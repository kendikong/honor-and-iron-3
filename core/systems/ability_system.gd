# ==============================================================================
# 🛑 WARNING TO AI AGENTS (HONOR & IRON ARCHITECTURE STRICT RULES) 🛑
# ==============================================================================
# DO NOT BRANCH ON `ability.id` IN THIS FILE. EVER.
# 
# Abilities are DATA, not engine code modifications. You are strictly forbidden
# from writing things like `if action.ability.id == "knight_shield_bash"` to
# inject mechanics. If an ability needs custom behavior (STAGGER on collision, 
# chain pushes, etc), you MUST add a new generic flag to `GameEnums.EffectType`
# or `GameEnums.StatusType`, assign it in the factory, and check for THAT flag.
# 
# VIOLATING THIS RULE WILL CAUSE THE AUTOMATED ARCHITECTURE TEST TO FAIL.
# ==============================================================================
class_name AbilitySystem
extends RefCounted

## Purpose: Runs the data-driven ability pipeline (Validate -> Execute -> Resolve).
## Responsibilities: Validate cost/range, spend action points, and interpret each
##   EffectData by delegating to the system that owns that effect.
## Dependencies: BoardState, UnitState, TimelineAction, EffectData, GridSystem,
##   CombatSystem, PhysicsSystem, SimEvent, GameEnums.
## Lifecycle: stateless; only static functions.

static func can_use(board: BoardState, action: TimelineAction) -> bool:
	var actor := board.get_unit_by_id(action.actor_id)
	if actor == null or not actor.is_alive():
		return false
	var ability := action.ability
	if ability == null:
		return false
	if not _has_resource_for_ability(actor, ability):
		return false
	var dist := GridSystem.manhattan(actor.position, action.target_coord)
	if ability_has_dash(ability):
		if PhysicsSystem.straight_line_dir(actor.position, action.target_coord) == Vector2i.ZERO:
			return false
		dist = PhysicsSystem.straight_line_distance(actor.position, action.target_coord)
	var max_range: int = actor.get_ability_range(ability)
	if ability_has_dash(ability):
		max_range = maxi(max_range, dash_steps(ability))
	var move_steps_for_range: int = effect_amount(ability, GameEnums.EffectType.MOVE, actor)
	if move_steps_for_range > 0:
		max_range = maxi(max_range, move_steps_for_range)
	if dist > max_range:
		return false
	if dist == 0 and actor.get_ability_range(ability) > 0 and not can_target_self(actor, ability):
		return false
	var target_unit: UnitState = null
	if action.target_unit_id >= 0:
		target_unit = board.get_unit_by_id(action.target_unit_id)
	else:
		target_unit = board.get_unit_at(action.target_coord)
	if not _target_allowed(actor, ability, target_unit, action.target_coord):
		return false

	if dist > 1:
		var tile = board.get_tile(action.target_coord)
		if tile != null and not tile.is_empty():
			var target = board.get_unit_by_id(tile.occupant_id)
			if target != null and target.has_status(GameEnums.StatusType.STEALTH):
				return false

	if actor.has_status(GameEnums.StatusType.STAGGER) or actor.has_status(GameEnums.StatusType.SILENCE):
		return false

	if actor.has_status(GameEnums.StatusType.PACIFY) and ability_uses_attack_animation(ability):
		for effect in ability.effects:
			if effect.type == GameEnums.EffectType.DAMAGE or effect.type == GameEnums.EffectType.EXPLODE or effect.type == GameEnums.EffectType.RANGED_EXPLODE:
				return false

	if ability.consumes_action_slot() and not actor.can_use_action_slot():
		return false

	var has_displacement := has_displacement_effects(ability)
		
	var is_dash := ability_has_dash(ability)
	var is_move := effect_amount(ability, GameEnums.EffectType.MOVE) > 0
	
	if is_dash:
		var delta := action.target_coord - actor.position
		if delta.x != 0 and delta.y != 0:
			return false
		if PhysicsSystem.straight_line_dir(actor.position, action.target_coord) == Vector2i.ZERO:
			return false
		var steps := PhysicsSystem.straight_line_distance(actor.position, action.target_coord)
		var dash_amount := effect_amount(ability, GameEnums.EffectType.DASH)
		if steps < 1 or steps > dash_amount:
			return false

	if is_move or (has_pass_through_effects(ability) and not is_dash):
		if action.target_coord != actor.position:
			var walk_steps: int = effect_amount(ability, GameEnums.EffectType.MOVE)
			if walk_steps <= 0:
				walk_steps = ability.range_tiles
			if GridSystem.manhattan(actor.position, action.target_coord) > walk_steps:
				return false
				
	if is_move or is_dash:
		if not has_displacement and not has_pass_through_effects(ability):
			var end_unit := board.get_unit_at(action.target_coord)
			if end_unit != null and end_unit.id != actor.id:
				return false

	return true


static func get_action_point_cost(actor: UnitState, ability: AbilityData, board: BoardState = null) -> int:
	if ability == null:
		return 0
	var ap_cost := ability.action_point_cost
	if actor == null or board == null:
		return ap_cost
	var effects: Array = ability.effects
	if actor.is_ability_upgraded(ability.id) and ability.upgraded_effects.size() > 0:
		effects = ability.upgraded_effects
	for eff: EffectData in effects:
		if eff != null and eff.modifiers.has("zero_ap_adjacent_enemies"):
			var needed: int = int(eff.modifiers["zero_ap_adjacent_enemies"])
			var adj_enemies := 0
			for dir in GridSystem.DIRECTIONS:
				var occ := board.get_unit_at(actor.position + dir)
				if occ != null and occ.team != actor.team:
					adj_enemies += 1
			if adj_enemies >= needed:
				return 0
	return ap_cost


static func movement_point_cost(actor: UnitState, ability: AbilityData) -> int:
	if ability == null:
		return 0
	if (
		actor != null
		and actor.is_ability_upgraded(ability.id)
		and ability.upgraded_movement_point_cost >= 0
	):
		return ability.upgraded_movement_point_cost
	return ability.movement_point_cost


static func _has_resource_for_ability(actor: UnitState, ability: AbilityData, board: BoardState = null) -> bool:
	if ability == null or actor == null:
		return false
		
	var ap_cost = get_action_point_cost(actor, ability, board)
	if ability.is_pre_move_planner():
		return actor.movement.points_left >= movement_point_cost(actor, ability)
	match ability.kind:
		GameEnums.AbilityKind.UNIVERSAL_RUN:
			if actor.has_run_boost():
				return false
			return actor.ability.points_left >= ap_cost
		GameEnums.AbilityKind.CLASS_SKILL:
			return actor.ability.points_left >= ap_cost
		GameEnums.AbilityKind.UNIVERSAL_WAIT:
			return actor.can_use_action_slot()
	return true


static func _target_allowed(
	actor: UnitState,
	ability: AbilityData,
	target: UnitState,
	target_coord: Vector2i,
) -> bool:
	if ability == null or actor == null:
		return false
	ability.ensure_targeting_flags_from_mode()
	if target != null:
		if target.id == actor.id and ability.has_targeting(GameEnums.TargetingFlags.SELF):
			return true
		if target.id != actor.id and target.team == actor.team and ability.has_targeting(GameEnums.TargetingFlags.ALLY):
			return true
		if target.team != actor.team and ability.has_targeting(GameEnums.TargetingFlags.ENEMY):
			return true
	if target_coord == actor.position:
		return ability.has_targeting(GameEnums.TargetingFlags.SELF)
	if ability.has_targeting(GameEnums.TargetingFlags.TILE):
		return true
	if ability.has_targeting(GameEnums.TargetingFlags.DASH_LINE):
		return true
	return false


static func can_target_self(_actor: UnitState, ability: AbilityData) -> bool:
	if ability == null:
		return false
	ability.ensure_targeting_flags_from_mode()
	return ability.has_targeting(GameEnums.TargetingFlags.SELF)


static func target_passes_mode(actor: UnitState, ability: AbilityData, target: UnitState) -> bool:
	if actor == null or ability == null:
		return false
	var coord: Vector2i = target.position if target != null else Vector2i.ZERO
	return _target_allowed(actor, ability, target, coord)


static func ability_has_dash(ability: AbilityData) -> bool:
	if ability == null:
		return false
	for eff in ability.effects:
		if eff.type == GameEnums.EffectType.DASH:
			return true
	return false


static func ability_has_movement_effect(ability: AbilityData) -> bool:
	if ability == null:
		return false
	for eff in ability.effects:
		if eff.type in [
			GameEnums.EffectType.DASH,
			GameEnums.EffectType.MOVE,
			GameEnums.EffectType.TELEPORT_CASTER,
			GameEnums.EffectType.MOVE_INTO_AND_PUSH,
		]:
			return true
	return false


static func is_movement_skill(ability: AbilityData) -> bool:
	## Legacy alias — prefer ability.is_movement_kind() / planner_group (ability-data.md §14.12).
	if ability == null:
		return false
	return ability.is_movement_kind()


## Module list for resolution (upgraded profile when applicable).
static func modules_for_actor(actor: UnitState, ability: AbilityData) -> Array[AbilityModule]:
	var empty: Array[AbilityModule] = []
	if ability == null:
		return empty
	if (
		actor != null
		and actor.is_ability_upgraded(ability.id)
		and not ability.upgraded_modules.is_empty()
	):
		return ability.upgraded_modules
	return ability.modules


## True when any module declares this gate (ability-data.md §2.7). Modules are the only source.
static func ability_has_module_gate(
	ability: AbilityData,
	gate: GameEnums.ModuleGate,
	actor: UnitState = null
) -> bool:
	if ability == null:
		return false
	for mod: AbilityModule in modules_for_actor(actor, ability):
		if mod != null and mod.gate == gate:
			return true
	return false


## Gate check at module resolution time (board after earlier modules).
static func evaluate_module_gate(
	gate: GameEnums.ModuleGate,
	collided: bool = false,
	killed_enemy: bool = false,
	damage_dealt: bool = false
) -> bool:
	match gate:
		GameEnums.ModuleGate.ALWAYS:
			return true
		GameEnums.ModuleGate.IF_COLLIDED:
			return collided
		GameEnums.ModuleGate.IF_KILL:
			return killed_enemy
		GameEnums.ModuleGate.IF_DAMAGE_DEALT:
			return damage_dealt
		_:
			## Unknown / unimplemented gates fail closed (do not silently run).
			return false


