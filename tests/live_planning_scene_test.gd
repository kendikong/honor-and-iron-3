## Tier 3 acceptance: one TestBattle session, multi-knight planning bible, then sim verify.
##
## Boots the real scene once, places four knights and two dummies, walks the 7-phase
## checklist layers through live mouse input, then runs headless Simulator on the
## committed plan and verifies final board positions match preview/commit promises.
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const _SHIELD_BASH_ID: StringName = &"knight_shield_bash"
const _CHAIN_HOOK_ID: StringName = &"knight_chain_hook"
const _TRAMPLE_ID: StringName = &"knight_trampling_advance"
const _BOWLING_CHARGE_ID: StringName = &"knight_bowling_charge"

const _K1_CELL := Vector2i(4, 5)
const _K2_CELL := Vector2i(1, 3)
const _K3_CELL := Vector2i(5, 4)
const _K4_CELL := Vector2i(4, 1)
const _E_BASH_CELL := Vector2i(7, 5)
const _E_HOOK_CELL := Vector2i(4, 3)
const _BASH_APPROACH := Vector2i(6, 5)
const _HOVER_WALK := Vector2i(5, 5)
const _OFF_BLUE_CELL := Vector2i(9, 9)
const _OFF_MAP_HOVER := Vector2i(-999, -999)
const _TRAMPLE_ROUTE: Array[Vector2i] = [Vector2i(6, 4), Vector2i(6, 3)]
const _TRAMPLE_END := Vector2i(6, 3)
const _TRAMPLE_FULL_PATH: Array[Vector2i] = [_K3_CELL, _TRAMPLE_ROUTE[0], _TRAMPLE_ROUTE[1]]
const _TRAMPLE_POST_DEST := Vector2i(8, 2)
const _TRAMPLE_POST_ROUTE: Array[Vector2i] = [
	_TRAMPLE_END, Vector2i(7, 3), Vector2i(8, 3), _TRAMPLE_POST_DEST,
]
const _TRAMPLE_POST_WAYPOINTS: Array[Vector2i] = [Vector2i(7, 3), Vector2i(8, 3), _TRAMPLE_POST_DEST]
const _TRAMPLE_POST_FULL_PATH: Array[Vector2i] = [
	_K3_CELL, _TRAMPLE_ROUTE[0], _TRAMPLE_ROUTE[1], Vector2i(7, 3), Vector2i(8, 3), _TRAMPLE_POST_DEST,
]
const _K4_RUN_TRIGGER_CELL := Vector2i(3, 2)
## Walk-only loop (3 MP) then one west tile triggers auto_run: E → N → W → W.
const _K4_DETOUR_PLUS_RUN_ROUTE: Array[Vector2i] = [
	Vector2i(4, 1), Vector2i(5, 1), Vector2i(5, 2), Vector2i(4, 2), _K4_RUN_TRIGGER_CELL,
]

const _SETTLE_FRAMES := 4
const _SETTLE_DELTA_MS := 20
const _MOUSE_MOTION_DELTA_MS := 10
const _ABILITY_SETTLE_FRAMES := 6
const _DRAG_SAMPLE_PIXELS := 72.0
const _TRACE_DIR := "res://reports/live_planning_trace/"

static var _qa_profile_resolved: bool = false
static var _qa_fast_profile: bool = true


func _qa_fast_enabled() -> bool:
	if not _qa_profile_resolved:
		_qa_fast_profile = OS.get_environment("LIVE_QA_PROFILE") != "full"
		_qa_profile_resolved = true
	return _qa_fast_profile


func _ability_settle_frames() -> int:
	return 4 if _qa_fast_enabled() else _ABILITY_SETTLE_FRAMES


func _settle_delta_ms() -> int:
	return 12 if _qa_fast_enabled() else _SETTLE_DELTA_MS


func _wants_trace_png(label: String) -> bool:
	if not _qa_fast_enabled():
		return true
	if label.ends_with("/committed"):
		return true
	if label == "undo_smoke/cleared":
		return true
	if label.contains("walk_loop"):
		return true
	if label.contains("run_trigger"):
		return true
	if label.ends_with("after_commit") or label.ends_with("/post_commit"):
		return true
	return false


