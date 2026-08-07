class_name ClassLibraryFactoryBaseline
extends RefCounted

## Fresh player units from code factories — no class_library_data.json overrides.
const LancerFactoryScript := preload("res://core/factory/classes/lancer_factory.gd")
const ArcherFactoryScript := preload("res://core/factory/classes/archer_factory.gd")


static func build_all_player_units() -> Dictionary:
	var axe := DataLibrary._make_weapon(&"iron_axe", "Iron Axe")
	var sword := DataLibrary._make_weapon(&"iron_sword", "Iron Sword")
	var lance := DataLibrary._make_weapon(&"iron_lance", "Iron Lance")
	var bow := DataLibrary._make_weapon(&"iron_bow", "Iron Bow")
	var staff := DataLibrary._make_weapon(&"wooden_staff", "Wooden Staff")
	var fist := DataLibrary._make_weapon(&"wrap", "Hand Wraps")
	var gun := DataLibrary._make_weapon(&"flintlock", "Flintlock")
	return {
		"knight": KnightFactory.build(axe),
		"bruiser": BruiserFactory.build(axe),
		"lancer": LancerFactoryScript.build(lance),
		"archer": _archer(bow),
		"mage": _mage(staff),
		"cleric": _cleric(staff),
		"assassin": _assassin(sword),
		"mercenary": _mercenary(sword),
		"gryphon": _gryphon(lance),
		"monk": _monk(fist),
		"engineer": _engineer(gun),
		"shaman": _shaman(staff),
		"paladin": _paladin(sword),
	}


static func collect_unit_overrides() -> Dictionary:
	var units: Dictionary = {}
	for unit_key: Variant in build_all_player_units().keys():
		var unit: UnitData = build_all_player_units()[unit_key] as UnitData
		if unit != null:
			units[String(unit_key)] = ClassLibrarySchema.unit_to_dict(unit)
	return units


static func _archer(bow: WeaponData) -> UnitData:
	return ArcherFactoryScript.build(bow)


static func _mage(staff: WeaponData) -> UnitData:
	var p := DataLibrary._make_passive(&"focus", "Focus", "More magic damage.")
	var fireball := DataLibrary._make_ability(&"mage_fireball", "Fireball", 3, [DataLibrary._effect(GameEnums.EffectType.DAMAGE, 3)], 1, GameEnums.StatType.MAGICAL)
	var swap := DataLibrary._make_movement_ability(&"mage_swap", "Phase Swap", 2, [DataLibrary._effect(GameEnums.EffectType.SWAP, 0)], 2)
	return DataLibrary._make_unit_data(&"mage", "Mage", 2, 3, 1, [fireball, swap], null, GameEnums.MovementType.WALK, 0, 5, 1, staff, [p])


static func _cleric(staff: WeaponData) -> UnitData:
	var p := DataLibrary._make_passive(&"blessing", "Blessing", "Heals adjacent allies.")
	var blessing := DataLibrary._make_ability(&"cleric_blessing", "Divine Shield", 2, [DataLibrary._effect(GameEnums.EffectType.ARMOR_UP, 2)], 1)
	var pull := DataLibrary._make_movement_ability(&"cleric_pull", "Rescue Pull", 2, [DataLibrary._effect(GameEnums.EffectType.PULL, 1)], 2)
	return DataLibrary._make_unit_data(&"cleric", "Cleric", 3, 3, 1, [blessing, pull], null, GameEnums.MovementType.WALK, 0, 3, 2, staff, [p])


static func _assassin(sword: WeaponData) -> UnitData:
	var p := DataLibrary._make_passive(&"lethal", "Lethal", "Backstabs do extra damage.")
	var execute := DataLibrary._make_ability(&"assassin_execute", "Assassinate", 1, [DataLibrary._effect(GameEnums.EffectType.DAMAGE, 3)], 1, GameEnums.StatType.PHYSICAL)
	var swap := DataLibrary._make_movement_ability(&"assassin_swap", "Shadow Swap", 1, [DataLibrary._effect(GameEnums.EffectType.SWAP, 0)], 1)
	return DataLibrary._make_unit_data(&"assassin", "Assassin", 3, 4, 1, [execute, swap], null, GameEnums.MovementType.WALK, 4, 0, 1, sword, [p])


