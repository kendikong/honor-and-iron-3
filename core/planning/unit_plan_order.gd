class_name UnitPlanOrder
extends RefCounted

## Resolves each unit's planned actions in **simulation execution order**
## (pre-move/face → abilities → post-move/face). UI and planning input use this
## so future bonus moves, AP refunds, and extra action grants can extend the
## step list without rewriting the timeline grid.

static func ordered_steps_for_unit(plan: Timeline, unit_id: int) -> Array[TimelineAction]:
	if plan == null or unit_id < 0:
		return []
	var pre_moves: Array[TimelineAction] = []
	var abilities: Array[TimelineAction] = []
	var post_moves: Array[TimelineAction] = []
	for action: TimelineAction in plan.entries:
		if action.actor_id != unit_id:
			continue
		match action.type:
			GameEnums.ActionType.ABILITY:
				abilities.append(action)
			GameEnums.ActionType.MOVE, GameEnums.ActionType.FACE:
				if action.move_timing == GameEnums.MoveTiming.POST_ACTION:
					post_moves.append(action)
				else:
					pre_moves.append(action)
	var ordered: Array[TimelineAction] = []
	ordered.append_array(pre_moves)
	ordered.append_array(abilities)
	ordered.append_array(post_moves)
	return ordered


static func max_step_count(plan: Timeline, board: BoardState) -> int:
	var max_steps: int = 0
	if board == null:
		return 1
	for unit: UnitState in board.units:
		if unit.is_enemy():
			continue
		max_steps = maxi(max_steps, ordered_steps_for_unit(plan, unit.id).size())
	return maxi(max_steps, 1)


static func status_for_action(
	plan: Timeline,
	statuses: PackedStringArray,
	action: TimelineAction,
) -> String:
	if plan == null or action == null:
		return ""
	var idx: int = plan.entries.find(action)
	if idx < 0 or idx >= statuses.size():
		return ""
	return String(statuses[idx])