## Indices of modules that need a fresh player aim (NEW_AIM + motion/tile).
static func planning_modules_needing_aim(actor: UnitState, ability: AbilityData) -> Array[int]:
	var result: Array[int] = []
	if ability == null:
		return result
	var modules: Array = modules_for_actor(actor, ability)
	for i: int in range(modules.size()):
		var mod: AbilityModule = modules[i]
		if mod == null or mod.aim_binding != GameEnums.AimBinding.NEW_AIM:
			continue
		if _module_needs_player_aim(mod):
			result.append(i)
	return result


static func _module_needs_player_aim(mod: AbilityModule) -> bool:
	if mod == null:
		return false
	if mod.primary_type in [
		GameEnums.EffectType.DASH,
		GameEnums.EffectType.MOVE,
		GameEnums.EffectType.TELEPORT_CASTER,
		GameEnums.EffectType.MOVE_INTO_AND_PUSH,
	]:
		return true
	return mod.has_targeting(GameEnums.TargetingFlags.TILE) or mod.has_targeting(GameEnums.TargetingFlags.DASH_LINE)


## Next module index needing player aim after `after_mod_idx`, or -1 when complete / gate skips follow-up.
static func planning_next_awaiting_module_index(
	board: BoardState,
	actor: UnitState,
	ability: AbilityData,
	after_mod_idx: int,
	module_coords: Array = [],
) -> int:
	if actor == null or ability == null:
		return -1
	var need_indices: Array[int] = planning_modules_needing_aim(actor, ability)
	var modules: Array = modules_for_actor(actor, ability)
	for idx: int in need_indices:
		if idx <= after_mod_idx:
			continue
		if idx >= modules.size():
			continue
		var mod: AbilityModule = modules[idx]
		if mod == null:
			continue
		if mod.gate != GameEnums.ModuleGate.ALWAYS:
			if not _planning_module_gate_would_activate(
				board, actor, ability, mod, after_mod_idx, module_coords,
			):
				continue
		return idx
	return -1


static func _planning_module_gate_would_activate(
	board: BoardState,
	actor: UnitState,
	ability: AbilityData,
	mod: AbilityModule,
	prior_mod_idx: int,
	module_coords: Array,
) -> bool:
	if mod == null:
		return false
	match mod.gate:
		GameEnums.ModuleGate.ALWAYS:
			return true
		GameEnums.ModuleGate.IF_COLLIDED:
			var dash_coord: Vector2i = TimelineAction.MODULE_COORD_UNSET
			if prior_mod_idx >= 0 and prior_mod_idx < module_coords.size():
				var raw: Variant = module_coords[prior_mod_idx]
				if raw is Vector2i:
					dash_coord = raw
			if dash_coord == TimelineAction.MODULE_COORD_UNSET:
				return false
			return planning_gated_followup_active(board, actor, ability, dash_coord)
		_:
			return false


## First module index with this gate, or -1.
static func first_module_index_with_gate(
	actor: UnitState,
	ability: AbilityData,
	gate: GameEnums.ModuleGate,
) -> int:
	if ability == null:
		return -1
	var modules: Array = modules_for_actor(actor, ability)
	for i: int in range(modules.size()):
		var mod: AbilityModule = modules[i]
		if mod != null and mod.gate == gate:
			return i
	return -1


## Predict whether IF_COLLIDED follow-up would activate after dashing to dash_coord (matches sim gate).
static func planning_gated_followup_active(
	board: BoardState,
	actor: UnitState,
	ability: AbilityData,
	dash_coord: Vector2i,
) -> bool:
	if board == null or actor == null or ability == null:
		return false
	if first_module_index_with_gate(actor, ability, GameEnums.ModuleGate.IF_COLLIDED) < 0:
		return false
	var scratch: BoardState = board.clone()
	var sim_actor: UnitState = scratch.get_unit_by_id(actor.id)
	if sim_actor == null:
		return false
	sim_actor.passive_flags.erase("module_gate_collided")
	var dir: Vector2i = PhysicsSystem.straight_line_dir(sim_actor.position, dash_coord)
	var steps: int = PhysicsSystem.straight_line_distance(sim_actor.position, dash_coord)
	if dir == Vector2i.ZERO or steps < 1:
		return false
	var mods: Dictionary = pass_through_modifiers(ability, actor)
	var events: Array[SimEvent] = []
	PhysicsSystem.dash(
		scratch,
		sim_actor,
		dir,
		steps,
		events,
		sim_actor,
		ability.id,
		int(mods.get("trample_atk", 0)),
		ability.display_name,
		int(mods.get("bulldoze", 0)),
		true,
	)
	return sim_actor.passive_flags.get("module_gate_collided", false)


static func planning_awaiting_module_range(
	actor: UnitState,
	ability: AbilityData,
	module_index: int,
) -> int:
	if ability == null or module_index < 0:
		return 0
	var modules: Array = modules_for_actor(actor, ability)
	if module_index >= modules.size():
		return 0
	var mod: AbilityModule = modules[module_index]
	if mod == null:
		return 0
	if mod.primary_type == GameEnums.EffectType.DASH:
		if mod.amount > 0:
			return mod.amount
		return mod.max_range if mod.max_range > 0 else dash_steps(ability)
	if mod.primary_type == GameEnums.EffectType.MOVE:
		if mod.amount > 0 and mod.max_range <= 0:
			return mod.amount
		return mod.max_range if mod.max_range > 0 else effect_amount(ability, GameEnums.EffectType.MOVE, actor)
	return mod.max_range if mod.max_range > 0 else ability.range_tiles


static func planning_awaiting_module_min_range(
	actor: UnitState,
	ability: AbilityData,
	module_index: int,
) -> int:
	if ability == null or module_index < 0:
		return 1
	var modules: Array = modules_for_actor(actor, ability)
	if module_index >= modules.size():
		return 1
	var mod: AbilityModule = modules[module_index]
	if mod == null:
		return 1
	return maxi(1, mod.min_range)


## Range origin for the module currently being aimed (prior module coords when chained).
static func planning_awaiting_origin_for_action(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
) -> Vector2i:
	if actor == null:
		return Vector2i.ZERO
	if action != null and action.awaiting_module_index > 0:
		for prior: int in range(action.awaiting_module_index):
			if action.has_module_coord(prior):
				return action.get_module_coord(prior)
	return actor.position if actor != null else Vector2i.ZERO


static func planning_is_valid_module_endpoint(
	board: BoardState,
	origin: Vector2i,
	coord: Vector2i,
	ability: AbilityData,
	actor: UnitState,
	module_index: int,
) -> bool:
	if ability == null or board == null or actor == null or module_index < 0:
		return false
	var modules: Array = modules_for_actor(actor, ability)
	if module_index >= modules.size():
		return false
	var mod: AbilityModule = modules[module_index]
	if mod == null:
		return false
	var min_range: int = planning_awaiting_module_min_range(actor, ability, module_index)
	var max_range: int = planning_awaiting_module_range(actor, ability, module_index)
	if max_range <= 0:
		return false
	if coord == origin:
		return false
	if mod.primary_type == GameEnums.EffectType.DASH or mod.has_targeting(GameEnums.TargetingFlags.DASH_LINE):
		var delta: Vector2i = coord - origin
		if delta.x != 0 and delta.y != 0:
			return false
		var steps: int = PhysicsSystem.straight_line_distance(origin, coord)
		return steps >= min_range and steps <= max_range
	var dist: int = GridSystem.manhattan(origin, coord)
	if dist < min_range or dist > max_range:
		return false
	if mod.primary_type == GameEnums.EffectType.MOVE and mod.has_targeting(GameEnums.TargetingFlags.TILE):
		if not board.is_in_bounds(coord):
			return false
		var occ: UnitState = board.get_unit_at(coord)
		if occ != null and occ.id != actor.id:
			return false
		if GridSystem.is_wall(board, coord):
			return false
	return true


## Planning: one-click commit vs two-phase awaiting-target flow (keyword rules live here only).
static func planning_commit_flow(actor: UnitState, ability: AbilityData) -> int:
	if actor == null or ability == null:
		return GameEnums.PlanningCommitFlow.IMMEDIATE
	var requires_aiming := ability_has_movement_effect(ability) or ability.has_targeting(GameEnums.TargetingFlags.TILE)
	if not requires_aiming or can_target_self(actor, ability):
		return GameEnums.PlanningCommitFlow.IMMEDIATE
	if not can_plan(actor, ability):
		return GameEnums.PlanningCommitFlow.IMMEDIATE
	return GameEnums.PlanningCommitFlow.AWAITING_TARGET


static func planning_arms_on_self_tile(actor: UnitState, ability: AbilityData) -> bool:
	return planning_commit_flow(actor, ability) == GameEnums.PlanningCommitFlow.AWAITING_TARGET


static func planning_pairs_with_premove(actor: UnitState, ability: AbilityData) -> bool:
	if actor == null or ability == null:
		return false
	if is_run_ability(ability) or is_wait_ability(ability):
		return false
	if planning_commit_flow(actor, ability) != GameEnums.PlanningCommitFlow.IMMEDIATE:
		return false
	return can_target_self(actor, ability)


static func planning_auto_arms_after_premove(actor: UnitState, ability: AbilityData) -> bool:
	return planning_commit_flow(actor, ability) == GameEnums.PlanningCommitFlow.AWAITING_TARGET


static func planning_awaiting_phase(ability: AbilityData) -> int:
	if ability == null:
		return GameEnums.PlanningAwaitingPhase.GENERIC
	if ability_has_movement_effect(ability) or ability.has_targeting(GameEnums.TargetingFlags.TILE):
		return GameEnums.PlanningAwaitingPhase.MOVEMENT_ENDPOINT
	return GameEnums.PlanningAwaitingPhase.GENERIC


