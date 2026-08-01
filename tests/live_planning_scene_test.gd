## Tier 3 acceptance: one TestBattle session, multi-knight planning bible, then execute.
##
## Boots the real scene once, places four knights and two dummies, walks the 7-phase
## checklist layers through live mouse input, then runs Ready → Execute and verifies
## final board positions match preview/commit promises.
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const _RUN_ID: StringName = &"universal_run"
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
const _TRAMPLE_ROUTE: Array[Vector2i] = [Vector2i(6, 4), Vector2i(6, 3)]
const _TRAMPLE_END := Vector2i(6, 3)
const _K4_RUN_DEST := Vector2i(0, 1)
const _K4_RUN_MID := Vector2i(2, 1)
const _K4_RUN_ROUTE: Array[Vector2i] = [_K4_CELL, _K4_RUN_MID, _K4_RUN_DEST]

const _SETTLE_FRAMES := 4
const _SETTLE_DELTA_MS := 20
const _ABILITY_SETTLE_FRAMES := 6


func test_live_planning_bible_multi_knight_session(timeout := 90000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	await runner.simulate_frames(8)
	var scene: TestBattleMapView = runner.scene() as TestBattleMapView
	assert_object(scene).is_not_null()
	var ctx: Dictionary = await _boot_multi_knight_session(runner, scene)
	await _journey_knight1_shield_bash(ctx)
	await _journey_knight2_chain_hook(ctx)
	await _journey_knight3_trampling_advance(ctx)
	await _journey_knight4_run_economy(ctx)
	await _journey_execute_all_plans(ctx)
	await _journey_scroll_and_undo_smoke(ctx)


func _boot_multi_knight_session(runner: GdUnitSceneRunner, scene: TestBattleMapView) -> Dictionary:
	var session: TestBattleSession = scene.get_session()
	session.reset_defaults()
	session.extra_player_coords = [_K2_CELL, _K3_CELL, _K4_CELL]
	session.dummy_coords = [_E_BASH_CELL, _E_HOOK_CELL]
	scene.apply_training_board()
	await runner.simulate_frames(_SETTLE_FRAMES, _SETTLE_DELTA_MS)
	var shell: TacticalCombatShell = scene.get_node("CombatShell") as TacticalCombatShell
	var director: CombatDirector = scene.get_node("CombatDirector") as CombatDirector
	var overlay: TacticalPlanningOverlay = scene.get_node(
		"WorldModulate/MapRoot/PlanningOverlay",
	) as TacticalPlanningOverlay
	director.auto_run = true
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
	}
	assert_int(ctx.k1_id).is_greater(0)
	assert_int(ctx.k2_id).is_greater(0)
	assert_int(ctx.k3_id).is_greater(0)
	assert_int(ctx.k4_id).is_greater(0)
	assert_int(ctx.e_bash_id).is_greater(0)
	assert_int(ctx.e_hook_id).is_greater(0)
	return ctx


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
	await _hover_cell(ctx, _K1_CELL)
	assert_bool(_overlay_has_blue_tile(overlay, director.board)).is_true()
	_assert_red_live(ctx, bash, true, _K1_CELL, "k1/phase1/red_at_stand")
	_assert_red_cell_live(ctx, bash, false, _K1_CELL, _E_BASH_CELL, "k1/phase1/enemy_oob")
	await _hover_cell(ctx, _HOVER_WALK)
	var ghost: UnitState = await _preview_unit(ctx, k1_id, _HOVER_WALK)
	assert_object(ghost).is_not_null()
	assert_that(ghost.position).is_equal(_HOVER_WALK)
	_assert_preview_path_ends(
		ctx, k1_id, _HOVER_WALK, 2, _K1_CELL, "k1/phase2/walk_path",
	)
	_assert_red_live(ctx, bash, true, _HOVER_WALK, "k1/phase2/red_follows_walk")
	var walk_icon: String = input.compute_hover_action_icon(_HOVER_WALK)
	assert_bool(walk_icon.contains(PlanningIcons.GLYPH_WALK)).is_true()
	await _hover_cell(ctx, _E_BASH_CELL)
	ghost = await _preview_unit(ctx, k1_id, _BASH_APPROACH)
	assert_that(ghost.position).is_equal(_BASH_APPROACH)
	_assert_preview_path_ends(
		ctx, k1_id, _BASH_APPROACH, 3, _K1_CELL, "k1/phase4/approach_path",
	)
	_assert_red_live(ctx, bash, true, _BASH_APPROACH, "k1/phase4/red_at_approach")
	var push_to: Vector2i = _preview_push_destination(input, e_bash_id)
	assert_bool(push_to.x > _E_BASH_CELL.x).is_true()
	var enemy_icon: String = input.compute_hover_action_icon(_E_BASH_CELL)
	assert_bool(enemy_icon.contains(PlanningIcons.GLYPH_WALK)).is_true()
	assert_bool(enemy_icon.contains(PlanningIcons.GLYPH_ATTACK)).is_true()
	await _tap_cell(ctx, _E_BASH_CELL)
	await _wait_ability_settle(ctx)
	assert_int(director.plan_pre_move.entries.size()).is_greater(0)
	assert_int(director.plan_action.entries.size()).is_greater(0)
	var bash_pre: TimelineAction = _committed_pre_move_for_unit(director, k1_id)
	assert_object(bash_pre).is_not_null()
	assert_that(bash_pre.target_coord).is_equal(_BASH_APPROACH)
	var projected: UnitState = director.projected_state.get_unit_by_id(k1_id)
	assert_object(projected).is_not_null()
	assert_int(projected.ability.points_left).is_equal(0)
	await _hover_cell(ctx, _BASH_APPROACH)
	await _wait_ability_settle(ctx)
	_assert_red_live(ctx, bash, false, _BASH_APPROACH, "k1/phase5/red_off_after_commit")
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
	await _hover_cell(ctx, _K2_CELL)
	_assert_red_live(ctx, hook, true, _K2_CELL, "k2/phase1/red_at_stand")
	_assert_red_cell_live(ctx, hook, true, _K2_CELL, _E_HOOK_CELL, "k2/phase1/enemy_in_red")
	await _hover_cell(ctx, Vector2i(2, 3))
	var ghost: UnitState = await _preview_unit(ctx, k2_id, Vector2i(2, 3))
	assert_that(ghost.position).is_equal(Vector2i(2, 3))
	_assert_preview_path_ends(
		ctx, k2_id, Vector2i(2, 3), 2, _K2_CELL, "k2/phase2/walk_path",
	)
	_assert_red_cell_live(ctx, hook, true, Vector2i(2, 3), _E_HOOK_CELL, "k2/phase2/enemy_in_red")
	await _hover_cell(ctx, _E_HOOK_CELL)
	await _wait_ability_settle(ctx)
	var pull_preview: Vector2i = _preview_push_destination(input, e_hook_id)
	if pull_preview.x > -900000:
		assert_bool(pull_preview.x < _E_HOOK_CELL.x).is_true()
	var hook_icon: String = input.compute_hover_action_icon(_E_HOOK_CELL)
	assert_bool(hook_icon.contains(PlanningIcons.GLYPH_ATTACK)).is_true()
	await _tap_cell(ctx, _E_HOOK_CELL)
	await ctx.runner.simulate_frames(_ABILITY_SETTLE_FRAMES, _SETTLE_DELTA_MS)
	assert_int(director.plan_action.entries.size()).is_greater(0)
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
	await _tap_cell(ctx, _K3_CELL)
	await _wait_ability_settle(ctx)
	assert_bool(input.awaiting_targeting_active()).is_true()
	assert_object(director.find_awaiting_action(k3_id)).is_not_null()
	_assert_red_live(ctx, trample, true, _K3_CELL, "k3/phase3/red_while_awaiting")
	var route: Array[Vector2i] = [_K3_CELL, _TRAMPLE_ROUTE[0], _TRAMPLE_ROUTE[1]]
	await _drag_through_cells_with_route_checks(ctx, route, "k3", false, &"exact")
	var action: TimelineAction = _committed_action_for_unit(director, k3_id)
	assert_object(action).is_not_null()
	assert_that(action.waypoints).is_equal(_TRAMPLE_ROUTE)
	var projected: UnitState = director.projected_state.get_unit_by_id(k3_id)
	assert_object(projected).is_not_null()
	assert_that(projected.position).is_equal(_TRAMPLE_END)
	assert_int(projected.ability.points_left).is_equal(0)
	ctx.expect["k3_pos"] = _TRAMPLE_END
	_cancel_active_pointer(ctx)


