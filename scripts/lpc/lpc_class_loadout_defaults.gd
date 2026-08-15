extends RefCounted

## Default per-class LPC visual overrides. Constants live on LpcConstants for parser safety.
## slot_fill 1.0 = always that item. slot_fill 0.5 = 50% that item, otherwise leave the slot empty.
## Do not force clothes/legs/shoes at 50% — a miss would skip the slot and look unfinished.

static func build() -> Dictionary:
	return {
		"knight": {
			"forced_items": {
				"weapon": "weapon_sword_longsword",
				"shield": "shield_heater_revised_wood",
				"armour": "torso_armour_plate",
				"hat": "hat_helmet_greathelm",
				"shoulders": "shoulders_pauldrons",
				"cape": "cape_solid",
			},
			"slot_fill": {
				"weapon": 1.0,
				"shield": 1.0,
				"armour": 0.5,
				"hat": 0.5,
				"shoulders": 0.5,
				"cape": 0.5,
			},
		},
		"bruiser": {
			"forced_items": {
				"weapon": "weapon_blunt_waraxe",
				"hat": "hat_helmet_barbarian",
				"bandages": "torso_bandages",
			},
			"slot_fill": {
				"weapon": 1.0,
				"hat": 0.5,
				"bandages": 0.5,
			},
		},
		"mercenary": {
			"forced_items": {
				"weapon": "weapon_sword_saber",
				"armour": "torso_armour_leather",
				"hat": "hat_cap_cavalier",
			},
			"slot_fill": {
				"weapon": 1.0,
				"armour": 0.5,
				"hat": 0.5,
			},
		},
		"rogue": {
			"forced_items": {
				"weapon": "weapon_sword_dagger",
				"hat": "hat_hood_cloth",
				"facial_mask": "facial_mask_plain",
				"cape": "cape_tattered",
			},
			"slot_fill": {
				"weapon": 1.0,
				"hat": 0.5,
				"facial_mask": 0.5,
				"cape": 0.5,
			},
		},
		"monk": {
			"forced_items": {
				"sash": "belt_obi",
				"shoes": "feet_socks_tabi",
				"headcover": "hat_headband_tied",
			},
			"slot_fill": {
				"sash": 1.0,
				"shoes": 1.0,
				"weapon": 0.0,
				"headcover": 0.5,
			},
		},
		"beast_rider": {
			"forced_items": {
				"hat": "hat_cap_leather",
				"weapon": "weapon_polearm_spear",
				"tail": "tail_wolf",
				"furry_ears": "head_ears_wolf",
			},
			"slot_fill": {
				"hat": 1.0,
				"weapon": 0.5,
				"tail": 0.5,
				"furry_ears": 0.5,
				"wings": 0.0,
			},
		},
		"mage": {
			"forced_items": {
				"weapon": "weapon_magic_wand",
				"hat": "hat_magic_wizard",
				"belt": "belt_mage",
			},
			"slot_fill": {
				"weapon": 1.0,
				"hat": 0.5,
				"belt": 0.5,
			},
		},
		"archer": {
			"forced_items": {
				"weapon": "weapon_ranged_crossbow",
				"quiver": "quiver",
				"hat": "hat_cap_leather",
			},
			"slot_fill": {
				"weapon": 1.0,
				"quiver": 1.0,
				"hat": 0.5,
			},
		},
		"cleric": {
			"forced_items": {
				"weapon": "weapon_magic_simple",
				"shield": "shield_crusader",
				"charm": "neck_amulet_cross",
				"cape": "cape_solid",
			},
			"slot_fill": {
				"weapon": 1.0,
				"shield": 0.5,
				"charm": 0.5,
				"cape": 0.5,
			},
		},
		"shaman": {
			"forced_items": {
				"weapon": "weapon_magic_gnarled",
				"horns": "head_horns_curled",
				"charm": "neck_amulet_spider",
				"hat": "hat_hood_sack_cloth",
			},
			"slot_fill": {
				"weapon": 1.0,
				"horns": 0.5,
				"charm": 0.5,
				"hat": 0.5,
			},
		},
		"lancer": {
			"forced_items": {
				"weapon": "weapon_polearm_spear",
				"armour": "torso_armour_legion",
				"hat": "hat_helmet_legion",
				"shoulders": "shoulders_legion",
			},
			"slot_fill": {
				"weapon": 1.0,
				"armour": 0.5,
				"hat": 0.5,
				"shoulders": 0.5,
			},
		},
		"engineer": {
			"forced_items": {
				"weapon": "tool_smash",
				"backpack": "backpack",
				"overalls": "torso_aprons_overalls",
			},
			"slot_fill": {
				"weapon": 1.0,
				"backpack": 0.5,
				"overalls": 0.5,
			},
		},
	}
