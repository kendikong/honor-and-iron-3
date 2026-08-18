class_name IntentSourceOfTruthGateTest
extends RefCounted

## Phase 1 source-of-truth gate: last valid preview slots == finalized slots ==
## committed timeline == Simulator result for the seven reference journeys.


static func run_all(failures: Array[String]) -> void:
	_test_walk_01(failures)
	_test_move_skill_01(failures)
	_test_push_pull_01(failures)
	_test_swap_01(failures)
	_test_await_01(failures)
	_test_trample_01(failures)
	_test_stale_01(failures)


static func _test_walk_01(failures: Array[String]) -> void:
	PlanningDragE2EHarness.cleanup_all()
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	PlanningChecklistHarness.enter_basic_movement(fix)
	_assert_valid_four_way(
		failures,
		"WALK-01",
		fix,
		PlanningChecklistHarness.BASH_HOVER_WALK,
		fix.director.selected_unit_id,
	)
	PlanningDragE2EHarness.cleanup_all()


static func _test_move_skill_01(failures: Array[String]) -> void:
	PlanningDragE2EHarness.cleanup_all()
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	if PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.SHIELD_BASH_ID) < 0:
		PlanningChecklistHarness.assert_fail(failures, "MOVE-SKILL-01", "Shield Bash missing")
		PlanningDragE2EHarness.cleanup_all()
		return
	_assert_valid_four_way(
		failures,
		"MOVE-SKILL-01",
		fix,
		PlanningChecklistHarness.ENEMY_POS,
		fix.director.selected_unit_id,
	)
	PlanningDragE2EHarness.cleanup_all()


static func _test_push_pull_01(failures: Array[String]) -> void:
	PlanningDragE2EHarness.cleanup_all()
	var bash_fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	if PlanningChecklistHarness.select_ability(bash_fix, PlanningChecklistHarness.SHIELD_BASH_ID) < 0:
		PlanningChecklistHarness.assert_fail(failures, "PUSH-PULL-01/bash", "Shield Bash missing")
	else:
		_assert_valid_four_way(
			failures,
			"PUSH-PULL-01/bash",
			bash_fix,
			PlanningChecklistHarness.ENEMY_POS,
			bash_fix.director.selected_unit_id,
		)
	PlanningDragE2EHarness.cleanup_all()
	var hook_fix: Dictionary = PlanningChecklistHarness.wire_hook_board()
	if PlanningChecklistHarness.select_ability(hook_fix, PlanningChecklistHarness.CHAIN_HOOK_ID) < 0:
		PlanningChecklistHarness.assert_fail(failures, "PUSH-PULL-01/hook", "Chain Hook missing")
	else:
		_assert_valid_four_way(
			failures,
			"PUSH-PULL-01/hook",
			hook_fix,
			PlanningChecklistHarness.HOOK_ENEMY_POS,
			hook_fix.director.selected_unit_id,
		)
	PlanningDragE2EHarness.cleanup_all()


static func _test_swap_01(failures: Array[String]) -> void:
	PlanningDragE2EHarness.cleanup_all()
	var fix: Dictionary = PlanningChecklistHarness.wire_swap_board(
		PlanningChecklistHarness.SWAP_ALLY_CELL,
	)
	var k1_id: int = int(fix.k1_id)
	if (
		PlanningChecklistHarness.select_ability_for_unit(
			fix, k1_id, PlanningChecklistHarness.KNIGHT_SWAP_ID
		)
		< 0
	):
		PlanningChecklistHarness.assert_fail(failures, "SWAP-01", "swap ability missing")
		PlanningDragE2EHarness.cleanup_all()
		return
	PlanningChecklistHarness.select_unit(fix, k1_id, PlanningChecklistHarness.SWAP_ALLY_CELL)
	_assert_valid_four_way(
		failures,
		"SWAP-01",
		fix,
		PlanningChecklistHarness.SWAP_ALLY_CELL,
		k1_id,
	)
	PlanningDragE2EHarness.cleanup_all()