func _journey_knight4_run_economy(ctx: Dictionary) -> void:
	var director: CombatDirector = ctx.director
	var input: CombatPlanningInput = ctx.input
	var k4_id: int = ctx.k4_id
	await _select_unit_live(ctx, k4_id, _K4_CELL)
	await _select_ability_for_unit(ctx, k4_id, _RUN_ID)
	await _drag_through_cells_with_route_checks(
		ctx, _K4_RUN_ROUTE, "k4/run", false, &"corridor_horizontal",
	)
	assert_bool(_plan_uses_run_for_unit(director, k4_id)).is_true()
	var projected: UnitState = director.projected_state.get_unit_by_id(k4_id)
	assert_that(projected.position).is_equal(_K4_RUN_DEST)
	assert_int(input.planning_display_ap_left(k4_id)).is_equal(0)
	var bowling: AbilityData = await _select_ability_for_unit(ctx, k4_id, _BOWLING_CHARGE_ID)
	assert_object(bowling).is_not_null()
	await _hover_cell(ctx, Vector2i(2, 1))
	await ctx.runner.simulate_frames(_ABILITY_SETTLE_FRAMES, _SETTLE_DELTA_MS)
	assert_int(input.planning_display_ap_left(k4_id)).is_equal(0)
	assert_bool(input.action_range_visible_for_hover()).is_false()
	assert_bool(_overlay_has_red_tile(ctx.overlay, director.board)).is_false()
	ctx.expect["k4_pos"] = _K4_RUN_DEST
	_cancel_active_pointer(ctx)


