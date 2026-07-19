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
	if dist > actor.get_ability_range(ability):
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

	if actor.has_status(GameEnums.StatusType.STUN) or actor.has_status(GameEnums.StatusType.SILENCE):
		return false

	if actor.has_status(GameEnums.StatusType.PACIFY) and ability_uses_attack_animation(ability):
		for effect in ability.effects:
			if effect.type == GameEnums.EffectType.DAMAGE or effect.type == GameEnums.EffectType.EXPLODE or effect.type == GameEnums.EffectType.RANGED_EXPLODE:
				return false

	if ability.consumes_action_slot() and not actor.can_use_action_slot():
		return false

	for effect in ability.effects:
		if effect.type == GameEnums.EffectType.DASH:
			if PhysicsSystem.straight_line_dir(actor.position, action.target_coord) == Vector2i.ZERO:
				return false
			var steps := PhysicsSystem.straight_line_distance(actor.position, action.target_coord)
			if steps < 1 or steps > effect.amount:
				return false
			if effect_amount(ability, GameEnums.EffectType.TRAMPLE) > 0:
				var end_unit := board.get_unit_at(action.target_coord)
				if end_unit != null and end_unit.id != actor.id:
					return false

	if has_pass_through_effects(ability) and not ability_has_dash(ability):
		if effect_amount(ability, GameEnums.EffectType.TRAMPLE) > 0:
			var end_occupant := board.get_unit_at(action.target_coord)
			if end_occupant != null and end_occupant.id != actor.id:
				return false
		if action.target_coord != actor.position:
			var walk_steps: int = ability.range_tiles
			if GridSystem.manhattan(actor.position, action.target_coord) > walk_steps:
				return false

	return true


static func _has_resource_for_ability(actor: UnitState, ability: AbilityData) -> bool:
	if ability == null or actor == null:
		return false
	match ability.kind:
		GameEnums.AbilityKind.MOVEMENT_SKILL:
			return actor.movement.points_left >= ability.movement_point_cost
		GameEnums.AbilityKind.UNIVERSAL_RUN:
			if actor.has_run_boost():
				return false
			return actor.ability.points_left >= ability.action_point_cost
		GameEnums.AbilityKind.CLASS_SKILL:
			return actor.ability.points_left >= ability.action_point_cost
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
		if target.id == actor.id:
			return ability.has_targeting(GameEnums.TargetingFlags.SELF)
		if target.team == actor.team:
			return ability.has_targeting(GameEnums.TargetingFlags.ALLY)
		return ability.has_targeting(GameEnums.TargetingFlags.ENEMY)
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


static func effect_amount(ability: AbilityData, effect_type: GameEnums.EffectType) -> int:
	if ability == null:
		return 0
	for eff in ability.effects:
		if eff.type == effect_type:
			return eff.amount
	return 0


static func has_pass_through_effects(ability: AbilityData) -> bool:
	return effect_amount(ability, GameEnums.EffectType.TRAMPLE) > 0 \
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
	for eff: EffectData in effects:
		if eff.type == GameEnums.EffectType.TRAMPLE:
			trample_atk = eff.amount
		elif eff.type == GameEnums.EffectType.BULLDOZE:
			bulldoze = eff.amount
	return {"trample_atk": trample_atk, "bulldoze": bulldoze}


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


## Auto-run / run-move commit: Run AP plus any paired action ability must fit the AP budget.
static func can_afford_run_for_commit(actor: UnitState, paired_ability: AbilityData = null) -> bool:
	if not can_afford_run(actor):
		return false
	if paired_ability == null or is_run_ability(paired_ability):
		return true
	if is_wait_ability(paired_ability):
		return actor.can_use_action_slot()
	match paired_ability.kind:
		GameEnums.AbilityKind.MOVEMENT_SKILL:
			return true
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
	if unit.has_status(GameEnums.StatusType.ROOT) or unit.has_status(GameEnums.StatusType.STUN):
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
static func ability_planning_selectable(actor: UnitState, ability: AbilityData) -> bool:
	return can_plan(actor, ability)


static func can_plan(actor: UnitState, ability: AbilityData) -> bool:
	if actor == null or ability == null:
		return false
	if not _has_resource_for_ability(actor, ability):
		return false
	if actor.has_status(GameEnums.StatusType.STUN) or actor.has_status(GameEnums.StatusType.SILENCE):
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
	if MovementSystem.can_reach_coord(board, unit, target_coord, waypoints, base_mp):
		return false
	return MovementSystem.can_reach_coord(
		board, unit, target_coord, waypoints, preview_move_budget_with_run(unit),
	)


## Kept for API compatibility; dash skills no longer suppress basic movement.
static func ability_blocks_basic_movement(_ability: AbilityData) -> bool:
	return false


