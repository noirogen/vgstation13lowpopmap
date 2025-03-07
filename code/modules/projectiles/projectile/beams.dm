
/*
 * Use: Caches beam state images and holds turfs that had these images overlaid.
 * Structure:
 * beam_master
 *     icon_states/dirs of beams
 *         image for that beam
 *     references for fired beams
 *         icon_states/dirs for each placed beam image
 *             turfs that have that icon_state/dir
 */


var/list/beam_master = list()

#define MAX_BEAM_DISTANCE 50

#define RAY_CAST_REBOUND 1.5

#define RAY_CAST_PORTAL 1.6

//overriding the filter function of an inherited beam
/ray/beam_ray
	var/obj/item/projectile/beam/fired_beam
	var/list/rayCastHit/hit_cache

/ray/beam_ray/New(var/vector/p_origin, var/vector/p_direction, var/obj/item/projectile/beam/fired_beam)
	..(p_origin, p_direction, fired_beam.starting.z)
	src.fired_beam = fired_beam
	original_damage = fired_beam.damage

/ray/beam_ray/Destroy()
	fired_beam = null
	QDEL_LIST_NULL(hit_cache)
	..()

/ray/beam_ray/cast(max_distance, max_hits, ignore_origin)
	. = ..()
	hit_cache = .

/ray/beam_ray/raycast_hit_check(var/rayCastHitInfo/info)
	var/atom/movable/A = info.hit_atom.get()

	if(isnull(A))
		return new /rayCastHit(info, RAY_CAST_NO_HIT_CONTINUE)

	var/turf/T = vector2turf(info.point, z)
	T.last_beam_damage = fired_beam.damage
	fired_beam.final_turf = final_turf
	fired_beam.previous_turf = previous_turf
	if(!A.Cross(fired_beam, T) || (!isturf(fired_beam.original) && A == fired_beam.original))
		var/ret = fired_beam.to_bump(A)
		if(ret)
			return new /rayCastHit(info, RAY_CAST_HIT_EXIT)
		else
			switch(fired_beam.special_collision)
				if (PROJECTILE_COLLISION_REBOUND)
					return new /rayCastHit(info, RAY_CAST_REBOUND)
				if (PROJECTILE_COLLISION_MISS)
					return new /rayCastHit(info, RAY_CAST_NO_HIT_CONTINUE)
				if (PROJECTILE_COLLISION_PORTAL)
					return new /rayCastHit(info, RAY_CAST_PORTAL)

	return new /rayCastHit(info, RAY_CAST_NO_HIT_CONTINUE)

/obj/item/projectile/beam
	name = "laser"
	icon_state = "laser"
	invisibility = 101
	animate_movement = 2
	linear_movement = 0 //this will set out icon_state to ..._pixel if 1
	layer = ABOVE_LIGHTING_LAYER
	plane = ABOVE_LIGHTING_PLANE
	pass_flags = PASSTABLE | PASSGLASS | PASSGRILLE | PASSRAILING
	damage = 30
	damage_type = BURN
	flag = "laser"
	eyeblur = 4
	fire_sound = 'sound/weapons/Laser.ogg'
	var/frequency = 1
	var/wait = 0
	var/beam_color = null
	var/beam_shift = null// the beam will animate() toward this color after being fired
	var/list/ray/past_rays = list() //full of rays
	var/turf/final_turf = null
	var/turf/previous_turf = null

/obj/item/projectile/beam/Destroy()
	QDEL_LIST_NULL(past_rays)
	..()


/obj/item/projectile/beam/proc/fireto(var/vector/origin, var/vector/direction)
	// + 0.5 because we want to start in the middle of the tile
	var/ray/beam_ray/shot_ray = new /ray/beam_ray(origin + new /vector(0.5, 0.5), direction, src)
	for(var/ray/beam_ray/other_ray in past_rays)
		if(other_ray.equals(shot_ray))
			return //we already went here

	var/list/rayCastHit/hits
	if(travel_range)
		hits = shot_ray.cast(travel_range)
	else
		hits = shot_ray.cast(MAX_BEAM_DISTANCE)
	final_turf = shot_ray.final_turf
	previous_turf = shot_ray.previous_turf
	if(!gcDestroyed)
		past_rays += shot_ray

	var/distance = MAX_BEAM_DISTANCE
	if(isnull(hits) || hits.len == 0)
		if(travel_range)
			distance = travel_range

	else
		var/rayCastHit/last_hit = hits[hits.len]

		distance = last_hit.distance

		if(last_hit.hit_type == RAY_CAST_REBOUND)
			final_turf=null
			ASSERT(!gcDestroyed)
			spawn()
				rebound(last_hit.hit_atom)

		if(last_hit.hit_type == RAY_CAST_PORTAL)
			final_turf=null
			ASSERT(!gcDestroyed)
			spawn()
				portal(last_hit.hit_atom)

	shot_ray.draw(distance, icon, icon_state, color_override = beam_color, color_shift = beam_shift)

	if(gcDestroyed)
		qdel(shot_ray)

