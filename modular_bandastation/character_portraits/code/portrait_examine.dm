/// Store the spawn-time portrait in DNA features so ordinary DNA copies retain it.
/datum/preferences/apply_prefs_to(mob/living/carbon/human/character, icon_updates = TRUE, list/do_not_apply)
	. = ..()
	var/owner_ckey = parent.ckey
	var/slot = default_slot
	var/list/profile = savefile.get_entry("character[slot]")
	var/path = character_portrait_selected_path(owner_ckey, slot, profile?["character_portrait_id"])
	if(!QDELETED(character) && path && fexists(path))
		character.dna.features["character_portrait_path"] = path

/mob/living/carbon/human/proc/character_portrait_url(mob/user)
	var/path = dna?.features["character_portrait_path"]
	if(!user.client || !path || !fexists(path))
		return
	if(HAS_TRAIT(src, TRAIT_UNKNOWN_APPEARANCE))
		return
	if((wear_mask?.flags_inv & HIDEFACE) || (head?.flags_inv & HIDEFACE))
		return
	return icon2html(file(path), user.client, sourceonly = TRUE)
