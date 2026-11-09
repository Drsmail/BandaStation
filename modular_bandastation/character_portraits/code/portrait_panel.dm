/datum/character_portrait_panel
	var/client/owner
	var/character_slot
	var/moderation = FALSE
	var/list/images = list()
	var/selected_image_key
	var/selected_image_data
	var/status_message = ""
	var/status_is_error = FALSE
	var/list_state = "idle"
	var/busy = FALSE
	var/datum/preference_middleware/character_portraits/uploader

/datum/character_portrait_panel/New(client/owner, datum/preference_middleware/character_portraits/uploader)
	src.owner = owner
	src.uploader = uploader
	character_slot = owner?.prefs.default_slot

/datum/character_portrait_panel/Destroy()
	owner = null
	uploader = null
	images = null
	selected_image_data = null
	return ..()

/datum/character_portrait_panel/ui_state(mob/user)
	return moderation ? ADMIN_STATE(R_ADMIN) : GLOB.always_state

/datum/character_portrait_panel/ui_status(mob/user, datum/ui_state/state)
	if(user.client != owner)
		return UI_CLOSE
	return ..()

/datum/character_portrait_panel/ui_interact(mob/user, datum/tgui/ui)
	if(user.client != owner)
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, moderation ? "CharacterPortraitModeration" : "CharacterPortraits")
		ui.open()
	if(list_state == "idle")
		refresh_images()

/datum/character_portrait_panel/ui_data(mob/user)
	var/list/profile = owner?.prefs.savefile.get_entry("character[character_slot]")
	return list(
		"images" = images,
		"selected_image_key" = selected_image_key,
		"selected_image_data" = selected_image_data,
		"list_state" = list_state,
		"status_message" = status_message,
		"status_is_error" = status_is_error,
		"service_configured" = SSdbcore.IsConnected(),
		// TODO: Align this check with the processor library once it is implemented and integrated.
		"processor_available" = fexists(character_portrait_library()),
		"upload_in_progress" = uploader?.uploading,
		"character_slot" = character_slot,
		"active_portrait_id" = profile?["character_portrait_id"],
		"busy" = busy,
	)

/datum/character_portrait_panel/ui_act(action, list/params, datum/tgui/ui)
	if(..())
		return TRUE
	if(ui.user.client != owner || (moderation && !check_rights_for(owner, R_ADMIN)) || busy)
		return FALSE
	switch(action)
		if("refresh")
			refresh_images()
		if("select")
			for(var/list/image as anything in images)
				if(image["key"] == params["key"])
					selected_image_key = image["key"]
					load_preview(image)
					break
		if("upload")
			if(!moderation)
				uploader?.request_upload(params, ui.user)
		if("use")
			if(!moderation)
				save_selection()
		if("clear")
			if(!moderation)
				save_selection(TRUE)
		if("approve", "reject")
			if(moderation)
				moderate_selected(action == "approve" ? "approved" : "rejected")
		else
			return FALSE
	return TRUE

/datum/character_portrait_panel/proc/refresh_images()
	busy = TRUE
	list_state = "loading"
	SStgui.update_uis(src)
	var/list/new_images = character_portrait_images(moderation ? null : owner.ckey)
	if(QDELETED(src))
		return
	busy = FALSE
	if(isnull(new_images))
		list_state = "unavailable"
		set_status("База данных недоступна. Проверьте подключение и миграцию портретов.", TRUE)
		return
	images = new_images
	list_state = "loaded"
	var/list/image = selected_image()
	if(!image)
		image = length(images) ? images[1] : null
		selected_image_key = image?["key"]
	load_preview(image)
	SStgui.update_uis(src)

/datum/character_portrait_panel/proc/selected_image()
	for(var/list/image as anything in images)
		if(image["key"] == selected_image_key)
			return image
	return null

/datum/character_portrait_panel/proc/load_preview(list/image)
	selected_image_data = null
	if(!image)
		return
	var/path = character_portrait_path(image)
	if(path && fexists(path))
		selected_image_data = icon2base64(icon(file(path)))

/datum/character_portrait_panel/proc/set_status(message, is_error = FALSE)
	status_message = message
	status_is_error = is_error
	SStgui.update_uis(src)

