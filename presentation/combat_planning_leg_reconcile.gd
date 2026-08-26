extends RefCounted

## Isolated MOVE / postmove preview leg — keeps prior-leg tiles out of active preview.

const _EMPTY_WPS: Array[Vector2i] = []


static func _route_reaches_hover(route: Array, hover: Vector2i) -> bool:
	return not route.is_empty() and route.back() == hover


static func uses_isolated_move_leg_preview(input, unit_id: int) -> bool:
	if input._director == null or unit_id < 0:
		return false
	var actor: UnitState = input._proj_unit(unit_id)
	if actor == null:
		actor = input._director.board.get_unit_by_id(unit_id) if input._director.board != null else null
	if actor == null:
		return false
	var armed: TimelineAction = input._director.find_awaiting_action(unit_id)
	if (
		armed != null
		and armed.ability != null
		and input.awaiting_targeting_active()
	):
		var module_index: int = armed.awaiting_module_index if armed.awaiting_module_index >= 0 else 0
		if (
			AbilitySystem.planning_awaiting_phase_for_module(
				actor, armed.ability, module_index,
			)
			== GameEnums.PlanningAwaitingPhase.MOVEMENT_ENDPOINT
		):
			if not AbilitySystem.ability_uses_caster_teleport(armed.ability, actor):
				return true
	var ability: AbilityData = input._selected_ability_data(actor)
	if input._is_awaiting_movement_endpoint(actor, ability):
		if AbilitySystem.ability_uses_caster_teleport(ability, actor):
			return false
		return true
	return (
		input.dragging
		and input.force_basic_movement
		and input._director.get_planning_move_timing(unit_id) == GameEnums.MoveTiming.POST_ACTION
	)


static func _awaiting_move_leg_active(input, unit_id: int, actor: UnitState) -> bool:
	if input._director == null or actor == null:
		return false
	var armed: TimelineAction = input._director.find_awaiting_action(unit_id)
	if (
		armed != null
		and armed.ability != null
		and input.awaiting_targeting_active()
	):
		var module_index: int = armed.awaiting_module_index if armed.awaiting_module_index >= 0 else 0
		return (
			AbilitySystem.planning_awaiting_phase_for_module(
				actor, armed.ability, module_index,
			)
			== GameEnums.PlanningAwaitingPhase.MOVEMENT_ENDPOINT
		)
	return input._is_awaiting_movement_endpoint(actor, input._selected_ability_data(actor))


static func reconcile(input, unit_id: int, preview: Dictionary) -> void:
	if input._director == null or unit_id < 0:
		return
	var actor: UnitState = input._proj_unit(unit_id)
	if actor == null:
		actor = input._director.board.get_unit_by_id(unit_id) if input._director.board != null else null
	if actor == null:
		return
	var hover: Vector2i = Vector2i(-999999, -999999)
	if input.dragging:
		if input._qa_pointer_grid_override:
			hover = input._pointer_grid_cell()
		elif input._intent_state != null and input._director.board.is_in_bounds(
			input._intent_state.hover_coord
		):
			hover = input._intent_state.hover_coord
		else:
			hover = input._pointer_grid_cell()
	elif input._intent_state != null:
		hover = input._intent_state.hover_coord
	if not input._director.board.is_in_bounds(hover):
		return
	if not uses_isolated_move_leg_preview(input, unit_id):
		return
	var ability: AbilityData = input._selected_ability_data(actor)
	var stand: Vector2i = Vector2i(-999999, -999999)
	if _awaiting_move_leg_active(input, unit_id, actor):
		stand = input._awaiting_endpoint_origin(actor)
	elif input.dragging:
		stand = input._active_move_drag_origin(actor)
	else:
		return
	if stand.x <= -900000:
		return
	var forbidden: Dictionary = CombatPlanningPreview.prior_leg_forbidden_cells(
		input._director, unit_id, stand,
	)
	if _awaiting_move_leg_active(input, unit_id, actor):
		if AbilitySystem.ability_uses_caster_teleport(ability, actor):
			return
	var current_route: Array = input.preview_state.preview_paths.get(unit_id, [])
	if (
		current_route.size() >= 2
		and not CombatPlanningPreview.route_touches_forbidden(current_route, forbidden)
		and current_route.back() == hover
	):
		return
	var route: Array = _resolve_route(input, unit_id, actor, stand, hover, forbidden, preview)
	input.preview_state.preview_paths[unit_id] = route
	var route_size: int = route.size()
	input.preview_state.preview_splits[unit_id] = route_size
	input.preview_state.preview_post_splits[unit_id] = route_size
	if not input.preview_state.action_splits.has(unit_id):
		input.preview_state.action_splits[unit_id] = 0


