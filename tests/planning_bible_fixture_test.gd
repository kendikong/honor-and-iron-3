extends RefCounted

const _Probe := preload("res://tests/planning_bible_fixture_probe.gd")

## Fixture Parity Suite: continuous K1–K4 bible session, hover edges, swap journeys.


static func run_all(failures: Array[String]) -> void:
	_test_bible_continuous_session(failures)
	_test_k1_hover_edges(failures)
	_test_swap_adjacent_premove(failures)
	_test_swap_walk_then_swap(failures)


static func _test_bible_continuous_session(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bible_board()
	var director: CombatDirector = fix.director
	var expect: Dictionary = {}
	var k1_id: int = fix.k1_id as int
	var k2_id: int = fix.k2_id as int
	var k3_id: int = fix.k3_id as int
	var k4_id: int = fix.k4_id as int
	var e_bash_id: int = fix.e_bash_id as int
	var e_hook_id: int = fix.e_hook_id as int

	director.auto_run = true
	fix.input.auto_use_skill_after_move = true

	_journey_k1_bash(fix, failures, k1_id, e_bash_id, expect)
	_journey_k2_hook(fix, failures, k2_id, e_hook_id, expect)
	_journey_k3_trample(fix, failures, k3_id, expect)
	_journey_k4_run(fix, failures, k4_id, expect)
	_execute_and_assert_positions(fix, failures, expect, k1_id, k2_id, k3_id, k4_id, e_bash_id, e_hook_id)


static func _journey_k1_bash(
	fix: Dictionary,
	failures: Array[String],
	k1_id: int,
	e_bash_id: int,
	expect: Dictionary,
) -> void:
	PlanningChecklistHarness.select_unit(fix, k1_id, PlanningChecklistHarness.KNIGHT_START)
	PlanningChecklistHarness.set_unit_pools(fix, k1_id, 1, 3)
	var bash_idx: int = PlanningChecklistHarness.select_ability_for_unit(
		fix, k1_id, PlanningChecklistHarness.SHIELD_BASH_ID,
	)
	var bash: AbilityData = null
	if bash_idx >= 0:
		bash = fix.board.get_unit_by_id(k1_id).active_abilities[bash_idx]

	_Probe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.KNIGHT_START, {
			"red_on": true,
			"red_stand": PlanningChecklistHarness.KNIGHT_START,
			"ability": bash,
			"blue_any": true,
		}, "bible/k1/stand",
	)
	_Probe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.BASH_HOVER_WALK, {
			"ghost_pos": PlanningChecklistHarness.BASH_HOVER_WALK,
			"path_end": PlanningChecklistHarness.BASH_HOVER_WALK,
			"path_start": PlanningChecklistHarness.KNIGHT_START,
			"path_min_size": 2,
			"manhattan": true,
			"blue_any": true,
		}, "bible/k1/walk",
	)
	var push_to: Vector2i = Vector2i(-999999, -999999)
	PlanningChecklistHarness.select_unit(fix, k1_id, PlanningChecklistHarness.ENEMY_POS)
	PlanningChecklistHarness.refresh_attack_hover(fix, PlanningChecklistHarness.ENEMY_POS)
	push_to = PlanningChecklistHarness.push_destination(fix, e_bash_id)
	_Probe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.ENEMY_POS, {
			"path_end": PlanningChecklistHarness.BASH_APPROACH,
			"path_start": PlanningChecklistHarness.KNIGHT_START,
			"path_min_size": 3,
			"manhattan": true,
			"blue_any": true,
			"red_on": true,
			"red_stand": PlanningChecklistHarness.BASH_APPROACH,
			"ability": bash,
			"push_dest": push_to,
			"push_enemy_id": e_bash_id,
		}, "bible/k1/enemy_hover",
	)

	if not PlanningChecklistHarness.commit_painted_click_on_cell(
		fix,
		PlanningChecklistHarness.K1_BASH_ROUTE,
		PlanningChecklistHarness.ENEMY_POS,
	):
		PlanningChecklistHarness.assert_fail(failures, "bible/k1/commit", "waypoint bash click commit failed")
		return
	var committed_pre: TimelineAction = PlanningChecklistHarness.committed_pre_move(fix.director, k1_id)
	if committed_pre == null or committed_pre.waypoints != PlanningChecklistHarness.K1_BASH_WAYPOINTS:
		PlanningChecklistHarness.assert_fail(
			failures,
			"bible/k1/commit",
			"bash pre-move waypoints must ratify painted route %s, got %s"
			% [PlanningChecklistHarness.K1_BASH_WAYPOINTS, committed_pre.waypoints if committed_pre != null else null],
		)

	PlanningChecklistHarness.assert_red_contract(
		failures,
		"bible/k1/post_commit",
		fix,
		bash,
		false,
		PlanningChecklistHarness.BASH_APPROACH,
		k1_id,
	)
	PlanningChecklistHarness.assert_enemy_live_unchanged(
		failures, "bible/k1/post_commit", fix, e_bash_id, PlanningChecklistHarness.E_BASH_CELL,
	)
	var bashed: UnitState = PlanningChecklistHarness.projected_unit(fix, e_bash_id)
	if bashed != null and bashed.position.x <= PlanningChecklistHarness.E_BASH_CELL.x:
		PlanningChecklistHarness.assert_fail(
			failures,
			"bible/k1/preview_push",
			"projected enemy must show bash push (got %s)" % bashed.position,
		)
	expect["k1_pos"] = PlanningChecklistHarness.BASH_APPROACH
	expect["e_bash_pos"] = bashed.position if bashed != null else PlanningChecklistHarness.E_BASH_CELL