static func planning_awaiting_endpoint_range(ability: AbilityData) -> int:
	if planning_awaiting_phase(ability) == GameEnums.PlanningAwaitingPhase.MOVEMENT_ENDPOINT:
		var ds := dash_steps(ability)
		if ds > 0:
			return ds
		var ws := effect_amount(ability, GameEnums.EffectType.MOVE)
		if ws > 0:
			return ws
		return ability.range_tiles
	return 0


static func planning_is_valid_awaiting_endpoint(
	origin: Vector2i,
	coord: Vector2i,
	ability: AbilityData,
) -> bool:
	var max_range: int = planning_awaiting_endpoint_range(ability)
	if max_range <= 0:
		return false
	if coord == origin:
		return false
	if ability_has_dash(ability):
		var delta: Vector2i = coord - origin
		if delta.x != 0 and delta.y != 0:
			return false
	var dist: int = GridSystem.manhattan(origin, coord)
	return dist >= 1 and dist <= max_range


## TILE-aim abilities commit a cell; occupant id is incidental (sim resolves via target_coord).
static func planning_commit_target_unit_id(ability: AbilityData, occupant_unit_id: int) -> int:
	if ability != null and ability.has_targeting(GameEnums.TargetingFlags.TILE):
		return -1
	return occupant_unit_id


## Deprecated alias: use planning_arms_on_self_tile / planning_auto_arms_after_premove.
static func ability_arms_dash_on_self_click(actor: UnitState, ability: AbilityData) -> bool:
	return planning_arms_on_self_tile(actor, ability)


static func effect_amount(
	ability: AbilityData,
	effect_type: GameEnums.EffectType,
	actor: UnitState = null,
) -> int:
	if ability == null:
		return 0
	var effects: Array = ability.effects
	if actor != null and actor.is_ability_upgraded(ability.id) and ability.upgraded_effects.size() > 0:
		effects = ability.upgraded_effects
	for eff in effects:
		if eff.type == effect_type:
			return eff.amount
	return 0


static func ability_has_swap_effect(ability: AbilityData) -> bool:
	if ability == null:
		return false
	for eff: EffectData in ability.effects:
		if eff.type == GameEnums.EffectType.SWAP:
			return true
	return false


static func has_pass_through_effects(ability: AbilityData) -> bool:
	if ability == null:
		return false
	return has_pass_through_effects_from(ability.effects)


static func has_displacement_effects(ability: AbilityData) -> bool:
	return effect_amount(ability, GameEnums.EffectType.PUSH) > 0 \
		or effect_amount(ability, GameEnums.EffectType.PULL) > 0 \
		or ability_has_swap_effect(ability) \
		or effect_amount(ability, GameEnums.EffectType.BULLDOZE) > 0


static func dash_steps(ability: AbilityData) -> int:
	return effect_amount(ability, GameEnums.EffectType.DASH)


## Single planning-preview entry point: action range tiles from `origin` (cursor-shifted during pre/post-move).
## Presentation calls this instead of per-keyword branches in the overlay.
static func planning_action_range_tiles(
	board: BoardState,
	unit: UnitState,
	ability: AbilityData,
	origin: Vector2i,
	alternate_origins: Array[Vector2i] = [],
) -> Array[Vector2i]:
	return planning_threat_tiles(board, unit, ability, origin, alternate_origins)


static func planning_threat_tiles(
	board: BoardState,
	unit: UnitState,
	ability: AbilityData,
	origin: Vector2i,
	alternate_origins: Array[Vector2i] = [],
) -> Array[Vector2i]:
	if board == null or unit == null or ability == null:
		var empty: Array[Vector2i] = []
		return empty
	if ability_has_dash(ability):
		return dash_line_threat_tiles(board, origin, dash_steps(ability))
	var eff_range: int = unit.get_ability_range(ability)
	if eff_range <= 0:
		if ability.target_shape == GameEnums.TargetShape.SINGLE:
			return _single_coord(origin)
		var shape: GameEnums.TargetShape = ability.target_shape
		var shape_size: int = ability.target_shape_size
		if unit.is_ability_upgraded(ability.id):
			if ability.upgraded_target_shape != GameEnums.TargetShape.SINGLE:
				shape = ability.upgraded_target_shape
			if ability.upgraded_target_shape_size >= 0:
				shape_size = ability.upgraded_target_shape_size
		return GridSystem.get_affected_tiles(board, origin, origin, shape, shape_size)
	var sources: Array[Vector2i] = alternate_origins if not alternate_origins.is_empty() else _single_coord(origin)
	return manhattan_threat_tiles(board, sources, eff_range)


