# ==============================================================================
# 🛑 WARNING TO AI AGENTS (HONOR & IRON ARCHITECTURE STRICT RULES) 🛑
# ==============================================================================
# DO NOT BRANCH ON `ability.id` IN THIS FILE. EVER.
# 
# Abilities are DATA, not engine code modifications. You are strictly forbidden
# from writing things like `if unit.is_ability_upgraded("knight_indomitable_will")`
# to inject mechanics. If an ability needs custom behavior, you MUST add a new 
# generic flag to `GameEnums.EffectType` or `GameEnums.StatusType`, assign it 
# in the factory, and check for THAT flag here.
# 
# VIOLATING THIS RULE WILL CAUSE THE AUTOMATED ARCHITECTURE TEST TO FAIL.
# ==============================================================================
class_name Simulator
extends RefCounted

const MercenarySystems := preload("res://core/systems/mercenary_systems.gd")
const MonkSystems := preload("res://core/systems/monk_systems.gd")
const ShamanSystems := preload("res://core/systems/shaman_systems.gd")
const RogueSystems := preload("res://core/systems/rogue_systems.gd")
const BeastRiderSystems := preload("res://core/systems/beast_rider_systems.gd")
const EngineerSystems := preload("res://core/systems/engineer_systems.gd")

## Purpose: THE single source of combat truth. One pure function turns a board +
## a plan into a resulting board + an ordered event log. Preview and execution
## both call this, guaranteeing "preview always matches execution".
## Responsibilities: Clone the input, replay the player plan then the locked enemy
##   intents through the fixed pipeline, do end-of-turn bookkeeping, and return
##   the result. Never mutates the input. Never renders.
## Dependencies: BoardState, Timeline, ResolutionPipeline, SimResult, SimEvent.
## Lifecycle: stateless; only static functions.

enum ActionBucket { PRE_MOVE, ACTION, POST_MOVE }


static func simulate(state_in: BoardState, plan: Timeline) -> SimResult:
	var board := state_in.clone()
	var events: Array[SimEvent] = []
	simulate_player_turn(board, plan, events)
	events.append(SimEvent.make(GameEnums.SimEventType.ENEMY_PHASE_BEGAN, {}))
	_tick_start_of_turn(board, events, GameEnums.Team.ENEMY)
	_tick_statuses(board, events)
	## Replan from the live board after the player phase — planning-time intents are
	## preview only; execution must not attack corpses or ignore player-phase deaths.
	var enemy_intents: Array = EnemyPlanner.plan(board)
	board.intents = enemy_intents
	for intent in enemy_intents:
		for action in intent.actions:
			ResolutionPipeline.apply_action(board, action, events)
	ResolutionPipeline.resolve_pending_pushes(board, events)
	_tick_end_of_turn(board, events)
	board.turn_index += 1
	for unit in board.units:
		if unit.is_alive():
			unit.reset_for_turn()
	_tick_statuses(board, events)
	events.append(SimEvent.make(GameEnums.SimEventType.TURN_ENDED, {
		"turn": board.turn_index,
	}))
	var result := SimResult.new(board)
	result.events = events
	return result


## Player portion only (planning validation / projected state).
static func simulate_player_turn(board: BoardState, plan: Timeline, events: Array[SimEvent]) -> void:
	_tick_start_of_turn(board, events, GameEnums.Team.PLAYER)
	_resolve_delayed_effects(board, events)
	_apply_bucket(board, plan, ActionBucket.PRE_MOVE, events)
	ResolutionPipeline.resolve_pending_pushes(board, events)
	AbilitySystem.apply_standing_aim_passives(board, events)
	_apply_bucket(board, plan, ActionBucket.ACTION, events)
	ResolutionPipeline.resolve_pending_pushes(board, events)
	_apply_bucket(board, plan, ActionBucket.POST_MOVE, events)
	ResolutionPipeline.resolve_pending_pushes(board, events)
	EngineerSystems.player_phase_end(board, events)


