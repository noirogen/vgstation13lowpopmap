
/*
 * Backpack
 */

/obj/item/weapon/storage/backpack
	name = "backpack"
	desc = "You wear this on your back and put items into it."
	inhand_states = list("left_hand" = 'icons/mob/in-hand/left/backpacks_n_bags.dmi', "right_hand" = 'icons/mob/in-hand/right/backpacks_n_bags.dmi')
	icon_state = "backpack"
	item_state = "backpack"
	w_class = W_CLASS_LARGE
	flags = FPRINT
	slot_flags = SLOT_BACK	//ERROOOOO
	fits_max_w_class = W_CLASS_MEDIUM
	max_combined_w_class = 21
	w_type = RECYK_FABRIC
	flammable = TRUE
	species_fit = list(VOX_SHAPED)

/obj/item/weapon/storage/backpack/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if(!stealthy(user))
		playsound(src, "rustle", 50, 1, -5)
	return ..()

/*
 * Backpack Types
 */


/obj/item/weapon/storage/backpack/santabag
	name = "Santa's Gift Bag"
	desc = "Space Santa uses this to deliver toys to all the nice children in space in Christmas! Wow, it's pretty big!"
	icon_state = "giftbag0"
	item_state = "giftbag0"
	w_class = W_CLASS_LARGE
	storage_slots = 0
	fits_max_w_class = W_CLASS_LARGE
	max_combined_w_class = 400 // can store a ton of shit!
	flags = MECH_SCAN_FAIL

/obj/item/weapon/storage/backpack/santabag/admin/attack_hand(user)
	if(contents.len < storage_slots)
		var/empty_slots = clamp((storage_slots - contents.len),0,storage_slots)
		to_chat(user,"<span class='notice'>You look into the bag, and find it filled with [empty_slots] new presents!</span>")
		for(var/i = 1,i <= empty_slots,i++)
			var/gift = pick(/obj/item/weapon/winter_gift/cloth,/obj/item/weapon/winter_gift/regular,/obj/item/weapon/winter_gift/food)
			if(prob(1))
				gift = /obj/item/weapon/winter_gift/special
			new gift(src)
	. = ..()

/obj/item/weapon/storage/backpack/santabag/refresh_all()
	..()
	update_icon()

/obj/item/weapon/storage/backpack/santabag/pickup()
	..()
	update_icon()

/obj/item/weapon/storage/backpack/santabag/update_icon()
	var/bagtype = "giftbag"
	var/bagfill = 0

	if (istype(loc, /mob/living/simple_animal/hostile/gremlin/grinch))
		bagtype = "grinchbag"

	bagfill = min(2,round(contents.len/10))

	icon_state = "[bagtype][bagfill]"
	item_state = icon_state

	if (ismob(loc))
		var/mob/M = loc
		M.update_inv_hands()
		M.update_inv_back()

/obj/item/weapon/storage/backpack/cultify()
	new /obj/item/weapon/storage/backpack/cultpack(loc)
	..()

/obj/item/weapon/storage/backpack/clown
	name = "Giggles Von Honkerton"
	desc = "It's a backpack made by Honk! Co."
	icon_state = "clownpack"
	item_state = "clownpack"
	species_fit = list(VOX_SHAPED)

/obj/item/weapon/storage/backpack/medic
	name = "medical backpack"
	desc = "It's a backpack especially designed for use in a sterile environment."
	icon_state = "medicalpack"
	item_state = "medicalpack"

/obj/item/weapon/storage/backpack/security
	name = "security backpack"
	desc = "It's a very robust backpack."
	icon_state = "securitypack"
	item_state = "securitypack"
	species_fit = list(VOX_SHAPED)

/obj/item/weapon/storage/backpack/captain
	name = "captain's backpack"
	desc = "It's a special backpack made exclusively for Nanotrasen officers."
	icon_state = "captainpack"
	item_state = "captainpack"
	species_fit = list(VOX_SHAPED)

/obj/item/weapon/storage/backpack/industrial
	name = "industrial backpack"
	desc = "It's a tough backpack for the daily grind of station life."
	icon_state = "engiepack"
	item_state = "engiepack"

/*
 * Satchel Types
 */

/obj/item/weapon/storage/backpack/satchel
	name = "leather satchel"
	desc = "It's a very fancy satchel made with fine leather."
	icon_state = "satchel"
	item_state = "satchel"
	species_fit = list(VOX_SHAPED)

/obj/item/weapon/storage/backpack/satchel/withwallet/New()
	..()
	new /obj/item/weapon/storage/wallet/random( src )

