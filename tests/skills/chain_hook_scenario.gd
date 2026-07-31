class_name ChainHookScenarioTest
extends RefCounted

## 7-phase checklist for Chain Hook — in-range hook from (1,3) needs no approach walk.


static func run_all(failures: Array[String]) -> void:
	_phase1_select(failures)
	_phase2_hover_empty(failures)
	_phase3_pathing_optional(failures)
	_phase4_hover_enemy(failures)
	_phase5_commit(failures)
	_phase6_execute(failures)
	_phase7_committed_premove(failures)


static func _hook_ability(fix: Dictionary) -> AbilityData:
	var idx: int = PlanningChecklistHarness.ability_index(
		fix.knight, PlanningChecklistHarness.CHAIN_HOOK_ID,
	)
	return fix.knight.active_abilities[idx] if idx >= 0 else null


static func _phase1_select(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_hook_board()
	var ability: AbilityData = _hook_ability(fix)
	if PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.CHAIN_HOOK_ID) < 0:
		PlanningChecklistHarness.assert_fail(failures, "hook/phase1", "Chain Hook missing")
		return
	var hook_idx: int = PlanningChecklistHarness.ability_index(
		fix.knight, PlanningChecklistHarness.CHAIN_HOOK_ID,
	)
	PlanningChecklistHarness.assert_preview_approach_tile(
		failures, "hook/phase1/approach_tile", fix, 2, hook_idx,
		PlanningChecklistHarness.HOOK_ENEMY_POS,
		PlanningChecklistHarness.HOOK_KNIGHT_START,
	)
	PlanningChecklistHarness.assert_ability_kind_class(failures, "hook/phase1", ability)
	PlanningChecklistHarness.assert_eq_int(failures, "hook/phase1/ap", fix.knight.ability.points_left, 1)
	PlanningChecklistHarness.assert_red_contract(
		failures, "hook/phase1/red_at_stand", fix, ability, true, PlanningChecklistHarness.HOOK_KNIGHT_START,
	)
	PlanningChecklistHarness.assert_red_includes_cell(
		failures, "hook/phase1/enemy_in_range",
		fix, ability, PlanningChecklistHarness.HOOK_KNIGHT_START, PlanningChecklistHarness.HOOK_ENEMY_POS,
	)


static func _phase2_hover_empty(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_hook_board()
	var ability: AbilityData = _hook_ability(fix)
	PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.CHAIN_HOOK_ID)
	var cell: Vector2i = Vector2i(2, 3)
	PlanningChecklistHarness.hover(fix, cell)
	PlanningChecklistHarness.assert_eq_cell(
		failures, "hook/phase2/ghost", PlanningChecklistHarness.preview_unit_pos(fix, 1), cell,
	)
	PlanningChecklistHarness.assert_red_contract(failures, "hook/phase2/red", fix, ability, true, cell)
	PlanningChecklistHarness.assert_red_includes_cell(
		failures, "hook/phase2/enemy_still_in_red",
		fix, ability, cell, PlanningChecklistHarness.HOOK_ENEMY_POS,
	)


static func _phase3_pathing_optional(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_hook_board()
	var ability: AbilityData = _hook_ability(fix)
	PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.CHAIN_HOOK_ID)
	var route: Array[Vector2i] = [
		PlanningChecklistHarness.HOOK_KNIGHT_START,
		Vector2i(2, 3),
		Vector2i(3, 3),
	]
	PlanningDragE2EHarness.begin_drag_route(fix, route)
	PlanningChecklistHarness.hover(fix, Vector2i(3, 3))
	PlanningChecklistHarness.assert_red_contract(failures, "hook/phase3/red", fix, ability, true, Vector2i(3, 3))


