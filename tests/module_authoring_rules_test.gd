class_name ModuleAuthoringRulesTest
extends RefCounted

const ModuleAuthoringRules = preload("res://data/definitions/module_authoring_rules.gd")

static func _test_pre_move_forces_on_action_phase(failures: Array[String]) -> void:
	var module := AbilityModule.new()
	module.execution_phase = GameEnums.ModulePhase.ON_PRE
	AbilityModuleBridge.normalize_module_authoring_fields(
		module, GameEnums.PlannerGroup.PRE_MOVE, 0
	)
	if module.execution_phase != GameEnums.ModulePhase.ON_ACTION:
		failures.append("PRE_MOVE should force execution_phase ON_ACTION on normalize")


static func run_all(failures: Array[String]) -> void:
	_test_move_clears_scaling(failures)
	_test_l_shape_move_is_path_motion(failures)
	_test_before_damage_layers_compile_first(failures)
	_test_migrate_kill_and_landing_riders(failures)
	_test_adjacent_bonus_layer_merges_into_primary(failures)
	_test_pre_move_excludes_phase_options(failures)
	_test_pre_move_forces_on_action_phase(failures)
	_test_self_status_clears_range(failures)
	_test_invalid_gate_reset(failures)
	_test_layer_condition_filter(failures)
	_test_primary_as_effect_strips_junk(failures)
	_test_every_effect_type_has_a_primary_family(failures)
	_test_typed_extra_label_mapping(failures)
	_test_violent_collision_recast_visibility(failures)
	_test_during_bulldoze_excludes_collision_modifiers(failures)
	_test_during_bulldoze_merges_into_dash_primary(failures)
	_test_migrate_legacy_layer_bundles(failures)


static func _test_migrate_legacy_layer_bundles(failures: Array[String]) -> void:
	var module := AbilityModule.new()
	module.primary_type = GameEnums.EffectType.DAMAGE
	module.layers = [
		DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.PUSH_STAGGER_ON_COLLISION, 1)),
	]
	ModuleAuthoringRules.migrate_legacy_layer_bundles(module)
	if module.layers.size() != 1:
		failures.append("bundle migration should keep one layer")
	elif (
		module.layers[0].condition != GameEnums.LayerCondition.ON_COLLISION
		or not module.layers[0].stagger_on_collision
	):
		failures.append("PUSH_STAGGER bundle should become ON_COLLISION stagger layer")


static func _test_during_bulldoze_excludes_collision_modifiers(failures: Array[String]) -> void:
	var layer := AbilityLayer.new()
	layer.condition = GameEnums.LayerCondition.DURING
	layer.effect = EffectData.new()
	layer.effect.type = GameEnums.EffectType.BULLDOZE
	var module := AbilityModule.new()
	module.primary_type = GameEnums.EffectType.DASH
	if ModuleAuthoringRules.layer_typed_field_applies(layer, module, "stagger_on_collision"):
		failures.append("DURING BULLDOZE must not expose stagger_on_collision on same layer")
	var on_collision := ModuleAuthoringRules.new_on_collision_layer(&"stagger")
	if not ModuleAuthoringRules.layer_typed_field_applies(on_collision, module, "stagger_on_collision"):
		failures.append("ON_COLLISION layer must expose stagger_on_collision")


static func _test_typed_extra_label_mapping(failures: Array[String]) -> void:
	var mapped: String = ModuleAuthoringRules.typed_extra_property_from_label("Next Ranged Attack STR")
	if mapped != "next_ranged_attack_strength":
		failures.append("label mapping failed for Next Ranged Attack STR: %s" % mapped)
	mapped = ModuleAuthoringRules.typed_extra_property_from_label("Grapple Pass Damage")
	if mapped != "grapple_pass_through_damage":
		failures.append("label mapping failed for Grapple Pass Damage: %s" % mapped)


static func _test_violent_collision_recast_visibility(failures: Array[String]) -> void:
	var dash_plain := AbilityModule.new()
	dash_plain.primary_type = GameEnums.EffectType.DASH
	if ModuleAuthoringRules.typed_extra_field_applies(dash_plain, "violent_collision_recast"):
		failures.append("plain DASH should not show violent_collision_recast when unset")
	var dash_bulldoze := AbilityModule.new()
	dash_bulldoze.primary_type = GameEnums.EffectType.DASH
	dash_bulldoze.layers = [DataLibrary._during_bulldoze()]
	if not ModuleAuthoringRules.typed_extra_field_applies(dash_bulldoze, "violent_collision_recast"):
		failures.append("DASH + BULLDOZE should show violent_collision_recast")
	dash_bulldoze.violent_collision_recast = 0
	var dash_set := AbilityModule.new()
	dash_set.primary_type = GameEnums.EffectType.MOVE
	dash_set.violent_collision_recast = 2
	if not ModuleAuthoringRules.typed_extra_field_applies(dash_set, "violent_collision_recast"):
		failures.append("non-zero violent_collision_recast must stay visible on any module")


static func _test_move_clears_scaling(failures: Array[String]) -> void:
	var module := AbilityModule.new()
	module.primary_type = GameEnums.EffectType.MOVE
	module.scaling_stat = GameEnums.StatType.PHYSICAL
	AbilityModuleBridge.normalize_module_authoring_fields(module)
	if module.scaling_stat != GameEnums.StatType.NONE:
		failures.append("MOVE should clear scaling_stat")


