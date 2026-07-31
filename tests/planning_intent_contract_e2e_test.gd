class_name PlanningIntentContractE2ETest
extends RefCounted

## Production input contracts that span hover -> click -> committed timeline ->
## projected economy -> refreshed overlay. These are intentionally not helper-only
## assertions: each test uses CombatPlanningInput's actual click entry point.

static func run_all(failures: Array[String]) -> void:
	_test_bowling_run_click_hides_red_across_refreshes(failures)
	_test_bowling_waypoint_run_center_hides_red(failures)
	_test_painted_run_preview_interior_walk_hides_red(failures)
	_test_committed_run_center_blue_hover_hides_red(failures)
	_test_pre_run_binding_when_move_timing_closed(failures)
	_test_red_hidden_when_projected_ap_zero(failures)
	_test_f5_display_ap_zero_implies_no_red(failures)
	_test_f5_stale_projection_at_run_dest_display_ap_zero(failures)
	_test_simulation_validator_rejects_invalid_timeline_action(failures)


static func _test_bowling_run_click_hides_red_across_refreshes(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var map_stub: QaPlanningMapStub = fix.map_stub as QaPlanningMapStub
	director.auto_run = true
	PlanningChecklistHarness.set_knight_pools(fix, 1, 0)
	director.selected_ability_index = -1
	input.auto_use_skill_after_move = false
	var run_dest: Vector2i = PlanningChecklistHarness.find_run_hover_tile(
		fix.board, fix.knight,
	)
	if run_dest.x <= -900000:
		PlanningChecklistHarness.assert_fail(
			failures, "intent_contract/bowling_run", "fixture has no run destination",
		)
		return
	PlanningChecklistHarness.hover(fix, run_dest)
	var click_slots: Dictionary = PlanningChecklistHarness.slots_for_click(fix, run_dest)
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/bowling_run/precondition",
		not PlanningChecklistHarness._slots_invalid(click_slots),
		"click slots must be valid before production click: %s" % str(click_slots),
	)
	input.on_left_press(map_stub.grid_to_local(run_dest))
	PlanningChecklistHarness.flush_planning(fix)
	var bowling_index: int = PlanningChecklistHarness.select_ability(
		fix, PlanningChecklistHarness.BOWLING_CHARGE_ID,
	)
	if bowling_index < 0:
		PlanningChecklistHarness.assert_fail(
			failures, "intent_contract/bowling_run", "Bowling Charge missing",
		)
		return

	var pre_moves: Array = director.plan_pre_move.entries
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/bowling_run/timeline",
		not pre_moves.is_empty(),
		"production click must commit a pre-move; pre-click slots=%s"
		% str(click_slots),
	)
	if pre_moves.is_empty():
		return
	var run: TimelineAction = pre_moves[0] as TimelineAction
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/bowling_run/timeline",
		run != null and run.uses_run and run.target_coord == run_dest,
		"committed pre-move must retain the Run action and its clicked destination",
	)
	var projected: UnitState = PlanningChecklistHarness.projected_unit(fix, 1)
	PlanningChecklistHarness.assert_eq_cell(
		failures,
		"intent_contract/bowling_run/projection",
		projected.position if projected != null else Vector2i(-999999, -999999),
		run_dest,
	)
	PlanningChecklistHarness.assert_eq_int(
		failures,
		"intent_contract/bowling_run/projection",
		projected.ability.points_left if projected != null else -1,
		0,
	)

	var bowling: AbilityData = fix.knight.active_abilities[bowling_index]
	_assert_red_stays_hidden_after_refresh(
		failures, fix, input, bowling, run_dest, "destination",
	)
	_assert_red_stays_hidden_after_refresh(
		failures, fix, input, bowling, PlanningChecklistHarness.ENEMY_POS, "enemy",
	)