static func _apply_bucket(
	board: BoardState,
	plan: Timeline,
	bucket: ActionBucket,
	events: Array[SimEvent],
) -> void:
	for action in plan.entries:
		var resolved: TimelineAction = action
		if not action.is_simulatable():
			resolved = AbilitySystem.planning_committed_prefix(action)
			if resolved == null:
				continue
		if not _action_in_bucket(action, bucket):
			continue
		BeastRiderSystems.prepare_action(board, plan, resolved)
		ResolutionPipeline.apply_action(board, resolved, events)


static func _action_in_bucket(action: TimelineAction, bucket: ActionBucket) -> bool:
	if action.type == GameEnums.ActionType.ABILITY and action.ability != null:
		if action.ability.kind == GameEnums.AbilityKind.UNIVERSAL_WAIT:
			return bucket == ActionBucket.ACTION
		if action.ability.is_movement_kind():
			return bucket == ActionBucket.PRE_MOVE
		if action.ability.is_class_kind():
			return bucket == ActionBucket.ACTION
	match bucket:
		ActionBucket.PRE_MOVE:
			return action.type in [
				GameEnums.ActionType.MOVE,
				GameEnums.ActionType.FACE,
			] and action.move_timing == GameEnums.MoveTiming.PRE_ACTION
		ActionBucket.ACTION:
			return action.type == GameEnums.ActionType.ABILITY
		ActionBucket.POST_MOVE:
			return action.type in [
				GameEnums.ActionType.MOVE,
				GameEnums.ActionType.FACE,
			] and action.move_timing == GameEnums.MoveTiming.POST_ACTION
	return false


static func _tick_statuses(board: BoardState, events: Array[SimEvent]) -> void:
	for unit in board.units:
		if unit.is_alive():
			var to_remove = []
			var indomitable_will_expired = false
			var indomitable_will_upgraded_expired = false
			for i in range(unit.active_statuses.size() - 1, -1, -1):
				var status = unit.active_statuses[i]
				if status.duration > 0:
					status.ticks_remaining -= 1
					if status.ticks_remaining <= 0:
						if status.type == GameEnums.StatusType.INDOMITABLE_WILL or status.type == GameEnums.StatusType.INDOMITABLE_WILL_UPGRADED:
							indomitable_will_expired = true
						if status.type == GameEnums.StatusType.INDOMITABLE_WILL_UPGRADED:
							indomitable_will_upgraded_expired = true
						to_remove.append(status)
						unit.active_statuses.remove_at(i)
						events.append(SimEvent.make(GameEnums.SimEventType.STATUS_REMOVED, {
							"unit": unit.id,
							"status_type": status.type,
						}))
			if indomitable_will_expired:
				unit.armor = 0
			if indomitable_will_upgraded_expired:
				unit.active_statuses.append(
					DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 99, 2),
				)
			if not unit.has_status(GameEnums.StatusType.MARK):
				unit.passive_flags.erase("marked_no_stealth_teleport")
			if to_remove.size() > 0 or indomitable_will_expired:
				unit._recalculate_stats(board)
			if unit.passive_flags.has("chakra_shift_turns"):
				var turns_left := int(unit.passive_flags["chakra_shift_turns"]) - 1
				if turns_left <= 0:
					unit.passive_flags.erase("chakra_shift_turns")
				else:
					unit.passive_flags["chakra_shift_turns"] = turns_left
				unit._recalculate_stats(board)