func test_live_planning_bible_multi_knight_session(timeout := 180000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	_ensure_live_test_window(runner)
	await runner.simulate_frames(8)
	var scene: TestBattleMapView = runner.scene() as TestBattleMapView
	assert_object(scene).is_not_null()
	var ctx: Dictionary = await _boot_multi_knight_session(runner, scene)
	await _journey_undo_sprite_smoke(ctx)
	await _journey_knight1_shield_bash(ctx)
	await _journey_knight2_chain_hook(ctx)
	await _journey_knight3_trampling_advance(ctx)
	await _journey_knight4_run_economy(ctx)
	await _journey_execute_all_plans(ctx)
	_write_planning_trace(ctx)


func _ensure_live_test_window(runner: GdUnitSceneRunner) -> void:
	## GdUnit CLI starts minimized; restore project viewport size so mouse coords match F5.
	runner.move_window_to_foreground()
	var target_w: int = int(ProjectSettings.get_setting("display/window/size/viewport_width", 1920))
	var target_h: int = int(ProjectSettings.get_setting("display/window/size/viewport_height", 1080))
	var screen: Vector2i = DisplayServer.screen_get_size()
	target_w = mini(target_w, screen.x)
	target_h = mini(target_h, screen.y)
	DisplayServer.window_set_size(Vector2i(target_w, target_h))


func _boot_multi_knight_session(runner: GdUnitSceneRunner, scene: TestBattleMapView) -> Dictionary:
	var session: TestBattleSession = scene.get_session()
	session.reset_defaults()
	session.extra_player_coords = [_K2_CELL, _K3_CELL, _K4_CELL]
	session.dummy_coords = [_E_BASH_CELL, _E_HOOK_CELL]
	scene.apply_training_board()
	if _qa_fast_enabled():
		scene._center_map()
	await runner.simulate_frames(_SETTLE_FRAMES, _settle_delta_ms())
	var shell: TacticalCombatShell = scene.get_node("CombatShell") as TacticalCombatShell
	var director: CombatDirector = scene.get_node("CombatDirector") as CombatDirector
	var overlay: TacticalPlanningOverlay = scene.get_node(
		"WorldModulate/MapRoot/PlanningOverlay",
	) as TacticalPlanningOverlay
	director.auto_run = true
	if _qa_fast_enabled():
		scene.apply_qa_performance_mode(overlay)
	var board: BoardState = director.board
	assert_object(board).is_not_null()
	var ctx: Dictionary = {
		"runner": runner,
		"scene": scene,
		"shell": shell,
		"director": director,
		"input": shell.planning_input,
		"overlay": overlay,
		"board": board,
		"k1_id": _unit_id_at(board, _K1_CELL),
		"k2_id": _unit_id_at(board, _K2_CELL),
		"k3_id": _unit_id_at(board, _K3_CELL),
		"k4_id": _unit_id_at(board, _K4_CELL),
		"e_bash_id": _unit_id_at(board, _E_BASH_CELL),
		"e_hook_id": _unit_id_at(board, _E_HOOK_CELL),
		"expect": {},
		"trace": [],
		"mode_commits": {},
	}
	assert_int(ctx.k1_id).is_greater(0)
	assert_int(ctx.k2_id).is_greater(0)
	assert_int(ctx.k3_id).is_greater(0)
	assert_int(ctx.k4_id).is_greater(0)
	assert_int(ctx.e_bash_id).is_greater(0)
	assert_int(ctx.e_hook_id).is_greater(0)
	return ctx


func _journey_undo_sprite_smoke(ctx: Dictionary) -> void:
	## Commit a real pre-move, undo via production right-click, sprite must return home.
	var k1_id: int = ctx.k1_id
	var home: Vector2i = _K1_CELL
	var dest: Vector2i = _HOVER_WALK
	await _select_unit_live(ctx, k1_id, home)
	await _drag_release_at(ctx, [home, dest], dest, "undo_smoke")
	await _wait_ability_settle(ctx)
	assert_int(ctx.director.plan_pre_move.entries.size()).override_failure_message(
		"undo_smoke: drag commit must write pre-move",
	).is_greater(0)
	await _wait_planning_move_tween(ctx, k1_id)
	await _assert_actor_on_cell(ctx, k1_id, dest, "undo_smoke/after_commit")
	await _undo_until_unit_clear(ctx, k1_id, home)
	await _capture_planning_surface(ctx, k1_id, "undo_smoke/cleared")


func _journey_knight1_shield_bash(ctx: Dictionary) -> void:
	var director: CombatDirector = ctx.director
	var input: CombatPlanningInput = ctx.input
	var overlay: TacticalPlanningOverlay = ctx.overlay
	var k1_id: int = ctx.k1_id
	var e_bash_id: int = ctx.e_bash_id
	await _select_unit_live(ctx, k1_id, _K1_CELL)
	var knight: UnitState = director.board.get_unit_by_id(k1_id)
	assert_int(knight.ability.points_left).is_equal(1)
	assert_int(knight.movement.points_left).is_equal(3)
	var bash: AbilityData = await _select_ability_for_unit(ctx, k1_id, _SHIELD_BASH_ID)
	assert_object(bash).is_not_null()
	await _probe_cell(ctx, k1_id, _K1_CELL, {
		"blue_any": true,
		"red_on": true,
		"red_stand": _K1_CELL,
		"ability": bash,
		"red_cell": {"cell": _E_BASH_CELL, "stand": _K1_CELL, "in_range": false},
	}, "k1/phase1/stand")
	await _probe_hover_edge_cases(ctx, k1_id, bash, _K1_CELL, "k1/hover_edges")
	await _probe_cell(ctx, k1_id, _HOVER_WALK, {
		"ghost_pos": _HOVER_WALK,
		"path_end": _HOVER_WALK,
		"path_start": _K1_CELL,
		"path_min_size": 2,
		"manhattan": true,
		"red_on": true,
		"red_stand": _HOVER_WALK,
		"ability": bash,
		"icon_has": [PlanningIcons.GLYPH_WALK],
		"blue_any": true,
	}, "k1/phase2/walk")
	await _probe_cell(ctx, k1_id, _E_BASH_CELL, {
		"ghost_pos": _BASH_APPROACH,
		"path_end": _BASH_APPROACH,
		"path_start": _K1_CELL,
		"path_min_size": 3,
		"manhattan": true,
		"red_on": true,
		"red_stand": _BASH_APPROACH,
		"ability": bash,
		"icon_has": [PlanningIcons.GLYPH_WALK, PlanningIcons.GLYPH_ATTACK],
		"blue_any": true,
		"push_enemy_id": e_bash_id,
	}, "k1/phase4/approach")
	var push_to: Vector2i = _preview_push_destination(input, e_bash_id)
	assert_bool(push_to.x > _E_BASH_CELL.x).is_true()
	if not _qa_fast_enabled():
		await _probe_cell(ctx, k1_id, _E_BASH_CELL, {
			"ghost_pos": _BASH_APPROACH,
			"path_end": _BASH_APPROACH,
			"path_start": _K1_CELL,
			"path_min_size": 3,
			"manhattan": true,
			"icon_has": [PlanningIcons.GLYPH_WALK, PlanningIcons.GLYPH_ATTACK],
			"push_dest": push_to,
			"push_enemy_id": e_bash_id,
		}, "k1/selection/pre_tap")
		await _tap_cell(ctx, _E_BASH_CELL, "k1/selection/release")
		await _wait_ability_settle(ctx)
		_assert_k1_bash_committed(ctx, k1_id, "k1/selection")
		await _capture_commit_state(ctx, k1_id, "k1/selection/committed")
		_remember_mode_commit(ctx, "k1/selection", k1_id)
		await _probe_cell(ctx, k1_id, _BASH_APPROACH, {
			"red_on": false,
			"red_stand": _BASH_APPROACH,
			"ability": bash,
			"manhattan": true,
		}, "k1/selection/post_commit")
		await _wait_ability_settle(ctx)
		_assert_k1_bash_committed(ctx, k1_id, "k1/selection")
		await _undo_until_unit_clear(ctx, k1_id, _K1_CELL)
	await _drag_release_at(ctx, [_K1_CELL, _BASH_APPROACH], _E_BASH_CELL, "k1/drag")
	await _wait_ability_settle(ctx)
	_assert_k1_bash_committed(ctx, k1_id, "k1/drag")
	await _capture_commit_state(ctx, k1_id, "k1/drag/committed")
	_remember_mode_commit(ctx, "k1/drag", k1_id)
	if not _qa_fast_enabled():
		_assert_mode_commit_parity(ctx, "k1/selection", "k1/drag")
	await _probe_cell(ctx, k1_id, _BASH_APPROACH, {
		"red_on": false,
		"red_stand": _BASH_APPROACH,
		"ability": bash,
		"manhattan": true,
	}, "k1/drag/post_commit")
	ctx.expect["k1_pos"] = _BASH_APPROACH
	var bashed: UnitState = director.projected_state.get_unit_by_id(e_bash_id)
	assert_object(bashed).is_not_null()
	ctx.expect["e_bash_pos"] = bashed.position
	_cancel_active_pointer(ctx)


func _journey_knight2_chain_hook(ctx: Dictionary) -> void:
	var director: CombatDirector = ctx.director
	var input: CombatPlanningInput = ctx.input
	var k2_id: int = ctx.k2_id
	var e_hook_id: int = ctx.e_hook_id
	await _select_unit_live(ctx, k2_id, _K2_CELL)
	var hook: AbilityData = await _select_ability_for_unit(ctx, k2_id, _CHAIN_HOOK_ID)
	assert_object(hook).is_not_null()
	await _probe_cell(ctx, k2_id, _K2_CELL, {
		"red_on": true,
		"red_stand": _K2_CELL,
		"ability": hook,
		"red_cell": {"cell": _E_HOOK_CELL, "stand": _K2_CELL, "in_range": true},
		"blue_any": true,
	}, "k2/phase1/stand")
	await _probe_cell(ctx, k2_id, Vector2i(2, 3), {
		"ghost_pos": Vector2i(2, 3),
		"path_end": Vector2i(2, 3),
		"path_start": _K2_CELL,
		"path_min_size": 2,
		"manhattan": true,
		"blue_any": true,
	}, "k2/phase2/walk")
	var pull_preview: Vector2i = _preview_push_destination(input, e_hook_id)
	if pull_preview.x > -900000:
		assert_bool(pull_preview.x < _E_HOOK_CELL.x).is_true()
	await _probe_cell(ctx, k2_id, _E_HOOK_CELL, {
		"path_end": _K2_CELL,
		"path_start": _K2_CELL,
		"path_min_size": 1,
		"icon_has": [PlanningIcons.GLYPH_ATTACK],
		"manhattan": true,
		"blue_any": true,
		"red_on": true,
		"red_stand": _K2_CELL,
		"ability": hook,
		"red_cell": {"cell": _E_HOOK_CELL, "stand": _K2_CELL, "in_range": true},
		"pull_dest": pull_preview,
		"pull_enemy_id": e_hook_id,
	}, "k2/phase4/enemy")
	await _tap_cell(ctx, _E_HOOK_CELL, "k2/selection/release")
	await _wait_ability_settle(ctx)
	_assert_k2_hook_committed(ctx, k2_id, e_hook_id, "k2/selection")
	await _capture_commit_state(ctx, k2_id, "k2/selection/committed")
	_remember_mode_commit(ctx, "k2/selection", k2_id)
	if not _qa_fast_enabled():
		await _undo_until_unit_clear(ctx, k2_id, _K2_CELL)
		await _drag_release_at(ctx, [_K2_CELL], _E_HOOK_CELL, "k2/drag")
		await _wait_ability_settle(ctx)
		_assert_k2_hook_committed(ctx, k2_id, e_hook_id, "k2/drag")
		await _capture_commit_state(ctx, k2_id, "k2/drag/committed")
		_remember_mode_commit(ctx, "k2/drag", k2_id)
		_assert_mode_commit_parity(ctx, "k2/selection", "k2/drag")
	var projected: UnitState = director.projected_state.get_unit_by_id(k2_id)
	assert_int(projected.ability.points_left).is_equal(0)
	var hooked: UnitState = director.projected_state.get_unit_by_id(e_hook_id)
	assert_object(hooked).is_not_null()
	assert_bool(hooked.position.x < _E_HOOK_CELL.x).is_true()
	ctx.expect["k2_pos"] = _K2_CELL
	ctx.expect["e_hook_pos"] = hooked.position
	_cancel_active_pointer(ctx)


func _journey_knight3_trampling_advance(ctx: Dictionary) -> void:
	var director: CombatDirector = ctx.director
	var input: CombatPlanningInput = ctx.input
	var k3_id: int = ctx.k3_id
	await _select_unit_live(ctx, k3_id, _K3_CELL)
	var trample: AbilityData = await _select_ability_for_unit(ctx, k3_id, _TRAMPLE_ID)
	assert_object(trample).is_not_null()
	await _probe_cell(ctx, k3_id, _K3_CELL, {
		"blue_any": true,
		"red_on": true,
		"red_stand": _K3_CELL,
		"ability": trample,
		"manhattan": true,
	}, "k3/phase1/stand")
	await _tap_cell(ctx, _K3_CELL, "k3/selection/arm")
	await _wait_ability_settle(ctx)
	assert_bool(input.awaiting_targeting_active()).is_true()
	assert_object(director.find_awaiting_action(k3_id)).is_not_null()
	await _probe_cell(ctx, k3_id, _K3_CELL, {
		"red_on": true,
		"red_stand": _K3_CELL,
		"ability": trample,
		"manhattan": true,
	}, "k3/phase2/awaiting_armed")
	var route: Array[Vector2i] = _TRAMPLE_FULL_PATH.duplicate()
	await _probe_cell(ctx, k3_id, _TRAMPLE_ROUTE[0], {
		"path": [_K3_CELL, _TRAMPLE_ROUTE[0]],
		"ghost_pos": _TRAMPLE_ROUTE[0],
		"manhattan": true,
		"preview_nonempty": true,
		"red_on": true,
		"red_stand": _K3_CELL,
		"ability": trample,
	}, "k3/hover/east")
	await _probe_cell(ctx, k3_id, _TRAMPLE_END, {
		"path": _TRAMPLE_FULL_PATH,
		"ghost_pos": _TRAMPLE_END,
		"manhattan": true,
		"preview_nonempty": true,
		"red_on": true,
		"red_stand": _K3_CELL,
		"ability": trample,
	}, "k3/hover/end")
	if not _qa_fast_enabled():
		await _rearm_trample_awaiting(ctx, k3_id)
		await _probe_cell(ctx, k3_id, _TRAMPLE_END, {
			"path": _TRAMPLE_FULL_PATH,
			"ghost_pos": _TRAMPLE_END,
			"manhattan": true,
			"preview_nonempty": true,
		}, "k3/selection/pre_tap")
		await _tap_cell(ctx, _TRAMPLE_END, "k3/selection/release")
		await _wait_ability_settle(ctx)
		_assert_k3_trample_committed(ctx, k3_id, "k3/selection")
		await _capture_commit_state(ctx, k3_id, "k3/selection/committed")
		_remember_mode_commit(ctx, "k3/selection", k3_id)
		await _undo_until_unit_clear(ctx, k3_id, _K3_CELL)
	await _rearm_trample_awaiting(ctx, k3_id)
	await _drag_through_cells_with_route_checks(ctx, route, "k3", false, &"trample_paint")
	_assert_k3_trample_committed(ctx, k3_id, "k3/drag")
	await _capture_commit_state(ctx, k3_id, "k3/drag/committed")
	_remember_mode_commit(ctx, "k3/drag", k3_id)
	if not _qa_fast_enabled():
		_assert_mode_commit_parity(ctx, "k3/selection", "k3/drag")
	await _probe_cell(ctx, k3_id, _TRAMPLE_END, {
		"red_on": false,
		"red_stand": _TRAMPLE_END,
		"ability": trample,
		"manhattan": true,
	}, "k3/drag/post_commit")
	await _select_unit_live(ctx, k3_id, _TRAMPLE_END)
	await _enter_basic_movement_mode(ctx, k3_id)
	await _probe_cell(ctx, k3_id, _TRAMPLE_END, {
		"blue_any": true,
		"manhattan": true,
	}, "k3/post/stand")
	await _probe_cell(ctx, k3_id, Vector2i(7, 3), {
		"blue_has": [Vector2i(7, 3)],
		"ghost_pos": Vector2i(7, 3),
		"path": [_K3_CELL, _TRAMPLE_ROUTE[0], _TRAMPLE_END, Vector2i(7, 3)],
		"manhattan": true,
		"preview_nonempty": true,
		"icon_has": [PlanningIcons.GLYPH_WALK],
		"icon_not": [PlanningIcons.GLYPH_ATTACK],
	}, "k3/post/hover_east")
	await _probe_cell(ctx, k3_id, _TRAMPLE_POST_DEST, {
		"path": _TRAMPLE_POST_FULL_PATH,
		"ghost_pos": _TRAMPLE_POST_DEST,
		"manhattan": true,
		"preview_nonempty": true,
		"icon_has": [PlanningIcons.GLYPH_WALK],
		"blue_any": true,
	}, "k3/post/hover_dest")
	await _drag_through_cells_with_route_checks(
		ctx, _TRAMPLE_POST_ROUTE, "k3/post", false, &"post_after_trample",
	)
	_assert_k3_post_move_committed(ctx, k3_id, "k3/post")
	await _probe_cell(ctx, k3_id, _TRAMPLE_POST_DEST, {
		"red_on": false,
		"red_stand": _TRAMPLE_POST_DEST,
		"ability": trample,
		"manhattan": true,
	}, "k3/post/after_commit")
	ctx.expect["k3_pos"] = _TRAMPLE_POST_DEST
	_cancel_active_pointer(ctx)


func _journey_knight4_run_economy(ctx: Dictionary) -> void:
	var director: CombatDirector = ctx.director
	var input: CombatPlanningInput = ctx.input
	var k4_id: int = ctx.k4_id
	var unit: UnitState = director.board.get_unit_by_id(k4_id)
	assert_object(unit).is_not_null()
	await _select_unit_live(ctx, k4_id, _K4_CELL)
	var bowling: AbilityData = await _select_ability_for_unit(ctx, k4_id, _BOWLING_CHARGE_ID)
	assert_object(bowling).is_not_null()
	await _probe_cell(ctx, k4_id, _K4_CELL, {
		"blue_any": true,
		"red_on": true,
		"red_stand": _K4_CELL,
		"ability": bowling,
		"manhattan": true,
	}, "k4/phase1/stand")
	await _enter_k4_auto_run_paint_mode(ctx, k4_id)
	if not _qa_fast_enabled():
		await _select_k4_detour_and_run_route(ctx, k4_id, bowling, "k4/selection")
		await _wait_ability_settle(ctx)
		await _capture_commit_state(ctx, k4_id, "k4/selection/committed")
		_assert_k4_run_committed(ctx, k4_id, bowling, "k4/selection")
		_remember_mode_commit(ctx, "k4/selection", k4_id)
		await _undo_until_unit_clear(ctx, k4_id, _K4_CELL)
		await _enter_k4_auto_run_paint_mode(ctx, k4_id)
	await _paint_k4_detour_and_run_route(ctx, k4_id, bowling, "k4/drag")
	await _capture_commit_state(ctx, k4_id, "k4/drag/committed")
	_assert_k4_run_committed(ctx, k4_id, bowling, "k4/drag")
	_remember_mode_commit(ctx, "k4/drag", k4_id)
	if not _qa_fast_enabled():
		_record_mode_commit_comparison(ctx, "k4/selection", "k4/drag")
		_assert_mode_commit_parity(ctx, "k4/selection", "k4/drag")
	await _select_ability_for_unit(ctx, k4_id, _BOWLING_CHARGE_ID)
	await _probe_cell(ctx, k4_id, _K4_RUN_TRIGGER_CELL, {
		"red_on": false,
		"red_stand": _K4_RUN_TRIGGER_CELL,
		"ability": bowling,
		"manhattan": true,
	}, "k4/drag/post_commit")
	await _k4_preview_snapshot(ctx, k4_id, _K4_RUN_TRIGGER_CELL, "after_commit")
	var k4_projected: UnitState = director.projected_state.get_unit_by_id(k4_id)
	if k4_projected != null:
		ctx.expect["k4_pos"] = k4_projected.position
	_cancel_active_pointer(ctx)


func _journey_execute_all_plans(ctx: Dictionary) -> void:
	var director: CombatDirector = ctx.director
	var combined: Timeline = director.get_player_plan()
	var result: SimResult = Simulator.simulate(director.base_board.clone(), combined)
	var board: BoardState = result.final_state
	ctx.trace.append({
		"label": "execute/sim_final",
		"k1_pos": _cell_name(board.get_unit_by_id(ctx.k1_id).position),
		"k2_pos": _cell_name(board.get_unit_by_id(ctx.k2_id).position),
		"k3_pos": _cell_name(board.get_unit_by_id(ctx.k3_id).position),
		"k4_pos": _cell_name(board.get_unit_by_id(ctx.k4_id).position),
		"e_bash_pos": _cell_name(board.get_unit_by_id(ctx.e_bash_id).position),
		"e_hook_pos": _cell_name(board.get_unit_by_id(ctx.e_hook_id).position),
	})
	var k1: UnitState = board.get_unit_by_id(ctx.k1_id)
	var k2: UnitState = board.get_unit_by_id(ctx.k2_id)
	var k3: UnitState = board.get_unit_by_id(ctx.k3_id)
	var k4: UnitState = board.get_unit_by_id(ctx.k4_id)
	var e_bash: UnitState = board.get_unit_by_id(ctx.e_bash_id)
	var e_hook: UnitState = board.get_unit_by_id(ctx.e_hook_id)
	assert_that(k1.position).is_equal(ctx.expect["k1_pos"])
	assert_that(k2.position).is_equal(ctx.expect["k2_pos"])
	assert_that(k3.position).is_equal(ctx.expect["k3_pos"])
	assert_that(k4.position).is_equal(ctx.expect["k4_pos"])
	assert_that(e_bash.position).is_equal(ctx.expect["e_bash_pos"])
	assert_that(e_hook.position).is_equal(ctx.expect["e_hook_pos"])


func _select_ability_for_unit(
	ctx: Dictionary,
	unit_id: int,
	ability_id: StringName,
) -> AbilityData:
	var runner: GdUnitSceneRunner = ctx.runner
	var director: CombatDirector = ctx.director
	var unit: UnitState = director.board.get_unit_by_id(unit_id)
	assert_object(unit).is_not_null()
	for index: int in range(unit.active_abilities.size()):
		var ability: AbilityData = unit.active_abilities[index]
		if ability != null and ability.id == ability_id:
			director.select_ability(index)
			await runner.simulate_frames(_ability_settle_frames(), _settle_delta_ms())
			return ability
	assert_that("Required ability missing for unit %d: %s" % [unit_id, ability_id]).is_equal("")
	return null


func _select_unit_live(ctx: Dictionary, unit_id: int, cell: Vector2i) -> void:
	_cancel_active_pointer(ctx)
	ctx.director.select_unit(unit_id)
	await _wait_ability_settle(ctx)
	assert_int(ctx.director.selected_unit_id).is_equal(unit_id)
	await _reposition_mouse_to_unit(ctx, unit_id, cell)


func _rearm_trample_awaiting(ctx: Dictionary, k3_id: int) -> void:
	var director: CombatDirector = ctx.director
	var input: CombatPlanningInput = ctx.input
	await _select_ability_for_unit(ctx, k3_id, _TRAMPLE_ID)
	await _tap_cell(ctx, _K3_CELL)
	await _wait_ability_settle(ctx)
	assert_bool(input.awaiting_targeting_active()).override_failure_message(
		"k3: trample must re-arm awaiting at stand",
	).is_true()
	assert_object(director.find_awaiting_action(k3_id)).override_failure_message(
		"k3: awaiting action missing after re-arm",
	).is_not_null()


func _click_commit_at_cell(ctx: Dictionary, cell: Vector2i) -> void:
	var input: CombatPlanningInput = ctx.input
	var director: CombatDirector = ctx.director
	input.set_qa_pointer_grid_cell(cell)
	if input._intent_state != null:
		input._intent_state.set_hover_coord(cell)
	var local: Vector2 = input._mouse_local_for_facing()
	input.on_left_press(local)
	await ctx.runner.simulate_frames(2, _settle_delta_ms())
	input.on_left_release(local)
	director.flush_plan_refresh_signals_if_pending()
	input.clear_qa_pointer_override()
	await ctx.runner.simulate_frames(_SETTLE_FRAMES, _settle_delta_ms())


func _tap_cell(
	ctx: Dictionary,
	cell: Vector2i,
	label: String = "tap",
	assert_preview_commit: bool = true,
) -> void:
	var runner: GdUnitSceneRunner = ctx.runner
	var unit_id: int = ctx.director.selected_unit_id
	await _sweep_mouse_to_cell(ctx, cell, "%s/approach" % label, unit_id)
	await _capture_planning_surface(ctx, unit_id, "%s/hover" % label)
	var pre_intent: Dictionary = _capture_preview_intent(ctx, unit_id, cell, false)
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(2, _settle_delta_ms())
	await _capture_planning_surface(ctx, ctx.director.selected_unit_id, "%s/press" % label)
	runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(_SETTLE_FRAMES, _settle_delta_ms())
	await _capture_planning_surface(ctx, ctx.director.selected_unit_id, "%s/settled" % label)
	if assert_preview_commit:
		_assert_commit_ratifies_preview(ctx, unit_id, pre_intent, label)


func _right_click_undo(ctx: Dictionary) -> void:
	var director: CombatDirector = ctx.director
	director.flush_plan_refresh_signals_if_pending()
	ctx.input.on_right_click()
	director.flush_plan_refresh_signals_if_pending()
	await _wait_ability_settle(ctx)


func _unit_layer(ctx: Dictionary) -> TacticalUnitLayer:
	return ctx.scene.get_node("WorldModulate/MapRoot/UnitLayer") as TacticalUnitLayer


func _actor_grid_cell(ctx: Dictionary, unit_id: int) -> Vector2i:
	return _unit_layer(ctx).actor_grid_cell(unit_id)


func _assert_actor_on_cell(ctx: Dictionary, unit_id: int, cell: Vector2i, label: String) -> void:
	var actor_cell: Vector2i = _actor_grid_cell(ctx, unit_id)
	assert_that(actor_cell).override_failure_message(
		"%s: sprite must stand on %s, got actor grid %s" % [label, _cell_name(cell), _cell_name(actor_cell)],
	).is_equal(cell)


func _wait_planning_move_tween(ctx: Dictionary, unit_id: int, extra_settle_frames: int = 4) -> void:
	var layer: TacticalUnitLayer = _unit_layer(ctx)
	var runner: GdUnitSceneRunner = ctx.runner
	for _frame: int in range(240):
		if not layer.has_move_tween(unit_id):
			break
		await runner.simulate_frames(1, _settle_delta_ms())
	await runner.simulate_frames(extra_settle_frames, _settle_delta_ms())


func _undo_until_unit_clear(ctx: Dictionary, unit_id: int, home_cell: Vector2i) -> void:
	var director: CombatDirector = ctx.director
	var input: CombatPlanningInput = ctx.input
	director.select_unit(unit_id)
	await _wait_ability_settle(ctx)
	await _wait_planning_move_tween(ctx, unit_id)
	for _attempt: int in range(8):
		if director.unit_has_undoable_action(unit_id):
			await _right_click_undo(ctx)
			await _wait_planning_move_tween(ctx, unit_id)
			continue
		if input.awaiting_targeting_active():
			await _right_click_undo(ctx)
			await _wait_ability_settle(ctx)
			continue
		break
	var unit: UnitState = director.board.get_unit_by_id(unit_id)
	assert_object(unit).override_failure_message(
		"undo_until_clear: missing unit %d on board" % unit_id,
	).is_not_null()
	assert_that(unit.position).override_failure_message(
		"undo_until_clear: board cell must return to %s" % _cell_name(home_cell),
	).is_equal(home_cell)
	await _assert_actor_on_cell(ctx, unit_id, home_cell, "undo_until_clear/sprite")
	assert_bool(director.unit_has_undoable_action(unit_id)).override_failure_message(
		"undo_until_clear: unit %d still has undoable plan" % unit_id,
	).is_false()


func _drag_release_at(
	ctx: Dictionary,
	route: Array[Vector2i],
	release_cell: Vector2i,
	label: String = "drag",
) -> void:
	var cells: Array[Vector2i] = route.duplicate()
	if cells.is_empty() or cells[cells.size() - 1] != release_cell:
		cells.append(release_cell)
	await _drag_through_cells(ctx, cells, false, label)


func _assert_k1_bash_committed(ctx: Dictionary, k1_id: int, label: String) -> void:
	var director: CombatDirector = ctx.director
	assert_int(director.plan_pre_move.entries.size()).override_failure_message(
		"%s: bash must write pre-move" % label,
	).is_greater(0)
	assert_int(director.plan_action.entries.size()).override_failure_message(
		"%s: bash must write action" % label,
	).is_greater(0)
	var bash_pre: TimelineAction = _committed_pre_move_for_unit(director, k1_id)
	assert_object(bash_pre).override_failure_message(
		"%s: missing bash pre-move" % label,
	).is_not_null()
	assert_that(bash_pre.target_coord).override_failure_message(
		"%s: bash pre-move dest" % label,
	).is_equal(_BASH_APPROACH)


func _assert_k2_hook_committed(
	ctx: Dictionary,
	k2_id: int,
	e_hook_id: int,
	label: String,
) -> void:
	var director: CombatDirector = ctx.director
	assert_int(director.plan_action.entries.size()).override_failure_message(
		"%s: hook must write action" % label,
	).is_greater(0)
	var projected: UnitState = director.projected_state.get_unit_by_id(k2_id)
	assert_int(projected.ability.points_left).override_failure_message(
		"%s: hook spends AP" % label,
	).is_equal(0)
	var hooked: UnitState = director.projected_state.get_unit_by_id(e_hook_id)
	assert_object(hooked).override_failure_message(
		"%s: hook target missing" % label,
	).is_not_null()
	assert_bool(hooked.position.x < _E_HOOK_CELL.x).override_failure_message(
		"%s: hook must pull west" % label,
	).is_true()


func _assert_k3_trample_committed(ctx: Dictionary, k3_id: int, label: String) -> void:
	var director: CombatDirector = ctx.director
	var action: TimelineAction = _committed_action_for_unit(director, k3_id)
	assert_object(action).override_failure_message(
		"%s: trample action missing" % label,
	).is_not_null()
	var projected: UnitState = director.projected_state.get_unit_by_id(k3_id)
	assert_object(projected).override_failure_message(
		"%s: trample projected unit missing" % label,
	).is_not_null()
	if label.ends_with("/drag"):
		assert_that(action.waypoints).override_failure_message(
			"%s: trample waypoints" % label,
		).is_equal(_TRAMPLE_ROUTE)
		assert_that(projected.position).override_failure_message(
			"%s: trample end position" % label,
		).is_equal(_TRAMPLE_END)
	else:
		assert_that(action.target_coord).override_failure_message(
			"%s: trample target" % label,
		).is_equal(_TRAMPLE_END)
	assert_int(projected.ability.points_left).override_failure_message(
		"%s: trample spends AP" % label,
	).is_equal(0)


func _assert_k3_post_move_committed(ctx: Dictionary, k3_id: int, label: String) -> void:
	var director: CombatDirector = ctx.director
	var post: TimelineAction = _committed_post_move_for_unit(director, k3_id)
	assert_object(post).override_failure_message(
		"%s: post-move missing" % label,
	).is_not_null()
	assert_that(post.target_coord).override_failure_message(
		"%s: post-move destination" % label,
	).is_equal(_TRAMPLE_POST_DEST)
	assert_that(post.waypoints).override_failure_message(
		"%s: post-move waypoints" % label,
	).is_equal(_TRAMPLE_POST_WAYPOINTS)
	var projected: UnitState = director.projected_state.get_unit_by_id(k3_id)
	assert_object(projected).override_failure_message(
		"%s: post-move projected unit missing" % label,
	).is_not_null()
	assert_that(projected.position).override_failure_message(
		"%s: post-move projected position" % label,
	).is_equal(_TRAMPLE_POST_DEST)


func _enter_basic_movement_mode(ctx: Dictionary, unit_id: int) -> void:
	ctx.director.select_unit(unit_id)
	ctx.director.select_ability(-1)
	ctx.input.force_basic_movement = true
	await _wait_ability_settle(ctx)


## K4 F5 parity: keep selected skill armed; auto_run extended move budget (force_basic blocks run).
func _enter_k4_auto_run_paint_mode(ctx: Dictionary, unit_id: int) -> void:
	ctx.director.select_unit(unit_id)
	ctx.input.force_basic_movement = false
	await _wait_ability_settle(ctx)


func _assert_k4_run_committed(
	ctx: Dictionary,
	k4_id: int,
	bowling: AbilityData,
	label: String,
) -> void:
	var director: CombatDirector = ctx.director
	var input: CombatPlanningInput = ctx.input
	var projected: UnitState = director.projected_state.get_unit_by_id(k4_id)
	assert_that(projected.position).override_failure_message(
		"%s: k4 destination" % label,
	).is_equal(_K4_RUN_TRIGGER_CELL)
	var pre: TimelineAction = _committed_pre_move_for_unit(director, k4_id)
	assert_object(pre).override_failure_message(
		"%s: k4 must commit pre-move" % label,
	).is_not_null()
	if pre != null:
		assert_that(pre.target_coord).override_failure_message(
			"%s: k4 pre-move destination" % label,
		).is_equal(_K4_RUN_TRIGGER_CELL)
		assert_bool(pre.uses_run).override_failure_message(
			"%s: k4 pre-move must use Run after detour" % label,
		).is_true()
		var expected_waypoints: Array[Vector2i] = _K4_DETOUR_PLUS_RUN_ROUTE.slice(1)
		assert_that(pre.waypoints).override_failure_message(
			"%s: k4 pre-move waypoints must match painted detour" % label,
		).is_equal(expected_waypoints)
	assert_bool(_plan_uses_run_for_unit(director, k4_id)).override_failure_message(
		"%s: k4 plan must use Run" % label,
	).is_true()
	assert_int(input.planning_display_ap_left(k4_id)).override_failure_message(
		"%s: k4 display AP after commit" % label,
	).is_equal(0)


func _hover_cell(ctx: Dictionary, cell: Vector2i) -> void:
	await _sweep_mouse_to_cell(ctx, cell)


func _reposition_mouse_to_unit(ctx: Dictionary, unit_id: int, cell: Vector2i) -> void:
	var input: CombatPlanningInput = ctx.input
	var director: CombatDirector = ctx.director
	var runner: GdUnitSceneRunner = ctx.runner
	input.set_qa_pointer_grid_cell(cell)
	runner.simulate_mouse_move(_screen_position_for_cell(ctx, cell))
	if input._intent_state != null:
		input._intent_state.set_hover_coord(cell)
	input.refresh_mouse_cursor(cell)
	director.flush_plan_refresh_signals_if_pending()
	await runner.simulate_frames(_ability_settle_frames(), _settle_delta_ms())


func _assert_not_dragging(ctx: Dictionary, label: String) -> void:
	assert_bool(ctx.input.dragging).override_failure_message(
		"%s: selection mode must not activate drag (sprite must not follow cursor)" % label,
	).is_false()


## Sweeps the pointer in pixel steps so selection and drag both match F5 hover motion.
func _sweep_mouse_to_cell(
	ctx: Dictionary,
	cell: Vector2i,
	motion_label: String = "",
	unit_id: int = -1,
	sample_pixels: float = -1.0,
	capture_motion: bool = true,
) -> void:
	ctx.input.clear_qa_pointer_override()
	var runner: GdUnitSceneRunner = ctx.runner
	var start: Vector2 = runner.get_mouse_position()
	var target: Vector2 = _screen_position_for_cell(ctx, cell)
	var step_px: float = sample_pixels if sample_pixels > 0.0 else _DRAG_SAMPLE_PIXELS
	var sample_count: int = maxi(1, ceili(start.distance_to(target) / step_px))
	for sample_index: int in range(1, sample_count + 1):
		var alpha: float = float(sample_index) / float(sample_count)
		runner.simulate_mouse_move(start.lerp(target, alpha))
		await runner.simulate_frames(1, _MOUSE_MOTION_DELTA_MS)
		if capture_motion and motion_label != "" and unit_id >= 0:
			await _capture_planning_surface(
				ctx, unit_id, "%s/motion_%03d" % [motion_label, sample_index], false,
			)
	await runner.simulate_frames(2, _MOUSE_MOTION_DELTA_MS)
	ctx.input.set_qa_pointer_grid_cell(cell)


func _sweep_drag_to_cell(ctx: Dictionary, unit_id: int, cell: Vector2i, label: String) -> void:
	await _sweep_mouse_to_cell(ctx, cell, label, unit_id)


## Discrete tile hops during drag — matches F5 tile-by-tile painting; avoids sweep repath.
func _hop_drag_to_cell(ctx: Dictionary, unit_id: int, cell: Vector2i, label: String) -> void:
	var input: CombatPlanningInput = ctx.input
	var runner: GdUnitSceneRunner = ctx.runner
	var screen: Vector2 = _screen_position_for_cell(ctx, cell)
	runner.simulate_mouse_move(screen)
	input.set_qa_pointer_grid_cell(cell)
	if input._intent_state != null:
		input._intent_state.set_hover_coord(cell)
	var local: Vector2 = input._mouse_local_for_facing()
	if not input.dragging:
		input.try_activate_drag(local)
	if input.dragging:
		input.update_drag(local)
	assert_bool(input.dragging).override_failure_message(
		"%s: drag paint must be active at %s" % [label, cell],
	).is_true()
	assert_that(input.compute_hover_action_icon(cell)).override_failure_message(
		"%s: planning cursor icon must stay hidden during drag (F5 parity)" % label,
	).is_equal("")
	await runner.simulate_frames(2, _MOUSE_MOTION_DELTA_MS)
	if label != "" and unit_id >= 0:
		await _capture_planning_surface(ctx, unit_id, label, false)


func _screen_position_for_cell(ctx: Dictionary, cell: Vector2i) -> Vector2:
	var scene: TestBattleMapView = ctx.scene
	var map_root: Node2D = scene.get_node("WorldModulate/MapRoot") as Node2D
	return scene.position + scene.grid_to_local(cell) * map_root.scale.x


## Hover + full planning-surface audit (preview path, blue/red overlay, cursor glyph).
## Contract keys (all optional): path, path_end, path_start, path_min_size, manhattan,
## ghost_pos, preview_nonempty, icon_has, icon_not, red_on, red_stand, ability,
## red_cell, red_cell_in, blue_any, blue_has, blue_not.
func _probe_cell(
	ctx: Dictionary,
	unit_id: int,
	cell: Vector2i,
	contract: Dictionary,
	label: String,
) -> Dictionary:
	if _qa_fast_enabled():
		await _reposition_mouse_to_unit(ctx, unit_id, cell)
	else:
		await _sweep_mouse_to_cell(ctx, cell, "%s/approach" % label, unit_id)
	await _wait_ability_settle(ctx)
	var surface: Dictionary = await _audit_surface(ctx, unit_id, cell, contract, label)
	await _capture_planning_surface(ctx, unit_id, label)
	return surface


func _audit_surface(
	ctx: Dictionary,
	unit_id: int,
	hover_cell: Vector2i,
	contract: Dictionary,
	label: String,
) -> Dictionary:
	var input: CombatPlanningInput = ctx.input
	var path: Array[Vector2i] = _preview_path(input, unit_id)
	var icon: String = input.compute_hover_action_icon(hover_cell)
	var surface: Dictionary = {
		"hover": hover_cell,
		"path": path,
		"icon": icon,
		"overlay_red": _overlay_has_red_tile(ctx.overlay, ctx.board),
		"overlay_blue": _overlay_has_blue_tile(ctx.overlay, ctx.board),
		"blue_tiles": _collect_blue_tiles(ctx),
		"red_tiles": _collect_red_tiles(ctx),
		"dragging": input.dragging,
		"drag_route": input.get_drag_route() if input.dragging else [],
	}
	if contract.has("preview_nonempty"):
		assert_bool(path.size() > 0).override_failure_message(
			"%s: preview path must not be empty at %s" % [label, hover_cell],
		).is_equal(contract["preview_nonempty"])
	if contract.has("path"):
		_assert_preview_path_equals(ctx, unit_id, contract["path"], label)
	elif contract.has("path_end"):
		var min_sz: int = int(contract.get("path_min_size", 2))
		var start: Vector2i = contract.get("path_start", hover_cell)
		_assert_preview_path_ends(ctx, unit_id, contract["path_end"], min_sz, start, label)
	if contract.get("manhattan", false) and not path.is_empty():
		_assert_path_is_manhattan(path, label)
	if contract.has("ghost_pos"):
		var ghost: UnitState = await _preview_unit(ctx, unit_id, contract["ghost_pos"])
		assert_object(ghost).override_failure_message(
			"%s: preview ghost missing at %s" % [label, hover_cell],
		).is_not_null()
		if ghost != null:
			assert_that(ghost.position).override_failure_message(
				"%s: preview ghost position" % label,
			).is_equal(contract["ghost_pos"])
	for glyph: Variant in contract.get("icon_has", []):
		assert_bool(icon.contains(glyph)).override_failure_message(
			"%s: icon must contain %s, got %s" % [label, glyph, icon],
		).is_true()
	for glyph_n: Variant in contract.get("icon_not", []):
		assert_bool(icon.contains(glyph_n)).override_failure_message(
			"%s: icon must not contain %s, got %s" % [label, glyph_n, icon],
		).is_false()
	if contract.has("red_on"):
		var ability: AbilityData = contract.get("ability", null)
		var stand: Vector2i = contract.get("red_stand", hover_cell)
		_assert_red_live(ctx, ability, contract["red_on"], stand, "%s/red" % label)
	if contract.has("red_cell"):
		var rc: Dictionary = contract["red_cell"]
		_assert_red_cell_live(
			ctx,
			contract.get("ability", null),
			rc.get("in_range", true),
			rc.get("stand", hover_cell),
			rc["cell"],
			"%s/red_cell" % label,
		)
	if contract.has("blue_any"):
		assert_bool(surface["overlay_blue"] == contract["blue_any"]).override_failure_message(
			"%s: overlay blue expected %s at %s" % [label, contract["blue_any"], hover_cell],
		).is_true()
	for blue_cell: Variant in contract.get("blue_has", []):
		_assert_move_tile_at(ctx, blue_cell, true, "%s/blue_has_%s" % [label, blue_cell])
	for blue_off: Variant in contract.get("blue_not", []):
		_assert_move_tile_at(ctx, blue_off, false, "%s/blue_not_%s" % [label, blue_off])
	if contract.get("tiles_only_in_bounds", false):
		_assert_overlay_tiles_in_bounds(ctx, label)
	if contract.get("hover_oob", false):
		var hover_ui: Vector2i = input.get_hover_tile_for_ui()
		assert_bool(not ctx.board.is_in_bounds(hover_ui)).override_failure_message(
			"%s: hover must be out of bounds, got %s" % [label, hover_ui],
		).is_true()
	if contract.has("push_dest"):
		var enemy_id: int = int(contract.get("push_enemy_id", -1))
		var push_to: Vector2i = _preview_push_destination(input, enemy_id)
		assert_that(push_to).override_failure_message(
			"%s: push preview destination" % label,
		).is_equal(contract["push_dest"])
	if contract.has("pull_dest"):
		var pull_enemy_id: int = int(contract.get("pull_enemy_id", -1))
		var pull_to: Vector2i = _preview_push_destination(input, pull_enemy_id)
		assert_that(pull_to).override_failure_message(
			"%s: pull preview destination" % label,
		).is_equal(contract["pull_dest"])
	return surface


## On-map unreachable cell + off-map hover: blue/red overlay must stay in-bounds and gate-aligned.
func _probe_hover_edge_cases(
	ctx: Dictionary,
	unit_id: int,
	ability: AbilityData,
	red_stand: Vector2i,
	label_prefix: String,
) -> void:
	await _probe_hover_surface(ctx, unit_id, _OFF_BLUE_CELL, {
		"blue_any": true,
		"blue_not": [_OFF_BLUE_CELL],
		"red_on": false,
		"tiles_only_in_bounds": true,
	}, "%s/off_blue" % label_prefix)
	await _hover_mouse_off_map(ctx)
	await _probe_hover_surface(ctx, unit_id, _OFF_MAP_HOVER, {
		"hover_oob": true,
		"blue_any": true,
		"red_on": true,
		"red_stand": red_stand,
		"ability": ability,
		"tiles_only_in_bounds": true,
	}, "%s/off_map" % label_prefix)


func _probe_hover_surface(
	ctx: Dictionary,
	unit_id: int,
	hover_cell: Vector2i,
	contract: Dictionary,
	label: String,
) -> void:
	if hover_cell == _OFF_MAP_HOVER:
		pass
	elif _qa_fast_enabled():
		await _reposition_mouse_to_unit(ctx, unit_id, hover_cell)
	else:
		await _sweep_mouse_to_cell(ctx, hover_cell, "%s/approach" % label, unit_id)
	if hover_cell == _OFF_MAP_HOVER:
		await ctx.runner.simulate_frames(_ability_settle_frames(), _settle_delta_ms())
	else:
		await ctx.runner.simulate_frames(2, _settle_delta_ms())
	await _audit_surface(ctx, unit_id, hover_cell, contract, label)


func _hover_mouse_off_map(ctx: Dictionary) -> void:
	var input: CombatPlanningInput = ctx.input
	var director: CombatDirector = ctx.director
	input.clear_qa_pointer_override()
	ctx.runner.simulate_mouse_move(Vector2(-10000.0, -10000.0))
	await ctx.runner.simulate_frames(1, _MOUSE_MOTION_DELTA_MS)
	input.on_hover_moved(_OFF_MAP_HOVER)
	if input._intent_state != null:
		input._intent_state.set_hover_coord(_OFF_MAP_HOVER)
	director.flush_plan_refresh_signals_if_pending()
	await ctx.runner.simulate_frames(2, _settle_delta_ms())


func _drag_between_cells(ctx: Dictionary, from: Vector2i, to: Vector2i) -> void:
	await _drag_through_cells(ctx, [from, to], true, "drag_between")


func _drag_through_cells(
	ctx: Dictionary,
	cells: Array[Vector2i],
	assert_hover_steps: bool = true,
	label: String = "drag",
) -> void:
	if cells.is_empty():
		return
	var runner: GdUnitSceneRunner = ctx.runner
	var input: CombatPlanningInput = ctx.input
	await _reposition_mouse_to_unit(ctx, ctx.director.selected_unit_id, cells[0])
	await _capture_planning_surface(ctx, ctx.director.selected_unit_id, "%s/start" % label)
	if assert_hover_steps:
		assert_that(input.get_hover_tile_for_ui()).is_equal(cells[0])
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(3, _MOUSE_MOTION_DELTA_MS)
	await _capture_planning_surface(ctx, ctx.director.selected_unit_id, "%s/press" % label)
	for i: int in range(1, cells.size()):
		await _hop_drag_to_cell(ctx, ctx.director.selected_unit_id, cells[i], "%s/step_%d" % [label, i])
		if assert_hover_steps:
			assert_that(input.get_hover_tile_for_ui()).is_equal(cells[i])
		await _capture_planning_surface(ctx, ctx.director.selected_unit_id, "%s/step_%d" % [label, i])
	var release_cell: Vector2i = cells[cells.size() - 1]
	input.set_qa_pointer_grid_cell(release_cell)
	if input._intent_state != null:
		input._intent_state.set_hover_coord(release_cell)
	var pre_intent: Dictionary = _capture_preview_intent(ctx, ctx.director.selected_unit_id, release_cell, true)
	runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(_ability_settle_frames(), _settle_delta_ms())
	await _capture_planning_surface(ctx, ctx.director.selected_unit_id, "%s/release" % label)
	_assert_commit_ratifies_preview(ctx, ctx.director.selected_unit_id, pre_intent, "%s/release" % label)


func _select_k4_detour_and_run_route(
	ctx: Dictionary,
	unit_id: int,
	bowling: AbilityData,
	label_prefix: String,
) -> void:
	var input: CombatPlanningInput = ctx.input
	await _reposition_mouse_to_unit(ctx, unit_id, _K4_DETOUR_PLUS_RUN_ROUTE[0])
	await _capture_planning_surface(ctx, unit_id, "%s/start" % label_prefix)
	_assert_not_dragging(ctx, "%s/start" % label_prefix)
	for step_index: int in range(1, _K4_DETOUR_PLUS_RUN_ROUTE.size()):
		var cell: Vector2i = _K4_DETOUR_PLUS_RUN_ROUTE[step_index]
		var step_label: String = "%s/step_%d" % [label_prefix, step_index]
		var expected_path: Array[Vector2i] = _K4_DETOUR_PLUS_RUN_ROUTE.slice(0, step_index + 1)
		await _sweep_mouse_to_cell(ctx, cell, "%s/approach" % step_label, unit_id, -1.0, false)
		_assert_not_dragging(ctx, step_label)
		_assert_preview_path_equals(ctx, unit_id, expected_path, "%s/path" % step_label)
		if cell == Vector2i(4, 2):
			await _wait_ability_settle(ctx)
			await _assert_k4_walk_loop_preview(ctx, unit_id, bowling, cell, "%s/walk_loop" % step_label)
		elif cell == _K4_RUN_TRIGGER_CELL:
			await _wait_ability_settle(ctx)
			await _assert_k4_run_loop_preview(ctx, unit_id, bowling, "%s/run_trigger" % step_label)
		await _capture_planning_surface(ctx, unit_id, step_label)
	var pre_intent: Dictionary = _capture_preview_intent(ctx, unit_id, _K4_RUN_TRIGGER_CELL, false)
	await _tap_cell(ctx, _K4_RUN_TRIGGER_CELL, "%s/release" % label_prefix, false)
	_assert_commit_ratifies_preview(ctx, unit_id, pre_intent, "%s/release" % label_prefix)
	_assert_not_dragging(ctx, "%s/after_release" % label_prefix)
	assert_that(input.get_drag_route()).override_failure_message(
		"%s: selection mode must not leave a drag route" % label_prefix,
	).is_equal([])


func _paint_k4_detour_and_run_route(
	ctx: Dictionary,
	unit_id: int,
	bowling: AbilityData,
	label_prefix: String,
	pause_frames_at_checkpoint: int = 0,
) -> void:
	var runner: GdUnitSceneRunner = ctx.runner
	var input: CombatPlanningInput = ctx.input
	await _reposition_mouse_to_unit(ctx, unit_id, _K4_DETOUR_PLUS_RUN_ROUTE[0])
	await _capture_planning_surface(ctx, unit_id, "%s/start" % label_prefix)
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(3, _MOUSE_MOTION_DELTA_MS)
	await _capture_planning_surface(ctx, unit_id, "%s/press" % label_prefix)
	for step_index: int in range(1, _K4_DETOUR_PLUS_RUN_ROUTE.size()):
		await _hop_drag_to_cell(
			ctx,
			unit_id,
			_K4_DETOUR_PLUS_RUN_ROUTE[step_index],
			"%s/step_%d" % [label_prefix, step_index],
		)
		var expected_path: Array[Vector2i] = _K4_DETOUR_PLUS_RUN_ROUTE.slice(0, step_index + 1)
		_assert_drag_route_equals(ctx, expected_path, "%s/drag_route_%d" % [label_prefix, step_index])
		_assert_preview_path_equals(
			ctx, unit_id, expected_path, "%s/preview_path_%d" % [label_prefix, step_index],
		)
		await _capture_planning_surface(ctx, unit_id, "%s/step_%d" % [label_prefix, step_index])
		var stand: Vector2i = _K4_DETOUR_PLUS_RUN_ROUTE[step_index]
		if stand == Vector2i(4, 2):
			await _wait_ability_settle(ctx)
			await _assert_k4_walk_loop_preview(ctx, unit_id, bowling, stand, "%s/walk_loop_end" % label_prefix)
			await _k4_preview_snapshot(ctx, unit_id, stand, "walk_loop_end")
			if pause_frames_at_checkpoint > 0:
				await runner.simulate_frames(pause_frames_at_checkpoint, _MOUSE_MOTION_DELTA_MS)
		elif stand == _K4_RUN_TRIGGER_CELL:
			await _wait_ability_settle(ctx)
			await _assert_k4_run_loop_preview(ctx, unit_id, bowling, "%s/run_trigger" % label_prefix)
			await _k4_preview_snapshot(ctx, unit_id, stand, "run_trigger")
			if pause_frames_at_checkpoint > 0:
				await runner.simulate_frames(pause_frames_at_checkpoint, _MOUSE_MOTION_DELTA_MS)
	_assert_drag_route_equals(ctx, _K4_DETOUR_PLUS_RUN_ROUTE, "%s/route" % label_prefix)
	_assert_preview_path_matches_drag_route(ctx, unit_id, "%s/pre_release" % label_prefix)
	var pre_intent: Dictionary = _capture_preview_intent(ctx, unit_id, _K4_RUN_TRIGGER_CELL, true)
	runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(_ability_settle_frames(), _settle_delta_ms())
	await _capture_planning_surface(ctx, unit_id, "%s/release" % label_prefix)
	_assert_commit_ratifies_preview(ctx, unit_id, pre_intent, "%s/release" % label_prefix)


func _drag_k4_detour_and_run_preview(
	ctx: Dictionary,
	unit_id: int,
	bowling: AbilityData,
	pause_frames_at_checkpoint: int = 0,
) -> void:
	await _paint_k4_detour_and_run_route(ctx, unit_id, bowling, "k4/drag", pause_frames_at_checkpoint)


func _assert_preview_path_matches_drag_route(
	ctx: Dictionary,
	unit_id: int,
	label: String,
) -> void:
	var drag_route: Array[Vector2i] = ctx.input.get_drag_route()
	_assert_preview_path_equals(ctx, unit_id, drag_route, label)


func _assert_k4_walk_loop_preview(
	ctx: Dictionary,
	unit_id: int,
	bowling: AbilityData,
	stand: Vector2i,
	label: String,
) -> void:
	var input: CombatPlanningInput = ctx.input
	assert_bool(input.unit_move_requires_run(unit_id)).override_failure_message(
		"%s: walk detour must not require Run at stand %s" % [label, stand],
	).is_false()
	assert_int(input.planning_display_ap_left(unit_id)).override_failure_message(
		"%s: walk detour must keep skill AP at stand %s" % [label, stand],
	).is_equal(1)
	assert_object(bowling).override_failure_message(
		"%s: K4 walk loop requires Bowling selected" % label,
	).is_not_null()
	assert_bool(input.action_range_visible_for_hover()).override_failure_message(
		"%s: walk detour must keep action-range gate on at stand %s" % [label, stand],
	).is_true()
	_assert_red_live(ctx, bowling, true, stand, "%s/red" % label)


func _assert_k4_run_loop_preview(
	ctx: Dictionary,
	unit_id: int,
	bowling: AbilityData,
	label: String,
) -> void:
	var input: CombatPlanningInput = ctx.input
	assert_bool(input.unit_move_requires_run(unit_id)).override_failure_message(
		"%s: extension past detour must require Run" % label,
	).is_true()
	assert_int(input.planning_display_ap_left(unit_id)).override_failure_message(
		"%s: Run intent must show 0 display AP" % label,
	).is_equal(0)
	assert_bool(input.action_range_visible_for_hover()).override_failure_message(
		"%s: Run trigger must hide action-range gate" % label,
	).is_false()
	assert_bool(_overlay_has_red_tile(ctx.overlay, ctx.board)).override_failure_message(
		"%s: Run trigger must hide action-range red" % label,
	).is_false()


func _k4_preview_snapshot(ctx: Dictionary, unit_id: int, stand: Vector2i, label: String) -> void:
	var input: CombatPlanningInput = ctx.input
	var requires_run: bool = input.unit_move_requires_run(unit_id)
	var display_ap: int = input.planning_display_ap_left(unit_id)
	var overlay_red: bool = _overlay_has_red_tile(ctx.overlay, ctx.board)
	var red_gate: bool = input.action_range_visible_for_hover()
	print(
		"[K4-SNAPSHOT] %s | stand=%s requires_run=%s display_ap=%d red_gate=%s overlay_red=%s"
		% [label, stand, requires_run, display_ap, red_gate, overlay_red],
	)
	if label == "run_trigger":
		print(
			"[K4-COMPARE] F5 auto_run paint at run end: requires_run=%s display_ap=%d red_gate=%s overlay_red=%s"
			% [requires_run, display_ap, red_gate, overlay_red],
		)
	await ctx.runner.simulate_frames(4, _settle_delta_ms())
	if not _wants_trace_png(label):
		return
	var vp: Viewport = ctx.scene.get_viewport()
	if vp == null:
		return
	var tex: ViewportTexture = vp.get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return
	var out_dir: String = "res://reports/k4_preview/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var out_path: String = "%sk4_%s.png" % [out_dir, label]
	img.save_png(out_path)
	print("[K4-SNAPSHOT] saved %s" % out_path)


func _drag_through_cells_with_route_checks(
	ctx: Dictionary,
	cells: Array[Vector2i],
	label_prefix: String,
	assert_timeline_empty: bool = true,
	route_mode: StringName = &"exact",
) -> void:
	if cells.is_empty():
		return
	var runner: GdUnitSceneRunner = ctx.runner
	var input: CombatPlanningInput = ctx.input
	var director: CombatDirector = ctx.director
	var unit_id: int = director.selected_unit_id
	await _reposition_mouse_to_unit(ctx, ctx.director.selected_unit_id, cells[0])
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(3, _MOUSE_MOTION_DELTA_MS)
	await _capture_planning_surface(ctx, unit_id, "%s/press" % label_prefix)
	for step_index: int in range(1, cells.size()):
		await _hop_drag_to_cell(
			ctx, unit_id, cells[step_index], "%s/step_%d" % [label_prefix, step_index],
		)
		await _capture_planning_surface(ctx, unit_id, "%s/step_%d" % [label_prefix, step_index])
		var expected: Array[Vector2i] = []
		for j: int in range(step_index + 1):
			expected.append(cells[j])
		if route_mode == &"corridor_horizontal":
			_assert_drag_route_corridor(
				ctx, cells[0], cells[step_index],
				"%s/drag_route_%d" % [label_prefix, step_index],
			)
			await runner.simulate_frames(2, _MOUSE_MOTION_DELTA_MS)
			var painted: Array[Vector2i] = ctx.input.get_drag_route()
			_assert_preview_path_equals(
				ctx, unit_id, painted, "%s/preview_path_%d" % [label_prefix, step_index],
			)
		elif route_mode == &"post_after_trample":
			_assert_drag_route_equals(ctx, expected, "%s/drag_route_%d" % [label_prefix, step_index])
			await runner.simulate_frames(2, _MOUSE_MOTION_DELTA_MS)
			var preview_expected: Array[Vector2i] = []
			var preview_len: int = _TRAMPLE_FULL_PATH.size() + step_index
			for j: int in range(preview_len):
				preview_expected.append(_TRAMPLE_POST_FULL_PATH[j])
			_assert_preview_path_equals(
				ctx, unit_id, preview_expected, "%s/preview_path_%d" % [label_prefix, step_index],
			)
			assert_bool(_overlay_has_blue_tile(ctx.overlay, ctx.board)).override_failure_message(
				"%s: post drag must show blue move tiles" % label_prefix,
			).is_true()
		elif route_mode == &"trample_paint":
			_assert_drag_route_equals(ctx, expected, "%s/drag_route_%d" % [label_prefix, step_index])
			assert_bool(input._paint_valid_movement_endpoint_intent()).override_failure_message(
				"%s: endpoint paint failed at step %d" % [label_prefix, step_index],
			).is_true()
			await runner.simulate_frames(2, _MOUSE_MOTION_DELTA_MS)
			_assert_preview_path_equals(
				ctx, unit_id, expected, "%s/preview_path_%d" % [label_prefix, step_index],
			)
		else:
			_assert_drag_route_equals(ctx, expected, "%s/drag_route_%d" % [label_prefix, step_index])
			assert_bool(input._paint_valid_movement_endpoint_intent()).override_failure_message(
				"%s: endpoint paint failed at step %d" % [label_prefix, step_index],
			).is_true()
			await runner.simulate_frames(2, _MOUSE_MOTION_DELTA_MS)
			_assert_preview_path_equals(
				ctx, unit_id, expected, "%s/preview_path_%d" % [label_prefix, step_index],
			)
		if assert_timeline_empty:
			assert_int(director.plan_pre_move.entries.size()).is_equal(0)
	var release_cell: Vector2i = cells[cells.size() - 1]
	var pre_intent: Dictionary = _capture_preview_intent(ctx, unit_id, release_cell, true)
	runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(_ability_settle_frames(), _settle_delta_ms())
	await _capture_planning_surface(ctx, unit_id, "%s/release" % label_prefix)
	_assert_commit_ratifies_preview(ctx, unit_id, pre_intent, "%s/release" % label_prefix)


func _assert_drag_route_corridor(
	ctx: Dictionary,
	start: Vector2i,
	end: Vector2i,
	label: String,
) -> void:
	var route: Array[Vector2i] = ctx.input.get_drag_route()
	var min_len: int = absi(end.x - start.x) + 1
	assert_bool(route.size() >= min_len).override_failure_message(
		"%s: corridor too short (%d < %d): %s" % [label, route.size(), min_len, route],
	).is_true()
	if route.size() > 0:
		assert_that(route[0]).override_failure_message(
			"%s: corridor must start at %s, got %s" % [label, start, route[0]],
		).is_equal(start)
		assert_that(route[route.size() - 1]).override_failure_message(
			"%s: corridor must end at %s, got %s" % [label, end, route],
		).is_equal(end)
	for cell: Vector2i in route:
		assert_that(cell.y).override_failure_message(
			"%s: corridor must stay on row %d, got %s in %s" % [label, start.y, cell, route],
		).is_equal(start.y)


func _assert_drag_route_equals(
	ctx: Dictionary,
	expected: Array[Vector2i],
	label: String,
) -> void:
	var route: Array[Vector2i] = ctx.input.get_drag_route()
	assert_that(route).override_failure_message(
		"%s: drag route expected %s got %s" % [label, expected, route],
	).is_equal(expected)


func _assert_preview_path_equals(
	ctx: Dictionary,
	unit_id: int,
	expected: Array,
	label: String,
) -> void:
	if not expected.is_empty():
		_assert_path_is_manhattan(expected, "%s/expected" % label)
	var path: Array[Vector2i] = _preview_path(ctx.input, unit_id)
	if not path.is_empty():
		_assert_path_is_manhattan(path, "%s/actual" % label)
	assert_that(path).override_failure_message(
		"%s: preview path expected %s got %s" % [label, expected, path],
	).is_equal(expected)


func _assert_path_is_manhattan(path: Array, label: String) -> void:
	for i: int in range(1, path.size()):
		if not path[i - 1] is Vector2i or not path[i] is Vector2i:
			continue
		var a: Vector2i = path[i - 1]
		var b: Vector2i = path[i]
		var dx: int = absi(b.x - a.x)
		var dy: int = absi(b.y - a.y)
		assert_bool(dx + dy == 1).override_failure_message(
			"%s: non-orthogonal step %s -> %s in %s" % [label, a, b, path],
		).is_true()


func _assert_preview_path_ends(
	ctx: Dictionary,
	unit_id: int,
	end: Vector2i,
	min_size: int,
	start: Vector2i,
	label: String,
) -> void:
	var path: Array[Vector2i] = _preview_path(ctx.input, unit_id)
	if path.is_empty():
		assert_bool(false).override_failure_message(
			"%s: preview path empty (expected end %s)" % [label, end],
		).is_true()
		return
	assert_bool(path.size() >= min_size).override_failure_message(
		"%s: path too short (%d < %d): %s" % [label, path.size(), min_size, path],
	).is_true()
	assert_that(path[0]).override_failure_message(
		"%s: path must start at %s, got %s" % [label, start, path[0]],
	).is_equal(start)
	assert_that(path[path.size() - 1]).override_failure_message(
		"%s: path must end at %s, got %s" % [label, end, path],
	).is_equal(end)


func _cancel_active_pointer(ctx: Dictionary) -> void:
	var input: CombatPlanningInput = ctx.input
	if input.dragging:
		ctx.runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
		await ctx.runner.simulate_frames(2, _MOUSE_MOTION_DELTA_MS)


func _wait_ability_settle(ctx: Dictionary) -> void:
	await ctx.runner.simulate_frames(_ability_settle_frames(), _settle_delta_ms())


func _preview_unit(
	ctx: Dictionary,
	unit_id: int,
	expected_pos: Vector2i = Vector2i(-999999, -999999),
) -> UnitState:
	for _attempt: int in range(20):
		var board: BoardState = ctx.input.preview_state.preview_board
		if board != null:
			var unit: UnitState = board.get_unit_by_id(unit_id)
			if unit != null:
				if expected_pos.x < -900000 or unit.position == expected_pos:
					return unit
		await ctx.runner.simulate_frames(2, _MOUSE_MOTION_DELTA_MS)
	return null


func _refresh_ctx_board(ctx: Dictionary) -> void:
	ctx.director = ctx.scene.get_node("CombatDirector") as CombatDirector
	ctx.board = ctx.director.board
	ctx.input = (ctx.scene.get_node("CombatShell") as TacticalCombatShell).planning_input
	ctx.overlay = ctx.scene.get_node(
		"WorldModulate/MapRoot/PlanningOverlay",
	) as TacticalPlanningOverlay
	ctx.k1_id = _unit_id_at(ctx.board, _K1_CELL)
	ctx.k2_id = _unit_id_at(ctx.board, _K2_CELL)
	ctx.k3_id = _unit_id_at(ctx.board, _K3_CELL)
	ctx.k4_id = _unit_id_at(ctx.board, _K4_CELL)
	ctx.e_bash_id = _unit_id_at(ctx.board, _E_BASH_CELL)
	ctx.e_hook_id = _unit_id_at(ctx.board, _E_HOOK_CELL)


func _unit_id_at(board: BoardState, cell: Vector2i) -> int:
	var unit: UnitState = board.get_unit_at(cell)
	return unit.id if unit != null else -1


func _plan_uses_run_for_unit(director: CombatDirector, unit_id: int) -> bool:
	for action: TimelineAction in director.plan_pre_move.entries:
		if action != null and action.actor_id == unit_id and action.uses_run:
			return true
	return false


func _committed_action_for_unit(director: CombatDirector, unit_id: int) -> TimelineAction:
	for action: TimelineAction in director.plan_action.entries:
		if action != null and action.actor_id == unit_id:
			return action
	return null


func _committed_pre_move_for_unit(director: CombatDirector, unit_id: int) -> TimelineAction:
	for action: TimelineAction in director.plan_pre_move.entries:
		if action != null and action.actor_id == unit_id:
			return action
	return null


func _committed_post_move_for_unit(director: CombatDirector, unit_id: int) -> TimelineAction:
	for action: TimelineAction in director.plan_post_move.entries:
		if action != null and action.actor_id == unit_id:
			return action
	return null


func _preview_push_destination(input: CombatPlanningInput, enemy_id: int) -> Vector2i:
	var pushes: Array = input.preview_state.preview_pushes.get(enemy_id, [])
	for seg: Variant in pushes:
		if seg is Array and (seg as Array).size() >= 2:
			return (seg as Array)[1] as Vector2i
	return Vector2i(-999999, -999999)


func _preview_path(input: CombatPlanningInput, unit_id: int) -> Array[Vector2i]:
	var raw: Array = input.preview_state.preview_paths.get(unit_id, [])
	var out: Array[Vector2i] = []
	for step: Variant in raw:
		if step is Vector2i:
			out.append(step)
	return out


func _slots_invalid(slots: Dictionary) -> bool:
	var flag: Variant = slots.get("invalid", false)
	if flag is bool:
		return flag
	if flag is String:
		return not (flag as String).is_empty()
	return bool(flag)


func _pre_target_from_slots(slots: Dictionary) -> Vector2i:
	var pre: Array = slots.get("pre", []) as Array
	if pre.is_empty():
		return Vector2i(-999999, -999999)
	var step: TimelineAction = pre[0] as TimelineAction
	return step.target_coord if step != null else Vector2i(-999999, -999999)


func _action_target_unit_from_slots(slots: Dictionary) -> int:
	var action_steps: Array = slots.get("action", []) as Array
	if action_steps.is_empty():
		return -1
	var step: TimelineAction = action_steps[0] as TimelineAction
	return step.target_unit_id if step != null else -1


func _post_target_from_slots(slots: Dictionary) -> Vector2i:
	var post: Array = slots.get("post", []) as Array
	if post.is_empty():
		return Vector2i(-999999, -999999)
	var step: TimelineAction = post[0] as TimelineAction
	return step.target_coord if step != null else Vector2i(-999999, -999999)


func _intent_slot_signature(slots: Dictionary) -> String:
	var pre_wps: String = "[]"
	var pre: Array = slots.get("pre", []) as Array
	if not pre.is_empty() and pre[0] is TimelineAction:
		pre_wps = str((pre[0] as TimelineAction).waypoints)
	var action_ability: String = ""
	var action_steps: Array = slots.get("action", []) as Array
	if not action_steps.is_empty() and action_steps[0] is TimelineAction:
		var act: TimelineAction = action_steps[0] as TimelineAction
		action_ability = str(act.ability.id) if act.ability != null else ""
	var post_count: int = (slots.get("post", []) as Array).size()
	return "%s|%s|%s|%s|%d|%s" % [
		str(_pre_target_from_slots(slots)),
		pre_wps,
		str(_action_target_unit_from_slots(slots)),
		action_ability,
		post_count,
		str(_slots_invalid(slots)),
	]


func _commit_slots_for_interaction(
	ctx: Dictionary,
	unit_id: int,
	cell: Vector2i,
	use_drop: bool,
) -> Dictionary:
	var input: CombatPlanningInput = ctx.input
	if use_drop and input.dragging:
		var legal_moves: Array[Vector2i] = []
		if input._drag_route_commits_active():
			legal_moves = input._snapshot_drag_legal_move_tiles()
		return input._final_commit_slots_for_drop_at_cell(
			unit_id, cell, Vector2.ZERO, legal_moves,
		)
	return input._final_commit_slots_for_click_at_cell(unit_id, cell, Vector2.ZERO)


func _capture_preview_intent(
	ctx: Dictionary,
	unit_id: int,
	cell: Vector2i,
	use_drop: bool = false,
) -> Dictionary:
	var input: CombatPlanningInput = ctx.input
	var director: CombatDirector = ctx.director
	director.flush_plan_refresh_signals_if_pending()
	var slots: Dictionary = _commit_slots_for_interaction(ctx, unit_id, cell, use_drop)
	var preview_path: Array[Vector2i] = _preview_path(input, unit_id)
	var drag_route: Array[Vector2i] = []
	if input.dragging:
		drag_route = input.get_drag_route()
	return {
		"cell": cell,
		"slots": slots,
		"slots_signature": _intent_slot_signature(slots),
		"preview_path": preview_path.duplicate(),
		"drag_route": drag_route.duplicate(),
		"display_ap": input.planning_display_ap_left(unit_id),
		"requires_run": input.unit_move_requires_run(unit_id),
		"invalid": _slots_invalid(slots),
	}


func _assert_commit_ratifies_preview(
	ctx: Dictionary,
	unit_id: int,
	pre: Dictionary,
	label: String,
) -> void:
	var director: CombatDirector = ctx.director
	var slots: Dictionary = pre.get("slots", {}) as Dictionary
	assert_bool(_slots_invalid(slots)).override_failure_message(
		"%s: commit must not run when preview slots are invalid" % label,
	).is_false()
	var pre_move: TimelineAction = _committed_pre_move_for_unit(director, unit_id)
	var pre_target: Vector2i = _pre_target_from_slots(slots)
	var post_target: Vector2i = _post_target_from_slots(slots)
	if pre_target.x > -900000:
		assert_object(pre_move).override_failure_message(
			"%s: committed pre-move missing for preview target %s" % [label, pre_target],
		).is_not_null()
		if pre_move != null:
			assert_that(pre_move.target_coord).override_failure_message(
				"%s: committed pre-move target must ratify preview" % label,
			).is_equal(pre_target)
			var slot_pre: Array = slots.get("pre", []) as Array
			if not slot_pre.is_empty() and slot_pre[0] is TimelineAction:
				var slot_action: TimelineAction = slot_pre[0] as TimelineAction
				assert_that(pre_move.uses_run).override_failure_message(
					"%s: committed pre-move uses_run must ratify preview" % label,
				).is_equal(slot_action.uses_run)
				if not (pre.get("drag_route", []) as Array).is_empty():
					assert_that(pre_move.waypoints).override_failure_message(
						"%s: committed pre-move waypoints must ratify preview" % label,
					).is_equal(slot_action.waypoints)
	var post_move: TimelineAction = _committed_post_move_for_unit(director, unit_id)
	if post_target.x > -900000:
		assert_object(post_move).override_failure_message(
			"%s: committed post-move missing for preview target %s" % [label, post_target],
		).is_not_null()
		if post_move != null:
			assert_that(post_move.target_coord).override_failure_message(
				"%s: committed post-move target must ratify preview" % label,
			).is_equal(post_target)
			var slot_post: Array = slots.get("post", []) as Array
			if not slot_post.is_empty() and slot_post[0] is TimelineAction:
				var slot_post_action: TimelineAction = slot_post[0] as TimelineAction
				if not (pre.get("drag_route", []) as Array).is_empty():
					assert_that(post_move.waypoints).override_failure_message(
						"%s: committed post-move waypoints must ratify preview" % label,
					).is_equal(slot_post_action.waypoints)
	var action: TimelineAction = _committed_action_for_unit(director, unit_id)
	var action_target_id: int = _action_target_unit_from_slots(slots)
	var slot_actions: Array = slots.get("action", []) as Array
	if action_target_id >= 0:
		assert_object(action).override_failure_message(
			"%s: committed action missing for preview target unit %d" % [label, action_target_id],
		).is_not_null()
		if action != null:
			assert_that(action.target_unit_id).override_failure_message(
				"%s: committed action target must ratify preview" % label,
			).is_equal(action_target_id)
	elif not slot_actions.is_empty() and slot_actions[0] is TimelineAction:
		var slot_act: TimelineAction = slot_actions[0] as TimelineAction
		assert_object(action).override_failure_message(
			"%s: committed action missing for preview slots" % label,
		).is_not_null()
		if action != null:
			if slot_act.ability != null:
				assert_that(str(action.ability.id if action.ability != null else "")).override_failure_message(
					"%s: committed action ability must ratify preview" % label,
				).is_equal(str(slot_act.ability.id))
			assert_that(action.target_coord).override_failure_message(
				"%s: committed action coord must ratify preview" % label,
			).is_equal(slot_act.target_coord)
			assert_that(action.waypoints).override_failure_message(
				"%s: committed action waypoints must ratify preview" % label,
			).is_equal(slot_act.waypoints)
	var preview_path: Array = pre.get("preview_path", [])
	if not preview_path.is_empty():
		var preview_end: Vector2i = preview_path[preview_path.size() - 1] as Vector2i
		if pre_target.x > -900000:
			assert_that(preview_end).override_failure_message(
				"%s: preview path end must match slot pre-move target" % label,
			).is_equal(pre_target)
		elif post_target.x > -900000:
			assert_that(preview_end).override_failure_message(
				"%s: preview path end must match slot post-move target" % label,
			).is_equal(post_target)
		elif action != null and action.type == GameEnums.ActionType.MOVE:
			assert_that(preview_end).override_failure_message(
				"%s: preview path end must match move action target" % label,
			).is_equal(action.target_coord)
	var projected: UnitState = director.projected_state.get_unit_by_id(unit_id)
	if projected != null and pre_target.x > -900000:
		assert_that(projected.position).override_failure_message(
			"%s: projected position must ratify preview pre-move target" % label,
		).is_equal(pre_target)
	elif projected != null and post_target.x > -900000:
		assert_that(projected.position).override_failure_message(
			"%s: projected position must ratify preview post-move target" % label,
		).is_equal(post_target)
	var drag_route: Array = pre.get("drag_route", [])
	if not drag_route.is_empty() and pre_move != null and not pre_move.waypoints.is_empty():
		assert_that(pre_move.waypoints).override_failure_message(
			"%s: committed waypoints must ratify painted drag route tail" % label,
		).is_equal(drag_route.slice(1))


func _overlay_has_red_tile(overlay: TacticalPlanningOverlay, _board: BoardState) -> bool:
	return not overlay.get_hover_action_range_tiles().is_empty()


func _overlay_has_blue_tile(overlay: TacticalPlanningOverlay, _board: BoardState) -> bool:
	return not overlay.get_hover_move_tiles().is_empty()


func _collect_blue_tiles(ctx: Dictionary) -> Array[Vector2i]:
	return ctx.overlay.get_hover_move_tiles()


func _collect_red_tiles(ctx: Dictionary) -> Array[Vector2i]:
	return ctx.overlay.get_hover_action_range_tiles()


## Records the complete F5-visible planning surface at an input boundary.
## JSON contains only stable scalar/array values; the paired PNG preserves arrows,
## sprites, and other visual details that are not exposed as public data.
func _capture_planning_surface(
	ctx: Dictionary,
	unit_id: int,
	label: String,
	save_screenshot: bool = true,
) -> void:
	var input: CombatPlanningInput = ctx.input
	var director: CombatDirector = ctx.director
	var projected: UnitState = director.projected_state.get_unit_by_id(unit_id)
	var snapshot: Dictionary = {
		"label": label,
		"phase": director.phase,
		"selected_unit": director.selected_unit_id,
		"selected_ability_index": director.selected_ability_index,
		"hover": _cell_name(input.get_hover_tile_for_ui()),
		"cursor_icon": input.compute_hover_action_icon(input.get_hover_tile_for_ui()),
		"dragging": input.dragging,
		"drag_route": _cell_names(input.get_drag_route() if input.dragging else []),
		"preview_paths": _all_preview_paths(input),
		"blue_tiles": _cell_names(_collect_blue_tiles(ctx)),
		"red_tiles": _cell_names(_collect_red_tiles(ctx)),
		"projected_unit": _unit_surface(projected),
		"pre_move": _action_surface(_committed_pre_move_for_unit(director, unit_id)),
		"action": _action_surface(_committed_action_for_unit(director, unit_id)),
		"post_move": _action_surface(_committed_post_move_for_unit(director, unit_id)),
	}
	var state_for_compare: Dictionary = snapshot.duplicate()
	state_for_compare.erase("label")
	var state_key: String = JSON.stringify(state_for_compare)
	if not save_screenshot and ctx.get("last_motion_state_key", "") == state_key:
		return
	ctx["last_motion_state_key"] = state_key
	ctx.trace.append(snapshot)
	if save_screenshot and _wants_trace_png(label):
		await _save_surface_screenshot(ctx, label)


func _capture_commit_state(ctx: Dictionary, unit_id: int, label: String) -> void:
	await _capture_planning_surface(ctx, unit_id, label)


func _remember_mode_commit(ctx: Dictionary, mode_key: String, unit_id: int) -> void:
	var director: CombatDirector = ctx.director
	var projected: UnitState = director.projected_state.get_unit_by_id(unit_id)
	ctx.mode_commits[mode_key] = {
		"projected_unit": _unit_surface(projected),
		"pre_move": _action_surface(_committed_pre_move_for_unit(director, unit_id)),
		"action": _action_surface(_committed_action_for_unit(director, unit_id)),
		"post_move": _action_surface(_committed_post_move_for_unit(director, unit_id)),
	}


func _assert_mode_commit_parity(ctx: Dictionary, selection_key: String, drag_key: String) -> void:
	assert_bool(ctx.mode_commits.has(selection_key)).override_failure_message(
		"missing recorded selection commit %s" % selection_key,
	).is_true()
	assert_bool(ctx.mode_commits.has(drag_key)).override_failure_message(
		"missing recorded drag commit %s" % drag_key,
	).is_true()
	if ctx.mode_commits.has(selection_key) and ctx.mode_commits.has(drag_key):
		assert_that(ctx.mode_commits[selection_key]).override_failure_message(
			"preview/commit parity diverged: %s != %s" % [selection_key, drag_key],
		).is_equal(ctx.mode_commits[drag_key])


func _record_mode_commit_comparison(ctx: Dictionary, selection_key: String, drag_key: String) -> void:
	var selection: Dictionary = ctx.mode_commits.get(selection_key, {})
	var drag: Dictionary = ctx.mode_commits.get(drag_key, {})
	ctx.trace.append({
		"label": "comparison/%s__%s" % [selection_key, drag_key],
		"selection": selection,
		"drag": drag,
		"exact_match": selection == drag,
	})


func _all_preview_paths(input: CombatPlanningInput) -> Dictionary:
	var out: Dictionary = {}
	for raw_id: Variant in input.preview_state.preview_paths.keys():
		out[str(raw_id)] = _cell_names(_preview_path(input, int(raw_id)))
	return out


func _unit_surface(unit: UnitState) -> Dictionary:
	if unit == null:
		return {}
	return {
		"id": unit.id,
		"position": _cell_name(unit.position),
		"ap": unit.ability.points_left,
		"mp": unit.movement.points_left,
		"facing": unit.facing,
	}


func _action_surface(action: TimelineAction) -> Dictionary:
	if action == null:
		return {}
	return {
		"type": action.type,
		"target": _cell_name(action.target_coord),
		"waypoints": _cell_names(action.waypoints),
		"uses_run": action.uses_run,
		"ability": action.ability.id if action.ability != null else "",
	}


func _cell_names(cells: Array) -> Array[String]:
	var out: Array[String] = []
	for cell: Variant in cells:
		if cell is Vector2i:
			out.append(_cell_name(cell))
	return out


func _cell_name(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _save_surface_screenshot(ctx: Dictionary, label: String) -> void:
	var out_dir: String = ProjectSettings.globalize_path(_TRACE_DIR)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var viewport: Viewport = ctx.scene.get_viewport()
	if viewport == null:
		return
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return
	var filename: String = _safe_trace_label(label) + ".png"
	image.save_png(out_dir.path_join(filename))


func _write_planning_trace(ctx: Dictionary) -> void:
	var out_dir: String = ProjectSettings.globalize_path(_TRACE_DIR)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var trace_file: FileAccess = FileAccess.open(out_dir.path_join("trace.json"), FileAccess.WRITE)
	assert_object(trace_file).override_failure_message("unable to write live planning trace").is_not_null()
	if trace_file != null:
		trace_file.store_string(JSON.stringify(ctx.trace, "\t"))
		trace_file.close()
	print("[LIVE-PLANNING-TRACE] %d transitions -> %strace.json" % [ctx.trace.size(), _TRACE_DIR])


func _safe_trace_label(label: String) -> String:
	return label.replace("/", "__").replace(":", "_").replace(" ", "_")


func _assert_move_tile_at(ctx: Dictionary, cell: Vector2i, expect: bool, label: String) -> void:
	assert_bool(ctx.overlay.is_hover_move_tile(cell) == expect).override_failure_message(
		"%s: blue move tile at %s expected %s" % [label, cell, expect],
	).is_true()


func _assert_overlay_tiles_in_bounds(ctx: Dictionary, label: String) -> void:
	var board: BoardState = ctx.board
	for cell: Vector2i in _collect_blue_tiles(ctx):
		assert_bool(board.is_in_bounds(cell)).override_failure_message(
			"%s: blue tile %s must be in bounds" % [label, cell],
		).is_true()
	for cell: Vector2i in _collect_red_tiles(ctx):
		assert_bool(board.is_in_bounds(cell)).override_failure_message(
			"%s: red tile %s must be in bounds" % [label, cell],
		).is_true()


func _assert_red_live(
	ctx: Dictionary,
	ability: AbilityData,
	expect_show: bool,
	expect_stand: Vector2i,
	label: String,
) -> void:
	var overlay: TacticalPlanningOverlay = ctx.overlay
	var has_red: bool = _overlay_has_red_tile(overlay, ctx.board)
	var gate_on: bool = ctx.input.action_range_visible_for_hover()
	assert_bool(gate_on == expect_show).override_failure_message(
		"%s: action-range gate expected %s got %s" % [label, expect_show, gate_on],
	).is_true()
	assert_bool(has_red == expect_show).override_failure_message(
		"%s: overlay red expected %s got %s" % [label, expect_show, has_red],
	).is_true()
	if expect_show and ability != null:
		var range_tiles: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
			ctx.board,
			ctx.director.projected_state.get_unit_by_id(ctx.director.selected_unit_id),
			ability,
			expect_stand,
		)
		var anchored: bool = false
		for tile: Vector2i in range_tiles:
			if overlay.is_hover_action_range_tile(tile):
				anchored = true
				break
		assert_bool(anchored).override_failure_message(
			"%s: no overlay red from AbilitySystem range at stand %s" % [label, expect_stand],
		).is_true()


func _assert_red_cell_live(
	ctx: Dictionary,
	ability: AbilityData,
	expect_in_red: bool,
	stand: Vector2i,
	cell: Vector2i,
	label: String,
) -> void:
	var overlay: TacticalPlanningOverlay = ctx.overlay
	var unit: UnitState = ctx.director.projected_state.get_unit_by_id(ctx.director.selected_unit_id)
	var range_tiles: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		ctx.board, unit, ability, stand,
	)
	var in_range: bool = range_tiles.has(cell)
	assert_bool(in_range == expect_in_red).override_failure_message(
		"%s: AbilitySystem range expected %s for %s at stand %s" % [
			label, expect_in_red, cell, stand,
		],
	).is_true()
	if expect_in_red:
		assert_bool(overlay.is_hover_action_range_tile(cell)).override_failure_message(
			"%s: overlay missing red at %s" % [label, cell],
		).is_true()
	else:
		assert_bool(overlay.is_hover_action_range_tile(cell)).override_failure_message(
			"%s: overlay must not show red at %s" % [label, cell],
		).is_false()
