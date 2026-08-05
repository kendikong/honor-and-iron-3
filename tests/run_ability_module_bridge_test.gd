extends SceneTree

## Headless smoke: modular finalize preserves Knight/Bruiser effect fingerprints.
## SceneTree + body checks (not Node --script): autoloads register before DataLibrary compiles.


func _initialize() -> void:
	var failures: Array[String] = []
	DataLibrary.reset_cache()
	_check_bruiser(failures)
	_check_knight(failures)
	_check_violent_collision_modules(failures)
	if failures.is_empty():
		print("ABILITY_MODULE_BRIDGE_TEST: PASS")
		quit(0)
	else:
		print("ABILITY_MODULE_BRIDGE_TEST: FAIL")
		for f: String in failures:
			printerr("  [FAIL] %s" % f)
		quit(1)


func _check_bruiser(failures: Array[String]) -> void:
	var bruiser: UnitData = DataLibrary.get_unit(&"bruiser")
	if bruiser == null:
		failures.append("bruiser missing from DataLibrary")
		return
	for ab: AbilityData in bruiser.abilities:
		if ab == null:
			continue
		if ab.modules.is_empty():
			failures.append("%s must have non-empty modules after factory finalize" % String(ab.id))
		if not ab.upgraded_effects.is_empty() and ab.upgraded_modules.is_empty():
			failures.append("%s has upgraded_effects but empty upgraded_modules" % String(ab.id))
		if ab.planner_group == GameEnums.PlannerGroup.PRE_MOVE:
			if ab.primary_resource != GameEnums.CostResource.MP:
				failures.append("%s PRE_MOVE primary_resource not MP" % String(ab.id))
			if not ab.has_tag(AbilityModuleBridge.TAG_POSITIONING):
				failures.append("%s PRE_MOVE missing positioning tag" % String(ab.id))
		elif ab.planner_group == GameEnums.PlannerGroup.ACTION:
			if ab.primary_resource != GameEnums.CostResource.AP:
				failures.append("%s ACTION primary_resource not AP" % String(ab.id))


func _check_knight(failures: Array[String]) -> void:
	var knight: UnitData = DataLibrary.get_unit(&"knight")
	if knight == null:
		failures.append("knight missing from DataLibrary")
		return
	var swap: AbilityData = null
	for ab: AbilityData in knight.abilities:
		if ab == null:
			continue
		if ab.modules.is_empty():
			failures.append("%s must have non-empty modules after factory finalize" % String(ab.id))
		if not ab.upgraded_effects.is_empty() and ab.upgraded_modules.is_empty():
			failures.append("%s has upgraded_effects but empty upgraded_modules" % String(ab.id))
		if ab.planner_group == GameEnums.PlannerGroup.PRE_MOVE:
			if ab.primary_resource != GameEnums.CostResource.MP:
				failures.append("%s PRE_MOVE primary_resource not MP" % String(ab.id))
			if not ab.has_tag(AbilityModuleBridge.TAG_POSITIONING):
				failures.append("%s PRE_MOVE missing positioning tag" % String(ab.id))
		elif ab.planner_group == GameEnums.PlannerGroup.ACTION:
			if ab.primary_resource != GameEnums.CostResource.AP:
				failures.append("%s ACTION primary_resource not AP" % String(ab.id))
		if ab.id == &"knight_swap":
			swap = ab
	if swap == null:
		failures.append("knight_swap missing")
		return
	if swap.planner_group != GameEnums.PlannerGroup.PRE_MOVE:
		failures.append("knight_swap planner_group not PRE_MOVE")
	if swap.modules.is_empty() or swap.modules[0].primary_type != GameEnums.EffectType.SWAP:
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
	if vc.modules[1].gate != GameEnums.ModuleGate.IF_COLLIDED:
		failures.append("violent_collision module[1] gate not IF_COLLIDED")
	if not AbilitySystem.ability_has_module_gate(vc, GameEnums.ModuleGate.IF_COLLIDED):
		failures.append("ability_has_module_gate IF_COLLIDED false for violent_collision")
	if vc.modules.is_empty() or vc.modules[0].legacy_modifiers.has("violent_collision_recast"):
		failures.append(
			"violent_collision flat effects must not stamp violent_collision_recast (gate is modular)"
		)
	if vc.modules.size() != 1:
		failures.append(
			"violent_collision legacy effects should stay 1 DASH (got %d)" % vc.modules.size()
		)
	if not vc.modules[0].legacy_modifiers.has("bulldoze"):
		failures.append("violent_collision lost bulldoze modifier")
	if not AbilitySystem.evaluate_module_gate(GameEnums.ModuleGate.IF_COLLIDED, true):
		failures.append("evaluate_module_gate IF_COLLIDED should pass when collided=true")
	if AbilitySystem.evaluate_module_gate(GameEnums.ModuleGate.IF_COLLIDED, false):
		failures.append("evaluate_module_gate IF_COLLIDED should fail when collided=false")
	if AbilitySystem.evaluate_module_gate(GameEnums.ModuleGate.IF_ADJACENT_ENEMY, true):
		failures.append("unimplemented gates must fail closed")
	## Factory must not leave anonymous stamp after ensure + finalize.
	if vc.modules[0].legacy_modifiers.has("violent_collision_recast"):
		failures.append("factory path left violent_collision_recast stamp")
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
	elif charge.modules[1].layers.is_empty():
		failures.append("charge_strike strike module should have PUSH layer")
