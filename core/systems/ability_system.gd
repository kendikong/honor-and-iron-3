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

const MercenarySystems := preload("res://core/systems/mercenary_systems.gd")
const MonkSystems := preload("res://core/systems/monk_systems.gd")
const ShamanSystems := preload("res://core/systems/shaman_systems.gd")
const RogueSystems := preload("res://core/systems/rogue_systems.gd")
const BeastRiderSystems := preload("res://core/systems/beast_rider_systems.gd")
const EngineerSystems := preload("res://core/systems/engineer_systems.gd")

## Purpose: Runs the data-driven ability pipeline (Validate -> Execute -> Resolve).
## Responsibilities: Validate cost/range, spend action points, and interpret each
##   EffectData by delegating to the system that owns that effect.
## Dependencies: BoardState, UnitState, TimelineAction, EffectData, GridSystem,
##   CombatSystem, PhysicsSystem, SimEvent, GameEnums.
## Lifecycle: stateless; only static functions.

## Canonical active profile for all runtime readers.
static func active_modules_for(actor: UnitState, ability: AbilityData) -> Array[AbilityModule]:
	if ability == null:
		return []
	var upgraded: bool = actor != null and actor.is_ability_upgraded(ability.id)
	return ability.get_active_modules(upgraded)


## Transitional compatibility API for unmigrated EffectData readers.
## This compiler is never a modular runtime decision owner.
static func compatibility_effects_for(
	actor: UnitState,
	ability: AbilityData,
) -> Array[EffectData]:
	if ability == null:
		return []
	var modules: Array[AbilityModule] = active_modules_for(actor, ability)
	if not modules.is_empty():
		return AbilityModuleBridge.compile_modules_for_runtime(modules)
	return _legacy_flat_effects_for(actor, ability)


static func _legacy_flat_effects_for(
	actor: UnitState,
	ability: AbilityData,
) -> Array[EffectData]:
	if ability == null:
		return []
	if actor != null and actor.is_ability_upgraded(ability.id) and not ability.upgraded_effects.is_empty():
		return ability.upgraded_effects
	return ability.effects


## Internal legacy fallback. Modular callers must use active_modules_for().
static func legacy_effects_for(actor: UnitState, ability: AbilityData) -> Array[EffectData]:
	if not active_modules_for(actor, ability).is_empty():
		push_error("legacy_effects_for() cannot serve an authored modular profile")
		return []
	return _legacy_flat_effects_for(actor, ability)


static func active_motion_module(actor: UnitState, ability: AbilityData) -> AbilityModule:
	if ability == null:
		return null
	var upgraded: bool = actor != null and actor.is_ability_upgraded(ability.id)
	return ability.get_active_motion_module(upgraded)


static func active_motion_min_range(actor: UnitState, ability: AbilityData) -> int:
	var module: AbilityModule = active_motion_module(actor, ability)
	return module.min_range if module != null else 0


static func active_motion_max_range(actor: UnitState, ability: AbilityData) -> int:
	var module: AbilityModule = active_motion_module(actor, ability)
	return module.max_range if module != null else 0


static func active_motion_range_valid(actor: UnitState, ability: AbilityData) -> bool:
	var module: AbilityModule = active_motion_module(actor, ability)
	return module != null and module.min_range >= 1 and module.max_range >= module.min_range


static func motion_requires_occupied_target(actor: UnitState, ability: AbilityData) -> bool:
	var module: AbilityModule = active_motion_module(actor, ability)
	return (
		module != null
		and module.primary_type == GameEnums.EffectType.MOVE_INTO_AND_PUSH
	)


## True for MOVE_INTO_AND_PUSH (Push Through): paired occupy-and-shove presentation.
## TILE MOVE with INTO_OCCUPIED_PUSH (Trampling) is a walk, not this.
static func ability_has_into_occupied_push_effect(
	ability: AbilityData,
	actor: UnitState = null,
) -> bool:
	return motion_requires_occupied_target(actor, ability)


## Walk may land on an occupant; execution pushes them off.
## Covers MOVE_INTO_AND_PUSH and MotionMode.INTO_OCCUPIED_PUSH. Not a skill-id branch.
static func ability_allows_occupied_landing(
	ability: AbilityData,
	actor: UnitState = null,
) -> bool:
	if ability_has_into_occupied_push_effect(ability, actor):
		return true
	var module: AbilityModule = active_motion_module(actor, ability)
	return module != null and module.motion_mode == GameEnums.MotionMode.INTO_OCCUPIED_PUSH


static func _occupied_push_target_valid(
	board: BoardState,
	actor: UnitState,
	ability: AbilityData,
	target_coord: Vector2i,
) -> bool:
	if board == null or actor == null or ability == null:
		return false
	if target_coord == actor.position:
		return false
	var occupant: UnitState = board.get_unit_at(target_coord)
	if occupant == null or occupant.id == actor.id:
		return false
	if not _target_allowed(actor, ability, occupant, target_coord):
		return false
	var push_dir: Vector2i = PhysicsSystem.cardinal_from_to(actor.position, target_coord)
	if push_dir == Vector2i.ZERO:
		return false
	var behind_coord: Vector2i = target_coord + push_dir
	if not board.is_in_bounds(behind_coord):
		return false
	if GridSystem.is_wall(board, behind_coord):
		return false
	if GridSystem.is_occupied(board, behind_coord):
		return false
	return true


static func active_module_for_index(
	actor: UnitState,
	ability: AbilityData,
	module_index: int,
) -> AbilityModule:
	var modules: Array[AbilityModule] = active_modules_for(actor, ability)
	if module_index < 0 or module_index >= modules.size():
		return null
	return modules[module_index]


static func active_targeting_flags(
	actor: UnitState,
	ability: AbilityData,
	module_index: int = 0,
) -> int:
	var module: AbilityModule = active_module_for_index(actor, ability, module_index)
	if module != null:
		if module.targeting_flags != 0:
			return module.targeting_flags
		if ability != null and ability.targeting_flags != 0:
			return ability.targeting_flags
	if ability == null:
		return 0
	if ability.targeting_flags != 0:
		return ability.targeting_flags
	return AbilityData._targeting_mode_to_flags(ability.targeting_mode)


static func active_target_shape(
	actor: UnitState,
	ability: AbilityData,
	module_index: int = 0,
) -> GameEnums.TargetShape:
	var module: AbilityModule = active_module_for_index(actor, ability, module_index)
	if module != null:
		return module.target_shape
	if ability == null:
		return GameEnums.TargetShape.SINGLE
	if actor != null and actor.is_ability_upgraded(ability.id):
		if ability.upgraded_target_shape != GameEnums.TargetShape.SINGLE:
			return ability.upgraded_target_shape
	return ability.target_shape


static func active_target_shape_size(
	actor: UnitState,
	ability: AbilityData,
	module_index: int = 0,
) -> int:
	var module: AbilityModule = active_module_for_index(actor, ability, module_index)
	if module != null:
		return module.target_shape_size
	if ability == null:
		return 1
	if actor != null and actor.is_ability_upgraded(ability.id):
		if ability.upgraded_target_shape_size >= 0:
			return ability.upgraded_target_shape_size
	return ability.target_shape_size


static func active_range_tiles(
	actor: UnitState,
	ability: AbilityData,
	module_index: int = 0,
) -> int:
	var module: AbilityModule = active_module_for_index(actor, ability, module_index)
	if actor != null and module_index == 0:
		return actor.get_ability_range(ability) + ShamanSystems.conduit_range_bonus(
			actor, ability,
		)
	if module != null:
		return module.max_range
	if ability == null:
		return 0
	return actor.get_ability_range(ability) if actor != null else ability.range_tiles


## Planning + can_use: authored range extended by MOVE steps or DASH length.
static func planning_max_target_distance(actor: UnitState, ability: AbilityData) -> int:
	if ability == null:
		return 0
	var max_range: int = actor.get_ability_range(ability) if actor != null else ability.range_tiles
	if actor != null:
		if ability_has_dash(ability, actor):
			max_range = maxi(max_range, dash_steps(ability, actor))
		var move_steps: int = (
			0
			if ability_has_post_attack_move(ability, actor)
			else effect_amount(ability, GameEnums.EffectType.MOVE, actor)
		)
		if move_steps > 0:
			var followup_range := 0
			for module: AbilityModule in active_modules_for(actor, ability):
				if (
					module != null
					and module.primary_type == GameEnums.EffectType.DAMAGE
					and module.aim_binding == GameEnums.AimBinding.SAME_AS_MODULE_N
				):
					followup_range = maxi(followup_range, module.max_range)
			max_range = maxi(max_range, move_steps + followup_range)
	return max_range


static func planning_new_aim_indices(
	actor: UnitState,
	ability: AbilityData,
) -> Array[int]:
	var out: Array[int] = []
	for index: int in range(active_modules_for(actor, ability).size()):
		var module: AbilityModule = active_module_for_index(actor, ability, index)
		if module != null and module.aim_binding == GameEnums.AimBinding.NEW_AIM:
			out.append(index)
	return out


static func planning_next_aim_module_index(
	actor: UnitState,
	ability: AbilityData,
	module_index: int,
) -> int:
	for index: int in range(module_index + 1, active_modules_for(actor, ability).size()):
		var module: AbilityModule = active_module_for_index(actor, ability, index)
		if module != null and module.aim_binding == GameEnums.AimBinding.NEW_AIM:
			return index
	return -1


static func module_target_coord(action: TimelineAction, module_index: int) -> Vector2i:
	if action == null or module_index < 0:
		return Vector2i.ZERO
	var module: AbilityModule = active_module_for_index(null, action.ability, module_index)
	if module != null and module.aim_binding == GameEnums.AimBinding.SAME_AS_MODULE_N:
		return module_target_coord(action, module.aim_module_index)
	if module_index < action.module_target_coords.size():
		return action.module_target_coords[module_index]
	return action.target_coord


static func module_target_unit_id(action: TimelineAction, module_index: int) -> int:
	if action == null or module_index < 0:
		return -1
	var module: AbilityModule = active_module_for_index(null, action.ability, module_index)
	if module != null and module.aim_binding == GameEnums.AimBinding.SAME_AS_MODULE_N:
		return module_target_unit_id(action, module.aim_module_index)
	if module_index < action.module_target_unit_ids.size():
		return action.module_target_unit_ids[module_index]
	return action.target_unit_id


static func set_module_target(
	action: TimelineAction,
	module_index: int,
	target_coord: Vector2i,
	target_unit_id: int,
) -> void:
	if action == null or module_index < 0:
		return
	while action.module_target_coords.size() <= module_index:
		action.module_target_coords.append(action.target_coord)
		action.module_target_unit_ids.append(action.target_unit_id)
	action.module_target_coords[module_index] = target_coord
	action.module_target_unit_ids[module_index] = target_unit_id


static func _prefix_action(action: TimelineAction, module_count: int) -> TimelineAction:
	if action == null or action.ability == null or module_count <= 0:
		return null
	var prefix: TimelineAction = action.clone()
	var profile: Array[AbilityModule] = active_modules_for(null, action.ability)
	if module_count > profile.size():
		return null
	var profile_copy: Array[AbilityModule] = profile.slice(0, module_count)
	var ability_copy: AbilityData = action.ability.duplicate(true) as AbilityData
	ability_copy.modules = profile_copy
	ability_copy.upgraded_modules = profile_copy.duplicate()
	ability_copy.effects = []
	ability_copy.upgraded_effects = []
	prefix.ability = ability_copy
	prefix.awaiting_target = false
	prefix.awaiting_module_index = -1
	prefix.module_target_coords = action.module_target_coords.slice(0, module_count)
	prefix.module_target_unit_ids = action.module_target_unit_ids.slice(0, module_count)
	return prefix


static func planning_gate_passes(
	board: BoardState,
	action: TimelineAction,
	module_index: int,
) -> bool:
	var module: AbilityModule = active_module_for_index(null, action.ability, module_index)
	if module == null or module.gate == GameEnums.ModuleGate.ALWAYS:
		return module != null
	var prefix: TimelineAction = _prefix_action(action, module_index)
	if prefix == null:
		return false
	var trial: BoardState = board.clone()
	var timeline := Timeline.new()
	timeline.add(prefix)
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(trial, timeline, events)
	var actor: UnitState = trial.get_unit_by_id(action.actor_id)
	return _module_gate_passes(module, actor, events, 0)


static func planning_preview_action(action: TimelineAction) -> TimelineAction:
	if action == null or not action.awaiting_target or action.awaiting_module_index <= 0:
		return action
	return _prefix_action(action, action.awaiting_module_index)


static func prepare_planning_action(board: BoardState, action: TimelineAction) -> void:
	if board == null or action == null or action.type != GameEnums.ActionType.ABILITY:
		return
	var modules: Array[AbilityModule] = active_modules_for(
		board.get_unit_by_id(action.actor_id),
		action.ability,
	)
	if modules.is_empty():
		return
	if action.awaiting_target:
		if action.awaiting_module_index < 0:
			action.awaiting_module_index = 0
		return
	set_module_target(
		action,
		0,
		action.target_coord,
		action.target_unit_id,
	)
	var last_aim_index: int = 0
	for index: int in planning_new_aim_indices(board.get_unit_by_id(action.actor_id), action.ability):
		if index < action.module_target_coords.size():
			last_aim_index = index
	var next_index: int = planning_next_aim_module_index(
		board.get_unit_by_id(action.actor_id),
		action.ability,
		last_aim_index,
	)
	if next_index >= 0 and planning_gate_passes(board, action, next_index):
		action.awaiting_target = true
		action.awaiting_module_index = next_index


static func planning_module_target_valid(
	board: BoardState,
	action: TimelineAction,
	module_index: int,
	target_coord: Vector2i,
	target_unit_id: int = -1,
) -> bool:
	if board == null or action == null or action.ability == null:
		return false
	var actor: UnitState = board.get_unit_by_id(action.actor_id)
	var module: AbilityModule = active_module_for_index(actor, action.ability, module_index)
	if actor == null or module == null or module.min_range < 0 or module.max_range < module.min_range:
		return false
	var origin: Vector2i = actor.position
	var target_board: BoardState = board
	if module_index > 0:
		var prefix: TimelineAction = _prefix_action(action, module_index)
		if prefix == null:
			return false
		var after: BoardState = board.clone()
		var timeline := Timeline.new()
		timeline.add(prefix)
		var prefix_events: Array[SimEvent] = []
		Simulator.simulate_player_turn(after, timeline, prefix_events)
		target_board = after
		actor = after.get_unit_by_id(action.actor_id)
		origin = actor.position if actor != null else origin
	var distance: int = GridSystem.manhattan(origin, target_coord)
	if module.primary_type == GameEnums.EffectType.DASH:
		if PhysicsSystem.straight_line_dir(origin, target_coord) == Vector2i.ZERO:
			return false
		distance = PhysicsSystem.straight_line_distance(origin, target_coord)
	if distance < module.min_range or distance > module.max_range:
		return false
	if module.has_targeting(GameEnums.TargetingFlags.TILE):
		return true
	if target_coord == origin:
		return module.has_targeting(GameEnums.TargetingFlags.SELF)
	var target: UnitState = (
		target_board.get_unit_by_id(target_unit_id)
		if target_unit_id >= 0
		else target_board.get_unit_at(target_coord)
	)
	if target != null:
		if target.team == actor.team:
			return module.has_targeting(GameEnums.TargetingFlags.ALLY)
		return module.has_targeting(GameEnums.TargetingFlags.ENEMY)
	return module.has_targeting(GameEnums.TargetingFlags.TILE) \
		or module.has_targeting(GameEnums.TargetingFlags.DASH_LINE)


static func active_profile_is_offensive(actor: UnitState, ability: AbilityData) -> bool:
	for module: AbilityModule in active_modules_for(actor, ability):
		if module == null:
			continue
		if _effect_is_offensive(module.primary_type, module.status_type):
			return true
		for layer: AbilityLayer in module.layers:
			if layer != null and layer.effect != null and _effect_is_offensive(
				layer.effect.type,
				layer.effect.status_type,
			):
				return true
	return false


static func _effect_is_offensive(
	effect_type: GameEnums.EffectType,
	status_type: GameEnums.StatusType,
) -> bool:
	if effect_type in [
		GameEnums.EffectType.DAMAGE,
		GameEnums.EffectType.PUSH,
		GameEnums.EffectType.PULL,
		GameEnums.EffectType.EXPLODE,
		GameEnums.EffectType.RANGED_EXPLODE,
	]:
		return true
	return effect_type == GameEnums.EffectType.ADD_STATUS and GameEnums.is_debuff(status_type)


static func can_use(board: BoardState, action: TimelineAction) -> bool:
	var actor := board.get_unit_by_id(action.actor_id)
	if actor == null or not actor.is_alive():
		return false
	if actor.passive_flags.get("__shaman_echo_repeat", false):
		return true
	var ability := action.ability
	if ability == null:
		return false
	if (
		actor.passive_flags.get("marked_no_stealth_teleport", false)
		and ability_has_teleport(ability, actor)
	):
		return false
	if (
		_is_spell(ability)
		and actor.passive_flags.get("mana_shield_active", false)
		and not actor.passive_flags.get("mana_shield_casting", false)
	):
		return false
	if (
		_is_spell(ability)
		and actor.passive_flags.get("mana_shield_casting", false)
		and actor.armor <= 0
	):
		return false
	if _caltrop_expert_waives(actor, ability) and actor.passive_flags.get("caltrop_expert_used", false):
		return false
	if _ability_has_modifier(actor, ability, &"limit_once_per_turn") and actor.passive_flags.get(
		"ability_used_once:%s" % ability.id, false
	):
		return false
	if _ability_has_modifier(actor, ability, &"paired_ally_charge"):
		var paired_ally := board.get_unit_by_id(action.target_unit_id)
		var paired_enemy := board.get_unit_at(action.target_coord)
		var paired_range: int = planning_max_target_distance(actor, ability)
		if (
			paired_ally == null
			or paired_ally.team != actor.team
			or paired_enemy == null
			or paired_enemy.team == actor.team
			or GridSystem.manhattan(actor.position, paired_ally.position) > paired_range
			or GridSystem.manhattan(actor.position, paired_enemy.position) > paired_range
		):
			return false
	if not _has_resource_for_ability(actor, ability):
		return false
	if (
		EngineerSystems.has_ability_modifier(actor, ability, &"scrap_shield")
		and actor.scrap <= 0
	):
		return false
	if (
		actor.is_ability_upgraded(ability.id)
		and EngineerSystems.has_ability_modifier(actor, ability, &"scrap_attack_bonus")
		and actor.scrap < 1
	):
		return false
	var dist := GridSystem.manhattan(actor.position, action.target_coord)
	if ability_has_dash(ability, actor):
		if PhysicsSystem.straight_line_dir(actor.position, action.target_coord) == Vector2i.ZERO:
			return false
		dist = PhysicsSystem.straight_line_distance(actor.position, action.target_coord)
	var motion_module: AbilityModule = active_motion_module(actor, ability)
	var has_authored_modules: bool = not active_modules_for(actor, ability).is_empty()
	var max_range: int = (
		active_motion_max_range(actor, ability)
		if motion_module != null
		else active_range_tiles(actor, ability)
	)
	var actor_tile := board.get_tile(actor.position)
	if (
		actor_tile != null
		and actor_tile.definition != null
		and actor_tile.definition.elevated
		and _passive_has_modifier(actor, &"elevation_range")
	):
		max_range += 1
	if _is_spell(ability):
		max_range += int(actor.passive_flags.get("mage_spell_range_bonus", 0))
	if motion_module == null and not has_authored_modules:
		var legacy_move_range: int = (
			0
			if ability_has_post_attack_move(ability, actor)
			else effect_amount(ability, GameEnums.EffectType.MOVE, actor)
		)
		if legacy_move_range > 0:
			max_range = maxi(max_range, legacy_move_range)
	if motion_module != null and motion_module.primary_type == GameEnums.EffectType.MOVE:
		max_range = maxi(max_range, planning_max_target_distance(actor, ability))
	if dist > max_range:
		var mark_target: UnitState = (
			board.get_unit_by_id(action.target_unit_id)
			if action.target_unit_id >= 0
			else board.get_unit_at(action.target_coord)
		)
		if (
			mark_target != null
			and int(mark_target.passive_flags.get("mark_allies_team", -1)) == actor.team
		):
			max_range += int(mark_target.passive_flags.get("mark_allies_range", 0))
		if dist > max_range:
			return false
	if dist == 0 and active_range_tiles(actor, ability) > 0 and not can_target_self(actor, ability):
		return false
	var target_unit: UnitState = null
	if _ability_has_modifier(actor, ability, &"paired_ally_charge"):
		target_unit = board.get_unit_at(action.target_coord)
	elif action.target_unit_id >= 0:
		target_unit = board.get_unit_by_id(action.target_unit_id)
	else:
		target_unit = board.get_unit_at(action.target_coord)
	if (
		target_unit == null
		and _ability_has_modifier(actor, ability, &"target_after_move_adjacent")
	):
		for dir: Vector2i in GridSystem.DIRECTIONS:
			var adj: Vector2i = action.target_coord + dir
			if not board.is_in_bounds(adj):
				continue
			var adj_unit: UnitState = board.get_unit_at(adj)
			if (
				adj_unit != null
				and adj_unit.is_enemy()
				and adj_unit.is_alive()
				and target_passes_mode(actor, ability, adj_unit)
			):
				target_unit = adj_unit
				break
	if EngineerSystems.has_ability_modifier(actor, ability, &"recall_adjacent_construct"):
		if not EngineerSystems.can_use_recall(board, actor, action.target_coord):
			return false
	if (
		EngineerSystems.has_ability_modifier(actor, ability, &"construct_target_only")
		and (
			target_unit == null
			or target_unit.team != actor.team
			or target_unit.definition == null
			or not target_unit.definition.is_construct
		)
	):
		return false
	if (
		target_unit != null
		and _ability_has_modifier(actor, ability, &"revive_percent_max_hp")
		and target_unit.is_alive()
	):
		return false
	if (
		target_unit != null
		and _ability_has_modifier(actor, ability, &"requires_debuff")
		and not _target_has_debuff(target_unit)
	):
		return false
	if (
		not _target_allowed(actor, ability, target_unit, action.target_coord)
		and not _can_push_destructible_target(
			board,
			actor,
			ability,
			target_unit,
			action.target_coord,
		)
	):
		return false
	if _ability_has_modifier(actor, ability, &"target_after_move_adjacent"):
		if (
			target_unit == null
			or target_unit.team == actor.team
			or (
				target_unit.position != action.target_coord
				and GridSystem.manhattan(action.target_coord, target_unit.position) != 1
			)
		):
			return false

	if dist > 1:
		var tile = board.get_tile(action.target_coord)
		if tile != null and not tile.is_empty():
			var target = board.get_unit_by_id(tile.occupant_id)
			if (
				target != null
				and target.has_status(GameEnums.StatusType.STEALTH)
				and not _passive_has_modifier(actor, &"ignore_stealth")
				and _stealth_blocks_attacker(actor, target)
			):
				return false
			if (
				target != null
				and RogueSystems.outside_smoke_cannot_target(board, actor, target)
				and not _passive_has_modifier(actor, &"ignore_stealth")
			):
				return false

	if _ability_has_modifier(actor, ability, &"target_unacted_only"):
		var dust_target := target_unit
		if dust_target == null:
			dust_target = board.get_unit_at(action.target_coord)
		if dust_target == null or dust_target.turn_action_used:
			return false

	if actor.has_status(GameEnums.StatusType.STAGGER) or actor.has_status(GameEnums.StatusType.SILENCE):
		return false

	if actor.has_status(GameEnums.StatusType.PACIFY) and active_profile_is_offensive(actor, ability):
		return false

	if (
		ability.consumes_action_slot()
		and not actor.can_use_action_slot()
		and not actor.passive_flags.get("__mage_wild_magic_repeat", false)
		and not (
			actor.passive_flags.get("dual_wield_bonus_basic", false)
			and _is_basic_attack(ability)
		)
	):
		return false

	var has_displacement := has_displacement_effects(ability, actor)
		
	var is_dash := ability_has_dash(ability, actor)
	var is_move := (
		(
			(motion_module != null and motion_module.primary_type == GameEnums.EffectType.MOVE)
			or (
				motion_module == null
				and not has_authored_modules
				and effect_amount(ability, GameEnums.EffectType.MOVE, actor) > 0
			)
		)
		and not ability_has_post_attack_move(ability, actor)
	)
	var requires_l_shape: bool = _ability_has_modifier(actor, ability, &"l_shape_move")
	if requires_l_shape and action.target_coord != actor.position:
		var l_shape_budget: int = (
			active_motion_max_range(actor, ability)
			if has_authored_modules
			else effect_amount(ability, GameEnums.EffectType.MOVE, actor)
		)
		if (
			l_shape_budget <= 0
			or MovementSystem._l_shape_path(
				board,
				actor.position,
				action.target_coord,
				l_shape_budget,
				actor,
				ability,
			).is_empty()
		):
			return false
	
	if is_dash:
		var delta := action.target_coord - actor.position
		if delta.x != 0 and delta.y != 0:
			return false
		if PhysicsSystem.straight_line_dir(actor.position, action.target_coord) == Vector2i.ZERO:
			return false
		var steps := PhysicsSystem.straight_line_distance(actor.position, action.target_coord)
		var dash_min: int = active_motion_min_range(actor, ability)
		var dash_max: int = active_motion_max_range(actor, ability)
		if has_authored_modules and not active_motion_range_valid(actor, ability):
			return false
		if steps < (dash_min if has_authored_modules else 1) or (
			dash_max > 0 and steps > dash_max
		):
			return false

	if is_move or (has_pass_through_effects(ability, actor) and not is_dash):
		if action.target_coord != actor.position:
			var walk_min: int = (
				active_motion_min_range(actor, ability)
				if has_authored_modules
				else 1
			)
			var walk_steps: int = (
				active_motion_max_range(actor, ability)
				if has_authored_modules
				else effect_amount(ability, GameEnums.EffectType.MOVE, actor)
			)
			if walk_steps <= 0:
				return false
			var walk_distance: int = GridSystem.manhattan(actor.position, action.target_coord)
			var max_walk_target: int = walk_steps
			if motion_module != null and motion_module.primary_type == GameEnums.EffectType.MOVE:
				max_walk_target = maxi(max_walk_target, planning_max_target_distance(actor, ability))
			if has_authored_modules and not active_motion_range_valid(actor, ability):
				return false
			if walk_distance < walk_min or walk_distance > max_walk_target:
				return false
				
	if is_move or is_dash:
		if (
			not has_displacement
			and not has_pass_through_effects(ability, actor)
			and not _ability_has_modifier(actor, ability, &"target_after_move_adjacent")
			and not _ability_has_modifier(actor, ability, &"move_to_target_adjacent")
			and not _ability_has_modifier(actor, ability, &"land_opposite_target")
			and not _ability_has_modifier(actor, ability, &"paired_ally_charge")
			and not _ability_has_modifier(actor, ability, &"stop_adjacent_first_enemy")
		):
			var end_unit := board.get_unit_at(action.target_coord)
			if end_unit != null and end_unit.id != actor.id:
				return false

	if motion_requires_occupied_target(actor, ability):
		if not _occupied_push_target_valid(board, actor, ability, action.target_coord):
			return false
	if not MercenarySystems.can_use_extra(board, actor, ability, action):
		return false
	if not BeastRiderSystems.can_use_extra(board, actor, ability, action):
		return false

	return true


