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
	var clean: Array[StringName] = AbilityModuleBridge.sanitize_tags(raw)
	if clean.size() != 2:
		failures.append("sanitize_tags size want 2 got %d" % clean.size())
	elif clean[0] != AbilityModuleBridge.TAG_ATTACK or clean[1] != AbilityModuleBridge.TAG_SPELL:
		failures.append("sanitize_tags order/contents wrong")
	if AbilityModuleBridge.is_canonical_tag(&"bogus"):
		failures.append("bogus tag reported canonical")
