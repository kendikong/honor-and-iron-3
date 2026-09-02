class_name PlanningPreviewTiles
extends RefCounted

## MOVE_PREVIEW_RULES — phase + tile layer SSOT.
## Owner priorities: one canonical path per concern; fewer global rules; no parallel preview pipelines.

enum PhaseKind { WAIT, MOVEMENT, NON_MOVEMENT }


static func _unit_has_committed_ability(director: CombatDirector, unit_id: int) -> bool:
	if director == null or unit_id < 0:
		return false
	for column: Variant in [
		director.plan_pre_move,
		director.plan_action,
		director.plan_post_move,
	]:
		for action: TimelineAction in column.entries:
			if action == null or action.actor_id != unit_id:
				continue
			if action.type != GameEnums.ActionType.ABILITY:
				continue
			if action.ability != null and action.ability.kind == GameEnums.AbilityKind.UNIVERSAL_WAIT:
				continue
			return true
	return false


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
	settled_board: BoardState = null,
	settled_preview_paths: Dictionary = {},
	range_stand_origin: Vector2i = Vector2i(-999999, -999999),
	settled_slots: Dictionary = {},
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
	## Locked current-phase stand (blue walk bubble / red aim bubble) — phase entry only.
	var locked_stand: Vector2i = _locked_current_phase_stand(
		unit,
		range_stand_origin,
		director,
		board,
		planning_input,
	)
	match phase:
		PhaseKind.MOVEMENT:
			plan["locked_move_origin"] = locked_stand if locked_stand.x > -900000 else none
			if show_action_range:
				var range_origin: Vector2i = _action_range_paint_stand(
					unit,
					hover_coord,
					planning_input,
					settled_board,
					range_stand_origin,
					director,
					board,
					settled_preview_paths,
					settled_slots,
				)
				if range_origin.x > -900000:
					plan["next_aim_origin"] = range_origin
			plan["show_blast"] = (
				show_action_range
				and not _is_settled_walk_only_hover(
					unit,
					hover_coord,
					planning_input,
					settled_preview_paths,
					settled_board,
				)
			)
			if plan["show_blast"] and plan["next_aim_origin"] != none:
				plan["blast_origin"] = plan["next_aim_origin"]
		PhaseKind.NON_MOVEMENT:
			var aim_stand: Vector2i = locked_stand
			if aim_stand.x > -900000:
				plan["locked_aim_origin"] = aim_stand
			var post_timing: int = director.get_planning_move_timing(unit.id)
			if (
				post_timing == GameEnums.MoveTiming.POST_ACTION
				and not director.unit_has_move_planned_at_timing(unit.id, post_timing)
				and planning_input != null
			):
				var settled_unit: UnitState = (
					settled_board.get_unit_by_id(unit.id)
					if settled_board != null
					else null
				)
				var hover_stand: Vector2i = (
					settled_unit.position
					if settled_unit != null
					else planning_input.predicted_stand_at_hover(unit.id, hover_coord)
				)
				if hover_stand.x > -900000:
					plan["next_move_origin"] = hover_stand
			var walk_only_blast: bool = false
			if planning_input != null and board.is_in_bounds(hover_coord):
				if planning_input.is_walk_only_hover_move(unit, hover_coord):
					walk_only_blast = true
				elif (
					not planning_input.awaiting_targeting_active()
					and planning_input.move_intent_destination(unit.id) == hover_coord
				):
					walk_only_blast = true
			elif _is_settled_walk_only_hover(
				unit,
				hover_coord,
				planning_input,
				settled_preview_paths,
				settled_board,
			):
				walk_only_blast = true
			plan["show_blast"] = (show_action_range or planning_input == null) and not walk_only_blast
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
	settled_board: BoardState = null,
	settled_preview_paths: Dictionary = {},
	range_stand_origin: Vector2i = Vector2i(-999999, -999999),
	settled_slots: Dictionary = {},
) -> Dictionary:
	var none: Vector2i = Vector2i(-999999, -999999)
	if director == null or board == null or unit == null:
		return {
			"stand_origin": none,
			"action_range_tiles": [],
			"blast_tiles": [],
			"move_tiles": [],
			"blast_on_hover_layer": false,
			"show_action_range": false,
			"show_blast": false,
			"phase": PhaseKind.NON_MOVEMENT,
			"ability_index": selected_ability,
		}
	var paint_board: BoardState = settled_board if settled_board != null else board
	var paint_unit: UnitState = unit
	if settled_board != null:
		var settled_unit: UnitState = settled_board.get_unit_by_id(unit.id)
		if settled_unit != null:
			paint_unit = settled_unit
	var plan: Dictionary = resolve_layer_origins(
		director,
		paint_board,
		paint_unit,
		selected_ability,
		planning_input,
		hover_coord,
		settled_board,
		settled_preview_paths,
		range_stand_origin,
		settled_slots,
	)
	var phase: int = int(plan.get("phase", PhaseKind.NON_MOVEMENT))
	var stand: Vector2i = _paint_stand_origin(plan, none)
	var action_range: Array[Vector2i] = []
	var blast: Array[Vector2i] = []
	## Locked blue (MOVEMENT) is overlay-only (EX-LOCKED-FIELD) — not recomputed every hover settle.
	var move_tiles: Array[Vector2i] = []
	if phase == PhaseKind.NON_MOVEMENT:
		move_tiles = resolve_move_tiles(
			director,
			paint_board,
			paint_unit,
			selected_ability,
			planning_input,
			plan,
			settled_board,
			settled_preview_paths,
		)
	var show_action_range: bool = bool(plan.get("show_action_range", false))
	var blast_on_hover_layer: bool = false
	match phase:
		PhaseKind.MOVEMENT:
			var next_aim: Vector2i = plan.get("next_aim_origin", none)
			if next_aim.x > -900000:
				action_range = action_range_tiles(
					director,
					paint_board,
					paint_unit,
					selected_ability,
					planning_input,
					next_aim,
					hover_coord,
					paint_board,
				)
		PhaseKind.NON_MOVEMENT:
			var locked_aim: Vector2i = plan.get("locked_aim_origin", none)
			if locked_aim.x > -900000 and show_action_range:
				var paint_stand: Vector2i = _action_range_paint_stand(
					paint_unit,
					hover_coord,
					planning_input,
					settled_board,
					range_stand_origin,
					director,
					paint_board,
					settled_preview_paths,
					settled_slots,
				)
				## Hover-shaped approach red only — locked red is overlay-only (EX-LOCKED-FIELD).
				if paint_stand.x > -900000 and paint_stand != locked_aim:
					action_range = action_range_tiles(
						director,
						paint_board,
						paint_unit,
						selected_ability,
						planning_input,
						paint_stand,
						hover_coord,
						paint_board,
					)
					stand = paint_stand
					blast_on_hover_layer = true
	var show_blast: bool = bool(plan.get("show_blast", false))
	if director != null and director.unit_has_committed_class_action(paint_unit.id):
		show_blast = false
	if (
		phase == PhaseKind.NON_MOVEMENT
		and show_blast
		and director != null
		and _unit_has_committed_ability(director, paint_unit.id)
		and board.is_in_bounds(hover_coord)
	):
		var locked_aim_blast: Vector2i = plan.get("locked_aim_origin", none)
		if locked_aim_blast.x > -900000 and hover_coord != locked_aim_blast:
			blast_on_hover_layer = true
	if show_blast:
		var blast_stand: Vector2i = stand
		if blast_stand.x <= -900000:
			if phase == PhaseKind.MOVEMENT:
				blast_stand = plan.get("next_aim_origin", none)
			else:
				blast_stand = plan.get("locked_aim_origin", none)
		if blast_stand.x > -900000:
			blast = blast_tiles(
				director,
				paint_board,
				paint_unit,
				selected_ability,
				planning_input,
				blast_stand,
				hover_coord,
				paint_board,
			)
	if blast.is_empty():
		show_blast = false
	return {
		"stand_origin": stand,
		"action_range_tiles": action_range,
		"blast_tiles": blast,
		"move_tiles": move_tiles,
		"blast_on_hover_layer": blast_on_hover_layer,
		"show_action_range": show_action_range,
		"show_blast": show_blast,
		"phase": phase,
		"ability_index": selected_ability,
	}


