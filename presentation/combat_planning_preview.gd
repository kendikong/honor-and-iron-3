class_name CombatPlanningPreview
extends RefCounted

const INVALID_VISUAL_CELL := Vector2i(-999999, -999999)

## Shared live-preview state for tactical planning (paths and forecast board).

var forecast: CombatPlanningForecast = null
var preview_paths: Dictionary = {}
var preview_splits: Dictionary = {}
var preview_post_splits: Dictionary = {}
var action_splits: Dictionary = {}
var preview_pushes: Dictionary = {}
var preview_board: BoardState = null
var live_intents: Array = []
## Painted drag legs sealed across awaiting-move buffer clears (unit_id → true).
var painted_leg_sealed: Dictionary = {}


func clear_interaction() -> void:
	forecast = null
	live_intents.clear()


func clear_all() -> void:
	clear_interaction()
	preview_paths.clear()
	preview_splits.clear()
	preview_post_splits.clear()
	action_splits.clear()
	preview_pushes.clear()
	preview_board = null
	painted_leg_sealed.clear()
	live_intents.clear()


static func assign_preview_path_dict(
	paths: Dictionary,
	splits: Dictionary,
	unit_id: int,
	path: Array,
) -> void:
	if unit_id < 0 or path.is_empty() or path.size() < 2:
		return
	paths[unit_id] = path.duplicate()
	splits[unit_id] = path.size()


static func set_unit_preview_path(preview: CombatPlanningPreview, unit_id: int, path: Array) -> void:
	if preview == null:
		return
	if unit_id < 0 or path.is_empty() or path.size() < 2:
		if unit_id >= 0:
			clear_unit_preview_path(preview, unit_id)
		return
	## Post-move split index is owned by build_preview_paths (sim POST_ACTION); do not clobber on intent writes.
	assign_preview_path_dict(
		preview.preview_paths,
		preview.preview_splits,
		unit_id,
		path,
	)


static func clear_unit_preview_path(preview: CombatPlanningPreview, unit_id: int) -> void:
	if preview == null or unit_id < 0:
		return
	preview.preview_paths.erase(unit_id)
	preview.preview_splits.erase(unit_id)
	preview.preview_post_splits.erase(unit_id)
	preview.clear_sealed_painted_leg(unit_id)


## In-range attack hover with no approach step: one-cell stand anchor (not a walk route).
static func set_unit_stand_anchor_path(
	preview: CombatPlanningPreview, unit_id: int, stand: Vector2i,
) -> void:
	if preview == null or unit_id < 0:
		return
	## Not a voluntary-walk route — bypasses set_unit_preview_path size>=2 guard.
	preview.preview_paths[unit_id] = [stand]
	preview.preview_splits.erase(unit_id)
	preview.preview_post_splits.erase(unit_id)


func _commit_preview_path(actor_id: int, path: Array) -> void:
	set_unit_preview_path(self, actor_id, path)


func apply_result(
	res: Dictionary,
	director: CombatDirector,
) -> void:
	var temp_board: BoardState = res.get("temp_board")
	if temp_board == null:
		return
	preview_board = temp_board
	var base_board: BoardState = director.base_board if director.base_board != null else director.board
	var path_init_board: BoardState = base_board
	var actions_v: Variant = res.get("actions", [])
	var forecast_baseline: BoardState = forecast_baseline_board(director, base_board)
	forecast = CombatPlanningForecast.from_boards(
		forecast_baseline,
		temp_board,
		director.plan_revision if director != null else -1,
	)
	var events: Array = res.get("events", [])
	live_intents = res.get("intents", [])
	build_preview_paths(
		events,
		director,
		preview_paths,
		preview_splits,
		preview_pushes,
		preview_post_splits,
		action_splits,
		path_init_board,
	)
	var settled_paths: Variant = res.get("settled_preview_paths", null)
	if settled_paths is Dictionary:
		preview_paths = (settled_paths as Dictionary).duplicate(true)
	## Settled interaction geometry is already authoritative; only legacy result paths
	## need action-based completion.
	if actions_v is Array and not settled_paths is Dictionary:
		ensure_movement_intent_from_actions(
			actions_v as Array, path_init_board, {}, director,
		)
		ensure_swap_approach_paths_from_actions(
			actions_v as Array,
			path_init_board,
			preview_paths,
			preview_splits,
			preview_post_splits,
			action_splits,
			director,
		)
		adjust_swap_intent_actor_pose(temp_board, actions_v as Array, director)



## Walk→swap hover: inject approach route when sim path is missing but commit slots include a pre-walk.
static func ensure_swap_approach_paths_from_actions(
	actions: Array,
	start_board: BoardState,
	preview_paths: Dictionary,
	preview_splits: Dictionary,
	preview_post_splits: Dictionary,
	action_splits: Dictionary,
	director: CombatDirector = null,
) -> void:
	if start_board == null or actions.is_empty():
		return
	var actor_id: int = -1
	var walk_dest: Vector2i = Vector2i(-999999, -999999)
	var has_swap: bool = false
	var swap_action: TimelineAction = null
	var swap_index: int = -1
	for action_index: int in range(actions.size()):
		var raw: Variant = actions[action_index]
		if not raw is TimelineAction:
			continue
		var action: TimelineAction = raw as TimelineAction
		if (
			action.type == GameEnums.ActionType.ABILITY
			and action.ability != null
			and AbilitySystem.ability_has_swap_effect(action.ability)
		):
			has_swap = true
			swap_action = action
			actor_id = action.actor_id
			swap_index = action_index
	if not has_swap or actor_id < 0 or swap_action == null:
		return
	walk_dest = _swap_approach_cell(director, start_board, swap_action)
	var move_action: TimelineAction = null
	var move_index: int = -1
	for action_index2: int in range(actions.size()):
		var raw2: Variant = actions[action_index2]
		if not raw2 is TimelineAction:
			continue
		var candidate: TimelineAction = raw2 as TimelineAction
		if candidate.type == GameEnums.ActionType.MOVE and candidate.actor_id == actor_id:
			move_action = candidate
			move_index = action_index2
			if GridSystem.manhattan(candidate.target_coord, walk_dest) <= 1:
				walk_dest = candidate.target_coord
			break
	if move_action == null and director != null and director.plan_pre_move != null:
		for planned: TimelineAction in director.plan_pre_move.entries:
			if planned.type == GameEnums.ActionType.MOVE and planned.actor_id == actor_id:
				move_action = planned
				move_index = -1
				break
	if not has_swap or actor_id < 0 or walk_dest.x < -900000:
		return
	var actor: UnitState = start_board.get_unit_by_id(actor_id)
	if actor == null:
		return
	var origin: Vector2i = actor.position
	if move_action != null and move_index > swap_index:
		var existing_after_swap: Array = preview_paths.get(actor_id, [])
		if (
			existing_after_swap.size() >= 2
			and existing_after_swap.back() is Vector2i
			and (existing_after_swap.back() as Vector2i) == move_action.target_coord
		):
			return
	var route_cells: Array = [origin]
	if walk_dest != origin:
		if (
			move_action != null
			and not move_action.waypoints.is_empty()
			and (move_index < 0 or move_index < swap_index)
		):
			route_cells = movement_intent_cells(origin, move_action)
		else:
			route_cells = corridor_route_cells(start_board, actor, origin, walk_dest)
	if route_cells.size() < 2:
		return
	assign_preview_path_dict(
		preview_paths, preview_splits, actor_id, route_cells,
	)
	if not action_splits.has(actor_id):
		action_splits[actor_id] = 0