static func _test_await_01(failures: Array[String]) -> void:
	PlanningDragE2EHarness.cleanup_all()
	var fix: Dictionary = PlanningQAGateTest._planning_fixture(Vector2i(1, 3), Vector2i(4, 3))
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var hook_idx: int = PlanningQAGateTest._ability_index(fix.knight, PlanningChecklistHarness.CHAIN_HOOK_ID)
	if hook_idx < 0:
		PlanningChecklistHarness.assert_fail(failures, "AWAIT-01", "Chain Hook missing")
		PlanningDragE2EHarness.cleanup_all()
		return
	director.selected_ability_index = hook_idx
	var empty_wps: Array[Vector2i] = []
	var empty_legal: Array[Vector2i] = []
	var wrong_slots: Dictionary = input._final_commit_slots_for_interaction(
		1, Vector2i(11, 11), empty_wps, empty_legal, Vector2i(-999999, -999999),
	)
	if not PlanningChecklistHarness.slots_invalid(wrong_slots):
		PlanningChecklistHarness.assert_fail(
			failures, "AWAIT-01", "far hover must not be a valid hook target",
		)
	else:
		if director.commit_from_slots(1, wrong_slots):
			PlanningChecklistHarness.assert_fail(
				failures, "AWAIT-01", "invalid awaiting hover must not commit",
			)
		if not director.plan_action.entries.is_empty():
			PlanningChecklistHarness.assert_fail(
				failures, "AWAIT-01", "rejected hook must not reach the action column",
			)
	var preview_slots: Dictionary = input._final_commit_slots_for_interaction(
		1, Vector2i(4, 3), empty_wps, empty_legal, Vector2i(-999999, -999999),
	)
	var commit_slots: Dictionary = input._final_commit_slots_for_interaction(
		1, Vector2i(4, 3), empty_wps.duplicate(), empty_legal.duplicate(), Vector2i(-999999, -999999),
	)
	_assert_slot_commit_sim(failures, "AWAIT-01", director, 1, preview_slots, commit_slots)
	PlanningDragE2EHarness.cleanup_all()


static func _test_trample_01(failures: Array[String]) -> void:
	PlanningDragE2EHarness.cleanup_all()
	var fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(TramplingAdvanceE2ETest.START_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	if int(fix.trample_idx) < 0:
		PlanningChecklistHarness.assert_fail(failures, "TRAMPLE-01", "Trampling Advance missing")
		PlanningDragE2EHarness.cleanup_all()
		return
	if not TramplingAdvanceE2ETest._arm_trample_awaiting(input, director, unit):
		PlanningChecklistHarness.assert_fail(failures, "TRAMPLE-01", "arm awaiting failed")
		PlanningDragE2EHarness.cleanup_all()
		return
	var route: Array[Vector2i] = [
		TramplingAdvanceE2ETest.START_CELL,
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[0],
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[1],
	]
	TramplingAdvanceE2ETest._paint_drag_route(input, unit, route, TramplingAdvanceE2ETest.END_CELL)
	var params: Dictionary = input._commit_interaction_params(TramplingAdvanceE2ETest.END_CELL, -1)
	var preview_slots: Dictionary = input._final_commit_slots_for_interaction(
		1,
		params.cell,
		params.waypoints,
		params.legal_move_tiles,
		params.preferred,
		int(params.get("face_dir", -1)),
	)
	var commit_slots: Dictionary = input._final_commit_slots_for_interaction(
		1,
		params.cell,
		params.waypoints,
		params.legal_move_tiles,
		params.preferred,
		int(params.get("face_dir", -1)),
	)
	input.dragging = false
	_assert_slot_commit_sim(failures, "TRAMPLE-01", director, 1, preview_slots, commit_slots)
	var committed: TimelineAction = TramplingAdvanceE2ETest._committed_trample_action(director)
	if committed == null or committed.waypoints != TramplingAdvanceE2ETest.EAST_THEN_NORTH:
		PlanningChecklistHarness.assert_fail(
			failures,
			"TRAMPLE-01",
			"committed trample waypoints %s expected %s"
			% [
				str(committed.waypoints if committed != null else null),
				str(TramplingAdvanceE2ETest.EAST_THEN_NORTH),
			],
		)
	PlanningDragE2EHarness.cleanup_all()


static func _test_stale_01(failures: Array[String]) -> void:
	PlanningDragE2EHarness.cleanup_all()
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	if PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.SHIELD_BASH_ID) < 0:
		PlanningChecklistHarness.assert_fail(failures, "STALE-01", "Shield Bash missing")
		PlanningDragE2EHarness.cleanup_all()
		return
	var director: CombatDirector = fix.director
	var oob: Dictionary = PlanningChecklistHarness.slots_for_click(fix, Vector2i(-1, 0))
	if not PlanningChecklistHarness.slots_invalid(oob):
		PlanningChecklistHarness.assert_fail(failures, "STALE-01", "OOB hover must be invalid")
		PlanningDragE2EHarness.cleanup_all()
		return
	var pre_before: int = director.plan_pre_move.entries.size()
	var action_before: int = director.plan_action.entries.size()
	if director.commit_from_slots(director.selected_unit_id, oob):
		PlanningChecklistHarness.assert_fail(
			failures, "STALE-01", "invalid slots must not commit",
		)
	if (
		director.plan_pre_move.entries.size() != pre_before
		or director.plan_action.entries.size() != action_before
	):
		PlanningChecklistHarness.assert_fail(
			failures, "STALE-01", "rejected intent must not mutate the timeline",
		)
	PlanningDragE2EHarness.cleanup_all()