static func _adjacent_enemy_count(board: BoardState, actor: UnitState) -> int:
	if board == null or actor == null:
		return 0
	var count: int = 0
	for direction: Vector2i in GridSystem.DIRECTIONS:
		var unit := board.get_unit_at(actor.position + direction)
		if unit != null and unit.team != actor.team:
			count += 1
	return count


static func get_action_point_cost(actor: UnitState, ability: AbilityData, board: BoardState = null) -> int:
	if ability == null:
		return 0
	var ap_cost: int = ability.action_point_cost
	if actor != null and actor.is_ability_upgraded(ability.id):
		ap_cost = ability.get_active_primary_value(true) \
			if ability.primary_resource == GameEnums.CostResource.AP else ap_cost
	if actor == null or board == null:
		return ap_cost
	if (
		_is_spell(ability)
		and actor.passive_flags.get("mana_shield_casting", false)
	):
		return 0
	if (
		_is_spell(ability)
		and actor.passive_flags.get("mana_well_next_spell", false)
	):
		return 0
	if (
		ability.cost_modifier == GameEnums.CostModifier.ZERO_IF_ADJACENT_ENEMIES_GTE_N
		and _adjacent_enemy_count(board, actor) >= ability.cost_modifier_n
	):
		return 0
	if (
		ability.kind == GameEnums.AbilityKind.CLASS_SKILL
		and actor.ability.points_left < ap_cost
		and ShamanSystems.can_use_ritual_sacrifice(actor, ability)
	):
		return 0
	var needed: int = AbilityModuleBridge.modules_modifier_value(
		active_modules_for(actor, ability),
		&"zero_ap_adjacent_enemies",
		0,
	)
	if needed > 0:
		var adj_enemies := 0
		for dir in GridSystem.DIRECTIONS:
			var occ := board.get_unit_at(actor.position + dir)
			if occ != null and occ.team != actor.team:
				adj_enemies += 1
		if adj_enemies >= needed:
			return 0
	if _caltrop_expert_waives(actor, ability):
		return 0
	if active_modules_for(actor, ability).is_empty():
		for eff: EffectData in legacy_effects_for(actor, ability):
			if (
				eff != null
				and eff.type == GameEnums.EffectType.CREATE_HAZARD
				and eff.modifiers.get("terrain_id", &"") == &"caltrop_trap"
				and _passive_has_modifier(actor, &"caltrop_zero_ap")
			):
				return 0
	return MercenarySystems.adjust_action_point_cost(board, actor, ability, ap_cost)


static func movement_point_cost(actor: UnitState, ability: AbilityData) -> int:
	if ability == null:
		return 0
	if actor != null and actor.is_ability_upgraded(ability.id):
		var upgraded_cost: int = ability.get_active_primary_value(true) \
			if ability.primary_resource == GameEnums.CostResource.MP \
			else ability.movement_point_cost
		return MercenarySystems.adjust_movement_point_cost(actor, ability, upgraded_cost)
	var base_mp: int = ability.movement_point_cost
	return MercenarySystems.adjust_movement_point_cost(actor, ability, base_mp)


static func _apply_healing_passive_modifiers(
	board: BoardState,
	healer: UnitState,
	target: UnitState,
	healing_delivered: int,
	requested_healing: int,
	events: Array[SimEvent],
	hp_before_heal: int = -1,
) -> void:
	if healer == null or target == null:
		return
	if healer.team != target.team or healer.id == target.id:
		return
	if healer.passive_flags.get("prayer_next_heal", false) and healing_delivered > 0:
		var doubled := target.health.current_hp
		CombatSystem.heal(board, target, healing_delivered, events)
		healing_delivered += target.health.current_hp - doubled
		healer.passive_flags.erase("prayer_next_heal")
		if healer.passive_flags.get("prayer_next_heal_cleanse", false):
			var cleanse_effect := DataLibrary._effect(GameEnums.EffectType.CLEANSE, 0)
			_apply_effect_to_tile(
				board,
				healer,
				TimelineAction.make_ability(healer.id, DataLibrary.get_universal_wait(), target.position, target.id),
				cleanse_effect,
				events,
				target.position,
				target,
			)
			healer.passive_flags.erase("prayer_next_heal_cleanse")
	var overheal := maxi(0, requested_healing - healing_delivered)
	for passive: PassiveData in healer.active_passives:
		if passive == null or not passive.modifiers.has("overheal_shield"):
			continue
		if overheal > 0:
			CombatSystem.add_armor(board, target, overheal, events)
			if passive.modifiers.get("overheal_self_cost", false):
				CombatSystem.deal_damage(
					board,
					healer,
					overheal,
					events,
					&"true",
					true,
					false,
					healer,
					"Blood Donation",
					overheal,
				)
			if healer.is_passive_upgraded(passive.id):
				healer.active_statuses.append(
					DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 1, 1)
				)
		break
	for passive: PassiveData in healer.active_passives:
		if passive == null or not passive.modifiers.has("selfless_siphon"):
			continue
		if healing_delivered <= 0:
			break
		var ratio := float(passive.modifiers.get("self_heal_pct", 0.25))
		if healer.is_passive_upgraded(passive.id):
			ratio = float(passive.modifiers.get("upgraded_self_heal_pct", ratio))
		var self_heal := floori(healing_delivered * ratio)
		if self_heal <= 0:
			continue
		if healer.is_passive_upgraded(passive.id) and healer.health.current_hp >= healer.health.max_hp:
			CombatSystem.add_armor(board, healer, self_heal, events)
		else:
			CombatSystem.heal(board, healer, self_heal, events)
		break
	for passive: PassiveData in healer.active_passives:
		if passive == null:
			continue
		if passive.modifiers.has("full_health_heal_pulse") and (
			hp_before_heal >= target.health.max_hp
			if hp_before_heal >= 0
			else target.health.current_hp >= target.health.max_hp
		):
			if not healer.passive_flags.get("divine_overflow_processing", false):
				healer.passive_flags["divine_overflow_processing"] = true
				var pulse := int(passive.modifiers["full_health_heal_pulse"])
				if healer.is_passive_upgraded(passive.id):
					pulse = int(passive.modifiers.get("upgraded_full_health_heal_pulse", pulse))
				for direction: Vector2i in GridSystem.DIRECTIONS:
					var adjacent := board.get_unit_at(target.position + direction)
					if adjacent != null and adjacent.team != healer.team:
						CombatSystem.deal_mag_atk(
							board,
							healer,
							adjacent,
							pulse,
							events,
							"Divine Overflow",
						)
				healer.passive_flags.erase("divine_overflow_processing")
		if passive.modifiers.has("adjacent_enemy_heal"):
			var adjacent_enemies := 0
			for direction: Vector2i in GridSystem.DIRECTIONS:
				var adjacent := board.get_unit_at(healer.position + direction)
				if adjacent != null and adjacent.team != healer.team:
					adjacent_enemies += 1
			if adjacent_enemies > 0:
				var bonus := int(passive.modifiers["adjacent_enemy_heal"])
				if healer.is_passive_upgraded(passive.id):
					bonus = int(passive.modifiers.get("upgraded_adjacent_enemy_heal", bonus))
				CombatSystem.heal(board, target, bonus, events)
		if passive.modifiers.has("heal_ally_str"):
			var strength_bonus := int(passive.modifiers["heal_ally_str"])
			var strength_duration := 1
			if target.health.current_hp >= target.health.max_hp:
				strength_bonus = int(passive.modifiers.get("heal_full_str", strength_bonus))
			if healer.is_passive_upgraded(passive.id):
				strength_bonus = int(passive.modifiers.get("upgraded_heal_ally_str", strength_bonus))
				strength_duration = int(passive.modifiers.get("upgraded_heal_ally_duration", 1))
			target.active_statuses.append(
				DataLibrary.make_status(
					GameEnums.StatusType.STAT_BUFF_STR,
					strength_duration,
					strength_bonus,
				)
			)
		if passive.modifiers.has("heal_def"):
			var defense_bonus := int(passive.modifiers["heal_def"])
			if healer.is_passive_upgraded(passive.id):
				defense_bonus = int(passive.modifiers.get("upgraded_heal_def", defense_bonus))
			healer.active_statuses.append(
				DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, defense_bonus)
			)
			target.active_statuses.append(
				DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, defense_bonus)
			)
	healer._recalculate_stats(board)
	target._recalculate_stats(board)


static func _apply_damage_effect_modifiers(
	board: BoardState,
	actor: UnitState,
	target: UnitState,
	effect: EffectData,
	events: Array[SimEvent],
	target_hp_before: int = 0,
	target_armor_before: int = 0,
) -> void:
	if board == null or actor == null or target == null or not target.is_alive():
		return
	if effect.modifiers.get("stagger_if_debuffed", false) and _target_has_debuff(target):
		target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAGGER, 1))
		target._recalculate_stats(board)
	if effect.modifiers.has("push"):
		PhysicsSystem.push(
			board,
			target,
			PhysicsSystem.cardinal_from_to(actor.position, target.position),
			int(effect.modifiers["push"]),
			events,
			actor,
		)
	if actor.passive_flags.get("next_attack_push", 0) > 0:
		PhysicsSystem.push(
			board,
			target,
			PhysicsSystem.cardinal_from_to(actor.position, target.position),
			int(actor.passive_flags["next_attack_push"]),
			events,
			actor,
		)
		actor.passive_flags.erase("next_attack_push")
	if effect.modifiers.has("shield_closest_ally_pct_damage"):
		var damage_dealt := maxi(
			0,
			target_hp_before
			+ target_armor_before
			- target.health.current_hp
			- target.armor,
		)
		var closest_ally: UnitState = null
		var closest_distance := 999
		for candidate: UnitState in board.units:
			if (
				candidate == null
				or not candidate.is_alive()
				or candidate.team != actor.team
			):
				continue
			var distance := GridSystem.manhattan(candidate.position, target.position)
			if distance < closest_distance:
				closest_distance = distance
				closest_ally = candidate
		if closest_ally != null and damage_dealt > 0:
			CombatSystem.add_armor(
				board,
				closest_ally,
				floori(damage_dealt * float(effect.modifiers["shield_closest_ally_pct_damage"])),
				events,
			)


static func purge_unit(target: UnitState, events: Array[SimEvent]) -> void:
	if target == null:
		return
	for index: int in range(target.active_statuses.size() - 1, -1, -1):
		if GameEnums.is_buff(target.active_statuses[index].type):
			var removed: StatusData = target.active_statuses.pop_at(index)
			events.append(SimEvent.make(GameEnums.SimEventType.STATUS_REMOVED, {
				"unit": target.id, "status_type": removed.type,
			}))
	target.armor = 0
	target._recalculate_stats()


static func cleanse_unit(target: UnitState, events: Array[SimEvent]) -> int:
	if target == null:
		return 0
	var removed_count := 0
	for index: int in range(target.active_statuses.size() - 1, -1, -1):
		if GameEnums.is_debuff(target.active_statuses[index].type):
			var removed: StatusData = target.active_statuses.pop_at(index)
			removed_count += 1
			events.append(SimEvent.make(GameEnums.SimEventType.STATUS_REMOVED, {
				"unit": target.id, "status_type": removed.type,
			}))
	target._recalculate_stats()
	return removed_count


static func _first_empty_adjacent_cell(board: BoardState, center: Vector2i) -> Vector2i:
	for direction: Vector2i in GridSystem.DIRECTIONS:
		var candidate := center + direction
		if (
			GridSystem.is_in_bounds(board, candidate)
			and not GridSystem.is_occupied(board, candidate)
			and not GridSystem.is_wall(board, candidate)
		):
			return candidate
	return Vector2i(-1, -1)


static func _link_enemy_pair(
	board: BoardState,
	actor: UnitState,
	target: UnitState,
	effect: EffectData,
	events: Array[SimEvent],
) -> void:
	var partner: UnitState = null
	var partner_distance := 999
	for candidate: UnitState in board.units:
		if (
			candidate == null
			or candidate.id == target.id
			or not candidate.is_alive()
			or candidate.team == actor.team
		):
			continue
		var distance := GridSystem.manhattan(actor.position, candidate.position)
		if distance < partner_distance:
			partner = candidate
			partner_distance = distance
	if partner == null:
		events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
			"actor": actor.id, "reason": "martyrs_chains_missing_second_enemy",
		}))
		return
	target.passive_flags["magic_chain_partner_id"] = partner.id
	partner.passive_flags["magic_chain_partner_id"] = target.id
	target.passive_flags["magic_chain_owner_id"] = actor.id
	partner.passive_flags["magic_chain_owner_id"] = actor.id
	if effect.modifiers.has("voodoo_link"):
		var weapon := actor.definition.equipped_weapon.might if actor.definition.equipped_weapon != null else 1
		var link_multiplier := 1
		if actor.has_passive(&"spirit_link"):
			link_multiplier = 2 if actor.is_passive_upgraded(&"spirit_link") else 1
		target.passive_flags["shaman_link_partner_id"] = partner.id
		partner.passive_flags["shaman_link_partner_id"] = target.id
		target.passive_flags["shaman_link_weapon"] = weapon * int(
			effect.modifiers.get("shared_damage_wpn", 1),
		) * link_multiplier
		partner.passive_flags["shaman_link_weapon"] = target.passive_flags["shaman_link_weapon"]
		target.passive_flags["shaman_link_damage_bonus"] = (
			2 if actor.is_passive_upgraded(&"pain_sharing") else 1
		) if actor.has_passive(&"pain_sharing") else 0
		partner.passive_flags["shaman_link_damage_bonus"] = target.passive_flags["shaman_link_damage_bonus"]
		target.passive_flags["shaman_link_shared_push"] = bool(effect.modifiers.get("shared_push", false))
		partner.passive_flags["shaman_link_shared_push"] = target.passive_flags["shaman_link_shared_push"]
		var push_amount := 0
		if actor.has_passive(&"chain_reaction"):
			push_amount = 2 if actor.is_passive_upgraded(&"chain_reaction") else 1
		target.passive_flags["shaman_link_push_amount"] = push_amount
		partner.passive_flags["shaman_link_push_amount"] = push_amount
	var blind: bool = bool(effect.modifiers.get("link_blind", false))
	target.passive_flags["magic_chain_blind"] = blind
	partner.passive_flags["magic_chain_blind"] = blind
	events.append(SimEvent.make(GameEnums.SimEventType.STATUS_APPLIED, {
		"unit": target.id,
		"partner": partner.id,
		"link": "martyrs_chains",
	}))


static func _has_resource_for_ability(actor: UnitState, ability: AbilityData, board: BoardState = null) -> bool:
	if ability == null or actor == null:
		return false
	if actor.passive_flags.get("__mage_wild_magic_repeat", false):
		return true
		
	var ap_cost = get_action_point_cost(actor, ability, board)
	var hp_cost: int = 0
	if ability.primary_resource == GameEnums.CostResource.HP:
		hp_cost = ability.get_active_primary_value(actor.is_ability_upgraded(ability.id))
	elif ability.secondary_resource == GameEnums.CostResource.HP:
		hp_cost = ability.get_active_secondary_value(actor.is_ability_upgraded(ability.id))
	var ritual_sacrifice := (
		actor.ability.points_left < ap_cost
		and ShamanSystems.can_use_ritual_sacrifice(actor, ability)
	)
	if ritual_sacrifice:
		hp_cost = ShamanSystems.ritual_sacrifice_cost(actor)
	if hp_cost > 0 and actor.health.current_hp <= hp_cost:
		return false
	if (
		actor.ability.points_left < ap_cost
		and ShamanSystems.can_use_ritual_sacrifice(actor, ability)
	):
		var ritual_hp := ShamanSystems.ritual_sacrifice_cost(actor)
		if actor.health.current_hp <= ritual_hp:
			return false
			
	match ability.kind:
		GameEnums.AbilityKind.MOVEMENT_SKILL:
			if _ability_has_modifier(actor, ability, &"cost_all_movement"):
				return actor.movement.points_left > 0
			return actor.movement.points_left >= movement_point_cost(actor, ability)
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
	if not _target_shape_is_valid(actor, ability, target_coord):
		return false
	var targeting_flags: int = active_targeting_flags(actor, ability)
	if target != null:
		if target.id == actor.id and (targeting_flags & GameEnums.TargetingFlags.SELF) != 0:
			return true
		if (
			target.id != actor.id
			and target.team == actor.team
			and (targeting_flags & GameEnums.TargetingFlags.ALLY) != 0
		):
			return true
		if target.team != actor.team and (targeting_flags & GameEnums.TargetingFlags.ENEMY) != 0:
			return true
	if target_coord == actor.position:
		return (targeting_flags & GameEnums.TargetingFlags.SELF) != 0
	if (targeting_flags & GameEnums.TargetingFlags.TILE) != 0:
		return true
	if (targeting_flags & GameEnums.TargetingFlags.DASH_LINE) != 0:
		return true
	return false


static func _target_shape_is_valid(
	actor: UnitState,
	ability: AbilityData,
	target_coord: Vector2i,
) -> bool:
	if actor == null or ability == null:
		return false
	var shape: GameEnums.TargetShape = active_target_shape(actor, ability)
	if shape in [
		GameEnums.TargetShape.ARC,
		GameEnums.TargetShape.CONE,
		GameEnums.TargetShape.LINE,
	]:
		return PhysicsSystem.cardinal_from_to(actor.position, target_coord) != Vector2i.ZERO
	return true


static func can_target_self(_actor: UnitState, ability: AbilityData) -> bool:
	if _actor == null or ability == null:
		return false
	return (
		active_targeting_flags(_actor, ability) & GameEnums.TargetingFlags.SELF
	) != 0


static func target_passes_mode(actor: UnitState, ability: AbilityData, target: UnitState) -> bool:
	if actor == null or ability == null:
		return false
	var coord: Vector2i = target.position if target != null else Vector2i.ZERO
	return _target_allowed(actor, ability, target, coord)