/obj/item/projectile/beam/process()
	var/vector/origin = atom2vector(starting)
	var/vector/direction = atoms2vector(starting, original)

	fireto(origin, direction)

/obj/item/projectile/beam/rebound(atom/A)
	//we only allow this laser to be rebound once
	reflected = 1

	//we assume that our latest ray is what caused this rebound
	var/ray/beam_ray/latest_ray = past_rays[past_rays.len]

	//make new ray
	var/list/rayCastHit/hit_cache = latest_ray.hit_cache
	var/vector/origin = hit_cache[hit_cache.len].point
	var/vector/direction = latest_ray.getReboundOnAtom(hit_cache[hit_cache.len])

	//check if raypath was already traveled
	var/ray/temp_ray = new /ray(origin, direction)
	for(var/ray/beam_ray/other_ray in past_rays)
		if(temp_ray.equals(other_ray))
			return

	fireto(origin, direction)
	shot_from = A //temporary

/obj/item/projectile/beam/proc/portal(var/atom/A)
	var/atom/dest
	if (istype(A, /obj/effect/portal))
		var/obj/effect/portal/P = A
		dest = P.target
	else if (istype(A, /obj/machinery/teleport/hub))
		var/obj/machinery/teleport/hub/H = A
		dest = H.get_target_lock()

	var/ray/beam_ray/latest_ray = past_rays[past_rays.len]

	//make new ray
	var/vector/origin = atom2vector(dest)
	var/vector/direction = latest_ray.direction

	fireto(origin, direction)
	shot_from = dest


/obj/item/projectile/beam/dumbfire(var/dir)
	src.dir = dir || src.dir
	src.starting = starting || loc

	var/vector/origin = atom2vector(src.starting)
	var/vector/direction = dir2vector(src.dir)
	fireto(origin, direction)

// Special laser the captains gun uses
/obj/item/projectile/beam/captain
	name = "captain laser"
	icon_state = "laser_old"
	damage = 40
	linear_movement = 0

/obj/item/projectile/beam/retro
	icon_state = "laser_old"
	linear_movement = 0

/obj/item/projectile/beam/lightning
	invisibility = 101
	name = "lightning"
	damage = 0
	icon = 'icons/obj/lightning.dmi'
	icon_state = "lightning"
	linear_movement = 1
	stun = 10
	weaken = 10
	stutter = 50
	eyeblur = 50
	var/tang = 0
	layer = PROJECTILE_LAYER
	kill_count = 12
	var/mob/firer_mob = null
	var/yellow = 0
	var/passdense = 0

/obj/item/projectile/beam/lightning/proc/adjustAngle(angle)
	angle = round(angle) + 45
	if(angle > 180)
		angle -= 180
	else
		angle += 180
	if(!angle)
		angle = 1
	/*if(angle < 0)
		//angle = (round(abs(get_angle(A, user))) + 45) - 90
		angle = round(angle) + 45 + 180
	else
		angle = round(angle) + 45*/
	return angle


/obj/item/projectile/beam/lightning/admin_warn(mob/living/M)
	if(firer_mob && istype(firer_mob, /mob))
		if(firer_mob == M)
			log_attack("<font color='red'>[key_name(firer_mob)] shot himself with a [type].</font>")
			M.attack_log += "\[[time_stamp()]\] <b>[key_name(firer_mob)]</b> shot himself with a <b>[type]</b>"
			firer_mob.attack_log += "\[[time_stamp()]\] <b>[key_name(firer_mob)]</b> shot himself with a <b>[type]</b>"
			if(firer_mob.key || firer_mob.ckey)
				msg_admin_attack("[key_name(firer_mob)] shot himself with a [type], [pick("top kek!","for shame.","he definitely meant to do that","probably not the last time either.")] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[firer_mob.x];Y=[firer_mob.y];Z=[firer_mob.z]'>JMP</a>)")
			M.assaulted_by(firer_mob)
		else
			log_attack("<font color='red'>[key_name(firer_mob)] shot [key_name(M)] with a [type]</font>")
			M.attack_log += "\[[time_stamp()]\] <b>[key_name(firer_mob)]</b> shot <b>[key_name(M)]</b> with a <b>[type]</b>"
			firer_mob.attack_log += "\[[time_stamp()]\] <b>[key_name(firer_mob)]</b> shot <b>[key_name(M)]</b> with a <b>[type]</b>"
			if((firer_mob.key || firer_mob.ckey) && (M.key || M.ckey))
				msg_admin_attack("[key_name(firer_mob)] shot [key_name(M)] with a [type] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[firer_mob.x];Y=[firer_mob.y];Z=[firer_mob.z]'>JMP</a>)")
			M.assaulted_by(firer_mob)
	else
		..()

