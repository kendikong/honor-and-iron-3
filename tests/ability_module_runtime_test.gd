class_name AbilityModuleRuntimeTest
extends RefCounted

## Focused AD-2 runtime bar. These scenarios exercise AbilitySystem with authored
## modules and intentionally empty compatibility effects.

static func run_all(failures: Array[String]) -> void:
	_test_module_only_execution(failures)
	_test_base_multi_module_compatibility_order(failures)
	var native_order_failures: int = failures.size()
	print("ABILITY_MODULE_SCENARIO: native_multi_module_execute_order START")
	_test_base_multi_module_native_execute_order(failures)
	print(
		"ABILITY_MODULE_SCENARIO: native_multi_module_execute_order %s"
		% ("PASS" if failures.size() == native_order_failures else "FAIL")
	)
	_test_upgraded_module_profile(failures)
	_test_legacy_flat_targeting_compatibility(failures)
	_test_motion_range_legality(failures)
	_test_if_collided_follow_up(failures)
	_test_schema_module_round_trip(failures)
	_test_legacy_json_import_round_trip(failures)
	_test_modular_base_legacy_upgrade_import(failures)


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
	var stale_legacy_effect: EffectData = EffectData.new()
	stale_legacy_effect.type = GameEnums.EffectType.DAMAGE
	stale_legacy_effect.amount = 99
	ability.effects = [stale_legacy_effect]
	var events: Array[SimEvent] = []
	AbilitySystem.execute(
		board,
		TimelineAction.make_ability(actor.id, ability, target.position, target.id),
		events,
	)
	if target.health.current_hp != 16:
		failures.append(
			"module-only runtime did not apply authored DAMAGE (HP %d, effects %d, events %d)"
			% [
				target.health.current_hp,
				AbilitySystem.compatibility_effects_for(actor, ability).size(),
				events.size(),
			]
		)
	if ability.effects.size() != 1 or ability.effects[0].amount != 99:
		failures.append("module-only runtime fixture mutated its legacy compatibility cache")
	var compatibility_view: Array[EffectData] = AbilitySystem.compatibility_effects_for(actor, ability)
	if compatibility_view.size() != 1 or compatibility_view[0].amount != 4:
		failures.append("module-only runtime compatibility view did not derive from modules")


static func _test_base_multi_module_compatibility_order(failures: Array[String]) -> void:
	var ability: AbilityData = _ability(&"runtime_base_multi_module_order", GameEnums.TargetingFlags.ENEMY)
	var damage: AbilityModule = AbilityModule.new()
	damage.primary_type = GameEnums.EffectType.DAMAGE
	damage.amount = 3
	damage.min_range = 1
	damage.max_range = 3
	damage.targeting_flags = GameEnums.TargetingFlags.ENEMY
	var push: AbilityModule = AbilityModule.new()
	push.primary_type = GameEnums.EffectType.PUSH
	push.amount = 2
	push.min_range = 1
	push.max_range = 3
	push.targeting_flags = GameEnums.TargetingFlags.ENEMY
	ability.modules = [damage, push]
	ability.effects = []
	var compatibility_view: Array[EffectData] = AbilitySystem.compatibility_effects_for(null, ability)
	if (
		compatibility_view.size() != 2
		or compatibility_view[0].type != GameEnums.EffectType.DAMAGE
		or compatibility_view[0].amount != 3
		or compatibility_view[1].type != GameEnums.EffectType.PUSH
		or compatibility_view[1].amount != 2
	):
		failures.append("base multi-module compatibility order changed DAMAGE + PUSH")


static func _test_base_multi_module_native_execute_order(failures: Array[String]) -> void:
	var board: BoardState = _plain_board(Vector2i(8, 4))
	var actor: UnitState = _unit(1, GameEnums.Team.PLAYER, Vector2i(1, 1), 20)
	var target: UnitState = _unit(2, GameEnums.Team.ENEMY, Vector2i(3, 1), 20)
	board.units = [actor, target]
	_place(board, actor)
	_place(board, target)

	var ability: AbilityData = _ability(&"runtime_native_multi_module_order", GameEnums.TargetingFlags.ENEMY)
	var damage: AbilityModule = AbilityModule.new()
	damage.primary_type = GameEnums.EffectType.DAMAGE
	damage.amount = 3
	damage.min_range = 1
	damage.max_range = 3
	damage.targeting_flags = GameEnums.TargetingFlags.ENEMY
	var push: AbilityModule = AbilityModule.new()
	push.primary_type = GameEnums.EffectType.PUSH
	push.amount = 2
	push.min_range = 1
	push.max_range = 3
	push.targeting_flags = GameEnums.TargetingFlags.ENEMY
	push.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
	push.aim_module_index = 0
	ability.modules = [damage, push]
	ability.effects = []

	var events: Array[SimEvent] = []
	AbilitySystem.execute(
		board,
		TimelineAction.make_ability(actor.id, ability, target.position, target.id),
		events,
	)
	AbilitySystem.resolve_pending_pushes(board, events)

	var damage_event_index: int = -1
	var push_event_index: int = -1
	for index: int in events.size():
		var event: SimEvent = events[index]
		if event == null:
			continue
		if (
			damage_event_index < 0
			and event.type == GameEnums.SimEventType.UNIT_DAMAGED
			and int(event.data.get("unit", -1)) == target.id
		):
			damage_event_index = index
		if (
			push_event_index < 0
			and event.type == GameEnums.SimEventType.UNIT_PUSHED
			and int(event.data.get("unit", -1)) == target.id
		):
			push_event_index = index
	if damage_event_index < 0 or push_event_index < 0 or damage_event_index >= push_event_index:
		failures.append(
			"native multi-module execute did not order DAMAGE before PUSH (events %s)"
			% _event_types(events)
		)
	if target.health.current_hp != 17 or target.position != Vector2i(5, 1):
		failures.append(
			"native multi-module execute produced HP %d at %s, expected HP 17 at (5, 1)"
			% [target.health.current_hp, target.position]
		)


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
	var effects: Array[EffectData] = AbilitySystem.compatibility_effects_for(actor, ability)
	if effects.size() != 1 or effects[0].amount != 7:
		failures.append("upgraded module profile did not compile its authored amount")


