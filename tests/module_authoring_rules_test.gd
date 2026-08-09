class_name ModuleAuthoringRulesTest
extends RefCounted

const ModuleAuthoringRules = preload("res://data/definitions/module_authoring_rules.gd")

static func run_all(failures: Array[String]) -> void:
	_test_move_clears_scaling_and_los(failures)
	_test_pre_move_excludes_phase_options(failures)
	_test_self_status_clears_range(failures)
	_test_invalid_gate_reset(failures)
	_test_layer_condition_filter(failures)
	_test_primary_as_effect_strips_junk(failures)


static func _test_move_clears_scaling_and_los(failures: Array[String]) -> void:
	var module := AbilityModule.new()
	module.primary_type = GameEnums.EffectType.MOVE
	module.scaling_stat = GameEnums.StatType.PHYSICAL
	module.requires_los = true
	module.motion_mode = GameEnums.MotionMode.TO_EMPTY_TILE
	AbilityModuleBridge.normalize_module_authoring_fields(module)
	if module.scaling_stat != GameEnums.StatType.NONE:
		failures.append("MOVE should clear scaling_stat")
	if module.requires_los:
		failures.append("MOVE should clear requires_los")


static func _test_pre_move_excludes_phase_options(failures: Array[String]) -> void:
	var excluded: PackedStringArray = ModuleAuthoringRules.excluded_module_phases(
		GameEnums.PlannerGroup.PRE_MOVE
	)
	if not excluded.has("ON_PRE") or not excluded.has("ON_POST"):
		failures.append("PRE_MOVE should exclude ON_PRE and ON_POST phases")


static func _test_self_status_clears_range(failures: Array[String]) -> void:
	var module := AbilityModule.new()
	module.primary_type = GameEnums.EffectType.ADD_STATUS_SELF
	module.min_range = 2
	module.max_range = 4
	AbilityModuleBridge.normalize_module_authoring_fields(module)
	if module.min_range != 0 or module.max_range != 0:
		failures.append("ADD_STATUS_SELF should clear range fields")
	if not module.has_targeting(GameEnums.TargetingFlags.SELF):
		failures.append("ADD_STATUS_SELF should force SELF targeting")


static func _test_invalid_gate_reset(failures: Array[String]) -> void:
	var module := AbilityModule.new()
	module.primary_type = GameEnums.EffectType.DAMAGE
	module.gate = GameEnums.ModuleGate.IF_COLLIDED
	AbilityModuleBridge.normalize_module_authoring_fields(module)
	if module.gate != GameEnums.ModuleGate.ALWAYS:
		failures.append("non-motion module should reset IF_COLLIDED gate")


static func _test_layer_condition_filter(failures: Array[String]) -> void:
	var module := AbilityModule.new()
	module.primary_type = GameEnums.EffectType.DAMAGE
	var excluded: PackedStringArray = ModuleAuthoringRules.excluded_layer_conditions(module)
	if not excluded.has("ON_LAND"):
		failures.append("DAMAGE module should exclude ON_LAND layer condition")


static func _test_primary_as_effect_strips_junk(failures: Array[String]) -> void:
	var module := AbilityModule.new()
	module.primary_type = GameEnums.EffectType.MOVE
	module.scaling_stat = GameEnums.StatType.PHYSICAL
	module.spawn_unit_id = &"foo"
	module.bonus_if_adjacent_at_cast = 2
	var eff: EffectData = module.primary_as_effect()
	if eff.scaling_stat != GameEnums.StatType.NONE:
		failures.append("MOVE primary_as_effect should not copy scaling_stat")
	if eff.spawn_unit_id != StringName():
		failures.append("MOVE primary_as_effect should not copy spawn_unit_id")
	if eff.bonus_if_adjacent_at_cast != 0:
		failures.append("MOVE primary_as_effect should not copy adjacent bonus")
