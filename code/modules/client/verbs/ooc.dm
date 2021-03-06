/client/verb/motd()
	set name = "MOTD"
	set category = "OOC"
	set desc ="Check the Message of the Day"

	var/motd = config.motd
	if(motd)
		to_chat(src, "<div class=\"motd\">[motd]</div>", handle_whitespace=FALSE)
	else
		to_chat(src, "<span class='notice'>The Message of the Day has not been set.</span>")

/client/proc/ooc_wrapper()
	var/message = input("","ooc (text)") as text|null
	if(message)
		ooc(message)

/client/verb/ooc(msg as text)
	set name = "OOC" //Gave this shit a shorter name so you only have to time out "ooc" rather than "ooc message" to use it --NeoFite
	set category = "OOC"

	if(say_disabled)	//This is here to try to identify lag problems
		to_chat(usr, "<span class='danger'>Speech is currently admin-disabled.</span>")
		return

	if(IsGuestKey(key))
		to_chat(src, "Guests may not use OOC.")
		return

	if(!is_preference_enabled(/datum/client_preference/show_ooc))
		to_chat(src, "<span class='warning'>You have OOC muted.</span>")
		return



	if(!mob)
		return

	if(!holder)
		if(!config_legacy.ooc_allowed)
			to_chat(src, "<span class='danger'>OOC is globally muted.</span>")
			return
		if(!config_legacy.dooc_allowed && (mob.stat == DEAD))
			to_chat(usr, "<span class='danger'>OOC for dead mobs has been turned off.</span>")
			return
		if(prefs.muted & MUTE_OOC)
			to_chat(src, "<span class='danger'>You cannot use OOC (muted).</span>")
			return
	// if(is_banned_from(ckey, "OOC"))
	// 	to_chat(src, "<span class='danger'>You have been banned from OOC.</span>")
	// 	return
	if(QDELETED(src))
		return

	msg = sanitize(msg)
	var/raw_msg = msg

	if(!msg)
		return

	if((msg[1] in list(".",";",":","#") || findtext_char(msg, "say", 1, 5))) //SSticker.HasRoundStarted() &&
		if(alert("Your message \"[raw_msg]\" looks like it was meant for in game communication, say it in OOC?", "Meant for OOC?", "No", "Yes") != "Yes")
			return

	if(!holder)
		if(handle_spam_prevention(MUTE_OOC))
			return
		if(findtext(msg, "byond://"))
			to_chat(src, "<B>Advertising other servers is not allowed.</B>")
			log_admin("[key_name(src)] has attempted to advertise in OOC: [msg]")
			message_admins("[key_name_admin(src)] has attempted to advertise in OOC: [msg]")
			return


	if(!is_preference_enabled(/datum/client_preference/show_ooc))
		to_chat(src, "<span class='warning'>You have OOC muted.</span>")
		return

	log_ooc(msg, src)

	var/ooc_style = "everyone"
	if(holder && !holder.fakekey)
		ooc_style = "elevated"
		if(holder.rights & R_EVENT)
			ooc_style = "event_manager"
		if(holder.rights & R_MOD)
			ooc_style = "moderator"
		if(holder.rights & R_DEBUG)
			ooc_style = "developer"
		if(holder.rights & R_ADMIN)
			ooc_style = "admin"

	for(var/client/target in GLOB.clients)
		if(target.is_preference_enabled(/datum/client_preference/show_ooc))
			if(target.is_key_ignored(key)) // If we're ignored by this person, then do nothing.
				continue
			var/display_name = src.key
			if(holder)
				if(holder.fakekey)
					if(target.holder)
						display_name = "[holder.fakekey]/([src.key])"
					else
						display_name = holder.fakekey
			if(holder && !holder.fakekey && (holder.rights & R_ADMIN) && config_legacy.allow_admin_ooccolor) // keeping this for the badmins
				to_chat(target, "<span class='prefix [ooc_style]'><span class='ooc'><font color='[prefs.ooccolor]'>" + "OOC: " + "<EM>[display_name]: </EM>[msg]</span></span></font>")
			else
				to_chat(target, "<span class='ooc'><span class='[ooc_style]'><span class='message linkify'>OOC: <EM>[display_name]: </EM>[msg]</span></span></span>")