static func ability_has_dash(ability: AbilityData, actor: UnitState = null) -> bool:
	if ability == null:
		return false
	var motion_module: AbilityModule = active_motion_module(actor, ability)
	if motion_module != null:
		return motion_module.primary_type == GameEnums.EffectType.DASH
	var modules: Array[AbilityModule] = active_modules_for(actor, ability)
	if not modules.is_empty():
		return AbilityModuleBridge.modules_have_effect(modules, GameEnums.EffectType.DASH)
	for eff: EffectData in legacy_effects_for(actor, ability):
		if eff.type == GameEnums.EffectType.DASH:
			return true
	return false


static func ability_has_movement_effect(ability: AbilityData, actor: UnitState = null) -> bool:
	if ability == null:
		return false
	var modules: Array[AbilityModule] = active_modules_for(actor, ability)
	if not modules.is_empty():
		for module: AbilityModule in modules:
			if module == null:
				continue
			if module.primary_type in [
				GameEnums.EffectType.DASH,
				GameEnums.EffectType.TELEPORT_CASTER,
				GameEnums.EffectType.MOVE_INTO_AND_PUSH,
			]:
				return true
			if (
				module.primary_type == GameEnums.EffectType.MOVE
				and not AbilityModuleBridge.module_has_modifier(module, &"post_attack_move")
			):
				return true
		return false
	for eff: EffectData in legacy_effects_for(actor, ability):
		if eff.type in [
			GameEnums.EffectType.DASH,
			GameEnums.EffectType.TELEPORT_CASTER,
			GameEnums.EffectType.MOVE_INTO_AND_PUSH,
		]:
			return true
		if eff.type == GameEnums.EffectType.MOVE and not eff.modifiers.has("post_attack_move"):
			return true
	return false


static func ability_has_post_attack_move(ability: AbilityData, actor: UnitState = null) -> bool:
	if ability == null:
		return false
	var modules: Array[AbilityModule] = active_modules_for(actor, ability)
	if not modules.is_empty():
		for module: AbilityModule in modules:
			if (
				module != null
				and module.primary_type == GameEnums.EffectType.MOVE
				and AbilityModuleBridge.module_has_modifier(module, &"post_attack_move")
			):
				return true
		return false
	for eff: EffectData in legacy_effects_for(actor, ability):
		if (
			eff != null
			and eff.type == GameEnums.EffectType.MOVE
			and eff.modifiers.has("post_attack_move")
		):
			return true
	return false


static func ability_has_teleport(ability: AbilityData, actor: UnitState = null) -> bool:
	if ability == null:
		return false
	var modules: Array[AbilityModule] = active_modules_for(actor, ability)
	if not modules.is_empty():
		return AbilityModuleBridge.modules_have_effect(
			modules,
			GameEnums.EffectType.TELEPORT_CASTER,
		)
	for eff: EffectData in legacy_effects_for(actor, ability):
		if eff != null and eff.type == GameEnums.EffectType.TELEPORT_CASTER:
			return true
	return false


static func is_movement_skill(ability: AbilityData, actor: UnitState = null) -> bool:
	if ability == null:
		return false
	var modules: Array[AbilityModule] = active_modules_for(actor, ability)
	if not modules.is_empty():
		for module: AbilityModule in modules:
			if module != null and module.primary_type in [
				GameEnums.EffectType.DASH,
				GameEnums.EffectType.MOVE,
				GameEnums.EffectType.TELEPORT_CASTER,
				GameEnums.EffectType.MOVE_INTO_AND_PUSH,
			]:
				return true
		return false
	for eff: EffectData in legacy_effects_for(actor, ability):
		if eff.type in [
			GameEnums.EffectType.DASH,
			GameEnums.EffectType.MOVE,
			GameEnums.EffectType.TELEPORT_CASTER,
			GameEnums.EffectType.MOVE_INTO_AND_PUSH,
		]:
			return true
	return false


## Planning: one-click commit vs two-phase awaiting-target flow (keyword rules live here only).
static func planning_commit_flow(actor: UnitState, ability: AbilityData) -> int:
	if actor == null or ability == null:
		return GameEnums.PlanningCommitFlow.IMMEDIATE
	var requires_aiming := (
		ability_has_movement_effect(ability, actor)
		or (active_targeting_flags(actor, ability) & GameEnums.TargetingFlags.TILE) != 0
	)
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


static func planning_awaiting_phase(ability: AbilityData, actor: UnitState = null) -> int:
	if ability == null:
		return GameEnums.PlanningAwaitingPhase.GENERIC
	if ability_has_modifier(ability, &"paired_ally_charge", actor):
		return GameEnums.PlanningAwaitingPhase.MOVEMENT_ENDPOINT
	if ability_has_movement_effect(ability, actor):
		return GameEnums.PlanningAwaitingPhase.MOVEMENT_ENDPOINT
	if (active_targeting_flags(actor, ability) & GameEnums.TargetingFlags.TILE) != 0:
		return GameEnums.PlanningAwaitingPhase.TARGET_PICK
	return GameEnums.PlanningAwaitingPhase.GENERIC


static func planning_awaiting_endpoint_range(
	ability: AbilityData,
	actor: UnitState = null,
) -> int:
	if planning_awaiting_phase(ability) in [
		GameEnums.PlanningAwaitingPhase.MOVEMENT_ENDPOINT,
		GameEnums.PlanningAwaitingPhase.TARGET_PICK,
	]:
		var module: AbilityModule = active_motion_module(actor, ability)
		if module == null or module.min_range < 1 or module.max_range < module.min_range:
			return 0
		return module.max_range
	return 0


static func planning_is_valid_awaiting_endpoint(
	origin: Vector2i,
	coord: Vector2i,
	ability: AbilityData,
	actor: UnitState = null,
) -> bool:
	if ability_has_modifier(ability, &"paired_ally_charge", actor):
		var paired_range: int = planning_max_target_distance(actor, ability)
		if paired_range <= 0 and ability != null:
			paired_range = ability.range_tiles
		var paired_dist: int = GridSystem.manhattan(origin, coord)
		return paired_dist >= 1 and paired_dist <= paired_range
	var module: AbilityModule = active_motion_module(actor, ability)
	if module == null or module.min_range < 1 or module.max_range < module.min_range:
		return false
	if coord == origin:
		return false
	if module.primary_type == GameEnums.EffectType.DASH:
		var delta: Vector2i = coord - origin
		if delta.x != 0 and delta.y != 0:
			return false
	var dist: int = GridSystem.manhattan(origin, coord)
	return dist >= module.min_range and dist <= module.max_range


## TILE-aim abilities commit a cell; occupant id is incidental (sim resolves via target_coord).
static func planning_commit_target_unit_id(ability: AbilityData, occupant_unit_id: int) -> int:
	if ability != null and (ability.targeting_flags & GameEnums.TargetingFlags.TILE) != 0:
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
	var modules: Array[AbilityModule] = active_modules_for(actor, ability)
	if not modules.is_empty():
		for module: AbilityModule in modules:
			if AbilityModuleBridge.module_has_effect(module, effect_type):
				return AbilityModuleBridge.module_effect_amount(module, effect_type)
		return 0
	for eff: EffectData in legacy_effects_for(actor, ability):
		if eff.type == effect_type:
			return eff.amount
	return 0


static func ability_has_effect(
	ability: AbilityData,
	effect_type: GameEnums.EffectType,
	actor: UnitState = null,
) -> bool:
	## Presentation/metadata query only. This ungated scan reports authored typed
	## effects, including gated modules; it never executes or bypasses module gates.
	if ability == null:
		return false
	var modules: Array[AbilityModule] = active_modules_for(actor, ability)
	if not modules.is_empty():
		return AbilityModuleBridge.modules_have_effect(modules, effect_type)
	for effect: EffectData in legacy_effects_for(actor, ability):
		if effect != null and effect.type == effect_type:
			return true
	return false


static func _ability_has_modifier(
	actor: UnitState,
	ability: AbilityData,
	key: StringName,
) -> bool:
	if ability == null:
		return false
	var modules: Array[AbilityModule] = active_modules_for(actor, ability)
	if not modules.is_empty():
		if AbilityModuleBridge.modules_have_modifier(modules, key):
			return true
		for effect: EffectData in AbilityModuleBridge.compile_modules_to_effects(modules):
			if effect != null and (effect.modifiers.has(key) or effect.modifiers.has(String(key))):
				return true
		return false
	for effect: EffectData in legacy_effects_for(actor, ability):
		if effect != null and effect.modifiers.has(key):
			return true
	return false


static func _caltrop_expert_waives(actor: UnitState, ability: AbilityData) -> bool:
	if actor == null or ability == null or not _passive_has_modifier(actor, &"caltrop_zero_ap"):
		return false
	return _ability_terrain_id(actor, ability) == &"caltrop_trap"


static func _ability_terrain_id(actor: UnitState, ability: AbilityData) -> StringName:
	if ability == null:
		return &""
	var modules: Array[AbilityModule] = active_modules_for(actor, ability)
	for module: AbilityModule in modules:
		if module != null and module.legacy_modifiers.has("terrain_id"):
			return module.legacy_modifiers["terrain_id"] as StringName
	for effect: EffectData in legacy_effects_for(actor, ability):
		if effect != null and effect.modifiers.has("terrain_id"):
			return effect.modifiers["terrain_id"] as StringName
	return &""


static func _status_amount(unit: UnitState, status_type: int) -> int:
	if unit == null:
		return 0
	for status: StatusData in unit.active_statuses:
		if status != null and status.type == status_type:
			return status.value
	return 0


static func _stealth_blocks_attacker(attacker: UnitState, target: UnitState) -> bool:
	if attacker == null or target == null:
		return false
	var stealth_range: int = _status_amount(target, GameEnums.StatusType.STEALTH)
	var dist: int = GridSystem.manhattan(attacker.position, target.position)
	if stealth_range <= 0:
		return true
	return dist > stealth_range


static func apply_standing_aim_passives(board: BoardState, events: Array[SimEvent]) -> void:
	if board == null:
		return
	for unit: UnitState in board.units:
		if unit == null or not unit.is_alive() or unit.team != GameEnums.Team.PLAYER:
			continue
		apply_standing_aim_passives_for_unit(board, unit, events)


static func apply_standing_aim_passives_for_unit(
	board: BoardState,
	actor: UnitState,
	events: Array[SimEvent],
) -> void:
	if actor == null or actor.passive_flags.get("steady_aim_triggered", false):
		return
	if actor.movement_points_spent_this_turn != 0:
		return
	if _passive_has_modifier(actor, &"zero_move_stealth_range"):
		var stealth_range: int = 3
		for passive: PassiveData in actor.active_passives:
			if passive != null and passive.modifiers.has("zero_move_stealth_range"):
				stealth_range = int(passive.modifiers["zero_move_stealth_range"])
				break
		if not actor.has_status(GameEnums.StatusType.STEALTH):
			actor.active_statuses.append(
				DataLibrary.make_status(GameEnums.StatusType.STEALTH, 1, stealth_range)
			)
			actor._recalculate_stats(board)
	if not _passive_has_modifier(actor, &"steady_aim"):
		return
	var remaining: int = actor.movement.points_left
	if remaining > 0:
		actor.movement.points_left = 0
		actor.movement_points_spent_this_turn += remaining
	actor.passive_flags["steady_aim_triggered"] = true
	for passive: PassiveData in actor.active_passives:
		if passive == null or not passive.modifiers.has("vantage_anchor"):
			continue
		if not actor.has_status(GameEnums.StatusType.STURDY):
			actor.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STURDY, 1))
		if not actor.has_status(GameEnums.StatusType.STEALTH):
			actor.active_statuses.append(
				DataLibrary.make_status(
					GameEnums.StatusType.STEALTH,
					1,
					int(passive.modifiers.get("vantage_anchor_stealth_range", 3)),
				)
			)
		if (
			actor.is_passive_upgraded(passive.id)
			and passive.modifiers.has("upgraded_vantage_anchor_strength")
		):
			actor.active_statuses.append(
				DataLibrary.make_status(
					GameEnums.StatusType.STAT_BUFF_STR,
					1,
					int(passive.modifiers["upgraded_vantage_anchor_strength"]),
				)
			)
		actor._recalculate_stats(board)
		break


static func _ability_modifier_int(
	actor: UnitState,
	ability: AbilityData,
	key: StringName,
	default_value: int = 0,
) -> int:
	if ability == null:
		return default_value
	var modules: Array[AbilityModule] = active_modules_for(actor, ability)
	if not modules.is_empty():
		for module: AbilityModule in modules:
			if module != null and module.legacy_modifiers.has(key):
				return int(module.legacy_modifiers[key])
		for effect: EffectData in AbilityModuleBridge.compile_modules_to_effects(modules):
			if effect != null and effect.modifiers.has(key):
				return int(effect.modifiers[key])
		return default_value
	for effect: EffectData in legacy_effects_for(actor, ability):
		if effect != null and effect.modifiers.has(key):
			return int(effect.modifiers[key])
	return default_value


static func ability_has_modifier(
	ability: AbilityData,
	key: StringName,
	actor: UnitState = null,
) -> bool:
	return _ability_has_modifier(actor, ability, key)


static func ability_has_swap_effect(ability: AbilityData, actor: UnitState = null) -> bool:
	if ability == null:
		return false
	var modules: Array[AbilityModule] = active_modules_for(actor, ability)
	if not modules.is_empty():
		return AbilityModuleBridge.modules_have_effect(modules, GameEnums.EffectType.SWAP)
	for eff: EffectData in legacy_effects_for(actor, ability):
		if eff.type == GameEnums.EffectType.SWAP:
			return true
	return false


static func resolve_presentation_anim(ability: AbilityData, actor: UnitState = null) -> int:
	if ability == null:
		return GameEnums.PresentationAnim.WALK
	var pres_anim: int = ability.presentation_anim
	if pres_anim != GameEnums.PresentationAnim.AUTO:
		return pres_anim
	if ability_has_dash(ability, actor):
		return GameEnums.PresentationAnim.SUPER_RUN
	if has_pass_through_effects(ability, actor):
		return GameEnums.PresentationAnim.RUN
	if ability_has_movement_effect(ability, actor):
		return GameEnums.PresentationAnim.WALK
	return GameEnums.PresentationAnim.WALK


static func has_pass_through_effects(ability: AbilityData, actor: UnitState = null) -> bool:
	if ability == null:
		return false
	var modules: Array[AbilityModule] = active_modules_for(actor, ability)
	if not modules.is_empty():
		var module_mods := AbilityModuleBridge.pass_through_modifiers_from_modules(modules)
		return (
			int(module_mods.get("trample_atk", 0)) > 0
			or int(module_mods.get("bulldoze", 0)) > 0
		)
	return has_pass_through_effects_from(legacy_effects_for(actor, ability))


static func has_displacement_effects(ability: AbilityData, actor: UnitState = null) -> bool:
	return effect_amount(ability, GameEnums.EffectType.PUSH, actor) > 0 \
		or effect_amount(ability, GameEnums.EffectType.PULL, actor) > 0 \
		or ability_has_swap_effect(ability, actor) \
		or effect_amount(ability, GameEnums.EffectType.BULLDOZE, actor) > 0 \
		or _ability_has_modifier(actor, ability, &"paired_ally_charge")


static func dash_steps(ability: AbilityData, actor: UnitState = null) -> int:
	var module: AbilityModule = active_motion_module(actor, ability)
	if module != null:
		return module.max_range
	if ability != null and not ability.modules.is_empty():
		return 0
	return effect_amount(ability, GameEnums.EffectType.DASH, actor)


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