static func ability_uses_attack_animation(ability: AbilityData) -> bool:
	if ability == null:
		return false
	if ability.presentation_anim == GameEnums.PresentationAnim.ATTACK:
		return true
	if ability.presentation_anim in [GameEnums.PresentationAnim.SPELL, GameEnums.PresentationAnim.MOVE, GameEnums.PresentationAnim.NONE]:
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
	if ability.presentation_anim == GameEnums.PresentationAnim.SPELL:
		return true
	if ability.presentation_anim == GameEnums.PresentationAnim.ATTACK:
		return false
	if ability.is_pre_move_kind():
		return true
	return not ability_uses_attack_animation(ability)


## Dash skill that reads as an attack (damage, bulldoze/trample, or enemy targeting).
static func ability_is_offensive_dash(ability: AbilityData) -> bool:
	if ability == null or not ability_has_dash(ability):
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
	_spend_ability_cost(actor, ability)
	if not actor.has_unlimited_training_actions() and ability.consumes_action_slot():
		actor.turn_action_used = true

	if DataLibrary.is_universal_wait(ability.id):
		actor.turn_action_used = true
		return

	var target_coord := _resolve_target_coord(board, action)

	if target_coord != actor.position:
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
	
	events.append(SimEvent.make(GameEnums.SimEventType.ABILITY_USED, {
		"actor": action.actor_id,
		"ability": action.ability.id,
		"ability_name": action.ability.display_name,
		"target_coord": target_coord,
		"target_unit": action.target_unit_id,
		"is_dash": ability_has_dash(action.ability),
	}))
	
	var effects_to_apply = action.ability.effects
	if actor.is_ability_upgraded(action.ability.id) and action.ability.upgraded_effects.size() > 0:
		effects_to_apply = action.ability.upgraded_effects

	if has_pass_through_effects(ability) and not ability_has_dash(ability) and target_coord != actor.position:
		MovementSystem.execute_pass_through_walk(
			board, actor, target_coord, action.waypoints, ability, events, effects_to_apply
		)

	for effect in effects_to_apply:
		if effect.type in [GameEnums.EffectType.DASH, GameEnums.EffectType.TELEPORT_CASTER]:
			_apply_effect_to_tile(board, actor, action, effect, events, target_coord, board.get_unit_at(target_coord))
			continue
		for tile_coord in affected_tiles:
			var target_unit := board.get_unit_at(tile_coord)
			_apply_effect_to_tile(board, actor, action, effect, events, tile_coord, target_unit)

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