## F5 parity: paint waypoints through center walk tiles (1 MP walk + Run finish),
## commit from painted hover slots, select Bowling Charge — red must stay off at 0 AP.
static func _test_bowling_waypoint_run_center_hides_red(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	director.auto_run = true
	input.auto_use_skill_after_move = false
	director.selected_ability_index = -1
	var painted: Dictionary = PlanningChecklistHarness.find_painted_center_run_dest(fix, 1, 1)
	if painted.is_empty():
		PlanningChecklistHarness.assert_fail(
			failures,
			"intent_contract/bowling_waypoint_run",
			"no center painted-run destination in walk tile core",
		)
		return
	var run_dest: Vector2i = painted.dest as Vector2i
	var route: Array[Vector2i] = painted.route as Array[Vector2i]
	var drop_slots: Dictionary = painted.slots as Dictionary
	var edge_run: Vector2i = PlanningChecklistHarness.find_run_hover_tile(
		fix.board, fix.knight,
	)
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/bowling_waypoint_run/dest",
		run_dest != edge_run,
		"center destination %s must differ from edge scan tile %s"
		% [run_dest, edge_run],
	)
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/bowling_waypoint_run/paint",
		input._drag_route == route,
		"painted drag route expected %s got %s" % [route, input._drag_route],
	)
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/bowling_waypoint_run/commit",
		PlanningChecklistHarness.commit_slots_production(fix, drop_slots),
		"painted center hover commit must succeed",
	)
	input.call("_promote_intent_preview_after_commit")
	PlanningChecklistHarness.flush_planning(fix)
	var pre_moves: Array = director.plan_pre_move.entries
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/bowling_waypoint_run/timeline",
		not pre_moves.is_empty(),
		"drag-release must commit a pre-move for painted route %s" % str(route),
	)
	if pre_moves.is_empty():
		return
	var run: TimelineAction = pre_moves[0] as TimelineAction
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/bowling_waypoint_run/timeline",
		run != null and run.uses_run and run.target_coord == run_dest,
		"timeline must be Run to %s (got %s)" % [run_dest, run],
	)
	var projected: UnitState = PlanningChecklistHarness.projected_unit(fix, 1)
	PlanningChecklistHarness.assert_eq_cell(
		failures,
		"intent_contract/bowling_waypoint_run/projection",
		projected.position if projected != null else Vector2i(-999999, -999999),
		run_dest,
	)
	PlanningChecklistHarness.assert_eq_int(
		failures,
		"intent_contract/bowling_waypoint_run/projection",
		projected.ability.points_left if projected != null else -1,
		0,
	)
	var bowling_index: int = PlanningChecklistHarness.select_ability(
		fix, PlanningChecklistHarness.BOWLING_CHARGE_ID,
	)
	if bowling_index < 0:
		PlanningChecklistHarness.assert_fail(
			failures, "intent_contract/bowling_waypoint_run", "Bowling Charge missing",
		)
		return
	var bowling: AbilityData = fix.knight.active_abilities[bowling_index]
	_assert_red_stays_hidden_after_refresh(
		failures, fix, input, bowling, run_dest, "destination",
		"intent_contract/bowling_waypoint_run",
	)
	_assert_red_stays_hidden_after_refresh(
		failures, fix, input, bowling, PlanningChecklistHarness.ENEMY_POS, "enemy",
		"intent_contract/bowling_waypoint_run",
	)


