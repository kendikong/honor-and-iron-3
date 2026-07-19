class_name PlanDependency
extends RefCounted

## Cancels plans that depended on a movement skill affecting an ally (e.g. Swap undo).


static func ally_ids_affected_by_action(
	board: BoardState,
	action: TimelineAction,
) -> Array[int]:
	var out: Array[int] = []
	if board == null or action == null:
		return out
	if action.type != GameEnums.ActionType.ABILITY or action.ability == null:
		return out
	if not action.ability.is_movement_kind():
		return out
	var actor := board.get_unit_by_id(action.actor_id)
	if actor == null:
		return out
	if action.target_unit_id >= 0:
		var target := board.get_unit_by_id(action.target_unit_id)
		if target != null and target.team == actor.team and target.id != actor.id:
			out.append(target.id)
	return out


static func cancel_ally_plans_after_step(
	combined: Timeline,
	plans: Array,
	removed_action: TimelineAction,
	ally_ids: Array[int],
) -> bool:
	if combined == null or removed_action == null or ally_ids.is_empty():
		return false
	var cut_idx: int = combined.entries.find(removed_action)
	if cut_idx < 0:
		return false
	var ally_set: Dictionary = {}
	for id: int in ally_ids:
		ally_set[id] = true
	var cancelled := false
	for i: int in range(cut_idx + 1, combined.size()):
		var step: TimelineAction = combined.entries[i]
		if not ally_set.has(step.actor_id):
			continue
		for plan: Timeline in plans:
			var local_idx: int = plan.entries.find(step)
			if local_idx >= 0:
				plan.entries.remove_at(local_idx)
				cancelled = true
	return cancelled