static func _phase4_hover_enemy(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_hook_board()
	PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.CHAIN_HOOK_ID)
	PlanningChecklistHarness.hover(fix, PlanningChecklistHarness.HOOK_ENEMY_POS)
	var hook_idx: int = PlanningChecklistHarness.ability_index(
		fix.knight, PlanningChecklistHarness.CHAIN_HOOK_ID,
	)
	PlanningChecklistHarness.assert_preview_approach_tile(
		failures, "hook/phase4/approach_tile", fix, 2, hook_idx,
		PlanningChecklistHarness.HOOK_ENEMY_POS,
		PlanningChecklistHarness.HOOK_KNIGHT_START,
	)
	# At range 3, preview_approach_tile returns actor.position — knight stays at start.
	PlanningChecklistHarness.assert_eq_cell(
		failures, "hook/phase4/ghost_stand",
		PlanningChecklistHarness.preview_unit_pos(fix, 1), PlanningChecklistHarness.HOOK_KNIGHT_START,
	)
	var push_to: Vector2i = PlanningChecklistHarness.push_destination(fix, 2)
	PlanningChecklistHarness.assert_true(
		failures, "hook/phase4/pull_west",
		push_to.x < PlanningChecklistHarness.HOOK_ENEMY_POS.x,
		"pull must move enemy west from %s to %s"
		% [PlanningChecklistHarness.HOOK_ENEMY_POS, push_to],
	)
	var pv_enemy: UnitState = fix.input.preview_state.preview_board.get_unit_by_id(2)
	PlanningChecklistHarness.assert_true(
		failures, "hook/phase4/preview_landing",
		pv_enemy != null and pv_enemy.position == push_to,
		"preview enemy at pull landing %s" % push_to,
	)
	var slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, PlanningChecklistHarness.HOOK_ENEMY_POS)
	var action: Array = slots.get("action", []) as Array
	PlanningChecklistHarness.assert_true(
		failures, "hook/phase4/action_slot",
		not action.is_empty(),
		"enemy hover must fill action slot",
	)
	if not action.is_empty() and action[0] is TimelineAction:
		var hook_step: TimelineAction = action[0] as TimelineAction
		PlanningChecklistHarness.assert_eq_int(
			failures, "hook/phase4/target",
			hook_step.target_unit_id, 2,
		)


static func _phase5_commit(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_hook_board()
	PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.CHAIN_HOOK_ID)
	PlanningChecklistHarness.hover(fix, PlanningChecklistHarness.HOOK_ENEMY_POS)
	PlanningChecklistHarness.assert_commit_no_jump(
		failures, "hook/phase5/no_jump", fix, PlanningChecklistHarness.HOOK_ENEMY_POS,
	)
	PlanningChecklistHarness.assert_eq_int(
		failures, "hook/phase5/ap_after",
		PlanningChecklistHarness.projected_unit(fix, 1).ability.points_left, 0,
	)
	var ability: AbilityData = _hook_ability(fix)
	PlanningChecklistHarness.assert_true(
		failures, "hook/phase5/cannot_replan",
		not AbilitySystem.can_plan(
			PlanningChecklistHarness.projected_unit(fix, 1),
			ability,
			fix.director.projected_state,
		),
		"0 AP after hook commit must block replan (overlay may still show range tint)",
	)


static func _phase6_execute(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_hook_board()
	PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.CHAIN_HOOK_ID)
	PlanningChecklistHarness.hover(fix, PlanningChecklistHarness.HOOK_ENEMY_POS)
	var expected_enemy: Vector2i = PlanningChecklistHarness.push_destination(fix, 2)
	PlanningChecklistHarness.commit_production(fix, PlanningChecklistHarness.HOOK_ENEMY_POS)
	var result: SimResult = PlanningChecklistHarness.simulate_committed(fix.director)
	var knight: UnitState = result.final_state.get_unit_by_id(1)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	PlanningChecklistHarness.assert_eq_cell(
		failures, "hook/phase6/knight",
		knight.position if knight != null else Vector2i(-1, -1),
		PlanningChecklistHarness.HOOK_KNIGHT_START,
	)
	PlanningChecklistHarness.assert_eq_cell(
		failures, "hook/phase6/enemy",
		enemy.position if enemy != null else Vector2i(-1, -1),
		expected_enemy,
	)
	PlanningChecklistHarness.assert_player_turn_ap_spent(
		failures, "hook/phase6/ap_spent", fix.director, 1, 0,
	)


static func _phase7_committed_premove(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_hook_board()
	fix.director.selected_ability_index = -1
	fix.input.force_basic_movement = true
	fix.input.auto_use_skill_after_move = false
	var walk_dest: Vector2i = Vector2i(2, 3)
	PlanningChecklistHarness.commit_production(fix, walk_dest)
	PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.CHAIN_HOOK_ID)
	PlanningChecklistHarness.hover(fix, PlanningChecklistHarness.HOOK_ENEMY_POS)
	var slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, PlanningChecklistHarness.HOOK_ENEMY_POS)
	var action: Array = slots.get("action", []) as Array
	var post: Array = slots.get("post", []) as Array
	PlanningChecklistHarness.assert_true(
		failures, "hook/phase7/action_slot",
		not action.is_empty(),
		"walk + in-range enemy hover must fill hook action (range skill, no approach walk)",
	)
	PlanningChecklistHarness.assert_true(
		failures, "hook/phase7/no_post",
		post.is_empty(),
		"hook must not use post-move column",
	)
