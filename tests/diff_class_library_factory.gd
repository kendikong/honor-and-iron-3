extends SceneTree

## One-shot: factory-coded abilities vs class_library_data.json overrides.
## Run: godot --headless --path . --script res://tests/diff_class_library_factory.gd
const LancerFactoryScript := preload("res://core/factory/classes/lancer_factory.gd")
const ArcherFactoryScript := preload("res://core/factory/classes/archer_factory.gd")
const MercenaryFactoryScript := preload("res://core/factory/classes/mercenary_factory.gd")

const EFFECT_NAMES: PackedStringArray = [
	"DAMAGE", "PUSH", "PULL", "SWAP", "HEAL", "ARMOR_UP", "EXPLODE", "SPAWN",
	"ADD_STATUS", "ADD_STATUS_SELF", "REMOVE_STATUS", "DAMAGE_SELF", "RANGED_EXPLODE",
	"CLEANSE", "PURGE", "DASH", "DESTROY_OBSTACLE", "TELEPORT_CASTER", "CHANGE_TERRAIN",
	"REFUND_AP_ON_CC", "TRAMPLE", "BULLDOZE", "MOVE", "PUSH_STAGGER_ON_COLLISION",
	"PULL_VULNERABLE_ON_ADJACENT", "PUSH_CHAIN_COLLISION", "MOVE_INTO_AND_PUSH", "THROW_BEHIND",
]


func _init() -> void:
	var json_units: Dictionary = ClassLibrarySchema.read_editor_save().get("units", {})
	var factory_units: Dictionary = _build_factory_units()
	var lines: PackedStringArray = []
	var diff_count: int = 0
	var missing_json: int = 0
	var missing_factory: int = 0
	const COL := 42

	for unit_id: String in factory_units.keys():
		var unit: UnitData = factory_units[unit_id] as UnitData
		if unit == null:
			continue
		var json_abilities: Dictionary = {}
		if json_units.has(unit_id):
			var unit_payload: Variant = json_units[unit_id]
			if typeof(unit_payload) == TYPE_DICTIONARY:
				json_abilities = (unit_payload as Dictionary).get("abilities", {}) as Dictionary
		for ability: AbilityData in unit.abilities:
			if ability == null:
				continue
			var ab_id := String(ability.id)
			var factory_dict: Dictionary = ClassLibrarySchema.ability_to_dict(ability)
			if not json_abilities.has(ab_id):
				missing_json += 1
				lines.append("[MISSING JSON] %s / %s" % [unit_id, ab_id])
				continue
			var json_dict: Dictionary = json_abilities[ab_id] as Dictionary
			var ab_diffs: Array = _diff_ability_rows(factory_dict, json_dict)
			if ab_diffs.is_empty():
				continue
			diff_count += 1
			lines.append("")
			lines.append("=" .repeat(88))
			lines.append("%s — %s" % [factory_dict.get("display_name", ab_id), ab_id])
			lines.append("=" .repeat(88))
			lines.append(_pad_right("FIELD", COL) + " | " + _pad_right("CODE (factory)", COL) + " | " + "LIBRARY (json)")
			lines.append("-" .repeat(88))
			for row: Dictionary in ab_diffs:
				lines.append(
					_pad_right(String(row.get("field", "")), COL)
					+ " | "
					+ _pad_right(String(row.get("factory", "")), COL)
					+ " | "
					+ String(row.get("json", ""))
				)

	for unit_id: String in json_units.keys():
		var unit_payload: Variant = json_units[unit_id]
		if typeof(unit_payload) != TYPE_DICTIONARY:
			continue
		var json_abilities: Dictionary = (unit_payload as Dictionary).get("abilities", {}) as Dictionary
		if not factory_units.has(unit_id):
			for ab_id: String in json_abilities.keys():
				missing_factory += 1
				lines.append("[JSON ONLY] %s / %s" % [unit_id, ab_id])

	lines.insert(0, "CODE = bruiser_factory.gd / knight_factory.gd etc.   |   LIBRARY = class_library_data.json (what game loads)")
	lines.insert(1, "Units: %d   Abilities with diffs: %d   Missing JSON: %d   JSON-only: %d" % [
		factory_units.size(), diff_count, missing_json, missing_factory,
	])

	var out_path := "res://qa_class_library_factory_diff.txt"
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file != null:
		for line: String in lines:
			file.store_line(line)
		file.close()
	for line: String in lines:
		print(line)
	quit()


static func _build_factory_units() -> Dictionary:
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
		"mercenary": MercenaryFactoryScript.build(sword),
		"gryphon": _gryphon(lance),
		"monk": _monk(fist),
		"engineer": _engineer(gun),
		"shaman": _shaman(staff),
	}


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


static func _values_equal(a: Variant, b: Variant) -> bool:
	if a == b:
		return true
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	return str(a) == str(b)


static func _pad_right(text: String, width: int) -> String:
	if text.length() >= width:
		return text.substr(0, width - 1) + "…"
	return text + " ".repeat(width - text.length())


static func _diff_ability_rows(factory: Dictionary, json: Dictionary) -> Array:
	var out: Array = []
	var scalar_keys: PackedStringArray = [
		"display_name", "action_point_cost", "movement_point_cost", "range_tiles",
		"target_shape", "target_shape_size", "targeting_mode", "targeting_flags",
		"scaling_stat", "upgrade_description", "upgraded_range_tiles",
		"upgraded_movement_point_cost",
	]
	for key: String in scalar_keys:
		if not json.has(key) and not factory.has(key):
			continue
		var f: Variant = factory.get(key, "—")
		var j: Variant = json.get(key, "—")
		if not _values_equal(f, j):
			out.append({"field": key, "factory": str(f), "json": str(j)})
	var fe: String = _effects_summary(factory.get("effects", []))
	var je: String = _effects_summary(json.get("effects", []))
	if fe != je:
		out.append({"field": "effects", "factory": fe if fe != "" else "(none)", "json": je if je != "" else "(none)"})
	var fue: String = _effects_summary(factory.get("upgraded_effects", []))
	var jue: String = _effects_summary(json.get("upgraded_effects", []))
	if fue != jue:
		out.append({
			"field": "upgraded_effects",
			"factory": fue if fue != "" else "(none)",
			"json": jue if jue != "" else "(none)",
		})
	return out


static func _effects_summary(effects: Variant) -> String:
	if typeof(effects) != TYPE_ARRAY:
		return ""
	var parts: PackedStringArray = []
	for entry: Variant in effects as Array:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry as Dictionary
		var t: int = int(d.get("type", -1))
		var name := EFFECT_NAMES[t] if t >= 0 and t < EFFECT_NAMES.size() else "TYPE_%d" % t
		var amount: int = int(d.get("amount", 0))
		var mods: Dictionary = d.get("modifiers", {}) as Dictionary
		var mod_keys: PackedStringArray = []
		for mk: Variant in mods.keys():
			mod_keys.append(String(mk))
		mod_keys.sort()
		var mod_txt := ""
		if not mod_keys.is_empty():
			mod_txt = " mods{%s}" % ", ".join(mod_keys)
		parts.append("%s %d%s" % [name, amount, mod_txt])
	return " | ".join(parts)