/client/proc/looc_wrapper()
	var/message = input("","looc (text)") as text|null
	if(message)
		looc(message)

/client/verb/looc(msg as text)
	set name = "LOOC"
	set desc = "Local OOC, seen only by those in view."
	set category = "OOC"

	if(say_disabled)	//This is here to try to identify lag problems
		to_chat(src, "<span class='danger'>Speech is currently admin-disabled.</span>")
		return

	if(!mob)
		return

	if(IsGuestKey(key))
		to_chat(src, "Guests may not use OOC.")
		return

	msg = sanitize(msg)
	if(!msg)
		return

	if(!is_preference_enabled(/datum/client_preference/show_looc))
		to_chat(src, "<span class='danger'>You have LOOC muted.</span>")
		return

	if(!holder)
		if(!config_legacy.looc_allowed)
			to_chat(src, "<span class='danger'>LOOC is globally muted.</span>")
			return
		if(!config_legacy.dooc_allowed && (mob.stat == DEAD))
			to_chat(usr, "<span class='danger'>OOC for dead mobs has been turned off.</span>")
			return
		if(prefs.muted & MUTE_OOC)
			to_chat(src, "<span class='danger'>You cannot use OOC (muted).</span>")
			return
		if(findtext(msg, "byond://"))
			to_chat(src, "<B>Advertising other servers is not allowed.</B>")
			log_admin("[key_name(src)] has attempted to advertise in OOC: [msg]")
			message_admins("[key_name_admin(src)] has attempted to advertise in OOC: [msg]")
			return

	log_looc(msg,src)

	if(msg)
		handle_spam_prevention(MUTE_OOC)

	var/mob/source = mob.get_looc_source()
	var/turf/T = get_turf(source)
	if(!T) return
	var/list/in_range = get_mobs_and_objs_in_view_fast(T,world.view,0)
	var/list/m_viewers = in_range["mobs"]

	var/list/receivers = list() //Clients, not mobs.
	var/list/r_receivers = list()

	var/display_name = key
	if(holder && holder.fakekey)
		display_name = holder.fakekey
	if(mob.stat != DEAD)
		display_name = mob.name
	//VOREStation Add - Resleeving shenanigan prevention
	if(ishuman(mob))
		var/mob/living/carbon/human/H = mob
		if(H.original_player && H.original_player != H.ckey) //In a body not their own
			display_name = "[H.mind.name] (as [H.name])"
	//VOREStation Add End

	// Everyone in normal viewing range of the LOOC
	for(var/mob/viewer in m_viewers)
		if(viewer.client && viewer.client.is_preference_enabled(/datum/client_preference/show_looc))
			receivers |= viewer.client
		else if(istype(viewer,/mob/observer/eye)) // For AI eyes and the like
			var/mob/observer/eye/E = viewer
			if(E.owner && E.owner.client)
				receivers |= E.owner.client

	// Admins with RLOOC displayed who weren't already in
	for(var/client/admin in admins)
		if(!(admin in receivers) && admin.is_preference_enabled(/datum/client_preference/holder/show_rlooc))
			r_receivers |= admin

	// Send a message
	for(var/client/target in receivers)
		var/admin_stuff = ""

		if(target in admins)
			admin_stuff += "/([key])"

		to_chat(target, "<span class='looc'>" +  "LOOC: " + "<EM>[display_name][admin_stuff]: </EM><span class='message'>[msg]</span></span>")

	for(var/client/target in r_receivers)
		var/admin_stuff = "/([key])([admin_jump_link(mob, target.holder)])"

		to_chat(target, "<span class='looc'>" + "LOOC: " + " <span class='prefix'>(R)</span><EM>[display_name][admin_stuff]: </EM> <span class='message'>[msg]</span></span>")

/mob/proc/get_looc_source()
	return src

/mob/living/silicon/ai/get_looc_source()
	if(eyeobj)
		return eyeobj
	return src