static func _assert_valid_four_way(
	failures: Array[String],
	label: String,
	fix: Dictionary,
	cell: Vector2i,
	unit_id: int,
) -> void:
	PlanningChecklistHarness.hover(fix, cell)
	var hover_slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, cell)
	var hover_again: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, cell)
	var click_slots: Dictionary = PlanningChecklistHarness.slots_for_click(fix, cell)
	var hover_sig: String = PlanningQAGateTest._intent_slot_signature(hover_slots)
	if hover_sig != PlanningQAGateTest._intent_slot_signature(hover_again):
		PlanningChecklistHarness.assert_fail(
			failures, label, "repeat hover must keep the same slot signature",
		)
		return
	if hover_sig != PlanningQAGateTest._intent_slot_signature(click_slots):
		PlanningChecklistHarness.assert_fail(
			failures, label, "hover slots must match click slots",
		)
		return
	if PlanningChecklistHarness.slots_invalid(hover_slots):
		PlanningChecklistHarness.assert_fail(failures, label, "expected valid hover slots")
		return
	var preview_pos: Vector2i = PlanningChecklistHarness.preview_unit_pos(fix, unit_id)
	var stand: Vector2i = CombatPlanningPreview.planning_latest_stand_cell(
		fix.director, fix.director.board, unit_id,
	)
	if not PlanningChecklistHarness.commit_slots_production(fix, click_slots):
		PlanningChecklistHarness.assert_fail(failures, label, "commit_from_slots rejected valid slots")
		return
	var timeline_sig: String = PlanningQAGateTest._intent_slot_signature_from_timeline(
		fix.director, unit_id,
	)
	if hover_sig != timeline_sig:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"committed timeline %s != preview slots %s" % [timeline_sig, hover_sig],
		)
		return
	var result: SimResult = PlanningChecklistHarness.simulate_committed(fix.director)
	var player_board: BoardState = PlanningChecklistHarness.simulate_player_committed(fix.director)
	_assert_comparison_four(
		failures, label, fix, unit_id, preview_pos, stand, player_board, result,
	)


