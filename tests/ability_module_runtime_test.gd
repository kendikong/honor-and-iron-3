class_name AbilityModuleRuntimeTest
extends RefCounted

## Focused AD-2 runtime bar. These scenarios exercise AbilitySystem with authored
## modules and intentionally empty compatibility effects.

static func run_all(failures: Array[String]) -> void:
	_test_module_only_execution(failures)
	_test_upgraded_module_profile(failures)
	_test_motion_range_legality(failures)
	_test_if_collided_follow_up(failures)


static func _test_module_only_execution(failures: Array[String]) -> void:
	var board: BoardState = _plain_board(Vector2i(8, 4))
	var actor: UnitState = _unit(1, GameEnums.Team.PLAYER, Vector2i(1, 1), 20)
	var target: UnitState = _unit(2, GameEnums.Team.ENEMY, Vector2i(3, 1), 20)
	board.units = [actor, target]
	_place(board, actor)
	_place(board, target)

	var ability: AbilityData = _ability(&"runtime_module_only", GameEnums.TargetingFlags.ENEMY)
	var damage: AbilityModule = AbilityModule.new()
	damage.primary_type = GameEnums.EffectType.DAMAGE
	damage.amount = 4
	damage.min_range = 1
	damage.max_range = 3
	damage.targeting_flags = GameEnums.TargetingFlags.ENEMY
	ability.modules = [damage]
	ability.effects = []
	var events: Array[SimEvent] = []
	AbilitySystem.execute(
		board,
		TimelineAction.make_ability(actor.id, ability, target.position, target.id),
		events,
	)
	if target.health.current_hp != 16:
		failures.append(
			"module-only runtime did not apply authored DAMAGE (HP %d, effects %d, events %d)"
			% [target.health.current_hp, AbilitySystem.active_effects_for(actor, ability).size(), events.size()]
		)
	if not ability.effects.is_empty():
		failures.append("module-only runtime fixture was populated with compatibility effects")


static func _test_upgraded_module_profile(failures: Array[String]) -> void:
	var ability: AbilityData = _ability(&"runtime_profile_selection", GameEnums.TargetingFlags.ENEMY)
	var base: AbilityModule = AbilityModule.new()
	base.primary_type = GameEnums.EffectType.DAMAGE
	base.amount = 2
	base.min_range = 1
	base.max_range = 3
	var upgraded: AbilityModule = AbilityModule.new()
	upgraded.primary_type = GameEnums.EffectType.DAMAGE
	upgraded.amount = 7
	upgraded.min_range = 2
	upgraded.max_range = 4
	ability.modules = [base]
	ability.upgraded_modules = [upgraded]
	ability.effects = []
	ability.upgraded_effects = []
	var actor: UnitState = _unit(7, GameEnums.Team.PLAYER, Vector2i(1, 1), 20)
	actor.upgraded_abilities = [ability.id]
	var active: Array[AbilityModule] = AbilitySystem.active_modules_for(actor, ability)
	if active.size() != 1 or active[0] != upgraded:
		failures.append("upgraded module profile was not selected as a complete replacement")
	var effects: Array[EffectData] = AbilitySystem.active_effects_for(actor, ability)
	if effects.size() != 1 or effects[0].amount != 7:
		failures.append("upgraded module profile did not compile its authored amount")


static func _test_motion_range_legality(failures: Array[String]) -> void:
	var board: BoardState = _plain_board(Vector2i(8, 4))
	var actor: UnitState = _unit(1, GameEnums.Team.PLAYER, Vector2i(1, 1), 20)
	board.units = [actor]
	_place(board, actor)
	var ability: AbilityData = _ability(&"runtime_motion_range", GameEnums.TargetingFlags.TILE)
	var move: AbilityModule = AbilityModule.new()
	move.primary_type = GameEnums.EffectType.MOVE
	move.amount = 99
	move.min_range = 2
	move.max_range = 3
	move.targeting_flags = GameEnums.TargetingFlags.TILE
	ability.modules = [move]
	ability.effects = []

	var too_short: TimelineAction = TimelineAction.make_ability(
		actor.id, ability, Vector2i(2, 1),
	)
	var too_long: TimelineAction = TimelineAction.make_ability(
		actor.id, ability, Vector2i(5, 1),
	)
	if AbilitySystem.can_use(board, too_short):
		failures.append("module MOVE min_range did not reject a too-short destination")
	if AbilitySystem.can_use(board, too_long):
		failures.append("module MOVE max_range did not reject a too-long destination")


