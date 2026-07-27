class_name StalePreMoveTest
extends RefCounted

## Regression: hide committed PRE leg when live board reached pre target but projection advanced.


static func run_all(failures: Array[String]) -> void:
	_test_live_board_at_pre_target_projection_past(failures)
	_test_bridge_scenario_matches_production_board_split(failures)


static func _make_unit(unit_id: int, pos: Vector2i) -> UnitState:
	var unit := UnitState.new()
	unit.id = unit_id
	unit.team = GameEnums.Team.PLAYER
	unit.position = pos
	unit.health = HealthComponent.new()
	unit.movement = MovementComponent.new()
	unit.ability = AbilityComponent.new()
	return unit


static func _test_live_board_at_pre_target_projection_past(failures: Array[String]) -> void:
	var director := CombatDirector.new()
	var base := BoardState.new()
	base.grid_size = Vector2i(12, 12)
	var turn_start := _make_unit(1, Vector2i(5, 3))
	base.units = [turn_start]
	director.base_board = base

	var live := BoardState.new()
	live.grid_size = base.grid_size
	var live_unit := turn_start.clone()
	live_unit.position = Vector2i(6, 2)
	live.units = [live_unit]
	director.board = live

	var proj := BoardState.new()
	proj.grid_size = base.grid_size
	var proj_unit := turn_start.clone()
	proj_unit.position = Vector2i(7, 1)
	proj.units = [proj_unit]
	director.projected_state = proj

	director.plan_pre_move = Timeline.new()
	director.plan_pre_move.entries.append(
		TimelineAction.make_move(
			1, Vector2i(6, 2), -1, [Vector2i(6, 3), Vector2i(6, 2)],
			GameEnums.MoveTiming.PRE_ACTION,
		),
	)
	director.plan_action = Timeline.new()
	var trample := AbilityData.new()
	trample.kind = GameEnums.AbilityKind.MOVEMENT_SKILL
	director.plan_action.entries.append(
		TimelineAction.make_ability(1, trample, Vector2i(7, 1), -1),
	)
	director.plan_post_move = Timeline.new()

	var preview := CombatPlanningPreview.new()
	preview.preview_paths[1] = [
		Vector2i(5, 3), Vector2i(6, 3), Vector2i(6, 2), Vector2i(7, 1),
	]

	var leg: Array = CombatPlanningPreview.committed_move_route_leg(
		1, preview, director, live, GameEnums.MoveTiming.PRE_ACTION,
	)
	if not leg.is_empty():
		failures.append(
			"PRE leg should hide when live at (6,2) and projection at (7,1); got %s" % str(leg),
		)


static func _test_bridge_scenario_matches_production_board_split(failures: Array[String]) -> void:
	var director_stub := CombatDirector.new()
	var base_stub := BoardState.new()
	base_stub.grid_size = Vector2i(12, 12)
	var plan_unit := _make_unit(1, Vector2i(5, 3))
	base_stub.units = [plan_unit]
	director_stub.base_board = base_stub

	var board_stub := BoardState.new()
	board_stub.grid_size = base_stub.grid_size
	var live_unit := plan_unit.clone()
	live_unit.position = Vector2i(6, 2)
	board_stub.units = [live_unit]
	director_stub.board = board_stub

	var proj_board := BoardState.new()
	proj_board.grid_size = base_stub.grid_size
	var proj_unit := plan_unit.clone()
	proj_unit.position = Vector2i(7, 1)
	proj_board.units = [proj_unit]
	director_stub.projected_state = proj_board

	director_stub.plan_pre_move = Timeline.new()
	director_stub.plan_pre_move.entries.append(
		TimelineAction.make_move(
			1, Vector2i(6, 2), -1, [Vector2i(6, 3), Vector2i(6, 2)],
			GameEnums.MoveTiming.PRE_ACTION,
		),
	)
	director_stub.plan_action = Timeline.new()
	director_stub.plan_action.entries.append(
		TimelineAction.make_ability(1, AbilityData.new(), Vector2i(7, 1), -1),
	)
	director_stub.plan_post_move = Timeline.new()
	var preview := CombatPlanningPreview.new()
	preview.preview_paths[1] = [Vector2i(5, 3), Vector2i(6, 3), Vector2i(6, 2), Vector2i(7, 1)]
	var leg: Array = CombatPlanningPreview.committed_move_route_leg(
		1, preview, director_stub, board_stub, GameEnums.MoveTiming.PRE_ACTION,
	)
	if not leg.is_empty():
		failures.append(
			"bridge-style scenario must hide PRE leg with split base/live boards; got %s" % str(leg),
		)
