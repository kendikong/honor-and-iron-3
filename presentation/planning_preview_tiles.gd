class_name PlanningPreviewTiles
extends RefCounted

## MOVE_PREVIEW_RULES — phase + tile layer SSOT.
## Owner priorities: one canonical path per concern; fewer global rules; no parallel preview pipelines.

enum PhaseKind { WAIT, MOVEMENT, NON_MOVEMENT }


static func planning_phase(
	director: CombatDirector,
	unit: UnitState,
	selected_ability: int,
	planning_input: CombatPlanningInput,
) -> PhaseKind:
	if unit == null or director == null:
		return PhaseKind.NON_MOVEMENT
	if CombatDirector.is_wait_ability_index(selected_ability):
		return PhaseKind.WAIT
	if director.unit_has_wait_planned(unit.id):
		return PhaseKind.WAIT
	if planning_input != null and planning_input.active_movement_planning_step(unit):
		return PhaseKind.MOVEMENT
	return PhaseKind.NON_MOVEMENT


static func tiles_blocked(
	director: CombatDirector,
	unit: UnitState,
	selected_ability: int,
	planning_input: CombatPlanningInput,
	is_selected_player: bool,
) -> bool:
	if not is_selected_player:
		return false
	if CombatDirector.is_wait_ability_index(selected_ability):
		return true
	if director.unit_has_wait_planned(unit.id):
		return true
	if director.find_awaiting_action(unit.id) != null:
		return false
	if planning_input != null and planning_input.selected_phase_action_exhausted(unit.id):
		return true
	return false


## Two-range model: locked current-phase origins + optional next-phase origins at hover.
static func resolve_layer_origins(
	director: CombatDirector,
	board: BoardState,
	unit: UnitState,
	selected_ability: int,
	planning_input: CombatPlanningInput,
	hover_coord: Vector2i,
) -> Dictionary:
	var phase: PhaseKind = planning_phase(director, unit, selected_ability, planning_input)
	var none: Vector2i = Vector2i(-999999, -999999)
	var plan: Dictionary = {
		"phase": phase,
		"locked_move_origin": none,
		"locked_aim_origin": none,
		"next_aim_origin": none,
		"next_move_origin": none,
		"show_blast": false,
	}
	if unit == null or director == null:
		return plan
	var locked_move: Vector2i = CombatPlanningPreview.planning_move_origin_cell(
		director, board, unit.id,
	)
	match phase:
		PhaseKind.MOVEMENT:
			plan["locked_move_origin"] = locked_move if locked_move.x > -900000 else none
			if planning_input != null and planning_input.action_range_visible_for_hover():
				var predicted: Vector2i = planning_input.predicted_stand_at_hover(
					unit.id, hover_coord,
				)
				if predicted.x > -900000:
					plan["next_aim_origin"] = predicted
			plan["show_blast"] = (
				planning_input != null
				and planning_input.action_range_visible_for_hover()
				and not planning_input.is_walk_only_hover_move(unit, hover_coord)
			)
		PhaseKind.NON_MOVEMENT:
			if planning_input != null:
				plan["locked_aim_origin"] = planning_input.action_range_intent_stand_cell(unit.id)
			var post_timing: int = director.get_planning_move_timing(unit.id)
			if (
				post_timing == GameEnums.MoveTiming.POST_ACTION
				and not director.unit_has_move_planned_at_timing(unit.id, post_timing)
				and planning_input != null
			):
				var hover_stand: Vector2i = planning_input.predicted_stand_at_hover(
					unit.id, hover_coord,
				)
				if hover_stand.x > -900000:
					plan["next_move_origin"] = hover_stand
			plan["show_blast"] = (
				planning_input == null or planning_input.action_range_visible_for_hover()
			)
	return plan