/obj/item/weapon/storage/backpack/satchel_norm
	name = "satchel"
	desc = "A trendy looking satchel."
	icon_state = "satchel-norm"
	species_fit = list(VOX_SHAPED)

/obj/item/weapon/storage/backpack/satchel_eng
	name = "industrial satchel"
	desc = "A tough satchel with extra pockets."
	icon_state = "satchel-eng"
	item_state = "engiepack"
	species_fit = list(VOX_SHAPED)

/obj/item/weapon/storage/backpack/satchel_med
	name = "medical satchel"
	desc = "A sterile satchel used in medical departments."
	icon_state = "satchel-med"
	item_state = "medicalpack"
	species_fit = list(VOX_SHAPED)

/obj/item/weapon/storage/backpack/satchel_vir
	name = "virologist satchel"
	desc = "A sterile satchel with virologist colours."
	icon_state = "satchel-vir"
	species_fit = list(VOX_SHAPED)

/obj/item/weapon/storage/backpack/satchel_chem
	name = "chemist satchel"
	desc = "A sterile satchel with chemist colours."
	icon_state = "satchel-chem"
	species_fit = list(VOX_SHAPED)

/obj/item/weapon/storage/backpack/satchel_gen
	name = "geneticist satchel"
	desc = "A sterile satchel with geneticist colours."
	icon_state = "satchel-gen"
	species_fit = list(VOX_SHAPED)

/obj/item/weapon/storage/backpack/satchel_tox
	name = "scientist satchel"
	desc = "Useful for holding research materials."
	icon_state = "satchel-tox"
	species_fit = list(VOX_SHAPED)

/obj/item/weapon/storage/backpack/satchel_sec
	name = "security satchel"
	desc = "A robust satchel for security related needs."
	icon_state = "satchel-sec"
	item_state = "securitypack"
	species_fit = list(VOX_SHAPED)

/obj/item/weapon/storage/backpack/satchel_hyd
	name = "hydroponics satchel"
	desc = "A green satchel for plant related work."
	icon_state = "satchel_hyd"

/obj/item/weapon/storage/backpack/satchel_cap
	name = "captain's satchel"
	desc = "An exclusive satchel for Nanotrasen officers."
	icon_state = "satchel-cap"
	item_state = "captainpack"
	species_fit = list(VOX_SHAPED)

/*
 * Messenger Bags
 */

/obj/item/weapon/storage/backpack/messenger
	name = "messenger bag"
	desc = "A sturdy backpack worn over one shoulder."
	icon_state = "courierbag"
	species_fit = list(VOX_SHAPED)

/obj/item/weapon/storage/backpack/messenger/chem
	name = "chemistry messenger bag"
	desc = "A serile backpack worn over one shoulder.  This one is in Chemsitry colors."
	icon_state = "courierbagchem"

/obj/item/weapon/storage/backpack/messenger/med
	name = "medical messenger bag"
	desc = "A sterile backpack worn over one shoulder used in medical departments."
	icon_state = "courierbagmed"

/obj/item/weapon/storage/backpack/messenger/viro
	name = "virology messenger bag"
	desc = "A sterile backpack worn over one shoulder.  This one is in Virology colors."
	icon_state = "courierbagviro"

/obj/item/weapon/storage/backpack/messenger/tox
	name = "research messenger bag"
	desc = "A backpack worn over one shoulder.  Useful for holding science materials."
	icon_state = "courierbagtox"

/obj/item/weapon/storage/backpack/messenger/com
	name = "captain's messenger bag"
	desc = "A special backpack worn over one shoulder.  This one is made specifically for officers."
	icon_state = "courierbagcom"

/obj/item/weapon/storage/backpack/messenger/engi
	name = "engineering messenger bag"
	icon_state = "courierbagengi"

/obj/item/weapon/storage/backpack/messenger/hyd
	name = "hydroponics messenger bag"
	desc = "A backpack worn over one shoulder.  This one is designed for plant-related work."
	icon_state = "courierbaghyd"

/obj/item/weapon/storage/backpack/messenger/sec
	name = "security messenger bag"
	desc = "A tactical backpack worn over one shoulder. This one is in Security colors."
	icon_state = "courierbagsec"

/obj/item/weapon/storage/backpack/messenger/black
	name = "black messenger bag"
	desc = "For the freerunning pizza delivery hacker on the go."
	icon_state = "courierbagblack"

/obj/item/weapon/storage/backpack/clownpackpsyche
	name = "Giggles Neon Honkerton"
	desc = "It's a backpack made by Honk! Co."
	icon_state = "clownpackpsyche"
	item_state = "clownpackpsyche"