static func planning_module_range_tiles(
	board: BoardState,
	action: TimelineAction,
	module_index: int,
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if board == null or action == null or action.ability == null:
		return out
	var actor: UnitState = board.get_unit_by_id(action.actor_id)
	var module: AbilityModule = active_module_for_index(actor, action.ability, module_index)
	if actor == null or module == null:
		return out
	var origin: Vector2i = actor.position
	var range_board: BoardState = board
	if module_index > 0:
		var prefix: TimelineAction = _prefix_action(action, module_index)
		if prefix == null:
			return out
		range_board = board.clone()
		var prefix_events: Array[SimEvent] = []
		var prefix_timeline := Timeline.new()
		prefix_timeline.add(prefix)
		Simulator.simulate_player_turn(range_board, prefix_timeline, prefix_events)
		actor = range_board.get_unit_by_id(action.actor_id)
		if actor == null:
			return out
		origin = actor.position
	if module.primary_type == GameEnums.EffectType.DASH:
		return dash_line_threat_tiles(range_board, origin, module.max_range)
	for y: int in range(range_board.grid_size.y):
		for x: int in range(range_board.grid_size.x):
			var cell := Vector2i(x, y)
			var distance: int = GridSystem.manhattan(origin, cell)
			if distance >= module.min_range and distance <= module.max_range:
				out.append(cell)
	return out


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
	if ability_has_dash(ability, unit):
		var dash_tiles: Array[Vector2i] = dash_line_threat_tiles(
			board, origin, dash_steps(ability, unit),
		)
		var motion: AbilityModule = active_motion_module(unit, ability)
		if motion != null and motion.min_range > 1:
			dash_tiles = dash_tiles.filter(
				func(cell: Vector2i) -> bool:
					return GridSystem.manhattan(origin, cell) >= motion.min_range
			)
		return dash_tiles
	var eff_range: int = active_range_tiles(unit, ability)
	if eff_range <= 0:
		var shape: GameEnums.TargetShape = active_target_shape(unit, ability)
		var shape_size: int = active_target_shape_size(unit, ability)
		if shape == GameEnums.TargetShape.SINGLE:
			return _single_coord(origin)
		return GridSystem.get_affected_tiles(board, origin, origin, shape, shape_size)
	var sources: Array[Vector2i] = alternate_origins if not alternate_origins.is_empty() else _single_coord(origin)
	var tiles: Array[Vector2i] = manhattan_threat_tiles(board, sources, eff_range)
	var motion_module: AbilityModule = active_motion_module(unit, ability)
	if motion_module == null or motion_module.min_range <= 0:
		if motion_requires_occupied_target(unit, ability):
			tiles = tiles.filter(
				func(cell: Vector2i) -> bool:
					var probe: TimelineAction = TimelineAction.make_ability(
						unit.id, ability, cell, -1,
					)
					return can_use(board, probe)
			)
		return tiles
	var filtered: Array[Vector2i] = tiles.filter(
		func(cell: Vector2i) -> bool:
			return GridSystem.manhattan(origin, cell) >= motion_module.min_range
	)
	if motion_requires_occupied_target(unit, ability):
		filtered = filtered.filter(
			func(cell: Vector2i) -> bool:
				var probe: TimelineAction = TimelineAction.make_ability(
					unit.id, ability, cell, -1,
				)
				return can_use(board, probe)
		)
	return filtered


## Blast footprint at hover for shaped skills (ARC/AOE). Empty when hover is not a legal target.
static func planning_blast_tiles_at_target(
	board: BoardState,
	unit: UnitState,
	ability: AbilityData,
	origin: Vector2i,
	target: Vector2i,
) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if board == null or unit == null or ability == null or not board.is_in_bounds(target):
		return empty
	var shape: GameEnums.TargetShape = active_target_shape(unit, ability)
	var shape_size: int = active_target_shape_size(unit, ability)
	if shape == GameEnums.TargetShape.SINGLE:
		return empty
	var ability_range: int = active_range_tiles(unit, ability)
	if ability_range <= 0:
		return GridSystem.get_affected_tiles(board, origin, origin, shape, shape_size)
	var cast_origin: Vector2i = origin
	if GridSystem.manhattan(cast_origin, target) > ability_range:
		return empty
	var probe: TimelineAction = TimelineAction.make_ability(unit.id, ability, target, -1)
	if not can_use(board, probe):
		return empty
	return GridSystem.get_affected_tiles(board, cast_origin, target, shape, shape_size)


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
	var modules: Array[AbilityModule] = active_modules_for(actor, ability)
	if not modules.is_empty():
		return AbilityModuleBridge.pass_through_modifiers_from_modules(modules)
	return pass_through_modifiers_from(legacy_effects_for(actor, ability))


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
	if (
		_is_spell(ability)
		and actor.passive_flags.get("mana_shield_active", false)
		and not actor.passive_flags.get("mana_shield_casting", false)
	):
		return false
	if (
		_is_spell(ability)
		and actor.passive_flags.get("mana_shield_casting", false)
		and actor.armor <= 0
	):
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


static func ability_uses_attack_animation(ability: AbilityData, actor: UnitState = null) -> bool:
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
	if not active_modules_for(actor, ability).is_empty():
		return active_profile_is_offensive(actor, ability)
	for eff: EffectData in legacy_effects_for(actor, ability):
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


static func _append_module_effects(
	module: AbilityModule,
	effects: Array[EffectData],
	effect_modules: Array[AbilityModule],
) -> void:
	if module == null:
		return
	var compiled: Array[EffectData] = AbilityModuleBridge.compile_module_to_effects(module)
	for effect: EffectData in compiled:
		effects.append(effect)
		effect_modules.append(module)


static func _module_gate_passes(
	module: AbilityModule,
	actor: UnitState,
	events: Array[SimEvent],
	event_start: int,
) -> bool:
	if module == null:
		return false
	match module.gate:
		GameEnums.ModuleGate.ALWAYS:
			return true
		GameEnums.ModuleGate.IF_COLLIDED:
			if actor == null:
				return false
			for event_index: int in range(event_start, events.size()):
				var event: SimEvent = events[event_index]
				if (
					event != null
					and event.type == GameEnums.SimEventType.COLLISION
					and int(event.data.get("pusher_id", -1)) == actor.id
				):
					return true
			return false
		_:
			return false


static func execute(board: BoardState, action: TimelineAction, events: Array[SimEvent]) -> void:
	if not can_use(board, action):
		events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
			"actor": action.actor_id, "reason": "cannot_use_ability",
		}))
		return

	var actor := board.get_unit_by_id(action.actor_id)
	var ability := action.ability
	var wild_magic_repeat := bool(actor.passive_flags.get("__mage_wild_magic_repeat", false))
	var shaman_echo_repeat := bool(actor.passive_flags.get("__shaman_echo_repeat", false))
	
	if actor != null:
		actor.passive_flags.erase("passed_through_terrain")
		actor.passive_flags.erase("passed_through_occupied")
		actor.passive_flags["__current_ability"] = ability
		actor.passive_flags["__engineer_event_start"] = events.size()
		if EngineerSystems.ability_has_explosion(actor, ability):
			actor.passive_flags["engineer_explosion_active"] = true
		RogueSystems.apply_smoke_spell_bonus(board, actor, ability)
		if _is_basic_attack(ability):
			var predatory_target: UnitState = (
				board.get_unit_by_id(action.target_unit_id)
				if action.target_unit_id >= 0
				else board.get_unit_at(action.target_coord)
			)
			if (
				predatory_target != null
				and MercenarySystems._has_predatory_momentum(actor)
				and MercenarySystems._hp_below_threshold(
					predatory_target, MercenarySystems._predatory_threshold(actor),
				)
			):
				actor.passive_flags["predatory_free_move_pending"] = true
		
	if not wild_magic_repeat and not shaman_echo_repeat:
		_spend_ability_cost(actor, ability, board, events)
	if not wild_magic_repeat and not shaman_echo_repeat and _ability_has_modifier(actor, ability, &"limit_once_per_turn"):
		actor.passive_flags["ability_used_once:%s" % ability.id] = true
	if (
		not wild_magic_repeat
		and not shaman_echo_repeat
		and not actor.has_unlimited_training_actions()
		and ability.consumes_action_slot()
		and not _caltrop_expert_waives(actor, ability)
	):
		actor.turn_action_used = true
	if _caltrop_expert_waives(actor, ability):
		actor.passive_flags["caltrop_expert_used"] = true

	if DataLibrary.is_universal_wait(ability.id):
		actor.turn_action_used = true
		return

	if _ability_has_modifier(actor, ability, &"paired_ally_charge"):
		_prepare_paired_charge(board, actor, action, events)

	var target_coord: Vector2i = module_target_coord(action, 0)
	if action.module_target_coords.is_empty():
		target_coord = _resolve_target_coord(board, action)

	var will_skill_walk := false
	if target_coord != actor.position:
		var is_move_check := (
			active_motion_module(actor, ability) != null
			and active_motion_module(actor, ability).primary_type == GameEnums.EffectType.MOVE
		)
		will_skill_walk = (
			(has_pass_through_effects(ability, actor) or is_move_check)
			and not ability_has_dash(ability, actor)
		)

	if not ability_has_movement_effect(ability, actor):
		apply_standing_aim_passives_for_unit(board, actor, events)

	if target_coord != actor.position and not will_skill_walk:
		if not _ability_has_modifier(actor, ability, &"preserve_facing"):
			var new_facing := PhysicsSystem.facing_from_vector(
				PhysicsSystem.cardinal_from_to(actor.position, target_coord),
			)
			if actor.facing != new_facing:
				actor.facing = new_facing
				events.append(SimEvent.make(GameEnums.SimEventType.UNIT_FACED, {"unit": actor.id, "facing": actor.facing}))
	if _is_spell(action.ability) and not wild_magic_repeat:
		_begin_spellcast(board, actor, action, events)
	var shape: GameEnums.TargetShape = active_target_shape(actor, action.ability)
	var shape_size: int = active_target_shape_size(actor, action.ability)
	if _is_spell(action.ability) and shape != GameEnums.TargetShape.SINGLE:
		shape_size += int(actor.passive_flags.get("mage_spell_shape_bonus", 0))
			
	var affected_tiles := GridSystem.get_affected_tiles(board, actor.position, target_coord, shape, shape_size)
	
	var pres_anim: int = resolve_presentation_anim(action.ability, actor)
	BeastRiderSystems.before_ability_execute(board, actor, action)
	events.append(SimEvent.make(GameEnums.SimEventType.ABILITY_USED, {
		"actor": action.actor_id,
		"ability": action.ability.id,
		"ability_name": action.ability.display_name,
		"target_coord": target_coord,
		"target_unit": action.target_unit_id,
		"presentation_anim": pres_anim,
	}))
	
	var runtime_modules: Array[AbilityModule] = active_modules_for(actor, action.ability)
	var legacy_runtime_effects: Array[EffectData] = []
	if runtime_modules.is_empty():
		legacy_runtime_effects = legacy_effects_for(actor, action.ability)
	var effects_to_apply: Array[EffectData] = []
	var effect_modules: Array[AbilityModule] = []
	var module_cursor: int = 0
	var module_event_start: int = events.size()
	if runtime_modules.is_empty():
		effects_to_apply = legacy_runtime_effects
	else:
		while module_cursor < runtime_modules.size():
			var first_module: AbilityModule = runtime_modules[module_cursor]
			module_cursor += 1
			if not _module_gate_passes(first_module, actor, events, module_event_start):
				continue
			_append_module_effects(first_module, effects_to_apply, effect_modules)
			break
	if _ability_has_modifier(actor, ability, &"next_ranged_attack_strength"):
		actor.passive_flags["next_ranged_attack_strength"] = _ability_modifier_int(
			actor, ability, &"next_ranged_attack_strength",
		)

	var cast_cc_snapshot: Dictionary = {}
	if actor != null:
		for unit in board.units:
			if unit != null and unit.is_alive():
				cast_cc_snapshot[unit.id] = (
					unit.has_status(GameEnums.StatusType.ROOT)
					or unit.has_status(GameEnums.StatusType.STAGGER)
				)
		actor.passive_flags["__cast_cc_snapshot"] = cast_cc_snapshot

	var is_move := (
		(
			(
				active_motion_module(actor, ability) != null
				and active_motion_module(actor, ability).primary_type == GameEnums.EffectType.MOVE
			)
			or (
				active_motion_module(actor, ability) == null
				and active_modules_for(actor, ability).is_empty()
				and effect_amount(ability, GameEnums.EffectType.MOVE, actor) > 0
			)
		)
		and not ability_has_post_attack_move(ability, actor)
	)
	if (has_pass_through_effects(ability, actor) or is_move) and not ability_has_dash(ability, actor) and target_coord != actor.position:
		var motion_module: AbilityModule = active_motion_module(actor, ability)
		var walk_steps: int = (
			active_motion_max_range(actor, ability)
			if motion_module != null
			else (
				effect_amount(ability, GameEnums.EffectType.MOVE, actor)
				if active_modules_for(actor, ability).is_empty()
				else 0
			)
		)
		if motion_module != null and not active_motion_range_valid(actor, ability):
			events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
				"actor": actor.id, "reason": "invalid_motion_module_range",
			}))
			return
		if walk_steps <= 0:
			events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
				"actor": actor.id, "reason": "missing_motion_module_range",
			}))
			return
			
		var has_ghost: bool = ability_has_modifier(ability, &"ghost_move", actor)
				
		var ghost_status = null
		if has_ghost:
			ghost_status = DataLibrary.make_status(GameEnums.StatusType.GHOST, 1, 1)
			actor.active_statuses.append(ghost_status)
			actor._recalculate_stats()

		MercenarySystems.before_skill_move(board, actor, ability, events)
		MonkSystems.before_skill_move(board, actor, ability, events)
		RogueSystems.before_skill_move(board, actor, ability, events)
		BeastRiderSystems.before_skill_move(board, actor, ability, events)

		var walk_goal: Vector2i = target_coord
		var goal_unit: UnitState = board.get_unit_at(walk_goal)
		if (
			goal_unit != null
			and goal_unit.team != actor.team
			and not MovementSystem.has_trample(actor)
			and not AbilitySystem.has_pass_through_effects(ability, actor)
		):
			var attack_target: UnitState = (
				board.get_unit_by_id(action.target_unit_id)
				if action.target_unit_id >= 0
				else goal_unit
			)
			if attack_target != null:
				var endpoint: Vector2i = MovementSystem.adjacent_attack_endpoint(
					board, actor, attack_target, ability,
				)
				if endpoint.x >= 0:
					walk_goal = endpoint
			
		MovementSystem.execute_skill_walk(
			board, actor, walk_goal, action.waypoints, ability, events, effects_to_apply, walk_steps
		)
		
		if ghost_status != null:
			actor.active_statuses.erase(ghost_status)
			actor._recalculate_stats()
		MercenarySystems.after_skill_move(board, actor, ability, events)
		MonkSystems.after_skill_move(board, actor, ability, events)
		RogueSystems.after_skill_move(board, actor, ability, events)
		BeastRiderSystems.after_skill_move(board, actor, ability, events)
			
		# Recompute affected tiles after movement since actor position and facing may have changed
		affected_tiles = GridSystem.get_affected_tiles(board, actor.position, target_coord, shape, shape_size)

	var heal_per_target_hit = false
	var buff_per_object = false
	var targets_hit_count = 0
	var objects_destroyed_count = 0
	
	if (
		(
			not runtime_modules.is_empty()
			and AbilityModuleBridge.modules_have_modifier(runtime_modules, &"pull_surfaces")
		)
		or (
			runtime_modules.is_empty()
			and _effects_have_modifier(legacy_runtime_effects, &"pull_surfaces")
		)
	):
		_pull_surfaces_to_center(board, action.target_coord, affected_tiles, events)

	if runtime_modules.is_empty():
		for eff: EffectData in legacy_runtime_effects:
			if eff.modifiers.has("heal_per_target_hit"): heal_per_target_hit = true
			if eff.modifiers.has("buff_per_destroyed_object"): buff_per_object = true
			if eff.modifiers.has("destroy_corpse_on_kill"):
				actor.passive_flags["destroy_corpse_on_kill"] = true
			if eff.modifiers.has("kill_grant_ap"):
				actor.passive_flags["kill_grant_ap"] = int(eff.modifiers["kill_grant_ap"])
			if eff.modifiers.has("next_attack_pierce"):
				actor.passive_flags["breaching_dash_pierce"] = true
			if eff.modifiers.has("on_kill_heal_shield"):
				actor.passive_flags["adrenaline_surge_active"] = true
			if eff.modifiers.has("intercept_grant_str"):
				actor.passive_flags["meat_shield_intercept_str"] = int(eff.modifiers["intercept_grant_str"])
			if eff.modifiers.has("frenzy_on_kill_ap"):
				actor.passive_flags["frenzy_on_kill_ap"] = true
			if eff.modifiers.has("on_kill_max_move"):
				actor.passive_flags["on_kill_max_move"] = int(eff.modifiers["on_kill_max_move"])
	else:
		heal_per_target_hit = AbilityModuleBridge.modules_have_modifier(
			runtime_modules, &"heal_per_target_hit",
		)
		buff_per_object = AbilityModuleBridge.modules_have_modifier(
			runtime_modules, &"buff_per_destroyed_object",
		)
		if AbilityModuleBridge.modules_have_modifier(runtime_modules, &"destroy_corpse_on_kill"):
			actor.passive_flags["destroy_corpse_on_kill"] = true
		if AbilityModuleBridge.modules_have_modifier(runtime_modules, &"kill_grant_ap"):
			actor.passive_flags["kill_grant_ap"] = AbilityModuleBridge.modules_modifier_value(
				runtime_modules, &"kill_grant_ap",
			)
		if AbilityModuleBridge.modules_have_modifier(runtime_modules, &"next_attack_pierce"):
			actor.passive_flags["breaching_dash_pierce"] = true
		if AbilityModuleBridge.modules_have_modifier(runtime_modules, &"on_kill_heal_shield"):
			actor.passive_flags["adrenaline_surge_active"] = true
		if AbilityModuleBridge.modules_have_modifier(runtime_modules, &"intercept_grant_str"):
			actor.passive_flags["meat_shield_intercept_str"] = AbilityModuleBridge.modules_modifier_value(
				runtime_modules, &"intercept_grant_str",
			)
		if AbilityModuleBridge.modules_have_modifier(runtime_modules, &"frenzy_on_kill_ap"):
			actor.passive_flags["frenzy_on_kill_ap"] = true
		if AbilityModuleBridge.modules_have_modifier(runtime_modules, &"on_kill_max_move"):
			actor.passive_flags["on_kill_max_move"] = AbilityModuleBridge.modules_modifier_value(
				runtime_modules, &"on_kill_max_move",
			)

	if buff_per_object:
		for tile_coord in affected_tiles:
			var construct_unit := board.get_unit_at(tile_coord)
			if construct_unit != null and construct_unit.definition.is_construct:
				objects_destroyed_count += 1

	var effect_index: int = 0
	var current_module_end: int = effects_to_apply.size()
	while effect_index < effects_to_apply.size() or module_cursor < runtime_modules.size():
		if effect_index >= current_module_end:
			var queued_next_module := false
			while module_cursor < runtime_modules.size():
				var next_module: AbilityModule = runtime_modules[module_cursor]
				module_cursor += 1
				if not _module_gate_passes(next_module, actor, events, module_event_start):
					continue
				if next_module.gate == GameEnums.ModuleGate.IF_COLLIDED:
					actor.passive_flags["violent_collision_recast_used"] = true
					actor.ability.points_left += 1
					actor.turn_action_used = false
				_append_module_effects(next_module, effects_to_apply, effect_modules)
				current_module_end = effects_to_apply.size()
				queued_next_module = true
				break
			if not queued_next_module:
				break
		var effect: EffectData = effects_to_apply[effect_index]
		var effect_module: AbilityModule = (
			effect_modules[effect_index]
			if effect_index < effect_modules.size()
			else null
		)
		var effect_module_index: int = runtime_modules.find(effect_module)
		var effect_target_coord: Vector2i = target_coord
		if effect_module_index >= 0:
			effect_target_coord = module_target_coord(action, effect_module_index)
			shape = active_target_shape(actor, ability, effect_module_index)
			shape_size = active_target_shape_size(actor, ability, effect_module_index)
			affected_tiles = GridSystem.get_affected_tiles(
				board, actor.position, effect_target_coord, shape, shape_size,
			)
		if (
			effect_module != null
			and effect.type == GameEnums.EffectType.MOVE
			and (
				effect_module.gate != GameEnums.ModuleGate.ALWAYS
				or effect_module.execution_phase == GameEnums.ModulePhase.ON_POST
			)
		):
			if effect_module.min_range < 1 or effect_module.max_range < effect_module.min_range:
				events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
					"actor": actor.id, "reason": "invalid_gated_motion_module_range",
				}))
			else:
				var gated_effects: Array[EffectData] = [effect]
				MovementSystem.execute_skill_walk(
					board,
					actor,
					effect_target_coord,
					action.waypoints,
					ability,
					events,
					gated_effects,
					effect_module.max_range,
				)
				affected_tiles = GridSystem.get_affected_tiles(
					board, actor.position, effect_target_coord, shape, shape_size,
				)
			effect_index += 1
			continue
		if effect.type == GameEnums.EffectType.TELEPORT_CASTER:
			actor.passive_flags["jumped_or_teleported_this_turn"] = true
		if effect.type in [GameEnums.EffectType.DASH, GameEnums.EffectType.TELEPORT_CASTER, GameEnums.EffectType.MOVE_INTO_AND_PUSH]:
			if effect.modifiers.has("paired_ally_charge"):
				if effect.type == GameEnums.EffectType.DASH:
					resolve_pending_pushes(board, events)
				effect_index += 1
				continue
			var departure_tile: Vector2i = actor.position
			_apply_effect_to_tile(
				board,
				actor,
				action,
				effect,
				events,
				effect_target_coord,
				board.get_unit_at(effect_target_coord),
			)
			if effect.modifiers.get("leave_elemental_surface", false):
				_create_elemental_surface(board, actor, action, events, departure_tile)
			if effect.type == GameEnums.EffectType.DASH:
				resolve_pending_pushes(board, events)
			effect_index += 1
			continue
			
		if effect.modifiers.has("belly_flop_push"):
			for dir in GridSystem.DIRECTIONS:
				var adj_coord = actor.position + dir
				var adj_unit = board.get_unit_at(adj_coord)
				_apply_effect_to_tile(board, actor, action, effect, events, adj_coord, adj_unit)
			effect_index += 1
			continue

		if effect.modifiers.has("damage_adjacent_on_landing"):
			if (
				effect.modifiers.get("require_dash_line_enemy", false)
				and int(actor.passive_flags.get("monk_dash_enemy_id", -1)) < 0
			):
				effect_index += 1
				continue
			for dir in GridSystem.DIRECTIONS:
				var adj_coord: Vector2i = actor.position + dir
				var adj_unit: UnitState = board.get_unit_at(adj_coord)
				if adj_unit != null and adj_unit != actor and adj_unit.is_alive() and adj_unit.team != actor.team:
					if (
						effect.modifiers.get("require_dash_line_enemy", false)
						and adj_unit.id != int(actor.passive_flags.get("monk_dash_enemy_id", -1))
					):
						continue
					_apply_effect_to_tile(board, actor, action, effect, events, adj_coord, adj_unit)
			actor.passive_flags.erase("monk_dash_enemy_id")
			effect_index += 1
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
					if effect.modifiers.has("item_collision_str_div"):
						var divisor: int = maxi(1, int(effect.modifiers["item_collision_str_div"]))
						item_dmg = floori(float(actor.current_strength) / float(divisor))
					CombatSystem.deal_damage(
						board, hit_unit, item_dmg, events, &"true", true, false, actor,
						action.ability.display_name, item_dmg,
					)
					if effect.modifiers.has("item_collision_vulnerable"):
						if not CombatSystem.try_resist_crowd_control(
							hit_unit, GameEnums.StatusType.VULNERABLE, events
						):
							hit_unit.active_statuses.append(
								DataLibrary.make_status(GameEnums.StatusType.VULNERABLE, 1)
							)
							hit_unit._recalculate_stats(board)
		if effect.modifiers.has("target_after_move_adjacent"):
			var adjacent_target := board.get_unit_by_id(action.target_unit_id)
			if adjacent_target == null:
				for dir: Vector2i in GridSystem.DIRECTIONS:
					var adj: Vector2i = actor.position + dir
					if not board.is_in_bounds(adj):
						continue
					var adj_unit: UnitState = board.get_unit_at(adj)
					if (
						adj_unit != null
						and adj_unit.is_enemy()
						and adj_unit.is_alive()
						and target_passes_mode(actor, action.ability, adj_unit)
					):
						adjacent_target = adj_unit
						break
			if (
				adjacent_target != null
				and adjacent_target.is_alive()
				and adjacent_target.team != actor.team
				and GridSystem.manhattan(actor.position, adjacent_target.position) == 1
			):
				_apply_effect_to_tile(
					board,
					actor,
					action,
					effect,
					events,
					adjacent_target.position,
					adjacent_target,
				)
			effect_index += 1
			continue
			
		for tile_coord in affected_tiles:
			var target_unit := board.get_unit_at(tile_coord)
			if action.target_unit_id >= 0:
				var pinned_target := board.get_unit_by_id(action.target_unit_id)
				if pinned_target != null and pinned_target.position == tile_coord:
					target_unit = pinned_target
			if effect.modifiers.get("delayed_next_turn", false):
				board.delayed_effects.append({
					"actor_id": actor.id,
					"ability": action.ability,
					"effect": effect.duplicate(true),
					"coord": tile_coord,
				})
				continue
			
			if effect.type == GameEnums.EffectType.DAMAGE and target_unit != null and target_unit != actor and target_unit.is_alive() and heal_per_target_hit:
				targets_hit_count += 1
				
			_apply_effect_to_tile(board, actor, action, effect, events, tile_coord, target_unit)
		effect_index += 1

	if heal_per_target_hit and targets_hit_count > 0:
		CombatSystem.heal(board, actor, targets_hit_count, events)
	if buff_per_object and objects_destroyed_count > 0:
		actor.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 999, objects_destroyed_count))
		actor._recalculate_stats()

	var attack_was_used := false
	for effect: EffectData in effects_to_apply:
		if effect != null and effect.type in [
			GameEnums.EffectType.DAMAGE,
			GameEnums.EffectType.EXPLODE,
			GameEnums.EffectType.RANGED_EXPLODE,
		]:
			attack_was_used = true
			break
	if attack_was_used:
		var post_attack_move_bonus := 0
		for effect: EffectData in effects_to_apply:
			if (
				effect != null
				and effect.type == GameEnums.EffectType.MOVE
				and effect.modifiers.has("post_attack_move")
			):
				post_attack_move_bonus += effect.amount
		actor.movement.points_left += post_attack_move_bonus
		for passive: PassiveData in actor.active_passives:
			if passive == null or not passive.modifiers.has("after_attack_move"):
				continue
			var move_bonus := int(passive.modifiers["after_attack_move"])
			if actor.is_passive_upgraded(passive.id):
				move_bonus = int(
					passive.modifiers.get("upgraded_after_attack_move", move_bonus)
				)
			actor.movement.points_left = mini(
				actor.movement.max_points,
				actor.movement.points_left + move_bonus,
			)
		if _passive_has_modifier(actor, &"zero_move_stealth_range") and actor.movement_points_spent_this_turn == 0 and not actor.passive_flags.get("steady_aim_triggered", false):
			var stealth_range: int = 3
			for passive: PassiveData in actor.active_passives:
				if passive != null and passive.modifiers.has("zero_move_stealth_range"):
					stealth_range = int(passive.modifiers["zero_move_stealth_range"])
					break
			actor.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STEALTH, 1, stealth_range))
			actor._recalculate_stats()
		if actor.has_status(GameEnums.StatusType.CANTO):
			actor.movement.points_left = actor.movement.max_points

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
		if _is_spell(action.ability):
			_finish_spellcast(board, actor, action, events)
			if (
				not wild_magic_repeat
				and actor.passive_flags.get("__mage_wild_magic_pending", false)
			):
				actor.passive_flags.erase("__mage_wild_magic_pending")
				actor.passive_flags["__mage_wild_magic_repeat"] = true
				execute(board, action, events)
				actor.passive_flags.erase("__mage_wild_magic_repeat")
				actor.passive_flags.erase("mage_spell_magic_bonus")
			elif wild_magic_repeat:
				actor.passive_flags.erase("mage_spell_magic_bonus")
			if not actor.passive_flags.get("__mage_wild_magic_repeat", false):
				actor.passive_flags.erase("mage_spell_in_progress")

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

	if actor != null:
		MercenarySystems.after_ability_execute(board, actor, action, events, attack_was_used)
		MonkSystems.after_ability_execute(board, actor, action, events)
		ShamanSystems.after_ability_execute(board, actor, action, events)
		RogueSystems.after_ability_execute(board, actor, action, events)
		BeastRiderSystems.after_ability_execute(board, actor, action, events)
		EngineerSystems.after_ability_execute(board, actor, action, events)

	if actor != null:
		actor.passive_flags.erase("paired_strength_bonus")
		actor.passive_flags.erase("on_kill_max_move")
		actor.passive_flags.erase("paired_ally_id")
		actor.passive_flags.erase("destroy_corpse_on_kill")
		actor.passive_flags.erase("kill_grant_ap")
		actor.passive_flags.erase("mage_spell_pierce")
		actor.passive_flags.erase("mage_spell_range_bonus")
		actor.passive_flags.erase("mage_spell_shape_bonus")


