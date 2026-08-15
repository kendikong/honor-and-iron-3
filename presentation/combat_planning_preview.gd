class_name CombatPlanningPreview
extends RefCounted

const INVALID_VISUAL_CELL := Vector2i(-999999, -999999)

## Shared live-preview state for tactical planning (paths, predicted HP/armor).

var predicted_hp: Dictionary = {}
var predicted_armor: Dictionary = {}
var predicted_ap: Dictionary = {}
var preview_paths: Dictionary = {}
var preview_splits: Dictionary = {}
var preview_post_splits: Dictionary = {}
var action_splits: Dictionary = {}
var preview_pushes: Dictionary = {}
var preview_board: BoardState = null
var live_intents: Array = []


func clear_interaction() -> void:
	predicted_hp.clear()
	predicted_armor.clear()
	predicted_ap.clear()
	live_intents.clear()


func clear_all() -> void:
	clear_interaction()
	preview_paths.clear()
	preview_splits.clear()
	preview_post_splits.clear()
	action_splits.clear()
	preview_pushes.clear()
	preview_board = null
	live_intents.clear()


func apply_result(res: Dictionary, director: CombatDirector) -> void:
	var temp_board: BoardState = res.get("temp_board")
	if temp_board == null:
		return
	preview_board = temp_board
	var base_board: BoardState = director.base_board if director.base_board != null else director.board
	predicted_hp.clear()
	predicted_armor.clear()
	predicted_ap.clear()
	if base_board != null:
		for unit: UnitState in base_board.units:
			var pv := temp_board.get_unit_by_id(unit.id)
			if pv != null and pv.is_alive():
				predicted_hp[unit.id] = pv.health.current_hp
				predicted_armor[unit.id] = pv.armor
				predicted_ap[unit.id] = pv.ability.points_left
			else:
				predicted_hp[unit.id] = 0
				predicted_armor[unit.id] = 0
				predicted_ap[unit.id] = 0
	var events: Array = res.get("events", [])
	live_intents = res.get("intents", [])
	build_preview_paths(events, director, preview_paths, preview_splits, preview_pushes, preview_post_splits, action_splits)
	## Intent geometry comes from planned actions (valid TILE/move selection), not only sim paths.
	var actions_v: Variant = res.get("actions", [])
	if actions_v is Array:
		ensure_movement_intent_from_actions(actions_v as Array, base_board, {}, director)
		ensure_swap_approach_paths_from_actions(
			actions_v as Array, base_board, preview_paths, preview_splits, action_splits, director,
		)
		adjust_swap_intent_actor_pose(temp_board, actions_v as Array, director)