func _journey_execute_all_plans(ctx: Dictionary) -> void:
	var director: CombatDirector = ctx.director
	var board: BoardState = director.board
	GlobalTimeline.rpc_set_ready(true)
	await _wait_until_not_executing(ctx)
	assert_bool(CombatDirector.is_planning_phase(director.phase)).is_true()
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


func _journey_scroll_and_undo_smoke(ctx: Dictionary) -> void:
	var scene: TestBattleMapView = ctx.scene
	var director: CombatDirector = ctx.director
	scene.apply_training_board()
	await ctx.runner.simulate_frames(_SETTLE_FRAMES, _SETTLE_DELTA_MS)
	_refresh_ctx_board(ctx)
	director.auto_run = true
	var before_scroll: int = director.selected_ability_index
	ctx.runner.simulate_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN)
	await _wait_ability_settle(ctx)
	assert_int(director.selected_ability_index).is_not_equal(before_scroll)
	await _select_unit_live(ctx, ctx.k4_id, _K4_CELL)
	await _select_ability_for_unit(ctx, ctx.k4_id, _RUN_ID)
	await _drag_between_cells(ctx, _K4_CELL, _K4_RUN_DEST)
	assert_int(director.plan_pre_move.entries.size()).is_greater(0)
	ctx.runner.simulate_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	await ctx.runner.simulate_frames(_SETTLE_FRAMES, _SETTLE_DELTA_MS)
	assert_int(director.plan_pre_move.entries.size()).is_equal(0)


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
			await runner.simulate_frames(_ABILITY_SETTLE_FRAMES, _SETTLE_DELTA_MS)
			return ability
	assert_that("Required ability missing for unit %d: %s" % [unit_id, ability_id]).is_equal("")
	return null


func _select_unit_live(ctx: Dictionary, unit_id: int, cell: Vector2i) -> void:
	_cancel_active_pointer(ctx)
	ctx.director.select_unit(unit_id)
	await _wait_ability_settle(ctx)
	assert_int(ctx.director.selected_unit_id).is_equal(unit_id)
	await _hover_cell(ctx, cell)


func _tap_cell(ctx: Dictionary, cell: Vector2i) -> void:
	var runner: GdUnitSceneRunner = ctx.runner
	await _hover_cell(ctx, cell)
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(2, _SETTLE_DELTA_MS)
	runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(_SETTLE_FRAMES, _SETTLE_DELTA_MS)


func _hover_cell(ctx: Dictionary, cell: Vector2i) -> void:
	var runner: GdUnitSceneRunner = ctx.runner
	var scene: TestBattleMapView = ctx.scene
	var map_root: Node2D = scene.get_node("WorldModulate/MapRoot") as Node2D
	var screen_pos: Vector2 = scene.position + scene.grid_to_local(cell) * map_root.scale.x
	runner.simulate_mouse_move(screen_pos)
	await runner.simulate_frames(2, _SETTLE_DELTA_MS)


func _drag_between_cells(ctx: Dictionary, from: Vector2i, to: Vector2i) -> void:
	await _drag_through_cells(ctx, [from, to])