static func _test_if_collided_follow_up(failures: Array[String]) -> void:
	var board: BoardState = _plain_board(Vector2i(7, 5))
	var actor: UnitState = _unit(1, GameEnums.Team.PLAYER, Vector2i(2, 1), 20)
	var blocker: UnitState = _unit(2, GameEnums.Team.ENEMY, Vector2i(2, 2), 20)
	blocker.active_statuses.append(
		DataLibrary.make_status(GameEnums.StatusType.ROOT, 1),
	)
	board.units = [actor, blocker]
	_place(board, actor)
	_place(board, blocker)

	var ability: AbilityData = _ability(&"runtime_if_collided", GameEnums.TargetingFlags.DASH_LINE)
	var dash: AbilityModule = AbilityModule.new()
	dash.primary_type = GameEnums.EffectType.DASH
	dash.amount = 2
	dash.min_range = 1
	dash.max_range = 2
	dash.targeting_flags = GameEnums.TargetingFlags.DASH_LINE
	var follow_up: AbilityModule = AbilityModule.new()
	follow_up.primary_type = GameEnums.EffectType.MOVE
	follow_up.min_range = 1
	follow_up.max_range = 5
	follow_up.targeting_flags = GameEnums.TargetingFlags.TILE
	follow_up.gate = GameEnums.ModuleGate.IF_COLLIDED
	follow_up.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
	ability.modules = [dash, follow_up]
	ability.effects = []

	var events: Array[SimEvent] = []
	AbilitySystem.execute(
		board,
		TimelineAction.make_ability(actor.id, ability, Vector2i(2, 3)),
		events,
	)
	var collision_seen: bool = false
	var collision_data: Dictionary = {}
	for event: SimEvent in events:
		if event != null and event.type == GameEnums.SimEventType.COLLISION:
			collision_seen = true
			collision_data = event.data
			break
	if not collision_seen:
		failures.append("IF_COLLIDED fixture did not produce collision state")
	if actor.position != Vector2i(2, 3):
		var event_types: Array[String] = []
		for event: SimEvent in events:
			event_types.append(str(event.type))
		var route: Array[Vector2i] = MovementSystem.resolve_move_path(
			board, actor, Vector2i(2, 3), [], 5, ability,
		)
		var follow_effects: Array[EffectData] = AbilityModuleBridge.compile_module_to_effects(
			follow_up,
		)
		var gate_passes: bool = AbilitySystem._module_gate_passes(
			follow_up, actor, events, 0,
		)
		failures.append(
			"IF_COLLIDED follow-up MOVE did not execute in module order (position %s, collision %s, data %s, events %s, route %s, gate %d, effect %d, passes %s)"
			% [
				actor.position, collision_seen, collision_data, event_types, route,
				follow_up.gate, follow_effects[0].type if not follow_effects.is_empty() else -1, gate_passes,
			]
		)


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


static func _unit(
	id: int,
	team: GameEnums.Team,
	position: Vector2i,
	hp: int,
) -> UnitState:
	var unit: UnitState = UnitState.new()
	unit.id = id
	unit.team = team
	unit.position = position
	unit.definition = UnitData.new()
	unit.definition.base_defense = 0
	unit.current_defense = 0
	unit.health = HealthComponent.new(hp)
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
			var cell: Vector2i = Vector2i(x, y)
			board.tiles[cell] = TileState.create(cell, terrain)
	return board


static func _place(board: BoardState, unit: UnitState) -> void:
	GridSystem.set_occupant(board, unit.position, unit.id)