static func _test_l_shape_move_is_path_motion(failures: Array[String]) -> void:
	if not GameEnums.is_path_motion(GameEnums.EffectType.L_SHAPE_MOVE):
		failures.append("L_SHAPE_MOVE should count as path motion")


static func _test_before_damage_layers_compile_first(failures: Array[String]) -> void:
	var module := AbilityModule.new()
	module.primary_type = GameEnums.EffectType.DAMAGE
	module.amount = 2
	var def_layer := AbilityLayer.new()
	def_layer.condition = GameEnums.LayerCondition.AT_RESOLUTION
	def_layer.effect = EffectData.new()
	def_layer.effect.type = GameEnums.EffectType.ADD_STATUS
	def_layer.effect.def_debuff_before_damage = 1
	module.layers = [
		DataLibrary._layer(DataLibrary._effect(GameEnums.EffectType.PUSH, 1)),
		def_layer,
	]
	var compiled: Array[EffectData] = AbilityModuleBridge.compile_module_to_effects(module)
	if compiled.size() < 3:
		failures.append("expected primary + pre/post layers in compile output")
	elif compiled[0].def_debuff_before_damage <= 0:
		failures.append("before-damage status layer must compile before DAMAGE primary")
	elif compiled[1].type != GameEnums.EffectType.DAMAGE:
		failures.append("DAMAGE primary must follow pre-primary layers")


static func _test_migrate_kill_and_landing_riders(failures: Array[String]) -> void:
	var module := AbilityModule.new()
	module.primary_type = GameEnums.EffectType.JUMP_TO_BEHIND
	module.kill_grant_ap = 1
	module.landing_adjacent_push = 2
	module.landing_adjacent_push_stagger = true
	ModuleAuthoringRules.migrate_kill_and_landing_riders_to_layers(module)
	if module.kill_grant_ap != 0 or module.landing_adjacent_push != 0:
		failures.append("migration should clear kill/landing module knobs")
	var has_on_kill := false
	var has_on_land := false
	for layer: AbilityLayer in module.layers:
		if layer == null:
			continue
		if (
			layer.condition == GameEnums.LayerCondition.ON_KILL
			and layer.effect != null
			and layer.effect.type == GameEnums.EffectType.GRANT_AP
		):
			has_on_kill = true
		if (
			layer.condition == GameEnums.LayerCondition.ON_LAND
			and layer.effect != null
			and layer.effect.type == GameEnums.EffectType.PUSH
		):
			has_on_land = true
	if not has_on_kill or not has_on_land:
		failures.append("migration should author ON_KILL GRANT_AP and ON_LAND PUSH layers")
	module.buff_on_push = 1
	ModuleAuthoringRules.migrate_kill_and_landing_riders_to_layers(module)
	if module.buff_on_push != 0:
		failures.append("migration should clear buff_on_push module knob")
	var has_buff_layer := false
	for layer: AbilityLayer in module.layers:
		if layer != null and layer.buff_on_push > 0:
			has_buff_layer = true
	if not has_buff_layer:
		failures.append("migration should author buff_on_push layer")


static func _test_during_bulldoze_merges_into_dash_primary(failures: Array[String]) -> void:
	var module := AbilityModule.new()
	module.primary_type = GameEnums.EffectType.DASH
	module.amount = 3
	module.layers = [DataLibrary._during_bulldoze(1, 1)]
	var compiled: Array[EffectData] = AbilityModuleBridge.compile_module_to_effects(module)
	var dash_rows: int = 0
	var bulldoze_rows: int = 0
	for eff: EffectData in compiled:
		if eff.type == GameEnums.EffectType.DASH:
			dash_rows += 1
			if int(eff.modifiers.get("bulldoze", 0)) <= 0:
				failures.append("DASH primary must carry bulldoze modifiers from DURING layer")
		elif eff.type == GameEnums.EffectType.BULLDOZE:
			bulldoze_rows += 1
	if dash_rows != 1 or bulldoze_rows != 0:
		failures.append(
			"DURING bulldoze must merge into DASH only (got dash=%d bulldoze=%d)"
			% [dash_rows, bulldoze_rows]
		)


static func _test_adjacent_bonus_layer_merges_into_primary(failures: Array[String]) -> void:
	var module := AbilityModule.new()
	module.primary_type = GameEnums.EffectType.DAMAGE
	module.amount = 2
	module.layers = [DataLibrary._if_already_adjacent_bonus_layer(2)]
	var compiled: Array[EffectData] = AbilityModuleBridge.compile_module_to_effects(module)
	if compiled.is_empty():
		failures.append("adjacent bonus layer compile produced no effects")
	elif compiled[0].bonus_if_adjacent_at_cast != 2:
		failures.append("IF_ALREADY_ADJACENT layer must merge bonus_if_adjacent_at_cast onto DAMAGE primary")
	elif compiled.size() != 1:
		failures.append("IF_ALREADY_ADJACENT bonus layer must not emit a separate effect row")


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


static func _test_every_effect_type_has_a_primary_family(failures: Array[String]) -> void:
	var missing: Array[GameEnums.EffectType] = ModuleAuthoringRules.uncategorized_effect_types()
	if not missing.is_empty():
		failures.append("EffectType missing from primary families: %s" % str(missing))
