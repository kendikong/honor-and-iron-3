extends RefCounted

## Default per-class LPC visual overrides. Constants live on LpcConstants for parser safety.

static func build() -> Dictionary:
	return {
		"knight": {
			"forced_items": {
				"weapon": "weapon_sword_longsword",
				"shield": "shield_heater_revised_wood",
				"armour": "torso_armour_plate",
				"legs": "legs_armour",
				"shoes": "feet_armour",
			},
			"slot_fill": {
				"armour": 1.0,
				"shield": 1.0,
				"weapon": 1.0,
			},
		},
		"paladin": {
			"forced_items": {
				"weapon": "weapon_sword_longsword",
				"shield": "shield_crusader",
				"armour": "torso_armour_legion",
				"clothes": "torso_clothes_robe",
			},
			"slot_fill": {
				"shield": 1.0,
				"weapon": 1.0,
				"armour": 0.85,
			},
		},
		"bruiser": {
			"forced_items": {
				"weapon": "weapon_blunt_waraxe",
				"armour": "torso_armour_leather",
			},
			"slot_fill": {
				"weapon": 1.0,
				"armour": 0.7,
			},
		},
		"cavalier": {
			"forced_items": {
				"weapon": "weapon_polearm_spear",
				"armour": "torso_armour_legion",
				"shoes": "feet_boots_revised",
			},
			"slot_fill": {
				"weapon": 1.0,
				"armour": 0.75,
			},
		},
		"archer": {
			"forced_items": {
				"weapon": "weapon_ranged_crossbow",
				"quiver": "quiver",
				"clothes": "torso_clothes_longsleeve",
			},
			"slot_fill": {
				"weapon": 1.0,
				"quiver": 1.0,
			},
		},
		"mage": {
			"forced_items": {
				"weapon": "weapon_magic_wand",
				"clothes": "torso_clothes_robe",
				"hat": "hat_magic_wizard",
			},
			"slot_fill": {
				"weapon": 1.0,
				"clothes": 0.9,
			},
		},
		"cleric": {
			"forced_items": {
				"weapon": "weapon_magic_simple",
				"clothes": "torso_clothes_robe",
			},
			"slot_fill": {
				"weapon": 1.0,
				"clothes": 0.85,
			},
		},
		"assassin": {
			"forced_items": {
				"weapon": "weapon_sword_dagger",
				"clothes": "torso_clothes_shortsleeve",
			},
			"slot_fill": {
				"weapon": 1.0,
			},
		},
		"mercenary": {
			"forced_items": {
				"weapon": "weapon_sword_saber",
				"armour": "torso_armour_leather",
			},
			"slot_fill": {
				"weapon": 1.0,
				"armour": 0.6,
			},
		},
		"gryphon": {
			"forced_items": {
				"weapon": "weapon_polearm_spear",
				"wings": "wings_feathered",
			},
			"slot_fill": {
				"weapon": 1.0,
				"wings": 1.0,
			},
		},
		"monk": {
			"forced_items": {
				"clothes": "torso_clothes_shortsleeve",
				"shoes": "feet_socks_tabi",
				"sash": "belt_obi",
			},
			"slot_fill": {
				"clothes": 0.9,
				"shoes": 0.9,
			},
		},
		"engineer": {
			"forced_items": {
				"weapon": "weapon_ranged_crossbow",
				"clothes": "torso_clothes_longsleeve_laced",
				"backpack": "backpack",
			},
			"slot_fill": {
				"weapon": 1.0,
				"backpack": 0.8,
			},
		},
		"shaman": {
			"forced_items": {
				"weapon": "weapon_magic_gnarled",
				"tail": "tail_lizard",
				"horns": "head_horns_curled",
			},
			"slot_fill": {
				"weapon": 1.0,
				"tail": 0.7,
			},
		},
	}
