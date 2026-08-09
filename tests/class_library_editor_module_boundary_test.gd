class_name ClassLibraryEditorModuleBoundaryTest
extends RefCounted

const EDITOR_PATH: String = "res://ui/class_library_editor.gd"
const SCHEMA_PATH: String = "res://ui/class_library_schema.gd"
const OVERRIDES_PATH: String = "res://data/class_library_data.json"
const LEGACY_FIXTURE_PATH: String = "user://class_library_legacy_read_test.json"


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
	var schema_source: String = FileAccess.get_file_as_string(SCHEMA_PATH)
	if not schema_source.contains("return migrate_editor_save_to_modules(parsed as Dictionary)"):
		failures.append("class library save reader bypasses module migration")
	_assert_saved_abilities_are_module_first(failures)
	_assert_runtime_legacy_read_migrates(failures)
	_assert_non_status_modules_clear_status_type(failures)


static func _assert_non_status_modules_clear_status_type(failures: Array[String]) -> void:
	var damage_module := AbilityModule.new()
	damage_module.primary_type = GameEnums.EffectType.DAMAGE
	damage_module.status_type = GameEnums.StatusType.STAT_BUFF_STR
	AbilityModuleBridge.normalize_module_status_fields(damage_module)
	if damage_module.status_type != GameEnums.StatusType.NONE:
		failures.append("DAMAGE module status_type should normalize to NONE")
	var compiled: Array[EffectData] = AbilityModuleBridge.compile_module_to_effects(damage_module)
	if compiled.is_empty():
		failures.append("DAMAGE module compile produced no effects")
	elif compiled[0].status_type != GameEnums.StatusType.NONE:
		failures.append("DAMAGE compiled effect should not carry a status_type")


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


static func _assert_runtime_legacy_read_migrates(failures: Array[String]) -> void:
	var legacy_payload: Dictionary = {
		"units": {
			"legacy_fixture": {
				"abilities": {
					"legacy_strike": {
						"display_name": "Legacy Strike",
						"effects": [{
							"type": GameEnums.EffectType.DAMAGE,
							"amount": 3,
						}],
						"kind": GameEnums.AbilityKind.CLASS_SKILL,
						"range_tiles": 2,
						"targeting_flags": GameEnums.TargetingFlags.ENEMY,
						"targeting_mode": GameEnums.TargetingMode.ENEMY_UNIT,
					},
				},
			},
		},
	}
	var file := FileAccess.open(LEGACY_FIXTURE_PATH, FileAccess.WRITE)
	if file == null:
		failures.append("could not create runtime legacy read fixture")
		return
	file.store_string(JSON.stringify(legacy_payload))
	file.close()
	var migrated: Dictionary = ClassLibrarySchema.read_editor_save_from_path(LEGACY_FIXTURE_PATH)
	var ability_data: Dictionary = (
		((migrated.get("units", {}) as Dictionary).get("legacy_fixture", {}) as Dictionary)
		.get("abilities", {})
		.get("legacy_strike", {})
	)
	if not ability_data.has("modules") or ability_data.has("effects") or ability_data.has("kind"):
		failures.append("runtime legacy read did not return module-first payload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_FIXTURE_PATH))