static func _single_coord(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.append(cell)
	return out


static func dash_line_threat_tiles(board: BoardState, origin: Vector2i, steps: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if board == null or steps <= 0:
		return tiles
	for dir: Vector2i in GridSystem.DIRECTIONS:
		for i: int in range(1, steps + 1):
			var coord: Vector2i = origin + dir * i
			if board.is_in_bounds(coord):
				tiles.append(coord)
	return tiles


static func manhattan_threat_tiles(
	board: BoardState,
	origins: Array[Vector2i],
	range_tiles: int,
) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if board == null or range_tiles <= 0 or origins.is_empty():
		return tiles
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			var coord := Vector2i(x, y)
			for src: Vector2i in origins:
				if GridSystem.manhattan(coord, src) <= range_tiles:
					tiles.append(coord)
					break
	return tiles


static func pass_through_modifiers(ability: AbilityData, actor: UnitState = null) -> Dictionary:
	var effects: Array = ability.effects if ability != null else []
	if ability != null and actor != null and actor.is_ability_upgraded(ability.id) and ability.upgraded_effects.size() > 0:
		effects = ability.upgraded_effects
	return pass_through_modifiers_from(effects)


static func pass_through_modifiers_from(effects: Array) -> Dictionary:
	var trample_atk := 0
	var bulldoze := 0
	var push := 0
	for eff: EffectData in effects:
		if eff.type == GameEnums.EffectType.TRAMPLE:
			trample_atk = eff.amount
		elif eff.type == GameEnums.EffectType.BULLDOZE:
			bulldoze = eff.amount
		elif eff.type == GameEnums.EffectType.PUSH:
			push = eff.amount
		elif eff.type == GameEnums.EffectType.DASH:
			if eff.modifiers.has("bulldoze"):
				bulldoze = int(eff.modifiers["bulldoze"])
			if eff.modifiers.has("push"):
				push = int(eff.modifiers["push"])
	return {"trample_atk": trample_atk, "bulldoze": bulldoze, "push": push}


static func has_pass_through_effects_from(effects: Array) -> bool:
	var mods := pass_through_modifiers_from(effects)
	return int(mods.get("trample_atk", 0)) > 0 or int(mods.get("bulldoze", 0)) > 0


static func is_run_ability(ability: AbilityData) -> bool:
	return ability != null and ability.is_universal_run()


static func is_wait_ability(ability: AbilityData) -> bool:
	return ability != null and ability.is_universal_wait()


static func can_afford_run(actor: UnitState) -> bool:
	if actor == null or actor.has_run_boost():
		return false
	var run_ability: AbilityData = DataLibrary.get_universal_run()
	if run_ability == null:
		return false
	return actor.ability.points_left >= run_ability.action_point_cost


## Planning overlay: red tiles only when selected skill stays legal after implicit premove.
static func can_show_planning_action_range_after_premove(
	board: BoardState,
	actor: UnitState,
	ability: AbilityData,
	premove_cell: Vector2i,
	auto_run_active: bool,
) -> bool:
	if board == null or actor == null or ability == null:
		return false
	if is_run_ability(ability) or is_wait_ability(ability):
		return false
	if not can_plan(actor, ability):
		return false
	if premove_cell == actor.position or not board.is_in_bounds(premove_cell):
		return true
	var projected: UnitState = project_actor_after_premove(
		board, actor, premove_cell, auto_run_active,
	)
	if projected == null:
		return false
	return can_plan(projected, ability)


## Simulate a single PRE_ACTION walk/run to `premove_cell` and return the post-move unit snapshot.
static func project_actor_after_premove(
	board: BoardState,
	actor: UnitState,
	premove_cell: Vector2i,
	auto_run_active: bool,
) -> UnitState:
	if board == null or actor == null:
		return null
	if premove_cell == actor.position:
		return actor.clone()
	if not board.is_in_bounds(premove_cell):
		return null
	var needs_run: bool = movement_requires_run(board, actor, premove_cell, [])
	if needs_run and not auto_run_active:
		return null
	var trial: BoardState = board.clone()
	var trial_actor: UnitState = trial.get_unit_by_id(actor.id)
	if trial_actor == null:
		return null
	var move_action: TimelineAction
	if needs_run:
		if not can_afford_run(trial_actor):
			return null
		move_action = TimelineAction.make_run_move(
			actor.id, premove_cell, -1, [], GameEnums.MoveTiming.PRE_ACTION,
		)
	else:
		var budget: int = trial_actor.movement.points_left
		if not MovementSystem.can_reach_coord(board, trial_actor, premove_cell, [], budget):
			return null
		move_action = TimelineAction.make_move(
			actor.id, premove_cell, -1, [], GameEnums.MoveTiming.PRE_ACTION,
		)
	var plan: Timeline = Timeline.new()
	plan.entries.append(move_action)
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(trial, plan, events)
	for event: SimEvent in events:
		if event.type != GameEnums.SimEventType.ACTION_FAILED:
			continue
		if int(event.data.get("actor", -1)) == actor.id:
			return null
	var projected: UnitState = trial.get_unit_by_id(actor.id)
	return projected.clone() if projected != null else null


## Canonical planning UI AP — live sim intent, implicit premove/run, then skill scroll preview.
static func planning_display_ap_left(
	board: BoardState,
	committed_actor: UnitState,
	selected_ability: AbilityData = null,
	live_actor: UnitState = null,
	live_preview_valid: bool = false,
	move_intent_requires_run: bool = false,
	auto_run_skill_scroll: bool = false,
	auto_run_move_active: bool = false,
	intent_premove_cell: Vector2i = Vector2i(-999, -999),
) -> int:
	if committed_actor == null:
		return -1
	if live_preview_valid and live_actor != null:
		return live_actor.ability.points_left
	var ap_left: int = committed_actor.ability.points_left
	var economy_actor: UnitState = committed_actor
	if (
		move_intent_requires_run
		and auto_run_move_active
		and board != null
		and board.is_in_bounds(intent_premove_cell)
		and intent_premove_cell != committed_actor.position
	):
		var after_premove: UnitState = project_actor_after_premove(
			board, committed_actor, intent_premove_cell, true,
		)
		if after_premove != null:
			ap_left = after_premove.ability.points_left
			economy_actor = after_premove
	if selected_ability != null and not auto_run_skill_scroll:
		ap_left = maxi(
			0,
			ap_left - get_action_point_cost(economy_actor, selected_ability, board),
		)
	return ap_left


## Canonical planning UI MP — projected economy; live sim only when non-negative.
static func planning_display_mp_left(
	committed_actor: UnitState,
	live_actor: UnitState = null,
	live_preview_valid: bool = false,
) -> int:
	if committed_actor == null:
		return -1
	var committed_mp: int = committed_actor.movement.points_left
	if not live_preview_valid or live_actor == null:
		return committed_mp
	var live_mp: int = live_actor.movement.points_left
	if live_mp >= 0:
		return live_mp
	return committed_mp


## Auto-run / run-move commit: Run AP plus any paired action ability must fit the AP budget.
static func can_afford_run_for_commit(actor: UnitState, paired_ability: AbilityData = null) -> bool:
	if not can_afford_run(actor):
		return false
	if paired_ability == null or is_run_ability(paired_ability):
		return true
	if is_wait_ability(paired_ability):
		return actor.can_use_action_slot()
	if paired_ability.is_pre_move_planner():
		return true
	match paired_ability.kind:
		GameEnums.AbilityKind.CLASS_SKILL:
			var run_ability: AbilityData = DataLibrary.get_universal_run()
			if run_ability == null:
				return false
			var ap_after_run: int = actor.ability.points_left - run_ability.action_point_cost
			if ap_after_run < paired_ability.action_point_cost:
				return false
			return actor.can_use_action_slot()
	return true


## Master Bible § Universal Action Economy: Pre-Move column (walk, Run, movement skills).
static func can_plan_pre_move(unit: UnitState, move_slot_open: bool) -> bool:
	if unit == null or not move_slot_open:
		return false
	if unit.has_status(GameEnums.StatusType.ROOT) or unit.has_status(GameEnums.StatusType.STAGGER):
		return false
	return unit.movement.points_left > 0 or can_afford_run(unit)


static func is_planning_fully_exhausted(unit: UnitState, move_slot_open: bool) -> bool:
	if unit == null:
		return true
	return not unit.can_use_action_slot() and not can_plan_pre_move(unit, move_slot_open)


## Spend Run AP and apply movement extension when a PRE_MOVE walk resolves (uses_run).
static func spend_run_for_move(actor: UnitState, events: Array[SimEvent]) -> bool:
	if not can_afford_run(actor):
		return false
	var run_ability: AbilityData = DataLibrary.get_universal_run()
	if run_ability == null:
		return false
	_spend_ability_cost(actor, run_ability)
	apply_run_boost(actor, events)
	return true


static func planning_move_budget(unit: UnitState, run_mode: bool) -> int:
	if unit == null:
		return 0
	if run_mode:
		return preview_move_budget_with_run(unit)
	return unit.movement.points_left


## Planning UI: skill button enabled when the unit could commit this ability now (ignores range).
static func ability_planning_selectable(actor: UnitState, ability: AbilityData, board: BoardState = null) -> bool:
	return can_plan(actor, ability, board)


static func can_plan(actor: UnitState, ability: AbilityData, board: BoardState = null) -> bool:
	if actor == null or ability == null:
		return false
	if not _has_resource_for_ability(actor, ability):
		return false
	if actor.has_status(GameEnums.StatusType.STAGGER) or actor.has_status(GameEnums.StatusType.SILENCE):
		return false
	if actor.has_status(GameEnums.StatusType.PACIFY) and ability_uses_attack_animation(ability):
		return false
	if ability.consumes_action_slot() and not actor.can_use_action_slot():
		return false
	return true


## Deprecated: use ability.consumes_action_slot() on AbilityData.
static func consumes_action_slot(ability: AbilityData) -> bool:
	return ability != null and ability.consumes_action_slot()


static func apply_run_boost(actor: UnitState, events: Array[SimEvent]) -> void:
	_apply_running_boost(actor, events)


static func running_move_bonus(max_move: int) -> int:
	return int(floor(float(max_move) * 0.5))


static func preview_move_budget_with_run(unit: UnitState) -> int:
	if unit == null:
		return 0
	if unit.has_run_boost():
		return unit.movement.points_left
	return unit.movement.points_left + running_move_bonus(unit.movement.max_points)


static func movement_requires_run(
	board: BoardState,
	unit: UnitState,
	target_coord: Vector2i,
	waypoints: Array[Vector2i] = [],
) -> bool:
	if unit == null or unit.has_run_boost():
		return false
	var base_mp: int = unit.movement.points_left
	var run_mp: int = preview_move_budget_with_run(unit)
	var move_cost: int = MovementSystem.move_cost_for(unit)
	## Drawn path is intent: if waypoints fit walk budget, no run; if only run budget, run.
	## Do not use can_reach_coord first — it pathfinds a shorter alternate and can hide run need.
	if not waypoints.is_empty():
		if MovementSystem._is_legal_walk(board, unit.position, waypoints, base_mp, move_cost, unit, null):
			return false
		if MovementSystem._is_legal_walk(board, unit.position, waypoints, run_mp, move_cost, unit, null):
			return true
	if MovementSystem.can_reach_coord(board, unit, target_coord, waypoints, base_mp):
		return false
	return MovementSystem.can_reach_coord(board, unit, target_coord, waypoints, run_mp)


## Kept for API compatibility; dash skills no longer suppress basic movement.
static func ability_blocks_basic_movement(_ability: AbilityData) -> bool:
	return false


## Master Bible: basic walk/run may precede class Movement Skills in the pre-move column (e.g. Move → Swap).
static func planning_allows_paired_premove(ability: AbilityData) -> bool:
	if ability == null or is_run_ability(ability) or is_wait_ability(ability):
		return false
	return ability.is_movement_kind()


static func ability_uses_attack_animation(ability: AbilityData) -> bool:
	if ability == null:
		return false
	if ability.presentation_anim == GameEnums.PresentationAnim.ATTACK:
		return true
	if ability.presentation_anim in [
		GameEnums.PresentationAnim.SPELL,
		GameEnums.PresentationAnim.WALK,
		GameEnums.PresentationAnim.RUN,
		GameEnums.PresentationAnim.SUPER_RUN,
		GameEnums.PresentationAnim.NONE
	]:
		return false
	if ability.is_movement_kind() or ability.is_pre_move_kind():
		return false
	if ability.kind == GameEnums.AbilityKind.UNIVERSAL_WAIT:
		return false
	ability.ensure_targeting_flags_from_mode()
	if (
		ability.has_targeting(GameEnums.TargetingFlags.SELF)
		and not ability.has_targeting(GameEnums.TargetingFlags.ENEMY)
	):
		return false
	var offensive_effects: Array[GameEnums.EffectType] = [
		GameEnums.EffectType.DAMAGE,
		GameEnums.EffectType.PUSH,
		GameEnums.EffectType.PULL,
		GameEnums.EffectType.EXPLODE,
		GameEnums.EffectType.RANGED_EXPLODE,
	]
	for eff: EffectData in ability.effects:
		if eff.type in offensive_effects:
			return true
	for eff: EffectData in ability.upgraded_effects:
		if eff.type in offensive_effects:
			return true
	return false


static func ability_uses_spellcast_animation(ability: AbilityData) -> bool:
	if ability == null:
		return false
	if ability_has_movement_effect(ability):
		return false
	## Movement skills (Swap, Trampling Advance, etc.) use walk/thrust presentation — not spellcast.
	if ability.is_movement_kind():
		return false
	if ability.presentation_anim == GameEnums.PresentationAnim.SPELL:
		return true
	if ability.presentation_anim == GameEnums.PresentationAnim.ATTACK:
		return false
	if ability.is_pre_move_kind():
		return true
	return not ability_uses_attack_animation(ability)


## Dash skill that reads as an attack (damage, bulldoze/trample, or enemy targeting).
static func ability_is_offensive_dash(ability: AbilityData) -> bool:
	if ability == null or not ability_has_movement_effect(ability):
		return false
	if ability_uses_attack_animation(ability):
		return true
	var mods: Dictionary = pass_through_modifiers(ability)
	if int(mods.get("trample_atk", 0)) > 0 or int(mods.get("bulldoze", 0)) > 0:
		return true
	ability.ensure_targeting_flags_from_mode()
	return ability.has_targeting(GameEnums.TargetingFlags.ENEMY)

## Extra damage when striking a target from the tile behind its facing.
const BACKSTAB_BONUS: int = 2

static func execute(board: BoardState, action: TimelineAction, events: Array[SimEvent]) -> void:
	if not can_use(board, action):
		events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
			"actor": action.actor_id, "reason": "cannot_use_ability",
		}))
		return

	var actor := board.get_unit_by_id(action.actor_id)
	var ability := action.ability
	
	if actor != null:
		actor.passive_flags.erase("passed_through_terrain")
		actor.passive_flags.erase("module_gate_collided")
		
	_spend_ability_cost(actor, ability, board)
	if not actor.has_unlimited_training_actions() and ability.consumes_action_slot():
		actor.turn_action_used = true

	if DataLibrary.is_universal_wait(ability.id):
		actor.turn_action_used = true
		return

	var target_coord := _resolve_target_coord(board, action)

	var will_skill_walk := false
	if target_coord != actor.position:
		var is_move_check := effect_amount(ability, GameEnums.EffectType.MOVE) > 0
		will_skill_walk = (
			(has_pass_through_effects(ability) or is_move_check)
			and not ability_has_dash(ability)
		)

	if target_coord != actor.position and not will_skill_walk:
		var new_facing := PhysicsSystem.facing_from_vector(
			PhysicsSystem.cardinal_from_to(actor.position, target_coord),
		)
		if actor.facing != new_facing:
			actor.facing = new_facing
			events.append(SimEvent.make(GameEnums.SimEventType.UNIT_FACED, {"unit": actor.id, "facing": actor.facing}))
	var shape = action.ability.target_shape
	var shape_size = action.ability.target_shape_size
	if actor != null and actor.is_ability_upgraded(action.ability.id):
		if action.ability.upgraded_target_shape != GameEnums.TargetShape.SINGLE or action.ability.upgraded_target_shape_size != -1:
			shape = action.ability.upgraded_target_shape if action.ability.upgraded_target_shape != GameEnums.TargetShape.SINGLE else shape
			shape_size = action.ability.upgraded_target_shape_size if action.ability.upgraded_target_shape_size != -1 else shape_size
			
	var affected_tiles := GridSystem.get_affected_tiles(board, actor.position, target_coord, shape, shape_size)
	
	var pres_anim: int = action.ability.presentation_anim
	if pres_anim == GameEnums.PresentationAnim.AUTO:
		if effect_amount(action.ability, GameEnums.EffectType.DASH) > 0:
			pres_anim = GameEnums.PresentationAnim.SUPER_RUN
		elif effect_amount(action.ability, GameEnums.EffectType.BULLDOZE) > 0:
			pres_anim = GameEnums.PresentationAnim.RUN
		elif effect_amount(action.ability, GameEnums.EffectType.MOVE) > 0:
			pres_anim = GameEnums.PresentationAnim.WALK
			
	events.append(SimEvent.make(GameEnums.SimEventType.ABILITY_USED, {
		"actor": action.actor_id,
		"ability": action.ability.id,
		"ability_name": action.ability.display_name,
		"target_coord": target_coord,
		"target_unit": action.target_unit_id,
		"presentation_anim": pres_anim,
	}))
	
	var effects_to_apply = action.ability.effects
	if actor.is_ability_upgraded(action.ability.id) and action.ability.upgraded_effects.size() > 0:
		effects_to_apply = action.ability.upgraded_effects

	var cast_cc_snapshot: Dictionary = {}
	if actor != null:
		for unit in board.units:
			if unit != null and unit.is_alive():
				cast_cc_snapshot[unit.id] = (
					unit.has_status(GameEnums.StatusType.ROOT)
					or unit.has_status(GameEnums.StatusType.STAGGER)
				)
		actor.passive_flags["__cast_cc_snapshot"] = cast_cc_snapshot

	var is_move := effect_amount(ability, GameEnums.EffectType.MOVE, actor) > 0
	if (has_pass_through_effects(ability) or is_move) and not ability_has_dash(ability) and target_coord != actor.position:
		var walk_steps: int = effect_amount(ability, GameEnums.EffectType.MOVE, actor)
		if walk_steps <= 0:
			walk_steps = ability.range_tiles
			
		var has_ghost = false
		for eff in effects_to_apply:
			if eff.type == GameEnums.EffectType.MOVE and eff.modifiers.has("ghost_move"):
				has_ghost = true
				break
				
		var ghost_status = null
		if has_ghost:
			ghost_status = DataLibrary.make_status(GameEnums.StatusType.GHOST, 1, 1)
			actor.active_statuses.append(ghost_status)
			actor._recalculate_stats()
			
		MovementSystem.execute_skill_walk(
			board, actor, target_coord, action.waypoints, ability, events, effects_to_apply, walk_steps
		)
		
		if ghost_status != null:
			actor.active_statuses.erase(ghost_status)
			actor._recalculate_stats()
			
		# Recompute affected tiles after movement since actor position and facing may have changed
		affected_tiles = GridSystem.get_affected_tiles(board, actor.position, target_coord, shape, shape_size)

	var heal_per_target_hit = false
	var buff_per_object = false
	var targets_hit_count = 0
	var objects_destroyed_count = 0
	
	for eff in effects_to_apply:
		if eff.modifiers.has("heal_per_target_hit"): heal_per_target_hit = true
		if eff.modifiers.has("buff_per_destroyed_object"): buff_per_object = true
		if eff.modifiers.has("next_attack_pierce"):
			actor.passive_flags["breaching_dash_pierce"] = true
		if eff.modifiers.has("on_kill_heal_shield"):
			actor.passive_flags["adrenaline_surge_active"] = true
		if eff.modifiers.has("intercept_grant_str"):
			actor.passive_flags["meat_shield_intercept_str"] = int(eff.modifiers["intercept_grant_str"])
		if eff.modifiers.has("frenzy_on_kill_ap"):
			actor.passive_flags["frenzy_on_kill_ap"] = true

	if buff_per_object:
		for tile_coord in affected_tiles:
			var construct_unit := board.get_unit_at(tile_coord)
			if construct_unit != null and construct_unit.definition.is_construct:
				objects_destroyed_count += 1

	for effect in effects_to_apply:
		if effect.type in [GameEnums.EffectType.DASH, GameEnums.EffectType.TELEPORT_CASTER, GameEnums.EffectType.MOVE_INTO_AND_PUSH]:
			_apply_effect_to_tile(board, actor, action, effect, events, target_coord, board.get_unit_at(target_coord))
			continue
			
		if effect.modifiers.has("belly_flop_push"):
			for dir in GridSystem.DIRECTIONS:
				var adj_coord = actor.position + dir
				var adj_unit = board.get_unit_at(adj_coord)
				_apply_effect_to_tile(board, actor, action, effect, events, adj_coord, adj_unit)
			continue

		if effect.modifiers.has("damage_adjacent_on_landing"):
			for dir in GridSystem.DIRECTIONS:
				var adj_coord: Vector2i = actor.position + dir
				var adj_unit: UnitState = board.get_unit_at(adj_coord)
				if adj_unit != null and adj_unit != actor and adj_unit.is_alive() and adj_unit.team != actor.team:
					_apply_effect_to_tile(board, actor, action, effect, events, adj_coord, adj_unit)
			continue

		if effect.modifiers.has("push_board_items"):
			for tile_coord in affected_tiles:
				var item_idx: int = board.items.find(tile_coord)
				if item_idx < 0:
					continue
				var push_dir: Vector2i = PhysicsSystem.cardinal_from_to(actor.position, tile_coord)
				if push_dir == Vector2i.ZERO:
					continue
				var dest: Vector2i = tile_coord + push_dir
				if not GridSystem.is_in_bounds(board, dest) or GridSystem.is_wall(board, dest):
					continue
				var hit_unit: UnitState = board.get_unit_at(dest)
				board.items[item_idx] = dest
				if (
					hit_unit != null
					and hit_unit.is_alive()
					and hit_unit.team != actor.team
					and effect.modifiers.has("item_collision_damage")
				):
					var item_dmg: int = int(effect.modifiers["item_collision_damage"])
					CombatSystem.deal_damage(
						board, hit_unit, item_dmg, events, &"true", true, false, actor,
						action.ability.display_name, item_dmg,
					)
			
		for tile_coord in affected_tiles:
			var target_unit := board.get_unit_at(tile_coord)
			if action.target_unit_id >= 0:
				var pinned_target := board.get_unit_by_id(action.target_unit_id)
				if pinned_target != null and pinned_target.position == tile_coord:
					target_unit = pinned_target
			
			if effect.type == GameEnums.EffectType.DAMAGE and target_unit != null and target_unit != actor and target_unit.is_alive() and heal_per_target_hit:
				targets_hit_count += 1
				
			_apply_effect_to_tile(board, actor, action, effect, events, tile_coord, target_unit)
			
	if heal_per_target_hit and targets_hit_count > 0:
		CombatSystem.heal(board, actor, targets_hit_count, events)
	if buff_per_object and objects_destroyed_count > 0:
		actor.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 999, objects_destroyed_count))
		actor._recalculate_stats()

	if actor != null and actor.is_alive() and actor.has_passive(&"intercept_tactics"):
		var is_redirect = false
		for effect in effects_to_apply:
			if effect.type in [GameEnums.EffectType.ADD_STATUS, GameEnums.EffectType.ADD_STATUS_SELF] \
					and effect.status_type in [GameEnums.StatusType.INTERCEPT, GameEnums.StatusType.TAUNT]:
				is_redirect = true
				break
		if is_redirect:
			var def_bonus = 3 if actor.is_passive_upgraded(&"intercept_tactics") else 2
			actor.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, def_bonus))
			actor._recalculate_stats()
			
	if actor != null:
		actor.passive_flags.erase("__cast_cc_snapshot")

	if actor != null and actor.is_alive() and actor.has_passive(&"kinetic_redirection"):
		var is_attack = false
		for effect in effects_to_apply:
			if effect.type in [GameEnums.EffectType.DAMAGE, GameEnums.EffectType.EXPLODE, GameEnums.EffectType.RANGED_EXPLODE]:
				is_attack = true
				break
		if is_attack:
			var stacks = actor.passive_flags.get("kinetic_redirection_stacks", 0)
			if stacks > 0:
				actor.passive_flags["kinetic_redirection_stacks"] = 0
				var to_remove = []
				for status in actor.active_statuses:
					if status.type == GameEnums.StatusType.STAT_BUFF_STR and status.duration == -1:
						to_remove.append(status)
				for status in to_remove:
					actor.active_statuses.erase(status)
				actor._recalculate_stats()

	if ability.is_class_kind():
		apply_canto_move_refund(actor)