static func _resolve_route(
	input,
	unit_id: int,
	actor: UnitState,
	stand: Vector2i,
	hover: Vector2i,
	forbidden: Dictionary,
	preview: Dictionary,
) -> Array:
	var armed_route: Array = _route_from_armed_awaiting_move(
		input, unit_id, actor, stand, hover, forbidden,
	)
	if armed_route.size() >= 2 and _route_reaches_hover(armed_route, hover):
		return armed_route
	if (
		input.dragging
		and input._drag_unit_id == unit_id
		and input._drag_route.size() >= 2
		and input._drag_route[0] == stand
		and _route_reaches_hover(input._drag_route, hover)
		and not CombatPlanningPreview.route_touches_forbidden(input._drag_route, forbidden)
	):
		return input._drag_route.duplicate()
	var preview_route: Array = _route_from_preview_actions(unit_id, stand, preview)
	if (
		preview_route.size() >= 2
		and _route_reaches_hover(preview_route, hover)
		and not CombatPlanningPreview.route_touches_forbidden(preview_route, forbidden)
	):
		return preview_route
	var snapshot_route: Array = _route_from_intent_snapshot(input, unit_id, stand, hover)
	if (
		snapshot_route.size() >= 2
		and _route_reaches_hover(snapshot_route, hover)
		and not CombatPlanningPreview.route_touches_forbidden(snapshot_route, forbidden)
	):
		return snapshot_route
	if _awaiting_move_leg_active(input, unit_id, actor):
		if AbilitySystem.planning_is_valid_awaiting_endpoint(
			stand, hover, input._selected_ability_data(actor), actor, input._proj(),
		):
			var route_wps: Array[Vector2i] = []
			if input.dragging:
				route_wps = input._route_waypoints()
			var ability: AbilityData = input._selected_ability_data(actor)
			var built_wps: Array[Vector2i] = []
			if AbilitySystem.ability_uses_l_shape_path(ability, actor):
				var budget: int = AbilitySystem.active_motion_max_range(actor, ability)
				built_wps = MovementSystem._l_shape_path(
					input._proj(), stand, hover, budget, actor, ability,
				)
			if built_wps.is_empty():
				built_wps = input._director.preview_waypoints_for_hover(
					input._proj(), actor, hover, route_wps, ability, true,
				)
			var action: TimelineAction = TimelineAction.make_ability(
				unit_id,
				input._selected_ability_data(actor),
				hover,
				AbilitySystem.planning_commit_target_unit_id(
					input._selected_ability_data(actor), -1,
				),
				GameEnums.MoveTiming.PRE_ACTION,
				built_wps,
			)
			var dash_route: Array = CombatPlanningPreview.movement_intent_cells(stand, action)
			if (
				dash_route.size() >= 2
				and _route_reaches_hover(dash_route, hover)
				and not CombatPlanningPreview.route_touches_forbidden(dash_route, forbidden)
			):
				return dash_route
		var corridor_route: Array = _route_from_awaiting_corridor(
			input, unit_id, actor, stand, hover, forbidden,
		)
		if corridor_route.size() >= 2 and _route_reaches_hover(corridor_route, hover):
			return corridor_route
	elif (
		input.dragging
		and input.force_basic_movement
		and input._director.get_planning_move_timing(unit_id) == GameEnums.MoveTiming.POST_ACTION
	):
		var corridor_route: Array = _route_from_basic_postmove_corridor(
			input, unit_id, stand, hover, forbidden,
		)
		if corridor_route.size() >= 2 and _route_reaches_hover(corridor_route, hover):
			return corridor_route
		if input._director.board.is_in_bounds(hover):
			var post_wps: Array[Vector2i] = input._route_waypoints()
			var post_action: TimelineAction = TimelineAction.make_move(
				unit_id, hover, -1, post_wps, GameEnums.MoveTiming.POST_ACTION,
			)
			var post_route: Array = CombatPlanningPreview.movement_intent_cells(stand, post_action)
			if (
				post_route.size() >= 2
				and _route_reaches_hover(post_route, hover)
				and not CombatPlanningPreview.route_touches_forbidden(post_route, forbidden)
			):
				return post_route
	var slot_route: Array = _route_from_hover_slots(input, unit_id, stand, hover)
	if (
		slot_route.size() >= 2
		and _route_reaches_hover(slot_route, hover)
		and not CombatPlanningPreview.route_touches_forbidden(slot_route, forbidden)
	):
		return slot_route
	return [stand]


