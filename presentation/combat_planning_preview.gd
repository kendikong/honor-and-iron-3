class_name CombatPlanningPreview
extends RefCounted

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
		ensure_movement_intent_from_actions(actions_v as Array, base_board)


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


## Keep preview_paths aligned with movement abilities in `actions` when sim path is missing/short.
func ensure_movement_intent_from_actions(actions: Array, start_board: BoardState) -> void:
	if start_board == null or actions.is_empty():
		return
	var origins: Dictionary = {}
	for unit: UnitState in start_board.units:
		origins[unit.id] = unit.position
	for raw: Variant in actions:
		if not raw is TimelineAction:
			continue
		var action: TimelineAction = raw as TimelineAction
		if action.type == GameEnums.ActionType.MOVE:
			origins[action.actor_id] = action.target_coord
			continue
		if action.type != GameEnums.ActionType.ABILITY or action.awaiting_target:
			continue
		if action.ability == null or not AbilitySystem.ability_has_movement_effect(action.ability):
			continue
		var origin: Vector2i = origins.get(action.actor_id, action.target_coord) as Vector2i
		var intent: Array = movement_intent_cells(origin, action)
		if intent.size() < 2:
			continue
		var existing: Array = preview_paths.get(action.actor_id, [])
		if existing.size() >= 2:
			var last_cell: Variant = existing[existing.size() - 1]
			if last_cell is Vector2i and (last_cell as Vector2i) == action.target_coord:
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


func ensure_movement_intent_from_plan(plan: Timeline, start_board: BoardState) -> void:
	if plan == null:
		return
	var actions: Array = []
	for entry: TimelineAction in plan.entries:
		actions.append(entry)
	ensure_movement_intent_from_actions(actions, start_board)


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
	var start_board: BoardState = director.base_board if director.base_board != null else director.board
	if start_board == null:
		return
	var current_positions: Dictionary = {}
	var post_move_marked: Dictionary = {}
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
				var id: int = int(d.get("actor", -1))
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
					var from_unit := start_board.get_unit_by_id(pid)
					var from_pos: Vector2i = current_positions.get(
						pid,
						from_unit.position if from_unit != null else to_pos,
					)
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


## Where the active planning move starts (projected stand, or action end for post-move).
static func planning_move_origin_cell(
	director: CombatDirector,
	fallback_board: BoardState,
	unit_id: int,
) -> Vector2i:
	if director == null or unit_id < 0:
		return Vector2i(-999999, -999999)
	var board: BoardState = planning_projection_board(director, fallback_board)
	if director.get_planning_move_timing(unit_id) == GameEnums.MoveTiming.POST_ACTION:
		var action_end: Vector2i = committed_plan_action_end_cell(director, board, unit_id)
		if board != null and board.is_in_bounds(action_end):
			return action_end
	var unit: UnitState = board.get_unit_by_id(unit_id) if board != null else null
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
	if preview == null:
		return []
	var route: Array = preview.preview_paths.get(unit_id, [])
	if route.size() < 2 or director == null:
		return []
	var split: int = int(preview.preview_splits.get(unit_id, route.size()))
	var end_idx: int = mini(split, route.size())
	var move_timing: int = director.get_planning_move_timing(unit_id)
	if move_timing == GameEnums.MoveTiming.POST_ACTION:
		return post_move_route_leg(unit_id, preview, director, board)
	var move_origin: Vector2i = planning_move_origin_cell(director, board, unit_id)
	var start_idx: int = _last_route_index(route, move_origin)
	if start_idx < 0:
		start_idx = 0
	return route.slice(start_idx, end_idx)


## Grid cell where the committed class action leaves the unit (post-move starts here).
static func committed_plan_action_end_cell(
	director: CombatDirector,
	board: BoardState,
	unit_id: int,
) -> Vector2i:
	if director == null:
		return Vector2i(-999999, -999999)
	var plan_board: BoardState = planning_projection_board(director, board)
	var origin: Vector2i = Vector2i(-999999, -999999)
	if plan_board != null:
		var live: UnitState = plan_board.get_unit_by_id(unit_id)
		if live != null:
			origin = live.position
	var plan: Timeline = director.get_player_plan()
	if plan != null:
		for act: TimelineAction in plan.entries:
			if act.actor_id != unit_id:
				continue
			if (
				act.type == GameEnums.ActionType.MOVE
				and act.move_timing == GameEnums.MoveTiming.PRE_ACTION
			):
				origin = act.target_coord
			elif act.type == GameEnums.ActionType.ABILITY and not act.awaiting_target:
				if (
					act.ability != null
					and (
						act.ability.is_movement_kind()
						or AbilitySystem.ability_has_movement_effect(act.ability)
					)
				):
					return act.target_coord
	if plan_board != null:
		var projected: UnitState = plan_board.get_unit_by_id(unit_id)
		if projected != null:
			return projected.position
	return origin


## Last index of `cell` in a preview route (handles revisits / stale post_split).
static func _last_route_index(route: Array, cell: Vector2i) -> int:
	var found: int = -1
	for i: int in range(route.size()):
		if route[i] is Vector2i and (route[i] as Vector2i) == cell:
			found = i
	return found


## Post-move leg: action destination → post-move target along preview_paths.
static func post_move_route_leg(
	unit_id: int,
	preview: CombatPlanningPreview,
	director: CombatDirector,
	board: BoardState,
) -> Array:
	if preview == null or director == null:
		return []
	var route: Array = preview.preview_paths.get(unit_id, [])
	if route.size() < 2:
		return []
	var plan_board: BoardState = planning_projection_board(director, board)
	var action_end: Vector2i = planning_move_origin_cell(director, board, unit_id)
	if plan_board != null and not plan_board.is_in_bounds(action_end):
		return []
	## Anchor at committed action end — never stale preview_post_splits or route.find first hit.
	var start_idx: int = _last_route_index(route, action_end)
	if start_idx < 0:
		return []
	var end_idx: int = route.size() - 1
	if start_idx >= end_idx:
		return []
	return route.slice(start_idx, end_idx + 1)


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
	var post_split: int = int(preview.preview_post_splits.get(unit_id, -1))
	if post_split > 1 and post_split - 1 < end_idx:
		end_idx = post_split - 1
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
	if director != null:
		route = pending_move_route_leg(unit_id, preview, director, board)
	if route.size() < 2:
		return []
	return destination_cells_from_route(route, from_cell, to_cell)