static func _journey_k2_hook(
	fix: Dictionary,
	failures: Array[String],
	k2_id: int,
	e_hook_id: int,
	expect: Dictionary,
) -> void:
	var hook_idx: int = PlanningChecklistHarness.select_ability_for_unit(
		fix, k2_id, PlanningChecklistHarness.CHAIN_HOOK_ID,
	)
	var hook: AbilityData = null
	if hook_idx >= 0:
		hook = fix.board.get_unit_by_id(k2_id).active_abilities[hook_idx]

	_Probe.probe_cell(
		failures, fix, k2_id, PlanningChecklistHarness.K2_CELL, {
			"red_on": true,
			"red_stand": PlanningChecklistHarness.K2_CELL,
			"ability": hook,
			"red_cell": {
				"cell": PlanningChecklistHarness.E_HOOK_CELL,
				"stand": PlanningChecklistHarness.K2_CELL,
				"in_range": true,
			},
			"blue_any": true,
		}, "bible/k2/stand",
	)
	var pull_preview: Vector2i = PlanningChecklistHarness.push_destination(fix, e_hook_id)
	_Probe.probe_cell(
		failures, fix, k2_id, PlanningChecklistHarness.E_HOOK_CELL, {
			"path_end": PlanningChecklistHarness.K2_CELL,
			"path_start": PlanningChecklistHarness.K2_CELL,
			"path_min_size": 1,
			"manhattan": true,
			"blue_any": true,
			"red_on": true,
			"red_stand": PlanningChecklistHarness.K2_CELL,
			"ability": hook,
			"pull_dest": pull_preview,
			"pull_enemy_id": e_hook_id,
		}, "bible/k2/enemy",
	)

	PlanningChecklistHarness.select_unit(fix, k2_id, PlanningChecklistHarness.K2_CELL)
	if PlanningChecklistHarness.slots_invalid(
		PlanningChecklistHarness.commit_production(fix, PlanningChecklistHarness.E_HOOK_CELL),
	):
		PlanningChecklistHarness.assert_fail(failures, "bible/k2/commit", "hook tap commit failed")
		return

	var hooked: UnitState = PlanningChecklistHarness.projected_unit(fix, e_hook_id)
	if hooked != null and hooked.position.x >= PlanningChecklistHarness.E_HOOK_CELL.x:
		PlanningChecklistHarness.assert_fail(
			failures,
			"bible/k2/pull",
			"hooked enemy must be pulled west (got %s)" % hooked.position,
		)
	expect["k2_pos"] = PlanningChecklistHarness.K2_CELL
	expect["e_hook_pos"] = hooked.position if hooked != null else PlanningChecklistHarness.E_HOOK_CELL