static func _route_from_awaiting_corridor(
	input,
	unit_id: int,
	actor: UnitState,
	stand: Vector2i,
	hover: Vector2i,
	forbidden: Dictionary,
) -> Array:
	var ability: AbilityData = input._selected_ability_data(actor)
	if ability == null:
		return [stand]
	if not AbilitySystem.planning_is_valid_awaiting_endpoint(
		stand, hover, ability, actor, input._proj(),
	):
		return [stand]
	var board: BoardState = input._proj()
	if board == null or not board.is_in_bounds(hover):
		return [stand]
	var budget: int = AbilitySystem.active_motion_max_range(actor, ability)
	var movement_type: GameEnums.MovementType = (
		actor.definition.movement_type
		if actor.definition != null
		else GameEnums.MovementType.WALK
	)
	var corridor: Array[Vector2i] = MovementSystem.drag_corridor_path(
		board,
		stand,
		hover,
		budget,
		movement_type,
		MovementSystem.move_cost_for(actor),
		actor,
		ability,
	)
	if corridor.is_empty():
		return [stand]
	var route: Array = [stand]
	for wp: Vector2i in corridor:
		if forbidden.has(wp):
			return [stand]
		route.append(wp)
	if route.size() < 2:
		return [stand]
	return route


static func _route_from_basic_postmove_corridor(
	input,
	unit_id: int,
	stand: Vector2i,
	hover: Vector2i,
	forbidden: Dictionary,
) -> Array:
	var board: BoardState = input._proj()
	var actor: UnitState = input._proj_unit(unit_id)
	if board == null or actor == null or not board.is_in_bounds(hover):
		return [stand]
	var movement_type: GameEnums.MovementType = (
		actor.definition.movement_type
		if actor.definition != null
		else GameEnums.MovementType.WALK
	)
	var corridor: Array[Vector2i] = MovementSystem.drag_corridor_path(
		board,
		stand,
		hover,
		actor.movement.points_left,
		movement_type,
		MovementSystem.move_cost_for(actor),
		actor,
	)
	if corridor.is_empty():
		return [stand]
	var route: Array = [stand]
	for wp: Vector2i in corridor:
		if forbidden.has(wp):
			return [stand]
		route.append(wp)
	if route.size() < 2:
		return [stand]
	return route


static func _route_from_hover_slots(
	input,
	unit_id: int,
	stand: Vector2i,
	hover: Vector2i,
) -> Array:
	var waypoints: Array[Vector2i] = []
	if input.dragging:
		waypoints = input._route_waypoints()
	var empty_legal: Array[Vector2i] = _EMPTY_WPS
	var slots: Dictionary = input._final_commit_slots_for_interaction(
		unit_id,
		hover,
		waypoints,
		empty_legal,
		Vector2i(-999999, -999999),
		-1,
		false,
	)
	return _route_from_slots_dict(slots, unit_id, stand)