## Painted waypoint Run in live preview (not committed): Bowling selected, hover interior
## walk tile in the start diamond — red must stay off (AP consumed by queued Run intent).
static func _test_painted_run_preview_interior_walk_hides_red(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	director.auto_run = true
	input.auto_use_skill_after_move = false
	director.selected_ability_index = -1
	var painted: Dictionary = PlanningChecklistHarness.find_painted_center_run_dest(fix, 1, 1)
	if painted.is_empty():
		painted = PlanningChecklistHarness.find_painted_center_run_dest(fix, 1, 0)
	if painted.is_empty():
		PlanningChecklistHarness.assert_fail(
			failures,
			"intent_contract/painted_run_preview",
			"no painted center Run destination",
		)
		return
	var run_dest: Vector2i = painted.dest as Vector2i
	var route: Array[Vector2i] = painted.route as Array[Vector2i]
	var drop_slots: Dictionary = painted.slots as Dictionary
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/painted_run_preview/slots",
		not PlanningChecklistHarness._slots_invalid(drop_slots),
		"finder must yield valid Run slots at %s" % run_dest,
	)
	TramplingAdvanceE2ETest._paint_drag_route(input, fix.knight, route, run_dest)
	PlanningChecklistHarness.hover(fix, run_dest)
	var bowling_index: int = PlanningChecklistHarness.select_ability(
		fix, PlanningChecklistHarness.BOWLING_CHARGE_ID,
	)
	if bowling_index < 0:
		PlanningChecklistHarness.assert_fail(
			failures, "intent_contract/painted_run_preview", "Bowling Charge missing",
		)
		return
	var bowling: AbilityData = fix.knight.active_abilities[bowling_index]
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/painted_run_preview/drag",
		input.dragging and input._drag_route.size() >= 2,
		"painted Run route must stay active on drag before release",
	)
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/painted_run_preview/binding_move",
		input.call("_binding_move_action_for_action_range", 1) != null,
		"painted drag must expose binding pre-move for action-range economy",
	)
	var drag_tiles: Array[Vector2i] = PlanningChecklistHarness.collect_drag_hover_tiles(fix)
	var walk_diamond: Array[Vector2i] = PlanningChecklistHarness.walk_diamond_from(
		fix.board, PlanningChecklistHarness.KNIGHT_START, fix.knight.movement.max_points,
	)
	var hover_cells: Array[Vector2i] = drag_tiles if drag_tiles.size() >= 3 else walk_diamond
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/painted_run_preview/hover_cells",
		hover_cells.size() >= 3,
		"need hover sweep cells during painted Run drag, count=%d" % hover_cells.size(),
	)
	var interior: Vector2i = PlanningChecklistHarness.blue_tile_near_stand(
		hover_cells, run_dest, false,
	)
	var edge: Vector2i = PlanningChecklistHarness.blue_tile_near_stand(
		hover_cells, run_dest, true,
	)
	PlanningChecklistHarness.assert_red_off_at_hover(
		failures,
		"intent_contract/painted_run_preview/red_off_interior_walk",
		fix,
		bowling,
		interior,
	)
	PlanningChecklistHarness.assert_red_off_at_hover(
		failures,
		"intent_contract/painted_run_preview/red_off_edge_walk",
		fix,
		bowling,
		edge,
	)
	var red_hovers: Array[Vector2i] = PlanningChecklistHarness.collect_red_visible_hovers(
		fix, hover_cells,
	)
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/painted_run_preview/no_red_on_drag_hovers",
		red_hovers.is_empty(),
		"queued Run drag: red must stay off on hover sweep, on=%s" % [red_hovers],
	)