static func execute_delayed_effect(
	board: BoardState,
	delayed: Dictionary,
	events: Array[SimEvent],
) -> void:
	var actor := board.get_unit_by_id(int(delayed.get("actor_id", -1)))
	var ability: AbilityData = delayed.get("ability", null)
	var effect: EffectData = delayed.get("effect", null)
	if actor == null or ability == null or effect == null:
		return
	var coord: Vector2i = delayed.get("coord", actor.position)
	var action := TimelineAction.make_ability(actor.id, ability, coord)
	_apply_effect_to_tile(
		board,
		actor,
		action,
		effect,
		events,
		coord,
		board.get_unit_at(coord),
	)
	if effect.modifiers.get("create_crater", false):
		var crater := DataLibrary._effect(GameEnums.EffectType.CREATE_HAZARD, 0)
		crater.modifiers["terrain_id"] = &"crater"
		crater.modifiers["hazard_duration"] = 2
		_apply_effect_to_tile(
			board,
			actor,
			action,
			crater,
			events,
			coord,
			board.get_unit_at(coord),
		)


static func _create_elemental_surface(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	events: Array[SimEvent],
	coord: Vector2i,
) -> void:
	var surface := DataLibrary._effect(GameEnums.EffectType.CREATE_HAZARD, 0)
	surface.modifiers["terrain_id"] = &"fire"
	surface.modifiers["hazard_duration"] = 1
	surface.modifiers["elemental_surface"] = true
	_apply_effect_to_tile(
		board,
		actor,
		action,
		surface,
		events,
		coord,
		board.get_unit_at(coord),
	)


static func _pull_surfaces_to_center(
	board: BoardState,
	center: Vector2i,
	affected_tiles: Array[Vector2i],
	events: Array[SimEvent],
) -> void:
	for coord: Vector2i in affected_tiles:
		if coord == center:
			continue
		var tile := board.get_tile(coord)
		if tile == null or tile.definition == null:
			continue
		if (
			tile.definition.hazard_damage <= 0
			and not board.terrain_payloads.has(coord)
			and tile.definition.id not in [&"water", &"frozen", &"fire", &"steam"]
		):
			continue
		var center_tile := board.get_tile(center)
		if center_tile == null:
			return
		var previous: TerrainData = board.temporary_terrain_previous.get(
			coord,
			DataLibrary.get_terrain(&"plain"),
		)
		var payload: Dictionary = board.terrain_payloads.get(coord, {}).duplicate(true)
		var surface_definition: TerrainData = tile.definition
		board.set_tile_terrain(coord, previous)
		board.set_tile_terrain(center, surface_definition)
		board.terrain_payloads.erase(coord)
		if not payload.is_empty():
			board.terrain_payloads[center] = payload
		board.temporary_terrain_previous.erase(coord)
		board.temporary_terrain_previous[center] = previous
		events.append(SimEvent.make(GameEnums.SimEventType.TERRAIN_CHANGED, {
			"coord": coord,
			"terrain": previous.id,
			"pulled_to": center,
		}))
		events.append(SimEvent.make(GameEnums.SimEventType.TERRAIN_CHANGED, {
			"coord": center,
			"terrain": surface_definition.id,
			"pulled_from": coord,
		}))
		return


static func _spend_ability_cost(
	actor: UnitState,
	ability: AbilityData,
	board: BoardState = null,
	events: Array[SimEvent] = [],
) -> void:
	if actor == null or ability == null:
		return
		
	var ap_cost = get_action_point_cost(actor, ability, board)
	if RogueSystems.consume_smoke_free_ap(actor, ability):
		ap_cost = 0
	MercenarySystems.consume_next_skill_zero_ap(actor, ability)
	if _is_spell(ability) and actor.passive_flags.get("mana_shield_casting", false):
		actor.armor = maxi(0, actor.armor - 1)
		return
	if _is_spell(ability) and actor.passive_flags.get("mana_well_next_spell", false):
		actor.passive_flags.erase("mana_well_next_spell")
		actor.passive_flags.erase("mana_well_magic_bonus")
	var hp_cost: int = 0
	if ability.primary_resource == GameEnums.CostResource.HP:
		hp_cost = ability.get_active_primary_value(actor.is_ability_upgraded(ability.id))
	elif ability.secondary_resource == GameEnums.CostResource.HP:
		hp_cost = ability.get_active_secondary_value(actor.is_ability_upgraded(ability.id))
	var ritual_sacrifice := (
		actor.ability.points_left < ap_cost
		and ShamanSystems.can_use_ritual_sacrifice(actor, ability)
	)
	if ritual_sacrifice:
		hp_cost = ShamanSystems.ritual_sacrifice_cost(actor)
		actor.passive_flags["shaman_ritual_used_this_turn"] = true
	if hp_cost > 0:
		actor.health.current_hp -= hp_cost
		if ritual_sacrifice:
			ShamanSystems.apply_spiritual_offering_on_hp_spend(board, actor, events)
		events.append(SimEvent.make(GameEnums.SimEventType.UNIT_DAMAGED, {
			"actor": actor.id,
			"source": actor.id,
			"target": actor.id,
			"unit": actor.id,
			"amount": hp_cost,
			"hp": actor.health.current_hp,
			"source_label": "Ability Cost",
		}))
			
	match ability.kind:
		GameEnums.AbilityKind.MOVEMENT_SKILL:
			if _ability_has_modifier(actor, ability, &"cost_all_movement"):
				actor.movement.points_left = 0
			else:
				var mp_spent: int = movement_point_cost(actor, ability)
				actor.movement.points_left -= mp_spent
				actor.movement_points_spent_this_turn += mp_spent
		GameEnums.AbilityKind.UNIVERSAL_RUN:
			actor.ability.points_left -= ap_cost
		GameEnums.AbilityKind.CLASS_SKILL:
			if not ritual_sacrifice:
				actor.ability.points_left -= ap_cost
			if _ability_has_modifier(actor, ability, &"cost_all_movement"):
				actor.movement.points_left = 0
		_:
			pass


## Canonical external-effect entry for shared passive reactions.
static func apply_external_effect(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	effect: EffectData,
	events: Array[SimEvent],
	tile_coord: Vector2i,
	target: UnitState,
) -> void:
	_apply_effect_to_tile(board, actor, action, effect, events, tile_coord, target)