static func _spend_ability_cost(actor: UnitState, ability: AbilityData) -> void:
	if actor == null or ability == null:
		return
	match ability.kind:
		GameEnums.AbilityKind.MOVEMENT_SKILL:
			actor.movement.points_left -= ability.movement_point_cost
		GameEnums.AbilityKind.UNIVERSAL_RUN:
			actor.ability.points_left -= ability.action_point_cost
		GameEnums.AbilityKind.CLASS_SKILL:
			actor.ability.points_left -= ability.action_point_cost
		_:
			pass


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
			if not friendly and not effect.type in [GameEnums.EffectType.ADD_STATUS_SELF, GameEnums.EffectType.DAMAGE_SELF, GameEnums.EffectType.TELEPORT_CASTER]:
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
			CombatSystem.deal_damage(board, target, amount, events, dmg_type, pierce, false, null, action.ability.display_name)
			
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
				
				if action.ability.id == &"knight_defensive_formation":
					for status in target.active_statuses:
						if status.type == GameEnums.StatusType.STURDY:
							if status.duration == 1:
								is_immune = true
								break
				
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
					
					if action.ability.id == &"knight_shield_bash" and actor.is_ability_upgraded(&"knight_shield_bash"):
						pending["stun_on_collision"] = true
						
					if action.ability.id == &"knight_chain_hook" and actor.is_ability_upgraded(&"knight_chain_hook"):
						pending["vulnerable_on_adjacent"] = true
					
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
					
					if action.ability.id == &"knight_chain_hook" and actor.is_ability_upgraded(&"knight_chain_hook"):
						pending["vulnerable_on_adjacent"] = true
						
					board.pending_pushes.append(pending)
		GameEnums.EffectType.SWAP:
			if target != null:
				PhysicsSystem.swap(board, actor, target, events)
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
						board, adj_unit, effect.amount, events, dmg_type, false, false, null,
						action.ability.display_name, effect.amount
					)
			# Self-destruct: kill the bomber.
			CombatSystem.deal_damage(
				board, actor, actor.health.current_hp, events, &"physical", false, false, null,
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
					board, target_unit, effect.amount, events, dmg_type, false, false, null,
					action.ability.display_name, effect.amount
				)
			for dir in GridSystem.DIRECTIONS:
				var adj := center + dir
				var adj_unit := board.get_unit_at(adj)
				if adj_unit != null and adj_unit.is_alive():
					CombatSystem.deal_damage(
						board, adj_unit, effect.amount, events, dmg_type, false, false, null,
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
					
				if target.is_boss() and GameEnums.is_debuff(effect.status_type) and effect.status_type in [GameEnums.StatusType.STUN, GameEnums.StatusType.ROOT, GameEnums.StatusType.SILENCE, GameEnums.StatusType.PACIFY, GameEnums.StatusType.FEAR, GameEnums.StatusType.CONFUSION, GameEnums.StatusType.POLYMORPH, GameEnums.StatusType.TAUNT]:
					events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
						"actor": target.id, "reason": "boss_immune_to_cc",
					}))
					return
					
				var stat_val = effect.amount
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
				if trample_atk > 0:
					pending["trample_atk"] = trample_atk
				if bulldoze > 0:
					pending["bulldoze"] = bulldoze
					pending["caster_collision_immune"] = true
				if action.ability.id == &"knight_bowling_charge" and actor.is_ability_upgraded(&"knight_bowling_charge"):
					pending["bowling_upgrade"] = true
				if action.ability.id == &"knight_trampling_advance" and actor.is_ability_upgraded(&"knight_trampling_advance"):
					pending["trampling_upgrade"] = true
				board.pending_pushes.append(pending)
		GameEnums.EffectType.TRAMPLE, GameEnums.EffectType.BULLDOZE:
			# Movement modifiers — applied during dash or execute_pass_through_walk, not per-tile.
			pass
		GameEnums.EffectType.DESTROY_OBSTACLE:
			if target != null and target.definition.is_construct:
				CombatSystem.deal_damage(
					board, target, target.health.current_hp, events, &"physical", false, false, null,
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
			if target != null:
				if target.has_status(GameEnums.StatusType.ROOT) or target.has_status(GameEnums.StatusType.STUN):
					actor.ability.points_left = mini(actor.definition.action_points, actor.ability.points_left + 1)

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
				board, actor, effect.amount, events, &"true", true, false, null,
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
	return action.target_coord

## True when the attacker stands on the tile directly behind the target's facing.
static func _is_backstab(actor: UnitState, target: UnitState) -> bool:
	var behind := -PhysicsSystem.facing_to_vector(target.facing)
	return PhysicsSystem.cardinal_from_to(target.position, actor.position) == behind

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
		
		if push_type == "push" or push_type == "pull":
			if push.get("stun_on_collision", false):
				for i in range(push_ev_start, events.size()):
					var ev = events[i]
					if ev.type == GameEnums.SimEventType.COLLISION and ev.data.get("unit") == target.id:
						target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STUN, 1))
						target._recalculate_stats()
						break
			
			if push.get("vulnerable_on_adjacent", false) and actor != null:
				if GridSystem.manhattan(actor.position, target.position) == 1:
					target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.VULNERABLE, 1))
					target._recalculate_stats()
					
		elif push_type == "dash":
			if ability_id == &"knight_bowling_charge" and push.get("bowling_upgrade", false):
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
			elif ability_id == &"knight_trampling_advance":
				var traveled := 0
				var hit_unit_id := -1
				for i in range(push_ev_start, events.size()):
					var ev = events[i]
					if ev.type == GameEnums.SimEventType.UNIT_MOVED and ev.data.get("actor", ev.data.get("unit", -1)) == target.id:
						traveled = ev.data.get("steps", ev.data.get("distance", 0))
					elif ev.type == GameEnums.SimEventType.UNIT_PUSHED and ev.data.get("unit") == target.id:
						traveled = ev.data.get("distance", 0)
				for i in range(push_ev_start, events.size()):
					var ev = events[i]
					if ev.type == GameEnums.SimEventType.COLLISION and ev.data.get("unit") == target.id:
						if ev.data.has("against_unit"):
							hit_unit_id = ev.data.get("against_unit")
							break
				if hit_unit_id != -1:
					var target_hit = board.get_unit_by_id(hit_unit_id)
					if target_hit != null:
						var trample_dmg := CombatSystem.calculate_scaled_damage(
							target, 2, GameEnums.StatType.PHYSICAL, board
						)
						CombatSystem.deal_damage_raw(
							board, target, target_hit, trample_dmg, GameEnums.StatType.PHYSICAL, events, "Trampling Advance", 2
						)
						PhysicsSystem.push(board, target_hit, push.dir, 1, events, target)
						GridSystem.set_occupant(board, target.position, target.id)
				
				if push.get("trampling_upgrade", false) and traveled > 0:
					target.armor += traveled
					events.append(SimEvent.make(GameEnums.SimEventType.UNIT_ARMORED, {
						"unit": target.id,
						"amount": traveled,
						"armor": target.armor,
					}))