/obj/item/projectile/beam/lightning/process()
	icon_state = "lightning"
	var/first = 1 //So we don't make the overlay in the same tile as the firer
	var/broke = 0
	var/broken
	var/atom/curr = current
	var/Angle=round(Get_Angle(firer,curr))
	var/icon/I=new('icons/obj/lightning.dmi',"[icon_state][yellow ? "_yellow" : ""]")
	var/icon/Istart=new('icons/obj/lightning.dmi',"[icon_state]start[yellow ? "_yellow" : ""]")
	var/icon/Iend=new('icons/obj/lightning.dmi',"[icon_state]end[yellow ? "_yellow" : ""]")
	I.Turn(Angle+45)
	Istart.Turn(Angle+45)
	Iend.Turn(Angle+45)
	var/DX=(WORLD_ICON_SIZE*curr.x+curr.pixel_x)-(WORLD_ICON_SIZE*firer.x+firer.pixel_x)
	var/DY=(WORLD_ICON_SIZE*curr.y+curr.pixel_y)-(WORLD_ICON_SIZE*firer.y+firer.pixel_y)
	var/N=0
	var/length=round(sqrt((DX)**2+(DY)**2))
	var/count = 0
	var/turf/T = get_turf(src)
	var/list/ouroverlays = list()

	spawn() for(N,N<length,N+=WORLD_ICON_SIZE)
		if(count >= kill_count)
			break
		count++
		var/obj/effect/overlay/beam/persist/lightning_segment = new /obj/effect/overlay/beam/persist(T)
		lightning_segment.BeamSource=src
		ouroverlays += lightning_segment
		if((N+WORLD_ICON_SIZE*2>length) && (N+WORLD_ICON_SIZE<=length))
			lightning_segment.icon=Iend
		else if(N==0)
			lightning_segment.icon=Istart
		else if(N+WORLD_ICON_SIZE>length)
			lightning_segment.icon=null
		else
			lightning_segment.icon=I

		// We set pixel_x to the position it should be based on the angle of the lightning, then we reduce pixel_x by a factor of 32 and add it to the
		// x position variable instead, resulting in the same overall position. Then, we do the same for y.
		lightning_segment.pixel_x = round(sin(Angle)+WORLD_ICON_SIZE*sin(Angle)*(N+WORLD_ICON_SIZE)/WORLD_ICON_SIZE)
		lightning_segment.pixel_y = round(cos(Angle)+WORLD_ICON_SIZE*cos(Angle)*(N+WORLD_ICON_SIZE)/WORLD_ICON_SIZE)
		if(lightning_segment.pixel_x >= 0)
			lightning_segment.x += Floor( lightning_segment.pixel_x / WORLD_ICON_SIZE )
		else
			lightning_segment.x += Ceiling( lightning_segment.pixel_x / WORLD_ICON_SIZE )
		if(lightning_segment.pixel_y >= 0)
			lightning_segment.y += Floor( lightning_segment.pixel_y / WORLD_ICON_SIZE )
		else
			lightning_segment.y += Ceiling( lightning_segment.pixel_y / WORLD_ICON_SIZE )
		lightning_segment.pixel_y %= 32
		lightning_segment.pixel_x %= 32


		var/turf/TT = get_turf(lightning_segment.loc)
		while((TT.timestopped || timestopped || lightning_segment.timestopped) && count)
			sleep(2)

		if(TT == firer.loc)
			continue
		if(TT.density)
			QDEL_NULL(lightning_segment)
			break
		for(var/atom/movable/O in TT)
			if(!O.Cross(src))
				qdel(lightning_segment)
				broke = 1
				break
		for(var/mob/living/O in TT.contents)
			if(istype(O, /mob/living))
				if(O.density)
					QDEL_NULL(lightning_segment)
					broke = 1
					break
		if(broke)
			if(lightning_segment)
				QDEL_NULL(lightning_segment)
			break

	spawn(10)
		for(var/atom/thing in ouroverlays)
			if(!thing.timestopped && thing.loc && !thing.loc.timestopped)
				ouroverlays -= thing
				qdel(thing)
	spawn
		var/tS = 0
		while(loc) //Move until we hit something
			if(tS)
				tS = 0
				timestopped = loc.timestopped
			while((loc.timestopped || timestopped) && !first)
				tS = 1
				sleep(3)
			if(first)
				icon = midicon
				if(timestopped || loc.timestopped)
					tS = 1
					timestopped = 0
			if((!( current ) || loc == current)) //If we pass our target
				broken = 1
				icon = endicon
				tang = adjustAngle(get_angle(original,current))
				if(tang > 180)
					tang -= 180
				else
					tang += 180
				icon_state = "[tang]"
				var/turf/simulated/floor/f = current
				if(f && istype(f))
					f.break_tile()
					f.hotspot_expose(1000,CELL_VOLUME,surfaces=1)
			if((x == 1 || x == world.maxx || y == 1 || y == world.maxy))
//				to_chat(world, "deleting")
				//del(src) //Delete if it passes the world edge
				broken = 1
				return
			if(kill_count < 1)
//				to_chat(world, "deleting")
				//del(src)
				broken = 1
			kill_count--
//			to_chat(world, "[x] [y]")
			if(!bumped && !isturf(original))
				if(loc == get_turf(original))
					if(!(original in permutated))
						icon = endicon
					if(!broken)
						tang = adjustAngle(get_angle(original,current))
						if(tang > 180)
							tang -= 180
						else
							tang += 180
						icon_state = "[tang]"
					to_bump(original)
			first = 0
			if(broken)