static func _spend_ability_cost(actor: UnitState, ability: AbilityData, board: BoardState = null) -> void:
	if actor == null or ability == null:
		return
		
	var ap_cost = get_action_point_cost(actor, ability, board)
	if ability.is_pre_move_planner():
		actor.movement.points_left -= movement_point_cost(actor, ability)
	elif ability.kind == GameEnums.AbilityKind.UNIVERSAL_RUN:
		actor.ability.points_left -= ap_cost
	elif ability.kind == GameEnums.AbilityKind.CLASS_SKILL:
		actor.ability.points_left -= ap_cost


static func apply_canto_move_refund(actor: UnitState) -> void:
	if actor == null:
		return
	if actor.has_passive(&"canto") or actor.has_status(GameEnums.StatusType.CANTO):
		actor.movement.points_left = actor.movement.max_points
		var has_canto_status := false
		for status: StatusData in actor.active_statuses:
			if status.type == GameEnums.StatusType.CANTO:
				has_canto_status = true
				break
		if not has_canto_status:
			actor.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.CANTO, 1, 0))
		actor._recalculate_stats()

static func _apply_effect_to_tile(board: BoardState, actor: UnitState, action: TimelineAction, effect: EffectData, events: Array[SimEvent], tile_coord: Vector2i, target: UnitState) -> void:
	if target != null and actor != target and actor != null:
		var dist = GridSystem.manhattan(actor.position, target.position)
		var is_ranged = dist > 1
		var is_aoe = action.ability.target_shape != GameEnums.TargetShape.SINGLE
		
		if is_ranged or is_aoe:
			var dir_to_target = PhysicsSystem.cardinal_from_to(actor.position, target.position)
			var front_tile = target.position - dir_to_target
			var knight = board.get_unit_at(front_tile)
			if knight != null and knight.team == target.team and knight.has_passive(&"living_barricade"):
				var dir_to_actor := PhysicsSystem.cardinal_from_to(knight.position, actor.position)
				if PhysicsSystem.facing_to_vector(knight.facing) == dir_to_actor:
					var protects_aoe = knight.is_passive_upgraded(&"living_barricade")
					if (is_ranged and not is_aoe) or (is_aoe and protects_aoe):
						events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
							"actor": actor.id, "reason": "blocked_by_living_barricade",
							"target": target.id
						}))
						return
					
	if target != null:
		var hostile := false
		var friendly := false
		if effect.type in [GameEnums.EffectType.DAMAGE, GameEnums.EffectType.PURGE, GameEnums.EffectType.PUSH, GameEnums.EffectType.PULL]:
			hostile = true
		elif effect.type in [GameEnums.EffectType.HEAL, GameEnums.EffectType.ARMOR_UP, GameEnums.EffectType.CLEANSE]:
			friendly = true
		elif effect.type == GameEnums.EffectType.ADD_STATUS:
			if GameEnums.is_buff(effect.status_type):
				friendly = true
			elif GameEnums.is_debuff(effect.status_type):
				hostile = true
				
		if target == actor:
			if effect.modifiers.get("exclude_caster", false):
				return
			if not friendly and not effect.type in [GameEnums.EffectType.ADD_STATUS_SELF, GameEnums.EffectType.DAMAGE_SELF, GameEnums.EffectType.TELEPORT_CASTER, GameEnums.EffectType.MOVE_INTO_AND_PUSH]:
				return
		elif actor != null:
			if hostile and target.team == actor.team:
				return
			if friendly and target.team != actor.team:
				return

	match effect.type:
		GameEnums.EffectType.DAMAGE:
			var pierce = false
			if actor.has_passive(&"kinetic_redirection") and actor.is_passive_upgraded(&"kinetic_redirection"):
				if actor.passive_flags.get("kinetic_redirection_stacks", 0) > 0:
					pierce = true
					
			var base_amt := effect.amount
			
			if effect.modifiers.has("bonus_dmg_per_10_hp"):
				base_amt += floori(actor.health.current_hp / 10.0) * effect.modifiers["bonus_dmg_per_10_hp"]
			if effect.modifiers.has("bonus_dmg_pct_max_hp"):
				base_amt += floori(actor.health.max_hp * float(effect.modifiers["bonus_dmg_pct_max_hp"]))
			if effect.modifiers.has("bonus_dmg_from_terrain") and actor.passive_flags.get("passed_through_terrain", false):
				base_amt += effect.modifiers["bonus_dmg_from_terrain"]
				
			if actor.has_passive(&"blood_for_blood") and actor.is_passive_upgraded(&"blood_for_blood") and actor.passive_flags.get("damaged_last_turn", false):
				base_amt += 1
				
			var amount := base_amt
			
			var wpn := 0
			if actor.definition != null and actor.definition.equipped_weapon != null:
				wpn = actor.definition.equipped_weapon.might
			
			var stat_val := actor.current_strength
			var stat_name := "STR"
			
			if action.ability.scaling_stat == GameEnums.StatType.PHYSICAL:
				stat_val = CombatSystem.get_dynamic_strength(board, actor)
			elif action.ability.scaling_stat == GameEnums.StatType.MAGICAL:
				stat_val = actor.current_magic
				stat_name = "MAG"
				
			if base_amt > 0:
				var raw = (base_amt + wpn) * (1.0 + stat_val / 5.0)
				amount = floori(raw)
				
			var dmg_type = &"physical"
			if action.ability.scaling_stat == GameEnums.StatType.MAGICAL:
				dmg_type = &"magical"
				
			var vuln = false
			var elec = false
			var backstabbed = false
			var target_def = 0
			var fort = 0
			
			var temp_def_debuff = null
			if target != null and effect.bonus_if_adjacent_at_cast > 0:
				if GridSystem.manhattan(actor.position, target.position) == 1:
					base_amt += effect.bonus_if_adjacent_at_cast
			if target != null and effect.def_debuff_before_damage > 0:
				temp_def_debuff = DataLibrary.make_status(
					GameEnums.StatusType.STAT_DEBUFF_DEF, 1, effect.def_debuff_before_damage,
				)
				target.active_statuses.append(temp_def_debuff)
				target._recalculate_stats()
				events.append(SimEvent.make(GameEnums.SimEventType.STATUS_APPLIED, {
					"unit": target.id,
					"status_type": GameEnums.StatusType.STAT_DEBUFF_DEF,
					"duration": 1,
					"amount": effect.def_debuff_before_damage,
					"temporary": true,
				}))
			
			if target != null:
				if _is_backstab(actor, target):
					amount += BACKSTAB_BONUS
					backstabbed = true
				target_def = CombatSystem.get_dynamic_defense(board, target)
				var tile = board.get_tile(target.position)
				if tile != null and tile.definition != null:
					fort = tile.definition.fortitude
				vuln = target.has_status(GameEnums.StatusType.VULNERABLE)
				elec = target.has_status(GameEnums.StatusType.ELECTRIFIED)

			if actor.passive_flags.has("breaching_dash_pierce"):
				pierce = true
				actor.passive_flags.erase("breaching_dash_pierce")
			if actor.has_status(GameEnums.StatusType.PIERCE):
				pierce = true
			if target != null and actor.has_passive(&"overwhelming_bulk"):
				if actor.health.current_hp > target.health.max_hp:
					pierce = true
					if actor.is_passive_upgraded(&"overwhelming_bulk"):
						var bulk_dir := PhysicsSystem.cardinal_from_to(actor.position, target.position)
						board.pending_pushes.append({
							"type": "push",
							"target_id": target.id,
							"dir": bulk_dir,
							"amount": 1,
							"actor_id": actor.id,
							"ability_id": &"overwhelming_bulk",
						})
				
			events.append(SimEvent.make(GameEnums.SimEventType.MATH_TELEMETRY, {
				"type": "damage",
				"base": base_amt,
				"wpn": wpn,
				"stat_name": stat_name,
				"stat_val": stat_val,
				"multiplier_raw": (base_amt + wpn) * (1.0 + stat_val / 5.0),
				"floored": floori((base_amt + wpn) * (1.0 + stat_val / 5.0)),
				"backstab": backstabbed,
				"backstab_bonus": BACKSTAB_BONUS if backstabbed else 0,
				"final_raw": amount,
				"target_def": target_def, "fortitude": fort,
				"vulnerable": vuln, "electrified": elec,
				"pierce": pierce
			}))
			CombatSystem.deal_damage(board, target, amount, events, dmg_type, pierce, false, actor, action.ability.display_name)
			if temp_def_debuff != null and target != null:
				target.active_statuses.erase(temp_def_debuff)
				target._recalculate_stats()
		GameEnums.EffectType.PUSH:
			if target != null:
				var is_immune = false
				if target.has_status(GameEnums.StatusType.INVULNERABLE) or (not target.has_status(GameEnums.StatusType.VULNERABLE) and target.has_status(GameEnums.StatusType.STURDY)):
					is_immune = true
				if target.has_passive(&"stand_ground") and not target.has_status(GameEnums.StatusType.VULNERABLE):
					is_immune = true
					if actor != null and actor.team != target.team:
						var stand_amt := 2 if target.is_passive_upgraded(&"stand_ground") else 1
						CombatSystem.counter_attack(board, target, actor, stand_amt, events, "Stand Ground")
				
				if not is_immune:
					var dir := PhysicsSystem.cardinal_from_to(actor.position, target.position)
					
					var pending := {
						"type": "push",
						"target_id": target.id,
						"dir": dir,
						"amount": effect.amount,
						"actor_id": actor.id,
						"ability_id": action.ability.id
					}
					
					if AbilitySystem.effect_amount(action.ability, GameEnums.EffectType.PUSH_STAGGER_ON_COLLISION, actor) > 0:
						pending["stagger_on_collision"] = true
						
					if AbilitySystem.effect_amount(action.ability, GameEnums.EffectType.PUSH_CHAIN_COLLISION, actor) > 0:
						pending["bowling_upgrade"] = true
					
					board.pending_pushes.append(pending)
		GameEnums.EffectType.PULL:
			if target != null:
				var is_immune := false
				if target.has_passive(&"stand_ground") and not target.has_status(GameEnums.StatusType.VULNERABLE):
					is_immune = true
					if actor != null and actor.team != target.team:
						var stand_amt := 2 if target.is_passive_upgraded(&"stand_ground") else 1
						CombatSystem.counter_attack(board, target, actor, stand_amt, events, "Stand Ground")
				for dir in GridSystem.DIRECTIONS:
					var adj_unit = board.get_unit_at(target.position + dir)
					if adj_unit != null and adj_unit.team == target.team and adj_unit.has_passive(&"shield_wall"):
						is_immune = true
						break
				if not is_immune:
					for x in range(-2, 3):
						for y in range(-2, 3):
							if abs(x) + abs(y) == 2:
								var adj = target.position + Vector2i(x, y)
								var adj_unit = board.get_unit_at(adj)
								if adj_unit != null and adj_unit.team == target.team and adj_unit.has_passive(&"shield_wall") and adj_unit.is_passive_upgraded(&"shield_wall"):
									is_immune = true
									break
						if is_immune: break
				if not is_immune:
					var dir := PhysicsSystem.cardinal_from_to(target.position, actor.position)
					
					var pending := {
						"type": "pull",
						"target_id": target.id,
						"dir": dir,
						"amount": effect.amount,
						"actor_id": actor.id,
						"ability_id": action.ability.id
					}
					
					if AbilitySystem.effect_amount(action.ability, GameEnums.EffectType.PULL_VULNERABLE_ON_ADJACENT, actor) > 0:
						pending["vulnerable_on_adjacent"] = true
						
					board.pending_pushes.append(pending)
		GameEnums.EffectType.SWAP:
			if target != null:
				PhysicsSystem.swap(board, actor, target, events)
		GameEnums.EffectType.MOVE_INTO_AND_PUSH:
			if target != null:
				var is_immune := false
				if target.has_passive(&"stand_ground") and not target.has_status(GameEnums.StatusType.VULNERABLE):
					is_immune = true
				if not is_immune:
					var dir := PhysicsSystem.cardinal_from_to(actor.position, target.position)
					var pending := {
						"type": "push",
						"target_id": target.id,
						"dir": dir,
						"amount": effect.amount,
						"actor_id": actor.id,
						"ability_id": action.ability.id,
						"follow_up_move_actor": true
					}
					board.pending_pushes.append(pending)
		GameEnums.EffectType.THROW_BEHIND:
			if target != null:
				var dir := PhysicsSystem.cardinal_from_to(target.position, actor.position)
				var behind_coord = actor.position + dir
				if not GridSystem.is_occupied(board, behind_coord) and not GridSystem.is_wall(board, behind_coord):
					GridSystem.set_occupant(board, target.position, -1)
					target.position = behind_coord
					GridSystem.set_occupant(board, target.position, target.id)
					events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
						"unit": target.id, "to": target.position
					}))
		GameEnums.EffectType.HEAL:
			if target != null:
				var heal_amount := effect.amount
				if action.ability.scaling_stat == GameEnums.StatType.MAGICAL:
					var wpn := 0
					if actor.definition != null and actor.definition.equipped_weapon != null:
						wpn = actor.definition.equipped_weapon.might
					var raw = (effect.amount + wpn) * (1.0 + actor.current_magic / 5.0) * 0.20 + (target.health.max_hp * 0.20)
					heal_amount = floori(raw)
				elif effect.scaling_stat == GameEnums.StatType.MAX_HP:
					var raw = effect.amount * 0.1 * target.health.max_hp
					heal_amount = floori(raw)
				CombatSystem.heal(board, target, heal_amount, events)
		GameEnums.EffectType.ARMOR_UP:
			if target != null:
				var shield_amount = effect.amount
				if effect.scaling_stat == GameEnums.StatType.MAX_HP:
					shield_amount = floori(effect.amount * 0.1 * target.health.max_hp)
				elif effect.scaling_stat == GameEnums.StatType.DEFENSE:
					shield_amount = floori(effect.amount + actor.current_defense)
				elif effect.scaling_stat == GameEnums.StatType.MISSING_HP:
					shield_amount = floori(effect.amount + (actor.health.max_hp - actor.health.current_hp))
				var old_armor = target.armor
				target.armor += shield_amount
				if target.armor > old_armor:
					events.append(SimEvent.make(GameEnums.SimEventType.UNIT_ARMORED, {
						"unit": target.id,
						"amount": shield_amount,
						"armor": target.armor,
					}))
		GameEnums.EffectType.EXPLODE:
			# AoE self-destruct: damage ALL adjacent units (friend and foe) + actor.
			var center := tile_coord
			events.append(SimEvent.make(GameEnums.SimEventType.UNIT_EXPLODED, {
				"actor": actor.id, "coord": center, "damage": effect.amount,
			}))
			for dir in GridSystem.DIRECTIONS:
				var adj := center + dir
				var adj_unit := board.get_unit_at(adj)
				if adj_unit != null and adj_unit.is_alive():
					var dmg_type = &"physical" if action.ability.scaling_stat == GameEnums.StatType.PHYSICAL else &"magical"
					CombatSystem.deal_damage(
						board, adj_unit, effect.amount, events, dmg_type, false, false, actor,
						action.ability.display_name, effect.amount
					)
			# Self-destruct: kill the bomber.
			CombatSystem.deal_damage(
				board, actor, actor.health.current_hp, events, &"physical", false, false, actor,
				action.ability.display_name, actor.health.current_hp
			)
		GameEnums.EffectType.RANGED_EXPLODE:
			# AoE explosion without self-destruct: damage target coordinate and all adjacent tiles.
			var center := tile_coord
			events.append(SimEvent.make(GameEnums.SimEventType.UNIT_EXPLODED, {
				"actor": actor.id, "coord": center, "damage": effect.amount,
			}))
			var target_unit := board.get_unit_at(center)
			var dmg_type = &"physical" if action.ability.scaling_stat == GameEnums.StatType.PHYSICAL else &"magical"
			if target_unit != null and target_unit.is_alive():
				CombatSystem.deal_damage(
					board, target_unit, effect.amount, events, dmg_type, false, false, actor,
					action.ability.display_name, effect.amount
				)
			for dir in GridSystem.DIRECTIONS:
				var adj := center + dir
				var adj_unit := board.get_unit_at(adj)
				if adj_unit != null and adj_unit.is_alive():
					CombatSystem.deal_damage(
						board, adj_unit, effect.amount, events, dmg_type, false, false, actor,
						action.ability.display_name, effect.amount
					)
		GameEnums.EffectType.SPAWN:
			var coord := tile_coord
			if effect.spawn_unit_id != &"":
				if GridSystem.is_occupied(board, coord) or not GridSystem.is_passable(board, coord):
					events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
						"actor": actor.id, "reason": "spawn_blocked",
					}))
					return
				var construct_def := DataLibrary.get_unit(effect.spawn_unit_id)
				if construct_def == null:
					events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
						"actor": actor.id, "reason": "unknown_spawn_id",
					}))
					return
				var construct_id := board.next_unit_id()
				var construct := UnitState.create(construct_id, construct_def, actor.team, coord)
				if construct_def.is_construct:
					var scaled_hp := floori(actor.health.max_hp * (construct_def.construct_scaling_percent / 100.0))
					construct.health.max_hp = maxi(1, scaled_hp)
					construct.health.current_hp = construct.health.max_hp
					construct.active_statuses.append(StatusData.new(GameEnums.StatusType.STURDY, 999, 0))
					construct._recalculate_stats()
				board.add_unit(construct)
				GridSystem.set_occupant(board, coord, construct_id)
				events.append(SimEvent.make(GameEnums.SimEventType.UNIT_SPAWNED, {
					"actor": actor.id,
					"unit": construct_id,
					"coord": coord,
				}))
			else:
				# Summoner: create a minion at target_coord from behavior.spawn_unit.
				if actor.definition == null or actor.definition.behavior == null:
					return
				var spawn_def := actor.definition.behavior.spawn_unit
				if spawn_def == null:
					return
				if not GridSystem.is_in_bounds(board, coord) or GridSystem.is_occupied(board, coord):
					return
				var cap := actor.definition.behavior.max_spawns
				if cap > 0 and board.count_living_by_definition(spawn_def) >= cap:
					return
				var new_id := board.next_unit_id()
				var spawned := UnitState.create(new_id, spawn_def, actor.team, coord)
				board.add_unit(spawned)
				GridSystem.set_occupant(board, coord, new_id)
				events.append(SimEvent.make(GameEnums.SimEventType.UNIT_SPAWNED, {
					"spawner": actor.id, "unit": new_id,
					"definition": spawn_def.id, "coord": coord,
				}))
		GameEnums.EffectType.ADD_STATUS:
			if target != null:
				if target.has_status(GameEnums.StatusType.INVULNERABLE) and GameEnums.is_debuff(effect.status_type):
					events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
						"actor": target.id, "reason": "status_prevented_by_invulnerable",
					}))
					return
					
				if target.is_boss() and GameEnums.is_debuff(effect.status_type) and effect.status_type in [GameEnums.StatusType.STAGGER, GameEnums.StatusType.ROOT, GameEnums.StatusType.SILENCE, GameEnums.StatusType.PACIFY, GameEnums.StatusType.FEAR, GameEnums.StatusType.CONFUSION, GameEnums.StatusType.POLYMORPH, GameEnums.StatusType.TAUNT]:
					events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
						"actor": target.id, "reason": "boss_immune_to_cc",
					}))
					return
					
				if CombatSystem.try_resist_crowd_control(target, effect.status_type, events):
					return
					
				var stat_val = effect.amount
				if effect.modifiers.has("weapon_scaled"):
					if actor.definition != null and actor.definition.equipped_weapon != null:
						stat_val = actor.definition.equipped_weapon.might
				if effect.scaling_stat == GameEnums.StatType.DEFENSE:
					stat_val = effect.amount + actor.current_defense
				var status := StatusData.new(effect.status_type, effect.status_duration, stat_val)
				target.active_statuses.append(status)
				target._recalculate_stats()
				events.append(SimEvent.make(GameEnums.SimEventType.STATUS_APPLIED, {
					"unit": target.id,
					"status_type": effect.status_type,
					"duration": effect.status_duration,
					"amount": effect.amount,
				}))
		GameEnums.EffectType.CLEANSE:
			if target != null:
				var new_statuses: Array[StatusData] = []
				for status in target.active_statuses:
					if not GameEnums.is_debuff(status.type):
						new_statuses.append(status)
				target.active_statuses = new_statuses
				target._recalculate_stats()
				events.append(SimEvent.make(GameEnums.SimEventType.STATUS_REMOVED, {
					"unit": target.id, "reason": "cleanse"
				}))
		GameEnums.EffectType.PURGE:
			if target != null:
				for i in range(target.active_statuses.size() - 1, -1, -1):
					if GameEnums.is_buff(target.active_statuses[i].type):
						var removed = target.active_statuses.pop_at(i)
						events.append(SimEvent.make(GameEnums.SimEventType.STATUS_REMOVED, {
							"unit": target.id, "status_type": removed.type
						}))
				target.armor = 0
				target._recalculate_stats()
		GameEnums.EffectType.DASH:
			var dir := PhysicsSystem.straight_line_dir(actor.position, action.target_coord)
			var dash_steps := PhysicsSystem.straight_line_distance(actor.position, action.target_coord)
			if dir != Vector2i.ZERO and dash_steps >= 1 and dash_steps <= effect.amount:
				var pending = {
					"type": "dash",
					"target_id": actor.id,
					"dir": dir,
					"amount": dash_steps,
					"actor_id": actor.id,
					"ability_id": action.ability.id
				}
				var mods := pass_through_modifiers(action.ability, actor)
				var trample_atk: int = int(mods.get("trample_atk", 0))
				var bulldoze: int = int(mods.get("bulldoze", 0))
				var push_amt: int = int(mods.get("push", 0))
				if trample_atk > 0:
					pending["trample_atk"] = trample_atk
				if push_amt > 0:
					pending["trample_push"] = push_amt
				if bulldoze > 0:
					pending["bulldoze"] = bulldoze
					pending["caster_collision_immune"] = true
				if AbilitySystem.effect_amount(action.ability, GameEnums.EffectType.PUSH_CHAIN_COLLISION) > 0:
					pending["bowling_upgrade"] = true
				if not action.module_coords.is_empty():
					pending["module_coords"] = action.module_coords.duplicate()
				board.pending_pushes.append(pending)
		GameEnums.EffectType.TRAMPLE, GameEnums.EffectType.BULLDOZE:
			# Movement modifiers — applied during dash or execute_pass_through_walk, not per-tile.
			pass
		GameEnums.EffectType.DESTROY_OBSTACLE:
			if target != null and target.definition.is_construct:
				CombatSystem.deal_damage(
					board, target, target.health.current_hp, events, &"physical", false, false, actor,
					action.ability.display_name, target.health.current_hp
				)
		GameEnums.EffectType.TELEPORT_CASTER:
			if not GridSystem.is_occupied(board, tile_coord) and not GridSystem.is_wall(board, tile_coord):
				GridSystem.set_occupant(board, actor.position, -1)
				actor.position = tile_coord
				GridSystem.set_occupant(board, actor.position, actor.id)
				events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
					"unit": actor.id, "to": actor.position
				}))
		GameEnums.EffectType.CHANGE_TERRAIN:
			# Amount parameter can be used to select terrain type, for now just hardcode cracked
			var terrain_id = &"cracked"
			var tile = board.get_tile(tile_coord)
			if tile != null:
				var new_def = DataLibrary.get_terrain(terrain_id)
				if new_def != null:
					tile.definition = new_def
					events.append(SimEvent.make(GameEnums.SimEventType.TERRAIN_CHANGED, {
						"coord": tile_coord, "terrain": terrain_id
					}))
		GameEnums.EffectType.REFUND_AP_ON_CC:
			if target != null and actor != null:
				var snap: Variant = actor.passive_flags.get("__cast_cc_snapshot", null)
				var had_cc_at_cast: bool = snap is Dictionary and snap.get(target.id, false)
				if had_cc_at_cast:
					actor.ability.points_left = mini(actor.ability.max_points, actor.ability.points_left + 1)

		GameEnums.EffectType.ADD_STATUS_SELF:
			if actor.has_status(GameEnums.StatusType.INVULNERABLE) and GameEnums.is_debuff(effect.status_type):
				events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
					"actor": actor.id, "reason": "status_prevented_by_invulnerable",
				}))
				return
			if effect.status_type == GameEnums.StatusType.RUNNING:
				_apply_running_boost(actor, events)
				return
			var status := StatusData.new(effect.status_type, effect.status_duration, effect.amount)
			actor.active_statuses.append(status)
			actor._recalculate_stats()
			events.append(SimEvent.make(GameEnums.SimEventType.STATUS_APPLIED, {
				"unit": actor.id,
				"status_type": effect.status_type,
				"duration": effect.status_duration,
				"amount": effect.amount,
			}))
		GameEnums.EffectType.DAMAGE_SELF:
			CombatSystem.deal_damage(
				board, actor, effect.amount, events, &"true", true, false, actor,
				"%s (self)" % action.ability.display_name, effect.amount
			)