static func _swap_approach_cell(
	director: CombatDirector,
	board: BoardState,
	swap_action: TimelineAction,
) -> Vector2i:
	if director == null or board == null or swap_action == null or swap_action.ability == null:
		return Vector2i(-999999, -999999)
	var actor: UnitState = board.get_unit_by_id(swap_action.actor_id)
	if actor == null:
		return Vector2i(-999999, -999999)
	var ability_index: int = 0
	for i: int in range(actor.active_abilities.size()):
		if actor.active_abilities[i].id == swap_action.ability.id:
			ability_index = i
			break
	var target_unit_id: int = swap_action.target_unit_id
	if target_unit_id < 0:
		var ally: UnitState = board.get_unit_at(swap_action.target_coord)
		if ally != null:
			target_unit_id = ally.id
	if target_unit_id < 0:
		return Vector2i(-999999, -999999)
	return director.preview_approach_tile(
		swap_action.actor_id, target_unit_id, ability_index, actor.position,
	)


## Walk→swap hover: preview_board sim ends swapped; ghost must stand on the walk leg endpoint.
static func adjust_swap_intent_actor_pose(
	preview_board: BoardState,
	actions: Array,
	director: CombatDirector = null,
) -> void:
	if preview_board == null or actions.is_empty():
		return
	var actor_id: int = -1
	var walk_dest: Vector2i = Vector2i(-999999, -999999)
	var has_swap: bool = false
	var swap_action: TimelineAction = null
	for raw: Variant in actions:
		if not raw is TimelineAction:
			continue
		var action: TimelineAction = raw as TimelineAction
		if action.type == GameEnums.ActionType.MOVE:
			actor_id = action.actor_id
			walk_dest = action.target_coord
		elif (
			action.type == GameEnums.ActionType.ABILITY
			and action.ability != null
			and AbilitySystem.ability_has_swap_effect(action.ability)
		):
			has_swap = true
			swap_action = action
			if actor_id < 0:
				actor_id = action.actor_id
			if walk_dest.x < -900000 and preview_board.is_in_bounds(action.target_coord):
				var ally: UnitState = preview_board.get_unit_at(action.target_coord)
				if ally != null and ally.id != actor_id:
					walk_dest = action.target_coord
	if not has_swap or actor_id < 0:
		return
	if walk_dest.x < -900000 and swap_action != null:
		walk_dest = _swap_approach_cell(director, preview_board, swap_action)
	if walk_dest.x <= -900000:
		return
	var actor: UnitState = preview_board.get_unit_by_id(actor_id)
	if actor != null and actor.position != walk_dest:
		actor.position = walk_dest


## Replace the action leg inside a longer preview route with waypoint intent geometry.
static func _splice_waypoint_action_leg(
	route: Array,
	origin: Vector2i,
	action: TimelineAction,
) -> Array:
	var intent: Array = movement_intent_cells(origin, action)
	if intent.size() < 2:
		return route
	var start_idx: int = _last_route_index(route, origin)
	if start_idx < 0:
		start_idx = 0
	var end_idx: int = -1
	for i: int in range(start_idx + 1, route.size()):
		if route[i] is Vector2i and (route[i] as Vector2i) == action.target_coord:
			end_idx = i
	if end_idx < 0:
		return intent
	var out: Array = route.slice(0, start_idx + 1)
	for i: int in range(1, intent.size()):
		out.append(intent[i])
	if end_idx + 1 < route.size():
		out.append_array(route.slice(end_idx + 1, route.size()))
	return out


## Grid cells for a movement-skill intent: origin → waypoints → target_coord (commit-slot truth).
static func movement_intent_cells(origin: Vector2i, action: TimelineAction) -> Array:
	var cells: Array = [origin]
	if action == null:
		return cells
	for wp: Vector2i in action.waypoints:
		if cells.is_empty() or wp != cells[cells.size() - 1]:
			cells.append(wp)
	if action.target_coord != cells[cells.size() - 1]:
		cells.append(action.target_coord)
	return cells


## Cardinal facing along the last step of a cell route (intent or sim leg).
static func facing_from_intent_cells(cells: Array) -> int:
	if cells.size() < 2:
		return -1
	var prev_v: Variant = cells[cells.size() - 2]
	var dest_v: Variant = cells[cells.size() - 1]
	if not prev_v is Vector2i or not dest_v is Vector2i:
		return -1
	var prev: Vector2i = prev_v as Vector2i
	var dest: Vector2i = dest_v as Vector2i
	if prev == dest:
		return -1
	return PhysicsSystem.facing_from_vector(dest - prev)


static func facing_from_route_leg(leg: Array) -> int:
	return facing_from_intent_cells(leg)


## Facing for a committed plan step — matches arrow leg direction, not end-state unit.facing.
static func facing_along_planned_action(
	base_board: BoardState,
	plan: Timeline,
	action: TimelineAction,
	preview: CombatPlanningPreview = null,
) -> int:
	if action == null or base_board == null or plan == null:
		return -1
	var face_action: TimelineAction = action
	if action.awaiting_target:
		face_action = AbilitySystem.planning_committed_prefix(action)
		if face_action == null:
			return -1
	var origin: Vector2i = CombatUiFormatters.plan_action_origin_cell(base_board, plan, face_action)
	if face_action.type == GameEnums.ActionType.MOVE:
		return facing_from_intent_cells(movement_intent_cells(origin, face_action))
	if face_action.type != GameEnums.ActionType.ABILITY or face_action.ability == null:
		return -1
	if AbilitySystem.ability_has_movement_effect(face_action.ability) and preview != null:
		var leg: Array = committed_action_route_leg(face_action.actor_id, preview, face_action, origin)
		var route_face: int = facing_from_route_leg(leg)
		if route_face >= 0:
			return route_face
	return facing_from_intent_cells(movement_intent_cells(origin, face_action))


## Last displacement facing across a unit's ordered plan steps (pre → action → post).
static func facing_along_last_planned_step(
	base_board: BoardState,
	plan: Timeline,
	unit_id: int,
	preview: CombatPlanningPreview = null,
) -> int:
	if base_board == null or plan == null or unit_id < 0:
		return -1
	var last_facing: int = -1
	for action: TimelineAction in plan.entries:
		if action.actor_id != unit_id:
			continue
		var step_face: int = facing_along_planned_action(base_board, plan, action, preview)
		if step_face >= 0:
			last_facing = step_face
	return last_facing


## Seed move-leg origins from latest committed stand (live board / post-action end), not turn-start.
static func _seed_movement_origins(
	director: CombatDirector,
	start_board: BoardState,
	preview: CombatPlanningPreview = null,
) -> Dictionary:
	var origins: Dictionary = {}
	if start_board == null:
		return origins
	if director != null:
		for unit: UnitState in start_board.units:
			var stand: Vector2i = planning_latest_stand_cell(director, start_board, unit.id, preview)
			if stand.x <= -900000:
				var live: BoardState = director.live_planning_board()
				var live_unit: UnitState = live.get_unit_by_id(unit.id) if live != null else null
				stand = live_unit.position if live_unit != null else unit.position
			origins[unit.id] = stand
	else:
		for unit: UnitState in start_board.units:
			origins[unit.id] = unit.position
	return origins