## F5 screenshot parity: committed Run to (3,4) through waypoint (4,4), Bowling selected,
## 0 AP — red must stay off when hovering interior blue tiles (not only map edge).
static func _test_committed_run_center_blue_hover_hides_red(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	director.auto_run = true
	input.auto_use_skill_after_move = false
	director.selected_ability_index = -1
	const SCREENSHOT_DEST := Vector2i(3, 4)
	var painted: Dictionary = PlanningChecklistHarness.try_painted_run_to_dest(
		fix, SCREENSHOT_DEST, 1, 0,
	)
	if painted.is_empty():
		painted = PlanningChecklistHarness.find_painted_center_run_dest(fix, 1, 0)
	if painted.is_empty():
		painted = PlanningChecklistHarness.find_painted_center_run_dest(fix, 1, 1)
	if painted.is_empty():
		PlanningChecklistHarness.assert_fail(
			failures,
			"intent_contract/committed_run_center",
			"no painted center Run destination (mp=0 or mp=1)",
		)
		return
	var run_dest: Vector2i = painted.dest as Vector2i
	var drop_slots: Dictionary = painted.slots as Dictionary
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/committed_run_center/commit",
		PlanningChecklistHarness.commit_slots_production(fix, drop_slots),
		"painted center hover commit must succeed for %s" % run_dest,
	)
	input.call("_promote_intent_preview_after_commit")
	PlanningChecklistHarness.flush_planning(fix)
	var pre_moves: Array = director.plan_pre_move.entries
	if pre_moves.is_empty() or not (pre_moves[0] is TimelineAction):
		PlanningChecklistHarness.assert_fail(
			failures,
			"intent_contract/committed_run_center/timeline",
			"timeline must contain Run pre-move",
		)
		return
	var run: TimelineAction = pre_moves[0] as TimelineAction
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/committed_run_center/timeline",
		run.uses_run and run.target_coord == run_dest,
		"timeline must be Run to %s (got %s)" % [run_dest, run],
	)
	var projected: UnitState = PlanningChecklistHarness.projected_unit(fix, 1)
	PlanningChecklistHarness.assert_eq_int(
		failures,
		"intent_contract/committed_run_center/ap",
		projected.ability.points_left if projected != null else -1,
		0,
	)
	var bowling_index: int = PlanningChecklistHarness.select_ability(
		fix, PlanningChecklistHarness.BOWLING_CHARGE_ID,
	)
	if bowling_index < 0:
		PlanningChecklistHarness.assert_fail(
			failures, "intent_contract/committed_run_center", "Bowling Charge missing",
		)
		return
	var bowling: AbilityData = fix.knight.active_abilities[bowling_index]
	PlanningChecklistHarness.assert_red_off_at_hover(
		failures, "intent_contract/committed_run_center/red_off_dest", fix, bowling, run_dest,
	)
	var walk_mp: int = fix.knight.movement.max_points
	var walk_diamond: Array[Vector2i] = PlanningChecklistHarness.walk_diamond_from(
		fix.board, PlanningChecklistHarness.KNIGHT_START, walk_mp,
	)
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/committed_run_center/walk_diamond",
		walk_diamond.size() >= 3,
		"need walk diamond tiles from start, count=%d" % walk_diamond.size(),
	)
	var center_hover: Vector2i = PlanningChecklistHarness.blue_tile_near_stand(
		walk_diamond, run_dest, false,
	)
	var edge_hover: Vector2i = PlanningChecklistHarness.blue_tile_near_stand(
		walk_diamond, run_dest, true,
	)
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/committed_run_center/walk_diamond",
		center_hover.x > -900000 and edge_hover.x > -900000 and center_hover != edge_hover,
		"need distinct interior and edge walk hovers (center=%s edge=%s)"
		% [center_hover, edge_hover],
	)
	PlanningChecklistHarness.assert_red_off_at_hover(
		failures,
		"intent_contract/committed_run_center/red_off_interior_walk",
		fix,
		bowling,
		center_hover,
	)
	PlanningChecklistHarness.assert_red_off_at_hover(
		failures,
		"intent_contract/committed_run_center/red_off_edge_walk",
		fix,
		bowling,
		edge_hover,
	)
	var red_hovers: Array[Vector2i] = PlanningChecklistHarness.collect_red_visible_hovers(
		fix, walk_diamond,
	)
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/committed_run_center/no_red_on_walk_diamond",
		red_hovers.is_empty(),
		"0 AP after Run commit: red must stay off on all walk-diamond hovers, on=%s" % [red_hovers],
	)


## Regression: pre-run on timeline but get_planning_move_timing() == -1 (action spent, no canto).
## Old code only checked the open timing slot → hover walk sim showed red at 0 AP after Run.
static func _test_pre_run_binding_when_move_timing_closed(failures: Array[String]) -> void:
	const RUN_DEST := Vector2i(3, 4)
	const INTERIOR_HOVER := Vector2i(4, 4)
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	director.auto_run = true
	input.auto_use_skill_after_move = false
	PlanningChecklistHarness.set_knight_pools(fix, 1, 0)
	director.plan_pre_move.entries.append(
		TimelineAction.make_run_move(
			1, RUN_DEST, -1, [INTERIOR_HOVER], GameEnums.MoveTiming.PRE_ACTION,
		),
	)
	var projected: UnitState = PlanningChecklistHarness.projected_unit(fix, 1)
	if projected != null:
		projected.turn_action_used = true
	var move_timing: int = director.get_planning_move_timing(1)
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/pre_run_binding_closed_timing/setup",
		move_timing < 0,
		"fixture must close move-timing slot (got %d)" % move_timing,
	)
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/pre_run_binding_closed_timing/setup",
		director.unit_has_move_planned_at_timing(1, GameEnums.MoveTiming.PRE_ACTION),
		"pre-run must remain on timeline",
	)
	var binding: TimelineAction = input.call(
		"_binding_move_action_for_action_range", 1,
	) as TimelineAction
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/pre_run_binding_closed_timing/setup",
		binding != null and binding.uses_run and binding.target_coord == RUN_DEST,
		"binding must still find pre-run on timeline (got %s)" % binding,
	)
	var bowling_index: int = PlanningChecklistHarness.select_ability(
		fix, PlanningChecklistHarness.BOWLING_CHARGE_ID,
	)
	if bowling_index < 0:
		PlanningChecklistHarness.assert_fail(
			failures, "intent_contract/pre_run_binding_closed_timing", "Bowling Charge missing",
		)
		return
	var bowling: AbilityData = fix.knight.active_abilities[bowling_index]
	PlanningChecklistHarness.assert_red_off_at_hover(
		failures,
		"intent_contract/pre_run_binding_closed_timing/red_off_interior",
		fix,
		bowling,
		INTERIOR_HOVER,
	)
	PlanningChecklistHarness.assert_red_contract(
		failures,
		"intent_contract/pre_run_binding_closed_timing/overlay_parity",
		fix,
		bowling,
		false,
	)


