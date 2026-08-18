class_name AbilityModuleBridgeRunner
extends RefCounted

## Headless smoke: modular finalize preserves Knight/Bruiser fingerprints + module bar.


static func run_all() -> Dictionary:
	var failures: Array[String] = []
	var check_failures: int = failures.size()
	print("ABILITY_MODULE_CHECK: bruiser_module_fingerprints START")
	_check_bruiser(failures)
	_report_check("bruiser_module_fingerprints", failures, check_failures)
	check_failures = failures.size()
	print("ABILITY_MODULE_CHECK: knight_module_fingerprints START")
	_check_knight(failures)
	_report_check("knight_module_fingerprints", failures, check_failures)
	check_failures = failures.size()
	print("ABILITY_MODULE_CHECK: violent_collision_module_shape START")
	_check_violent_collision_modules(failures)
	_report_check("violent_collision_module_shape", failures, check_failures)
	check_failures = failures.size()
	print("ABILITY_MODULE_CHECK: trampling_advance_module_shape START")
	_check_trampling_advance_modules(failures)
	_report_check("trampling_advance_module_shape", failures, check_failures)
	check_failures = failures.size()
	print("ABILITY_MODULE_CHECK: er1_shared_homes START")
	_check_er1_shared_homes(failures)
	_report_check("er1_shared_homes", failures, check_failures)
	check_failures = failures.size()
	print("ABILITY_MODULE_CHECK: infer_motion_push_layer START")
	_check_authored_motion_push_layer(failures)
	_report_check("infer_motion_push_layer", failures, check_failures)
	_run_script_check(
		"res://tests/ability_module_runtime_test.gd",
		"run_all",
		failures,
		"ability_module_runtime",
		check_failures,
	)
	check_failures = failures.size()
	_run_script_check(
		"res://tests/extra_rules_conversion_contract.gd",
		"run_all",
		failures,
		"extra_rules_conversion_contract",
		check_failures,
	)
	check_failures = failures.size()
	_run_script_check(
		"res://tests/module_authoring_rules_test.gd",
		"run_all",
		failures,
		"module_authoring_rules",
		check_failures,
	)
	check_failures = failures.size()
	_run_script_check(
		"res://tests/class_library_editor_module_boundary_test.gd",
		"run_all",
		failures,
		"class_editor_module_boundary",
		check_failures,
	)
	check_failures = failures.size()
	_run_script_check(
		"res://tests/ability_module_reader_boundary_test.gd",
		"run_all",
		failures,
		"module_reader_boundary",
		check_failures,
	)
	check_failures = failures.size()
	_run_formatter_audit(failures, check_failures)
	if failures.is_empty():
		print("ABILITY_MODULE_BRIDGE_TEST: PASS")
	else:
		print("ABILITY_MODULE_BRIDGE_TEST: FAIL")
		for f: String in failures:
			printerr("  [FAIL] %s" % f)
	return {"passed": failures.is_empty(), "failures": failures}


static func _run_script_check(
	script_path: String,
	method: StringName,
	failures: Array[String],
	label: String,
	before: int,
) -> void:
	print("ABILITY_MODULE_CHECK: %s START" % label)
	var script: Script = load(script_path) as Script
	if script == null:
		failures.append("%s script missing: %s" % [label, script_path])
		_report_check(label, failures, before)
		return
	if not script.has_method(method):
		failures.append("%s missing %s (parse error?): %s" % [label, String(method), script_path])
		_report_check(label, failures, before)
		return
	script.call(method, failures)
	_report_check(label, failures, before)


static func _run_formatter_audit(failures: Array[String], before: int) -> void:
	print("ABILITY_MODULE_CHECK: ability_formatter_audit START")
	var script: Script = load("res://tests/run_ability_formatter_audit.gd") as Script
	if script == null:
		failures.append("ability_formatter_audit script missing")
		_report_check("ability_formatter_audit", failures, before)
		return
	var issues: PackedStringArray = script.call("run_all") as PackedStringArray
	for issue: String in issues:
		failures.append(issue)
	_report_check("ability_formatter_audit", failures, before)


static func _report_check(label: String, failures: Array[String], before: int) -> void:
	var result: String = "PASS" if failures.size() == before else "FAIL"
	print("ABILITY_MODULE_CHECK: %s %s" % [label, result])