static func _is_settled_walk_only_hover(
	unit: UnitState,
	hover_coord: Vector2i,
	planning_input: CombatPlanningInput,
	settled_preview_paths: Dictionary,
	settled_board: BoardState,
) -> bool:
	if planning_input == null:
		return false
	if settled_board == null:
		return planning_input.is_walk_only_hover_move(unit, hover_coord)
	if not planning_input.active_movement_planning_step(unit):
		return false
	var route: Array = settled_preview_paths.get(unit.id, [])
	return route.size() >= 2 and route.back() == hover_coord


static func _paint_stand_origin(plan: Dictionary, none: Vector2i) -> Vector2i:
	var phase: int = int(plan.get("phase", PhaseKind.NON_MOVEMENT))
	var candidate: Vector2i = none
	if phase == PhaseKind.MOVEMENT:
		candidate = plan.get("next_aim_origin", none)
		if candidate == none:
			candidate = plan.get("locked_move_origin", none)
	else:
		candidate = plan.get("locked_aim_origin", none)
		if candidate == none:
			candidate = plan.get("next_move_origin", none)
	return candidate


## MOVE_PREVIEW_RULES locked current-phase field — blue/red bubble origin at phase entry.
## PERF GUARD: must NOT follow hover_coord or settled sim landing (see planning-hover-perf-mandatory.mdc).
static func _locked_current_phase_stand(
	unit: UnitState,
	range_stand_origin: Vector2i,
	director: CombatDirector,
	board: BoardState,
	planning_input: CombatPlanningInput,
) -> Vector2i:
	var none: Vector2i = Vector2i(-999999, -999999)
	if unit == null:
		return none
	if range_stand_origin.x > -900000:
		return range_stand_origin
	if planning_input != null:
		var phase_entry: Vector2i = planning_input.phase_entry_stand_cell(unit.id)
		if phase_entry.x > -900000:
			return phase_entry
	if director != null and board != null:
		return CombatPlanningPreview.forecast_stand_at_phase_entry(
			director, board, unit.id, null,
		)
	return none