static func _test_legacy_flat_targeting_compatibility(failures: Array[String]) -> void:
	var board: BoardState = _plain_board(Vector2i(8, 4))
	var actor: UnitState = _unit(1, GameEnums.Team.PLAYER, Vector2i(1, 1), 20)
	var target: UnitState = _unit(2, GameEnums.Team.ENEMY, Vector2i(3, 1), 20)
	board.units = [actor, target]
	_place(board, actor)
	_place(board, target)

	var ability: AbilityData = _ability(&"runtime_legacy_flat", 0)
	ability.targeting_mode = GameEnums.TargetingMode.ENEMY_UNIT
	ability.range_tiles = 3
	var damage: EffectData = EffectData.new()
	damage.type = GameEnums.EffectType.DAMAGE
	damage.amount = 4
	ability.effects = [damage]
	var events: Array[SimEvent] = []
	AbilitySystem.execute(
		board,
		TimelineAction.make_ability(actor.id, ability, target.position, target.id),
		events,
	)
	if target.health.current_hp != 16:
		failures.append(
			"legacy flat targeting mode did not resolve DAMAGE (HP %d)" % target.health.current_hp
		)


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

	if AbilitySystem._module_gate_passes(follow_up, actor, [], 0):
		failures.append("IF_COLLIDED gate passed without a collision event")
	if not AbilitySystem.ability_has_effect(ability, GameEnums.EffectType.MOVE, actor):
		failures.append("typed metadata scan did not see gated MOVE module")
	var compatibility_view: Array[EffectData] = AbilitySystem.compatibility_effects_for(actor, ability)
	if (
		compatibility_view.size() != 1
		or compatibility_view[0].type != GameEnums.EffectType.DASH
		or not compatibility_view[0].modifiers.has("violent_collision_recast")
	):
		failures.append("compatibility view did not stay gated-stripped for IF_COLLIDED")

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