//				to_chat(world, "breaking")
				break
			else
				step_towards(src, current) //Move~
				if(src.loc != current)
					tang = adjustAngle(get_angle(src.loc,current))
				icon_state = "[tang]"
		if(ouroverlays.len)
			sleep(10)
			for(var/atom/thing in ouroverlays)
				ouroverlays -= thing
				qdel(thing)

		//del(src)
		qdel(src)

/*cleanup(reference) //Waits .3 seconds then removes the overlay.
//	to_chat(world, "setting invisibility")
	sleep(50)
	src.invisibility = 101
	return*/

/obj/item/projectile/beam/lightning/on_hit(atom/target, blocked = 0)
	if(istype(target, /mob/living))
		var/mob/living/M = target
		M.playsound_local(src, "explosion", 50, 1)
	..()

/obj/item/projectile/beam/lightning/spell
	var/spell/lightning/our_spell
	weaken = 0
	stun = 0
	stutter = 0
	eyeblur = 0
/obj/item/projectile/beam/lightning/spell/to_bump(atom/A as mob|obj|turf|area)
	. = ..()
	if(.)
		our_spell.lastbumped = A
	return .

/obj/item/projectile/beam/practice
	name = "laser"
	icon_state = "laser"
	damage = 0
	eyeblur = 2

/obj/item/projectile/beam/practice/stormtrooper
	fire_sound = "sound/weapons/blaster-storm.ogg"
	excessive_missing = TRUE
	projectile_miss_chance = 99999
	projectile_miss_message_replace = TRUE

/obj/item/projectile/beam/practice/stormtrooper/to_bump(atom/A)
	var/selected_message = pick("\The [src] narrowly whizzes past [A]!","\The [src] almost hits [A]!",
								"\The [src] straight up misses [A].","[A]'s hair is singed off by \the [src]!",
								"\The [src] misses [A] by a millimetre!","\The [src] doesn't hit [A]!",
								"\The [src] misses [A].","[A] has a lucky escape from \the [src]!")
	projectile_miss_message = "<span class='danger'>[selected_message]</span>"
	return ..()

/obj/item/projectile/beam/scorchray
	name = "scorch ray"
	icon_state = "scorchray"
	damage = 30
	fire_sound = 'sound/weapons/ray1.ogg'

/obj/item/projectile/beam/scorchray/on_hit(var/atom/target, var/blocked = 0)
	if(!..())
		return 0
	var/mob/living/carbon/human/H = target
	if(!istype(H) || !H.isDead() || !(H.species.anatomy_flags & NO_BLOOD)) //Not human, not dead or doesn't have blood
		return 1 // This way it should only apply to the more fleshy species (To-Do: Add animations for mushmen, catbeasts, skrell, and unathi)
	var/lying_animation = "dust-h2-nohead" //Defaults to humanoid ashing sprites if it doesn't get changed
	var/standing_animation = "dust-h-nohead"
	if(isgrey(H))
		lying_animation = "dust-g2-nohead"
		standing_animation = "dust-g-nohead"
	else if(isvox(H))
		lying_animation = "dust-v2-nohead"
		standing_animation = "dust-v-nohead"
	else if(isinsectoid(H))
		lying_animation = "dust-i2-nohead"
		standing_animation = "dust-i-nohead"
	H.visible_message("<span class='danger'>[H.name]'s body disintegrates into ash!</span>")
	playsound(target.loc, 'sound/items/Welder.ogg', 100, 1)
	H.drop_all() // So their gear doesn't all get deleted
	var/datum/organ/external/head/head_organ = H.get_organ(LIMB_HEAD)
	if(head_organ)
		head_organ.droplimb(1,1) // Their body melts, but the head flies off (so they can be revived)
	if(H.lying)
		anim(target = H, a_icon = 'icons/mob/mob.dmi', flick_anim = lying_animation, sleeptime = 15)
	else
		anim(target = H, a_icon = 'icons/mob/mob.dmi', flick_anim = standing_animation, sleeptime = 15)
	new /obj/effect/decal/cleanable/ash(get_turf(target))
	qdel(H)
	return 1

/obj/item/projectile/beam/scorchray/immolationray
	name = "immolation ray"
	icon_state = "immolationray"
	damage = 45

/obj/item/projectile/beam/scorchray/immolationray/upgraded // Exclusively used by the hoverdisc drone
	damage = 55
	destroy = 1

/obj/item/projectile/beam/scorchray/atomizationray
	name = "atomization ray"
	icon_state = "atomray"
	damage = 40

/obj/item/projectile/beam/lightlaser
	name = "light laser"
	damage = 25

/obj/item/projectile/beam/weaklaser
	name = "weak laser"
	damage = 15

/obj/item/projectile/beam/weakerlaser
	name = "mini laser"
	damage = 10

/obj/item/projectile/beam/veryweaklaser
	name = "micro laser"
	damage = 5