static func _journey_k3_trample(
	fix: Dictionary,
	failures: Array[String],
	k3_id: int,
	expect: Dictionary,
) -> void:
	var trample_idx: int = PlanningChecklistHarness.select_ability_for_unit(
		fix, k3_id, PlanningChecklistHarness.TRAMPLE_ID,
	)
	var trample: AbilityData = null
	if trample_idx >= 0:
		trample = fix.board.get_unit_by_id(k3_id).active_abilities[trample_idx]

	_Probe.probe_cell(
		failures, fix, k3_id, PlanningChecklistHarness.K3_CELL, {
			"blue_any": true,
			"red_on": true,
			"red_stand": PlanningChecklistHarness.K3_CELL,
			"ability": trample,
			"manhattan": true,
		}, "bible/k3/stand",
	)

	if not PlanningChecklistHarness.arm_trample_awaiting(fix, k3_id):
		PlanningChecklistHarness.assert_fail(failures, "bible/k3/arm", "trample arm failed")
		return

	_Probe.probe_cell(
		failures, fix, k3_id, PlanningChecklistHarness.TRAMPLE_END, {
			"path": PlanningChecklistHarness.TRAMPLE_FULL_PATH,
			"ghost_pos": PlanningChecklistHarness.TRAMPLE_END,
			"manhattan": true,
			"preview_nonempty": true,
		}, "bible/k3/hover_end",
	)

	var route: Array[Vector2i] = [
		PlanningChecklistHarness.K3_CELL,
		PlanningChecklistHarness.TRAMPLE_ROUTE[0],
		PlanningChecklistHarness.TRAMPLE_ROUTE[1],
	]
	if not PlanningChecklistHarness.commit_painted_drop_on_cell(
		fix, route, PlanningChecklistHarness.TRAMPLE_END,
	):
		PlanningChecklistHarness.assert_fail(failures, "bible/k3/commit", "trample drag commit failed")
		return

	PlanningChecklistHarness.assert_red_contract(
		failures,
		"bible/k3/post_trample",
		fix,
		trample,
		false,
		PlanningChecklistHarness.TRAMPLE_END,
		k3_id,
	)

	PlanningChecklistHarness.enter_basic_movement(fix)
	PlanningChecklistHarness.select_unit(fix, k3_id, PlanningChecklistHarness.TRAMPLE_END)
	_Probe.probe_cell(
		failures, fix, k3_id, PlanningChecklistHarness.TRAMPLE_POST_DEST, {
			"path": [
				PlanningChecklistHarness.K3_CELL,
				PlanningChecklistHarness.TRAMPLE_ROUTE[0],
				PlanningChecklistHarness.TRAMPLE_ROUTE[1],
				Vector2i(7, 3),
				Vector2i(8, 3),
				PlanningChecklistHarness.TRAMPLE_POST_DEST,
			],
			"ghost_pos": PlanningChecklistHarness.TRAMPLE_POST_DEST,
			"manhattan": true,
			"preview_nonempty": true,
		}, "bible/k3/post_hover",
	)

	if not PlanningChecklistHarness.commit_painted_drop_on_cell(
		fix,
		PlanningChecklistHarness.TRAMPLE_POST_ROUTE,
		PlanningChecklistHarness.TRAMPLE_POST_DEST,
	):
		PlanningChecklistHarness.assert_fail(failures, "bible/k3/post_commit", "post-trample move failed")
		return

	expect["k3_pos"] = PlanningChecklistHarness.TRAMPLE_POST_DEST


