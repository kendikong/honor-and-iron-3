class_name PlanningT3MimicJourneysTest
extends RefCounted

## Headless mirror of Tier 3 LIVE journey commit checks (fixture board, not TestBattle).
## Tap/selection vs waypoint-drag parity, post-commit red-off, undo smoke.

const _K1_BASH_ROUTE: Array[Vector2i] = [
	PlanningChecklistHarness.KNIGHT_START,
	PlanningChecklistHarness.BASH_HOVER_WALK,
	PlanningChecklistHarness.BASH_APPROACH,
]
const _LiveParity := preload("res://tests/planning_live_parity_harness.gd")
const _K1_BASH_WAYPOINTS: Array[Vector2i] = [
	PlanningChecklistHarness.BASH_HOVER_WALK,
	PlanningChecklistHarness.BASH_APPROACH,
]


static func run_all(failures: Array[String]) -> void:
	_test_undo_drag_premove_clears(failures)
	_test_k1_bash_tap_vs_waypoint_drag_parity(failures)
	_test_k1_bash_painted_route_click_waypoints(failures)
	_test_k1_bash_post_commit_red_off_tap_and_waypoint(failures)
	_test_k2_hook_tap_vs_drag_parity(failures)
	_test_k3_trample_tap_vs_drag_parity(failures)
	_test_k4_run_selection_vs_drag_parity(failures)


static func _setup_k1_bash(fix: Dictionary) -> void:
	fix.director.auto_run = true
	fix.input.auto_use_skill_after_move = true
	PlanningChecklistHarness.set_knight_pools(fix, 1, 3)
	PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.SHIELD_BASH_ID)