## Walk→swap hover: inject approach route when sim path is missing but commit slots include a pre-walk.
static func ensure_swap_approach_paths_from_actions(
	actions: Array,
	start_board: BoardState,
	preview_paths: Dictionary,
	preview_splits: Dictionary,
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
			var budget: int = actor.movement.points_left
			var found: Array[Vector2i] = MovementSystem.find_path(
				start_board, origin, walk_dest, budget,
			)
			if not found.is_empty():
				route_cells.append_array(found)
			elif GridSystem.manhattan(origin, walk_dest) == 1:
				route_cells.append(walk_dest)
	if route_cells.size() < 2:
		return
	preview_paths[actor_id] = route_cells
	preview_splits[actor_id] = route_cells.size()
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
		var approach_board: BoardState = preview_board
		if director != null and director.base_board != null:
			approach_board = director.base_board
		walk_dest = _swap_approach_cell(director, approach_board, swap_action)
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
	if action == null or base_board == null or plan == null or action.awaiting_target:
		return -1
	var origin: Vector2i = CombatUiFormatters.plan_action_origin_cell(base_board, plan, action)
	if action.type == GameEnums.ActionType.MOVE:
		return facing_from_intent_cells(movement_intent_cells(origin, action))
	if action.type != GameEnums.ActionType.ABILITY or action.ability == null:
		return -1
	if AbilitySystem.ability_has_movement_effect(action.ability) and preview != null:
		var leg: Array = committed_action_route_leg(action.actor_id, preview, action, origin)
		var route_face: int = facing_from_route_leg(leg)
		if route_face >= 0:
			return route_face
	return facing_from_intent_cells(movement_intent_cells(origin, action))


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
) -> Dictionary:
	var origins: Dictionary = {}
	if start_board == null:
		return origins
	if director != null:
		for unit: UnitState in start_board.units:
			var stand: Vector2i = planning_latest_stand_cell(director, start_board, unit.id)
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
) -> void:
	if start_board == null or actions.is_empty():
		return
	var origins: Dictionary = _seed_movement_origins(director, start_board)
	var move_actors: Dictionary = {}
	var movement_intents: Dictionary = {}
	for raw: Variant in actions:
		if not raw is TimelineAction:
			continue
		var action: TimelineAction = raw as TimelineAction
		if action.type == GameEnums.ActionType.MOVE:
			move_actors[action.actor_id] = true
			var move_origin_from_plan: Vector2i = origins.get(action.actor_id, action.target_coord) as Vector2i
			if not action.waypoints.is_empty():
				movement_intents[action.actor_id] = movement_intent_cells(move_origin_from_plan, action)
			var existing: Array = preview_paths.get(action.actor_id, [])
			var move_origin: Vector2i = origins.get(action.actor_id, action.target_coord) as Vector2i
			var path_board: BoardState = _path_board_for_unit(director, start_board, action.actor_id)
			if existing.size() < 2:
				var route_cells: Array = movement_intent_cells(move_origin, action)
				if route_cells.size() < 2 and path_board != null:
					var actor: UnitState = path_board.get_unit_by_id(action.actor_id)
					var budget: int = actor.movement.points_left if actor != null else 999
					var found: Array[Vector2i] = MovementSystem.find_path(
						path_board, move_origin, action.target_coord, budget,
					)
					if not found.is_empty():
						route_cells = [move_origin]
						route_cells.append_array(found)
				if route_cells.size() >= 2:
					preview_paths[action.actor_id] = route_cells
					preview_splits[action.actor_id] = route_cells.size()
					if not action_splits.has(action.actor_id):
						action_splits[action.actor_id] = 0
			origins[action.actor_id] = action.target_coord
			continue
		if action.type != GameEnums.ActionType.ABILITY or action.awaiting_target:
			continue
		if action.ability != null and _paired_displace_preview_ability(action, start_board):
			## Swap / occupy-push are paired displacement, not an extra walk/dash leg.
			## Keep the preview route on the explicit approach MOVE (never sim tail).
			var approach: Vector2i = origins.get(action.actor_id, action.target_coord) as Vector2i
			if move_actors.get(action.actor_id, false):
				var planned_route: Array = movement_intents.get(action.actor_id, [])
				if planned_route.size() >= 2:
					preview_paths[action.actor_id] = planned_route
					preview_splits[action.actor_id] = planned_route.size()
					origins[action.actor_id] = action.target_coord
					continue
				var swap_board: BoardState = _path_board_for_unit(director, start_board, action.actor_id)
				var walker: UnitState = swap_board.get_unit_by_id(action.actor_id)
				var walk_origin: Vector2i = origins.get(action.actor_id, approach) as Vector2i
				if walker != null and walk_origin.x <= -900000:
					walk_origin = walker.position
				var route_cells: Array = [walk_origin]
				if approach != walk_origin:
					var budget: int = walker.movement.points_left if walker != null else 999
					var found: Array[Vector2i] = MovementSystem.find_path(
						swap_board, walk_origin, approach, budget,
					)
					if not found.is_empty():
						route_cells.append_array(found)
					elif GridSystem.manhattan(walk_origin, approach) == 1:
						route_cells.append(approach)
				if route_cells.size() >= 2:
					preview_paths[action.actor_id] = route_cells
					preview_splits[action.actor_id] = route_cells.size()
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
						var budget2: int = walker2.movement.points_left if walker2 != null else 999
						var found2: Array[Vector2i] = MovementSystem.find_path(
							swap_board2, walk_origin2, approach, budget2,
						)
						if not found2.is_empty():
							route2.append_array(found2)
						elif GridSystem.manhattan(walk_origin2, approach) == 1:
							route2.append(approach)
					if route2.size() >= 2:
						preview_paths[action.actor_id] = route2
						preview_splits[action.actor_id] = route2.size()
			origins[action.actor_id] = action.target_coord
			continue
		if action.ability == null or not AbilitySystem.ability_has_movement_effect(action.ability):
			continue
		var origin: Vector2i = origins.get(action.actor_id, action.target_coord) as Vector2i
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
				preview_paths[action.actor_id] = combined
				preview_splits[action.actor_id] = combined.size()
				if not action_splits.has(action.actor_id):
					action_splits[action.actor_id] = 0
				origins[action.actor_id] = action.target_coord
				continue
			if existing.size() > intent.size():
				preview_paths[action.actor_id] = _splice_waypoint_action_leg(existing, origin, action)
				preview_splits[action.actor_id] = (preview_paths[action.actor_id] as Array).size()
			else:
				preview_paths[action.actor_id] = intent
				preview_splits[action.actor_id] = intent.size()
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
		preview_paths[action.actor_id] = intent
		preview_splits[action.actor_id] = intent.size()
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
	var painted_paths: Dictionary = preview.preview_paths.duplicate(true)
	var painted_actors: Dictionary = {}
	for actor_id: Variant in painted_paths.keys():
		var route: Variant = painted_paths[actor_id]
		if route is Array and (route as Array).size() >= 2:
			painted_actors[int(actor_id)] = true
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
	for actor_id: Variant in painted_paths.keys():
		var route: Variant = painted_paths[actor_id]
		if route is Array and (route as Array).size() >= 2:
			preview.preview_paths[actor_id] = (route as Array).duplicate()
			preview.preview_splits[actor_id] = (route as Array).size()
	if base_board != null:
		for unit: UnitState in base_board.units:
			var pv := result.final_state.get_unit_by_id(unit.id)
			if pv != null and pv.is_alive():
				preview.predicted_hp[unit.id] = pv.health.current_hp
				preview.predicted_armor[unit.id] = pv.armor
				preview.predicted_ap[unit.id] = pv.ability.points_left
			else:
				preview.predicted_hp[unit.id] = 0
				preview.predicted_armor[unit.id] = 0
				preview.predicted_ap[unit.id] = 0
	if director != null and painted_actors.is_empty():
		preview.ensure_movement_intent_from_plan(director.get_player_plan(), base_board)


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
		for unit: UnitState in base_board.units:
			var pv := result.final_state.get_unit_by_id(unit.id)
			if pv != null and pv.is_alive():
				preview.predicted_hp[unit.id] = pv.health.current_hp
				preview.predicted_armor[unit.id] = pv.armor
				preview.predicted_ap[unit.id] = pv.ability.points_left
			else:
				preview.predicted_hp[unit.id] = 0
				preview.predicted_armor[unit.id] = 0
				preview.predicted_ap[unit.id] = 0
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
) -> void:
	paths.clear()
	splits.clear()
	pushes.clear()
	post_splits.clear()
	action_splits.clear()
	var start_board: BoardState = null
	if director != null:
		start_board = director.base_board if director.base_board != null else director.board
	var current_positions: Dictionary = {}
	var post_move_marked: Dictionary = {}
	if start_board != null:
		for unit: UnitState in start_board.units:
			paths[unit.id] = [unit.position]
			splits[unit.id] = 1
			post_splits[unit.id] = 1
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
					if not enemy_phase and not d.has("pusher") and paths.has(pid):
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


