class_name PlanningIntentContractE2ETest
extends RefCounted

## Production input contracts that span hover -> click -> committed timeline ->
## projected economy -> refreshed overlay. These are intentionally not helper-only
## assertions: each test uses CombatPlanningInput's actual click entry point.

static func run_all(failures: Array[String]) -> void:
	_test_bowling_run_click_hides_red_across_refreshes(failures)
	_test_bowling_waypoint_run_center_hides_red(failures)
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
