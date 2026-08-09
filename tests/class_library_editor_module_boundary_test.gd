class_name ClassLibraryEditorModuleBoundaryTest
extends RefCounted

const EDITOR_PATH: String = "res://ui/class_library_editor.gd"
const OVERRIDES_PATH: String = "res://data/class_library_data.json"


static func run_all(failures: Array[String]) -> void:
	var source: String = FileAccess.get_file_as_string(EDITOR_PATH)
	if source.is_empty():
		failures.append("class library editor source could not be read")
		return
	for forbidden: String in [
		"ability.kind =",
		"ability.is_movement_skill =",
		"ability.effects.clear()",
		"ability.upgraded_effects.clear()",
	]:
		if source.contains(forbidden):
			failures.append("class library editor still writes legacy field: %s" % forbidden)
	_assert_saved_abilities_are_module_first(failures)


static func _assert_saved_abilities_are_module_first(failures: Array[String]) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OVERRIDES_PATH))
	if not parsed is Dictionary:
		failures.append("class library override JSON could not be read")
		return
	var units_value: Variant = (parsed as Dictionary).get("units", {})
	if not units_value is Dictionary:
		return
	for unit_key: Variant in (units_value as Dictionary).keys():
		var unit_value: Variant = (units_value as Dictionary)[unit_key]
		if not unit_value is Dictionary:
			continue
		var abilities_value: Variant = (unit_value as Dictionary).get("abilities", {})
		if not abilities_value is Dictionary:
			continue
		for ability_key: Variant in (abilities_value as Dictionary).keys():
			var payload: Variant = (abilities_value as Dictionary)[ability_key]
			if not payload is Dictionary:
				continue
			var ability_data: Dictionary = payload
			if not ability_data.has("modules"):
				failures.append("%s/%s is missing module-first payload" % [unit_key, ability_key])
			for legacy_key: String in [
				"effects",
				"upgraded_effects",
				"kind",
				"is_movement_skill",
				"range_tiles",
				"targeting_mode",
			]:
				if ability_data.has(legacy_key):
					failures.append("%s/%s emitted legacy key %s" % [unit_key, ability_key, legacy_key])