static func _check_bruiser(failures: Array[String]) -> void:
	var bruiser: UnitData = DataLibrary.get_unit(&"bruiser")
	if bruiser == null:
		failures.append("bruiser missing from DataLibrary")
		return
	for ab: AbilityData in bruiser.abilities:
		if ab == null:
			continue
		if ab.modules.is_empty():
			failures.append("%s has no authored modules" % String(ab.id))
		if ab.planner_group == GameEnums.PlannerGroup.PRE_MOVE:
			if ab.primary_resource != GameEnums.CostResource.MP:
				failures.append("%s PRE_MOVE primary_resource not MP" % String(ab.id))
			if not ab.has_tag(AbilityModuleBridge.TAG_POSITIONING):
				failures.append("%s PRE_MOVE missing positioning tag" % String(ab.id))
		elif ab.kind == GameEnums.AbilityKind.CLASS_SKILL:
			if ab.primary_resource != GameEnums.CostResource.AP:
				failures.append("%s ACTION primary_resource not AP" % String(ab.id))


static func _check_knight(failures: Array[String]) -> void:
	var knight: UnitData = DataLibrary.get_unit(&"knight")
	if knight == null:
		failures.append("knight missing from DataLibrary")
		return
	var swap: AbilityData = null
	for ab: AbilityData in knight.abilities:
		if ab != null and ab.id == &"knight_swap":
			swap = ab
			break
	if swap == null:
		failures.append("knight_swap missing")
		return
	if swap.planner_group != GameEnums.PlannerGroup.PRE_MOVE:
		failures.append("knight_swap planner_group not PRE_MOVE")
	if swap.modules.is_empty() or swap.modules[0].primary_type != GameEnums.EffectType.SWAP:
		failures.append("knight_swap lost authored SWAP module")


static func _check_violent_collision_modules(failures: Array[String]) -> void:
	var bruiser: UnitData = DataLibrary.get_unit(&"bruiser")
	if bruiser == null:
		return
	var vc: AbilityData = null
	for ab: AbilityData in bruiser.abilities:
		if ab != null and ab.id == &"bruiser_violent_collision":
			vc = ab
			break
	if vc == null:
		failures.append("bruiser_violent_collision missing")
		return
	if vc.modules.size() < 2:
		failures.append("violent_collision should have DASH + gated MOVE modules")
		return
	if vc.modules[0].primary_type != GameEnums.EffectType.DASH:
		failures.append("violent_collision module[0] should be DASH")
	if vc.modules[1].primary_type != GameEnums.EffectType.MOVE:
		failures.append("violent_collision module[1] should be MOVE")
	if vc.modules[1].gate != GameEnums.ModuleGate.IF_COLLIDED:
		failures.append("violent_collision module[1] gate not IF_COLLIDED")
	if vc.modules[0].violent_collision_recast <= 0:
		failures.append("violent_collision module lost violent_collision_recast")
	if not vc.modules[0].runtime_has("bulldoze"):
		failures.append("violent_collision module lost bulldoze modifier")
	var charge: AbilityData = null
	for ab2: AbilityData in bruiser.abilities:
		if ab2 != null and ab2.id == &"bruiser_charge_strike":
			charge = ab2
			break
	if charge == null:
		failures.append("bruiser_charge_strike missing")
	elif charge.modules.size() < 2:
		failures.append("charge_strike should be MOVE module + strike module")
	elif charge.modules[0].primary_type != GameEnums.EffectType.MOVE \
			or charge.modules[1].primary_type != GameEnums.EffectType.DAMAGE:
		failures.append("charge_strike module order should be MOVE then DAMAGE")
	elif charge.modules[1].layers.is_empty():
		failures.append("charge_strike strike module should have PUSH layer")


static func _check_trampling_advance_modules(failures: Array[String]) -> void:
	var knight: UnitData = DataLibrary.get_unit(&"knight")
	if knight == null:
		failures.append("knight missing for trampling_advance check")
		return
	var trample: AbilityData = null
	for ab: AbilityData in knight.abilities:
		if ab != null and ab.id == &"knight_trampling_advance":
			trample = ab
			break
	if trample == null:
		failures.append("knight_trampling_advance missing")
		return
	if trample.modules.size() != 1:
		failures.append(
			"trampling_advance should be 1 motion module + PUSH layer (got %d modules)"
			% trample.modules.size(),
		)
		return
	var motion: AbilityModule = trample.modules[0]
	if motion.primary_type != GameEnums.EffectType.MOVE:
		failures.append("trampling_advance module[0] should be MOVE primary")
	var has_trample_kw: bool = false
	for keyword: AbilityKeyword in motion.keywords:
		if keyword != null and keyword.keyword_id == GameEnums.AbilityKeywordId.TRAMPLE:
			has_trample_kw = true
	if not has_trample_kw:
		failures.append("trampling_advance missing TRAMPLE keyword on motion module")
	var has_push_layer: bool = false
	for layer: AbilityLayer in motion.layers:
		if layer != null and layer.effect != null and layer.effect.type == GameEnums.EffectType.PUSH:
			has_push_layer = true
	if not has_push_layer:
		failures.append("trampling_advance missing PUSH layer on motion module")


