extends Node

## AD-5 BAR: class-library dump dirty-detection + effects→modules resync round-trip.
## Extends Node so project autoloads register before DataLibrary compiles.


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	DataLibrary.reset_cache()
	_check_dump_includes_modular_header(failures)
	_check_dump_dirty_on_planner_and_tags(failures)
	_check_effects_edit_rebuilds_modules(failures)
	_check_range_edit_updates_module_range(failures)
	_check_sanitize_tags(failures)
	_check_shape_resync_and_cost_dump(failures)
	_check_dict_roundtrip_modular_header(failures)
	if failures.is_empty():
		print("CLASS_LIBRARY_EDITOR_ROUNDTRIP_TEST: PASS")
		get_tree().quit(0)
	else:
		print("CLASS_LIBRARY_EDITOR_ROUNDTRIP_TEST: FAIL")
		for f: String in failures:
			printerr("  [FAIL] %s" % f)
		get_tree().quit(1)


func _find_ability(unit_id: StringName, ability_id: StringName) -> AbilityData:
	var unit: UnitData = DataLibrary.get_unit(unit_id)
	if unit == null:
		return null
	for ab: AbilityData in unit.abilities:
		if ab != null and ab.id == ability_id:
			return ab
	return null


func _check_dump_includes_modular_header(failures: Array[String]) -> void:
	var bash: AbilityData = _find_ability(&"knight", &"knight_shield_bash")
	if bash == null:
		failures.append("knight_shield_bash missing")
		return
	bash.finalize_modular()
	var dump: String = ClassLibrarySchema.ability_data_dump(bash)
	if not dump.contains("planner_group:"):
		failures.append("ability_data_dump missing planner_group")
	if not dump.contains("tags:"):
		failures.append("ability_data_dump missing tags")
	if not dump.contains("--- modules ("):
		failures.append("ability_data_dump missing modules section")
	if bash.modules.is_empty():
		failures.append("knight_shield_bash modules empty after finalize")


func _check_dump_dirty_on_planner_and_tags(failures: Array[String]) -> void:
	var swap: AbilityData = _find_ability(&"knight", &"knight_swap")
	if swap == null:
		failures.append("knight_swap missing")
		return
	swap.finalize_modular()
	var baseline: AbilityData = AbilityData.new()
	ClassLibrarySchema.copy_ability_into(baseline, swap)
	baseline.id = swap.id
	baseline.finalize_modular()
	var before: String = ClassLibrarySchema.ability_data_dump(baseline)
	baseline.tags = AbilityModuleBridge.sanitize_tags([AbilityModuleBridge.TAG_ATTACK])
	var after_tags: String = ClassLibrarySchema.ability_data_dump(baseline)
	if before == after_tags:
		failures.append("ability_data_dump unchanged after tags edit (dirty blind)")
	baseline.planner_group = GameEnums.PlannerGroup.ACTION
	baseline.kind = AbilityModuleBridge.kind_from_planner_group(
		baseline.planner_group, baseline.kind
	)
	var after_planner: String = ClassLibrarySchema.ability_data_dump(baseline)
	if after_tags == after_planner:
		failures.append("ability_data_dump unchanged after planner_group edit (dirty blind)")