func _drag_through_cells(
	ctx: Dictionary,
	cells: Array[Vector2i],
	assert_hover_steps: bool = true,
) -> void:
	if cells.is_empty():
		return
	var runner: GdUnitSceneRunner = ctx.runner
	var input: CombatPlanningInput = ctx.input
	await _hover_cell(ctx, cells[0])
	if assert_hover_steps:
		assert_that(input.get_hover_tile_for_ui()).is_equal(cells[0])
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(3, _SETTLE_DELTA_MS)
	for i: int in range(1, cells.size()):
		await _hover_cell(ctx, cells[i])
		if assert_hover_steps:
			assert_that(input.get_hover_tile_for_ui()).is_equal(cells[i])
		await runner.simulate_frames(3, _SETTLE_DELTA_MS)
	runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(_ABILITY_SETTLE_FRAMES, _SETTLE_DELTA_MS)


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
	await _hover_cell(ctx, cells[0])
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(3, _SETTLE_DELTA_MS)
	for step_index: int in range(1, cells.size()):
		await _hover_cell(ctx, cells[step_index])
		await runner.simulate_frames(3, _SETTLE_DELTA_MS)
		var expected: Array[Vector2i] = []
		for j: int in range(step_index + 1):
			expected.append(cells[j])
		if route_mode == &"corridor_horizontal":
			_assert_drag_route_corridor(
				ctx, cells[0], cells[step_index],
				"%s/drag_route_%d" % [label_prefix, step_index],
			)
			await runner.simulate_frames(2, _SETTLE_DELTA_MS)
			var painted: Array[Vector2i] = ctx.input.get_drag_route()
			_assert_preview_path_equals(
				ctx, unit_id, painted, "%s/preview_path_%d" % [label_prefix, step_index],
			)
		else:
			_assert_drag_route_equals(ctx, expected, "%s/drag_route_%d" % [label_prefix, step_index])
			assert_bool(input._paint_valid_movement_endpoint_intent()).override_failure_message(
				"%s: endpoint paint failed at step %d" % [label_prefix, step_index],
			).is_true()
			await runner.simulate_frames(2, _SETTLE_DELTA_MS)
			_assert_preview_path_equals(
				ctx, unit_id, expected, "%s/preview_path_%d" % [label_prefix, step_index],
			)
		if assert_timeline_empty:
			assert_int(director.plan_pre_move.entries.size()).is_equal(0)
	runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(_ABILITY_SETTLE_FRAMES, _SETTLE_DELTA_MS)


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
	expected: Array[Vector2i],
	label: String,
) -> void:
	var path: Array[Vector2i] = _preview_path(ctx.input, unit_id)
	assert_that(path).override_failure_message(
		"%s: preview path expected %s got %s" % [label, expected, path],
	).is_equal(expected)


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
		await ctx.runner.simulate_frames(2, _SETTLE_DELTA_MS)


func _wait_ability_settle(ctx: Dictionary) -> void:
	await ctx.runner.simulate_frames(_ABILITY_SETTLE_FRAMES, _SETTLE_DELTA_MS)


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
		await ctx.runner.simulate_frames(2, _SETTLE_DELTA_MS)
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


func _wait_until_not_executing(ctx: Dictionary) -> void:
	var director: CombatDirector = ctx.director
	var runner: GdUnitSceneRunner = ctx.runner
	for _attempt: int in range(240):
		if CombatDirector.is_planning_phase(director.phase):
			return
		await runner.simulate_frames(2, _SETTLE_DELTA_MS)
	assert_that("execute did not return to planning within frame budget").is_equal("")


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


func _overlay_has_red_tile(overlay: TacticalPlanningOverlay, board: BoardState) -> bool:
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			if overlay.is_hover_action_range_tile(Vector2i(x, y)):
				return true
	return false


func _overlay_has_blue_tile(overlay: TacticalPlanningOverlay, board: BoardState) -> bool:
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			if overlay.is_hover_move_tile(Vector2i(x, y)):
				return true
	return false


func _assert_red_live(
	ctx: Dictionary,
	ability: AbilityData,
	expect_show: bool,
	expect_stand: Vector2i,
	label: String,
) -> void:
	var input: CombatPlanningInput = ctx.input
	var overlay: TacticalPlanningOverlay = ctx.overlay
	var visible: bool = input.action_range_visible_for_hover()
	assert_bool(visible == expect_show).override_failure_message(
		"%s: visibility gate expected %s got %s" % [label, expect_show, visible],
	).is_true()
	var has_red: bool = _overlay_has_red_tile(overlay, ctx.board)
	assert_bool(has_red == expect_show).override_failure_message(
		"%s: overlay red expected %s got %s" % [label, expect_show, has_red],
	).is_true()
	if expect_stand.x > -900000:
		assert_that(input.action_range_intent_stand_cell(ctx.director.selected_unit_id)).is_equal(
			expect_stand,
		)
	if expect_show and ability != null:
		var stand: Vector2i = input.action_range_intent_stand_cell(ctx.director.selected_unit_id)
		var range_tiles: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
			ctx.board,
			ctx.director.projected_state.get_unit_by_id(ctx.director.selected_unit_id),
			ability,
			stand,
		)
		var anchored: bool = false
		for tile: Vector2i in range_tiles:
			if overlay.is_hover_action_range_tile(tile):
				anchored = true
				break
		assert_bool(anchored).override_failure_message(
			"%s: no overlay red from AbilitySystem range at stand %s" % [label, stand],
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