static func _apply_effect_to_tile(board: BoardState, actor: UnitState, action: TimelineAction, effect: EffectData, events: Array[SimEvent], tile_coord: Vector2i, target: UnitState) -> void:
	if (
		effect != null
		and effect.type == GameEnums.EffectType.PUSH
		and actor != null
		and action != null
		and _ability_has_modifier(actor, action.ability, &"kidnap")
	):
		var kidnap_target := board.get_unit_by_id(action.target_unit_id)
		if kidnap_target != null:
			target = kidnap_target
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
			if not friendly and not effect.type in [
				GameEnums.EffectType.ADD_STATUS_SELF,
				GameEnums.EffectType.DAMAGE_SELF,
				GameEnums.EffectType.EXPLODE,
				GameEnums.EffectType.TELEPORT_CASTER,
				GameEnums.EffectType.MOVE_INTO_AND_PUSH,
			]:
				return
		elif actor != null:
			if hostile and target.team == actor.team and not effect.modifiers.has("allow_friendly_target"):
				return
			if friendly and target.team != actor.team and not effect.modifiers.has("enemy_mag_atk"):
				return

	match effect.type:
		GameEnums.EffectType.DAMAGE:
			if target != null:
				if (
					effect.modifiers.has("side_attack_only")
					and not _is_side_attack(actor, target)
				):
					return
				RogueSystems.try_blink_strike(board, actor, target, events, action.ability)
				if effect.modifiers.has("true_damage"):
					CombatSystem.deal_damage(
						board,
						target,
						effect.amount,
						events,
						&"true",
						true,
						false,
						actor,
						action.ability.display_name,
						effect.amount,
					)
					return
				_apply_range_one_attack_passives(board, actor, target, events)
			actor.passive_flags.erase("attack_ignore_def")
			var pierce = false
			if actor.has_passive(&"kinetic_redirection") and actor.is_passive_upgraded(&"kinetic_redirection"):
				if actor.passive_flags.get("kinetic_redirection_stacks", 0) > 0:
					pierce = true
					
			var base_amt := effect.amount
			var temporary_strength_bonus := 0
			var next_ranged_str: int = int(actor.passive_flags.get("next_ranged_attack_strength", 0))
			if next_ranged_str > 0:
				temporary_strength_bonus += next_ranged_str
				actor.passive_flags.erase("next_ranged_attack_strength")
			if actor.has_status(GameEnums.StatusType.STEALTH):
				for stealth_passive: PassiveData in actor.active_passives:
					if (
						stealth_passive != null
						and actor.is_passive_upgraded(stealth_passive.id)
						and stealth_passive.modifiers.has("upgraded_stealth_attack_bonus")
					):
						temporary_strength_bonus += int(
							stealth_passive.modifiers["upgraded_stealth_attack_bonus"]
						)
			var engineer_damage := EngineerSystems.damage_adjustment(
				board, actor, target, effect,
			)
			base_amt += int(engineer_damage.get("amount", 0))
			pierce = pierce or bool(engineer_damage.get("pierce", false))
			if action.ability.scaling_stat == GameEnums.StatType.PHYSICAL:
				base_amt += int(actor.passive_flags.get("weave_physical_bonus", 0))
				if actor.passive_flags.has("weave_physical_bonus"):
					pierce = bool(actor.passive_flags.get("weave_physical_pierce", false))
					actor.passive_flags.erase("weave_physical_bonus")
					actor.passive_flags.erase("weave_physical_pierce")
					MonkSystems.on_weave_consumed(board, actor, tile_coord, events)
			elif action.ability.scaling_stat == GameEnums.StatType.MAGICAL:
				base_amt += int(actor.passive_flags.get("weave_magic_bonus", 0))
				if actor.passive_flags.has("weave_magic_bonus"):
					pierce = bool(actor.passive_flags.get("weave_magic_pierce", false))
					actor.passive_flags.erase("weave_magic_bonus")
					actor.passive_flags.erase("weave_magic_pierce")
					MonkSystems.on_weave_consumed(board, actor, tile_coord, events)
			var reaction_tile := board.get_tile(tile_coord)
			if (
				reaction_tile != null
				and reaction_tile.definition != null
				and effect.modifiers.has("reaction_terrain")
				and reaction_tile.definition.id == effect.modifiers["reaction_terrain"]
			):
				base_amt = int(effect.modifiers.get("reaction_damage", 2))
			var kinetic_energy_bonus := int(actor.passive_flags.get("kinetic_energy", 0))
			if actor.passive_flags.get("mage_spell_pierce", false):
				pierce = true
			if target != null and target.has_status(GameEnums.StatusType.ROOT):
				for passive: PassiveData in actor.active_passives:
					if passive == null or not passive.modifiers.has("gravity_anchor"):
						continue
					var anchor_bonus := int(passive.modifiers["gravity_anchor"])
					if actor.is_passive_upgraded(passive.id):
						anchor_bonus = int(
							passive.modifiers.get("upgraded_gravity_anchor", anchor_bonus)
						)
					base_amt += anchor_bonus
					break
			if kinetic_energy_bonus > 0:
				base_amt += kinetic_energy_bonus
				actor.passive_flags.erase("kinetic_energy")
				actor.passive_flags["kinetic_energy_push"] = true
			if (
				target != null
				and target.team == actor.team
				and effect.modifiers.has("ally_damage_zero")
			):
				base_amt = 0
			
			if effect.modifiers.has("bonus_dmg_per_10_hp"):
				base_amt += floori(actor.health.current_hp / 10.0) * effect.modifiers["bonus_dmg_per_10_hp"]
			if effect.modifiers.has("bonus_dmg_pct_max_hp"):
				base_amt += floori(actor.health.max_hp * float(effect.modifiers["bonus_dmg_pct_max_hp"]))
			if effect.modifiers.has("bonus_dmg_from_terrain") and actor.passive_flags.get("passed_through_terrain", false):
				base_amt += effect.modifiers["bonus_dmg_from_terrain"]
			if effect.modifiers.has("bonus_dmg_from_occupied") and actor.passive_flags.get("passed_through_occupied", false):
				base_amt += effect.modifiers["bonus_dmg_from_occupied"]
			if effect.modifiers.has("damage_multiplier"):
				base_amt *= int(effect.modifiers["damage_multiplier"])
			for passive: PassiveData in actor.active_passives:
				if passive == null:
					continue
				if passive.modifiers.has("straight_line_str_per_tile"):
					temporary_strength_bonus += actor.continuous_straight_tiles_this_turn * int(
						passive.modifiers["straight_line_str_per_tile"]
					)
				if actor.movement_points_spent_this_turn == 0 \
						or actor.passive_flags.get("steady_aim_triggered", false):
					base_amt += int(passive.modifiers.get("zero_move_attack_strength", 0))
					if (
						actor.is_passive_upgraded(passive.id)
						and passive.modifiers.has("upgraded_zero_move_attack_strength")
					):
						base_amt += int(passive.modifiers["upgraded_zero_move_attack_strength"])
					var steady_aim_strength := int(
						passive.modifiers.get("steady_aim_strength", 0)
					)
					if (
						actor.is_passive_upgraded(passive.id)
						and passive.modifiers.has("upgraded_steady_aim_strength")
					):
						steady_aim_strength = int(
							passive.modifiers["upgraded_steady_aim_strength"]
						)
					base_amt += steady_aim_strength
					if (
						actor.is_passive_upgraded(passive.id)
						and passive.modifiers.get("upgraded_steady_aim_pierce", false)
					):
						pierce = true
				if actor.passive_flags.get("corpse_move_empowered", false):
					var corpse_bonus := int(passive.modifiers.get("corpse_move_attack_bonus", 0))
					if actor.is_passive_upgraded(passive.id):
						corpse_bonus = int(
							passive.modifiers.get("upgraded_corpse_move_attack_bonus", corpse_bonus)
						)
					base_amt += corpse_bonus
				if (
					target != null
					and _target_has_movement_penalty(target)
					and passive.modifiers.has("movement_penalty_attack_bonus")
				):
					base_amt += int(passive.modifiers["movement_penalty_attack_bonus"])
				if (
					target != null
					and _target_has_debuff(target)
					and passive.modifiers.has("debuffed_attack_bonus")
				):
					base_amt += int(passive.modifiers["debuffed_attack_bonus"])
				if target != null and passive.modifiers.has("bonus_per_target_status") \
						and actor.is_passive_upgraded(passive.id):
					base_amt += target.active_statuses.size() * int(
						passive.modifiers["bonus_per_target_status"],
					)
				if passive.modifiers.has("physical_scale_higher_stat") \
						and action.ability.scaling_stat == GameEnums.StatType.PHYSICAL:
					temporary_strength_bonus += maxi(0, actor.current_magic - actor.current_strength)
				if actor.movement_points_spent_this_turn == 0 \
						and passive.modifiers.has("zero_move_attack_pierce"):
					pierce = true
				if passive.modifiers.has("moved_tiles_attack_divisor"):
					var divisor := int(passive.modifiers["moved_tiles_attack_divisor"])
					if actor.is_passive_upgraded(passive.id):
						divisor = int(passive.modifiers.get(
							"upgraded_moved_tiles_attack_divisor", divisor,
						))
					if divisor > 0:
						temporary_strength_bonus += actor.movement_points_spent_this_turn / divisor
				if (
					target != null
					and target.id == int(actor.passive_flags.get("vaulted_target_id", -1))
					and passive.modifiers.has("vaulted_attack_bonus")
				):
					var vault_bonus := int(passive.modifiers["vaulted_attack_bonus"])
					if actor.is_passive_upgraded(passive.id):
						vault_bonus = int(passive.modifiers.get(
							"upgraded_vaulted_attack_bonus", vault_bonus,
						))
					base_amt += vault_bonus
				if (
					target != null
					and GridSystem.manhattan(actor.position, target.position) == 2
					and passive.modifiers.has("range_two_bonus_atk")
				):
					base_amt += int(passive.modifiers["range_two_bonus_atk"])
				if (
					target != null
					and GridSystem.manhattan(actor.position, target.position) == 2
					and actor.is_passive_upgraded(passive.id)
				):
					if passive.modifiers.has("upgraded_range_two_strength"):
						base_amt += int(passive.modifiers["upgraded_range_two_strength"])
					elif passive.modifiers.has("range_two_strength"):
						base_amt += int(passive.modifiers["range_two_strength"])
				if (
					not actor.passive_flags.get("plunging_attack_consumed", false)
					and actor.passive_flags.get("jumped_or_teleported_this_turn", false)
					and _is_basic_attack(action.ability)
					and passive.modifiers.has("jump_next_basic_bonus")
				):
					base_amt += int(passive.modifiers["jump_next_basic_bonus"])
					if (
						actor.is_passive_upgraded(passive.id)
						and passive.modifiers.has("upgraded_jump_next_basic_pierce")
					):
						actor.passive_flags["next_attack_pierce"] = true
			if (
				effect.modifiers.has("bonus_atk_vs_fear_or_lower_movement")
				and target != null
				and (
					target.has_status(GameEnums.StatusType.FEAR)
					or target.movement.max_points < actor.movement.max_points
				)
			):
				base_amt += int(effect.modifiers["bonus_atk_vs_fear_or_lower_movement"])
				
			if actor.has_passive(&"blood_for_blood") and actor.is_passive_upgraded(&"blood_for_blood") and actor.passive_flags.get("damaged_last_turn", false):
				base_amt += 1
			base_amt = MercenarySystems.adjust_attack_base(board, actor, target, action.ability, base_amt)
				
			var amount := base_amt
			
			var wpn := 0
			if actor.definition != null and actor.definition.equipped_weapon != null:
				wpn = actor.definition.equipped_weapon.might
			
			var stat_val := actor.current_strength
			var stat_name := "STR"
			
			if action.ability.scaling_stat == GameEnums.StatType.PHYSICAL:
				stat_val = CombatSystem.get_dynamic_strength(board, actor)
			elif action.ability.scaling_stat == GameEnums.StatType.MAGICAL:
				stat_val = actor.current_magic + int(
					actor.passive_flags.get("mage_spell_magic_bonus", 0)
				)
				stat_name = "MAG"
			temporary_strength_bonus += MercenarySystems.attack_strength_bonus(
				board, actor, target, action.ability,
			)
			temporary_strength_bonus += BeastRiderSystems.attack_strength_bonus(
				board, actor, target,
			)
			stat_val += temporary_strength_bonus
				
			if base_amt > 0:
				var raw = (base_amt + wpn) * (1.0 + stat_val / 5.0)
				amount = floori(raw)
			amount += ShamanSystems.damage_bonus(
				board, actor, target, effect, &"ability",
			)
			amount += RogueSystems.damage_bonus(board, actor, target, effect)
			amount += BeastRiderSystems.damage_bonus(board, actor, target, effect)
			amount += MonkSystems.damage_bonus(board, actor, target, effect)
				
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
			if (
				target != null
				and effect.modifiers.get("halve_target_def_one_turn", false)
			):
				var current_def := CombatSystem.get_dynamic_defense(board, target)
				var remaining_def := ceili(float(current_def) / 2.0)
				var reduction := current_def - remaining_def
				if reduction > 0:
					target.active_statuses.append(
						DataLibrary.make_status(
							GameEnums.StatusType.STAT_DEBUFF_DEF, 1, reduction
						)
					)
					target._recalculate_stats()
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
				if (
					GridSystem.manhattan(actor.position, target.position) == 1
					and effect.modifiers.has("range_one_damage_multiplier")
				):
					amount = floori(
						amount * float(effect.modifiers["range_one_damage_multiplier"])
					)
				target_def = CombatSystem.get_dynamic_defense(board, target)
				if action.ability.scaling_stat == GameEnums.StatType.MAGICAL:
					target_def = floori(
						(target_def + target.current_magic) / 2.0
					)
				var tile = board.get_tile(target.position)
				if tile != null and tile.definition != null:
					fort = tile.definition.fortitude
					if _passive_has_modifier(actor, &"ignore_cover"):
						fort = 0
				var attacker_tile := board.get_tile(actor.position)
				if (
					attacker_tile != null
					and attacker_tile.definition != null
					and attacker_tile.definition.elevated
				):
					for passive: PassiveData in actor.active_passives:
						if passive != null and passive.modifiers.has("elevation_def_multiplier"):
							var reduced_def := floori(
								target_def * float(passive.modifiers["elevation_def_multiplier"])
							)
							actor.passive_flags["attack_ignore_def"] = maxi(
								int(actor.passive_flags.get("attack_ignore_def", 0)),
								target_def - reduced_def,
							)
							target_def = floori(
								target_def * float(passive.modifiers["elevation_def_multiplier"])
							)
							break
				vuln = target.has_status(GameEnums.StatusType.VULNERABLE)
				elec = target.has_status(GameEnums.StatusType.ELECTRIFIED)
				if effect.modifiers.has("target_def_set"):
					target_def = int(effect.modifiers["target_def_set"])
				if target.id == int(actor.passive_flags.get("vaulted_target_id", -1)):
					for passive: PassiveData in actor.active_passives:
						if passive == null or not passive.modifiers.has("vaulted_target_ignore_def"):
							continue
						var ignore_def := int(passive.modifiers["vaulted_target_ignore_def"])
						if (
							actor.is_passive_upgraded(passive.id)
							and passive.modifiers.has("upgraded_vaulted_target_ignore_def")
						):
							ignore_def = int(passive.modifiers["upgraded_vaulted_target_ignore_def"])
						actor.passive_flags["attack_ignore_def"] = maxi(
							int(actor.passive_flags.get("attack_ignore_def", 0)),
							ignore_def,
						)
				for passive: PassiveData in actor.active_passives:
					if passive == null:
						continue
					if _is_side_attack(actor, target) and passive.modifiers.has(
						"side_attack_ignore_def"
					):
						var side_ignore := int(passive.modifiers["side_attack_ignore_def"])
						if (
							actor.is_passive_upgraded(passive.id)
							and passive.modifiers.has("upgraded_side_attack_ignore_def")
						):
							side_ignore = int(passive.modifiers["upgraded_side_attack_ignore_def"])
						actor.passive_flags["attack_ignore_def"] = maxi(
							int(actor.passive_flags.get("attack_ignore_def", 0)),
							side_ignore,
						)
						target_def = maxi(
							0,
							target_def - side_ignore,
						)
					if GridSystem.manhattan(actor.position, target.position) == 2:
						var ignore_def := int(passive.modifiers.get("range_two_ignore_def", 0))
						if (
							actor.is_passive_upgraded(passive.id)
							and passive.modifiers.has("upgraded_range_two_ignore_def")
						):
							ignore_def = int(passive.modifiers["upgraded_range_two_ignore_def"])
						if ignore_def > 0:
							actor.passive_flags["attack_ignore_def"] = maxi(
								int(actor.passive_flags.get("attack_ignore_def", 0)),
								ignore_def,
							)
							target_def = maxi(0, target_def - ignore_def)
					if (
						GridSystem.manhattan(actor.position, target.position) == 2
						and actor.is_passive_upgraded(passive.id)
						and passive.modifiers.has("range_two_def_debuff")
					):
						var debuff := int(passive.modifiers["range_two_def_debuff"])
						actor.passive_flags["attack_ignore_def"] = maxi(
							int(actor.passive_flags.get("attack_ignore_def", 0)),
							debuff,
						)
						target_def = maxi(0, target_def - debuff)
					if (
						GridSystem.manhattan(actor.position, target.position)
						>= int(passive.modifiers.get("long_shot_pierce_distance", 999))
						and passive.modifiers.has("long_shot_pierce_distance")
					):
						pierce = true
					if (
						_target_has_movement_penalty(target)
						and passive.modifiers.has("movement_penalty_ignore_def_pct")
					):
						var ignore_pct := float(passive.modifiers["movement_penalty_ignore_def_pct"])
						if (
							actor.is_passive_upgraded(passive.id)
							and passive.modifiers.has("upgraded_movement_penalty_ignore_def_pct")
						):
							ignore_pct = float(passive.modifiers["upgraded_movement_penalty_ignore_def_pct"])
						var movement_ignore := floori(target_def * ignore_pct)
						actor.passive_flags["attack_ignore_def"] = maxi(
							int(actor.passive_flags.get("attack_ignore_def", 0)),
							movement_ignore,
						)
						target_def = maxi(0, target_def - movement_ignore)
					if (
						_target_has_movement_penalty(target)
						and passive.modifiers.has("movement_penalty_ignore_def")
					):
						var movement_ignore := int(passive.modifiers["movement_penalty_ignore_def"])
						if (
							actor.is_passive_upgraded(passive.id)
							and passive.modifiers.has("upgraded_movement_penalty_ignore_def")
						):
							movement_ignore = int(passive.modifiers["upgraded_movement_penalty_ignore_def"])
						actor.passive_flags["attack_ignore_def"] = maxi(
							int(actor.passive_flags.get("attack_ignore_def", 0)),
							movement_ignore,
						)
						target_def = maxi(0, target_def - movement_ignore)
					if (
						_target_has_debuff(target)
						and actor.is_passive_upgraded(passive.id)
						and passive.modifiers.has("upgraded_debuffed_attack_pierce")
					):
						pierce = true
				var merc_ignore_pct: float = MercenarySystems.extra_def_ignore_pct(
					board, actor, target, action.ability,
				)
				if merc_ignore_pct > 0.0:
					var merc_ignore: int = floori(target_def * merc_ignore_pct)
					actor.passive_flags["attack_ignore_def"] = maxi(
						int(actor.passive_flags.get("attack_ignore_def", 0)),
						merc_ignore,
					)
					target_def = maxi(0, target_def - merc_ignore)
				RogueSystems.apply_attack_ignore_def(board, actor, target)
				var strike_mods: Dictionary = MercenarySystems._ability_legacy_mods(actor, action.ability)
				if strike_mods.get("remove_push_mitigation", false):
					target.passive_flags["no_push_mitigation"] = true
				if strike_mods.get("prevent_target_shield", false):
					target.passive_flags["shield_blocked"] = true
				if strike_mods.has("target_def_debuff"):
					target.active_statuses.append(
						DataLibrary.make_status(
							GameEnums.StatusType.STAT_DEBUFF_DEF,
							1,
							int(strike_mods["target_def_debuff"]),
						),
					)
					target._recalculate_stats(board)
				MercenarySystems.apply_feint_on_target(target, actor)

			if actor.passive_flags.has("breaching_dash_pierce"):
				pierce = true
				actor.passive_flags.erase("breaching_dash_pierce")
			if actor.passive_flags.get("next_attack_pierce", false):
				pierce = true
				actor.passive_flags.erase("next_attack_pierce")
			if MercenarySystems.should_pierce(board, actor, target, action.ability):
				pierce = true
			if MonkSystems.should_pierce(board, actor, target):
				pierce = true
			if RogueSystems.should_pierce(board, actor, target, effect):
				pierce = true
			if BeastRiderSystems.should_pierce(board, actor, target, effect):
				pierce = true
			if actor.has_passive(&"unstoppable_mass") and actor.moved_max_movement_this_turn():
				pierce = true
				actor.passive_flags["root_immune_this_turn"] = true
			if (
				target != null
				and GridSystem.manhattan(actor.position, target.position) == 2
				and _has_melee_basic_attack(target)
				and _passive_has_modifier(actor, &"range_two_counter_immunity")
			):
				actor.passive_flags["suppress_melee_counter"] = true
			if actor.has_status(GameEnums.StatusType.PIERCE):
				pierce = true
			if (
				target != null
				and target.passive_flags.get("mark_allies_pierce", false)
				and int(target.passive_flags.get("mark_allies_team", -1)) == actor.team
			):
				pierce = true
			if effect.modifiers.has("target_def_set"):
				pierce = true
			if effect.modifiers.get("pierce_if_first_zero", false) \
					and actor.passive_flags.get("monk_first_hit_zero", false):
				pierce = true
			if effect.modifiers.get("dash_absorb_element", false) \
					and actor.passive_flags.get("passed_through_terrain", false):
				pierce = true
			pierce = CombatSystem.apply_attack_passive_modifiers(
				board, actor, target, pierce
			)
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
				"range_one_damage_multiplier": effect.modifiers.get(
					"range_one_damage_multiplier", 1.0
				),
				"target_def": target_def, "fortitude": fort,
				"vulnerable": vuln, "electrified": elec,
				"pierce": pierce
			}))
			var target_hp_before := target.health.current_hp if target != null else 0
			var target_armor_before := target.armor if target != null else 0
			if effect.modifiers.has("ignore_target_magic_pct"):
				actor.passive_flags["mage_target_magic_ignore_pct"] = float(
					effect.modifiers["ignore_target_magic_pct"]
				)
			if effect.modifiers.has("target_magic_defense"):
				actor.passive_flags["target_magic_defense_override"] = true
			CombatSystem.deal_damage(board, target, amount, events, dmg_type, pierce, false, actor, action.ability.display_name)
			if (
				effect.modifiers.has("armor_explosion_atk")
				and target != null
			):
				var explosion_amount: int = int(effect.modifiers["armor_explosion_atk"])
				for dir: Vector2i in GridSystem.DIRECTIONS:
					var adjacent := board.get_unit_at(target.position + dir)
					if adjacent != null and adjacent.is_alive() and adjacent.team != actor.team:
						var raw := CombatSystem.calculate_scaled_damage(
							actor,
							explosion_amount,
							GameEnums.StatType.PHYSICAL,
							board,
						)
						CombatSystem.deal_damage_raw(
							board,
							actor,
							adjacent,
							raw,
							GameEnums.StatType.PHYSICAL,
							events,
							action.ability.display_name,
							explosion_amount,
						)
			if (
				target != null
				and target.is_alive()
			):
				var paired_strike: int = int(actor.passive_flags.get("paired_ally_strike_atk", 0))
				var paired_id: int = int(actor.passive_flags.get("paired_ally_strike_id", -1))
				if paired_strike > 0 and paired_id >= 0:
					var paired_ally := board.get_unit_by_id(paired_id)
					if paired_ally != null and paired_ally.is_alive():
						var paired_raw := CombatSystem.calculate_scaled_damage(
							paired_ally,
							paired_strike,
							GameEnums.StatType.PHYSICAL,
							board,
						)
						CombatSystem.deal_damage_raw(
							board,
							paired_ally,
							target,
							paired_raw,
							GameEnums.StatType.PHYSICAL,
							events,
							action.ability.display_name,
							paired_strike,
						)
					actor.passive_flags.erase("paired_ally_strike_atk")
			if dmg_type == &"physical":
				CombatSystem.apply_post_attack_push_passives(
					board, actor, target, events, action.ability.id,
				)
			if (
				effect.modifiers.has("heal_per_debuff")
				and target != null
				and target_hp_before > target.health.current_hp
			):
				var siphon_heal := ShamanSystems.unit_debuff_count(target) * int(
					effect.modifiers["heal_per_debuff"],
				)
				if siphon_heal > 0:
					CombatSystem.heal(board, actor, siphon_heal, events)
					ShamanSystems.on_healed(board, actor, actor, siphon_heal, events)
			if effect.modifiers.get("track_first_hit_zero", false):
				actor.passive_flags["monk_first_hit_zero"] = (
					target == null or target_hp_before <= target.health.current_hp
				)
			if target != null and target_hp_before > target.health.current_hp:
				for passive: PassiveData in actor.active_passives:
					if passive == null or not passive.modifiers.has("way_of_the_weaver"):
						continue
					if dmg_type == &"physical":
						actor.passive_flags["weave_magic_bonus"] = int(
							passive.modifiers.get("weave_bonus", 2),
						)
						actor.passive_flags["weave_magic_pierce"] = true
					else:
						actor.passive_flags["weave_physical_bonus"] = int(
							passive.modifiers.get("weave_bonus", 2),
						)
						actor.passive_flags["weave_physical_pierce"] = false
						actor.passive_flags["next_attack_push"] = int(
							passive.modifiers.get("weave_push", 1),
						)
					if actor.is_passive_upgraded(passive.id):
						CombatSystem.add_armor(
							board, actor, int(passive.modifiers.get("weave_shield", 1)), events,
						)
					break
			actor.passive_flags.erase("mage_target_magic_ignore_pct")
			actor.passive_flags.erase("target_magic_defense_override")
			_apply_damage_effect_modifiers(
				board,
				actor,
				target,
				effect,
				events,
				target_hp_before,
				target_armor_before,
			)
			if effect.modifiers.has("bounce_count") and target != null:
				_resolve_chain_lightning(board, actor, target, effect, events)
			if effect.modifiers.has("repeat_hits") and target != null:
				_resolve_repeat_hits(board, actor, target, effect, events)
			if (
				target != null
				and target.is_alive()
				and actor.passive_flags.get("kinetic_energy_push", false)
			):
				actor.passive_flags.erase("kinetic_energy_push")
				PhysicsSystem.push(board, target, PhysicsSystem.cardinal_from_to(actor.position, target.position), 1, events, actor)
			for passive: PassiveData in actor.active_passives:
				if (
					target != null
					and passive != null
					and passive.modifiers.has("range_two_push")
					and GridSystem.manhattan(actor.position, target.position) == 2
					and target.is_alive()
				):
					board.pending_pushes.append({
						"type": "push",
						"target_id": target.id,
						"dir": PhysicsSystem.cardinal_from_to(actor.position, target.position),
						"amount": int(passive.modifiers["range_two_push"]),
						"actor_id": actor.id,
						"ability_id": action.ability.id,
						"stagger_on_collision": passive.modifiers.get(
							"range_two_stagger_on_collision", false
						),
					})
					resolve_pending_pushes(board, events)
					if passive.modifiers.get("range_two_movement_penalty", 0) > 0:
						target.active_statuses.append(
							DataLibrary.make_status(
								GameEnums.StatusType.STAT_DEBUFF_MOV,
								1,
								int(passive.modifiers["range_two_movement_penalty"]),
							)
						)
						target._recalculate_stats(board)
					break
			if effect.modifiers.has("destroy_terrain"):
				var replacement := DataLibrary.get_terrain(&"plain")
				if (
					effect.modifiers.has("ignite_flammable_terrain")
					and board.get_tile(tile_coord) != null
					and board.get_tile(tile_coord).definition.id == &"oil"
				):
					replacement = DataLibrary.get_terrain(&"fire")
				if replacement != null and board.get_tile(tile_coord) != null:
					board.set_tile_terrain(tile_coord, replacement)
					board.terrain_payloads.erase(tile_coord)
					events.append(SimEvent.make(GameEnums.SimEventType.TERRAIN_CHANGED, {
						"coord": tile_coord,
						"terrain": replacement.id,
						"destroyed_by": actor.id,
					}))
			actor.passive_flags.erase("suppress_melee_counter")
			actor.passive_flags.erase("attack_ignore_def")
			if target != null and target.id == int(actor.passive_flags.get("vaulted_target_id", -1)):
				for passive: PassiveData in actor.active_passives:
					if passive != null and passive.modifiers.has("vaulted_target_bleed_weapon"):
						var bleed_amount := 1
						if actor.definition != null and actor.definition.equipped_weapon != null:
							bleed_amount = actor.definition.equipped_weapon.might
						target.active_statuses.append(
							DataLibrary.make_status(GameEnums.StatusType.BLEED, 1, bleed_amount)
						)
						target._recalculate_stats()
						actor.passive_flags.erase("vaulted_target_id")
						break
			if (
				actor.passive_flags.get("jumped_or_teleported_this_turn", false)
				and _is_basic_attack(action.ability)
				and _passive_has_modifier(actor, &"jump_next_basic_bonus")
			):
				actor.passive_flags["plunging_attack_consumed"] = true
			actor.passive_flags.erase("corpse_move_empowered")
			if temp_def_debuff != null and target != null:
				target.active_statuses.erase(temp_def_debuff)
				target._recalculate_stats()
		GameEnums.EffectType.PUSH:
			if target == null and _can_push_destructible_target(
				board,
				actor,
				action.ability,
				null,
				tile_coord,
			):
				var trap_tile := board.get_tile(tile_coord)
				if trap_tile != null and trap_tile.definition != null and trap_tile.definition.id == &"trap":
					var plain := DataLibrary.get_terrain(&"plain")
					if plain != null:
						board.set_tile_terrain(tile_coord, plain)
					CombatSystem.add_armor(board, actor, 2, events)
					if actor.is_passive_upgraded(&"pole_plant"):
						var trap_wpn := 1
						if actor.definition != null and actor.definition.equipped_weapon != null:
							trap_wpn = actor.definition.equipped_weapon.might
						for dir: Vector2i in GridSystem.DIRECTIONS:
							var adjacent := board.get_unit_at(tile_coord + dir)
							if adjacent != null and adjacent.team != actor.team:
								CombatSystem.deal_damage(
									board,
									adjacent,
									trap_wpn,
									events,
									&"true",
									true,
									false,
									actor,
									action.ability.display_name,
									trap_wpn,
								)
					events.append(SimEvent.make(GameEnums.SimEventType.TERRAIN_CHANGED, {
						"coord": tile_coord,
						"terrain": &"plain",
						"destroyed_by": actor.id,
					}))
				return
			if target != null:
				if _ability_has_modifier(actor, action.ability, &"kidnap"):
					var kidnap_target := board.get_unit_by_id(action.target_unit_id)
					if kidnap_target != null:
						target = kidnap_target
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
					var push_amount := effect.amount + _push_synergy_bonus(
						actor, effect, "push_bonus_if_push_used"
					)
					if effect.modifiers.has("push_if_target_on_water"):
						var target_tile := board.get_tile(target.position)
						if (
							target_tile != null
							and target_tile.definition != null
							and target_tile.definition.id == &"water"
						):
							push_amount = maxi(
								push_amount,
								int(effect.modifiers["push_if_target_on_water"]),
							)
					if effect.modifiers.has("enemy_pushed_mov"):
						actor.passive_flags["monk_pushed_enemies"] = int(
							actor.passive_flags.get("monk_pushed_enemies", 0)
						) + 1
					var pending := {
						"type": "push",
						"target_id": target.id,
						"dir": dir,
						"amount": push_amount,
						"actor_id": actor.id,
						"ability_id": action.ability.id
					}
					
					if AbilitySystem.effect_amount(action.ability, GameEnums.EffectType.PUSH_STAGGER_ON_COLLISION, actor) > 0:
						pending["stagger_on_collision"] = true
						
					if AbilitySystem.effect_amount(action.ability, GameEnums.EffectType.PUSH_CHAIN_COLLISION, actor) > 0:
						pending["bowling_upgrade"] = true
					
					board.pending_pushes.append(pending)
		GameEnums.EffectType.PULL:
			if (
				target == null
				and effect.modifiers.has("grapple_wall_pull_self")
				and board.get_tile(tile_coord) != null
				and board.get_tile(tile_coord).definition != null
				and board.get_tile(tile_coord).definition.blocks_movement
			):
				var best_tile := Vector2i(-1, -1)
				var best_distance := 1_000_000
				for dir: Vector2i in GridSystem.DIRECTIONS:
					var adjacent_coord := tile_coord + dir
					if (
						not GridSystem.is_in_bounds(board, adjacent_coord)
						or not GridSystem.is_passable(board, adjacent_coord)
					):
						continue
					var distance_to_actor := GridSystem.manhattan(actor.position, adjacent_coord)
					if distance_to_actor < best_distance:
						best_distance = distance_to_actor
						best_tile = adjacent_coord
				if best_tile != Vector2i(-1, -1):
					var from := actor.position
					GridSystem.set_occupant(board, from, -1)
					actor.position = best_tile
					GridSystem.set_occupant(board, best_tile, actor.id)
					events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
						"actor": actor.id, "from": from, "to": best_tile, "grapple": true,
					}))
				return
			if target != null:
				var grapple_plan := RogueSystems.resolve_grapple_pull(
					board, actor, target, tile_coord, effect,
				)
				if grapple_plan.get("pull_self", false):
					var pull_dest: Vector2i = grapple_plan.get("destination", actor.position)
					if (
						GridSystem.is_in_bounds(board, pull_dest)
						and not GridSystem.is_occupied(board, pull_dest)
					):
						if int(effect.modifiers.get("trap_collision_damage_multiplier", 0)) > 0:
							actor.passive_flags["trap_collision_damage_multiplier"] = int(
								effect.modifiers["trap_collision_damage_multiplier"]
							)
						var from := actor.position
						GridSystem.set_occupant(board, from, -1)
						actor.position = pull_dest
						GridSystem.set_occupant(board, pull_dest, actor.id)
						events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
							"actor": actor.id, "from": from, "to": pull_dest, "grapple": true,
						}))
						TerrainSystem.apply_landing(board, actor, events)
						return
				target = grapple_plan.get("pull_target", target) as UnitState
				if effect.modifiers.has("grapple_pass_through_damage"):
					var grapple_raw := CombatSystem.calculate_scaled_damage(
						actor, 2, GameEnums.StatType.PHYSICAL, board,
					)
					CombatSystem.deal_damage(
						board, target, grapple_raw, events, &"physical", false,
						false, actor, action.ability.display_name, grapple_raw,
					)
				var is_immune := false
				if target.has_passive(&"stand_ground") and not target.has_status(GameEnums.StatusType.VULNERABLE):
					is_immune = true
					if actor != null and actor.team != target.team:
						var stand_amt := 2 if target.is_passive_upgraded(&"stand_ground") else 1
						CombatSystem.counter_attack(board, target, actor, stand_amt, events, "Stand Ground")
				if EngineerSystems.is_pull_immune(board, target):
					is_immune = true
				if target.passive_flags.get("pull_immune_this_turn", false):
					is_immune = true
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
					var pull_amount := effect.amount + _push_synergy_bonus(
						actor, effect, "pull_bonus_if_push_used"
					)
					if effect.modifiers.get("grapple_bidirectional", false) \
							or effect.modifiers.get("pull_until_adjacent", false):
						pull_amount = maxi(0, GridSystem.manhattan(actor.position, target.position) - 1)
					if effect.modifiers.get("trap_collision_damage_multiplier", 0) > 0:
						target.passive_flags["trap_collision_damage_multiplier"] = int(
							effect.modifiers["trap_collision_damage_multiplier"]
						)
					
					var pending := {
						"type": "pull",
						"target_id": target.id,
						"dir": dir,
						"amount": pull_amount,
						"actor_id": actor.id,
						"ability_id": action.ability.id
					}
					
					if AbilitySystem.effect_amount(action.ability, GameEnums.EffectType.PULL_VULNERABLE_ON_ADJACENT, actor) > 0:
						pending["vulnerable_on_adjacent"] = true
					if effect.modifiers.has("stagger_on_collision"):
						pending["stagger_on_collision"] = true
					if effect.modifiers.has("pull_self_if_rooted") and actor.has_status(
						GameEnums.StatusType.ROOT
					):
						pending["pull_actor_to_target"] = true
					elif effect.modifiers.has("pull_self_if_rooted_or_heavier") and (
						actor.has_status(GameEnums.StatusType.ROOT)
						or target.health.max_hp > actor.health.max_hp
					):
						pending["pull_actor_to_target"] = true
						
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
				if effect.modifiers.has("enemy_mag_atk") and target.team != actor.team:
					CombatSystem.deal_mag_atk(
						board,
						actor,
						target,
						int(effect.modifiers["enemy_mag_atk"]),
						events,
						action.ability.display_name,
					)
					return
				if effect.modifiers.has("revive_percent_max_hp"):
					if target.is_alive():
						events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
							"actor": actor.id, "reason": "resurrection_requires_corpse",
						}))
						return
				if effect.modifiers.has("revive_percent_max_hp") and not target.is_alive():
					var self_cost := int(effect.modifiers.get("spend_self_hp", 0))
					if actor.health.current_hp <= self_cost:
						events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
							"actor": actor.id, "reason": "insufficient_resurrection_hp",
						}))
						return
					actor.health.current_hp -= self_cost
					target.health.current_hp = maxi(
						1,
						floori(
							target.health.max_hp
							* float(effect.modifiers["revive_percent_max_hp"])
						),
					)
					target.passive_flags["revived_next_turn"] = true
					if effect.modifiers.has("revive_shield"):
						CombatSystem.add_shield_x(
							board,
							target,
							int(effect.modifiers["revive_shield"]),
							events,
						)
					events.append(SimEvent.make(GameEnums.SimEventType.UNIT_HEALED, {
						"unit": target.id,
						"amount": target.health.current_hp,
						"revived": true,
					}))
					return
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
				var hp_before := target.health.current_hp
				CombatSystem.heal(board, target, heal_amount, events)
				_apply_healing_passive_modifiers(
					board,
					actor,
					target,
					target.health.current_hp - hp_before,
					heal_amount,
					events,
					hp_before,
				)
				ShamanSystems.on_healed(
					board,
					actor,
					target,
					target.health.current_hp - hp_before,
					events,
				)
		GameEnums.EffectType.ARMOR_UP:
			if target != null:
				var shield_amount = effect.amount
				if effect.modifiers.has("mana_shield"):
					shield_amount = actor.current_magic
					actor.passive_flags["mana_shield_active"] = true
					if effect.modifiers.get("mana_shield_casting", false):
						actor.passive_flags["mana_shield_casting"] = true
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
				ShamanSystems.on_spawned(board, actor, construct, effect, action, events)
				events.append(SimEvent.make(GameEnums.SimEventType.UNIT_SPAWNED, {
					"actor": actor.id,
					"unit": construct_id,
					"coord": coord,
				}))
				if effect.modifiers.get("creation_adjacent_damage", false):
					var adjacent_damage := int(effect.modifiers["creation_adjacent_damage"])
					for direction: Vector2i in GridSystem.DIRECTIONS:
						var adjacent := board.get_unit_at(coord + direction)
						if (
							adjacent == null
							or not adjacent.is_alive()
							or adjacent.team == actor.team
						):
							continue
						var raw := CombatSystem.calculate_scaled_damage(
							actor,
							adjacent_damage,
							GameEnums.StatType.MAGICAL,
							board,
						)
						CombatSystem.deal_damage_raw(
							board,
							actor,
							adjacent,
							raw,
							GameEnums.StatType.MAGICAL,
							events,
							action.ability.display_name,
							adjacent_damage,
						)
						if effect.modifiers.has("creation_adjacent_push") and adjacent.is_alive():
							PhysicsSystem.push(
								board,
								adjacent,
								PhysicsSystem.cardinal_from_to(coord, adjacent.position),
								int(effect.modifiers["creation_adjacent_push"]),
								events,
								actor,
							)
				if effect.modifiers.get("holy_aura", false):
					construct.passive_flags["holy_aura"] = true
					construct.passive_flags["holy_aura_owner_id"] = actor.id
				EngineerSystems.on_spawned(board, actor, construct, effect, action, events)
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
				if effect.modifiers.has("link_two_enemies"):
					_link_enemy_pair(board, actor, target, effect, events)
					return
				if effect.modifiers.has("life_link"):
					target.passive_flags["life_link_source_id"] = actor.id
					target.passive_flags["life_link_damage_reduction"] = int(
						effect.modifiers.get("life_link_reduction", 3)
					)
					return
				if effect.status_type in [GameEnums.StatusType.POISON, GameEnums.StatusType.BLEED]:
					var purity_handled := false
					for passive: PassiveData in target.active_passives:
						if passive == null or not passive.modifiers.has("dot_heal"):
							continue
						CombatSystem.heal_x(
							board,
							target,
							int(passive.modifiers["dot_heal"]),
							events,
						)
						target.active_statuses.append(DataLibrary.make_status(
							GameEnums.StatusType.STAT_BUFF_MAG,
							1,
							int(passive.modifiers.get("dot_mag", 1)),
						))
						if (
							passive.modifiers.get("upgraded_dot_cleanse", false)
							and target.is_passive_upgraded(passive.id)
						):
							AbilitySystem.cleanse_unit(target, events)
						target._recalculate_stats(board)
						purity_handled = true
						break
					if purity_handled:
						return
				if ShamanSystems.pre_status_application(
					board, actor, target, effect, events,
				):
					return
				if (
					effect.modifiers.get("status_requires_debuff", false)
					and not _target_has_debuff(target)
				):
					return
				if (
					effect.modifiers.get("cone_all_targets", false)
					and target.team == actor.team
				):
					return
				if (
					target.passive_flags.get("full_health_debuff_immunity", false)
					and GameEnums.is_debuff(effect.status_type)
				):
					return
				if target.has_status(GameEnums.StatusType.INVULNERABLE) and GameEnums.is_debuff(effect.status_type):
					events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
						"actor": target.id, "reason": "status_prevented_by_invulnerable",
					}))
					return
					
				if target.is_boss() and GameEnums.is_debuff(effect.status_type) and effect.status_type in [GameEnums.StatusType.STAGGER, GameEnums.StatusType.ROOT, GameEnums.StatusType.SILENCE, GameEnums.StatusType.PACIFY, GameEnums.StatusType.FEAR, GameEnums.StatusType.CONFUSION, GameEnums.StatusType.POLYMORPH, GameEnums.StatusType.TAUNT]:
					CombatSystem.try_resist_crowd_control(
						target, effect.status_type, events, board, actor,
					)
					return
					
				if CombatSystem.try_resist_crowd_control(target, effect.status_type, events, board, actor):
					return
				if effect.modifiers.get("from_behind_only", false) and not _is_backstab(actor, target):
					return
				if effect.modifiers.get("density_shift", false):
					if target.team == actor.team:
						target.active_statuses.append(
							DataLibrary.make_status(
								GameEnums.StatusType.STURDY,
								effect.status_duration,
							),
						)
					else:
						var mit_tiles := int(target.passive_flags.get("push_mitigation_tiles", 1))
						target.passive_flags["push_mitigation_tiles"] = mit_tiles * 2
					if (
						effect.modifiers.get("apply_weaken_enemy", false)
						and target.team != actor.team
					):
						target.active_statuses.append(DataLibrary.make_status(
							GameEnums.StatusType.WEAKEN,
							effect.status_duration,
							1,
						))
					target._recalculate_stats(board)
					events.append(SimEvent.make(GameEnums.SimEventType.STATUS_APPLIED, {
						"unit": target.id,
						"status_type": GameEnums.StatusType.STURDY
						if target.team == actor.team
						else GameEnums.StatusType.WEAKEN,
						"duration": effect.status_duration,
						"amount": effect.amount,
					}))
					return
					
				var stat_val = effect.amount
				if effect.modifiers.has("weapon_scaled"):
					if actor.definition != null and actor.definition.equipped_weapon != null:
						stat_val = actor.definition.equipped_weapon.might
				if effect.scaling_stat == GameEnums.StatType.DEFENSE:
					stat_val = effect.amount + actor.current_defense
				if effect.modifiers.has("target_def_set"):
					stat_val = target.current_defense
				if effect.modifiers.get("utility_only", false):
					if effect.modifiers.has("grant_ap"):
						target.ability.points_left = mini(
							target.ability.max_points,
							target.ability.points_left + int(effect.modifiers["grant_ap"]),
						)
					if effect.modifiers.has("cooldown_reduction"):
						target.passive_flags["cooldown_reduction"] = int(
							target.passive_flags.get("cooldown_reduction", 0)
						) + int(effect.modifiers["cooldown_reduction"])
					return
				var delayed_move := effect.modifiers.has("next_turn") or effect.modifiers.has(
					"next_turn_max_move"
				)
				if (
					effect.modifiers.get("next_turn", false)
					and effect.status_type == GameEnums.StatusType.CONFUSION
				):
					target.passive_flags["confusion_next_turn"] = true
					events.append(SimEvent.make(GameEnums.SimEventType.STATUS_APPLIED, {
						"unit": target.id,
						"status_type": effect.status_type,
						"duration": effect.status_duration,
						"amount": effect.amount,
						"next_turn": true,
					}))
					return
				if delayed_move and effect.status_type == GameEnums.StatusType.STAT_BUFF_MOV:
					target.passive_flags["next_turn_max_move_bonus"] = int(
						target.passive_flags.get("next_turn_max_move_bonus", 0)
					) + stat_val
					if effect.modifiers.has("upgraded_trample"):
						target.passive_flags["next_turn_trample"] = true
				else:
					var status := StatusData.new(effect.status_type, effect.status_duration, stat_val)
					target.active_statuses.append(status)
					if effect.modifiers.get("mantra_peace_weaken", false):
						target.passive_flags["mantra_weaken"] = true
					if (
						effect.modifiers.get("apply_weaken_enemy", false)
						and target.team != actor.team
					):
						target.active_statuses.append(DataLibrary.make_status(
							GameEnums.StatusType.WEAKEN,
							effect.status_duration,
							1,
						))
					if effect.modifiers.get("curse_of_weakness", false):
						target.active_statuses.append(DataLibrary.make_status(
							GameEnums.StatusType.STAT_DEBUFF_DEF,
							effect.status_duration,
							2,
						))
					target._recalculate_stats()
					if (
						effect.modifiers.has("set_max_move")
						and not target.passive_flags.get("slow_immune_this_turn", false)
					):
						var move_cap: int = int(effect.modifiers["set_max_move"])
						target.movement.max_points = mini(target.movement.max_points, move_cap)
						target.movement.points_left = mini(target.movement.points_left, move_cap)
				events.append(SimEvent.make(GameEnums.SimEventType.STATUS_APPLIED, {
					"unit": target.id,
					"status_type": effect.status_type,
					"duration": effect.status_duration,
					"amount": effect.amount,
				}))
				if GameEnums.is_debuff(effect.status_type):
					RogueSystems.on_debuff_applied(board, actor, target, events)
				if effect.modifiers.has("grant_ap"):
					target.ability.points_left += int(effect.modifiers["grant_ap"])
				if effect.modifiers.has("self_move_zero_next_turn"):
					actor.passive_flags["next_turn_move_zero"] = true
				if effect.modifiers.has("self_root_immune_next_turn"):
					actor.passive_flags["next_turn_root_immune"] = true
				if effect.modifiers.has("counterattack_melee"):
					target.passive_flags["counterattack_melee"] = true
				if effect.modifiers.has("counterattack_on_intercept"):
					target.passive_flags["counterattack_on_intercept"] = true
				if effect.modifiers.has("upgraded_trample"):
					target.active_statuses.append(
						DataLibrary.make_status(GameEnums.StatusType.TRAMPLE, 1, 0)
					)
					target._recalculate_stats()
				if effect.modifiers.has("spread_status_adjacent"):
					for dir: Vector2i in GridSystem.DIRECTIONS:
						var adjacent := board.get_unit_at(target.position + dir)
						if (
							adjacent != null
							and adjacent.is_alive()
							and adjacent.team != actor.team
						):
							adjacent.active_statuses.append(StatusData.new(
								effect.status_type,
								effect.status_duration,
								stat_val,
							))
							adjacent._recalculate_stats()
							events.append(SimEvent.make(GameEnums.SimEventType.STATUS_APPLIED, {
								"unit": adjacent.id,
								"status_type": effect.status_type,
								"duration": effect.status_duration,
								"amount": stat_val,
								"spread": true,
							}))
				if effect.modifiers.has("prevent_stealth_teleport"):
					target.passive_flags["marked_no_stealth_teleport"] = true
				if effect.modifiers.has("allies_range_bonus"):
					target.passive_flags["mark_allies_range"] = int(effect.modifiers["allies_range_bonus"])
					target.passive_flags["mark_allies_team"] = actor.team
				if effect.modifiers.has("allies_pierce"):
					target.passive_flags["mark_allies_pierce"] = true
					target.passive_flags["mark_allies_team"] = actor.team
				if effect.modifiers.has("armor_explosion_atk"):
					var explosion_amount: int = int(effect.modifiers["armor_explosion_atk"])
					for dir: Vector2i in GridSystem.DIRECTIONS:
						var adjacent := board.get_unit_at(target.position + dir)
						if adjacent != null and adjacent.is_alive() and adjacent.team != actor.team:
							var raw := CombatSystem.calculate_scaled_damage(
								actor,
								explosion_amount,
								GameEnums.StatType.PHYSICAL,
								board,
							)
							CombatSystem.deal_damage_raw(
								board,
								actor,
								adjacent,
								raw,
								GameEnums.StatType.PHYSICAL,
								events,
								action.ability.display_name,
								explosion_amount,
							)
		GameEnums.EffectType.CLEANSE:
			if target != null:
				var removed_count := cleanse_unit(target, events)
				if effect.modifiers.has("ally_str_per_debuff") and removed_count > 0:
					target.active_statuses.append(DataLibrary.make_status(
						GameEnums.StatusType.STAT_BUFF_STR,
						1,
						removed_count * int(effect.modifiers["ally_str_per_debuff"]),
					))
					target._recalculate_stats()
		GameEnums.EffectType.PURGE:
			if target != null:
				purge_unit(target, events)
		GameEnums.EffectType.DASH:
			var dir := PhysicsSystem.straight_line_dir(actor.position, action.target_coord)
			var dash_steps := PhysicsSystem.straight_line_distance(actor.position, action.target_coord)
			if dir != Vector2i.ZERO and dash_steps >= 1 and dash_steps <= effect.amount:
				if effect.modifiers.get("stop_adjacent_first_enemy", false):
					actor.passive_flags.erase("monk_dash_enemy_id")
					for step_index: int in range(1, dash_steps + 1):
						var cell := actor.position + dir * step_index
						var occupant := board.get_unit_at(cell)
						if occupant != null and occupant.team != actor.team and occupant.is_alive():
							actor.passive_flags["monk_dash_enemy_id"] = occupant.id
							dash_steps = step_index - 1
							break
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
				var runtime_profile: Array[AbilityModule] = active_modules_for(actor, action.ability)
				if not runtime_profile.is_empty():
					push_amt += _module_push_synergy_bonus(
						actor,
						runtime_profile,
						&"push_bonus_if_push_used",
					)
					if trample_atk <= 0:
						trample_atk = effect_amount(
							action.ability,
							GameEnums.EffectType.DAMAGE,
							actor,
						)
				else:
					for candidate: EffectData in legacy_effects_for(actor, action.ability):
						if candidate != null and candidate.type == GameEnums.EffectType.PUSH:
							push_amt += _push_synergy_bonus(
								actor,
								candidate,
								&"push_bonus_if_push_used",
							)
							if trample_atk <= 0:
								for damage_effect: EffectData in legacy_effects_for(actor, action.ability):
									if damage_effect != null and damage_effect.type == GameEnums.EffectType.DAMAGE:
										trample_atk = damage_effect.amount
										break
							break
				if trample_atk > 0:
					pending["trample_atk"] = trample_atk
				if effect.modifiers.has("line_breaker"):
					pending["trample_atk"] = 2
					pending["line_breaker"] = true
				if push_amt > 0:
					pending["trample_push"] = push_amt
				if bulldoze > 0:
					pending["bulldoze"] = bulldoze
					pending["caster_collision_immune"] = true
				if AbilitySystem.effect_amount(action.ability, GameEnums.EffectType.PUSH_CHAIN_COLLISION, actor) > 0:
					pending["bowling_upgrade"] = true
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
		GameEnums.EffectType.MOVE:
			if effect.modifiers.get("relocate_target", false):
				var subject := target
				if subject == null and action.target_unit_id >= 0:
					subject = board.get_unit_by_id(action.target_unit_id)
				if subject == null or subject.team != actor.team:
					events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
						"actor": actor.id, "reason": "relocate_missing_subject",
					}))
					return
				var is_totem := subject.passive_flags.has("shaman_totem_owner_id")
				if is_totem and not effect.modifiers.get("move_active_totem", false):
					events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
						"actor": actor.id, "reason": "relocate_totem_requires_upgrade",
					}))
					return
				var max_steps := 2 if is_totem else 1
				var relocate_dest := tile_coord
				if (
					GridSystem.is_occupied(board, relocate_dest)
					or GridSystem.is_wall(board, relocate_dest)
					or GridSystem.manhattan(subject.position, relocate_dest) > max_steps
					or GridSystem.manhattan(subject.position, relocate_dest) < 1
				):
					events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
						"actor": actor.id, "reason": "relocate_invalid_destination",
					}))
					return
				GridSystem.set_occupant(board, subject.position, -1)
				subject.position = relocate_dest
				GridSystem.set_occupant(board, relocate_dest, subject.id)
				events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
					"unit": subject.id, "to": relocate_dest,
				}))
				return
		GameEnums.EffectType.TELEPORT_CASTER:
			if effect.modifiers.get("reposition_opposite_side", false):
				return
			var destination := tile_coord
			if effect.modifiers.get("land_opposite_target", false):
				if target == null:
					events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
						"actor": actor.id, "reason": "vault_missing_target",
					}))
					return
				var opposite_dir := PhysicsSystem.cardinal_from_to(actor.position, target.position)
				destination = target.position + opposite_dir
				if (
					opposite_dir == Vector2i.ZERO
					or not GridSystem.is_in_bounds(board, destination)
					or GridSystem.is_occupied(board, destination)
					or GridSystem.is_wall(board, destination)
				):
					events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
						"actor": actor.id, "reason": "vault_no_landing",
					}))
					return
			elif effect.modifiers.has("warp_adjacent_to_target"):
				if target == null:
					events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
						"actor": actor.id, "reason": "guardian_step_missing_ally",
					}))
					return
				destination = _first_empty_adjacent_cell(board, target.position)
				if destination == Vector2i(-1, -1):
					events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
						"actor": actor.id, "reason": "guardian_step_no_landing",
					}))
					return
			elif effect.modifiers.has("motion_mode"):
				if effect.modifiers.get("reposition_opposite_side", false):
					destination = BeastRiderSystems.resolve_reposition_destination(
						board, actor, target,
					)
				else:
					destination = RogueSystems.resolve_teleport_destination(
						board,
						actor,
						target,
						tile_coord,
						int(effect.modifiers["motion_mode"]),
					)
				if destination == Vector2i(-1, -1):
					events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
						"actor": actor.id, "reason": "teleport_no_landing",
					}))
					return
			if not GridSystem.is_occupied(board, destination) and not GridSystem.is_wall(board, destination):
				if effect.modifiers.has("vault_over"):
					var vault_dir := PhysicsSystem.straight_line_dir(actor.position, destination)
					var vault_distance := PhysicsSystem.straight_line_distance(
						actor.position,
						destination,
					)
					for step_index: int in range(1, vault_distance):
						var vaulted := board.get_unit_at(actor.position + vault_dir * step_index)
						if vaulted != null and vaulted.team != actor.team:
							if effect.modifiers.get("vault_obstacle_or_gap_only", false):
								events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
									"actor": actor.id, "reason": "vault_over_enemy",
								}))
								return
							actor.passive_flags["vaulted_target_id"] = vaulted.id
							break
				GridSystem.set_occupant(board, actor.position, -1)
				actor.position = destination
				GridSystem.set_occupant(board, actor.position, actor.id)
				events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
					"unit": actor.id, "to": actor.position
				}))
				if actor.passive_flags.has("vaulted_target_id"):
					MonkSystems.on_moved_through_enemy(
						board,
						actor,
						[int(actor.passive_flags["vaulted_target_id"])],
						events,
					)
				if effect.modifiers.has("cleanse_target"):
					cleanse_unit(target, events)
				var landing_push: int = int(effect.modifiers.get("landing_adjacent_push", 0))
				if landing_push <= 0 and actor.passive_flags.get("push_used_this_turn", false):
					landing_push = int(
						effect.modifiers.get("landing_adjacent_push_if_push_used", 0)
					)
				if landing_push > 0:
					for dir: Vector2i in GridSystem.DIRECTIONS:
						var adjacent := board.get_unit_at(actor.position + dir)
						if adjacent == null or adjacent.team == actor.team:
							continue
						board.pending_pushes.append({
							"type": "push",
							"target_id": adjacent.id,
							"dir": dir,
							"amount": landing_push,
							"actor_id": actor.id,
							"ability_id": action.ability.id,
							"stagger_on_collision": effect.modifiers.get(
								"landing_adjacent_push_stagger", false
							),
						})
				for passive: PassiveData in actor.active_passives:
					if passive == null or not passive.modifiers.has("landing_adjacent_push"):
						continue
					var crash_push: int = int(passive.modifiers["landing_adjacent_push"])
					for dir: Vector2i in GridSystem.DIRECTIONS:
						var adjacent := board.get_unit_at(actor.position + dir)
						if adjacent == null or adjacent.team == actor.team:
							continue
						board.pending_pushes.append({
							"type": "push",
							"target_id": adjacent.id,
							"dir": dir,
							"amount": crash_push,
							"actor_id": actor.id,
							"ability_id": action.ability.id,
							"stagger_on_collision": actor.is_passive_upgraded(passive.id)
							and passive.modifiers.has("upgraded_landing_collision_stagger"),
						})
				RogueSystems.after_teleport(board, actor, target, action.ability, events)
		GameEnums.EffectType.CHANGE_TERRAIN:
			# Amount parameter can be used to select terrain type, for now just hardcode cracked
			var terrain_id = &"cracked"
			var tile = board.writable_tile(tile_coord)
			if tile != null:
				var new_def = DataLibrary.get_terrain(terrain_id)
				if new_def != null:
					tile.definition = new_def
					events.append(SimEvent.make(GameEnums.SimEventType.TERRAIN_CHANGED, {
						"coord": tile_coord, "terrain": terrain_id
					}))
		GameEnums.EffectType.CREATE_HAZARD:
			var terrain_id: StringName = effect.modifiers.get("terrain_id", &"spear_wall")
			var previous_tile := board.get_tile(tile_coord)
			var reacted_to_terrain := false
			if (
				previous_tile != null
				and previous_tile.definition != null
				and effect.modifiers.has("reaction_terrain")
				and previous_tile.definition.id == effect.modifiers["reaction_terrain"]
			):
				terrain_id = &"steam"
				reacted_to_terrain = true
			var terrain := DataLibrary.get_terrain(terrain_id)
			if terrain != null:
				if not board.temporary_terrain_previous.has(tile_coord):
					var current_tile := board.get_tile(tile_coord)
					if current_tile != null:
						board.temporary_terrain_previous[tile_coord] = current_tile.definition
				board.set_tile_terrain(tile_coord, terrain)
				var duration := int(effect.modifiers.get("hazard_duration", 1))
				for passive: PassiveData in actor.active_passives:
					if passive == null or not passive.modifiers.has("lasting_terrain_duration"):
						continue
					duration += int(passive.modifiers["lasting_terrain_duration"])
					break
				board.temporary_terrain_turns[tile_coord] = duration
				var terrain_payload := effect.modifiers.duplicate(true)
				for passive: PassiveData in actor.active_passives:
					if passive == null or not passive.modifiers.has("lasting_terrain_damage"):
						continue
					var hazard_bonus := int(passive.modifiers["lasting_terrain_damage"])
					if actor.is_passive_upgraded(passive.id):
						hazard_bonus = int(
							passive.modifiers.get("upgraded_lasting_terrain_damage", hazard_bonus)
						)
					terrain_payload["hazard_damage_bonus"] = hazard_bonus
					break
				 
				for passive: PassiveData in actor.active_passives:
					if passive == null or not passive.modifiers.has("feedback_magic"):
						continue
					actor.active_statuses.append(DataLibrary.make_status(
						GameEnums.StatusType.STAT_BUFF_MAG,
						1,
						int(passive.modifiers["feedback_magic"]),
					))
					CombatSystem.add_armor(
						board,
						actor,
						int(passive.modifiers.get(
							"upgraded_feedback_shield"
							if actor.is_passive_upgraded(passive.id)
							else "feedback_shield",
							1,
						)),
						events,
					)
					actor._recalculate_stats(board)
					break
				if (
					terrain_payload.get("crossing_weapon_damage", false)
					or terrain_payload.get("created_area_weapon_damage", false)
				):
					terrain_payload["weapon_damage_owner"] = actor.id
				if terrain_payload.get("sanctuary", false) or terrain_payload.get("holy_ground", false):
					terrain_payload["terrain_owner_id"] = actor.id
				if terrain_payload.get("elemental_surface", false):
					terrain_payload["terrain_owner_id"] = actor.id
				for passive: PassiveData in actor.active_passives:
					if passive == null:
						continue
					if passive.modifiers.has("created_area_root"):
						terrain_payload["created_area_root"] = true
					if passive.modifiers.has("created_area_weapon_damage"):
						terrain_payload["created_area_weapon_damage"] = true
					if (
						actor.is_passive_upgraded(passive.id)
						and passive.modifiers.has("created_area_poison")
					):
						terrain_payload["created_area_poison"] = true
					if passive.modifiers.has("created_difficult_terrain_extra_mp"):
						terrain_payload["created_difficult_terrain_extra_mp"] = int(
							passive.modifiers["created_difficult_terrain_extra_mp"]
						)
					if passive.modifiers.has("created_difficult_terrain_remove_fear"):
						terrain_payload["created_difficult_terrain_remove_fear"] = true
					if (
						actor.is_passive_upgraded(passive.id)
						and passive.modifiers.has("created_difficult_terrain_root")
					):
						terrain_payload["created_difficult_terrain_root"] = true
					if (
						effect.modifiers.get("terrain_id", &"") == &"caltrop_trap"
						and passive.modifiers.has("caltrop_damage_bonus")
						and actor.is_passive_upgraded(passive.id)
					):
						terrain_payload["trap_damage_bonus"] = int(
							passive.modifiers["caltrop_damage_bonus"]
						)
				if terrain_id == &"smoke" or terrain_payload.get("smoke_field", false):
					terrain_payload["terrain_owner_id"] = actor.id
				if _ability_has_modifier(actor, action.ability, &"hazard_blind_on_entry"):
					terrain_payload["hazard_blind_on_entry"] = true
				board.terrain_payloads[tile_coord] = terrain_payload
				MonkSystems.on_terrain_created(board, actor, tile_coord, events)
				var standing_unit := board.get_unit_at(tile_coord)
				if (
					standing_unit != null
					and standing_unit.team != actor.team
					and terrain_id in [&"fire", &"frozen"]
				):
					for passive: PassiveData in actor.active_passives:
						if passive == null or not passive.modifiers.has("elementalist"):
							continue
						var weapon_damage := 0
						if actor.definition != null and actor.definition.equipped_weapon != null:
							weapon_damage = actor.definition.equipped_weapon.might
						if actor.is_passive_upgraded(passive.id) and weapon_damage > 0:
							CombatSystem.deal_damage(
								board,
								standing_unit,
								weapon_damage,
								events,
								&"true",
								true,
								false,
								actor,
								"Elementalist",
								weapon_damage,
							)
						break
				if (
					standing_unit != null
					and standing_unit.team == actor.team
					and terrain_payload.get("sanctuary", false)
				):
					standing_unit.active_statuses.append(DataLibrary.make_status(
						GameEnums.StatusType.STEALTH, 1
					))
					standing_unit.active_statuses.append(DataLibrary.make_status(
						GameEnums.StatusType.INVULNERABLE, 1
					))
				if (
					reacted_to_terrain
					and terrain_id == &"steam"
					and effect.modifiers.get("reaction_steam_splash", false)
				):
					var splash_size := int(effect.modifiers.get("reaction_steam_splash_size", 1))
					var splash_power := int(effect.modifiers.get("reaction_steam_splash_damage", 2))
					var splash_coords := GridSystem.get_affected_tiles(
						board,
						tile_coord,
						tile_coord,
						GameEnums.TargetShape.AOE_SQUARE,
						splash_size,
					)
					for splash_coord: Vector2i in splash_coords:
						var splash_target := board.get_unit_at(splash_coord)
						if splash_target == null or splash_target.team == actor.team:
							continue
						var splash_amount := CombatSystem.calculate_scaled_damage(
							actor, splash_power, GameEnums.StatType.MAGICAL, board,
						)
						CombatSystem.deal_damage(
							board,
							splash_target,
							splash_amount,
							events,
							&"magical",
							false,
							false,
							actor,
							"Steam Splash",
							splash_amount,
						)
				events.append(SimEvent.make(GameEnums.SimEventType.TERRAIN_CHANGED, {
					"coord": tile_coord,
					"terrain": terrain_id,
					"temporary_turns": board.temporary_terrain_turns[tile_coord],
				}))
		GameEnums.EffectType.REFUND_AP_ON_CC:
			if target != null and actor != null:
				var snap: Variant = actor.passive_flags.get("__cast_cc_snapshot", null)
				var had_cc_at_cast: bool = snap is Dictionary and snap.get(target.id, false)
				if had_cc_at_cast:
					actor.ability.points_left = mini(actor.ability.max_points, actor.ability.points_left + 1)

		GameEnums.EffectType.ADD_STATUS_SELF:
			if effect.modifiers.get("utility_only", false):
				if effect.modifiers.has("elemental_surge"):
					actor.passive_flags["elemental_surge_ready"] = true
				if effect.modifiers.has("elemental_surge_ap"):
					actor.ability.points_left = mini(
						actor.ability.max_points,
						actor.ability.points_left + int(effect.modifiers["elemental_surge_ap"]),
					)
				return
			if actor.has_status(GameEnums.StatusType.INVULNERABLE) and GameEnums.is_debuff(effect.status_type):
				events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
					"actor": actor.id, "reason": "status_prevented_by_invulnerable",
				}))
				return
			if effect.status_type == GameEnums.StatusType.RUNNING:
				_apply_running_boost(actor, events)
				return
			if effect.modifiers.has("chakra_shift"):
				actor.passive_flags["chakra_shift_turns"] = 2
				actor._recalculate_stats(board)
				events.append(SimEvent.make(GameEnums.SimEventType.STATUS_APPLIED, {
					"unit": actor.id,
					"status_type": GameEnums.StatusType.NONE,
					"duration": 2,
					"amount": 0,
				}))
				if effect.modifiers.has("chakra_burst_damage"):
					var burst := DataLibrary._effect(
						GameEnums.EffectType.DAMAGE,
						int(effect.modifiers["chakra_burst_damage"]),
					)
					burst.scaling_stat = GameEnums.StatType.MAGICAL
					for burst_coord: Vector2i in GridSystem.get_affected_tiles(
						board, actor.position, actor.position,
						GameEnums.TargetShape.AOE_CROSS,
						int(effect.modifiers.get("chakra_burst_size", 2)),
					):
						_apply_effect_to_tile(
							board, actor, action, burst, events,
							burst_coord, board.get_unit_at(burst_coord),
						)
				return
			var status := StatusData.new(effect.status_type, effect.status_duration, effect.amount)
			actor.active_statuses.append(status)
			if effect.status_type == GameEnums.StatusType.INTERCEPT and action.target_unit_id >= 0 and action.target_unit_id != actor.id:
				actor.passive_flags["intercept_ward_id"] = action.target_unit_id
				actor.passive_flags["intercept_range"] = maxi(1, action.ability.range_tiles)
			if effect.modifiers.has("brace_attacker_stagger"):
				actor.passive_flags["braced_attacker_stagger"] = true
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