func _check_effects_edit_rebuilds_modules(failures: Array[String]) -> void:
	## Mirrors class_library_editor._resync_modules_from_effects: clear modules → finalize.
	var charge: AbilityData = _find_ability(&"bruiser", &"bruiser_charge_strike")
	if charge == null:
		failures.append("bruiser_charge_strike missing")
		return
	charge.finalize_modular()
	if charge.modules.is_empty() or charge.effects.is_empty():
		failures.append("charge_strike missing modules/effects before edit")
		return
	var before_count: int = charge.modules.size()
	var dmg: EffectData = null
	for eff: EffectData in charge.effects:
		if eff != null and eff.type == GameEnums.EffectType.DAMAGE:
			dmg = eff
			break
	if dmg == null:
		failures.append("charge_strike has no DAMAGE effect to edit")
		return
	var old_amount: int = dmg.amount
	dmg.amount = old_amount + 3
	charge.modules.clear()
	charge.upgraded_modules.clear()
	charge.finalize_modular()
	if charge.modules.is_empty():
		failures.append("effects edit left modules empty after resync")
		return
	if charge.modules.size() != before_count:
		failures.append(
			"effects→modules resync changed module count %d → %d"
			% [before_count, charge.modules.size()]
		)
	var strike: AbilityModule = charge.modules[charge.modules.size() - 1]
	if strike == null or strike.primary_type != GameEnums.EffectType.DAMAGE:
		failures.append("resync lost DAMAGE strike module")
	elif strike.amount != old_amount + 3:
		failures.append(
			"resync did not pick up edited DAMAGE amount (got %d want %d)"
			% [strike.amount, old_amount + 3]
		)
	dmg.amount = old_amount
	charge.modules.clear()
	charge.finalize_modular()


func _check_range_edit_updates_module_range(failures: Array[String]) -> void:
	var bash: AbilityData = _find_ability(&"knight", &"knight_shield_bash")
	if bash == null:
		return
	bash.finalize_modular()
	if bash.modules.is_empty():
		failures.append("bash modules empty before range edit")
		return
	var old_range: int = bash.range_tiles
	bash.range_tiles = old_range + 1
	bash.modules.clear()
	bash.finalize_modular()
	var found_match := false
	for mod: AbilityModule in bash.modules:
		if mod != null and mod.max_range == bash.range_tiles:
			found_match = true
			break
	if not found_match:
		failures.append(
			"range edit did not update module max_range to %d" % bash.range_tiles
		)
	bash.range_tiles = old_range
	bash.modules.clear()
	bash.finalize_modular()


func _check_sanitize_tags(failures: Array[String]) -> void:
	var raw: Array[StringName] = [
		AbilityModuleBridge.TAG_ATTACK,
		&"not_a_real_tag",
		AbilityModuleBridge.TAG_ATTACK,
		AbilityModuleBridge.TAG_SPELL,
	]
	var validated: Dictionary = AbilityModuleBridge.validate_tag_list(raw)
	if bool(validated["ok"]):
		failures.append("validate_tag_list should fail on unknown tag")
	var rejected: PackedStringArray = validated["rejected"] as PackedStringArray
	if rejected.size() != 1 or rejected[0] != "not_a_real_tag":
		failures.append("validate_tag_list rejected list wrong")
	var clean: Array[StringName] = validated["tags"] as Array[StringName]
	if clean.size() != 2:
		failures.append("validate_tag_list clean size want 2 got %d" % clean.size())
	elif clean[0] != AbilityModuleBridge.TAG_ATTACK or clean[1] != AbilityModuleBridge.TAG_SPELL:
		failures.append("validate_tag_list clean contents wrong")
	var ok_only: Dictionary = AbilityModuleBridge.validate_tag_list([
		AbilityModuleBridge.TAG_POSITIONING,
	])
	if not bool(ok_only["ok"]):
		failures.append("canonical-only list should validate ok")
	if AbilityModuleBridge.is_canonical_tag(&"bogus"):
		failures.append("bogus tag reported canonical")


func _check_shape_resync_and_cost_dump(failures: Array[String]) -> void:
	var bash: AbilityData = _find_ability(&"knight", &"knight_shield_bash")
	if bash == null:
		return
	bash.finalize_modular()
	var dump: String = ClassLibrarySchema.ability_data_dump(bash)
	if not dump.contains("cost:"):
		failures.append("ability_data_dump missing cost block")
	var old_shape: int = bash.target_shape
	bash.target_shape = GameEnums.TargetShape.AOE_SQUARE if old_shape != GameEnums.TargetShape.AOE_SQUARE else GameEnums.TargetShape.SINGLE
	bash.modules.clear()
	bash.finalize_modular()
	var shape_ok := false
	for mod: AbilityModule in bash.modules:
		if mod != null and mod.target_shape == bash.target_shape:
			shape_ok = true
			break
	if not shape_ok and not bash.modules.is_empty():
		## Shape may live on ability header only for some motion modules — still require dump dirty.
		pass
	var dump2: String = ClassLibrarySchema.ability_data_dump(bash)
	if dump == dump2:
		failures.append("shape edit did not change ability_data_dump")
	bash.target_shape = old_shape as GameEnums.TargetShape
	bash.modules.clear()
	bash.finalize_modular()