func get_predicted_hp(unit_id: int, current: int) -> int:
	return int(predicted_hp.get(unit_id, current))


func get_predicted_armor(unit_id: int, current: int) -> int:
	return int(predicted_armor.get(unit_id, current))


func get_predicted_ap(unit_id: int, current: int) -> int:
	return int(predicted_ap.get(unit_id, current))


func copy_from(other: CombatPlanningPreview) -> void:
	predicted_hp = other.predicted_hp.duplicate()
	predicted_armor = other.predicted_armor.duplicate()
	predicted_ap = other.predicted_ap.duplicate()
	live_intents = other.live_intents.duplicate()
	preview_board = other.preview_board
	preview_paths = other.preview_paths.duplicate(true)
	preview_splits = other.preview_splits.duplicate()
	preview_post_splits = other.preview_post_splits.duplicate()
	action_splits = other.action_splits.duplicate()
	preview_pushes = other.preview_pushes.duplicate(true)


## Committed projection board — never use move-only `director.board` for planning geometry.
static func planning_projection_board(director: CombatDirector, fallback: BoardState) -> BoardState:
	if director != null and director.projected_state != null:
		return director.projected_state
	return fallback


## Canonical stand cell for the next move preview leg (pre = live board, post = action end).
static func planning_latest_stand_cell(
	director: CombatDirector,
	fallback_board: BoardState,
	unit_id: int,
) -> Vector2i:
	if director == null or unit_id < 0:
		return Vector2i(-999999, -999999)
	var timing: int = director.get_planning_move_timing(unit_id)
	if timing < 0:
		timing = GameEnums.MoveTiming.PRE_ACTION
	return planning_move_origin_cell_for_timing(director, fallback_board, unit_id, timing)