/obj/item/projectile/beam/humanelaser
	damage = 25

/obj/item/projectile/beam/humanelaser/to_bump(atom/A as mob|obj|turf|area)
	if(ishuman(A))
		damage = 10
	if(istype(A,/obj/effect/blob)) //It will deal half of its damage to a nearby blob tile on hit.
		var/obj/effect/blob/B = A
		var/actual_damage = damage/B.fire_resist //More resistant tiles such as strong blobs will cause less damage to be spread
		for(var/obj/effect/blob/B2 in orange(1,B))
			B2.bullet_act(src, null, actual_damage)
			break
	return ..()

/obj/item/projectile/beam/heavylaser
	name = "heavy laser"
	icon_state = "heavylaser"
	damage = 60
	fire_sound = 'sound/weapons/lasercannonfire.ogg'

/obj/item/projectile/beam/heavylaser/lawgiver
	damage = 40

/obj/item/projectile/beam/xray
	name = "xray beam"
	icon_state = "xray"
	damage = 30
	kill_count = 500
	phase_type = PROJREACT_WALLS|PROJREACT_WINDOWS|PROJREACT_OBJS|PROJREACT_MOBS|PROJREACT_BLOB
	penetration = -1
	fire_sound = 'sound/weapons/laser3.ogg'

/obj/item/projectile/beam/xray/to_bump(atom/A)
	if((istype(A, /turf/simulated/wall/r_wall) || (istype(A, /obj/machinery/door/poddoor) && !istype(A, /obj/machinery/door/poddoor/shutters))) || damage <=0)	//if we hit an rwall or blast doors, but not shutters, the beam dies
		bullet_die()
		return 0
	if(..())
		damage -= 3


/obj/item/projectile/beam/pulse
	name = "pulse"
	icon_state = "u_laser"
	damage = 50
	destroy = 1
	fire_sound = 'sound/weapons/pulse.ogg'

/obj/item/projectile/beam/deathlaser
	name = "death laser"
	icon_state = "heavylaser"
	damage = 60

/obj/item/projectile/beam/emitter
	name = "emitter beam"
	icon_state = "emitter"
	damage = 30

/obj/item/projectile/beam/emitter/singularity_pull()
	return

////////Laser Tag////////////////////

var/list/laser_tag_vests = list(/obj/item/clothing/suit/tag/redtag, /obj/item/clothing/suit/tag/bluetag)

/obj/item/projectile/beam/lasertag
	name = "lasertag beam"
	damage = 0
	icon_state = "bluelaser"
	var/list/enemy_vest_types = list(/obj/item/clothing/suit/tag/redtag)

/obj/item/projectile/beam/lasertag/on_hit(var/atom/target, var/blocked = 0)
	if(ismob(target))
		var/mob/M = target
		var/obj/item/clothing/suit/tag/target_tag = get_tag_armor(M)
		var/obj/item/clothing/suit/tag/firer_tag = get_tag_armor(firer)
		if(is_type_in_list(target_tag, laser_tag_vests))
			var/datum/laser_tag_game/game = firer_tag.my_laser_tag_game
			if (!game) // No registered game : classic laser tag
				if (!(is_type_in_list(target_tag, enemy_vest_types)))
					return 1
				if(!M.lying) //Kick a man while he's down, will ya
					var/obj/item/weapon/gun/energy/tag/taggun = shot_from
					if(istype(taggun))
						taggun.score()
				M.Knockdown(2)
				M.Stun(2)
			else // We've got a game on the receiver, let's check if we've got a game on the wearer.
				if (!firer_tag || !firer_tag.my_laser_tag_game || (target_tag.my_laser_tag_game != firer_tag.my_laser_tag_game))
					return 1
				if (!target_tag.player || !firer_tag.player)
					CRASH("A suit has a laser tag game registered, but no players attached.")

				var/datum/laser_tag_participant/target_player = target_tag.player
				var/datum/laser_tag_participant/firer_player = firer_tag.player

				if (firer_tag.my_laser_tag_game.mode == LT_MODE_TEAM && !(is_type_in_list(target_tag, enemy_vest_types)))
					return 1
				if(!M.lying) // Not counting scores if the opponent is lying down.
					firer_player.total_hits++
					target_player.total_hit_by++
					target_player.hit_by[firer_player.nametag]++
				var/taggun_index = M.find_held_item_by_type(/obj/item/weapon/gun/energy/tag)
				if (taggun_index)
					var/obj/item/weapon/gun/energy/tag/their_gun = M.held_items[taggun_index]
					their_gun.cooldown(target_tag.my_laser_tag_game.disable_time/2)
				M.Knockdown(target_tag.my_laser_tag_game.stun_time/2)
				M.Stun(target_tag.my_laser_tag_game.stun_time/2)
				var/obj/item/weapon/gun/energy/tag/taggun = shot_from
				if(istype(taggun))
					taggun.score()
	return 1

/obj/item/projectile/beam/lasertag/blue
	icon_state = "bluelaser"
	enemy_vest_types = list(/obj/item/clothing/suit/tag/redtag)

