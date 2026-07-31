class_name TramplingAdvanceE2ETest
extends RefCounted

## End-to-end Trampling Advance path tests through CombatPlanningInput commit slots,
## committed preview paths, overlay route legs, and Simulator move events.
## Matches TestBattle flow: select skill -> arm awaiting -> drag E-then-N -> commit.

const TRAMPLE_ID: StringName = &"knight_trampling_advance"
const START_CELL := Vector2i(5, 4)
const END_CELL := Vector2i(6, 3)
const EAST_THEN_NORTH: Array[Vector2i] = [Vector2i(6, 4), Vector2i(6, 3)]
const NORTH_THEN_EAST: Array[Vector2i] = [Vector2i(5, 3), Vector2i(6, 3)]


static func run_all(failures: Array[String]) -> void:
	_test_arm_and_commit_smoke(failures)
	_test_tile_by_tile_drag_route_preserves_paint_order(failures)
	_test_jump_drag_repath_must_not_replace_valid_painted_route(failures)
	_test_mouse_jump_drag_exposes_pathfinder_reorder(failures)
	_test_overlay_partial_paint_completes_to_hover(failures)
	_test_drag_commit_preserves_east_then_north_waypoints(failures)
	_test_drag_commit_with_auto_skill_after_move(failures)
	_test_paint_endpoint_intent_matches_drag_route(failures)
	_test_committed_overlay_route_leg_matches_paint(failures)
	_test_sim_move_events_follow_painted_order(failures)
	_test_post_move_leg_keeps_painted_route_after_trample(failures)
	_test_post_move_sim_preview_keeps_trample_paint_order(failures)
	_test_planning_animation_cells_after_post_move(failures)


static func _plain_board(size: Vector2i) -> BoardState:
	var terrain := TerrainData.new()
	terrain.id = &"plain"
	terrain.blocks_movement = false
	var board := BoardState.new()
	board.grid_size = size
	for y: int in range(size.y):
		for x: int in range(size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, terrain)
	return board


static func _trample_ability_index(unit: UnitState) -> int:
	for i: int in range(unit.active_abilities.size()):
		var ability: AbilityData = unit.active_abilities[i]
		if ability != null and ability.id == TRAMPLE_ID:
			return i
	return -1


static func _knight_fixture(start: Vector2i) -> Dictionary:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	director.plan_pre_move = Timeline.new()
	director.plan_action = Timeline.new()
	director.plan_post_move = Timeline.new()
	var board := _plain_board(Vector2i(12, 12))
	var knight_def: UnitData = DataLibrary.get_unit(&"knight")
	var unit: UnitState = UnitState.create(1, knight_def, GameEnums.Team.PLAYER, start)
	unit.active_abilities = DataLibrary.build_training_abilities(knight_def)
	unit.movement.points_left = unit.movement.max_points
	unit.ability.points_left = 1
	unit.ability.max_points = 1
	board.units = [unit]
	GridSystem.set_occupant(board, unit.position, unit.id)
	director.board = board
	director.base_board = board.clone()
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = 1
	var trample_idx: int = _trample_ability_index(unit)
	director.selected_ability_index = trample_idx
	input._director = director
	input.auto_use_skill_after_move = false
	return {
		"input": input,
		"director": director,
		"board": board,
		"unit": unit,
		"trample_idx": trample_idx,
	}