static func _push_synergy_bonus(actor: UnitState, effect: EffectData, modifier_key: StringName) -> int:
	if actor == null or effect == null:
		return 0
	if not actor.passive_flags.get("push_used_this_turn", false):
		return 0
	return int(effect.modifiers.get(modifier_key, 0))


static func _module_push_synergy_bonus(
	actor: UnitState,
	modules: Array[AbilityModule],
	modifier_key: StringName,
) -> int:
	if actor == null or not actor.passive_flags.get("push_used_this_turn", false):
		return 0
	for module: AbilityModule in modules:
		if module == null:
			continue
		if module.primary_type == GameEnums.EffectType.PUSH:
			return AbilityModuleBridge.module_modifier_value(module, modifier_key)
		for layer: AbilityLayer in module.layers:
			if (
				layer != null
				and layer.effect != null
				and layer.effect.type == GameEnums.EffectType.PUSH
			):
				return int(layer.effect.modifiers.get(modifier_key, 0))
	return 0


static func _effects_have_modifier(effects: Array[EffectData], key: StringName) -> bool:
	for effect: EffectData in effects:
		if effect != null and effect.modifiers.has(key):
			return true
	return false


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
	if action == null:
		return null
	var actor := board.get_unit_by_id(action.actor_id)
	if _ability_has_modifier(actor, action.ability, &"paired_ally_charge"):
		return board.get_unit_at(action.target_coord)
	if action.target_unit_id >= 0:
		return board.get_unit_by_id(action.target_unit_id)
	return board.get_unit_at(action.target_coord)