static func _paired_premove_approach_slots(slots: Dictionary) -> bool:
	if slots.is_empty():
		return false
	var pre_steps: Array = slots.get("pre", []) as Array
	var action_steps: Array = slots.get("action", []) as Array
	return not pre_steps.is_empty() and not action_steps.is_empty()


## Next-phase / hover-aware range stand (red at predicted landing). Not for locked_move_origin.
static func _action_range_paint_stand(
	unit: UnitState,
	hover_coord: Vector2i,
	planning_input: CombatPlanningInput,
	settled_board: BoardState,
	range_stand_origin: Vector2i,
	director: CombatDirector,
	board: BoardState,
	settled_preview_paths: Dictionary = {},
	settled_slots: Dictionary = {},
) -> Vector2i:
	var none: Vector2i = Vector2i(-999999, -999999)
	if unit == null:
		return none
	var phase_entry: Vector2i = range_stand_origin
	if phase_entry.x <= -900000 and director != null and board != null:
		phase_entry = _locked_current_phase_stand(
			unit, none, director, board, planning_input,
		)
	if settled_board != null and board.is_in_bounds(hover_coord):
		if (
			planning_input != null
			and director != null
			and unit != null
		):
			var awaiting_action: TimelineAction = director.find_awaiting_action(unit.id)
			if (
				awaiting_action != null
				and awaiting_action.ability != null
				and planning_input._is_awaiting_movement_endpoint(
					unit, awaiting_action.ability,
				)
				and phase_entry.x > -900000
			):
				return phase_entry
			if (
				planning_input._voluntary_walk_orbit_phase_open(unit)
				and phase_entry.x > -900000
				and _unit_has_committed_ability(director, unit.id)
			):
				return phase_entry
		var landed_unit: UnitState = settled_board.get_unit_by_id(unit.id)
		if (
			landed_unit != null
			and landed_unit.position == hover_coord
			and phase_entry.x > -900000
			and landed_unit.position != phase_entry
		):
			return hover_coord
	if planning_input != null and planning_input.is_walk_only_hover_move(unit, hover_coord):
		if (
			planning_input.action_range_visible_for_hover()
			and director != null
			and director.get_planning_move_timing(unit.id) != GameEnums.MoveTiming.POST_ACTION
		):
			var walk_stand: Vector2i = planning_input.predicted_stand_at_hover(unit.id, hover_coord)
			if walk_stand.x > -900000:
				return walk_stand
	if planning_input != null and planning_input.action_range_visible_for_hover():
		if (
			director != null
			and director.get_planning_move_timing(unit.id) != GameEnums.MoveTiming.POST_ACTION
		):
			var premove_dest: Vector2i = planning_input.move_intent_destination(unit.id)
			if (
				board.is_in_bounds(premove_dest)
				and premove_dest == hover_coord
				and phase_entry.x > -900000
				and premove_dest != phase_entry
			):
				return premove_dest
	if (
		director != null
		and director.get_planning_move_timing(unit.id) == GameEnums.MoveTiming.POST_ACTION
		and range_stand_origin.x > -900000
	):
		return range_stand_origin
	if range_stand_origin.x > -900000 and settled_board != null:
		var sim_unit: UnitState = settled_board.get_unit_by_id(unit.id)
		if sim_unit != null and sim_unit.position != range_stand_origin:
			if sim_unit.position == hover_coord:
				return sim_unit.position
			var route: Variant = settled_preview_paths.get(unit.id, [])
			if route is Array and (route as Array).size() >= 2:
				var route_end: Variant = (route as Array).back()
				if (
					route_end is Vector2i
					and (route_end as Vector2i) == sim_unit.position
					and _paired_premove_approach_slots(settled_slots)
				):
					return sim_unit.position
	if range_stand_origin.x > -900000:
		return range_stand_origin
	if planning_input != null:
		var settled: Vector2i = planning_input.settled_action_range_stand_cell(unit.id)
		if settled.x > -900000:
			return settled
	if director != null and board != null:
		return CombatPlanningPreview.forecast_stand_at_phase_entry(
			director, board, unit.id, null,
		)
	return none


