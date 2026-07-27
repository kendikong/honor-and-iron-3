class_name PlanningPathRegressionTest
extends RefCounted

## Fixed tactical-path scenarios. These use production movement, preview, and simulation
## APIs so a future regression fails before a player has to discover it in TestBattle.

static func run_all(failures: Array[String]) -> void:
	_test_painted_skill_path_is_preview_and_execution_truth(failures)


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


static func _test_painted_skill_path_is_preview_and_execution_truth(
	failures: Array[String],
) -> void:
	var board := _plain_board(Vector2i(12, 12))
	var actor := UnitState.new()
	actor.id = 1
	actor.team = GameEnums.Team.PLAYER
	actor.position = Vector2i(6, 3)
	actor.movement.points_left = 4
	actor.movement.points_max = 4
	actor.ability.points_left = 1
	actor.ability.points_max = 1
	board.units = [actor]
	GridSystem.set_occupant(board, actor.position, actor.id)

	var trample := AbilityData.new()
	trample.id = &"test_trample"
	trample.kind = GameEnums.AbilityKind.MOVEMENT_SKILL
	trample.movement_point_cost = 2
	trample.range_tiles = 2
	trample.targeting_mode = GameEnums.TargetingMode.TILE
	trample.targeting_flags = AbilityData._targeting_mode_to_flags(trample.targeting_mode)
	var move_effect := EffectData.new()
	move_effect.type = GameEnums.EffectType.MOVE
	move_effect.amount = 2
	trample.effects = [move_effect]

	var waypoints: Array[Vector2i] = [Vector2i(7, 3), Vector2i(7, 2)]
	var action := TimelineAction.make_ability(
		actor.id, trample, Vector2i(7, 2), -1, GameEnums.MoveTiming.PRE_ACTION, waypoints,
	)
	var preview := CombatPlanningPreview.new()
	preview.preview_paths[actor.id] = [Vector2i(6, 3), Vector2i(6, 2), Vector2i(7, 2)]
	preview.ensure_movement_intent_from_actions([action], board)
	var preview_path: Array = preview.preview_paths.get(actor.id, [])
	if preview_path != [Vector2i(6, 3), Vector2i(7, 3), Vector2i(7, 2)]:
		failures.append(
			"PlanningPathRegression: preview must replace N-then-E with committed E-then-N waypoints",
		)

	var resolved: Array[Vector2i] = MovementSystem.resolve_move_path(
		board, actor, action.target_coord, action.waypoints, trample.range_tiles, trample,
	)
	if resolved != waypoints:
		failures.append(
			"PlanningPathRegression: MovementSystem must preserve committed waypoint order",
		)