static func _assert_slot_commit_sim(
	failures: Array[String],
	label: String,
	director: CombatDirector,
	unit_id: int,
	preview_slots: Dictionary,
	commit_slots: Dictionary,
) -> void:
	var preview_sig: String = PlanningQAGateTest._intent_slot_signature(preview_slots)
	if preview_sig != PlanningQAGateTest._intent_slot_signature(commit_slots):
		PlanningChecklistHarness.assert_fail(
			failures, label, "preview slots must match finalized commit slots",
		)
		return
	if PlanningChecklistHarness.slots_invalid(preview_slots):
		PlanningChecklistHarness.assert_fail(failures, label, "expected valid preview slots")
		return
	if not director.commit_from_slots(unit_id, commit_slots):
		PlanningChecklistHarness.assert_fail(failures, label, "commit_from_slots rejected valid slots")
		return
	director.flush_plan_refresh_signals_if_pending()
	var timeline_sig: String = PlanningQAGateTest._intent_slot_signature_from_timeline(
		director, unit_id,
	)
	if preview_sig != timeline_sig:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"committed timeline %s != preview slots %s" % [timeline_sig, preview_sig],
		)
		return
	var player_board: BoardState = PlanningChecklistHarness.simulate_player_committed(director)
	var result: SimResult = PlanningChecklistHarness.simulate_committed(director)
	_assert_player_phase_matches(
		failures, label, director.projected_state, player_board, result,
	)


static func _assert_comparison_four(
	failures: Array[String],
	label: String,
	fix: Dictionary,
	unit_id: int,
	preview_pos: Vector2i,
	stand: Vector2i,
	player_board: BoardState,
	result: SimResult,
) -> void:
	if result == null or result.final_state == null:
		PlanningChecklistHarness.assert_fail(failures, label, "Simulator returned no result")
		return
	var sim_sig: String = PlanningQAGateTest._sim_result_signature(result)
	if not sim_sig.begins_with("units="):
		PlanningChecklistHarness.assert_fail(failures, label, "sim signature missing units= prefix")
		return
	var player_unit: UnitState = (
		player_board.get_unit_by_id(unit_id) if player_board != null else null
	)
	if player_unit == null:
		PlanningChecklistHarness.assert_fail(failures, label, "actor missing from player-turn sim")
		return
	var committed_pos: Vector2i = PlanningChecklistHarness.preview_unit_pos(fix, unit_id)
	if player_unit.position != committed_pos and player_unit.position != preview_pos:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"player-turn pos %s != preview/commit %s / %s stand %s (sig %s)"
			% [
				str(player_unit.position),
				str(preview_pos),
				str(committed_pos),
				str(stand),
				sim_sig,
			],
		)
	_assert_player_phase_matches(
		failures, label, fix.director.projected_state, player_board, result,
	)


static func _assert_player_phase_matches(
	failures: Array[String],
	label: String,
	projected: BoardState,
	player_board: BoardState,
	result: SimResult,
) -> void:
	if projected == null:
		PlanningChecklistHarness.assert_fail(failures, label, "projected board missing after commit")
		return
	if player_board == null:
		PlanningChecklistHarness.assert_fail(failures, label, "player-turn sim missing")
		return
	var sim_sig: String = PlanningQAGateTest._sim_result_signature(result)
	for unit: UnitState in projected.units:
		if unit.team != GameEnums.Team.PLAYER:
			continue
		var player_u: UnitState = player_board.get_unit_by_id(unit.id)
		if player_u == null:
			PlanningChecklistHarness.assert_fail(
				failures, label, "player %d missing after player-turn sim (%s)" % [unit.id, sim_sig],
			)
			continue
		if player_u.position != unit.position:
			PlanningChecklistHarness.assert_fail(
				failures,
				label,
				"player %d player-turn pos %s != projected %s (%s)"
				% [unit.id, str(player_u.position), str(unit.position), sim_sig],
			)
		var proj_ap: int = unit.ability.points_left if unit.ability != null else 0
		var turn_ap: int = player_u.ability.points_left if player_u.ability != null else 0
		if proj_ap != turn_ap:
			PlanningChecklistHarness.assert_fail(
				failures,
				label,
				"player %d player-turn AP %d != projected %d (%s)"
				% [unit.id, turn_ap, proj_ap, sim_sig],
			)
		var proj_mp: int = unit.movement.points_left if unit.movement != null else 0
		var turn_mp: int = player_u.movement.points_left if player_u.movement != null else 0
		if proj_mp != turn_mp:
			PlanningChecklistHarness.assert_fail(
				failures,
				label,
				"player %d player-turn MP %d != projected %d (%s)"
				% [unit.id, turn_mp, proj_mp, sim_sig],
			)
