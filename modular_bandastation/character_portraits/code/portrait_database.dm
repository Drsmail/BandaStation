/// Metadata is stored in SQL; PNG bytes remain in the persistent data directory.
/proc/character_portrait_path(list/image)
	var/directory = image["status"] == "rejected" ? "deny" : image["status"]
	if(!(directory in list("pending", "approved", "deny")))
		return null
	return "data/character_portraits/[image["uploader_ckey"]]/[directory]/[image["key"]].png"

/proc/character_portrait_images(owner_ckey)
	if(!SSdbcore.IsConnected())
		return null
	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT id, uploader_ckey, filename, status, reviewer_ckey FROM [format_table_name("character_portraits")] WHERE (:owner IS NULL OR uploader_ckey = :owner) ORDER BY created_at DESC LIMIT 500",
		list("owner" = owner_ckey),
	)
	if(!query?.Execute())
		qdel(query)
		return null
	var/list/images = list()
	while(query.NextRow())
		images += list(list("key" = query.item[1], "uploader_ckey" = query.item[2], "filename" = query.item[3], "status" = query.item[4], "reviewer_ckey" = query.item[5]))
	qdel(query)
	return images

/proc/character_portrait_record(image_id, owner_ckey, filename, width, height)
	var/datum/db_query/query = SSdbcore.NewQuery(
		"INSERT INTO [format_table_name("character_portraits")] (id, uploader_ckey, filename, width, height) VALUES (:id, :owner, :filename, :width, :height)",
		list("id" = image_id, "owner" = owner_ckey, "filename" = filename, "width" = width, "height" = height),
	)
	. = query?.Execute()
	qdel(query)

/// Resolve an owned and approved selection; never accept a path from the client.
/proc/character_portrait_selected_path(owner_ckey, slot, portrait_id)
	if(!portrait_id || !SSdbcore.IsConnected())
		return null
	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT p.id FROM [format_table_name("character_portrait_selections")] s JOIN [format_table_name("character_portraits")] p ON p.id = s.portrait_id AND p.uploader_ckey = s.ckey WHERE s.ckey = :owner AND s.character_slot = :slot AND p.id = :id AND p.status = 'approved'",
		list("owner" = owner_ckey, "slot" = slot, "id" = portrait_id),
	)
	if(query?.Execute() && query.NextRow())
		. = "data/character_portraits/[owner_ckey]/approved/[query.item[1]].png"
	qdel(query)
