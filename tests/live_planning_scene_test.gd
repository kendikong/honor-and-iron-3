## Tier 3 acceptance tests: real TestBattle scene, real input events, real frames.
##
## This suite intentionally does not use PlanningDragE2EHarness, QA pointer
## overrides, or direct private refresh calls. A pass here is the only
## automated evidence that a planning-overlay workflow reached the F5 scene path.
extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const _RUN_ID: StringName = &"universal_run"
const _BOWLING_CHARGE_ID: StringName = &"knight_bowling_charge"
const _START_CELL := Vector2i(4, 5)
const _RUN_DESTINATION := Vector2i(0, 5)
const _INTERIOR_HOVER := Vector2i(2, 4)


func test_test_battle_scene_boots(timeout := 15000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	await runner.simulate_frames(8)
	var scene: TestBattleMapView = runner.scene() as TestBattleMapView
	assert_object(scene).is_not_null()


func test_run_spends_ap_before_bowling_hover_has_no_live_red_range(timeout := 15000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	await runner.simulate_frames(8)
	var scene: TestBattleMapView = runner.scene() as TestBattleMapView
	var shell: TacticalCombatShell = scene.get_node("CombatShell") as TacticalCombatShell
	var director: CombatDirector = scene.get_node("CombatDirector") as CombatDirector
	var overlay: TacticalPlanningOverlay = scene.get_node(
		"WorldModulate/MapRoot/PlanningOverlay",
	) as TacticalPlanningOverlay
	# Pin the real arena session after its user preferences have loaded.
	scene.get_session().reset_defaults()
	scene.apply_training_board()
	await runner.simulate_frames(4)
	var player: UnitState = director.board.get_unit_by_id(1)
	assert_object(player).is_not_null()
	await _select_ability_by_id(runner, director, player, _RUN_ID)
	await _drag_between_cells(runner, scene, _START_CELL, _RUN_DESTINATION)
	await runner.simulate_frames(6, 20)
	assert_that(director.plan_pre_move.entries.size()).is_greater(0)
	assert_bool(_plan_uses_run(director)).is_true()
	player = director.projected_state.get_unit_by_id(1)
	await _select_ability_by_id(runner, director, player, _BOWLING_CHARGE_ID)
	await _move_pointer_to_cell(runner, scene, _INTERIOR_HOVER)
	await runner.simulate_frames(6, 20)
	assert_int(shell.planning_input.planning_display_ap_left(1)).is_equal(0)
	assert_bool(shell.planning_input.action_range_visible_for_hover()).is_false()
	assert_bool(_overlay_has_red_tile(overlay, director.board)).is_false()


func test_live_drag_preview_commits_then_right_click_undoes(timeout := 15000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	await runner.simulate_frames(8)
	var scene: TestBattleMapView = runner.scene() as TestBattleMapView
	var shell: TacticalCombatShell = scene.get_node("CombatShell") as TacticalCombatShell
	var director: CombatDirector = scene.get_node("CombatDirector") as CombatDirector
	scene.get_session().reset_defaults()
	scene.apply_training_board()
	await runner.simulate_frames(4)
	var player: UnitState = director.board.get_unit_by_id(1)
	await _select_ability_by_id(runner, director, player, _RUN_ID)
	await _move_pointer_to_cell(runner, scene, _START_CELL)
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(2)
	await _move_pointer_to_cell(runner, scene, _RUN_DESTINATION)
	await runner.simulate_frames(3)
	var preview_actor: UnitState = shell.planning_input.preview_state.preview_board.get_unit_by_id(1)
	assert_that(preview_actor.position).is_equal(_RUN_DESTINATION)
	runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(6, 20)
	var committed_actor: UnitState = director.projected_state.get_unit_by_id(1)
	assert_that(committed_actor.position).is_equal(_RUN_DESTINATION)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	await runner.simulate_frames(4)
	assert_int(director.plan_pre_move.entries.size()).is_equal(0)


func test_scroll_wheel_changes_live_ability_selection(timeout := 15000) -> void:
	var runner := scene_runner("res://scenes/TestBattle.tscn")
	await runner.simulate_frames(8)
	var scene: TestBattleMapView = runner.scene() as TestBattleMapView
	var director: CombatDirector = scene.get_node("CombatDirector") as CombatDirector
	scene.get_session().reset_defaults()
	scene.apply_training_board()
	await runner.simulate_frames(4)
	var player: UnitState = director.board.get_unit_by_id(1)
	await _select_ability_by_id(runner, director, player, _RUN_ID)
	var before: int = director.selected_ability_index
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN)
	await runner.simulate_frames(6, 20)
	assert_int(director.selected_ability_index).is_not_equal(before)


func _select_ability_by_id(
	runner: GdUnitSceneRunner,
	director: CombatDirector,
	unit: UnitState,
	ability_id: StringName,
) -> void:
	for index: int in range(unit.active_abilities.size()):
		var ability: AbilityData = unit.active_abilities[index]
		if ability != null and ability.id == ability_id:
			director.select_ability(index)
			await runner.simulate_frames(6, 20)
			return
	assert_that("Required training ability missing: %s" % ability_id).is_equal("")


func _drag_between_cells(
	runner: GdUnitSceneRunner,
	scene: TestBattleMapView,
	from: Vector2i,
	to: Vector2i,
) -> void:
	await _move_pointer_to_cell(runner, scene, from)
	var input: CombatPlanningInput = (
		scene.get_node("CombatShell") as TacticalCombatShell
	).planning_input
	assert_that(input.get_hover_tile_for_ui()).is_equal(from)
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(2)
	await _move_pointer_to_cell(runner, scene, to)
	assert_that(input.get_hover_tile_for_ui()).is_equal(to)
	await runner.simulate_frames(2)
	runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)


func _move_pointer_to_cell(
	runner: GdUnitSceneRunner,
	scene: TestBattleMapView,
	cell: Vector2i,
) -> void:
	var map_root: Node2D = scene.get_node("WorldModulate/MapRoot") as Node2D
	var screen_pos: Vector2 = scene.position + scene.grid_to_local(cell) * map_root.scale.x
	runner.simulate_mouse_move(screen_pos)
	await runner.simulate_frames(2)


func _plan_uses_run(director: CombatDirector) -> bool:
	for action: TimelineAction in director.plan_pre_move.entries:
		if action != null and action.uses_run:
			return true
	return false


func _overlay_has_red_tile(overlay: TacticalPlanningOverlay, board: BoardState) -> bool:
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			if overlay.is_hover_action_range_tile(Vector2i(x, y)):
				return true
	return false