## Pathfinding board for the next move leg (pre = live premove board, post = projected action end).
static func _path_board_for_unit(
	director: CombatDirector,
	start_board: BoardState,
	unit_id: int,
) -> BoardState:
	if director == null:
		return start_board
	if director.get_planning_move_timing(unit_id) == GameEnums.MoveTiming.POST_ACTION:
		return planning_projection_board(director, start_board)
	var live: BoardState = director.live_planning_board()
	return live if live != null else start_board


static func _paired_displace_preview_ability(action: TimelineAction, start_board: BoardState) -> bool:
	if action == null or action.ability == null:
		return false
	if AbilitySystem.ability_has_swap_effect(action.ability):
		return true
	var actor: UnitState = start_board.get_unit_by_id(action.actor_id) if start_board != null else null
	return AbilitySystem.motion_requires_occupied_target(actor, action.ability)


## Keep preview_paths aligned with movement abilities in `actions` when sim path is missing/short.
func ensure_movement_intent_from_actions(
	actions: Array,
	start_board: BoardState,
	actors_with_committed_move: Dictionary = {},
	director: CombatDirector = null,
	skip_path_merge_actor_ids: Dictionary = {},
) -> void:
	if start_board == null or actions.is_empty():
		return
	var origins: Dictionary = _seed_movement_origins(director, start_board, self)
	var move_actors: Dictionary = {}
	var movement_intents: Dictionary = {}
	for raw: Variant in actions:
		if not raw is TimelineAction:
			continue
		var action: TimelineAction = raw as TimelineAction
		if skip_path_merge_actor_ids.get(action.actor_id, false):
			if action.type == GameEnums.ActionType.MOVE:
				origins[action.actor_id] = action.target_coord
			continue
		if action.type == GameEnums.ActionType.MOVE:
			move_actors[action.actor_id] = true
			var move_origin_from_plan: Vector2i = origins.get(action.actor_id, action.target_coord) as Vector2i
			if not action.waypoints.is_empty():
				movement_intents[action.actor_id] = movement_intent_cells(move_origin_from_plan, action)
			var existing: Array = preview_paths.get(action.actor_id, [])
			var move_origin: Vector2i = origins.get(action.actor_id, action.target_coord) as Vector2i
			var path_board: BoardState = _path_board_for_unit(director, start_board, action.actor_id)
			var existing_end: Vector2i = (
				existing.back() as Vector2i if existing.size() > 0 else Vector2i(-999999, -999999)
			)
			var existing_start: Vector2i = (
				existing[0] as Vector2i if existing.size() > 0 else Vector2i(-999999, -999999)
			)
			if (
				actors_with_committed_move.get(action.actor_id, false)
				and existing.size() > 2
				and existing_start == move_origin
			):
				origins[action.actor_id] = action.target_coord
				continue
			var needs_route: bool = (
				existing.size() < 2
				or existing_end != action.target_coord
				or existing_start != move_origin
			)
			if needs_route:
				var route_cells: Array = movement_intent_cells(move_origin, action)
				if route_cells.size() < 2 and path_board != null:
					var actor: UnitState = path_board.get_unit_by_id(action.actor_id)
					if actor != null:
						route_cells = corridor_route_cells(
							path_board, actor, move_origin, action.target_coord, action.ability, director,
						)
				if route_cells.size() >= 2:
					var anchor_idx: int = _last_route_index(existing, move_origin)
					if anchor_idx >= 0:
						var merged: Array = existing.slice(0, anchor_idx + 1)
						if route_cells.size() >= 2 and (route_cells[0] as Vector2i) == move_origin:
							merged.append_array(route_cells.slice(1))
						else:
							merged.append_array(route_cells)
						_commit_preview_path(action.actor_id, merged)
					else:
						_commit_preview_path(action.actor_id, route_cells)
					if not action_splits.has(action.actor_id):
						action_splits[action.actor_id] = 0
			origins[action.actor_id] = action.target_coord
			continue
		if action.type != GameEnums.ActionType.ABILITY:
			continue
		if action.awaiting_target:
			action = AbilitySystem.planning_committed_prefix(action)
			if action == null:
				continue
		if action.ability != null and _paired_displace_preview_ability(action, start_board):
			## Swap / occupy-push are paired displacement, not an extra walk/dash leg.
			## Keep the preview route on the explicit approach MOVE (never sim tail).
			var approach: Vector2i = origins.get(action.actor_id, action.target_coord) as Vector2i
			if move_actors.get(action.actor_id, false):
				var planned_route: Array = movement_intents.get(action.actor_id, [])
				if planned_route.size() >= 2:
					_commit_preview_path(action.actor_id, planned_route)
					origins[action.actor_id] = action.target_coord
					continue
				var swap_board: BoardState = _path_board_for_unit(director, start_board, action.actor_id)
				var walker: UnitState = swap_board.get_unit_by_id(action.actor_id)
				var walk_origin: Vector2i = origins.get(action.actor_id, approach) as Vector2i
				if walker != null and walk_origin.x <= -900000:
					walk_origin = walker.position
				var route_cells: Array = [walk_origin]
				if approach != walk_origin:
					route_cells = corridor_route_cells(
						swap_board, walker, walk_origin, approach, action.ability, director,
					)
				if route_cells.size() >= 2:
					_commit_preview_path(action.actor_id, route_cells)
			else:
				var inferred: Vector2i = _swap_approach_cell(director, start_board, action)
				if inferred.x > -900000:
					approach = inferred
					var swap_board2: BoardState = _path_board_for_unit(director, start_board, action.actor_id)
					var walker2: UnitState = swap_board2.get_unit_by_id(action.actor_id)
					var walk_origin2: Vector2i = origins.get(action.actor_id, approach) as Vector2i
					if walker2 != null and walk_origin2.x <= -900000:
						walk_origin2 = walker2.position
					var route2: Array = [walk_origin2]
					if approach != walk_origin2:
						route2 = corridor_route_cells(
							swap_board2, walker2, walk_origin2, approach, action.ability, director,
						)
					if route2.size() >= 2:
						_commit_preview_path(action.actor_id, route2)
			origins[action.actor_id] = action.target_coord
			continue
		if action.ability == null or not AbilitySystem.ability_has_movement_effect(action.ability):
			continue
		var origin: Vector2i = origins.get(action.actor_id, action.target_coord) as Vector2i
		var relocation_actor: UnitState = start_board.get_unit_by_id(action.actor_id)
		if AbilitySystem.ability_uses_direct_relocation(action.ability, relocation_actor):
			var hop: Array = [origin, action.target_coord]
			_commit_preview_path(action.actor_id, hop)
			if not action_splits.has(action.actor_id):
				action_splits[action.actor_id] = 0
			origins[action.actor_id] = action.target_coord
			continue
		var intent: Array = movement_intent_cells(origin, action)
		if intent.size() < 2:
			continue
		var existing: Array = preview_paths.get(action.actor_id, [])
		## Committed waypoints are intent truth — never keep a same-endpoint sim path with different steps.
		if not action.waypoints.is_empty():
			if (
				not existing.is_empty()
				and existing.back() is Vector2i
				and (existing.back() as Vector2i) == origin
			):
				var combined: Array = existing.duplicate()
				combined.append_array(intent.slice(1))
				_commit_preview_path(action.actor_id, combined)
				if not action_splits.has(action.actor_id):
					action_splits[action.actor_id] = 0
				origins[action.actor_id] = action.target_coord
				continue
			if existing.size() > intent.size():
				_commit_preview_path(
					action.actor_id,
					_splice_waypoint_action_leg(existing, origin, action),
				)
			else:
				_commit_preview_path(action.actor_id, intent)
			if not action_splits.has(action.actor_id):
				action_splits[action.actor_id] = 0
			origins[action.actor_id] = action.target_coord
			continue
		if existing.size() >= 2:
			var last_cell: Variant = existing[existing.size() - 1]
			if last_cell is Vector2i and (last_cell as Vector2i) == action.target_coord:
				origins[action.actor_id] = action.target_coord
				continue
			## Committed MOVE slot(s) on plan — never truncate sim path for shorter ability intent.
			if actors_with_committed_move.get(action.actor_id, false) and existing.size() >= 2:
				origins[action.actor_id] = action.target_coord
				continue
			## Sim path (e.g. L-shaped trample + post-move tail) beats straight intent geometry.
			if existing.size() > intent.size():
				continue
		_commit_preview_path(action.actor_id, intent)
		if not action_splits.has(action.actor_id):
			action_splits[action.actor_id] = 0
		origins[action.actor_id] = action.target_coord