static func _journey_k4_run(
	fix: Dictionary,
	failures: Array[String],
	k4_id: int,
	expect: Dictionary,
) -> void:
	fix.director.auto_run = true
	fix.input.auto_use_skill_after_move = false
	var bowling_idx: int = PlanningChecklistHarness.select_ability_for_unit(
		fix, k4_id, PlanningChecklistHarness.BOWLING_CHARGE_ID,
	)
	var bowling: AbilityData = null
	if bowling_idx >= 0:
		bowling = fix.board.get_unit_by_id(k4_id).active_abilities[bowling_idx]

	PlanningChecklistHarness.select_unit(fix, k4_id, PlanningChecklistHarness.K4_START)
	for step_index: int in range(1, PlanningChecklistHarness.K4_DETOUR_PLUS_RUN_ROUTE.size()):
		var cell: Vector2i = PlanningChecklistHarness.K4_DETOUR_PLUS_RUN_ROUTE[step_index]
		var expected_path: Array[Vector2i] = []
		for j: int in range(step_index + 1):
			expected_path.append(PlanningChecklistHarness.K4_DETOUR_PLUS_RUN_ROUTE[j])
		_Probe.probe_cell(
			failures,
			fix,
			k4_id,
			cell,
			{"path": expected_path, "manhattan": true, "preview_nonempty": true},
			"bible/k4/step_%d" % step_index,
		)
		if cell == Vector2i(4, 2):
			_Probe.assert_k4_walk_loop(
				failures, fix, k4_id, bowling, cell, "bible/k4/walk_loop",
			)
		elif cell == PlanningChecklistHarness.K4_RUN_TRIGGER:
			_Probe.assert_k4_run_trigger(
				failures, fix, k4_id, "bible/k4/run_trigger",
			)

	if not PlanningChecklistHarness.commit_painted_drop_on_cell(
		fix,
		PlanningChecklistHarness.K4_DETOUR_PLUS_RUN_ROUTE,
		PlanningChecklistHarness.K4_RUN_TRIGGER,
	):
		PlanningChecklistHarness.assert_fail(failures, "bible/k4/commit", "k4 run route commit failed")
		return

	var k4_projected: UnitState = PlanningChecklistHarness.projected_unit(fix, k4_id)
	expect["k4_pos"] = k4_projected.position if k4_projected != null else PlanningChecklistHarness.K4_START


static func _execute_and_assert_positions(
	fix: Dictionary,
	failures: Array[String],
	expect: Dictionary,
	k1_id: int,
	k2_id: int,
	k3_id: int,
	k4_id: int,
	e_bash_id: int,
	e_hook_id: int,
) -> void:
	var director: CombatDirector = fix.director
	var result: SimResult = PlanningChecklistHarness.simulate_committed(director)
	var board: BoardState = result.final_state
	PlanningChecklistHarness.assert_eq_cell(
		failures, "bible/execute/k1", board.get_unit_by_id(k1_id).position, expect["k1_pos"] as Vector2i,
	)
	PlanningChecklistHarness.assert_eq_cell(
		failures, "bible/execute/k2", board.get_unit_by_id(k2_id).position, expect["k2_pos"] as Vector2i,
	)
	PlanningChecklistHarness.assert_eq_cell(
		failures, "bible/execute/k3", board.get_unit_by_id(k3_id).position, expect["k3_pos"] as Vector2i,
	)
	PlanningChecklistHarness.assert_eq_cell(
		failures, "bible/execute/k4", board.get_unit_by_id(k4_id).position, expect["k4_pos"] as Vector2i,
	)
	PlanningChecklistHarness.assert_eq_cell(
		failures,
		"bible/execute/e_bash",
		board.get_unit_by_id(e_bash_id).position,
		expect["e_bash_pos"] as Vector2i,
	)
	PlanningChecklistHarness.assert_eq_cell(
		failures,
		"bible/execute/e_hook",
		board.get_unit_by_id(e_hook_id).position,
		expect["e_hook_pos"] as Vector2i,
	)