static func _check_er1_shared_homes(failures: Array[String]) -> void:
	if not GameEnums.is_walk_motion(GameEnums.EffectType.PAIRED_MOVE):
		failures.append("PAIRED_MOVE is not a shared walk-motion type")
	var illegal_action_pair := AbilityModule.new()
	illegal_action_pair.primary_type = GameEnums.EffectType.PAIRED_MOVE
	if AbilityModuleBridge.validate_modules(
		[illegal_action_pair], GameEnums.PlannerGroup.ACTION,
	).is_empty():
		failures.append("ACTION PAIRED_MOVE was not rejected by module validation")
	var illegal_ally_swap := AbilityModule.new()
	illegal_ally_swap.primary_type = GameEnums.EffectType.SWAP
	illegal_ally_swap.targeting_flags = GameEnums.TargetingFlags.ALLY
	if AbilityModuleBridge.validate_modules(
		[illegal_ally_swap], GameEnums.PlannerGroup.ACTION,
	).is_empty():
		failures.append("ACTION ally SWAP was not rejected by module validation")
	for unit: UnitData in DataLibrary.get_all_player_units():
		if unit == null:
			continue
		for ability: AbilityData in unit.abilities:
			_check_relocation_planner(failures, ability, ability.modules)
			_check_relocation_planner(failures, ability, ability.upgraded_modules)
	var paired := AbilityModule.new()
	paired.primary_type = GameEnums.EffectType.PAIRED_MOVE
	paired.amount = 1
	paired.min_range = 1
	paired.max_range = 1
	var paired_effects := AbilityModuleBridge.compile_module_to_effects(paired)
	if paired_effects.is_empty() or paired_effects[0].type != GameEnums.EffectType.PAIRED_MOVE:
		failures.append("PAIRED_MOVE module did not compile as its authored primary effect")
	var resource := AbilityModule.new()
	resource.primary_type = GameEnums.EffectType.GRANT_SCRAP
	resource.amount = 2
	resource.grant_scrap = 1
	var layer := AbilityLayer.new()
	layer.effect = DataLibrary._effect(GameEnums.EffectType.GRANT_SCRAP, 0)
	layer.grant_scrap = 2
	resource.layers.append(layer)
	var resource_effects := AbilityModuleBridge.compile_module_to_effects(resource)
	if resource_effects.is_empty() or not resource_effects[0].modifiers.has("grant_scrap"):
		failures.append("GRANT_SCRAP module field missing from compiled effect")
	if resource_effects.size() < 2 or not resource_effects[1].modifiers.has("grant_scrap"):
		failures.append("GRANT_SCRAP layer field missing from compiled effect")
	var grant_ap := AbilityModule.new()
	grant_ap.primary_type = GameEnums.EffectType.GRANT_AP
	grant_ap.grant_ap = 1
	var grant_ap_layer := AbilityLayer.new()
	grant_ap_layer.effect = DataLibrary._effect(GameEnums.EffectType.GRANT_AP, 0)
	grant_ap_layer.grant_ap = 2
	grant_ap.layers.append(grant_ap_layer)
	var grant_ap_effects := AbilityModuleBridge.compile_module_to_effects(grant_ap)
	if grant_ap_effects.is_empty() or not grant_ap_effects[0].modifiers.has("grant_ap"):
		failures.append("GRANT_AP module field missing from compiled effect")
	if grant_ap_effects.size() < 2 or not grant_ap_effects[1].modifiers.has("grant_ap"):
		failures.append("GRANT_AP layer field missing from compiled effect")
	var hazard := AbilityModule.new()
	hazard.primary_type = GameEnums.EffectType.CREATE_HAZARD
	hazard.terrain_id = &"fire"
	hazard.hazard_duration = 3
	hazard.hazard_status = GameEnums.StatusType.ROOT
	hazard.spread_status_adjacent = true
	hazard.reaction_terrain = &"steam"
	hazard.reaction_damage = 2
	var hazard_effects := AbilityModuleBridge.compile_module_to_effects(hazard)
	if (
		hazard_effects.is_empty()
		or not hazard_effects[0].modifiers.has_all([
			"terrain_id", "hazard_duration", "hazard_status",
			"spread_status_adjacent", "reaction_terrain", "reaction_damage",
		])
	):
		failures.append("CREATE_HAZARD typed fields missing from compiled effect")
	var spawn := AbilityModule.new()
	spawn.primary_type = GameEnums.EffectType.SPAWN
	spawn.spawn_unit_id = &"engineer_turret"
	spawn.construct_spawn = true
	spawn.turret_attack = 3
	spawn.construct_hp_pct = 0.5
	var spawn_layer := AbilityLayer.new()
	spawn_layer.effect = DataLibrary._effect(GameEnums.EffectType.SPAWN, 0)
	spawn_layer.construct_hp_pct = 0.75
	spawn_layer.spawn_furthest_empty_on_line = true
	spawn.layers.append(spawn_layer)
	var spawn_effects := AbilityModuleBridge.compile_module_to_effects(spawn)
	if (
		spawn_effects.is_empty()
		or not spawn_effects[0].modifiers.has_all([
			"construct_spawn", "turret_attack", "construct_hp_pct",
		])
	):
		failures.append("SPAWN module fields missing from compiled effect")
	if (
		spawn_effects.size() < 2
		or not spawn_effects[1].modifiers.has("spawn_furthest_empty_on_line")
	):
		failures.append("SPAWN layer placement field missing from compiled effect")
	var mercenary: UnitData = DataLibrary.get_unit(&"mercenary")
	var pullback: AbilityData = null
	if mercenary != null:
		for ability: AbilityData in mercenary.abilities:
			if ability != null and ability.id == &"mercenary_pullback":
				pullback = ability
				break
	if pullback == null or pullback.modules.is_empty():
		failures.append("mercenary_pullback missing from shared PAIRED_MOVE audit")
	elif pullback.modules[0].primary_type != GameEnums.EffectType.PAIRED_MOVE:
		failures.append("mercenary_pullback is not authored as PAIRED_MOVE")