## Resource gate: projected actor at 0 AP must never show red for a 1-AP class skill.
static func _test_red_hidden_when_projected_ap_zero(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	director.auto_run = true
	input.auto_use_skill_after_move = false
	PlanningChecklistHarness.set_knight_pools(fix, 0, 0)
	var projected: UnitState = PlanningChecklistHarness.projected_unit(fix, 1)
	PlanningChecklistHarness.assert_eq_int(
		failures,
		"intent_contract/projected_ap_zero/precondition",
		projected.ability.points_left if projected != null else -1,
		0,
	)
	var bowling_index: int = PlanningChecklistHarness.select_ability(
		fix, PlanningChecklistHarness.BOWLING_CHARGE_ID,
	)
	if bowling_index < 0:
		PlanningChecklistHarness.assert_fail(
			failures, "intent_contract/projected_ap_zero", "Bowling Charge missing",
		)
		return
	var bowling: AbilityData = fix.knight.active_abilities[bowling_index]
	var walk_diamond: Array[Vector2i] = PlanningChecklistHarness.walk_diamond_from(
		fix.board, PlanningChecklistHarness.KNIGHT_START, fix.knight.movement.max_points,
	)
	var red_hovers: Array[Vector2i] = PlanningChecklistHarness.collect_red_visible_hovers(
		fix, walk_diamond,
	)
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/projected_ap_zero/no_red_anywhere",
		red_hovers.is_empty(),
		"0 AP projected actor: red must stay off on all hovers, on=%s" % [red_hovers],
	)
	PlanningChecklistHarness.assert_red_contract(
		failures,
		"intent_contract/projected_ap_zero/gate",
		fix,
		bowling,
		false,
	)


## F5 screenshot parity: committed center Run, Bowling, display AP 0 → no red (gate + overlay).
static func _test_f5_display_ap_zero_implies_no_red(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	var input: CombatPlanningInput = fix.input
	fix.director.auto_run = true
	input.auto_use_skill_after_move = false
	fix.director.selected_ability_index = -1
	var painted: Dictionary = PlanningChecklistHarness.find_painted_center_run_dest(fix, 1, 0)
	if painted.is_empty():
		painted = PlanningChecklistHarness.find_painted_center_run_dest(fix, 1, 1)
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/f5_display_ap/setup",
		not painted.is_empty(),
		"need painted center Run destination for F5 parity",
	)
	if painted.is_empty():
		return
	var run_dest: Vector2i = painted.dest as Vector2i
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/f5_display_ap/commit",
		PlanningChecklistHarness.commit_slots_production(
			fix, painted.slots as Dictionary,
		),
		"F5 route commit must succeed for %s" % run_dest,
	)
	var bowling_index: int = PlanningChecklistHarness.select_ability(
		fix, PlanningChecklistHarness.BOWLING_CHARGE_ID,
	)
	if bowling_index < 0:
		PlanningChecklistHarness.assert_fail(
			failures, "intent_contract/f5_display_ap", "Bowling Charge missing",
		)
		return
	var bowling: AbilityData = fix.knight.active_abilities[bowling_index]
	PlanningChecklistHarness.assert_no_red_when_display_ap_zero(
		failures, "intent_contract/f5_display_ap/at_dest", fix, 1,
	)
	var walk_diamond: Array[Vector2i] = PlanningChecklistHarness.walk_diamond_from(
		fix.board, PlanningChecklistHarness.KNIGHT_START, fix.knight.movement.max_points,
	)
	var interior: Vector2i = PlanningChecklistHarness.blue_tile_near_stand(
		walk_diamond, run_dest, false,
	)
	var overlay_red: Array[Vector2i] = PlanningChecklistHarness.collect_overlay_red_hovers(
		fix, walk_diamond,
	)
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/f5_display_ap/walk_diamond_overlay",
		overlay_red.is_empty(),
		"display AP 0: overlay red on walk diamond hovers=%s" % overlay_red,
	)
	if interior.x > -900000:
		PlanningChecklistHarness.assert_red_off_at_hover(
			failures,
			"intent_contract/f5_display_ap/interior",
			fix,
			bowling,
			interior,
		)