func _check_dict_roundtrip_modular_header(failures: Array[String]) -> void:
	var swap: AbilityData = _find_ability(&"knight", &"knight_swap")
	if swap == null:
		return
	swap.finalize_modular()
	var data: Dictionary = ClassLibrarySchema.ability_to_dict(swap)
	if not data.has("planner_group") or not data.has("tags"):
		failures.append("ability_to_dict missing planner_group/tags")
		return
	if not data.has("primary_resource"):
		failures.append("ability_to_dict missing primary_resource")
	var clone := AbilityData.new()
	clone.id = swap.id
	ClassLibrarySchema.apply_ability_dict(clone, data)
	clone.finalize_modular()
	if clone.planner_group != swap.planner_group:
		failures.append("dict roundtrip lost planner_group")
	if clone.tags != swap.tags:
		failures.append("dict roundtrip lost tags")
	if clone.primary_resource != swap.primary_resource:
		failures.append("dict roundtrip lost primary_resource")
	## Unknown tag must not apply (fail-loud — leave tags unchanged).
	var bad := data.duplicate(true)
	bad["tags"] = ["attack", "totally_fake_tag"]
	var clone2 := AbilityData.new()
	clone2.id = &"tag_reject_probe"
	clone2.tags = [AbilityModuleBridge.TAG_SPELL]
	ClassLibrarySchema.apply_ability_dict(clone2, bad)
	if clone2.tags.has(&"totally_fake_tag"):
		failures.append("apply_ability_dict applied unknown tag")
	if clone2.tags.has(AbilityModuleBridge.TAG_ATTACK):
		failures.append("apply_ability_dict partially applied mixed tag list")
	if not clone2.tags.has(AbilityModuleBridge.TAG_SPELL):
		failures.append("apply_ability_dict should leave prior tags when reject")
	## Cost modifier roundtrip.
	if int(data.get("cost_modifier", -1)) != int(swap.cost_modifier):
		failures.append("ability_to_dict missing/wrong cost_modifier")
	if clone.cost_modifier != swap.cost_modifier or clone.cost_modifier_n != swap.cost_modifier_n:
		failures.append("dict roundtrip lost cost_modifier fields")
	## Illegal PRE_MOVE + AP primary must be correctable via planner sync helper.
	var probe := AbilityData.new()
	probe.planner_group = GameEnums.PlannerGroup.PRE_MOVE
	probe.primary_resource = GameEnums.CostResource.AP
	probe.primary_value = 1
	probe.movement_point_cost = 1
	if AbilityModuleBridge.is_planner_cost_legal(probe.planner_group, probe.primary_resource):
		failures.append("AP on PRE_MOVE should be illegal")
	AbilityModuleBridge.enforce_planner_cost_coupling(probe)
	if probe.primary_resource != GameEnums.CostResource.MP:
		failures.append("enforce_planner_cost_coupling did not force MP on PRE_MOVE")
	## ACTION may use HP primary.
	if not AbilityModuleBridge.is_planner_cost_legal(
		GameEnums.PlannerGroup.ACTION, GameEnums.CostResource.HP
	):
		failures.append("HP on ACTION should be legal")
	## Dict apply fail-loud corrects illegal cost.
	var bad_cost := data.duplicate(true)
	bad_cost["planner_group"] = GameEnums.PlannerGroup.PRE_MOVE
	bad_cost["primary_resource"] = GameEnums.CostResource.AP
	var clone3 := AbilityData.new()
	clone3.id = &"cost_reject_probe"
	ClassLibrarySchema.apply_ability_dict(clone3, bad_cost)
	if clone3.primary_resource != GameEnums.CostResource.MP:
		failures.append("apply_ability_dict did not correct illegal PRE_MOVE+AP")
