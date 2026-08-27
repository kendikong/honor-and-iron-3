class_name PlanningPreviewTiles
extends RefCounted

## MOVE_PREVIEW_RULES phase SSOT — overlay tile math uses these gates only.

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