static func _apply_running_boost(actor: UnitState, events: Array[SimEvent]) -> void:
	if actor.has_run_boost():
		return
	var bonus: int = running_move_bonus(actor.movement.max_points)
	if bonus <= 0:
		return
	actor.apply_run_boost(bonus)
	events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
		"actor": actor.id,
		"run_boost": true,
		"bonus": bonus,
	}))


static func _resolve_target(board: BoardState, action: TimelineAction) -> UnitState:
	if action.target_unit_id >= 0:
		return board.get_unit_by_id(action.target_unit_id)
	return board.get_unit_at(action.target_coord)

static func _resolve_target_coord(board: BoardState, action: TimelineAction) -> Vector2i:
	if action.target_unit_id >= 0:
		var target = board.get_unit_by_id(action.target_unit_id)
		if target != null:
			return target.position
	if action.has_module_coord(0):
		return action.get_module_coord(0)
	return action.target_coord

## True when the attacker stands on the tile directly behind the target's facing.
static func _is_backstab(actor: UnitState, target: UnitState) -> bool:
	var behind := -PhysicsSystem.facing_to_vector(target.facing)
	return PhysicsSystem.cardinal_from_to(target.position, actor.position) == behind


static func _execute_gated_module_followups(
	board: BoardState,
	actor: UnitState,
	ability: AbilityData,
	module_coords: Array,
	events: Array[SimEvent],
) -> void:
	if actor == null or ability == null or not actor.is_alive():
		return
	var collided: bool = actor.passive_flags.get("module_gate_collided", false)
	actor.passive_flags.erase("module_gate_collided")
	var modules: Array = modules_for_actor(actor, ability)
	for i: int in range(modules.size()):
		var mod: AbilityModule = modules[i]
		if mod == null or mod.gate != GameEnums.ModuleGate.IF_COLLIDED:
			continue
		if not evaluate_module_gate(GameEnums.ModuleGate.IF_COLLIDED, collided):
			return
		var has_coord: bool = (
			i < module_coords.size()
			and module_coords[i] is Vector2i
			and module_coords[i] != TimelineAction.MODULE_COORD_UNSET
		)
		if not has_coord:
			events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
				"actor": actor.id,
				"reason": "gated_followup_missing_aim",
				"module_index": i,
			}))
			return
		var dest: Vector2i = module_coords[i]
		if not planning_is_valid_module_endpoint(
			board, actor.position, dest, ability, actor, i,
		):
			events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
				"actor": actor.id,
				"reason": "gated_followup_invalid_dest",
				"module_index": i,
			}))
			return
		var move_effect: EffectData = mod.primary_as_effect()
		var walk_steps: int = mod.max_range if mod.max_range > 0 else mod.amount
		MovementSystem.execute_skill_walk(
			board, actor, dest, [], ability, events, [move_effect], walk_steps,
		)
		return