/obj/item/projectile/beam/lasertag/red
	icon_state = "laser"
	enemy_vest_types = list(/obj/item/clothing/suit/tag/bluetag)

/obj/item/projectile/beam/lasertag/omni //A laser tag ray that stuns EVERYONE
	icon_state = "omnilaser"
	enemy_vest_types = list(/obj/item/clothing/suit/tag/redtag, /obj/item/clothing/suit/tag/bluetag)



/obj/item/projectile/beam/bison
	name = "heat ray"
	damage_type = BURN
	flag = "laser"
	kill_count = 100
	layer = PROJECTILE_LAYER
	damage = 15
	icon = 'icons/obj/lightning.dmi'
	icon_state = "heatray"
	animate_movement = 0
	linear_movement = 0
	pass_flags = PASSTABLE | PASSRAILING
	var/drawn = 0
	var/tang = 0
	var/turf/last = null
	fire_sound = 'sound/weapons/bison_fire.ogg'

/obj/item/projectile/beam/bison/proc/adjustAngle(angle)
	angle = round(angle) + 45
	if(angle > 180)
		angle -= 180
	else
		angle += 180
	if(!angle)
		angle = 1
	/*if(angle < 0)
		//angle = (round(abs(get_angle(A, user))) + 45) - 90
		angle = round(angle) + 45 + 180
	else
		angle = round(angle) + 45*/
	return angle

/obj/item/projectile/beam/bison/process()
	//calculating the turfs that we go through
	var/lastposition = loc
	target = get_turf(original)
	dist_x = abs(target.x - src.x)
	dist_y = abs(target.y - src.y)

	if (target.x > src.x)
		dx = EAST
	else
		dx = WEST

	if (target.y > src.y)
		dy = NORTH
	else
		dy = SOUTH

	if(dist_x > dist_y)
		error = dist_x/2 - dist_y

		spawn while(src && src.loc)
			// only stop when we've hit something, or hit the end of the map
			if(error < 0)
				var/atom/step = get_step(src, dy)
				if(!step) // going off the edge of the map makes get_step return null, don't let things go off the edge
					break
				src.Move(step)
				error += dist_x
			else
				var/atom/step = get_step(src, dx)
				if(!step)
					break
				src.Move(step)
				error -= dist_y

			if(isnull(loc))
				if(!isnull(lastposition))
					draw_ray(lastposition)
				return
			if(lastposition == loc)
				kill_count = 0
			lastposition = loc
			if(kill_count < 1)
				//del(src)
				draw_ray(lastposition)
				qdel(src)
				return
			kill_count--

			if(!bumped && !isturf(original))
				if(loc == target)
					if(!(original in permutated))
						draw_ray(target)
						to_bump(original)

	else
		error = dist_y/2 - dist_x
		spawn while(src && src.loc)
			// only stop when we've hit something, or hit the end of the map
			if(error < 0)
				var/atom/step = get_step(src, dx)
				if(!step)
					break
				src.Move(step)
				error += dist_y
			else
				var/atom/step = get_step(src, dy)
				if(!step)
					break
				src.Move(step)
				error -= dist_x

			if(isnull(loc))
				if(!isnull(lastposition))
					draw_ray(lastposition)
				return
			if(lastposition == loc)
				kill_count = 0
			lastposition = loc
			if(kill_count < 1)
				//del(src)
				draw_ray(lastposition)
				qdel(src)
				return
			kill_count--

			if(!bumped && !isturf(original))
				if(loc == get_turf(original))
					if(!(original in permutated))
						draw_ray(target)
						to_bump(original)

/obj/item/projectile/beam/bison/bullet_die()
	draw_ray(loc)
	..()