static func _test_k1_hover_edges(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	var k1_id: int = 1
	PlanningChecklistHarness.select_unit(fix, k1_id, PlanningChecklistHarness.KNIGHT_START)
	var bash_idx: int = PlanningChecklistHarness.select_ability(
		fix, PlanningChecklistHarness.SHIELD_BASH_ID,
	)
	var bash: AbilityData = null
	if bash_idx >= 0:
		bash = fix.board.get_unit_by_id(k1_id).active_abilities[bash_idx]

	_Probe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.ENEMY_POS, {
			"ability": bash,
		}, "bible/k1_edges/from_enemy",
	)
	_Probe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.OFF_BLUE_CELL, {
			"blue_any": true,
			"blue_not": [PlanningChecklistHarness.OFF_BLUE_CELL],
			"red_on": true,
			"red_stand": PlanningChecklistHarness.KNIGHT_START,
			"ability": bash,
			"icon_is": PlanningIcons.GLYPH_NULL,
			"slots_invalid": true,
			"tiles_only_in_bounds": true,
		}, "bible/k1_edges/off_blue",
	)
	var off_slots: Dictionary = PlanningChecklistHarness.slots_for_click(
		fix, PlanningChecklistHarness.OFF_BLUE_CELL,
	)
	if not PlanningChecklistHarness.slots_invalid(off_slots):
		PlanningChecklistHarness.assert_fail(
			failures,
			"bible/k1_edges/off_blue_click",
			"off-blue click slots must be invalid",
		)

	PlanningChecklistHarness.hover_off_map(fix)
	_Probe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.OFF_MAP_HOVER, {
			"hover_oob": true,
			"blue_any": true,
			"red_on": true,
			"red_stand": PlanningChecklistHarness.KNIGHT_START,
			"ability": bash,
			"tiles_only_in_bounds": true,
		}, "bible/k1_edges/off_map",
	)


static func _test_swap_adjacent_premove(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_swap_board(
		PlanningChecklistHarness.SWAP_ALLY_CELL,
	)
	var director: CombatDirector = fix.director
	var k1_id: int = fix.k1_id as int
	var ally_id: int = fix.ally_id as int
	var start_mp: int = fix.start_k1_mp as int
	director.auto_run = true

	var swap_idx: int = PlanningChecklistHarness.select_ability_for_unit(
		fix, k1_id, PlanningChecklistHarness.KNIGHT_SWAP_ID,
	)
	if swap_idx < 0:
		PlanningChecklistHarness.assert_fail(failures, "bible/swap_adjacent", "swap ability missing")
		return

	_Probe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.SWAP_ALLY_CELL, {
			"blue_any": true,
			"manhattan": true,
			"preview_nonempty": true,
		}, "bible/swap/hover_ally",
	)

	PlanningChecklistHarness.select_unit(fix, k1_id, PlanningChecklistHarness.SWAP_ALLY_CELL)
	if PlanningChecklistHarness.slots_invalid(
		PlanningChecklistHarness.commit_production(fix, PlanningChecklistHarness.SWAP_ALLY_CELL),
	):
		PlanningChecklistHarness.assert_fail(failures, "bible/swap/commit", "swap commit failed")
		return

	PlanningChecklistHarness.assert_swap_board_layers(
		failures,
		"bible/swap/after_swap",
		fix,
		k1_id,
		ally_id,
		PlanningChecklistHarness.SWAP_ALLY_CELL,
		PlanningChecklistHarness.KNIGHT_START,
		start_mp - 1,
		1,
	)

	PlanningChecklistHarness.enter_basic_movement(fix)
	PlanningChecklistHarness.select_unit(fix, k1_id, PlanningChecklistHarness.SWAP_ALLY_CELL)
	var premove_route: Array[Vector2i] = [
		PlanningChecklistHarness.SWAP_ALLY_CELL,
		PlanningChecklistHarness.SWAP_PREMOVE_ROUTE[0],
		PlanningChecklistHarness.SWAP_PREMOVE_DEST,
	]
	if not PlanningChecklistHarness.commit_painted_drop_on_cell(
		fix, premove_route, PlanningChecklistHarness.SWAP_PREMOVE_DEST,
	):
		PlanningChecklistHarness.assert_fail(failures, "bible/swap/premove", "premove drag failed")
		return

	var pre_moves: Array[TimelineAction] = PlanningChecklistHarness.pre_moves_for_unit(director, k1_id)
	if pre_moves.size() < 2:
		PlanningChecklistHarness.assert_fail(
			failures,
			"bible/swap/premove_count",
			"expected 2 pre-moves (swap+walk) got %d" % pre_moves.size(),
		)
	PlanningChecklistHarness.assert_eq_cell(
		failures,
		"bible/swap/premove_dest",
		PlanningChecklistHarness.projected_unit(fix, k1_id).position,
		PlanningChecklistHarness.SWAP_PREMOVE_DEST,
	)