static func _tick_start_of_turn(board: BoardState, events: Array[SimEvent], team: GameEnums.Team) -> void:
	for unit in board.units:
		if unit.is_alive() and unit.team == team:
			MercenarySystems.turn_start(board, unit, events)
			MonkSystems.turn_start(board, unit, events)
			MonkSystems.on_turn_start_penalty(board, unit)
			ShamanSystems.turn_start(board, unit, events)
			RogueSystems.turn_start(board, unit, events)
			RogueSystems.apply_next_turn_ap_bonus(unit)
			BeastRiderSystems.turn_start(board, unit, events)
			EngineerSystems.turn_start(board, unit, events)
			unit.passive_flags.erase(GameEnums.RUNTIME_SPELL_AP_REFUNDED)
			if unit.health.current_hp < unit.health.max_hp:
				unit.passive_flags.erase("full_health_debuff_immunity")
			if unit.passive_flags.get("next_turn_move_zero", false):
				unit.movement.points_left = 0
				unit.passive_flags.erase("next_turn_move_zero")
			unit.passive_flags.erase("life_link_source_id")
			unit.passive_flags.erase("life_link_damage_reduction")
			if unit.passive_flags.get("revived_next_turn", false):
				unit.ability.reset()
				unit.movement.points_left = unit.movement.max_points
				unit.passive_flags.erase("revived_next_turn")
			var next_move_bonus: int = int(
				unit.passive_flags.get("next_turn_max_move_bonus", 0)
			)
			if next_move_bonus > 0:
				unit.active_statuses.append(
					DataLibrary.make_status(
						GameEnums.StatusType.STAT_BUFF_MOV,
						1,
						next_move_bonus,
					)
				)
				if unit.passive_flags.get("next_turn_trample", false):
					unit.active_statuses.append(
						DataLibrary.make_status(GameEnums.StatusType.TRAMPLE, 1, 0)
					)
				unit.passive_flags.erase("next_turn_max_move_bonus")
				unit.passive_flags.erase("next_turn_trample")
				unit._recalculate_stats(board)
			if unit.has_status(GameEnums.StatusType.STAGGER):
				unit.ability.points_left = maxi(0, unit.ability.points_left - 1)
			var zone_payload: Dictionary = board.terrain_payloads.get(unit.position, {})
			var zone_owner := board.get_unit_by_id(int(zone_payload.get("terrain_owner_id", -1)))
			if zone_owner != null and unit.team == zone_owner.team:
				if zone_payload.get("sanctuary", false):
					if not unit.has_status(GameEnums.StatusType.STEALTH):
						unit.active_statuses.append(DataLibrary.make_status(
							GameEnums.StatusType.STEALTH, 1
						))
					if not unit.has_status(GameEnums.StatusType.INVULNERABLE):
						unit.active_statuses.append(DataLibrary.make_status(
							GameEnums.StatusType.INVULNERABLE, 1
						))
				if zone_payload.get("holy_ground_zone", false):
					CombatSystem.heal_x(board, unit, 1, events)
			for aura_source: UnitState in board.units:
				if (
					aura_source == null
					or not aura_source.is_alive()
					or not bool(aura_source.passive_flags.get("holy_aura", false))
					or aura_source.team == unit.team
					or GridSystem.manhattan(aura_source.position, unit.position) != 1
				):
					continue
				var aura_owner := board.get_unit_by_id(
					int(aura_source.passive_flags.get("holy_aura_owner_id", -1))
				)
				if aura_owner == null or not aura_owner.is_alive():
					aura_owner = aura_source
				CombatSystem.deal_mag_atk(board, aura_owner, unit, 1, events, "Holy Aura")
				break
			for status in unit.active_statuses:
				if status.type == GameEnums.StatusType.BURN:
					CombatSystem.deal_damage(
						board, unit, status.value, events, &"burn", true, false, null, "Burn", status.value,
					)
				elif status.type == GameEnums.StatusType.POISON:
					var dmg: int = ceili(unit.health.max_hp * 0.10)
					CombatSystem.deal_damage(
						board, unit, dmg, events, &"poison", true, false, null, "Poison", dmg,
					)
			var has_rallying_knight := false
			var rally_upgraded := false
			for dir in GridSystem.DIRECTIONS:
				var adj_unit = board.get_unit_at(unit.position + dir)
				if (
					adj_unit != null
					and adj_unit.team == unit.team
					and adj_unit.has_passive(&"rallying_presence")
				):
					has_rallying_knight = true
					if adj_unit.is_passive_upgraded(&"rallying_presence"):
						rally_upgraded = true
						break
			if has_rallying_knight:
				var mov_bonus: int = 2 if rally_upgraded else 1
				unit.active_statuses.append(
					DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_MP, 1, mov_bonus),
				)
				unit._recalculate_stats(board)
				
			if unit.has_passive(&"cellular_regeneration"):
				var adj_enemies = 0
				for dir in GridSystem.DIRECTIONS:
					var adj_unit = board.get_unit_at(unit.position + dir)
					if adj_unit != null and adj_unit.team != unit.team:
						adj_enemies += 1
				var regeneration := 1
				var sanguine_regeneration := false
				var reactive_adrenaline := unit.has_passive(&"reactive_adrenaline")
				var upgraded_def_per_enemy := 0
				for passive: PassiveData in unit.active_passives:
					if passive == null:
						continue
					if passive.modifiers.has("sanguine_regeneration"):
						sanguine_regeneration = true
						regeneration = floori(unit.health.max_hp * 0.05)
						if unit.is_passive_upgraded(passive.id):
							regeneration = floori(unit.health.max_hp * 0.10)
					if not passive.modifiers.has("reactive_adrenaline"):
						continue
					if unit.is_passive_upgraded(passive.id):
						upgraded_def_per_enemy = int(
							passive.modifiers.get("upgraded_adjacent_enemy_def", 0)
						)
					break
				if sanguine_regeneration and adj_enemies == 0:
					var missing_hp: int = maxi(0, unit.health.max_hp - unit.health.current_hp)
					CombatSystem.heal(board, unit, regeneration, events)
					var overflow: int = maxi(0, regeneration - missing_hp)
					if overflow > 0:
						CombatSystem.add_armor(board, unit, overflow, events)
				elif adj_enemies >= 1 and reactive_adrenaline:
					CombatSystem.add_armor(board, unit, regeneration, events)
					var adjacent_str := mini(adj_enemies, 3)
					if adjacent_str > 0:
						unit.active_statuses.append(
							DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 1, adjacent_str)
						)
					if upgraded_def_per_enemy > 0:
						unit.active_statuses.append(
							DataLibrary.make_status(
								GameEnums.StatusType.STAT_BUFF_DEF,
								1,
								adj_enemies * upgraded_def_per_enemy,
							)
						)
					unit._recalculate_stats(board)
				elif adj_enemies >= 1:
					CombatSystem.heal(board, unit, regeneration, events)

			for passive: PassiveData in unit.active_passives:
				if passive == null or not passive.modifiers.has("holy_ground_tick"):
					continue
				for dir: Vector2i in GridSystem.DIRECTIONS:
					var adjacent := board.get_unit_at(unit.position + dir)
					if adjacent == null or not adjacent.is_alive():
						continue
					if adjacent.team == unit.team:
						CombatSystem.heal_x(board, adjacent, 1, events)
					else:
						AbilitySystem.purge_unit(adjacent, events)
						if unit.is_passive_upgraded(passive.id):
							adjacent.active_statuses.append(
								DataLibrary.make_status(GameEnums.StatusType.BLIND, 1)
							)
				break
			for source: UnitState in board.units:
				if source == null or source.team != unit.team:
					continue
				for passive: PassiveData in source.active_passives:
					if (
						passive == null
						or not passive.modifiers.has("full_health_def")
						or unit.health.current_hp < unit.health.max_hp
					):
						continue
					var full_health_def := int(passive.modifiers["full_health_def"])
					var full_health_status := DataLibrary.make_status(
						GameEnums.StatusType.STAT_BUFF_DEF,
						1,
						full_health_def,
					)
					unit.active_statuses.append(full_health_status)
					unit.passive_flags["full_health_debuff_immunity"] = true
					if source.is_passive_upgraded(passive.id):
						unit.active_statuses.append(DataLibrary.make_status(
							GameEnums.StatusType.STAT_BUFF_MAG,
							1,
							int(passive.modifiers.get("upgraded_full_health_mag", 0)),
						))
					unit._recalculate_stats(board)
					break


