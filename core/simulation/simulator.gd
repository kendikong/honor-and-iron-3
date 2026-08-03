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
	_apply_bucket(board, plan, ActionBucket.PRE_MOVE, events)
	ResolutionPipeline.resolve_pending_pushes(board, events)
	_apply_bucket(board, plan, ActionBucket.ACTION, events)
	ResolutionPipeline.resolve_pending_pushes(board, events)
	_apply_bucket(board, plan, ActionBucket.POST_MOVE, events)
	ResolutionPipeline.resolve_pending_pushes(board, events)


static func _apply_bucket(
	board: BoardState,
	plan: Timeline,
	bucket: ActionBucket,
	events: Array[SimEvent],
) -> void:
	for action in plan.entries:
		if not action.is_simulatable():
			continue
		if not _action_in_bucket(action, bucket):
			continue
		ResolutionPipeline.apply_action(board, action, events)


static func _action_in_bucket(action: TimelineAction, bucket: ActionBucket) -> bool:
	if action.type == GameEnums.ActionType.ABILITY and action.ability != null:
		if action.ability.is_universal_wait():
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
			if to_remove.size() > 0 or indomitable_will_expired:
				unit._recalculate_stats(board)


static func _tick_start_of_turn(board: BoardState, events: Array[SimEvent], team: GameEnums.Team) -> void:
	for unit in board.units:
		if unit.is_alive() and unit.team == team:
			if unit.has_status(GameEnums.StatusType.STAGGER):
				unit.ability.points_left = maxi(0, unit.ability.points_left - 1)
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
				if adj_enemies >= 1:
					CombatSystem.heal(board, unit, 1, events)
				if adj_enemies >= 2 and unit.is_passive_upgraded(&"cellular_regeneration"):
					unit.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 1, 1))
					unit._recalculate_stats(board)


static func _tick_end_of_turn(board: BoardState, events: Array[SimEvent]) -> void:
	for unit in board.units:
		if unit.is_alive():
			var took_dmg: bool = unit.passive_flags.get("damaged_this_turn", false)
			unit.passive_flags["damaged_last_turn"] = took_dmg
			unit.passive_flags["damaged_this_turn"] = false
			
			for status in unit.active_statuses:
				if status.type == GameEnums.StatusType.BLEED:
					CombatSystem.deal_damage(
						board, unit, status.value, events, &"bleed", true, false, null, "Bleed", status.value,
					)