func ensure_movement_intent_from_plan(
	plan: Timeline,
	start_board: BoardState,
	director: CombatDirector = null,
) -> void:
	if plan == null:
		return
	var actors_with_committed_move: Dictionary = {}
	for act: TimelineAction in plan.entries:
		if act.type == GameEnums.ActionType.MOVE:
			actors_with_committed_move[act.actor_id] = true
	var actions: Array = []
	for entry: TimelineAction in plan.entries:
		actions.append(entry)
	ensure_movement_intent_from_actions(actions, start_board, actors_with_committed_move, director)


static func apply_movement_result(
	preview: CombatPlanningPreview,
	result: SimResult,
	director: CombatDirector,
	base_board: BoardState,
) -> void:
	if preview == null or result == null or result.final_state == null:
		return
	preview.preview_board = result.final_state
	build_preview_paths(
		result.events,
		director,
		preview.preview_paths,
		preview.preview_splits,
		preview.preview_pushes,
		preview.preview_post_splits,
		preview.action_splits,
	)
	preview.forecast = CombatPlanningForecast.from_boards(
		forecast_baseline_board(director, base_board),
		result.final_state,
		director.plan_revision if director != null else -1,
	)
	if director != null:
		preview.ensure_movement_intent_from_plan(director.get_player_plan(), base_board)


static func forecast_baseline_board(
	director: CombatDirector,
	fallback: BoardState,
) -> BoardState:
	if director != null and director.board != null:
		return director.board
	return fallback


static func from_sim_result(
	result: SimResult,
	director: CombatDirector,
	base_board: BoardState,
) -> CombatPlanningPreview:
	var preview := CombatPlanningPreview.new()
	if result == null or result.final_state == null:
		return preview
	preview.preview_board = result.final_state
	build_preview_paths(
		result.events,
		director,
		preview.preview_paths,
		preview.preview_splits,
		preview.preview_pushes,
		preview.preview_post_splits,
		preview.action_splits,
	)
	if base_board != null:
		preview.forecast = CombatPlanningForecast.from_boards(
			forecast_baseline_board(director, base_board),
			result.final_state,
			director.plan_revision if director != null else -1,
		)
	if director != null:
		preview.ensure_movement_intent_from_plan(director.get_player_plan(), base_board)
	return preview


static func build_preview_paths(
	events: Array,
	director: CombatDirector,
	paths: Dictionary,
	splits: Dictionary,
	pushes: Dictionary,
	post_splits: Dictionary = {},
	action_splits: Dictionary = {},
	init_board: BoardState = null,
) -> void:
	paths.clear()
	splits.clear()
	pushes.clear()
	post_splits.clear()
	action_splits.clear()
	var start_board: BoardState = init_board
	if start_board == null and director != null:
		start_board = director.base_board if director.base_board != null else director.board
	var current_positions: Dictionary = {}
	var post_move_marked: Dictionary = {}
	if start_board != null:
		for unit: UnitState in start_board.units:
			pushes[unit.id] = []
			current_positions[unit.id] = unit.position
	var enemy_phase: bool = false
	for event: Variant in events:
		if not event is SimEvent:
			continue
		var d: Dictionary = (event as SimEvent).data
		match (event as SimEvent).type:
			GameEnums.SimEventType.ENEMY_PHASE_BEGAN:
				enemy_phase = true
			GameEnums.SimEventType.ABILITY_USED:
				var id: int = int(d.get("actor", -1))
				if paths.has(id):
					action_splits[id] = maxi(0, (paths[id] as Array).size() - 1)
			GameEnums.SimEventType.UNIT_MOVED:
				var id: int = (event as SimEvent).moved_unit_id()
				if not paths.has(id):
					paths[id] = []
					splits[id] = 0
					post_splits[id] = 0
					pushes[id] = []
				if paths.has(id):
					var path: Array = d.get("path", [])
					var move_timing: int = int(
						d.get("move_timing", GameEnums.MoveTiming.PRE_ACTION)
					)
					if not enemy_phase and path.size() > 0:
						var route: Array = paths[id] as Array
						var leg_start: Vector2i = current_positions.get(id, Vector2i(-999999, -999999)) as Vector2i
						if route.is_empty() and leg_start.x > -900000:
							var first_step: Vector2i = path[0] as Vector2i
							if first_step != leg_start:
								route.append(leg_start)
					for c: Variant in path:
						if (
							not enemy_phase
							and move_timing == GameEnums.MoveTiming.POST_ACTION
							and not post_move_marked.get(id, false)
						):
							post_splits[id] = (paths[id] as Array).size()
							post_move_marked[id] = true
						(paths[id] as Array).append(c)
						if not enemy_phase:
							splits[id] = int(splits[id]) + 1
					if not path.is_empty():
						current_positions[id] = path[path.size() - 1]
			GameEnums.SimEventType.UNIT_PUSHED:
				var pid: int = int(d.get("unit", -1))
				var to_pos: Vector2i = d.get("to", Vector2i.ZERO)
				if pushes.has(pid):
					var from_unit: UnitState = (
						start_board.get_unit_by_id(pid) if start_board != null else null
					)
					var from_pos: Vector2i = current_positions.get(
						pid,
						from_unit.position if from_unit != null else to_pos,
					)
					## Voluntary displacement (SWAP): extend route only — not orange push arrows.
					if not enemy_phase and not d.has("pusher"):
						if not paths.has(pid):
							paths[pid] = []
							splits[pid] = 0
							post_splits[pid] = 0
						var route: Array = paths[pid]
						if route.is_empty():
							route.append(from_pos)
						var tail: Variant = route[route.size() - 1]
						if tail is Vector2i and (tail as Vector2i) != to_pos:
							route.append(to_pos)
							splits[pid] = int(splits[pid]) + 1
						current_positions[pid] = to_pos
						continue
					(pushes[pid] as Array).append([from_pos, to_pos])
					current_positions[pid] = to_pos