static func _test_swap_walk_then_swap(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_swap_board(
		PlanningChecklistHarness.WALK_SWAP_ALLY_CELL,
	)
	var director: CombatDirector = fix.director
	var k1_id: int = fix.k1_id as int
	var ally_id: int = fix.ally_id as int
	var start_mp: int = fix.start_k1_mp as int
	director.auto_run = true

	PlanningChecklistHarness.select_ability_for_unit(
		fix, k1_id, PlanningChecklistHarness.KNIGHT_SWAP_ID,
	)
	_Probe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.WALK_SWAP_ALLY_CELL, {
			"preview_nonempty": true,
			"path_end": PlanningChecklistHarness.WALK_SWAP_APPROACH,
			"path_start": PlanningChecklistHarness.KNIGHT_START,
			"path_min_size": 2,
			"ghost_pos": PlanningChecklistHarness.WALK_SWAP_APPROACH,
			"manhattan": true,
		}, "bible/walk_swap/hover",
	)

	PlanningChecklistHarness.select_unit(fix, k1_id, PlanningChecklistHarness.WALK_SWAP_ALLY_CELL)
	if PlanningChecklistHarness.slots_invalid(
		PlanningChecklistHarness.commit_production(fix, PlanningChecklistHarness.WALK_SWAP_ALLY_CELL),
	):
		PlanningChecklistHarness.assert_fail(failures, "bible/walk_swap/commit", "walk-swap click failed")
		return

	var pre_moves: Array[TimelineAction] = PlanningChecklistHarness.pre_moves_for_unit(director, k1_id)
	if pre_moves.size() < 2:
		PlanningChecklistHarness.assert_fail(
			failures,
			"bible/walk_swap/pre_count",
			"expected walk+swap pre-moves got %d" % pre_moves.size(),
		)
		return
	if pre_moves[0].type != GameEnums.ActionType.MOVE:
		PlanningChecklistHarness.assert_fail(failures, "bible/walk_swap/type0", "first pre-move must be walk")
	if pre_moves[1].type != GameEnums.ActionType.ABILITY:
		PlanningChecklistHarness.assert_fail(failures, "bible/walk_swap/type1", "second must be ability")

	PlanningChecklistHarness.assert_swap_board_layers(
		failures,
		"bible/walk_swap/after",
		fix,
		k1_id,
		ally_id,
		PlanningChecklistHarness.WALK_SWAP_ALLY_CELL,
		PlanningChecklistHarness.WALK_SWAP_APPROACH,
		start_mp - 3,
		2,
	)
