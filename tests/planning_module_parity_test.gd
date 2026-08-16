class_name PlanningModuleParityTest
extends RefCounted

## AD-3 planning contracts: authored module metadata is the same input used by
## preview and by the slots action that commit ratifies.

static func run_all(failures: Array[String]) -> void:
	_test_module_authored_motion_range(failures)
	_test_gated_follow_up_preview_commit_parity(failures)
	_test_module_only_empty_compatibility_effects(failures)
	_test_committed_prefix_simulates_while_later_aim_awaits(failures)


static func _test_module_authored_motion_range(failures: Array[String]) -> void:
	var board: BoardState = _plain_board(Vector2i(8, 4))
	var actor: UnitState = _unit(1, GameEnums.Team.PLAYER, Vector2i(1, 1))
	board.units = [actor]
	_place(board, actor)
	var ability: AbilityData = _ability(&"planning_module_move", GameEnums.TargetingFlags.TILE)
	var motion: AbilityModule = AbilityModule.new()
	motion.primary_type = GameEnums.EffectType.MOVE
	motion.min_range = 2
	motion.max_range = 3
	motion.targeting_flags = GameEnums.TargetingFlags.TILE
	ability.modules = [motion]
	ability.effects = []
	var tiles: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		board, actor, ability, actor.position,
	)
	if AbilitySystem.active_range_tiles(actor, ability) != 3:
		failures.append("planning did not use the authored module motion range")
	if not tiles.has(Vector2i(4, 1)) or tiles.has(Vector2i(2, 1)):
		failures.append("planning motion range tiles ignored module min/max range")


static func _test_gated_follow_up_preview_commit_parity(failures: Array[String]) -> void:
	var board: BoardState = _plain_board(Vector2i(7, 5))
	var actor: UnitState = _unit(1, GameEnums.Team.PLAYER, Vector2i(2, 1))
	var blocker: UnitState = _unit(2, GameEnums.Team.ENEMY, Vector2i(2, 2))
	board.units = [actor, blocker]
	_place(board, actor)
	_place(board, blocker)
	var wall: TerrainData = TerrainData.new()
	wall.id = &"wall"
	wall.blocks_movement = true
	wall.stops_displacement = true
	board.tiles[Vector2i(2, 3)] = TileState.create(Vector2i(2, 3), wall)
	var ability: AbilityData = _ability(&"planning_gated_follow_up", GameEnums.TargetingFlags.ENEMY)
	var dash: AbilityModule = AbilityModule.new()
	dash.primary_type = GameEnums.EffectType.PUSH
	dash.amount = 1
	dash.min_range = 1
	dash.max_range = 1
	dash.targeting_flags = GameEnums.TargetingFlags.ENEMY
	var follow_up: AbilityModule = AbilityModule.new()
	follow_up.primary_type = GameEnums.EffectType.MOVE
	follow_up.min_range = 1
	follow_up.max_range = 5
	follow_up.targeting_flags = GameEnums.TargetingFlags.TILE
	follow_up.gate = GameEnums.ModuleGate.IF_COLLIDED
	follow_up.aim_binding = GameEnums.AimBinding.NEW_AIM
	ability.modules = [dash, follow_up]
	ability.effects = []
	var action: TimelineAction = TimelineAction.make_ability(
		actor.id, ability, Vector2i(2, 2), blocker.id,
	)
	AbilitySystem.prepare_planning_action(board, action)
	if not action.awaiting_target or action.awaiting_module_index != 1:
		failures.append("collision gate did not expose the authored follow-up aim")
	var preview: TimelineAction = AbilitySystem.planning_preview_action(action)
	if preview == null or preview.awaiting_target or preview.ability.modules.size() != 1:
		failures.append("follow-up preview did not simulate the resolved module prefix")
	if not AbilitySystem.planning_module_target_valid(
		board, action, 1, Vector2i(3, 3),
	):
		failures.append("follow-up endpoint rejected a valid module-authored target")
	AbilitySystem.set_module_target(action, 1, Vector2i(3, 3), -1)
	action.awaiting_target = false
	action.awaiting_module_index = -1
	AbilitySystem.prepare_planning_action(board, action)
	if action.awaiting_target or AbilitySystem.module_target_coord(action, 1) != Vector2i(3, 3):
		failures.append("commit action did not ratify the painted follow-up target")

	var clear_board: BoardState = _plain_board(Vector2i(7, 5))
	var clear_actor: UnitState = _unit(1, GameEnums.Team.PLAYER, Vector2i(2, 1))
	clear_board.units = [clear_actor]
	_place(clear_board, clear_actor)
	var hidden: TimelineAction = TimelineAction.make_ability(
		clear_actor.id, ability, Vector2i(2, 2),
	)
	AbilitySystem.prepare_planning_action(clear_board, hidden)
	if hidden.awaiting_target:
		failures.append("failed collision gate incorrectly exposed a follow-up aim")