func copy_from(other: CombatPlanningPreview) -> void:
	forecast = other.forecast
	live_intents = other.live_intents.duplicate()
	sync_route_geometry_from(other)


## Route geometry mirror — sole bulk copy owner (promote, awaiting restore, overlay copy_from).
func sync_route_geometry_from(other: CombatPlanningPreview) -> void:
	if other == null:
		return
	preview_board = other.preview_board
	sync_route_paths_from(other)


func sync_route_paths_from(other: CombatPlanningPreview) -> void:
	if other == null:
		return
	preview_paths = other.preview_paths.duplicate(true)
	preview_splits = other.preview_splits.duplicate()
	preview_post_splits = other.preview_post_splits.duplicate()
	action_splits = other.action_splits.duplicate()
	preview_pushes = other.preview_pushes.duplicate(true)
	painted_leg_sealed = other.painted_leg_sealed.duplicate()


func seal_painted_leg(unit_id: int) -> void:
	if unit_id >= 0:
		painted_leg_sealed[unit_id] = true


func clear_route_geometry() -> void:
	preview_paths.clear()
	preview_splits.clear()
	preview_post_splits.clear()
	preview_pushes.clear()
	painted_leg_sealed.clear()


func is_painted_leg_sealed(unit_id: int) -> bool:
	return bool(painted_leg_sealed.get(unit_id, false))


func clear_sealed_painted_leg(unit_id: int) -> void:
	painted_leg_sealed.erase(unit_id)


## Read-only preview stub for commit-animation path slicing (paths dict only).
static func preview_read_stub(paths: Dictionary) -> CombatPlanningPreview:
	var preview := CombatPlanningPreview.new()
	preview.preview_paths = paths.duplicate(true)
	return preview


## Committed projection board — never use move-only `director.board` for planning geometry.
static func planning_projection_board(director: CombatDirector, fallback: BoardState) -> BoardState:
	if director != null and director.projected_state != null:
		return director.projected_state
	return fallback


## Sealed voluntary-walk leg locks preview_paths[unit][0] as phase-entry anchor.
static func sealed_phase_entry_anchor(
	preview: CombatPlanningPreview,
	unit_id: int,
) -> Vector2i:
	if preview != null and preview.is_painted_leg_sealed(unit_id):
		var sealed_route: Array = preview.preview_paths.get(unit_id, [])
		if not sealed_route.is_empty() and sealed_route[0] is Vector2i:
			return sealed_route[0] as Vector2i
	return Vector2i(-999999, -999999)


## Canonical stand cell for the next move preview leg (pre = live board, post = action end).
static func planning_latest_stand_cell(
	director: CombatDirector,
	fallback_board: BoardState,
	unit_id: int,
	preview: CombatPlanningPreview = null,
) -> Vector2i:
	return planning_move_origin_cell(director, fallback_board, unit_id, preview)


## Where the active planning move starts (projected stand, or action end for post-move).
static func planning_move_origin_cell(
	director: CombatDirector,
	fallback_board: BoardState,
	unit_id: int,
	preview: CombatPlanningPreview = null,
) -> Vector2i:
	if director == null or unit_id < 0:
		return Vector2i(-999999, -999999)
	var sealed: Vector2i = sealed_phase_entry_anchor(preview, unit_id)
	if sealed.x > -900000:
		return sealed
	var awaiting: TimelineAction = director.find_awaiting_action(unit_id)
	if awaiting != null and awaiting.awaiting_module_index > 0:
		var prior_stand: Vector2i = AbilitySystem.module_target_coord(
			awaiting,
			awaiting.awaiting_module_index - 1,
		)
		if fallback_board != null and fallback_board.is_in_bounds(prior_stand):
			return prior_stand
	var timing: int = director.get_planning_move_timing(unit_id)
	if timing < 0:
		var idle_board: BoardState = planning_projection_board(director, fallback_board)
		var idle_unit: UnitState = idle_board.get_unit_by_id(unit_id) if idle_board != null else null
		if idle_unit != null:
			return idle_unit.position
		return Vector2i(-999999, -999999)
	return planning_move_origin_cell_for_timing(director, fallback_board, unit_id, timing)


## Forecast stand at the start of the current planning phase (walk + locked tiles SSOT).
## Sealed voluntary-walk leg locks `preview_paths[unit][0]` so hover cannot drift the anchor.
static func forecast_stand_at_phase_entry(
	director: CombatDirector,
	fallback_board: BoardState,
	unit_id: int,
	preview: CombatPlanningPreview = null,
) -> Vector2i:
	return planning_move_origin_cell(director, fallback_board, unit_id, preview)


## Move-leg anchor for a specific timing slot (pre = projected stand, post = action end).
static func planning_move_origin_cell_for_timing(
	director: CombatDirector,
	fallback_board: BoardState,
	unit_id: int,
	timing: int,
) -> Vector2i:
	if director == null or unit_id < 0:
		return Vector2i(-999999, -999999)
	if timing == GameEnums.MoveTiming.POST_ACTION:
		var board: BoardState = planning_projection_board(director, fallback_board)
		var action_end: Vector2i = committed_plan_action_end_cell(director, board, unit_id)
		if board != null and board.is_in_bounds(action_end):
			return action_end
		return Vector2i(-999999, -999999)
	var board: BoardState = (
		director.live_planning_board()
		if director != null
		else planning_projection_board(director, fallback_board)
	)
	var unit: UnitState = board.get_unit_by_id(unit_id) if board != null else null
	if unit != null:
		return unit.position
	return Vector2i(-999999, -999999)


## Committed basic MOVE at `timing` for `unit_id`, if any.
static func committed_move_action(
	plan: Timeline,
	unit_id: int,
	timing: int,
) -> TimelineAction:
	if plan == null:
		return null
	var found: TimelineAction = null
	for act: TimelineAction in plan.entries:
		if (
			act.actor_id == unit_id
			and act.type == GameEnums.ActionType.MOVE
			and act.move_timing == timing
		):
			found = act
	return found


## Origin cell for a move leg — delegates planning_move_origin_cell (pre) or action end (post).
static func move_leg_origin_cell(
	director: CombatDirector,
	board: BoardState,
	unit_id: int,
	timing: int,
	move_action: TimelineAction = null,
	preview: CombatPlanningPreview = null,
) -> Vector2i:
	if timing == GameEnums.MoveTiming.POST_ACTION:
		var plan_board: BoardState = planning_projection_board(director, board)
		return committed_plan_action_end_cell(director, plan_board, unit_id)
	if move_action != null and director != null:
		var plan_board: BoardState = planning_projection_board(director, board)
		var unit: UnitState = plan_board.get_unit_by_id(unit_id) if plan_board != null else null
		return CombatUiFormatters.plan_action_origin_cell(
			plan_board,
			director.get_player_plan(),
			move_action,
			unit,
		)
	return planning_move_origin_cell(director, board, unit_id, preview)