/datum/character_portrait_panel/proc/save_selection(clear = FALSE)
	var/list/image = selected_image()
	if(!clear && (!image || image["status"] != "approved" || image["uploader_ckey"] != owner.ckey))
		return
	var/datum/preferences/preferences = owner.prefs
	var/list/profile = preferences.savefile.get_entry("character[character_slot]")
	if(!islist(profile))
		set_status("Этот слот персонажа был удалён. Откройте панель заново.", TRUE)
		return
	var/image_id = clear ? null : image["key"]
	busy = TRUE
	var/datum/db_query/query
	if(clear)
		query = SSdbcore.NewQuery(
			"DELETE FROM [format_table_name("character_portrait_selections")] WHERE ckey = :owner AND character_slot = :slot",
			list("owner" = owner.ckey, "slot" = character_slot),
		)
	else
		query = SSdbcore.NewQuery(
			"INSERT INTO [format_table_name("character_portrait_selections")] (ckey, character_slot, portrait_id) SELECT :owner, :slot, id FROM [format_table_name("character_portraits")] WHERE id = :id AND uploader_ckey = :owner AND status = 'approved' ON DUPLICATE KEY UPDATE portrait_id = VALUES(portrait_id)",
			list("owner" = owner.ckey, "slot" = character_slot, "id" = image["key"]),
		)
	var/success = query?.Execute()
	qdel(query)
	// The profile marker also prevents a reused/deleted slot inheriting an old SQL selection.
	if(success && !QDELETED(preferences) && preferences.savefile.get_entry("character[character_slot]") == profile)
		profile["character_portrait_id"] = image_id
		preferences.savefile.save()
	if(QDELETED(src))
		return
	busy = FALSE
	set_status(success ? "Сохранено для слота [character_slot]. Изменение применяется при следующем создании персонажа." : "Не удалось сохранить выбор.", !success)

GLOBAL_LIST_EMPTY(character_portrait_moderation_locks)

/datum/character_portrait_panel/proc/moderate_selected(decision)
	var/list/image = selected_image()
	if(!image || image["status"] != "pending" || !check_rights_for(owner, R_ADMIN))
		return
	var/image_id = image["key"]
	if(GLOB.character_portrait_moderation_locks[image_id])
		set_status("Это изображение уже проверяет другой модератор.", TRUE)
		return
	GLOB.character_portrait_moderation_locks[image_id] = TRUE
	var/reviewer_ckey = owner.ckey
	var/reviewer_name = key_name(owner)
	busy = TRUE
	var/source_path = character_portrait_path(image)
	var/list/destination = image.Copy()
	destination["status"] = decision
	var/destination_path = character_portrait_path(destination)
	var/success = fexists(source_path) && !fexists(destination_path) && fcopy(source_path, destination_path)
	if(success)
		var/datum/db_query/query = SSdbcore.NewQuery(
			"UPDATE [format_table_name("character_portraits")] SET status = :status, reviewer_ckey = :reviewer, reviewed_at = NOW() WHERE id = :id AND status = 'pending'",
			list("status" = decision, "reviewer" = reviewer_ckey, "id" = image_id),
		)
		success = query?.Execute() && query.affected == 1
		qdel(query)
		if(success)
			fdel(source_path)
			log_admin("[reviewer_name] [decision] character portrait [image_id] of [image["uploader_ckey"]].")
		else
			fdel(destination_path)
	GLOB.character_portrait_moderation_locks -= image_id
	if(QDELETED(src))
		return
	busy = FALSE
	refresh_images()
	set_status(success ? "Решение сохранено." : "Не удалось сохранить решение. Обновите список.", !success)

/datum/admins
	var/datum/character_portrait_panel/portrait_moderation_panel

/datum/admins/Destroy()
	if(IsAdminAdvancedProcCall())
		return ..()
	QDEL_NULL(portrait_moderation_panel)
	return ..()

ADMIN_VERB(character_portrait_moderation, R_ADMIN, "Character Portrait Moderation", "Review uploaded character portraits.", ADMIN_CATEGORY_GAME)
	if(user.holder.portrait_moderation_panel?.owner != user)
		QDEL_NULL(user.holder.portrait_moderation_panel)
	if(!user.holder.portrait_moderation_panel)
		user.holder.portrait_moderation_panel = new(user)
		user.holder.portrait_moderation_panel.moderation = TRUE
	user.holder.portrait_moderation_panel.ui_interact(user.mob)