static func _test_undo_drag_premove_clears(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	var director: CombatDirector = fix.director
	director.selected_ability_index = -1
	fix.input.force_basic_movement = true
	var dest: Vector2i = PlanningChecklistHarness.BASH_HOVER_WALK
	PlanningDragE2EHarness.paint_and_release(
		fix,
		[PlanningChecklistHarness.KNIGHT_START, dest],
		dest,
	)
	if director.plan_pre_move.entries.is_empty():
		PlanningChecklistHarness.assert_fail(
			failures, "t3_mimic/undo_smoke", "drag commit must write pre-move",
		)
		return
	if not director.unit_has_undoable_action(1):
		PlanningChecklistHarness.assert_fail(
			failures, "t3_mimic/undo_smoke", "unit must be undoable after drag walk",
		)
		return
	PlanningDragE2EHarness.undo_selected(fix)
	if director.unit_has_undoable_action(1):
		PlanningChecklistHarness.assert_fail(
			failures, "t3_mimic/undo_smoke", "undo must remove undoable action",
		)
	if director.plan_pre_move.entries.size() > 0:
		PlanningChecklistHarness.assert_fail(
			failures, "t3_mimic/undo_smoke", "undo must clear committed pre-move",
		)


static func _test_k1_bash_tap_vs_waypoint_drag_parity(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	var k1_id: int = 1
	var e_bash_id: int = 2
	var bash_idx: int = PlanningChecklistHarness.select_ability(
		fix, PlanningChecklistHarness.SHIELD_BASH_ID,
	)
	var bash: AbilityData = null
	if bash_idx >= 0:
		bash = fix.knight.active_abilities[bash_idx]
	_LiveParity.run_k1_bash_live_parity(
		fix, failures, k1_id, e_bash_id, bash, "t3_mimic/k1_bash",
	)


static func _test_k1_bash_painted_route_click_waypoints(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	_setup_k1_bash(fix)
	if not PlanningChecklistHarness.commit_painted_click_on_cell(
		fix, _K1_BASH_ROUTE, PlanningChecklistHarness.ENEMY_POS,
	):
		PlanningChecklistHarness.assert_fail(
			failures, "t3_mimic/k1_bash/click_waypoint", "painted enemy click commit failed",
		)
		return
	var pre: TimelineAction = PlanningChecklistHarness.committed_pre_move(fix.director, 1)
	if pre == null or pre.waypoints != _K1_BASH_WAYPOINTS:
		PlanningChecklistHarness.assert_fail(
			failures,
			"t3_mimic/k1_bash/click_waypoint",
			"click commit pre-move expected %s got %s"
			% [_K1_BASH_WAYPOINTS, pre.waypoints if pre != null else null],
		)


static func _test_k1_bash_post_commit_red_off_tap_and_waypoint(failures: Array[String]) -> void:
	var bash: AbilityData = null
	var tap_fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	_setup_k1_bash(tap_fix)
	PlanningChecklistHarness.commit_production(tap_fix, PlanningChecklistHarness.ENEMY_POS)
	var bash_idx: int = PlanningChecklistHarness.ability_index(
		tap_fix.knight, PlanningChecklistHarness.SHIELD_BASH_ID,
	)
	bash = tap_fix.knight.active_abilities[bash_idx] if bash_idx >= 0 else null
	PlanningChecklistHarness.assert_red_contract(
		failures,
		"t3_mimic/k1_bash/tap/post_commit",
		tap_fix,
		bash,
		false,
		PlanningChecklistHarness.BASH_APPROACH,
	)

	var drag_fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	_setup_k1_bash(drag_fix)
	PlanningChecklistHarness.commit_painted_drop_on_cell(
		drag_fix, _K1_BASH_ROUTE, PlanningChecklistHarness.ENEMY_POS,
	)
	PlanningChecklistHarness.assert_red_contract(
		failures,
		"t3_mimic/k1_bash/waypoint/post_commit",
		drag_fix,
		bash,
		false,
		PlanningChecklistHarness.BASH_APPROACH,
	)


static func _test_k2_hook_tap_vs_drag_parity(failures: Array[String]) -> void:
	var tap_fix: Dictionary = PlanningChecklistHarness.wire_hook_board()
	PlanningChecklistHarness.select_ability(tap_fix, PlanningChecklistHarness.CHAIN_HOOK_ID)
	PlanningChecklistHarness.commit_production(tap_fix, PlanningChecklistHarness.HOOK_ENEMY_POS)
	var tap_surface: Dictionary = PlanningChecklistHarness.mode_commit_surface(tap_fix, 1)

	var drag_fix: Dictionary = PlanningChecklistHarness.wire_hook_board()
	PlanningChecklistHarness.select_ability(drag_fix, PlanningChecklistHarness.CHAIN_HOOK_ID)
	var route: Array[Vector2i] = [
		PlanningChecklistHarness.HOOK_KNIGHT_START,
	]
	if not PlanningChecklistHarness.commit_painted_drop_on_cell(
		drag_fix, route, PlanningChecklistHarness.HOOK_ENEMY_POS,
	):
		PlanningChecklistHarness.assert_fail(
			failures, "t3_mimic/k2_hook/drag", "hook drag commit failed",
		)
		return
	var drag_surface: Dictionary = PlanningChecklistHarness.mode_commit_surface(drag_fix, 1)
	PlanningChecklistHarness.assert_mode_commit_parity(
		failures, "k2/selection", tap_surface, "k2/drag", drag_surface,
	)


static func _test_k3_trample_tap_vs_drag_parity(failures: Array[String]) -> void:
	var tap_fix: Dictionary = PlanningChecklistHarness.wire_trample_board()
	var tap_unit: UnitState = tap_fix.knight
	if not TramplingAdvanceE2ETest._arm_trample_awaiting(
		tap_fix.input, tap_fix.director, tap_unit,
	):
		PlanningChecklistHarness.assert_fail(
			failures, "t3_mimic/k3_trample/tap", "arm awaiting failed",
		)
		return
	PlanningChecklistHarness.commit_production(tap_fix, PlanningChecklistHarness.TRAMPLE_END)
	var tap_surface: Dictionary = PlanningChecklistHarness.mode_commit_surface(tap_fix, 1)

	var drag_fix: Dictionary = PlanningChecklistHarness.wire_trample_board()
	var drag_unit: UnitState = drag_fix.knight
	if not TramplingAdvanceE2ETest._arm_trample_awaiting(
		drag_fix.input, drag_fix.director, drag_unit,
	):
		PlanningChecklistHarness.assert_fail(
			failures, "t3_mimic/k3_trample/drag", "arm awaiting failed",
		)
		return
	var route: Array[Vector2i] = [
		PlanningChecklistHarness.TRAMPLE_START,
		PlanningChecklistHarness.TRAMPLE_ROUTE[0],
		PlanningChecklistHarness.TRAMPLE_ROUTE[1],
	]
	if not PlanningChecklistHarness.commit_painted_drop_on_cell(
		drag_fix, route, PlanningChecklistHarness.TRAMPLE_END,
	):
		PlanningChecklistHarness.assert_fail(
			failures, "t3_mimic/k3_trample/drag", "trample drag commit failed",
		)
		return
	var drag_surface: Dictionary = PlanningChecklistHarness.mode_commit_surface(drag_fix, 1)
	PlanningChecklistHarness.assert_mode_commit_parity(
		failures, "k3/selection", tap_surface, "k3/drag", drag_surface,
	)


static func _test_k4_run_selection_vs_drag_parity(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_k4_board()
	var k4_id: int = fix.director.selected_unit_id
	var bowling_idx: int = PlanningChecklistHarness.select_ability(
		fix, PlanningChecklistHarness.BOWLING_CHARGE_ID,
	)
	var bowling: AbilityData = null
	if bowling_idx >= 0:
		bowling = fix.knight.active_abilities[bowling_idx]
	_LiveParity.run_k4_run_live_parity(
		fix, failures, k4_id, bowling, "t3_mimic/k4_run",
	)