static func resolve_move_tiles(
	director: CombatDirector,
	board: BoardState,
	unit: UnitState,
	selected_ability: int,
	planning_input: CombatPlanningInput,
	plan: Dictionary,
	settled_board: BoardState = null,
	settled_preview_paths: Dictionary = {},
) -> Array[Vector2i]:
	if (
		director == null
		or board == null
		or unit == null
		or planning_input == null
		or tiles_blocked(
			director,
			unit,
			selected_ability,
			planning_input,
			unit.id == director.selected_unit_id,
		)
	):
		return []
	var origin: Vector2i = plan.get("locked_move_origin", Vector2i(-999999, -999999))
	if int(plan.get("phase", PhaseKind.NON_MOVEMENT)) == PhaseKind.NON_MOVEMENT:
		origin = plan.get("next_move_origin", origin)
	if origin.x <= -900000:
		return []
	return reachable_move_tiles(
		director,
		board,
		unit,
		selected_ability,
		planning_input,
		origin,
		settled_board,
		settled_preview_paths,
	)


static func reachable_move_tiles(
	director: CombatDirector,
	board: BoardState,
	unit: UnitState,
	selected_ability: int,
	planning_input: CombatPlanningInput,
	origin: Vector2i,
	settled_board: BoardState = null,
	settled_preview_paths: Dictionary = {},
) -> Array[Vector2i]:
	if (
		director == null
		or board == null
		or unit == null
		or (planning_input == null and unit.id == director.selected_unit_id)
	):
		return []
	var is_selected: bool = unit.id == director.selected_unit_id
	var phase_entry: Vector2i = Vector2i(-999999, -999999)
	if is_selected and planning_input != null:
		phase_entry = planning_input.phase_entry_stand_cell(unit.id)
	var use_settled_for_flood: bool = (
		settled_board != null
		and phase_entry.x > -900000
		and origin != phase_entry
	)
	var projected: UnitState = null
	if is_selected:
		projected = (
			settled_board.get_unit_by_id(unit.id)
			if use_settled_for_flood
			else planning_input.projected_unit_for_preview(unit.id)
		)
	var move_board: BoardState = board
	if is_selected:
		move_board = (
			settled_board
			if use_settled_for_flood
			else CombatPlanningPreview.planning_projection_board(director, board)
		)
	var move_actor: UnitState = projected if projected != null else unit
	var move_budget: int = move_budget_for_preview(
		director,
		move_actor,
		selected_ability,
		planning_input if is_selected else null,
	)
	if not is_selected:
		move_budget = move_actor.movement.points_left
	if move_budget <= 0:
		return []
	var move_cost: int = 2 if move_actor.has_status(GameEnums.StatusType.BLEED) else 1
	var movement_type: int = (
		move_actor.definition.movement_type
		if move_actor.definition != null
		else GameEnums.MovementType.WALK
	)
	var move_ability: AbilityData = null
	if is_selected and planning_input != null:
		move_ability = planning_input.route_pathfinding_ability_for_hover(move_actor)
	var tiles: Array[Vector2i] = MovementSystem.get_reachable_tiles(
		move_board,
		origin,
		move_budget,
		movement_type,
		move_cost,
		move_ability,
	)
	if is_selected and planning_input != null:
		var painted_waypoints: Array = (
			settled_preview_paths.get(unit.id, [])
			if settled_board != null
			else planning_input.painted_corridor_waypoints_for_blue_tiles(unit.id)
		)
		for painted: Vector2i in painted_waypoints:
			if not tiles.has(painted):
				tiles.append(painted)
	return tiles