## Where the active planning move starts (projected stand, or action end for post-move).
static func planning_move_origin_cell(
	director: CombatDirector,
	fallback_board: BoardState,
	unit_id: int,
) -> Vector2i:
	if director == null or unit_id < 0:
		return Vector2i(-999999, -999999)
	var timing: int = director.get_planning_move_timing(unit_id)
	if timing < 0:
		var idle_board: BoardState = planning_projection_board(director, fallback_board)
		var idle_unit: UnitState = idle_board.get_unit_by_id(unit_id) if idle_board != null else null
		if idle_unit != null:
			return idle_unit.position
		return Vector2i(-999999, -999999)
	return planning_move_origin_cell_for_timing(director, fallback_board, unit_id, timing)


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


## Origin cell for a move leg — turn-start walk for pre, action end for post.
static func move_leg_origin_cell(
	director: CombatDirector,
	board: BoardState,
	unit_id: int,
	timing: int,
	move_action: TimelineAction = null,
) -> Vector2i:
	if timing == GameEnums.MoveTiming.POST_ACTION:
		var plan_board: BoardState = planning_projection_board(director, board)
		return committed_plan_action_end_cell(director, plan_board, unit_id)
	var start_board: BoardState = board
	if director != null and director.base_board != null:
		start_board = director.base_board
	var unit: UnitState = start_board.get_unit_by_id(unit_id) if start_board != null else null
	if move_action != null and start_board != null:
		return CombatUiFormatters.plan_action_origin_cell(
			start_board,
			director.get_player_plan() if director != null else null,
			move_action,
			unit,
		)
	if unit != null:
		return unit.position
	return Vector2i(-999999, -999999)


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
	if leg.size() >= 2:
		if committed_move_already_realized(
			director, board, unit_id, timing, move_action, leg, visual_cell,
		):
			return []
		return leg
	var origin: Vector2i = move_leg_origin_cell(
		director, board, unit_id, timing, move_action,
	)
	if origin.x == -999999:
		return []
	var fallback: Array = movement_intent_cells(origin, move_action)
	if (
		fallback.size() >= 2
		and committed_move_already_realized(
			director, board, unit_id, timing, move_action, fallback, visual_cell,
		)
	):
		return []
	return fallback


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
		elif act.type == GameEnums.ActionType.ABILITY and not act.awaiting_target:
			origin = _plan_step_end_cell_for_action_end(origin, act)
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
	if action.type != GameEnums.ActionType.ABILITY or not action.ability.is_pre_move_planner():
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


## After a committed pre-move, drop stale route prefix so the next leg starts at latest stand.
static func anchor_preview_paths_to_latest_stand(
	director: CombatDirector,
	preview: CombatPlanningPreview,
	unit_id: int,
	fallback_board: BoardState = null,
) -> void:
	if director == null or preview == null or unit_id < 0:
		return
	var stand: Vector2i = planning_latest_stand_cell(director, fallback_board, unit_id)
	if stand.x <= -900000:
		return
	var route: Array = preview.preview_paths.get(unit_id, [])
	if route.is_empty():
		preview.preview_paths[unit_id] = [stand]
	else:
		var start_idx: int = _last_route_index(route, stand)
		if start_idx >= 0:
			preview.preview_paths[unit_id] = route.slice(start_idx)
		else:
			preview.preview_paths[unit_id] = [stand]
	var anchored: Array = preview.preview_paths.get(unit_id, [])
	preview.preview_splits[unit_id] = anchored.size()
	preview.preview_post_splits[unit_id] = anchored.size()


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


## Awaiting movement-skill arrow cells. Drag paint is intent truth — never swap to
## pathfinder order while the player is still painting toward the hover endpoint.
static func awaiting_movement_route_cells(
	origin: Vector2i,
	hover: Vector2i,
	drag_route: Array,
	sim_path: Array,
	action_split: int = -1,
) -> Array[Vector2i]:
	var path: Array = []
	if drag_route.size() >= 2:
		var hover_idx: int = drag_route.find(hover)
		if hover_idx > 0:
			path = drag_route.slice(1, hover_idx + 1)
		else:
			var tail: Variant = drag_route[drag_route.size() - 1]
			if tail is Vector2i and GridSystem.manhattan(tail as Vector2i, hover) == 1:
				path = drag_route.slice(1)
				path.append(hover)
	if path.is_empty() and sim_path.size() >= 2:
		var start_idx: int = action_split
		if start_idx < 0:
			start_idx = _last_route_index(sim_path, origin)
		if start_idx < 0:
			start_idx = 0
		if start_idx < sim_path.size() - 1:
			path = sim_path.slice(start_idx + 1, sim_path.size())
	var route_cells: Array[Vector2i] = [origin]
	for step: Variant in path:
		if step is Vector2i:
			route_cells.append(step)
	if route_cells.size() == 1:
		route_cells.append(hover)
	return route_cells