static func _tick_end_of_turn(board: BoardState, events: Array[SimEvent]) -> void:
	for unit in board.units:
		if unit.is_alive():
			if unit.passive_flags.get(GameEnums.RUNTIME_SPELL_CAST_THIS_TURN, false) == false:
				unit.passive_flags.erase("arcane_overchannel_stacks")
			unit.passive_flags.erase(GameEnums.RUNTIME_SPELL_CAST_THIS_TURN)
			var surface_payload: Dictionary = board.terrain_payloads.get(unit.position, {})
			var surface_owner := board.get_unit_by_id(int(surface_payload.get("terrain_owner_id", -1)))
			if surface_owner != null and surface_owner.id == unit.id:
				for passive: PassiveData in unit.active_passives:
					if passive == null or not passive.modifiers.has("surface_syphoner"):
						continue
					CombatSystem.heal(board, unit, int(passive.modifiers.get("surface_syphoner_heal", 1)), events)
					if unit.is_passive_upgraded(passive.id):
						CombatSystem.add_armor(
							board,
							unit,
							int(passive.modifiers.get("surface_syphoner_shield", 1)),
							events,
						)
					else:
						AbilitySystem.cleanse_unit(unit, events)
					break
			for passive: PassiveData in unit.active_passives:
				if passive == null or not passive.modifiers.has("mana_well"):
					continue
				var tile := board.get_tile(unit.position)
				if tile != null and tile.definition != null and tile.definition.id in [
					&"fire", &"frozen", &"water", &"steam", &"oil"
				]:
					unit.passive_flags["mana_well_next_spell"] = true
					if unit.is_passive_upgraded(passive.id):
						unit.passive_flags["mana_well_magic_bonus"] = int(
							passive.modifiers.get("mana_well_magic", 1)
						)
					unit._recalculate_stats(board)
				break
			if unit.passive_flags.get("next_turn_root_immune", false):
				unit.passive_flags["root_immune_this_turn"] = true
				unit.passive_flags.erase("next_turn_root_immune")
			MonkSystems.turn_end(board, unit, events)
			ShamanSystems.turn_end(unit)
			RogueSystems.turn_end(board, unit, events)
			BeastRiderSystems.turn_end(board, unit, events)
			MercenarySystems.turn_end_rollover(unit)
			EngineerSystems.turn_end(board, unit, events)
			var took_dmg: bool = unit.passive_flags.get("damaged_this_turn", false)
			unit.passive_flags["damaged_last_turn"] = took_dmg
			for passive: PassiveData in unit.active_passives:
				if passive == null or not passive.modifiers.has("prayer_next_heal_multiplier"):
					continue
				if not unit.passive_flags.get("attacked_this_turn", false):
					unit.passive_flags["prayer_next_heal"] = true
					if unit.is_passive_upgraded(passive.id):
						unit.passive_flags["prayer_next_heal_cleanse"] = true
				break
			unit.passive_flags.erase("attacked_this_turn")
			unit.passive_flags["damaged_this_turn"] = false
			unit.passive_flags.erase("magic_chain_partner_id")
			unit.passive_flags.erase("magic_chain_blind")
			
			for status in unit.active_statuses:
				if status.type == GameEnums.StatusType.BLEED:
					CombatSystem.deal_damage(
						board, unit, status.value, events, &"bleed", true, false, null, "Bleed", status.value,
					)
	var expired_terrain: Array[Vector2i] = []
	for coord: Vector2i in board.temporary_terrain_turns.keys():
		board.temporary_terrain_turns[coord] = int(board.temporary_terrain_turns[coord]) - 1
		if int(board.temporary_terrain_turns[coord]) <= 0:
			expired_terrain.append(coord)
	for coord: Vector2i in expired_terrain:
		var previous: TerrainData = board.temporary_terrain_previous.get(coord, null)
		if previous != null:
			board.set_tile_terrain(coord, previous)
			events.append(SimEvent.make(GameEnums.SimEventType.TERRAIN_CHANGED, {
				"coord": coord,
				"terrain": previous.id,
				"temporary_expired": true,
			}))
		board.temporary_terrain_turns.erase(coord)
		board.temporary_terrain_previous.erase(coord)
		board.terrain_payloads.erase(coord)


static func _resolve_delayed_effects(board: BoardState, events: Array[SimEvent]) -> void:
	if board.delayed_effects.is_empty():
		return
	var delayed := board.delayed_effects.duplicate(true)
	board.delayed_effects.clear()
	for entry: Dictionary in delayed:
		AbilitySystem.execute_delayed_effect(board, entry, events)