static func _test_module_only_empty_compatibility_effects(failures: Array[String]) -> void:
	var board: BoardState = _plain_board(Vector2i(6, 4))
	var actor: UnitState = _unit(1, GameEnums.Team.PLAYER, Vector2i(1, 1))
	var target: UnitState = _unit(2, GameEnums.Team.ENEMY, Vector2i(3, 1))
	board.units = [actor, target]
	_place(board, actor)
	_place(board, target)
	var ability: AbilityData = _ability(&"planning_module_only", GameEnums.TargetingFlags.ENEMY)
	var damage: AbilityModule = AbilityModule.new()
	damage.primary_type = GameEnums.EffectType.DAMAGE
	damage.amount = 4
	damage.min_range = 1
	damage.max_range = 3
	damage.targeting_flags = GameEnums.TargetingFlags.ENEMY
	ability.modules = [damage]
	ability.effects = []
	ability.upgraded_effects = []
	var action: TimelineAction = TimelineAction.make_ability(
		actor.id, ability, target.position, target.id,
	)
	AbilitySystem.prepare_planning_action(board, action)
	if AbilitySystem.active_modules_for(actor, ability).is_empty() or action.awaiting_target:
		failures.append("module-only planning ignored authored modules with empty flat compatibility data")


static func _test_committed_prefix_simulates_while_later_aim_awaits(failures: Array[String]) -> void:
	var board: BoardState = _plain_board(Vector2i(8, 4))
	var actor: UnitState = _unit(1, GameEnums.Team.PLAYER, Vector2i(2, 1))
	actor.movement.points_left = 4
	actor.ability.points_left = 3
	board.units = [actor]
	_place(board, actor)
	var ability: AbilityData = _ability(
		&"planning_move_then_strike",
		GameEnums.TargetingFlags.TILE | GameEnums.TargetingFlags.ENEMY,
	)
	ability.display_name = "Charge Strike"
	var motion: AbilityModule = AbilityModule.new()
	motion.primary_type = GameEnums.EffectType.MOVE
	motion.amount = 2
	motion.min_range = 1
	motion.max_range = 2
	motion.targeting_flags = GameEnums.TargetingFlags.TILE
	motion.motion_mode = GameEnums.MotionMode.TO_EMPTY_TILE
	var strike: AbilityModule = AbilityModule.new()
	strike.primary_type = GameEnums.EffectType.DAMAGE
	strike.amount = 3
	strike.min_range = 1
	strike.max_range = 1
	strike.targeting_flags = GameEnums.TargetingFlags.ENEMY
	ability.modules = [motion, strike]
	ability.effects = []
	var action: TimelineAction = TimelineAction.make_ability(actor.id, ability, Vector2i(4, 1))
	AbilitySystem.set_module_target(action, 0, Vector2i(4, 1), -1)
	action.awaiting_target = true
	action.awaiting_module_index = 1
	if AbilitySystem.planning_committed_prefix(action) == null:
		failures.append("planning prefix missing for awaiting later NEW_AIM")
	var trial: BoardState = board.clone()
	var plan := Timeline.new()
	plan.add(action)
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(trial, plan, events)
	var after: UnitState = trial.get_unit_by_id(actor.id)
	if after == null or after.position != Vector2i(4, 1):
		failures.append("simulator skipped committed MOVE prefix while a later NEW_AIM is awaiting")


static func _ability(id: StringName, targeting_flags: int) -> AbilityData:
	var ability: AbilityData = AbilityData.new()
	ability.id = id
	ability.kind = GameEnums.AbilityKind.CLASS_SKILL
	ability.action_point_cost = 1
	ability.primary_resource = GameEnums.CostResource.AP
	ability.primary_value = 1
	ability.targeting_flags = targeting_flags
	ability.targeting_mode = (
		GameEnums.TargetingMode.DASH_LINE
		if targeting_flags == GameEnums.TargetingFlags.DASH_LINE
		else GameEnums.TargetingMode.TILE
	)
	return ability


static func _unit(id: int, team: GameEnums.Team, position: Vector2i) -> UnitState:
	var unit: UnitState = UnitState.new()
	unit.id = id
	unit.team = team
	unit.position = position
	unit.definition = UnitData.new()
	unit.definition.base_defense = 0
	unit.current_defense = 0
	unit.health = HealthComponent.new(20)
	unit.ability = AbilityComponent.new(3)
	return unit


static func _plain_board(size: Vector2i) -> BoardState:
	var terrain: TerrainData = TerrainData.new()
	terrain.id = &"plain"
	terrain.blocks_movement = false
	var board: BoardState = BoardState.new()
	board.grid_size = size
	for y: int in range(size.y):
		for x: int in range(size.x):
			var cell := Vector2i(x, y)
			board.tiles[cell] = TileState.create(cell, terrain)
	return board


static func _place(board: BoardState, unit: UnitState) -> void:
	GridSystem.set_occupant(board, unit.position, unit.id)