static func _test_arm_and_commit_smoke(failures: Array[String]) -> void:
	var fix: Dictionary = _knight_fixture(START_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("TramplingAdvanceE2E smoke: knight missing Trampling Advance (idx=%d)" % fix.trample_idx)
		return
	var arm_slots: Dictionary = input._final_commit_slots_for_interaction(1, unit.position)
	if _commit_slots_invalid(arm_slots):
		failures.append("TramplingAdvanceE2E smoke: arm slots marked invalid")
		return
	if (arm_slots.get("action", []) as Array).is_empty():
		failures.append("TramplingAdvanceE2E smoke: arm slots missing action (noop=%s)" % str(arm_slots.get("_noop", false)))
		return
	if not director.commit_from_slots(1, arm_slots):
		failures.append("TramplingAdvanceE2E smoke: arm commit_from_slots returned false")
		return
	director.flush_plan_refresh_signals_if_pending()
	if director.find_awaiting_action(1) == null:
		failures.append(
			"TramplingAdvanceE2E smoke: awaiting missing after arm; plan_action=%d combined=%d"
			% [director.plan_action.entries.size(), director.get_player_plan().entries.size()],
		)
		return
	if not input.awaiting_targeting_active():
		failures.append("TramplingAdvanceE2E smoke: awaiting_targeting_active false after arm")
		return
	var route: Array[Vector2i] = [START_CELL, EAST_THEN_NORTH[0], EAST_THEN_NORTH[1]]
	_paint_drag_route(input, unit, route, END_CELL)
	var params: Dictionary = input._commit_interaction_params(END_CELL, -1)
	if params.is_empty():
		failures.append("TramplingAdvanceE2E smoke: empty commit params")
		return
	var slots: Dictionary = input._final_commit_slots_for_interaction(
		1,
		params.cell,
		params.waypoints,
		params.legal_move_tiles,
		params.preferred,
		params.face_dir,
	)
	if _commit_slots_invalid(slots):
		failures.append(
			"TramplingAdvanceE2E smoke: invalid slots %s" % str(slots.get("invalid", "")),
		)
		return
	if (slots.get("action", []) as Array).is_empty():
		failures.append("TramplingAdvanceE2E smoke: no action in commit slots")
		return
	var slots_committed: Dictionary = _commit_drag_route(input, director, END_CELL)
	if slots_committed.is_empty():
		failures.append("TramplingAdvanceE2E smoke: commit_from_slots failed")
		return
	var action: TimelineAction = _committed_trample_action(director)
	if action == null:
		failures.append(
			"TramplingAdvanceE2E smoke: no trample action in plan entries=%d"
			% director.get_player_plan().entries.size(),
		)
		return
	if action.waypoints != EAST_THEN_NORTH:
		failures.append(
			"TramplingAdvanceE2E smoke: waypoints %s expected %s"
			% [str(action.waypoints), str(EAST_THEN_NORTH)],
		)


static func _commit_slots_invalid(slots: Dictionary) -> bool:
	if not slots.has("invalid"):
		return false
	var invalid_v: Variant = slots["invalid"]
	if typeof(invalid_v) == TYPE_BOOL:
		return invalid_v
	if typeof(invalid_v) == TYPE_STRING:
		return invalid_v != ""
	return true


static func _arm_trample_awaiting(input: CombatPlanningInput, director: CombatDirector, unit: UnitState) -> bool:
	var arm_slots: Dictionary = input._final_commit_slots_for_interaction(1, unit.position)
	if _commit_slots_invalid(arm_slots):
		return false
	if not director.commit_from_slots(1, arm_slots):
		return false
	director.flush_plan_refresh_signals_if_pending()
	return input.awaiting_targeting_active()


static func _paint_drag_route(
	input: CombatPlanningInput,
	unit: UnitState,
	route: Array[Vector2i],
	dest: Vector2i,
) -> void:
	input._drag_unit_id = unit.id
	input._drag_unit_was_selected = true
	input._drag_route = route.duplicate()
	input._drag_last_free = dest
	input.dragging = true
	director_set_hover(input, dest)


static func director_set_hover(input: CombatPlanningInput, cell: Vector2i) -> void:
	var intent := CombatIntentState.new()
	intent.bind(input._director)
	intent.set_hover_coord(cell)
	input._intent_state = intent


static func _commit_drag_route(
	input: CombatPlanningInput,
	director: CombatDirector,
	dest: Vector2i,
) -> Dictionary:
	var params: Dictionary = input._commit_interaction_params(dest, -1)
	var slots: Dictionary = input._final_commit_slots_for_interaction(
		1,
		params.cell,
		params.waypoints,
		params.legal_move_tiles,
		params.preferred,
		params.face_dir,
	)
	input.dragging = false
	if not director.commit_from_slots(1, slots):
		return {}
	director.flush_plan_refresh_signals_if_pending()
	return slots


static func _test_tile_by_tile_drag_route_preserves_paint_order(failures: Array[String]) -> void:
	var fix: Dictionary = _knight_fixture(START_CELL)
	var input: CombatPlanningInput = fix.input
	var unit: UnitState = fix.unit
	input._drag_unit_id = unit.id
	input._drag_route = [START_CELL]
	input._extend_drag_route(EAST_THEN_NORTH[0])
	input._extend_drag_route(EAST_THEN_NORTH[1])
	var painted: Array[Vector2i] = [START_CELL, EAST_THEN_NORTH[0], EAST_THEN_NORTH[1]]
	if input._drag_route != painted:
		failures.append(
			"TramplingAdvanceE2E tile drag: expected route %s, got %s"
			% [str(painted), str(input._drag_route)],
		)


static func _test_jump_drag_repath_must_not_replace_valid_painted_route(failures: Array[String]) -> void:
	var fix: Dictionary = _knight_fixture(START_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("TramplingAdvanceE2E jump drag: knight missing Trampling Advance ability")
		return
	_arm_trample_awaiting(input, director, unit)
	input._drag_unit_id = unit.id
	input._drag_route = [START_CELL]
	input._extend_drag_route(EAST_THEN_NORTH[0])
	input._extend_drag_route(END_CELL)
	var painted: Array[Vector2i] = [START_CELL, EAST_THEN_NORTH[0], END_CELL]
	if input._drag_route != painted:
		failures.append(
			"TramplingAdvanceE2E jump drag: painted E-then-N must survive endpoint jump, got %s"
			% str(input._drag_route),
		)


static func _test_mouse_jump_drag_exposes_pathfinder_reorder(failures: Array[String]) -> void:
	var fix: Dictionary = _knight_fixture(START_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("TramplingAdvanceE2E mouse jump: knight missing Trampling Advance ability")
		return
	_arm_trample_awaiting(input, director, unit)
	input._drag_unit_id = unit.id
	input._drag_route = [START_CELL]
	input._extend_drag_route(END_CELL)
	var expected_paint: Array[Vector2i] = [START_CELL, EAST_THEN_NORTH[0], END_CELL]
	if input._drag_route == expected_paint:
		return
	if input._drag_route == [START_CELL, NORTH_THEN_EAST[0], END_CELL]:
		failures.append(
			"TramplingAdvanceE2E mouse jump: drag snap used pathfinder N-then-E instead of E-then-N %s"
			% str(input._drag_route),
		)
		return
	failures.append(
		"TramplingAdvanceE2E mouse jump: unexpected drag route %s (expected painted E-then-N)"
		% str(input._drag_route),
	)


static func _test_drag_commit_with_auto_skill_after_move(failures: Array[String]) -> void:
	var fix: Dictionary = _knight_fixture(START_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("TramplingAdvanceE2E auto-skill: knight missing Trampling Advance ability")
		return
	input.auto_use_skill_after_move = true
	director.selected_ability_index = fix.trample_idx
	var route: Array[Vector2i] = [START_CELL, EAST_THEN_NORTH[0], EAST_THEN_NORTH[1]]
	_paint_drag_route(input, unit, route, END_CELL)
	var params: Dictionary = input._commit_interaction_params(END_CELL, -1)
	var slots: Dictionary = input._final_commit_slots_for_interaction(
		1,
		params.cell,
		params.waypoints,
		params.legal_move_tiles,
		params.preferred,
		params.face_dir,
	)
	input.dragging = false
	if not director.commit_from_slots(1, slots):
		failures.append("TramplingAdvanceE2E auto-skill: commit failed")
		return
	var action: TimelineAction = _committed_trample_action(director)
	_assert_waypoints(
		failures,
		action,
		EAST_THEN_NORTH,
		"TramplingAdvanceE2E auto-skill drag commit",
	)


static func _committed_trample_action(director: CombatDirector) -> TimelineAction:
	for action: TimelineAction in director.get_player_plan().entries:
		if action.actor_id != 1 or action.type != GameEnums.ActionType.ABILITY:
			continue
		if action.ability != null and action.ability.id == TRAMPLE_ID:
			return action
	return null


static func _assert_waypoints(
	failures: Array[String],
	action: TimelineAction,
	expected: Array[Vector2i],
	label: String,
) -> void:
	if action == null:
		failures.append("%s: missing committed trample action" % label)
		return
	if action.waypoints != expected:
		failures.append(
			"%s: expected waypoints %s, got %s" % [label, str(expected), str(action.waypoints)],
		)


static func _assert_route_cells(
	failures: Array[String],
	route: Array,
	expected: Array[Vector2i],
	label: String,
) -> void:
	var cells: Array[Vector2i] = []
	for step: Variant in route:
		if step is Vector2i:
			cells.append(step)
	if cells != expected:
		failures.append(
			"%s: expected route %s, got %s" % [label, str(expected), str(cells)],
		)


## Runtime path: sim events -> build_preview_paths -> ensure_movement_intent_from_plan.
static func _rebuild_committed_preview(director: CombatDirector) -> CombatPlanningPreview:
	var base: BoardState = director.base_board.clone() if director.base_board != null else director.board.clone()
	base.intents = []
	var result: SimResult = Simulator.simulate(base, director.get_player_plan())
	return CombatPlanningPreview.from_sim_result(result, director, base)


static func _test_overlay_partial_paint_completes_to_hover(failures: Array[String]) -> void:
	var origin := START_CELL
	var hover := END_CELL
	var drag_route: Array = [origin, EAST_THEN_NORTH[0]]
	var sim_path: Array = [origin, NORTH_THEN_EAST[0], hover]
	var route_cells: Array[Vector2i] = CombatPlanningPreview.awaiting_movement_route_cells(
		origin, hover, drag_route, sim_path,
	)
	_assert_route_cells(
		failures,
		route_cells,
		[origin, EAST_THEN_NORTH[0], hover],
		"TramplingAdvanceE2E overlay partial paint",
	)


static func _test_drag_commit_preserves_east_then_north_waypoints(failures: Array[String]) -> void:
	var fix: Dictionary = _knight_fixture(START_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("TramplingAdvanceE2E: knight missing Trampling Advance ability")
		return
	_arm_trample_awaiting(input, director, unit)
	var route: Array[Vector2i] = [START_CELL, EAST_THEN_NORTH[0], EAST_THEN_NORTH[1]]
	_paint_drag_route(input, unit, route, END_CELL)
	_commit_drag_route(input, director, END_CELL)
	var action: TimelineAction = _committed_trample_action(director)
	_assert_waypoints(
		failures,
		action,
		EAST_THEN_NORTH,
		"TramplingAdvanceE2E drag commit",
	)
	if action != null and action.target_coord != END_CELL:
		failures.append(
			"TramplingAdvanceE2E drag commit: target should be %s, got %s"
			% [str(END_CELL), str(action.target_coord)],
		)


static func _test_paint_endpoint_intent_matches_drag_route(failures: Array[String]) -> void:
	var fix: Dictionary = _knight_fixture(START_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("TramplingAdvanceE2E paint: knight missing Trampling Advance ability")
		return
	_arm_trample_awaiting(input, director, unit)
	var route: Array[Vector2i] = [START_CELL, EAST_THEN_NORTH[0], EAST_THEN_NORTH[1]]
	_paint_drag_route(input, unit, route, END_CELL)
	if not input._paint_valid_movement_endpoint_intent():
		failures.append("TramplingAdvanceE2E paint: endpoint intent paint failed")
		return
	var preview_path: Array = input.preview_state.preview_paths.get(1, [])
	_assert_route_cells(
		failures,
		preview_path,
		[START_CELL, EAST_THEN_NORTH[0], EAST_THEN_NORTH[1]],
		"TramplingAdvanceE2E paint preview path",
	)


static func _test_committed_overlay_route_leg_matches_paint(failures: Array[String]) -> void:
	var fix: Dictionary = _knight_fixture(START_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("TramplingAdvanceE2E overlay: knight missing Trampling Advance ability")
		return
	_arm_trample_awaiting(input, director, unit)
	var route: Array[Vector2i] = [START_CELL, EAST_THEN_NORTH[0], EAST_THEN_NORTH[1]]
	_paint_drag_route(input, unit, route, END_CELL)
	_commit_drag_route(input, director, END_CELL)
	var action: TimelineAction = _committed_trample_action(director)
	if action == null:
		failures.append("TramplingAdvanceE2E overlay: missing committed trample action")
		return
	var preview: CombatPlanningPreview = _rebuild_committed_preview(director)
	var leg: Array = CombatPlanningPreview.committed_action_route_leg(
		1, preview, action, START_CELL,
	)
	_assert_route_cells(
		failures,
		leg,
		[START_CELL, EAST_THEN_NORTH[0], EAST_THEN_NORTH[1]],
		"TramplingAdvanceE2E committed overlay leg",
	)
	var director_wps: Array[Vector2i] = director.get_planned_skill_walk_waypoints(1, END_CELL)
	if director_wps != EAST_THEN_NORTH:
		failures.append(
			"TramplingAdvanceE2E director skill walk: expected %s, got %s"
			% [str(EAST_THEN_NORTH), str(director_wps)],
		)


static func _test_sim_move_events_follow_painted_order(failures: Array[String]) -> void:
	var fix: Dictionary = _knight_fixture(START_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("TramplingAdvanceE2E sim: knight missing Trampling Advance ability")
		return
	_arm_trample_awaiting(input, director, unit)
	var route: Array[Vector2i] = [START_CELL, EAST_THEN_NORTH[0], EAST_THEN_NORTH[1]]
	_paint_drag_route(input, unit, route, END_CELL)
	if _commit_drag_route(input, director, END_CELL).is_empty():
		failures.append("TramplingAdvanceE2E sim: trample commit failed")
		return
	var action: TimelineAction = _committed_trample_action(director)
	if action == null or action.waypoints != EAST_THEN_NORTH:
		failures.append(
			"TramplingAdvanceE2E sim: trample waypoints %s"
			% str(action.waypoints if action != null else null),
		)
		return
	var start_board: BoardState = director.base_board.clone()
	start_board.intents = []
	var result: SimResult = Simulator.simulate(start_board, director.get_player_plan())
	var visited: Array[Vector2i] = [START_CELL]
	for event: SimEvent in result.events:
		if event.type != GameEnums.SimEventType.UNIT_MOVED:
			continue
		if int(event.data.get("actor", -1)) != 1:
			continue
		var path_v: Variant = event.data.get("path", [])
		if path_v is Array and not (path_v as Array).is_empty():
			for step: Variant in path_v:
				if step is Vector2i:
					visited.append(step)
			continue
		var to_cell: Variant = event.data.get("to")
		if to_cell is Vector2i:
			visited.append(to_cell)
	if visited != [START_CELL, EAST_THEN_NORTH[0], EAST_THEN_NORTH[1]]:
		failures.append(
			"TramplingAdvanceE2E sim: move events visited %s, expected E-then-N %s"
			% [str(visited), str([START_CELL, EAST_THEN_NORTH[0], EAST_THEN_NORTH[1]])],
		)
	var actor_after: UnitState = result.final_state.get_unit_by_id(1)
	if actor_after == null or actor_after.position != END_CELL:
		failures.append(
			"TramplingAdvanceE2E sim: final position should be %s, got %s"
			% [str(END_CELL), str(actor_after.position if actor_after != null else null)],
		)


static func _test_post_move_leg_keeps_painted_route_after_trample(failures: Array[String]) -> void:
	var fix: Dictionary = _knight_fixture(START_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("TramplingAdvanceE2E post-move: knight missing Trampling Advance ability")
		return
	var commit: Dictionary = _commit_trample_then_post_move(input, director, unit)
	if not commit.get("ok", false):
		failures.append("TramplingAdvanceE2E post-move: commit failed")
		return
	var trample_action: TimelineAction = _committed_trample_action(director)
	_assert_waypoints(
		failures,
		trample_action,
		EAST_THEN_NORTH,
		"TramplingAdvanceE2E post-move trample waypoints",
	)
	var post_move: TimelineAction = null
	for action: TimelineAction in director.get_player_plan().entries:
		if (
			action.actor_id == 1
			and action.type == GameEnums.ActionType.MOVE
			and action.move_timing == GameEnums.MoveTiming.POST_ACTION
		):
			post_move = action
	if post_move == null:
		failures.append("TramplingAdvanceE2E post-move: missing committed post-move action")
		return
	var expected_post_wps: Array[Vector2i] = []
	for wp: Variant in commit.get("post_waypoints", []):
		expected_post_wps.append(wp as Vector2i)
	if post_move.waypoints != expected_post_wps:
		failures.append(
			"TramplingAdvanceE2E post-move: expected waypoints %s, got %s"
			% [str(expected_post_wps), str(post_move.waypoints)],
		)
	var preview: CombatPlanningPreview = _rebuild_committed_preview(director)
	var full_path: Array = preview.preview_paths.get(1, [])
	var expected_full: Array[Vector2i] = [
		START_CELL,
		EAST_THEN_NORTH[0],
		EAST_THEN_NORTH[1],
		expected_post_wps[0],
		expected_post_wps[1],
		expected_post_wps[2],
	]
	_assert_route_cells(
		failures,
		full_path,
		expected_full,
		"TramplingAdvanceE2E post-move full preview path",
	)


static func _commit_trample_then_post_move(
	input: CombatPlanningInput,
	director: CombatDirector,
	unit: UnitState,
) -> Dictionary:
	_arm_trample_awaiting(input, director, unit)
	var trample_route: Array[Vector2i] = [START_CELL, EAST_THEN_NORTH[0], EAST_THEN_NORTH[1]]
	_paint_drag_route(input, unit, trample_route, END_CELL)
	_commit_drag_route(input, director, END_CELL)
	director.selected_ability_index = -1
	input.force_basic_movement = true
	var post_dest := Vector2i(8, 2)
	var post_route: Array[Vector2i] = [END_CELL, Vector2i(7, 3), Vector2i(8, 3), post_dest]
	input._drag_route = post_route.duplicate()
	input._drag_last_free = post_dest
	input.dragging = true
	director_set_hover(input, post_dest)
	var post_params: Dictionary = input._commit_interaction_params(post_dest, -1)
	var post_slots: Dictionary = input._final_commit_slots_for_interaction(
		1,
		post_params.cell,
		post_params.waypoints,
		post_params.legal_move_tiles,
		post_params.preferred,
		post_params.face_dir,
	)
	input.dragging = false
	if not director.commit_from_slots(1, post_slots):
		return {"ok": false}
	director.flush_plan_refresh_signals_if_pending()
	return {
		"ok": true,
		"post_dest": post_dest,
		"post_waypoints": [Vector2i(7, 3), Vector2i(8, 3), post_dest],
	}


static func _test_post_move_sim_preview_keeps_trample_paint_order(failures: Array[String]) -> void:
	var fix: Dictionary = _knight_fixture(START_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("TramplingAdvanceE2E sim preview: knight missing Trampling Advance ability")
		return
	var commit: Dictionary = _commit_trample_then_post_move(input, director, unit)
	if not commit.get("ok", false):
		failures.append("TramplingAdvanceE2E sim preview: post-move commit failed")
		return
	var trample_action: TimelineAction = _committed_trample_action(director)
	_assert_waypoints(
		failures,
		trample_action,
		EAST_THEN_NORTH,
		"TramplingAdvanceE2E sim preview trample waypoints",
	)
	var preview: CombatPlanningPreview = _rebuild_committed_preview(director)
	var trample_leg: Array = CombatPlanningPreview.committed_action_route_leg(
		1, preview, trample_action, START_CELL,
	)
	_assert_route_cells(
		failures,
		trample_leg,
		[START_CELL, EAST_THEN_NORTH[0], EAST_THEN_NORTH[1]],
		"TramplingAdvanceE2E sim preview trample leg",
	)
	var director_wps: Array[Vector2i] = director.get_planned_skill_walk_waypoints(1, END_CELL)
	if director_wps != EAST_THEN_NORTH:
		failures.append(
			"TramplingAdvanceE2E sim preview director walk: expected %s, got %s"
			% [str(EAST_THEN_NORTH), str(director_wps)],
		)
	var start_board: BoardState = director.base_board.clone()
	start_board.intents = []
	var result: SimResult = Simulator.simulate(start_board, director.get_player_plan())
	var visited: Array[Vector2i] = [START_CELL]
	for event: SimEvent in result.events:
		if event.type != GameEnums.SimEventType.UNIT_MOVED:
			continue
		if int(event.data.get("actor", -1)) != 1:
			continue
		var path_v: Variant = event.data.get("path", [])
		if path_v is Array and not (path_v as Array).is_empty():
			for step: Variant in path_v:
				if step is Vector2i:
					visited.append(step)
			continue
		var to_cell: Variant = event.data.get("to")
		if to_cell is Vector2i:
			visited.append(to_cell)
	var expected_post_wps: Array[Vector2i] = [Vector2i(7, 3), Vector2i(8, 3), commit.post_dest]
	var expected_full: Array[Vector2i] = [
		START_CELL,
		EAST_THEN_NORTH[0],
		EAST_THEN_NORTH[1],
		expected_post_wps[0],
		expected_post_wps[1],
		expected_post_wps[2],
	]
	if visited != expected_full:
		failures.append(
			"TramplingAdvanceE2E sim preview: move events visited %s, expected %s"
			% [str(visited), str(expected_full)],
		)


static func _test_planning_animation_cells_after_post_move(failures: Array[String]) -> void:
	var fix: Dictionary = _knight_fixture(START_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("TramplingAdvanceE2E animation: knight missing Trampling Advance ability")
		return
	var commit: Dictionary = _commit_trample_then_post_move(input, director, unit)
	if not commit.get("ok", false):
		failures.append("TramplingAdvanceE2E animation: post-move commit failed")
		return
	var preview: CombatPlanningPreview = _rebuild_committed_preview(director)
	var trample_anim: Array[Vector2i] = CombatPlanningPreview.planning_animation_cells(
		1, preview, START_CELL, END_CELL, director, fix.board,
	)
	_assert_route_cells(
		failures,
		trample_anim,
		EAST_THEN_NORTH,
		"TramplingAdvanceE2E animation trample leg",
	)
	var post_dest: Vector2i = commit.post_dest
	var post_anim: Array[Vector2i] = CombatPlanningPreview.planning_animation_cells(
		1, preview, END_CELL, post_dest, director, fix.board,
	)
	var expected_post_wps: Array[Vector2i] = [Vector2i(7, 3), Vector2i(8, 3), post_dest]
	_assert_route_cells(
		failures,
		post_anim,
		expected_post_wps,
		"TramplingAdvanceE2E animation post-move leg",
	)
