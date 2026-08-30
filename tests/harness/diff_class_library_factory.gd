extends SceneTree

## One-shot: factory-coded abilities vs class_library_data.json overrides.
## Run: godot --headless --path . --script res://tests/diff_class_library_factory.gd
const FactoryBaseline = preload("res://ui/class_library_factory_baseline.gd")

const EFFECT_NAMES: PackedStringArray = [
	"DAMAGE", "PUSH", "PULL", "SWAP", "HEAL", "ARMOR_UP", "EXPLODE", "SPAWN",
	"ADD_STATUS", "ADD_STATUS_SELF", "REMOVE_STATUS", "DAMAGE_SELF", "RANGED_EXPLODE",
	"CLEANSE", "PURGE", "DASH", "DESTROY_OBSTACLE", "TELEPORT_CASTER", "CHANGE_TERRAIN",
	"REFUND_AP_ON_CC", "TRAMPLE", "BULLDOZE", "MOVE", "PUSH_STAGGER_ON_COLLISION",
	"PULL_VULNERABLE_ON_ADJACENT", "PUSH_CHAIN_COLLISION", "MOVE_INTO_AND_PUSH", "THROW_BEHIND",
]


func _init() -> void:
	var json_units: Dictionary = ClassLibrarySchema.read_editor_save().get("units", {})
	var factory_units: Dictionary = FactoryBaseline.build_all_player_units()
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