static func _mercenary(sword: WeaponData) -> UnitData:
	var p := DataLibrary._make_passive(&"veteran", "Veteran", "Reliable criticals.")
	var rend := DataLibrary._make_ability(&"merc_rend", "Rend", 1, [DataLibrary._effect(GameEnums.EffectType.DAMAGE, 2)], 1, GameEnums.StatType.PHYSICAL)
	var kick := DataLibrary._make_movement_ability(&"merc_kick", "Boot Kick", 1, [DataLibrary._effect(GameEnums.EffectType.PUSH, 1)], 1)
	return DataLibrary._make_unit_data(&"mercenary", "Mercenary", 4, 4, 1, [rend, kick], null, GameEnums.MovementType.WALK, 4, 0, 3, sword, [p])


static func _gryphon(lance: WeaponData) -> UnitData:
	var p := DataLibrary._make_passive(&"air_superiority", "Air Superiority", "Evades ground attacks.")
	var swoop := DataLibrary._make_ability(&"gryphon_swoop", "Swoop Attack", 2, [DataLibrary._effect(GameEnums.EffectType.DAMAGE, 2)], 1, GameEnums.StatType.PHYSICAL)
	var shove := DataLibrary._make_movement_ability(&"gryphon_shove", "Wing Buffet", 2, [DataLibrary._effect(GameEnums.EffectType.PUSH, 1)], 2)
	return DataLibrary._make_unit_data(&"gryphon", "Gryphon Rider", 4, 5, 1, [swoop, shove], null, GameEnums.MovementType.FLY, 3, 0, 2, lance, [p])


static func _monk(fist: WeaponData) -> UnitData:
	var p := DataLibrary._make_passive(&"flurry", "Flurry", "Multiple quick attacks.")
	var palm := DataLibrary._make_ability(&"monk_palm", "Palm Strike", 1, [DataLibrary._effect(GameEnums.EffectType.DAMAGE, 2), DataLibrary._effect(GameEnums.EffectType.PUSH, 1)], 1, GameEnums.StatType.PHYSICAL)
	var swap := DataLibrary._make_movement_ability(&"monk_swap", "Vault Swap", 1, [DataLibrary._effect(GameEnums.EffectType.SWAP, 0)], 1)
	return DataLibrary._make_unit_data(&"monk", "Monk", 4, 4, 1, [palm, swap], null, GameEnums.MovementType.WALK, 3, 1, 3, fist, [p])


static func _engineer(gun: WeaponData) -> UnitData:
	var p := DataLibrary._make_passive(&"shrapnel", "Shrapnel", "Explosions deal more damage.")
	var grenade := DataLibrary._make_ability(&"eng_grenade", "Grenade", 3, [DataLibrary._effect(GameEnums.EffectType.RANGED_EXPLODE, 2)], 1)
	var pull := DataLibrary._make_ability(&"eng_pull", "Grappling Hook", 3, [DataLibrary._effect(GameEnums.EffectType.PULL, 1)], 0)
	return DataLibrary._make_unit_data(&"engineer", "Engineer", 3, 3, 1, [grenade, pull], null, GameEnums.MovementType.WALK, 2, 0, 3, gun, [p])


static func _shaman(staff: WeaponData) -> UnitData:
	var p := DataLibrary._make_passive(&"curse", "Curse", "Enemies take more damage.")
	var ward := DataLibrary._make_ability(&"shaman_ward", "Earth Ward", 3, [DataLibrary._effect(GameEnums.EffectType.ARMOR_UP, 2)], 1)
	var shove := DataLibrary._make_ability(&"shaman_shove", "Gale Force", 2, [DataLibrary._effect(GameEnums.EffectType.PUSH, 1)], 0)
	return DataLibrary._make_unit_data(&"shaman", "Shaman", 3, 3, 1, [ward, shove], null, GameEnums.MovementType.WALK, 0, 4, 2, staff, [p])


static func _paladin(sword: WeaponData) -> UnitData:
	var p := DataLibrary._make_passive(&"holy_shield", "Holy Shield", "Resists magic.")
	var heal := DataLibrary._make_ability(&"paladin_heal", "Lay on Hands", 1, [DataLibrary._effect(GameEnums.EffectType.HEAL, 2)], 1, GameEnums.StatType.MAGICAL)
	var swap := DataLibrary._make_movement_ability(&"paladin_swap", "Holy Swap", 2, [DataLibrary._effect(GameEnums.EffectType.SWAP, 0)], 1)
	return DataLibrary._make_unit_data(&"paladin", "Paladin", 5, 3, 1, [heal, swap], null, GameEnums.MovementType.WALK, 3, 2, 4, sword, [p])
