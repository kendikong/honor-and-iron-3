extends Node

## Headless smoke: modular finalize preserves Knight/Bruiser effect fingerprints.
## Extends Node so project autoloads (EventBus) are registered before DataLibrary compiles.

const AbilityModuleRuntimeTest = preload("res://tests/ability_module_runtime_test.gd")
const AbilityModuleReaderBoundaryTest = preload(
	"res://tests/ability_module_reader_boundary_test.gd"
)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	DataLibrary.reset_cache()
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
	AbilityModuleRuntimeTest.run_all(failures)
	check_failures = failures.size()
	print("ABILITY_MODULE_CHECK: compatibility_reader_boundary START")
	AbilityModuleReaderBoundaryTest.run_all(failures)
	_report_check("compatibility_reader_boundary", failures, check_failures)
	if failures.is_empty():
		print("ABILITY_MODULE_BRIDGE_TEST: PASS")
		get_tree().quit(0)
	else:
		print("ABILITY_MODULE_BRIDGE_TEST: FAIL")
		for f: String in failures:
			printerr("  [FAIL] %s" % f)
		get_tree().quit(1)


func _report_check(label: String, failures: Array[String], before: int) -> void:
	var result: String = "PASS" if failures.size() == before else "FAIL"
	print("ABILITY_MODULE_CHECK: %s %s" % [label, result])


func _check_bruiser(failures: Array[String]) -> void:
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


func _check_knight(failures: Array[String]) -> void:
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


func _check_violent_collision_modules(failures: Array[String]) -> void:
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
	## Charge Strike: MOVE module + DAMAGE module with PUSH layer (not three peer modules).
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
