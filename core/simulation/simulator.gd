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

static func simulate(state_in: BoardState, plan: Timeline) -> SimResult:
	# Work on a throwaway copy so the caller's board is never touched. Preview
	# discards this copy; execution adopts it (constitution ghost-preview model).
	var board := state_in.clone()
	var events: Array[SimEvent] = []

	# 1) Player Phase 1 actions
	_tick_start_of_turn(board, events, GameEnums.Team.PLAYER)
	
	for action in plan.entries:
		if action.phase == 1:
			ResolutionPipeline.apply_action(board, action, events)
	ResolutionPipeline.resolve_pending_pushes(board, events)

	# Phase 1 MOV Refund
	_refund_movement(board)

	# 2) Player Phase 2 actions
	for action in plan.entries:
		if action.phase == 2:
			ResolutionPipeline.apply_action(board, action, events)
	ResolutionPipeline.resolve_pending_pushes(board, events)

	# Phase 2 MOV Refund
	_refund_movement(board)

	_tick_statuses(board, events)

	# Marker so presentation can distinguish player-phase from enemy-phase effects
	events.append(SimEvent.make(GameEnums.SimEventType.ENEMY_PHASE_BEGAN, {}))
	
	_tick_start_of_turn(board, events, GameEnums.Team.ENEMY)

	# 3) Locked enemy intents, in stored order (perfect information).
	for intent in board.intents:
		for action in intent.actions:
			ResolutionPipeline.apply_action(board, action, events)

	# 4) End-of-turn bookkeeping: advance turn, refresh per-turn points.
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

static func _tick_statuses(board: BoardState, events: Array[SimEvent]) -> void:
	for unit in board.units:
		if unit.is_alive():
			var to_remove = []
			var indomitable_will_expired = false
			for i in range(unit.active_statuses.size() - 1, -1, -1):
				var status = unit.active_statuses[i]
				if status.duration > 0:
					status.ticks_remaining -= 1
					if status.ticks_remaining <= 0:
						if status.type == GameEnums.StatusType.INDOMITABLE_WILL:
							indomitable_will_expired = true
						to_remove.append(status)
						unit.active_statuses.remove_at(i)
						events.append(SimEvent.make(GameEnums.SimEventType.STATUS_REMOVED, {
							"unit": unit.id,
							"status_type": status.type,
						}))
			if indomitable_will_expired:
				unit.armor = 0
				if unit.is_ability_upgraded(&"knight_indomitable_will"):
					unit.active_statuses.append(DataLibrary._status_effect(GameEnums.StatusType.STAT_BUFF_STR, 99, 2))
			if to_remove.size() > 0 or indomitable_will_expired:
				unit._recalculate_stats()

static func _refund_movement(board: BoardState) -> void:
	for unit in board.units:
		if unit.is_alive() and unit.team == GameEnums.Team.PLAYER:
			var refund = floori(unit.movement.max_points / 2.0)
			unit.movement.points_left = mini(unit.movement.max_points, unit.movement.points_left + refund)

static func _tick_start_of_turn(board: BoardState, events: Array[SimEvent], team: GameEnums.Team) -> void:
	for unit in board.units:
		if unit.is_alive() and unit.team == team:
			for status in unit.active_statuses:
				if status.type == GameEnums.StatusType.BURN:
					# Take exactly X unmitigated damage
					CombatSystem.deal_damage(board, unit, status.value, events, &"burn", true, false, null, "Burn", status.value)
				elif status.type == GameEnums.StatusType.POISON:
					# 10% of Max HP (rounded up)
					var dmg = ceili(unit.health.max_hp * 0.10)
					CombatSystem.deal_damage(board, unit, dmg, events, &"poison", true, false, null, "Poison", dmg)
					
			var has_rallying_knight = false
			var rally_upgraded = false
			for dir in GridSystem.DIRECTIONS:
				var adj_unit = board.get_unit_at(unit.position + dir)
				if adj_unit != null and adj_unit.team == unit.team and adj_unit.has_passive(&"rallying_presence"):
					has_rallying_knight = true
					if adj_unit.is_passive_upgraded(&"rallying_presence"):
						rally_upgraded = true
						break
			
			if has_rallying_knight:
				var mov_bonus = 2 if rally_upgraded else 1
				unit.active_statuses.append(DataLibrary._status_effect(GameEnums.StatusType.STAT_BUFF_MP, 1, mov_bonus))
				unit._recalculate_stats()

static func _tick_end_of_turn(board: BoardState, events: Array[SimEvent]) -> void:
	for unit in board.units:
		if unit.is_alive():
			for status in unit.active_statuses:
				if status.type == GameEnums.StatusType.BLEED:
					# Take exactly X unmitigated damage
					CombatSystem.deal_damage(board, unit, status.value, events, &"bleed", true, false, null, "Bleed", status.value)