## Route leg for the current planning move — same slice as overlay arrow drawing.
static func pending_move_route_leg(
	unit_id: int,
	preview: CombatPlanningPreview,
	director: CombatDirector,
	board: BoardState,
) -> Array:
	if preview == null or director == null:
		return []
	if (
		director.base_board == null
		and director.board == null
		and director.projected_state == null
	):
		return preview.preview_paths.get(unit_id, []).duplicate()
	var timing: int = director.get_planning_move_timing(unit_id)
	if timing < 0:
		return []
	return move_route_leg_from_preview(unit_id, preview, director, board, timing, true)


## Slice preview_paths for one move-timing slot (pending or committed).
static func move_route_leg_from_preview(
	unit_id: int,
	preview: CombatPlanningPreview,
	director: CombatDirector,
	board: BoardState,
	timing: int,
	pending: bool,
) -> Array:
	if preview == null or director == null:
		return []
	var route: Array = preview.preview_paths.get(unit_id, [])
	if route.size() < 2:
		return []
	if timing == GameEnums.MoveTiming.POST_ACTION:
		var plan_board: BoardState = planning_projection_board(director, board)
		var action_end: Vector2i = committed_plan_action_end_cell(director, plan_board, unit_id)
		if plan_board != null and not plan_board.is_in_bounds(action_end):
			return []
		var start_idx: int = _last_route_index(route, action_end)
		if start_idx < 0:
			return []
		var end_idx: int = route.size() - 1
		if start_idx >= end_idx:
			return []
		return route.slice(start_idx, end_idx + 1)
	var move_action: TimelineAction = committed_move_action(
		director.get_player_plan(), unit_id, timing,
	)
	if not pending and move_action != null:
		var committed_end: int = _last_route_index(route, move_action.target_coord)
		if committed_end > 0:
			return route.slice(0, committed_end + 1)
		return []
	var move_origin: Vector2i = planning_move_origin_cell_for_timing(
		director, board, unit_id, timing,
	)
	var start_idx: int = _last_route_index(route, move_origin)
	if start_idx < 0:
		start_idx = 0
	var end_idx: int = mini(int(preview.preview_splits.get(unit_id, route.size())), route.size())
	if start_idx >= end_idx:
		return []
	return route.slice(start_idx, end_idx)


## True when a committed PRE-MOVE displacement is visually done (sprite on target).
## Post-move legs always draw: they document action-end → post-dest even after full projection.
## When visual_cell is set, logical/projected board must not hide arrows before commit walk finishes.
static func committed_move_already_realized(
	director: CombatDirector,
	board: BoardState,
	unit_id: int,
	timing: int,
	move_action: TimelineAction,
	_route_leg: Array,
	visual_cell: Vector2i = INVALID_VISUAL_CELL,
) -> bool:
	if timing != GameEnums.MoveTiming.PRE_ACTION:
		return false
	if director == null or move_action == null:
		return false
	var origin: Vector2i = move_leg_origin_cell(
		director, board, unit_id, timing, move_action,
	)
	## Intentional loop / same-tile-end — origin equals target, path still matters.
	var target: Vector2i = move_action.target_coord
	if (
		_route_leg.size() >= 3
		and _route_leg[0] is Vector2i
		and _route_leg[_route_leg.size() - 1] is Vector2i
		and (_route_leg[0] as Vector2i) == target
		and (_route_leg[_route_leg.size() - 1] as Vector2i) == target
	):
		return false
	if origin == target:
		if (
			_route_leg.size() < 2
			or not _route_leg[0] is Vector2i
			or (_route_leg[0] as Vector2i) == target
		):
			return false
		var loop_live_unit: UnitState = board.get_unit_by_id(unit_id) if board != null else null
		return loop_live_unit != null and loop_live_unit.position == target
	if visual_cell != INVALID_VISUAL_CELL:
		if director.is_planning_move_instant(unit_id):
			return true
		return visual_cell == target
	if board != null:
		var live_unit: UnitState = board.get_unit_by_id(unit_id)
		if (
			live_unit != null
			and not _route_leg.is_empty()
			and _route_leg[0] is Vector2i
			and live_unit.position == target
			and (_route_leg[0] as Vector2i) != target
		):
			return true
		if live_unit != null and _committed_pre_move_satisfied(origin, live_unit.position, target):
			return true
	return false


static func _committed_pre_move_satisfied(
	origin: Vector2i,
	current: Vector2i,
	target: Vector2i,
) -> bool:
	if current == target:
		return true
	if current == origin:
		return false
	return GridSystem.manhattan(origin, current) >= GridSystem.manhattan(origin, target)


## Frozen committed move leg — preview slice, then plan geometry fallback.
static func committed_move_route_leg(
	unit_id: int,
	preview: CombatPlanningPreview,
	director: CombatDirector,
	board: BoardState,
	timing: int,
	visual_cell: Vector2i = INVALID_VISUAL_CELL,
) -> Array:
	if director == null:
		return []
	var move_action: TimelineAction = committed_move_action(
		director.get_player_plan(), unit_id, timing,
	)
	if move_action == null:
		return []
	var leg: Array = move_route_leg_from_preview(
		unit_id, preview, director, board, timing, false,
	)
	if leg.size() < 2:
		leg = _committed_move_route_from_slots(
			director, board, unit_id, timing, move_action,
		)
	if leg.size() >= 2:
		if committed_move_already_realized(
			director, board, unit_id, timing, move_action, leg, visual_cell,
		):
			return []
		return leg
	return []


static func _committed_move_route_from_slots(
	director: CombatDirector,
	board: BoardState,
	unit_id: int,
	timing: int,
	move_action: TimelineAction,
) -> Array[Vector2i]:
	if director == null or move_action == null:
		return []
	var origin: Vector2i = move_leg_origin_cell(
		director, board, unit_id, timing, move_action,
	)
	if origin.x <= -900000:
		return []
	var route: Array[Vector2i] = [origin]
	for waypoint: Vector2i in move_action.waypoints:
		if route.back() != waypoint:
			route.append(waypoint)
	if route.back() != move_action.target_coord:
		route.append(move_action.target_coord)
	return route


## Grid cell where the committed class action leaves the unit (post-move starts here).
static func committed_plan_action_end_cell(
	director: CombatDirector,
	board: BoardState,
	unit_id: int,
) -> Vector2i:
	if director == null:
		return Vector2i(-999999, -999999)
	var walked_end: Vector2i = _walk_committed_plan_action_end_cell(director, board, unit_id)
	if _plan_has_post_move_for_unit(director, unit_id):
		return walked_end
	var plan_board: BoardState = planning_projection_board(director, board)
	if plan_board != null:
		var projected: UnitState = plan_board.get_unit_by_id(unit_id)
		if projected != null:
			return projected.position
	return walked_end