static func _prepare_paired_charge(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	events: Array[SimEvent],
) -> void:
	var ally := board.get_unit_by_id(action.target_unit_id)
	var enemy := board.get_unit_at(action.target_coord)
	if ally == null or enemy == null or not ally.is_alive() or not enemy.is_alive():
		return
	var strike_atk: int = _ability_modifier_int(
		actor, action.ability, &"paired_ally_strike_atk"
	)
	if strike_atk > 0:
		actor.passive_flags["paired_ally_strike_id"] = ally.id
		actor.passive_flags["paired_ally_strike_atk"] = strike_atk
	if _ability_has_modifier(actor, action.ability, &"on_kill_both_ap"):
		actor.passive_flags["paired_ally_id"] = ally.id
	var candidates: Array[Vector2i] = []
	var preferred := PhysicsSystem.cardinal_from_to(enemy.position, actor.position)
	var directions: Array[Vector2i] = [preferred]
	for dir: Vector2i in GridSystem.DIRECTIONS:
		if not directions.has(dir):
			directions.append(dir)
	for dir: Vector2i in directions:
		var cell := enemy.position + dir
		if not board.is_in_bounds(cell) or not GridSystem.is_passable(board, cell):
			continue
		var occupant := board.get_unit_at(cell)
		if occupant != null and occupant.id != actor.id and occupant.id != ally.id:
			continue
		candidates.append(cell)
	if candidates.is_empty():
		return
	var actor_dest: Vector2i = candidates[0]
	for cell: Vector2i in candidates:
		if cell == actor.position:
			actor_dest = cell
			break
	var ally_dest := Vector2i(-1, -1)
	for cell: Vector2i in candidates:
		if cell != actor_dest:
			ally_dest = cell
			break
	_move_paired_charger(board, actor, actor_dest, events)
	if ally_dest != Vector2i(-1, -1):
		_move_paired_charger(board, ally, ally_dest, events)


static func _move_paired_charger(
	board: BoardState,
	unit: UnitState,
	destination: Vector2i,
	events: Array[SimEvent],
) -> void:
	if unit == null or unit.position == destination:
		return
	GridSystem.set_occupant(board, unit.position, -1)
	var from := unit.position
	unit.position = destination
	GridSystem.set_occupant(board, destination, unit.id)
	events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
		"actor": unit.id,
		"from": from,
		"to": destination,
		"paired_charge": true,
	}))


static func _resolve_target_coord(board: BoardState, action: TimelineAction) -> Vector2i:
	if (
		action.ability != null
		and (
			_ability_has_modifier(
				board.get_unit_by_id(action.actor_id), action.ability, &"paired_ally_charge",
			)
			or _ability_has_modifier(
				board.get_unit_by_id(action.actor_id),
				action.ability,
				&"target_after_move_adjacent",
			)
		)
	):
		return action.target_coord
	if action.target_unit_id >= 0:
		var target = board.get_unit_by_id(action.target_unit_id)
		if target != null:
			return target.position
	return action.target_coord


static func _passive_has_modifier(actor: UnitState, key: StringName) -> bool:
	if actor == null:
		return false
	for passive: PassiveData in actor.active_passives:
		if passive != null and passive.modifiers.has(key):
			return true
	return false


static func _is_spell(ability: AbilityData) -> bool:
	return ability != null and ability.tags.has(AbilityModuleBridge.TAG_SPELL)


static func _begin_spellcast(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	events: Array[SimEvent],
) -> void:
	if actor == null or action == null:
		return
	actor.passive_flags["mage_spell_cast_this_turn"] = true
	actor.passive_flags["mage_spell_in_progress"] = true
	var target := board.get_unit_by_id(action.target_unit_id)
	if target == null:
		target = board.get_unit_at(action.target_coord)
	for passive: PassiveData in actor.active_passives:
		if passive == null:
			continue
		if passive.modifiers.has("arcane_overchannel_max"):
			var max_stacks := int(passive.modifiers["arcane_overchannel_max"])
			var stacks := mini(
				max_stacks,
				int(actor.passive_flags.get("arcane_overchannel_stacks", 0)) + 1,
			)
			actor.passive_flags["arcane_overchannel_stacks"] = stacks
			if (
				stacks >= max_stacks
				and not actor.passive_flags.get("arcane_overchannel_refunded", false)
			):
				actor.ability.points_left = mini(
					actor.ability.max_points,
					actor.ability.points_left + int(
						passive.modifiers.get("arcane_overchannel_refund_ap", 0)
					),
				)
				actor.passive_flags["arcane_overchannel_refunded"] = true
				CombatSystem.add_armor(
					board,
					actor,
					int(passive.modifiers.get("arcane_overchannel_shield", 0)),
					events,
				)
			break
	if _passive_has_modifier(actor, &"arcane_overdrive_hp_pct"):
		var cost := maxi(
			0,
			floori(actor.health.current_hp * float(
				_get_passive_value(actor, &"arcane_overdrive_hp_pct")
			)),
		)
		if cost > 0:
			CombatSystem.deal_damage(
				board,
				actor,
				cost,
				events,
				&"true",
				true,
				false,
				actor,
				"Arcane Overdrive",
				cost,
			)
	if actor.passive_flags.get("elemental_surge_ready", false):
		actor.passive_flags["mage_spell_range_bonus"] = 2
		actor.passive_flags["mage_spell_shape_bonus"] = 2
		actor.passive_flags.erase("elemental_surge_ready")
	for passive: PassiveData in actor.active_passives:
		if passive == null:
			continue
		if passive.modifiers.has("arcane_mastery_radius"):
			actor.passive_flags["mage_spell_shape_bonus"] = int(
				actor.passive_flags.get("mage_spell_shape_bonus", 0)
			) + int(passive.modifiers["arcane_mastery_radius"])
			if actor.is_passive_upgraded(passive.id):
				actor.passive_flags["mage_spell_pierce"] = true
		if passive.modifiers.has("wild_magic") and target != null:
			var tile := board.get_tile(target.position)
			if tile != null and tile.definition != null and tile.definition.hazard_damage > 0:
				actor.passive_flags["__mage_wild_magic_pending"] = true
				if actor.is_passive_upgraded(passive.id):
					actor.passive_flags["mage_spell_magic_bonus"] = int(
						passive.modifiers.get("upgraded_wild_magic_magic", 0)
					)


static func _finish_spellcast(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	events: Array[SimEvent],
) -> void:
	if actor == null or action == null:
		return
	var target := board.get_unit_by_id(action.target_unit_id)
	if target == null:
		target = board.get_unit_at(action.target_coord)
	if target != null and target.team == actor.team and target.id != actor.id:
		for passive: PassiveData in actor.active_passives:
			if passive == null or not passive.modifiers.has("arcane_attunement"):
				continue
			target.active_statuses.append(DataLibrary.make_status(
				GameEnums.StatusType.STAT_BUFF_DEF,
				1,
				int(passive.modifiers.get("arcane_attunement_def", 1)),
			))
			target.active_statuses.append(DataLibrary.make_status(
				GameEnums.StatusType.STAT_BUFF_STR,
				1,
				int(passive.modifiers.get("arcane_attunement_str", 1)),
			))
			if actor.is_passive_upgraded(passive.id):
				target.active_statuses.append(DataLibrary.make_status(
					GameEnums.StatusType.STAT_BUFF_MOV,
					1,
					int(passive.modifiers.get("upgraded_arcane_attunement_mov", 1)),
				))
			target._recalculate_stats(board)
			break
	actor._recalculate_stats(board)


static func _resolve_chain_lightning(
	board: BoardState,
	actor: UnitState,
	origin: UnitState,
	effect: EffectData,
	events: Array[SimEvent],
) -> void:
	var struck: Dictionary = {origin.id: true}
	var current := origin
	var bounce_count := int(effect.modifiers.get("bounce_count", 0))
	for _bounce: int in range(bounce_count):
		var next_target: UnitState = null
		var next_distance := 1_000_000
		for candidate: UnitState in board.units:
			if (
				candidate == null
				or not candidate.is_alive()
				or candidate.team == actor.team
				or struck.has(candidate.id)
				or GridSystem.manhattan(current.position, candidate.position)
					> int(effect.modifiers.get("bounce_range", 2))
			):
				continue
			var distance := GridSystem.manhattan(current.position, candidate.position)
			if distance < next_distance or (
				distance == next_distance and candidate.id < next_target.id
			):
				next_target = candidate
				next_distance = distance
		if next_target == null:
			break
		struck[next_target.id] = true
		var raw := CombatSystem.calculate_scaled_damage(
			actor,
			effect.amount,
			GameEnums.StatType.MAGICAL,
			board,
		)
		CombatSystem.deal_damage_raw(
			board,
			actor,
			next_target,
			raw,
			GameEnums.StatType.MAGICAL,
			events,
			"Chain Lightning",
			effect.amount,
		)
		current = next_target
	if effect.modifiers.get("strike_all_surface", false):
		for candidate: UnitState in board.units:
			if (
				candidate == null
				or not candidate.is_alive()
				or candidate.team == actor.team
				or struck.has(candidate.id)
			):
				continue
			var tile := board.get_tile(candidate.position)
			if (
				tile == null
				or tile.definition == null
				or tile.definition.id not in [&"water", &"frozen"]
			):
				continue
			struck[candidate.id] = true
			var raw := CombatSystem.calculate_scaled_damage(
				actor,
				effect.amount,
				GameEnums.StatType.MAGICAL,
				board,
			)
			CombatSystem.deal_damage_raw(
				board,
				actor,
				candidate,
				raw,
				GameEnums.StatType.MAGICAL,
				events,
				"Chain Lightning",
				effect.amount,
			)


static func _resolve_repeat_hits(
	board: BoardState,
	actor: UnitState,
	target: UnitState,
	effect: EffectData,
	events: Array[SimEvent],
) -> void:
	var hit_count := int(effect.modifiers.get("repeat_hits", 1))
	for _hit: int in range(1, hit_count):
		var raw := CombatSystem.calculate_scaled_damage(
			actor,
			effect.amount,
			GameEnums.StatType.MAGICAL,
			board,
		)
		if effect.modifiers.has("ignore_target_magic_pct"):
			actor.passive_flags["mage_target_magic_ignore_pct"] = float(
				effect.modifiers["ignore_target_magic_pct"]
			)
		CombatSystem.deal_damage_raw(
			board,
			actor,
			target,
			raw,
			GameEnums.StatType.MAGICAL,
			events,
			"Arcane Barrage",
			effect.amount,
		)
		actor.passive_flags.erase("mage_target_magic_ignore_pct")


static func _get_passive_value(actor: UnitState, key: StringName) -> float:
	if actor == null:
		return 0.0
	for passive: PassiveData in actor.active_passives:
		if passive != null and passive.modifiers.has(key):
			return float(passive.modifiers[key])
	return 0.0


static func _target_has_movement_penalty(target: UnitState) -> bool:
	if target == null:
		return false
	if target.has_status(GameEnums.StatusType.ROOT):
		return true
	if target.movement.max_points < target.definition.move_points:
		return true
	return false


static func _target_has_debuff(target: UnitState) -> bool:
	if target == null:
		return false
	for status: StatusData in target.active_statuses:
		if GameEnums.is_debuff(status.type):
			return true
	return false


static func _can_push_destructible_target(
	board: BoardState,
	actor: UnitState,
	ability: AbilityData,
	target: UnitState,
	target_coord: Vector2i,
) -> bool:
	if (
		board == null
		or actor == null
		or ability == null
		or ability.kind != GameEnums.AbilityKind.MOVEMENT_SKILL
		or not _passive_has_modifier(actor, &"push_destroy_obstacles")
	):
		return false
	if target != null:
		return target.definition != null and target.definition.is_construct
	var tile := board.get_tile(target_coord)
	return tile != null and tile.definition != null and tile.definition.id == &"trap"


static func _is_basic_attack(ability: AbilityData) -> bool:
	return (
		ability != null
		and ability.tags.has(AbilityModuleBridge.TAG_ATTACK)
		and (ability.id == &"basic_attack" or String(ability.id).ends_with("_basic"))
	)


static func _has_melee_basic_attack(unit: UnitState) -> bool:
	if unit == null or unit.definition == null:
		return false
	for ability: AbilityData in unit.definition.abilities:
		if DataLibrary.is_basic_ability(ability.id):
			return unit.get_ability_range(ability) <= 1
	return true


static func _is_side_attack(actor: UnitState, target: UnitState) -> bool:
	if actor == null or target == null:
		return false
	var origin_dir := PhysicsSystem.cardinal_from_to(target.position, actor.position)
	var facing_dir := PhysicsSystem.facing_to_vector(target.facing)
	return (
		origin_dir != Vector2i.ZERO
		and origin_dir.x * facing_dir.x + origin_dir.y * facing_dir.y == 0
	)


static func _apply_range_one_attack_passives(
	board: BoardState,
	actor: UnitState,
	target: UnitState,
	events: Array[SimEvent],
) -> void:
	if actor == null or target == null:
		return
	if GridSystem.manhattan(actor.position, target.position) != 1:
		return
	for passive: PassiveData in actor.active_passives:
		if passive == null or not passive.modifiers.has("range_one_self_push"):
			continue
		var push_dir := PhysicsSystem.cardinal_from_to(target.position, actor.position)
		PhysicsSystem.push(
			board,
			actor,
			push_dir,
			int(passive.modifiers["range_one_self_push"]),
			events,
			target,
			&"lancer_disengage",
		)
		if actor.is_passive_upgraded(passive.id) and passive.modifiers.has(
			"upgraded_range_one_enemy_push"
		):
			var enemy_dir := PhysicsSystem.cardinal_from_to(actor.position, target.position)
			PhysicsSystem.push(
				board,
				target,
				enemy_dir,
				int(passive.modifiers["upgraded_range_one_enemy_push"]),
				events,
				actor,
				&"lancer_disengage",
			)


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
		ShamanSystems.on_push_resolved(board, actor, target, ability_id, events)
		
		if push.get("pull_actor_to_target", false) and actor != null and actor.is_alive():
			var pull_distance := GridSystem.manhattan(actor.position, target.position)
			if pull_distance > 1:
				var pull_dir := PhysicsSystem.cardinal_from_to(actor.position, target.position)
				PhysicsSystem.push(
					board,
					actor,
					pull_dir,
					pull_distance - 1,
					events,
					target,
					ability_id,
				)
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
