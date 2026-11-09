#define CHARACTER_PORTRAIT_DIRECTORY "data/character_portraits"
#define CHARACTER_PORTRAIT_COOLDOWN (30 SECONDS)
#define CHARACTER_PORTRAIT_PENDING_LIMIT 10

/client
	/// Temporarily enables the portrait-specific limit in AllowUpload.
	var/character_portrait_upload_dialog = FALSE

// TODO: Implement the portrait processor library and integrate it with this existing upload flow.
// Sources and build are not included in this repository; see ../README.md for the contract.
/proc/character_portrait_library()
	if(world.system_type == UNIX)
		return "./libportrait_processor.so"
	return "./portrait_processor.dll"

/datum/preference_middleware/character_portraits
	action_delegations = list("upload_character_portrait" = PROC_REF(open_panel))
	var/datum/character_portrait_panel/panel
	var/uploading = FALSE
	var/next_upload = 0
	var/upload_status = ""

/datum/preference_middleware/character_portraits/get_ui_data(mob/user)
	return list(
		"portrait_upload_available" = TRUE,
		"portrait_uploading" = uploading,
		"portrait_upload_status" = upload_status,
	)

/datum/preference_middleware/character_portraits/proc/open_panel(list/params, mob/user)
	if(user.client != preferences.parent)
		return FALSE
	if(panel && panel.character_slot != preferences.default_slot)
		QDEL_NULL(panel)
	if(!panel)
		panel = new(preferences.parent, src)
	panel.ui_interact(user)
	return TRUE

/datum/preference_middleware/character_portraits/Destroy()
	QDEL_NULL(panel)
	return ..()

/datum/preference_middleware/character_portraits/proc/request_upload(list/params, mob/user)
	if(user.client != preferences.parent || uploading || !SSdbcore.IsConnected())
		return FALSE
	// TODO: Deploy the implemented DLL/SO on the game server; keep uploads blocked until it is available.
	if(!fexists(character_portrait_library()))
		to_chat(user, span_warning("Обработчик портретов не установлен на сервере."))
		return FALSE
	if(is_guest_key(user.key))
		to_chat(user, span_warning("Для загрузки портрета нужен аккаунт BYOND."))
		return FALSE
	if(world.time < next_upload)
		to_chat(user, span_warning("Подождите 30 секунд между загрузками."))
		return FALSE
	uploading = TRUE
	upload_status = "Выберите изображение."
	next_upload = world.time + CHARACTER_PORTRAIT_COOLDOWN
	INVOKE_ASYNC(src, PROC_REF(upload_portrait), user)
	return TRUE

/datum/preference_middleware/character_portraits/proc/upload_portrait(mob/user)
	var/client/owner = preferences.parent
	var/owner_ckey = owner.ckey
	owner.character_portrait_upload_dialog = TRUE
	var/uploaded_file = input(user, "Выберите PNG, JPEG или WebP размером до 10 МиБ. Большая сторона будет уменьшена до 1080 пикселей с сохранением пропорций.", "Загрузить портрет") as null|file
	if(!QDELETED(owner))
		owner.character_portrait_upload_dialog = FALSE
	if(QDELETED(src))
		return
	if(!uploaded_file || QDELETED(owner) || user.client != owner)
		finish_upload("Загрузка отменена.")
		return
	var/pending_directory = "[CHARACTER_PORTRAIT_DIRECTORY]/[owner_ckey]/pending/"
	if(length(flist(pending_directory)) >= CHARACTER_PORTRAIT_PENDING_LIMIT)
		finish_upload("У вас уже 10 изображений в ожидании проверки.")
		return
	// The client supplies bytes only: both the ckey and filename are server controlled.
	var/image_id = rustg_generate_uuid_v4()
	var/original_filename = replacetext("[uploaded_file]", "\\", "/")
	var/list/filename_parts = splittext(original_filename, "/")
	original_filename = copytext_char(filename_parts[length(filename_parts)], 1, 256)
	var/input_path = "[CHARACTER_PORTRAIT_DIRECTORY]/[owner_ckey]/uploads/[image_id].upload"
	var/output_path = "[pending_directory][image_id].png"
	if(!fcopy(uploaded_file, input_path))
		finish_upload("Не удалось сохранить загруженный файл.")
		return
	var/list/start_result
	try
		// TODO: Implement portrait_start(input_path, output_path): JSON with status="started" and job.
		// Validate PNG/JPEG/WebP (10 MiB, 24 million pixels), resize to at most 1080 px and write PNG off-thread.
		start_result = json_decode(RUSTG_CALL(character_portrait_library(), "portrait_start")(input_path, output_path))
	catch(var/exception/start_error)
		fdel(input_path)
		log_game("Character portrait processor failed to start: [start_error]")
		finish_upload("Не удалось запустить обработчик изображения.")
		return
	if(start_result["status"] != "started")
		fdel(input_path)
		finish_upload("Обработчик занят или недоступен. Попробуйте позже.")
		return
	var/job_id = start_result["job"]
	upload_status = "Обработка изображения..."
	SStgui.update_uis(preferences)
	if(!QDELETED(panel))
		SStgui.update_uis(panel)
	// Continue collecting the job after disconnect so the native worker slot is freed.
	var/list/result
	try
		do
			sleep(1)
			// TODO: Implement portrait_check(job): pending, or ok with width/height, or failure with error.
			// Clean up the temporary input and release the worker on completion, including after disconnect.
			result = json_decode(RUSTG_CALL(character_portrait_library(), "portrait_check")(job_id))
		while(result["status"] == "pending")
	catch(var/exception/poll_error)
		log_game("Character portrait processor failed while polling: [poll_error]")
		if(!QDELETED(src))
			finish_upload("Не удалось получить результат обработки.")
		return
	if(result["status"] != "ok")
		log_game("Character portrait upload rejected for [owner_ckey]: [result["error"]]")
		if(!QDELETED(src))
			finish_upload("Не удалось обработать изображение. Проверьте формат и размер файла (до 10 МиБ и 24 миллионов пикселей).")
		return
	if(!character_portrait_record(image_id, owner_ckey, original_filename, result["width"], result["height"]))
		fdel(output_path)
		if(!QDELETED(src))
			finish_upload("Не удалось записать портрет в БД. Изображение удалено; повторите загрузку позже.")
		return
	log_game("Character portrait uploaded by [owner_ckey]: [output_path] ([result["width"]]x[result["height"]])")
	if(!QDELETED(src))
		finish_upload("Сохранено: [result["width"]]×[result["height"]] px, PNG. Ожидает проверки.")
	if(!QDELETED(owner))
		to_chat(owner, span_notice("Портрет сохранён в PNG ([result["width"]]×[result["height"]] px). Идентификатор: [image_id]."))

/datum/preference_middleware/character_portraits/proc/finish_upload(message)
	uploading = FALSE
	upload_status = message
	if(!QDELETED(panel))
		panel.set_status(message)
		panel.refresh_images()
	if(!QDELETED(preferences))
		SStgui.update_uis(preferences)

#undef CHARACTER_PORTRAIT_DIRECTORY
#undef CHARACTER_PORTRAIT_COOLDOWN
#undef CHARACTER_PORTRAIT_PENDING_LIMIT