static func _plan_has_post_move_for_unit(director: CombatDirector, unit_id: int) -> bool:
	if director == null:
		return false
	var plan: Timeline = director.get_player_plan()
	if plan == null:
		return false
	for act: TimelineAction in plan.entries:
		if (
			act.actor_id == unit_id
			and act.type == GameEnums.ActionType.MOVE
			and act.move_timing == GameEnums.MoveTiming.POST_ACTION
		):
			return true
	return false


static func _walk_committed_plan_action_end_cell(
	director: CombatDirector,
	board: BoardState,
	unit_id: int,
) -> Vector2i:
	var origin: Vector2i = Vector2i(-999999, -999999)
	var start_board: BoardState = director.base_board if director.base_board != null else board
	if start_board != null:
		var start_unit: UnitState = start_board.get_unit_by_id(unit_id)
		if start_unit != null:
			origin = start_unit.position
	if origin.x <= -900000 and board != null:
		var fallback_unit: UnitState = board.get_unit_by_id(unit_id)
		if fallback_unit != null:
			origin = fallback_unit.position
	var plan: Timeline = director.get_player_plan()
	if plan == null:
		return origin
	for act: TimelineAction in plan.entries:
		if act.actor_id != unit_id:
			continue
		if act.type == GameEnums.ActionType.MOVE:
			if act.move_timing == GameEnums.MoveTiming.POST_ACTION:
				continue
			origin = act.target_coord
		elif act.type == GameEnums.ActionType.ABILITY:
			var step: TimelineAction = act
			if act.awaiting_target:
				step = AbilitySystem.planning_committed_prefix(act)
				if step == null:
					continue
			origin = _plan_step_end_cell_for_action_end(origin, step)
	return origin


static func _plan_step_end_cell_for_action_end(origin: Vector2i, act: TimelineAction) -> Vector2i:
	if act == null:
		return origin
	if act.type == GameEnums.ActionType.MOVE:
		return act.target_coord
	if act.type != GameEnums.ActionType.ABILITY or act.awaiting_target:
		return origin
	if act.ability == null:
		return origin
	if act.ability.is_movement_kind() or AbilitySystem.ability_has_movement_effect(act.ability):
		return act.target_coord
	return origin


static func _plan_pre_move_contains_action(director: CombatDirector, action: TimelineAction) -> bool:
	if director == null or action == null:
		return false
	for act: TimelineAction in director.plan_pre_move.entries:
		if act == action:
			return true
		if (
			act.actor_id == action.actor_id
			and act.type == action.type
			and act.target_coord == action.target_coord
			and act.ability == action.ability
		):
			return true
	return false


## True when a committed pre-move displacement skill already applied on the live planning board.
static func premove_displacement_realized(
	director: CombatDirector,
	action: TimelineAction,
	live_board: BoardState = null,
) -> bool:
	if director == null or action == null or action.ability == null:
		return false
	if (
		action.type != GameEnums.ActionType.ABILITY
		or TimelineAction.timeline_column_for_ability(action.ability)
			!= GameEnums.TimelineColumn.PRE_MOVE
	):
		return false
	if not _plan_pre_move_contains_action(director, action):
		return false
	var board: BoardState = live_board
	if board == null:
		board = director.live_planning_board()
	if board == null:
		return false
	var turn_start: BoardState = director.base_board if director.base_board != null else director.board
	if turn_start == null:
		return false
	var actor_live: UnitState = board.get_unit_by_id(action.actor_id)
	var actor_start: UnitState = turn_start.get_unit_by_id(action.actor_id)
	if actor_live != null and actor_start != null and actor_live.position != actor_start.position:
		return true
	if action.target_unit_id >= 0:
		var target_live: UnitState = board.get_unit_by_id(action.target_unit_id)
		var target_start: UnitState = turn_start.get_unit_by_id(action.target_unit_id)
		if (
			target_live != null
			and target_start != null
			and target_live.position != target_start.position
		):
			return true
	if actor_live != null and actor_live.position == action.target_coord:
		return true
	return false


## Shared corridor waypoints (tiles entered) from origin to target.
## Premove and MOVE module legs use the same MovementSystem paint path.
static func corridor_waypoints_to_cell(
	board: BoardState,
	unit: UnitState,
	origin: Vector2i,
	target: Vector2i,
	budget: int,
	ability: AbilityData = null,
	director: CombatDirector = null,
	unit_id: int = -1,
) -> Array[Vector2i]:
	if board == null or unit == null or origin == target or budget <= 0:
		return []
	if not board.is_in_bounds(target):
		return []
	var movement_type: GameEnums.MovementType = (
		unit.definition.movement_type
		if unit.definition != null
		else GameEnums.MovementType.WALK
	)
	var move_cost: int = MovementSystem.move_cost_for(unit)
	var corridor: Array[Vector2i] = MovementSystem.drag_corridor_path(
		board,
		origin,
		target,
		budget,
		movement_type,
		move_cost,
		unit,
		ability,
	)
	if corridor.is_empty():
		return []
	if director != null and unit_id >= 0:
		var route: Array = [origin]
		route.append_array(corridor)
		var forbidden: Dictionary = prior_leg_forbidden_cells(director, unit_id, origin)
		if route_touches_forbidden(route, forbidden):
			return []
	return corridor


## Voluntary-walk corridor extend — PRE unarmed premove and MOVE-module awaiting share this builder.
static func voluntary_walk_corridor_waypoints(
	board: BoardState,
	unit: UnitState,
	leg_origin: Vector2i,
	hover_cell: Vector2i,
	budget: int,
	director: CombatDirector,
) -> Array[Vector2i]:
	return corridor_waypoints_to_cell(
		board,
		unit,
		leg_origin,
		hover_cell,
		budget,
		null,
		director,
		unit.id,
	)


## Full route cells (origin + corridor) for committed/sim rebuild — corridor only, no pathfind invent.
static func corridor_route_cells(
	board: BoardState,
	unit: UnitState,
	origin: Vector2i,
	target: Vector2i,
	ability: AbilityData = null,
	director: CombatDirector = null,
) -> Array:
	if board == null or unit == null:
		return []
	if origin == target:
		return []
	var budget: int = unit.movement.points_left
	var wps: Array[Vector2i] = corridor_waypoints_to_cell(
		board, unit, origin, target, budget, ability, director, unit.id,
	)
	if wps.is_empty():
		if GridSystem.manhattan(origin, target) == 1:
			return [origin, target]
		return []
	var route: Array = [origin]
	route.append_array(wps)
	return route


## Tiles from earlier committed legs that must not reappear on the active leg preview.
static func prior_leg_forbidden_cells(
	director: CombatDirector,
	unit_id: int,
	leg_origin: Vector2i,
) -> Dictionary:
	var forbidden: Dictionary = {}
	if director == null or unit_id < 0:
		return forbidden
	var pre_move: TimelineAction = committed_move_action(
		director.plan_pre_move, unit_id, GameEnums.MoveTiming.PRE_ACTION,
	)
	if pre_move != null:
		if director.base_board != null:
			var base_unit: UnitState = director.base_board.get_unit_by_id(unit_id)
			if base_unit != null and base_unit.position != leg_origin:
				forbidden[base_unit.position] = true
		for wp: Vector2i in pre_move.waypoints:
			if wp != leg_origin:
				forbidden[wp] = true
	for act: TimelineAction in director.plan_action.entries:
		if act == null or act.actor_id != unit_id:
			continue
		if act.type != GameEnums.ActionType.ABILITY:
			continue
		for wp: Vector2i in act.waypoints:
			if wp != leg_origin:
				forbidden[wp] = true
	return forbidden