static func move_budget_for_preview(
	director: CombatDirector,
	unit: UnitState,
	selected_ability: int,
	planning_input: CombatPlanningInput = null,
) -> int:
	if unit == null or director == null:
		return 0
	if unit.has_status(GameEnums.StatusType.ROOT) or unit.has_status(GameEnums.StatusType.STAGGER):
		return 0
	if director.get_planning_move_timing(unit.id) < 0:
		return 0
	if planning_input != null and planning_input.extended_move_budget_active(unit):
		return AbilitySystem.preview_move_budget_with_run(unit)
	if selected_ability >= 0:
		var ability: AbilityData = CombatDirector.resolve_selected_ability(unit, selected_ability)
		if (
			ability != null
			and AbilitySystem.is_run_ability(ability)
			and unit.ability.points_left >= ability.action_point_cost
		):
			return AbilitySystem.preview_move_budget_with_run(unit)
	return AbilitySystem.planning_available_movement_points(unit)


static func action_range_tiles(
	director: CombatDirector,
	board: BoardState,
	unit: UnitState,
	selected_ability: int,
	planning_input: CombatPlanningInput,
	origin: Vector2i,
	hover_coord: Vector2i,
	plan_board: BoardState = null,
) -> Array[Vector2i]:
	var ability: AbilityData = CombatDirector.resolve_selected_ability(unit, selected_ability)
	var effective_board: BoardState = board
	if director != null and director.projected_state != null:
		effective_board = director.projected_state
	elif director != null and director.board != null:
		effective_board = director.board
	var range_actor: UnitState = effective_board.get_unit_by_id(unit.id) if effective_board != null else null
	if range_actor == null:
		range_actor = unit
	var awaiting: TimelineAction = (
		director.find_awaiting_action(unit.id)
		if director != null
		else null
	)
	if awaiting != null and awaiting.awaiting_module_index >= 0:
		return AbilitySystem.planning_module_range_tiles(
			effective_board,
			awaiting,
			awaiting.awaiting_module_index,
			origin,
			hover_coord,
		)
	return AbilitySystem.planning_action_range_tiles(
		effective_board, range_actor, ability, origin, [], hover_coord,
	)


static func blast_tiles(
	director: CombatDirector,
	board: BoardState,
	unit: UnitState,
	selected_ability: int,
	planning_input: CombatPlanningInput,
	origin: Vector2i,
	hover_coord: Vector2i,
	plan_board: BoardState = null,
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
		unit
		if plan_board != null
		else (
			planning_input.projected_unit_for_preview(unit.id)
			if planning_input != null
			else unit
		)
	)
	if actor == null:
		actor = unit
	var effective_board: BoardState = plan_board
	if effective_board == null:
		effective_board = (
			director.projected_state
			if director != null and director.projected_state != null
			else board
		)
	return AbilitySystem.planning_blast_tiles_at_target(
		effective_board, actor, ability, origin, hover_coord,
	)
