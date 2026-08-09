extends SceneTree

const KEEP_LIBRARY_ABILITIES: Dictionary = {
	"knight": ["knight_bowling_charge"],
}


const FactoryBaseline = preload("res://ui/class_library_factory_baseline.gd")


func _init() -> void:
	var existing: Dictionary = ClassLibrarySchema.read_editor_save()
	var factory_units: Dictionary = FactoryBaseline.collect_unit_overrides()
	var merged_units: Dictionary = factory_units.duplicate(true)
	for unit_id: String in KEEP_LIBRARY_ABILITIES.keys():
		if not existing.get("units", {}).has(unit_id):
			continue
		var old_unit: Dictionary = existing["units"][unit_id]
		if typeof(old_unit) != TYPE_DICTIONARY:
			continue
		var old_abilities: Dictionary = (old_unit as Dictionary).get("abilities", {})
		if typeof(old_abilities) != TYPE_DICTIONARY:
			continue
		if not merged_units.has(unit_id):
			continue
		var new_unit: Dictionary = merged_units[unit_id] as Dictionary
		var new_abilities: Dictionary = new_unit.get("abilities", {}).duplicate(true)
		for ab_id: String in KEEP_LIBRARY_ABILITIES[unit_id]:
			if old_abilities.has(ab_id):
				new_abilities[ab_id] = old_abilities[ab_id]
		new_unit["abilities"] = new_abilities
		merged_units[unit_id] = new_unit
	var out: Dictionary = existing.duplicate(true)
	out["units"] = merged_units
	if ClassLibrarySchema.write_editor_save(out):
		print("Synced class_library_data.json from factory (kept library: %s)" % str(KEEP_LIBRARY_ABILITIES))
	else:
		push_error("Failed to write class_library_data.json")
	quit()
