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
	print("ABILITY_MODULE_CHECK: infer_motion_push_layer START")
	_check_infer_motion_push_layer(failures)
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
		"compatibility_reader_boundary",
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
		if ab.modules.is_empty() and not ab.effects.is_empty():
			failures.append("%s has effects but empty modules" % String(ab.id))
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
	if swap.effects.is_empty() or swap.effects[0].type != GameEnums.EffectType.SWAP:
		failures.append("knight_swap lost SWAP effect after finalize")


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
	if vc.effects.is_empty() or not vc.effects[0].modifiers.has("violent_collision_recast"):
		failures.append("violent_collision legacy effects lost violent_collision_recast")
	if vc.effects.size() != 1:
		failures.append(
			"violent_collision legacy effects should stay 1 DASH (got %d)" % vc.effects.size()
		)
	if not vc.effects[0].modifiers.has("bulldoze"):
		failures.append("violent_collision lost bulldoze modifier")
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
	if motion.motion_mode != GameEnums.MotionMode.NONE:
		failures.append("trampling_advance motion_mode should be NONE")
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


static func _check_infer_motion_push_layer(failures: Array[String]) -> void:
	var move_eff := EffectData.new()
	move_eff.type = GameEnums.EffectType.MOVE
	move_eff.amount = 2
	var push_eff := EffectData.new()
	push_eff.type = GameEnums.EffectType.PUSH
	push_eff.amount = 1
	var damage_eff := EffectData.new()
	damage_eff.type = GameEnums.EffectType.DAMAGE
	damage_eff.amount = 3
	var trample_proxy := AbilityData.new()
	var trample_modules: Array[AbilityModule] = AbilityModuleBridge.infer_modules_from_effects(
		[move_eff, push_eff], trample_proxy,
	)
	if trample_modules.size() != 1:
		failures.append(
			"infer MOVE+PUSH should be one module (got %d)" % trample_modules.size(),
		)
	elif trample_modules[0].layers.is_empty() \
			or trample_modules[0].layers[0].effect.type != GameEnums.EffectType.PUSH:
		failures.append("infer MOVE+PUSH should attach PUSH as motion layer")
	var charge_proxy := AbilityData.new()
	var charge_modules: Array[AbilityModule] = AbilityModuleBridge.infer_modules_from_effects(
		[move_eff.duplicate(true), damage_eff], charge_proxy,
	)
	if charge_modules.size() != 2:
		failures.append(
			"infer MOVE+DAMAGE should stay two modules (got %d)" % charge_modules.size(),
		)
	elif charge_modules[1].primary_type != GameEnums.EffectType.DAMAGE:
		failures.append("infer MOVE+DAMAGE second module should be DAMAGE strike")
