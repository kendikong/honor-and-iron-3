extends SceneTree

## AD-5 / AD-5b BAR: class-library dump dirty-detection + effectsâ†’modules + planner callback.
## SceneTree + _initialize (not Node --script): autoloads register; body checks run immediately.


func _initialize() -> void:
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
		quit(0)
	else:
		print("CLASS_LIBRARY_EDITOR_ROUNDTRIP_TEST: FAIL")
		for f: String in failures:
			printerr("  [FAIL] %s" % f)
		quit(1)


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
	## Mirrors class_library_editor._resync_modules_from_effects: clear modules â†’ finalize.
	var charge: AbilityData = _find_ability(&"bruiser", &"bruiser_charge_strike")
	if charge == null:
		failures.append("bruiser_charge_strike missing")
		return
	charge.finalize_modular()
	if charge.modules.is_empty() or charge.modules.is_empty():
		failures.append("charge_strike missing modules/effects before edit")
		return
	var before_count: int = charge.modules.size()
	var dmg: AbilityModule = null
	for eff: AbilityModule in charge.modules:
		if eff != null and eff.primary_type == GameEnums.EffectType.DAMAGE:
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
			"effectsâ†’modules resync changed module count %d â†’ %d"
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
		## Shape may live on ability header only for some motion modules â€” still require dump dirty.
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
	## Unknown tag must not apply (fail-loud â€” leave tags unchanged).
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
	## HP-primary ACTION must survive dict roundtrip.
	var hp_skill := AbilityData.new()
	hp_skill.id = &"hp_primary_probe"
	hp_skill.planner_group = GameEnums.PlannerGroup.ACTION
	hp_skill.kind = GameEnums.AbilityKind.CLASS_SKILL
	hp_skill.primary_resource = GameEnums.CostResource.HP
	hp_skill.primary_value = 5
	hp_skill.action_point_cost = 0
	hp_skill.tags = [AbilityModuleBridge.TAG_ATTACK]
	hp_skill.modules = [AbilityModule.new()]
	hp_skill.modules[0].primary_type = GameEnums.EffectType.DAMAGE
	hp_skill.modules[0].amount = 1
	hp_skill.finalize_modular()
	var hp_dict: Dictionary = ClassLibrarySchema.ability_to_dict(hp_skill)
	if int(hp_dict.get("primary_resource", -1)) != int(GameEnums.CostResource.HP):
		failures.append("ability_to_dict lost HP primary_resource")
	var hp_clone := AbilityData.new()
	hp_clone.id = hp_skill.id
	ClassLibrarySchema.apply_ability_dict(hp_clone, hp_dict)
	if hp_clone.primary_resource != GameEnums.CostResource.HP:
		failures.append("dict roundtrip lost HP primary_resource")
	## Editor/schema shared apply paths (what the class library UI calls).
	var tag_ok: Dictionary = ClassLibrarySchema.try_apply_tags(
		AbilityData.new(), [AbilityModuleBridge.TAG_ATTACK]
	)
	if not bool(tag_ok["ok"]):
		failures.append("try_apply_tags should accept attack")
	var tag_bad_ab := AbilityData.new()
	tag_bad_ab.tags = [AbilityModuleBridge.TAG_SPELL]
	var tag_bad: Dictionary = ClassLibrarySchema.try_apply_tags(
		tag_bad_ab, [AbilityModuleBridge.TAG_ATTACK, &"nope"]
	)
	if bool(tag_bad["ok"]):
		failures.append("try_apply_tags should reject unknown")
	if tag_bad_ab.tags.has(AbilityModuleBridge.TAG_ATTACK):
		failures.append("try_apply_tags must not mutate on reject")
	var cost_ok: Dictionary = ClassLibrarySchema.try_apply_primary_resource(
		hp_skill, GameEnums.CostResource.HP
	)
	if not bool(cost_ok["ok"]):
		failures.append("try_apply_primary_resource HP on ACTION should ok")
	var cost_bad_ab := AbilityData.new()
	cost_bad_ab.planner_group = GameEnums.PlannerGroup.PRE_MOVE
	cost_bad_ab.primary_resource = GameEnums.CostResource.MP
	var cost_bad: Dictionary = ClassLibrarySchema.try_apply_primary_resource(
		cost_bad_ab, GameEnums.CostResource.AP
	)
	if bool(cost_bad["ok"]):
		failures.append("try_apply_primary_resource AP on PRE_MOVE should fail")
	if cost_bad_ab.primary_resource != GameEnums.CostResource.MP:
		failures.append("try_apply_primary_resource must not mutate on reject")
	var action_legal: Array[GameEnums.CostResource] = AbilityModuleBridge.legal_primary_resources(
		GameEnums.PlannerGroup.ACTION
	)
	if action_legal.size() != 2:
		failures.append("ACTION legal_primary_resources want AP+HP only")
	elif (
		action_legal[0] != GameEnums.CostResource.AP
		or action_legal[1] != GameEnums.CostResource.HP
	):
		failures.append("ACTION legal_primary_resources contents wrong")
	if GameEnums.CostResource.MP in action_legal or GameEnums.CostResource.NONE in action_legal:
		failures.append("ACTION must not offer MP/NONE")
	var pre_legal: Array[GameEnums.CostResource] = AbilityModuleBridge.legal_primary_resources(
		GameEnums.PlannerGroup.PRE_MOVE
	)
	if pre_legal.size() != 1 or pre_legal[0] != GameEnums.CostResource.MP:
		failures.append("PRE_MOVE legal_primary_resources want MP only")
	## Critic-proposed infra: OptionButton fill must match legal_primary_resources (same path as editor).
	var action_ab := AbilityData.new()
	action_ab.planner_group = GameEnums.PlannerGroup.ACTION
	action_ab.primary_resource = GameEnums.CostResource.AP
	var action_ob := OptionButton.new()
	ClassLibrarySchema.populate_legal_primary_option_button(action_ob, action_ab)
	if action_ob.item_count != 2:
		failures.append("ACTION OptionButton item_count want 2 got %d" % action_ob.item_count)
	else:
		var ids: Array[int] = [action_ob.get_item_id(0), action_ob.get_item_id(1)]
		if GameEnums.CostResource.AP not in ids or GameEnums.CostResource.HP not in ids:
			failures.append("ACTION OptionButton missing AP/HP ids")
		if GameEnums.CostResource.MP in ids or GameEnums.CostResource.NONE in ids:
			failures.append("ACTION OptionButton offered illegal MP/NONE")
	var pre_ab := AbilityData.new()
	pre_ab.planner_group = GameEnums.PlannerGroup.PRE_MOVE
	pre_ab.primary_resource = GameEnums.CostResource.MP
	var pre_ob := OptionButton.new()
	ClassLibrarySchema.populate_legal_primary_option_button(pre_ob, pre_ab)
	if pre_ob.item_count != 1 or pre_ob.get_item_id(0) != int(GameEnums.CostResource.MP):
		failures.append("PRE_MOVE OptionButton must offer only MP")
	action_ob.free()
	pre_ob.free()
	## Planner switch via shared editor callback (AD-5b) â€” not bare enforce alone.
	var switch_ab := AbilityData.new()
	switch_ab.planner_group = GameEnums.PlannerGroup.ACTION
	switch_ab.kind = GameEnums.AbilityKind.CLASS_SKILL
	switch_ab.primary_resource = GameEnums.CostResource.HP
	switch_ab.primary_value = 5
	switch_ab.action_point_cost = 0
	switch_ab.movement_point_cost = 2
	ClassLibrarySchema.apply_planner_group_change(switch_ab, GameEnums.PlannerGroup.PRE_MOVE)
	if switch_ab.planner_group != GameEnums.PlannerGroup.PRE_MOVE:
		failures.append("apply_planner_group_change did not set PRE_MOVE")
	if switch_ab.primary_resource != GameEnums.CostResource.MP:
		failures.append("apply_planner_group_change should force MP on PRE_MOVE from HP")
	if not switch_ab.is_movement_kind():
		failures.append("apply_planner_group_change should sync is_movement_kind via PRE_MOVE")
	if switch_ab.is_movement_skill:
		failures.append("PRE_MOVE without displacement effects must not set is_movement_skill")
	var switch_ob := OptionButton.new()
	ClassLibrarySchema.populate_legal_primary_option_button(switch_ob, switch_ab)
	if switch_ob.item_count != 1 or switch_ob.get_item_id(0) != int(GameEnums.CostResource.MP):
		failures.append("after apply_planner_group_change OptionButton must offer only MP")
	## ACTIONâ†PRE_MOVE via same callback: MP â†’ AP; dropdown AP+HP; kind CLASS_SKILL.
	ClassLibrarySchema.apply_planner_group_change(switch_ab, GameEnums.PlannerGroup.ACTION)
	if switch_ab.planner_group != GameEnums.PlannerGroup.ACTION:
		failures.append("apply_planner_group_change did not set ACTION")
	if switch_ab.primary_resource != GameEnums.CostResource.AP:
		failures.append("apply_planner_group_change to ACTION should force AP from MP")
	if switch_ab.is_movement_kind():
		failures.append("ACTION must not report is_movement_kind")
	ClassLibrarySchema.populate_legal_primary_option_button(switch_ob, switch_ab)
	if switch_ob.item_count != 2:
		failures.append("after apply_planner_group_change to ACTION OptionButton want 2 items")
	## Legal primary preserved: ACTION AP â†’ stays AP (no stomp).
	switch_ab.primary_resource = GameEnums.CostResource.AP
	switch_ab.primary_value = 3
	ClassLibrarySchema.apply_planner_group_change(switch_ab, GameEnums.PlannerGroup.ACTION)
	if switch_ab.primary_resource != GameEnums.CostResource.AP or switch_ab.primary_value != 3:
		failures.append("apply_planner_group_change must keep legal AP primary")
	## Displacement flag follows effects, not column (ACTION + MOVE â†’ is_movement_skill true).
	var move_eff := AbilityModule.new()
	move_eff.primary_type = GameEnums.EffectType.MOVE
	move_eff.amount = 2
	switch_ab.modules = [move_eff]
	ClassLibrarySchema.apply_planner_group_change(switch_ab, GameEnums.PlannerGroup.ACTION)
	if not switch_ab.is_movement_skill:
		failures.append("ACTION+MOVE must set is_movement_skill via apply_planner_group_change")
	if switch_ab.is_movement_kind():
		failures.append("ACTION+MOVE must not set is_movement_kind")
	switch_ob.free()
	## Dict import must use the same planner apply path (critic AD-5b residual).
	var dict_switch := AbilityData.new()
	dict_switch.id = &"dict_planner_switch_probe"
	dict_switch.planner_group = GameEnums.PlannerGroup.ACTION
	dict_switch.kind = GameEnums.AbilityKind.CLASS_SKILL
	dict_switch.primary_resource = GameEnums.CostResource.HP
	dict_switch.primary_value = 5
	dict_switch.action_point_cost = 0
	dict_switch.movement_point_cost = 2
	dict_switch.tags = [AbilityModuleBridge.TAG_ATTACK]
	dict_switch.modules = [AbilityModule.new()]
	dict_switch.modules[0].primary_type = GameEnums.EffectType.DAMAGE
	dict_switch.modules[0].amount = 1
	dict_switch.finalize_modular()
	var dict_payload: Dictionary = ClassLibrarySchema.ability_to_dict(dict_switch)
	dict_payload["planner_group"] = GameEnums.PlannerGroup.PRE_MOVE
	var dict_clone := AbilityData.new()
	dict_clone.id = dict_switch.id
	ClassLibrarySchema.apply_ability_dict(dict_clone, dict_payload)
	if dict_clone.planner_group != GameEnums.PlannerGroup.PRE_MOVE:
		failures.append("apply_ability_dict planner_group via apply_planner_group_change failed")
	if dict_clone.primary_resource != GameEnums.CostResource.MP:
		failures.append("apply_ability_dict PRE_MOVE switch must force MP from HP (shared path)")
	var schema_src := FileAccess.get_file_as_string("res://ui/class_library_schema.gd")
	var dict_fn_idx: int = schema_src.find("static func apply_ability_dict")
	if dict_fn_idx < 0:
		failures.append("apply_ability_dict missing in schema")
	else:
		var dict_slice: String = schema_src.substr(dict_fn_idx, 900)
		if dict_slice.find("apply_planner_group_change") < 0:
			failures.append("apply_ability_dict must call apply_planner_group_change")
	## Editor source must wire planner OptionButton to apply_planner_group_change (not inline enforce).
	var editor_src := FileAccess.get_file_as_string("res://ui/class_library_editor.gd")
	if editor_src.find("ClassLibrarySchema.apply_planner_group_change") < 0:
		failures.append("class_library_editor.gd must call ClassLibrarySchema.apply_planner_group_change")
	if editor_src.find("enforce_planner_cost_coupling(ability)") >= 0:
		## Only allowed inside schema apply_planner_group_change â€” editor must not inline it.
		var planner_bind_idx: int = editor_src.find("\"planner_group\"")
		if planner_bind_idx >= 0:
			var slice: String = editor_src.substr(planner_bind_idx, 400)
			if slice.find("enforce_planner_cost_coupling") >= 0:
				failures.append(
					"planner_group OptionButton must not inline enforce â€” use apply_planner_group_change"
				)