static func resolve_pending_pushes(board: BoardState, events: Array[SimEvent]) -> void:
	var pending = board.pending_pushes.duplicate()
	board.pending_pushes.clear()
	
	for push in pending:
		var target = board.get_unit_by_id(push.target_id)
		var actor = board.get_unit_by_id(push.actor_id) if push.has("actor_id") else null
		var ability_id = push.ability_id
		var push_type = push.get("type", "push")
		
		if target == null or not target.is_alive():
			continue
			
		var push_ev_start = events.size()
		var old_pos = target.position
		if push_type == "dash":
			PhysicsSystem.dash(
				board, target, push.dir, push.amount, events, actor, ability_id,
				int(push.get("trample_atk", 0)),
				String(push.get("source_label", "")),
				int(push.get("bulldoze", 0)),
				push.get("caster_collision_immune", false),
			)
		else:
			PhysicsSystem.push(board, target, push.dir, push.amount, events, actor, ability_id)
		
		if push.get("follow_up_move_actor", false) and actor != null and actor.is_alive():
			if target.position != old_pos:
				GridSystem.set_occupant(board, actor.position, -1)
				actor.position = old_pos
				GridSystem.set_occupant(board, actor.position, actor.id)
				events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
					"unit": actor.id, "to": actor.position
				}))
		
		if push_type == "push" or push_type == "pull":
			if push.get("stagger_on_collision", false):
				for i in range(push_ev_start, events.size()):
					var ev = events[i]
					if ev.type == GameEnums.SimEventType.COLLISION and ev.data.get("unit") == target.id:
						if not CombatSystem.try_resist_crowd_control(target, GameEnums.StatusType.STAGGER, events):
							target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAGGER, 1))
							target._recalculate_stats()
						break
			
			if push.get("vulnerable_on_adjacent", false) and actor != null:
				if GridSystem.manhattan(actor.position, target.position) == 1:
					target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.VULNERABLE, 1))
					target._recalculate_stats()
					
		elif push_type == "dash":
			var ability := actor.get_ability_by_id(ability_id) if actor != null and ability_id != &"" else null
			if ability != null and AbilitySystem.effect_amount(ability, GameEnums.EffectType.PUSH_CHAIN_COLLISION) > 0 and push.get("bowling_upgrade", false):
				for i in range(push_ev_start, events.size()):
					var ev = events[i]
					if ev.type != GameEnums.SimEventType.COLLISION:
						continue
					var pushed_id: int = ev.data.get("unit", -1)
					if pushed_id == -1 or not ev.data.has("against_unit"):
						continue
					var pushed_unit := board.get_unit_by_id(pushed_id)
					var chain_hit := board.get_unit_by_id(ev.data.get("against_unit"))
					if pushed_unit != null and chain_hit != null and chain_hit.team != target.team:
						var chain_dmg := CombatSystem.calculate_scaled_damage(
							target, 2, GameEnums.StatType.PHYSICAL, board
						)
						CombatSystem.deal_damage_raw(
							board, target, pushed_unit, chain_dmg, GameEnums.StatType.PHYSICAL, events, "Bowling Charge", 2
						)
						CombatSystem.deal_damage_raw(
							board, target, chain_hit, chain_dmg, GameEnums.StatType.PHYSICAL, events, "Bowling Charge", 2
						)
			if push.has("module_coords"):
				var module_coords: Array = push["module_coords"]
				_execute_gated_module_followups(
					board, actor, ability, module_coords, events,
				)