/obj/item/projectile/beam/bison/proc/draw_ray(var/turf/lastloc)
	if (gcDestroyed)
		return
	if(drawn)
		return
	drawn = 1
	var/atom/curr = lastloc
	if(!firer)
		firer = starting
	var/Angle=round(Get_Angle(firer,curr))
	var/icon/I=new('icons/obj/lightning.dmi',icon_state)
	var/icon/Istart=new('icons/obj/lightning.dmi',"[icon_state]start")
	var/icon/Iend=new('icons/obj/lightning.dmi',"[icon_state]end")
	I.Turn(Angle+45)
	Istart.Turn(Angle+45)
	Iend.Turn(Angle+45)
	var/DX=(WORLD_ICON_SIZE*curr.x+curr.pixel_x)-(WORLD_ICON_SIZE*firer.x+firer.pixel_x)
	var/DY=(WORLD_ICON_SIZE*curr.y+curr.pixel_y)-(WORLD_ICON_SIZE*firer.y+firer.pixel_y)
	var/N=0
	var/length=round(sqrt((DX)**2+(DY)**2))
	var/count = 0
	var/turf/T = get_turf(firer)
	var/timer_total = 16
	var/increment = timer_total/max(1,round(length/32))
	var/current_timer = 5

	for(N,N<(length+16),N+=WORLD_ICON_SIZE)
		if(count >= kill_count)
			break
		count++
		var/obj/effect/overlay/beam/X=new /obj/effect/overlay/beam(T, current_timer, 1, base_damage = 1)
		X.BeamSource=src
		current_timer += increment
		if((N+64>(length+16)) && (N+WORLD_ICON_SIZE<=(length+16)))
			X.icon=Iend
		else if(N==0)
			X.icon=Istart
		else if(N+WORLD_ICON_SIZE>(length+16))
			X.icon=null
		else
			X.icon=I


		var/Pixel_x=round(sin(Angle)+WORLD_ICON_SIZE*sin(Angle)*(N+WORLD_ICON_SIZE/2)/WORLD_ICON_SIZE)
		var/Pixel_y=round(cos(Angle)+WORLD_ICON_SIZE*cos(Angle)*(N+WORLD_ICON_SIZE/2)/WORLD_ICON_SIZE)
		if(DX==0)
			Pixel_x=0
		if(DY==0)
			Pixel_y=0
		if(Pixel_x>WORLD_ICON_SIZE)
			for(var/a=0, a<=Pixel_x,a+=WORLD_ICON_SIZE)
				X.x++
				Pixel_x-=WORLD_ICON_SIZE
		if(Pixel_x<-WORLD_ICON_SIZE)
			for(var/a=0, a>=Pixel_x,a-=WORLD_ICON_SIZE)
				X.x--
				Pixel_x+=WORLD_ICON_SIZE
		if(Pixel_y>WORLD_ICON_SIZE)
			for(var/a=0, a<=Pixel_y,a+=WORLD_ICON_SIZE)
				X.y++
				Pixel_y-=WORLD_ICON_SIZE
		if(Pixel_y<-WORLD_ICON_SIZE)
			for(var/a=0, a>=Pixel_y,a-=WORLD_ICON_SIZE)
				X.y--
				Pixel_y+=WORLD_ICON_SIZE

		//Now that we've calculated the total offset in pixels, we move each beam parts to their closest corresponding turfs
		var/x_increm = 0
		var/y_increm = 0

		while(Pixel_x >= WORLD_ICON_SIZE || Pixel_x <= -WORLD_ICON_SIZE)
			if(Pixel_x > 0)
				Pixel_x -= WORLD_ICON_SIZE
				x_increm++
			else
				Pixel_x += WORLD_ICON_SIZE
				x_increm--

		while(Pixel_y >= WORLD_ICON_SIZE || Pixel_y <= -WORLD_ICON_SIZE)
			if(Pixel_y > 0)
				Pixel_y -= WORLD_ICON_SIZE
				y_increm++
			else
				Pixel_y += WORLD_ICON_SIZE
				y_increm--

		X.x += x_increm
		X.y += y_increm
		X.pixel_x=Pixel_x
		X.pixel_y=Pixel_y
		var/turf/TT = get_turf(X.loc)
		if(TT == firer.loc)
			continue

/obj/item/projectile/beam/bison/to_bump(atom/A as mob|obj|turf|area)
	//Heat Rays go through mobs
	if(A == firer)
		loc = A.loc
		return 0 //cannot shoot yourself

	if(firer && istype(A, /mob/living))
		var/mob/living/M = A
		A.bullet_act(src, def_zone)
		loc = A.loc
		permutated.Add(A)
		visible_message("<span class='warning'>[A.name] is hit by the [src.name] in the [parse_zone(def_zone)]!</span>")//X has fired Y is now given by the guns so you cant tell who shot you if you could not see the shooter
		if(istype(firer, /mob))
			log_attack("<font color='red'>[key_name(firer)] shot [key_name(M)] with a [type]</font>")
			M.attack_log += "\[[time_stamp()]\] <b>[key_name(firer)]</b> shot <b>[key_name(M)]</b> with a <b>[type]</b>"
			firer.attack_log += "\[[time_stamp()]\] <b>[key_name(firer)]</b> shot <b>[key_name(M)]</b> with a <b>[type]</b>"
			msg_admin_attack("[key_name(firer)] shot [key_name(M)] with a [type] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[firer.x];Y=[firer.y];Z=[firer.z]'>JMP</a>)") //BS12 EDIT ALG
			M.assaulted_by(firer)
		else
			M.attack_log += "\[[time_stamp()]\] <b>UNKNOWN/(no longer exists)</b> shot <b>[key_name(M)]</b> with a <b>[type]</b>"
			msg_admin_attack("UNKNOWN/(no longer exists) shot [key_name(M)] with a [type] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[firer.x];Y=[firer.y];Z=[firer.z]'>JMP</a>)") //BS12 EDIT ALG
			log_attack("<font color='red'>UNKNOWN/(no longer exists) shot [key_name(M)] with a [type]</font>")
		return 1
	else
		return ..()

/obj/item/projectile/beam/apply_projectile_color(var/proj_color)
	beam_color = proj_color

/obj/item/projectile/beam/apply_projectile_color_shift(var/proj_color_shift)
	beam_shift = proj_color_shift

