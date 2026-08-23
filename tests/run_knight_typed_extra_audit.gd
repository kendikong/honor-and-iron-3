extends SceneTree

func _initialize() -> void:
	DataLibrary.reset_cache()
	var knight: UnitData = DataLibrary.get_unit(&"knight")
	for ability: AbilityData in knight.abilities:
		if ability == null:
			continue
		var count: int = 0
		for module: AbilityModule in ability.modules:
			count += ModuleAuthoringRules.typed_extra_active_count(module)
		for module: AbilityModule in ability.upgraded_modules:
			count += ModuleAuthoringRules.typed_extra_active_count(module)
		print("%s: typed_extras=%d" % [String(ability.id), count])
	quit(0)
