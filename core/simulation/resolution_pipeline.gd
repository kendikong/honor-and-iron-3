class_name ResolutionPipeline
extends RefCounted

## Purpose: Applies ONE action using the project's fixed combat resolution order.
## The canonical order (constitution) is:
##   Movement -> Displacement -> Collision -> Damage -> Break -> Death -> Status
##   -> Terrain -> Reactions -> Timeline Updates
## Milestone 1 implements: Movement, Displacement, Collision, Damage, Death.
## Later milestones insert their steps at the marked stages WITHOUT reordering.
## Responsibilities: Route an action to the correct system in the correct order.
## Dependencies: BoardState, TimelineAction, MovementSystem, AbilitySystem, SimEvent.
## Lifecycle: stateless; only static functions.

static func apply_action(board: BoardState, action: TimelineAction, events: Array[SimEvent]) -> void:
	var starting_event_count := events.size()
	
	var unit := board.get_unit_by_id(action.actor_id)
	if unit != null:
		if unit.has_status(GameEnums.StatusType.STUN):
			events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
				"actor": action.actor_id, "reason": "stunned",
			}))
			return
		
		if action.type == GameEnums.ActionType.ABILITY:
			if (unit.has_status(GameEnums.StatusType.SILENCE) or unit.has_status(GameEnums.StatusType.POLYMORPH)) and action.ability.action_point_cost > 0:
				events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
					"actor": action.actor_id, "reason": "silenced_or_polymorphed",
				}))
				return
				
			if unit.has_status(GameEnums.StatusType.PACIFY):
				# Pacify blocks all offensive skills or basic attacks (damage, explode, push, etc.)
				# We will check if it has a damaging/offensive effect
				var is_offensive = false
				for effect in action.ability.effects:
					if effect.type in [GameEnums.EffectType.DAMAGE, GameEnums.EffectType.EXPLODE, GameEnums.EffectType.RANGED_EXPLODE, GameEnums.EffectType.PUSH, GameEnums.EffectType.PULL]:
						is_offensive = true
					elif effect.type == GameEnums.EffectType.ADD_STATUS and GameEnums.is_debuff(effect.status_type):
						is_offensive = true
				if is_offensive:
					events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
						"actor": action.actor_id, "reason": "pacified",
					}))
					return
	
	match action.type:
		GameEnums.ActionType.MOVE:
			# Stage: Movement.
			MovementSystem.execute_move(board, action, events)
		GameEnums.ActionType.FACE:
			# Stage: Movement (turn-in-place; no displacement).
			MovementSystem.execute_face(board, action, events)
		GameEnums.ActionType.ABILITY:
			# Stage: Displacement -> Collision -> Damage -> Death (handled inside
			# the effect interpreters, in that fixed order).
			AbilitySystem.execute(board, action, events)
		_:
			events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
				"actor": action.actor_id, "reason": "unknown_action_type",
			}))

	# Tag all newly generated events with the actor_id for AI Telemetry attribution
	for i in range(starting_event_count, events.size()):
		events[i].data["actor_id"] = action.actor_id

	# Check if the action succeeded (no ACTION_FAILED was emitted during this step)
	var failed := false
	for i in range(starting_event_count, events.size()):
		if events[i].type == GameEnums.SimEventType.ACTION_FAILED:
			failed = true
			break
			
	if not failed:
		var actor := board.get_unit_by_id(action.actor_id)
		if actor != null and action.type != GameEnums.ActionType.FACE:
			if action.phase == 1:
				actor.phase_1_action_used = true
			else:
				actor.phase_2_action_used = true

static func resolve_pending_pushes(board: BoardState, events: Array[SimEvent]) -> void:
	if board.pending_pushes.size() > 0:
		AbilitySystem.resolve_pending_pushes(board, events)