//Used by the pain mirror spell
//Damage type and damage done varies
/obj/item/projectile/beam/pain
	name = "bolt of pain"
	pass_flags = PASSALL //Go through everything
	icon_state = "pain"

/obj/item/projectile/beam/white
	icon_state = "whitelaser"

/obj/item/projectile/beam/rainbow
	icon_state = "rainbow"

/obj/item/projectile/beam/white/hit_apply(var/mob/living/X, var/blocked)
	X.reagents.add_reagent(SPACE_DRUGS, 1)
	X.reagents.add_reagent(HONKSERUM, 10)
	var/hit_verb = pick("covers","completely soaks","fills","splashes")
	X.visible_message("<span class='warning'>\The [src] [hit_verb] [X] with love!</span>",
		"<span class='warning'>\The [src] [hit_verb] you with love!</span>")

/obj/item/projectile/beam/liquid_stream
	name = "stream of liquid"
	icon_state = "liquid_stream"
	damage = 0
	fire_sound = null
	custom_impact = 1
	penetration = 0
	pass_flags = PASSTABLE | PASSRAILING
	var/has_splashed = FALSE
	var/atom/splashed_atom = null

/obj/item/projectile/beam/liquid_stream/New(atom/A, var/t_range=3, var/m_color, var/m_alpha=255)
	..(A)
	create_reagents(20)
	travel_range = t_range
	beam_color = m_color
	alpha = m_alpha

/obj/item/projectile/beam/liquid_stream/on_hit(var/atom/A, var/blocked = 0)
	if(reagents.total_volume && istype(A, /mob))
		if(firer.zone_sel.selecting == TARGET_MOUTH && def_zone == LIMB_HEAD && ishuman(A)) //if aiming at head and is humanoid
			var/mob/living/carbon/human/victim = A
			if(!victim.check_body_part_coverage(MOUTH)) //if not covered with mask or something
				victim.visible_message("<span class='warning'>[A] swallows \the [src]!</span>",
									"<span class='warning'>You swallow \the [src]!</span>")
				reagents.trans_to(A, reagents.total_volume)
				has_splashed = TRUE //guess we arent stacking with the splash
				qdel(src)
				return 1
			else
				A.visible_message("<span class='warning'>\The [src] gets blocked from [A]'s mouth!</span>",
								"<span class='warning'>\The [src] gets blocked from your mouth!</span>")//just block mouth, no turf splash
		else
			var/splash_verb = pick("douses","completely soaks","drenches","splashes")
			A.visible_message("<span class='warning'>\The [src] [splash_verb] [A]!</span>",
								"<span class='warning'>\The [src] [splash_verb] you!</span>")

/obj/item/projectile/beam/liquid_stream/to_bump(var/atom/A)
	splashed_atom = A//doesn't matter if it's actually the atom we end up splashing since we only use that var on bullet_die()
	. = ..()

/obj/item/projectile/beam/liquid_stream/bullet_die()//splashes reagents on the hit atom, or in front of it in case of turfs and border objects
	if(reagents && reagents.total_volume && !has_splashed && ((bumped && splashed_atom) || final_turf))
		if (splashed_atom && !isturf(splashed_atom) && (previous_turf && previous_turf.Adjacent(splashed_atom)))
			if (splashed_atom.flow_flags & ON_BORDER)
				loc = previous_turf
			else
				loc = get_turf(splashed_atom)
		else if (isturf(splashed_atom))
			loc = final_turf
		else
			loc = previous_turf
		playsound(loc, 'sound/effects/slosh.ogg', 20, 1)
		reagents.splashplosion(0)
		has_splashed = TRUE
	..()
//I never want to deal wity ray casts ever again
/obj/item/projectile/beam/liquid_stream/fireto(var/vector/origin, var/vector/direction)//splashes reagents on the turf if the projectile ran out
	..()
	if (reagents && reagents.total_volume && final_turf && !has_splashed)
		loc = final_turf
		reagents.splashplosion(0)
		has_splashed = TRUE
		qdel(src)


/obj/item/projectile/beam/liquid_stream/proc/adjust_strength(var/t_range)
	if(t_range)
		travel_range = t_range
	else
		travel_range = 0

/obj/item/projectile/beam/combustion
	name = "combustion beam"
	icon_state = "heavylaser"
	damage = 0
	fire_sound = 'sound/weapons/railgun_highpower.ogg'

/obj/item/projectile/beam/combustion/to_bump(atom/A)
	if(!A)
		return
	..()
	var/turf/T = get_turf(A)
	explosion(T,0,0,5)
	var/datum/effect/system/smoke_spread/smoke = new /datum/effect/system/smoke_spread()
	smoke.set_up(3, 0, T)
	smoke.start()
	return 1

/obj/item/projectile/beam/armawhip
	name = "bullwhip"
	icon = 'icons/obj/projectiles.dmi'
	icon_state = "whip"
	fire_sound = 'sound/weapons/whip_crack.ogg'
	travel_range = 5
	damage = 10
	damage_type = BRUTE
	pass_flags = PASSTABLE | PASSRAILING
	eyeblur = 0