static func _route_from_armed_awaiting_move(
	input,
	unit_id: int,
	actor: UnitState,
	stand: Vector2i,
	hover: Vector2i,
	forbidden: Dictionary,
) -> Array:
	if input._director == null or actor == null:
		return [stand]
	var armed: TimelineAction = input._director.find_awaiting_action(unit_id)
	if armed == null or armed.ability == null:
		return [stand]
	var module_index: int = armed.awaiting_module_index if armed.awaiting_module_index >= 0 else 0
	if (
		AbilitySystem.planning_awaiting_phase_for_module(actor, armed.ability, module_index)
		!= GameEnums.PlanningAwaitingPhase.MOVEMENT_ENDPOINT
	):
		return [stand]
	if not AbilitySystem.planning_is_valid_awaiting_endpoint(
		stand, hover, armed.ability, actor, input._proj(),
	):
		return [stand]
	var built_wps: Array[Vector2i] = []
	if AbilitySystem.ability_uses_l_shape_path(armed.ability, actor):
		var budget: int = AbilitySystem.active_motion_max_range(actor, armed.ability)
		built_wps = MovementSystem._l_shape_path(
			input._proj(), stand, hover, budget, actor, armed.ability,
		)
	if built_wps.is_empty():
		var route_wps: Array[Vector2i] = _EMPTY_WPS
		if input.dragging:
			route_wps = input._route_waypoints()
		built_wps = input._director.preview_waypoints_for_hover(
			input._proj(), actor, hover, route_wps, armed.ability, true,
		)
	var action: TimelineAction = TimelineAction.make_ability(
		unit_id,
		armed.ability,
		hover,
		AbilitySystem.planning_commit_target_unit_id(armed.ability, -1),
		GameEnums.MoveTiming.PRE_ACTION,
		built_wps,
	)
	var route: Array = CombatPlanningPreview.movement_intent_cells(stand, action)
	if (
		route.size() >= 2
		and _route_reaches_hover(route, hover)
		and not CombatPlanningPreview.route_touches_forbidden(route, forbidden)
	):
		return route
	return [stand]


static func _route_from_preview_actions(
	unit_id: int,
	stand: Vector2i,
	preview: Dictionary,
) -> Array:
	if preview.is_empty():
		return [stand]
	var actions_v: Variant = preview.get("actions", [])
	if not actions_v is Array:
		return [stand]
	for raw: Variant in actions_v:
		if not raw is TimelineAction:
			continue
		var act: TimelineAction = raw as TimelineAction
		if act.actor_id != unit_id:
			continue
		if act.type == GameEnums.ActionType.MOVE:
			return CombatPlanningPreview.movement_intent_cells(stand, act)
		if act.type != GameEnums.ActionType.ABILITY or act.ability == null:
			continue
		var step: TimelineAction = act
		if act.awaiting_target:
			step = AbilitySystem.planning_committed_prefix(act)
			if step == null:
				continue
		if (
			AbilitySystem.ability_has_movement_effect(act.ability)
			or not act.waypoints.is_empty()
			or act.target_coord != stand
		):
			return CombatPlanningPreview.movement_intent_cells(stand, step)
	return [stand]


static func _route_from_intent_snapshot(
	input,
	unit_id: int,
	stand: Vector2i,
	_hover: Vector2i,
) -> Array:
	if not input._intent_snapshot_valid or input._intent_snapshot_unit_id != unit_id:
		return [stand]
	return _route_from_slots_dict(input._intent_snapshot_slots, unit_id, stand)


static func _route_from_slots_dict(
	slots: Dictionary,
	unit_id: int,
	stand: Vector2i,
) -> Array:
	if slots.get("invalid", false):
		return [stand]
	for col: String in ["action", "pre", "post"]:
		for raw: Variant in slots.get(col, []):
			if not raw is TimelineAction:
				continue
			var act: TimelineAction = raw as TimelineAction
			if act.actor_id != unit_id:
				continue
			if act.type == GameEnums.ActionType.MOVE:
				return CombatPlanningPreview.movement_intent_cells(stand, act)
			if act.type != GameEnums.ActionType.ABILITY or act.ability == null:
				continue
			var step: TimelineAction = act
			if act.awaiting_target:
				step = AbilitySystem.planning_committed_prefix(act)
				if step == null:
					continue
			if (
				AbilitySystem.ability_has_movement_effect(act.ability)
				or not act.waypoints.is_empty()
				or act.target_coord != stand
			):
				return CombatPlanningPreview.movement_intent_cells(stand, step)
	return [stand]
