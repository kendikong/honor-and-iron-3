class_name RunEconomyScenarioTest
extends RefCounted

## Run / AP economy checklist - walk keeps AP, run spends AP, skill red hides at 0 AP.


static func run_all(failures: Array[String]) -> void:
	_walk_adjacent_keeps_ap(failures)
	_run_spends_ap_and_hides_red(failures)
	_run_commit_production_path_bash(failures)
	_run_commit_production_path_bowling(failures)


static func _walk_adjacent_keeps_ap(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	fix.director.selected_ability_index = -1
	fix.input.force_basic_movement = true
	fix.input.auto_use_skill_after_move = false
	var dest: Vector2i = Vector2i(5, 5)
	PlanningChecklistHarness.hover(fix, dest)
	var slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, dest)
	PlanningChecklistHarness.assert_cursor_contains(
		failures, "run_economy/walk_cursor", fix, slots, PlanningIcons.GLYPH_WALK,
	)
	PlanningChecklistHarness.commit_production(fix, dest)
	PlanningChecklistHarness.assert_eq_int(
		failures, "run_economy/walk_ap",
		PlanningChecklistHarness.projected_unit(fix, 1).ability.points_left, 1,
	)
	PlanningChecklistHarness.assert_eq_int(
		failures, "run_economy/walk_mp",
		PlanningChecklistHarness.projected_unit(fix, 1).movement.points_left,
		fix.knight.movement.max_points - 1,
	)


static func _run_spends_ap_and_hides_red(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	fix.director.auto_run = true
	PlanningChecklistHarness.set_knight_pools(fix, 1, 0)
	PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.SHIELD_BASH_ID)
	var run_tile: Vector2i = PlanningChecklistHarness.find_run_hover_tile(fix.board, fix.knight)
	if run_tile.x <= -900000:
		PlanningChecklistHarness.assert_fail(failures, "run_economy/run_hover", "no run tile")
		return
	PlanningChecklistHarness.hover(fix, run_tile)
	var ability: AbilityData = fix.knight.active_abilities[
		PlanningChecklistHarness.ability_index(fix.knight, PlanningChecklistHarness.SHIELD_BASH_ID)
	]
	PlanningChecklistHarness.assert_action_range_hidden(failures, "run_economy/visibility_gate", fix)
	PlanningChecklistHarness.assert_red_contract(failures, "run_economy/red_off_hover", fix, ability, false)
	PlanningChecklistHarness.assert_eq_int(
		failures, "run_economy/display_ap_hover",
		fix.input.planning_display_ap_left(1), 0,
	)


static func _run_commit_production_path_bash(failures: Array[String]) -> void:
	ActionRangeRegressionTest.assert_hide_red_after_commit_run_icon_shield_bash(failures)


static func _run_commit_production_path_bowling(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	fix.director.auto_run = true
	PlanningChecklistHarness.set_knight_pools(fix, 1, 0)
	var idx: int = PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.BOWLING_CHARGE_ID)
	if idx < 0:
		PlanningChecklistHarness.assert_fail(failures, "run_economy/bowling", "Bowling Charge missing")
		return
	var run_tile: Vector2i = PlanningChecklistHarness.find_run_hover_tile(fix.board, fix.knight)
	if run_tile.x <= -900000:
		PlanningChecklistHarness.assert_fail(failures, "run_economy/bowling", "no run tile")
		return
	PlanningChecklistHarness.hover(fix, run_tile)
	var ability: AbilityData = fix.knight.active_abilities[idx]
	PlanningChecklistHarness.assert_red_contract(failures, "run_economy/bowling_red_off", fix, ability, false)
	PlanningChecklistHarness.commit_production(fix, run_tile)
	PlanningChecklistHarness.assert_red_contract(
		failures, "run_economy/bowling_red_after_commit", fix, ability, false, run_tile,
	)
