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
		"show_action_range": false,
		"show_blast": false,
		"blast_origin": none,
		"blast_on_hover_layer": false,
	}
	if unit == null or director == null:
		return plan
	var show_action_range: bool = (
		planning_input != null
		and unit.id == director.selected_unit_id
		and planning_input.action_range_visible_for_hover()
	)
	plan["show_action_range"] = show_action_range
	var locked_stand: Vector2i = none
	if planning_input != null:
		locked_stand = planning_input.phase_entry_stand_cell(unit.id)
	else:
		locked_stand = CombatPlanningPreview.forecast_stand_at_phase_entry(
			director, board, unit.id, null,
		)
	match phase:
		PhaseKind.MOVEMENT:
			plan["locked_move_origin"] = locked_stand if locked_stand.x > -900000 else none
			if show_action_range:
				var predicted: Vector2i = planning_input.predicted_stand_at_hover(
					unit.id, hover_coord,
				)
				if predicted.x > -900000:
					plan["next_aim_origin"] = predicted
			plan["show_blast"] = (
				show_action_range
				and not planning_input.is_walk_only_hover_move(unit, hover_coord)
			)
			if (
				planning_input != null
				and planning_input.action_range_stand_locked_to_projection(unit.id)
			):
				plan["show_blast"] = true
				if plan["next_aim_origin"] != none:
					plan["blast_origin"] = plan["next_aim_origin"]
				elif plan["locked_move_origin"] != none:
					plan["blast_origin"] = plan["locked_move_origin"]
			if plan["show_blast"] and plan["next_aim_origin"] != none:
				plan["blast_origin"] = plan["next_aim_origin"]
			plan["blast_on_hover_layer"] = (
				planning_input != null
				and planning_input.action_range_stand_locked_to_projection(unit.id)
			)
		PhaseKind.NON_MOVEMENT:
			var aim_stand: Vector2i = locked_stand
			if planning_input != null and show_action_range:
				var intent_stand: Vector2i = planning_input.action_range_intent_stand_cell(unit.id)
				if intent_stand.x > -900000:
					aim_stand = intent_stand
			if aim_stand.x > -900000:
				plan["locked_aim_origin"] = aim_stand
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
			plan["show_blast"] = show_action_range or planning_input == null
			if plan["show_blast"] and plan["locked_aim_origin"] != none:
				plan["blast_origin"] = plan["locked_aim_origin"]
			if (
				planning_input != null
				and planning_input.action_range_stand_locked_to_projection(unit.id)
			):
				plan["show_blast"] = true
				plan["blast_on_hover_layer"] = true
				if plan["locked_aim_origin"] != none:
					plan["blast_origin"] = plan["locked_aim_origin"]
	return plan


## Settled paint is derived beside the settled slots, then carried read-only.
## Overlay code must consume this result instead of rebuilding range or blast geometry.
static func resolve_paint(
	director: CombatDirector,
	board: BoardState,
	unit: UnitState,
	selected_ability: int,
	planning_input: CombatPlanningInput,
	hover_coord: Vector2i,
) -> Dictionary:
	var none: Vector2i = Vector2i(-999999, -999999)
	if director == null or board == null or unit == null:
		return {
			"stand_origin": none,
			"action_range_tiles": [],
			"blast_tiles": [],
			"blast_on_hover_layer": false,
			"show_action_range": false,
			"show_blast": false,
			"phase": PhaseKind.NON_MOVEMENT,
			"ability_index": selected_ability,
		}
	var plan: Dictionary = resolve_layer_origins(
		director, board, unit, selected_ability, planning_input, hover_coord,
	)
	var stand: Vector2i = (
		planning_input.action_range_intent_stand_cell(unit.id)
		if planning_input != null
		else none
	)
	var action_range: Array[Vector2i] = []
	var blast: Array[Vector2i] = []
	var phase: int = int(plan.get("phase", PhaseKind.NON_MOVEMENT))
	var show_action_range: bool = bool(plan.get("show_action_range", false))
	match phase:
		PhaseKind.MOVEMENT:
			var next_aim: Vector2i = plan.get("next_aim_origin", none)
			if next_aim.x > -900000:
				action_range = action_range_tiles(
					director, board, unit, selected_ability, planning_input,
					next_aim, hover_coord,
				)
		PhaseKind.NON_MOVEMENT:
			var locked_aim: Vector2i = plan.get("locked_aim_origin", none)
			if locked_aim.x > -900000 and show_action_range:
				action_range = action_range_tiles(
					director, board, unit, selected_ability, planning_input,
					locked_aim, hover_coord,
				)
	if bool(plan.get("show_blast", false)):
		var blast_origin: Vector2i = plan.get("blast_origin", none)
		if blast_origin.x > -900000:
			blast = blast_tiles(
				director, board, unit, selected_ability, planning_input,
				blast_origin, hover_coord,
			)
	return {
		"stand_origin": stand,
		"action_range_tiles": action_range,
		"blast_tiles": blast,
		"blast_on_hover_layer": bool(plan.get("blast_on_hover_layer", false)),
		"show_action_range": show_action_range,
		"show_blast": bool(plan.get("show_blast", false)),
		"phase": phase,
		"ability_index": selected_ability,
	}


static func action_range_tiles(
	director: CombatDirector,
	board: BoardState,
	unit: UnitState,
	selected_ability: int,
	planning_input: CombatPlanningInput,
	origin: Vector2i,
	hover_coord: Vector2i,
) -> Array[Vector2i]:
	var ability: AbilityData = CombatDirector.resolve_selected_ability(unit, selected_ability)
	var actor: UnitState = (
		planning_input.projected_unit_for_preview(unit.id)
		if planning_input != null
		else unit
	)
	if actor == null:
		actor = unit
	var plan_board: BoardState = (
		director.projected_state
		if director != null and director.projected_state != null
		else board
	)
	var awaiting: TimelineAction = (
		director.find_awaiting_action(unit.id)
		if director != null
		else null
	)
	if awaiting != null and awaiting.awaiting_module_index >= 0:
		var range_stand: Vector2i = origin
		if planning_input != null:
			var intent_stand: Vector2i = planning_input.action_range_intent_stand_cell(unit.id)
			if intent_stand.x > -900000:
				range_stand = intent_stand
		return AbilitySystem.planning_module_range_tiles(
			plan_board, awaiting, awaiting.awaiting_module_index, range_stand, hover_coord,
		)
	return AbilitySystem.planning_action_range_tiles(
		plan_board, actor, ability, origin, [], hover_coord,
	)


static func blast_tiles(
	director: CombatDirector,
	board: BoardState,
	unit: UnitState,
	selected_ability: int,
	planning_input: CombatPlanningInput,
	origin: Vector2i,
	hover_coord: Vector2i,
) -> Array[Vector2i]:
	if board == null or not board.is_in_bounds(hover_coord):
		return []
	var ability: AbilityData = CombatDirector.resolve_selected_ability(unit, selected_ability)
	if ability == null and director != null:
		var awaiting: TimelineAction = director.find_awaiting_action(unit.id)
		if awaiting != null:
			ability = awaiting.ability
	if ability == null:
		return []
	var actor: UnitState = (
		planning_input.projected_unit_for_preview(unit.id)
		if planning_input != null
		else unit
	)
	if actor == null:
		actor = unit
	var plan_board: BoardState = (
		director.projected_state
		if director != null and director.projected_state != null
		else board
	)
	return AbilitySystem.planning_blast_tiles_at_target(
		plan_board, actor, ability, origin, hover_coord,
	)