static func route_touches_forbidden(
	route: Array,
	forbidden: Dictionary,
	skip_origin: bool = true,
) -> bool:
	if route.is_empty() or forbidden.is_empty():
		return false
	var start_idx: int = 1 if skip_origin else 0
	for i: int in range(start_idx, route.size()):
		var step: Variant = route[i]
		if step is Vector2i and forbidden.has(step as Vector2i):
			return true
	return false


## After a committed pre-move, drop stale route prefix so the next leg starts at latest stand.
static func anchor_preview_paths_to_latest_stand(
	director: CombatDirector,
	preview: CombatPlanningPreview,
	unit_id: int,
	fallback_board: BoardState = null,
) -> void:
	if director == null or preview == null or unit_id < 0:
		return
	var stand: Vector2i = forecast_stand_at_phase_entry(director, fallback_board, unit_id, preview)
	if not preview.is_painted_leg_sealed(unit_id) and director.projected_state != null:
		var projected_unit: UnitState = director.projected_state.get_unit_by_id(unit_id)
		if projected_unit != null:
			stand = projected_unit.position
	if stand.x <= -900000:
		return
	var route: Array = preview.preview_paths.get(unit_id, [])
	if route.is_empty():
		clear_unit_preview_path(preview, unit_id)
		return
	var start_idx: int = _last_route_index(route, stand)
	if start_idx < 0:
		clear_unit_preview_path(preview, unit_id)
		return
	var trimmed: Array = route.slice(start_idx)
	if trimmed.size() < 2:
		clear_unit_preview_path(preview, unit_id)
		return
	set_unit_preview_path(preview, unit_id, trimmed)


## Post-commit ratify trim — sole caller after slot promote (not sim apply_result merge).
static func trim_committed_paths_after_slot_promote(
	director: CombatDirector,
	committed: CombatPlanningPreview,
	unit_id: int,
	fallback_board: BoardState,
	preserve_full_route: bool,
) -> void:
	if preserve_full_route or director == null or committed == null or unit_id < 0:
		return
	anchor_preview_paths_to_latest_stand(director, committed, unit_id, fallback_board)


## Last index of `cell` in a preview route (handles revisits / stale post_split).
static func _last_route_index(route: Array, cell: Vector2i) -> int:
	var found: int = -1
	for i: int in range(route.size()):
		if route[i] is Vector2i and (route[i] as Vector2i) == cell:
			found = i
	return found


## Committed action movement leg — frozen to action.target_coord, not current move-timing slot.
static func committed_action_route_leg(
	unit_id: int,
	preview: CombatPlanningPreview,
	action: TimelineAction,
	origin: Vector2i,
) -> Array:
	if preview == null or action == null:
		return []
	var route: Array = preview.preview_paths.get(unit_id, [])
	if route.size() < 2:
		return []
	var end_idx: int = -1
	for i: int in range(route.size()):
		if route[i] is Vector2i and (route[i] as Vector2i) == action.target_coord:
			end_idx = i
	if end_idx < 1:
		return []
	var start_idx: int = route.find(origin)
	if start_idx < 0:
		start_idx = 0
	if start_idx >= end_idx:
		return []
	return route.slice(start_idx, end_idx + 1)


## Tween destination cells along a preview route (exclusive start, inclusive end).
static func destination_cells_from_route(
	route: Array,
	from_cell: Vector2i,
	to_cell: Vector2i,
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if route.size() < 2 or from_cell == to_cell:
		return out
	var start_idx: int = -1
	for i: int in range(route.size()):
		if route[i] is Vector2i and (route[i] as Vector2i) == from_cell:
			start_idx = i
			break
	var end_idx: int = -1
	for i: int in range(route.size()):
		if route[i] is Vector2i and (route[i] as Vector2i) == to_cell:
			end_idx = i
	if end_idx < 0:
		return out
	if start_idx < 0:
		if route[0] is Vector2i and (route[0] as Vector2i) == from_cell:
			start_idx = 0
		else:
			return out
	if start_idx >= end_idx:
		return out
	for i: int in range(start_idx + 1, end_idx + 1):
		if route[i] is Vector2i:
			out.append(route[i] as Vector2i)
	return out


## Walk cells from move-preview paths only — never re-pathfind.
static func planning_animation_cells(
	unit_id: int,
	preview: CombatPlanningPreview,
	from_cell: Vector2i,
	to_cell: Vector2i,
	director: CombatDirector = null,
	board: BoardState = null,
) -> Array[Vector2i]:
	if preview == null or from_cell == to_cell:
		return []
	var route: Array = preview.preview_paths.get(unit_id, [])
	if route.size() < 2:
		return []
	var full_cells: Array[Vector2i] = destination_cells_from_route(route, from_cell, to_cell)
	if not full_cells.is_empty():
		return full_cells
	if director != null:
		route = pending_move_route_leg(unit_id, preview, director, board)
		if route.size() >= 2:
			return destination_cells_from_route(route, from_cell, to_cell)
	return []


static func frozen_move_route_cells(
	unit_id: int,
	preview: CombatPlanningPreview,
) -> Array[Vector2i]:
	if preview == null or unit_id < 0:
		return []
	var route: Array = preview.preview_paths.get(unit_id, [])
	if route.size() < 2:
		return []
	var typed: Array[Vector2i] = []
	for tile: Variant in route:
		if tile is Vector2i:
			typed.append(tile as Vector2i)
	return typed


static func display_route_cells_from_preview(
	unit_id: int,
	preview: CombatPlanningPreview,
	director: CombatDirector,
	board: BoardState,
	movement_step_active: bool,
) -> Array[Vector2i]:
	if preview == null or unit_id < 0:
		return []
	if movement_step_active:
		var leg: Array = pending_move_route_leg(unit_id, preview, director, board)
		if leg.size() >= 2:
			return frozen_move_route_cells_from_array(leg)
		var fallback: Array = preview.preview_paths.get(unit_id, [])
		if fallback.size() >= 2:
			return frozen_move_route_cells_from_array(fallback)
		return []
	return frozen_move_route_cells(unit_id, preview)


## Committed timeline chevron route — single read API (frozen preview, then plan waypoints).
static func display_committed_action_route_cells(
	unit_id: int,
	preview: CombatPlanningPreview,
	director: CombatDirector,
	board: BoardState,
	action: TimelineAction,
	start_pos: Vector2i,
) -> Array:
	if action == null:
		return []
	var draw_route: Array = display_route_cells_from_preview(
		unit_id, preview, director, board, false,
	)
	if draw_route.size() >= 2:
		return draw_route
	var path_leg: Array = committed_action_route_leg(unit_id, preview, action, start_pos)
	if path_leg.size() >= 2:
		return path_leg
	return []


static func frozen_move_route_cells_from_array(route: Array) -> Array[Vector2i]:
	var typed: Array[Vector2i] = []
	for tile: Variant in route:
		if tile is Vector2i:
			typed.append(tile as Vector2i)
	return typed