## F5 bug shape: projected knight already at run dest with stale 1 AP while UI shows 0 AP.
static func _test_f5_stale_projection_at_run_dest_display_ap_zero(
	failures: Array[String],
) -> void:
	const RUN_DEST := Vector2i(3, 4)
	const INTERIOR_HOVER := Vector2i(4, 4)
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	director.auto_run = true
	input.auto_use_skill_after_move = false
	PlanningChecklistHarness.set_knight_pools(fix, 1, 0)
	director.plan_pre_move.entries.append(
		TimelineAction.make_run_move(
			1, RUN_DEST, -1, [INTERIOR_HOVER], GameEnums.MoveTiming.PRE_ACTION,
		),
	)
	var projected: UnitState = PlanningChecklistHarness.projected_unit(fix, 1)
	if projected == null:
		PlanningChecklistHarness.assert_fail(
			failures, "intent_contract/f5_stale_projection", "projected knight missing",
		)
		return
	projected.position = RUN_DEST
	projected.ability.points_left = 1
	projected.movement.points_left = 0
	var bowling_index: int = PlanningChecklistHarness.select_ability(
		fix, PlanningChecklistHarness.BOWLING_CHARGE_ID,
	)
	if bowling_index < 0:
		PlanningChecklistHarness.assert_fail(
			failures, "intent_contract/f5_stale_projection", "Bowling Charge missing",
		)
		return
	var bowling: AbilityData = fix.knight.active_abilities[bowling_index]
	PlanningChecklistHarness.assert_eq_int(
		failures,
		"intent_contract/f5_stale_projection/display_ap",
		input.planning_display_ap_left(1),
		0,
	)
	PlanningChecklistHarness.assert_no_red_when_display_ap_zero(
		failures, "intent_contract/f5_stale_projection", fix, 1,
	)
	PlanningChecklistHarness.assert_red_off_at_hover(
		failures,
		"intent_contract/f5_stale_projection/interior",
		fix,
		bowling,
		INTERIOR_HOVER,
	)


static func _assert_red_stays_hidden_after_refresh(
	failures: Array[String],
	fix: Dictionary,
	input: CombatPlanningInput,
	ability: AbilityData,
	cell: Vector2i,
	refresh_name: String,
	label_prefix: String = "intent_contract/bowling_run",
) -> void:
	PlanningChecklistHarness.hover(fix, cell)
	input.call("_run_ability_settled_refresh")
	PlanningChecklistHarness.flush_planning(fix)
	PlanningChecklistHarness.assert_red_contract(
		failures,
		"%s/red_off_%s" % [label_prefix, refresh_name],
		fix,
		ability,
		false,
	)


static func _test_simulation_validator_rejects_invalid_timeline_action(
	failures: Array[String],
) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	var director: CombatDirector = fix.director
	var action: TimelineAction = TimelineAction.make_move(
		1,
		Vector2i(-1, -1),
		-1,
		[],
		GameEnums.MoveTiming.PRE_ACTION,
	)
	var rejection: String = director.preview_commit_valid(1, [action])
	PlanningChecklistHarness.assert_true(
		failures,
		"intent_contract/sim_reject",
		not rejection.is_empty(),
		"preview_commit_valid must reject an out-of-bounds timeline action",
	)
