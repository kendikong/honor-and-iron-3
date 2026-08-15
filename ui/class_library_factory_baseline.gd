class_name ClassLibraryFactoryBaseline
extends RefCounted

## Fresh player units from Bible class factories — no class_library_data.json overrides.


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
		"mercenary": MercenaryFactory.build(sword),
		"rogue": RogueFactory.build(sword),
		"monk": MonkFactory.build(fist),
		"beast_rider": BeastRiderFactory.build(lance),
		"mage": MageFactory.build(staff),
		"archer": ArcherFactory.build(bow),
		"cleric": ClericFactory.build(staff),
		"shaman": ShamanFactory.build(staff),
		"lancer": LancerFactory.build(lance),
		"engineer": EngineerFactory.build(gun),
	}


static func collect_unit_overrides() -> Dictionary:
	var units: Dictionary = {}
	var built: Dictionary = build_all_player_units()
	for unit_key: Variant in built.keys():
		var unit: UnitData = built[unit_key] as UnitData
		if unit != null:
			units[String(unit_key)] = ClassLibrarySchema.unit_to_dict(unit)
	return units