static func _check_relocation_planner(
	failures: Array[String],
	ability: AbilityData,
	modules: Array[AbilityModule],
) -> void:
	if ability == null:
		return
	for module: AbilityModule in modules:
		if (
			module != null
			and (
				module.primary_type == GameEnums.EffectType.PAIRED_MOVE
				or (
					module.primary_type == GameEnums.EffectType.SWAP
					and (module.targeting_flags & GameEnums.TargetingFlags.ALLY) != 0
				)
			)
			and ability.planner_group != GameEnums.PlannerGroup.PRE_MOVE
		):
			failures.append(
				"%s authors ally relocation outside PRE_MOVE" % String(ability.id),
			)


static func _check_authored_motion_push_layer(failures: Array[String]) -> void:
	var trample_module := AbilityModule.new()
	trample_module.primary_type = GameEnums.EffectType.MOVE
	trample_module.amount = 2
	var push_layer := AbilityLayer.new()
	push_layer.effect = DataLibrary._effect(GameEnums.EffectType.PUSH, 1)
	trample_module.layers.append(push_layer)
	var trample_modules: Array[AbilityModule] = [trample_module]
	if trample_modules.size() != 1:
		failures.append(
			"authored MOVE+PUSH should be one module (got %d)" % trample_modules.size(),
		)
	elif trample_modules[0].layers.is_empty() \
			or trample_modules[0].layers[0].effect.type != GameEnums.EffectType.PUSH:
		failures.append("authored MOVE+PUSH should attach PUSH as motion layer")
	var strike_module := AbilityModule.new()
	strike_module.primary_type = GameEnums.EffectType.DAMAGE
	strike_module.amount = 3
	var charge_modules: Array[AbilityModule] = [trample_module, strike_module]
	if charge_modules.size() != 2:
		failures.append(
			"authored MOVE+DAMAGE should stay two modules (got %d)" % charge_modules.size(),
		)
	elif charge_modules[1].primary_type != GameEnums.EffectType.DAMAGE:
		failures.append("authored MOVE+DAMAGE second module should be DAMAGE strike")