static func _test_schema_module_round_trip(failures: Array[String]) -> void:
	var authored: AbilityData = AbilityData.new()
	authored.id = &"schema_round_trip"
	authored.planner_group = GameEnums.PlannerGroup.ACTION
	authored.primary_resource = GameEnums.CostResource.AP
	authored.primary_value = 2
	authored.tags = [&"positioning", &"attack"]
	var module: AbilityModule = AbilityModule.new()
	module.primary_type = GameEnums.EffectType.PUSH
	module.amount = 2
	module.min_range = 1
	module.max_range = 4
	module.targeting_flags = GameEnums.TargetingFlags.ENEMY
	module.target_shape = GameEnums.TargetShape.SINGLE
	var keyword: AbilityKeyword = AbilityKeyword.new()
	keyword.keyword_id = GameEnums.AbilityKeywordId.PIERCE
	keyword.amount = 1
	module.keywords = [keyword]
	var layer: AbilityLayer = AbilityLayer.new()
	layer.effect = EffectData.new()
	layer.effect.type = GameEnums.EffectType.DAMAGE
	layer.effect.amount = 1
	module.layers = [layer]
	authored.modules = [module]
	var upgraded_module: AbilityModule = module.duplicate(true) as AbilityModule
	upgraded_module.amount = 5
	authored.upgraded_modules = [upgraded_module]
	authored.upgraded_primary_value = 4
	authored.secondary_resource = GameEnums.CostResource.HP
	authored.secondary_value = 2
	authored.cost_modifier = GameEnums.CostModifier.ZERO_IF_ADJACENT_ENEMIES_GTE_N
	authored.cost_modifier_n = 2
	authored.finalize_modular()
	var payload: Dictionary = ClassLibrarySchema.ability_to_dict(authored)
	for legacy_key: String in [
		"effects", "upgraded_effects", "range_tiles", "targeting_mode",
		"targeting_flags", "target_shape", "action_point_cost", "movement_point_cost",
	]:
		if payload.has(legacy_key):
			failures.append("module-first ability JSON emitted legacy key %s" % legacy_key)
	var restored: AbilityData = AbilityData.new()
	ClassLibrarySchema.apply_ability_dict(restored, payload)
	if restored.modules.size() != 1:
		failures.append("module-first JSON round trip lost authored module")
		return
	var restored_module: AbilityModule = restored.modules[0]
	if (
		restored.primary_value != authored.primary_value
		or restored.tags != authored.tags
		or restored_module.primary_type != module.primary_type
		or restored_module.amount != module.amount
		or restored_module.min_range != module.min_range
		or restored_module.max_range != module.max_range
		or restored_module.targeting_flags != module.targeting_flags
		or restored_module.keywords.size() != 1
		or restored_module.layers.size() != 1
		or restored.upgraded_modules.size() != 1
		or restored.upgraded_modules[0].amount != upgraded_module.amount
		or restored.upgraded_primary_value != authored.upgraded_primary_value
		or restored.secondary_resource != authored.secondary_resource
		or restored.secondary_value != authored.secondary_value
		or restored.cost_modifier != authored.cost_modifier
		or restored.cost_modifier_n != authored.cost_modifier_n
	):
		failures.append("module-first JSON round trip changed header or module data")
	var player_text: String = CombatUiFormatters.ability_effect_bbcode(authored)
	if player_text.find("PUSH") < 0:
		failures.append("module-first player-facing formatter lost PUSH text")
	var unknown_tag_payload: Dictionary = payload.duplicate(true)
	unknown_tag_payload["tags"] = ["attack", "control"]
	var unknown_tag_result: AbilityData = AbilityData.new()
	ClassLibrarySchema.apply_ability_dict(unknown_tag_result, unknown_tag_payload)
	if unknown_tag_result.tags.has(&"control"):
		failures.append("module-first JSON retained an unknown tag")


static func _test_legacy_json_import_round_trip(failures: Array[String]) -> void:
	var legacy_effect: EffectData = EffectData.new()
	legacy_effect.type = GameEnums.EffectType.DAMAGE
	legacy_effect.amount = 6
	var legacy_payload: Dictionary = {
		"display_name": "Legacy Strike",
		"kind": GameEnums.AbilityKind.CLASS_SKILL,
		"action_point_cost": 1,
		"range_tiles": 3,
		"targeting_mode": GameEnums.TargetingMode.ENEMY_UNIT,
		"effects": ClassLibrarySchema.effects_to_dict_array([legacy_effect]),
	}
	var imported: AbilityData = AbilityData.new()
	ClassLibrarySchema.apply_ability_dict(imported, legacy_payload)
	if imported.modules.size() != 1 or imported.effects.size() != 1:
		failures.append("legacy effects-only JSON did not infer a modular profile")
	elif imported.modules[0].primary_type != GameEnums.EffectType.DAMAGE:
		failures.append("legacy effects-only JSON inferred the wrong module effect")
	var hybrid_payload: Dictionary = legacy_payload.duplicate(true)
	hybrid_payload["modules"] = []
	var hybrid: AbilityData = AbilityData.new()
	ClassLibrarySchema.apply_ability_dict(hybrid, hybrid_payload)
	if hybrid.modules.size() != 1 or hybrid.modules[0].amount != 6:
		failures.append("hybrid empty-modules JSON dropped legacy effects")


static func _test_modular_base_legacy_upgrade_import(failures: Array[String]) -> void:
	var base_module: AbilityModule = AbilityModule.new()
	base_module.primary_type = GameEnums.EffectType.DAMAGE
	base_module.amount = 2
	base_module.max_range = 3
	base_module.targeting_flags = GameEnums.TargetingFlags.ENEMY
	var base: AbilityData = AbilityData.new()
	base.modules = [base_module]
	base.finalize_modular()
	var upgraded_effect: EffectData = EffectData.new()
	upgraded_effect.type = GameEnums.EffectType.DAMAGE
	upgraded_effect.amount = 9
	var payload: Dictionary = ClassLibrarySchema.ability_to_dict(base)
	payload.erase("upgraded_modules")
	payload["upgraded_effects"] = ClassLibrarySchema.effects_to_dict_array([upgraded_effect])
	var imported: AbilityData = AbilityData.new()
	ClassLibrarySchema.apply_ability_dict(imported, payload)
	if imported.upgraded_modules.size() != 1 or imported.upgraded_modules[0].amount != 9:
		failures.append("modular base plus legacy upgraded_effects lost upgrade profile")


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


static func _event_types(events: Array[SimEvent]) -> Array[String]:
	var types: Array[String] = []
	for event: SimEvent in events:
		types.append(str(event.type) if event != null else "null")
	return types
