class_name PlanningIntentContractE2ETest
extends RefCounted

## Production input contracts that span hover -> click -> committed timeline ->
## projected economy -> refreshed overlay. These are intentionally not helper-only
## assertions: each test uses CombatPlanningInput's actual click entry point.

static func run_all(failures: Array[String]) -> void:
	_test_bowling_run_click_hides_red_across_refreshes(failures)
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


static func _assert_red_stays_hidden_after_refresh(
	failures: Array[String],
	fix: Dictionary,
	input: CombatPlanningInput,
	ability: AbilityData,
	cell: Vector2i,
	refresh_name: String,
) -> void:
	PlanningChecklistHarness.hover(fix, cell)
	input.call("_run_ability_settled_refresh")
	PlanningChecklistHarness.flush_planning(fix)
	PlanningChecklistHarness.assert_red_contract(
		failures,
		"intent_contract/bowling_run/red_off_%s" % refresh_name,
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
