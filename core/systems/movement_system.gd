class_name MovementSystem
extends RefCounted

## Purpose: Owns point-based unit movement and pathfinding.
## Responsibilities: Find a deterministic shortest path and walk a unit along it,
##   spending movement points and updating occupancy via GridSystem.
## Dependencies: BoardState, UnitState, TimelineAction, GridSystem, TerrainSystem,
##   PhysicsSystem, SimEvent.
## Lifecycle: stateless; only static functions.

## Find all tiles reachable within `max_steps` movement cost using Breadth-First-Search.
## O(N) performance, vastly faster than calling find_path for every tile.
static func get_reachable_tiles(board: BoardState, start: Vector2i, max_steps: int, movement_type: GameEnums.MovementType = GameEnums.MovementType.WALK, move_cost: int = 1) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = [start]
	
	if movement_type == GameEnums.MovementType.TELEPORT:
		for y in range(board.grid_size.y):
			for x in range(board.grid_size.x):
				var coord := Vector2i(x, y)
				if coord != start and not GridSystem.is_occupied(board, coord) and GridSystem.is_passable(board, coord):
					reachable.append(coord)
		return reachable

	var unit := board.get_unit_at(start)
	var cost_so_far: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		
		# A unit cannot end its movement on an occupied tile (e.g. an ally).
		# We still explore through allies, but they aren't "reachable" end points.
		if current != start and not GridSystem.is_occupied(board, current):
			reachable.append(current)

		for dir in GridSystem.DIRECTIONS:
			var next: Vector2i = current + dir
			var new_cost = cost_so_far[current] + move_cost
			if new_cost > max_steps:
				continue
			
			if cost_so_far.has(next) and cost_so_far[next] <= new_cost:
				continue
				
			if not _is_walkable_for(board, next, unit):
				continue
				
			cost_so_far[next] = new_cost
			queue.append(next)
			
	return reachable

## Deterministic breadth-first shortest path from start to goal.
## Returns the list of tiles to ENTER (excluding start). Empty if unreachable or
## already there. Result is truncated to max_steps tiles.
static func find_path(board: BoardState, start: Vector2i, goal: Vector2i, max_steps: int, movement_type: GameEnums.MovementType = GameEnums.MovementType.WALK, move_cost: int = 1) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if start == goal:
		return empty

	# Teleporters skip pathfinding entirely — warp to any unoccupied, in-bounds tile.
	if movement_type == GameEnums.MovementType.TELEPORT:
		if GridSystem.is_in_bounds(board, goal) and not GridSystem.is_occupied(board, goal):
			return [goal]
		return empty

	var unit := board.get_unit_at(start)
	var team := unit.team if unit != null else GameEnums.Team.PLAYER

	if not GridSystem.is_passable(board, goal):
		return empty

	var came_from: Dictionary = {}   # Vector2i -> Vector2i
	var visited: Dictionary = {}     # Vector2i -> true
	var queue: Array[Vector2i] = [start]
	visited[start] = true

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == goal:
			break
		for dir in GridSystem.DIRECTIONS:
			var next: Vector2i = current + dir
			if visited.has(next):
				continue
			if not _is_walkable_for(board, next, unit):
				continue
			visited[next] = true
			came_from[next] = current
			queue.append(next)

	if not came_from.has(goal):
		return empty

	var path: Array[Vector2i] = []
	var node: Vector2i = goal
	while node != start:
		path.push_front(node)
		node = came_from[node]

	if path.size() * move_cost > max_steps:
		path = path.slice(0, floori(max_steps / float(move_cost)))
		
	# A unit cannot end its movement on an occupied tile (e.g. an ally).
	# Backtrack until we find an empty tile.
	while path.size() > 0 and GridSystem.is_occupied(board, path[path.size() - 1]):
		path.pop_back()
		
	return path

static func move_cost_for(unit: UnitState) -> int:
	if unit != null and unit.has_status(GameEnums.StatusType.BLEED):
		return 2
	return 1


static func resolve_move_path(
	board: BoardState,
	unit: UnitState,
	target_coord: Vector2i,
	waypoints: Array[Vector2i],
	max_steps: int,
) -> Array[Vector2i]:
	if unit == null:
		return []
	var move_cost: int = move_cost_for(unit)
	var mt: GameEnums.MovementType = (
		unit.definition.movement_type
		if unit.definition != null
		else GameEnums.MovementType.WALK
	)
	if _is_legal_walk(board, unit.position, waypoints, max_steps, move_cost):
		return waypoints.duplicate()
	return find_path(board, unit.position, target_coord, max_steps, mt, move_cost)


static func can_reach_coord(
	board: BoardState,
	unit: UnitState,
	target_coord: Vector2i,
	waypoints: Array[Vector2i],
	max_steps: int,
) -> bool:
	var path: Array[Vector2i] = resolve_move_path(board, unit, target_coord, waypoints, max_steps)
	return not path.is_empty() and path[path.size() - 1] == target_coord


static func is_walkable_for(board: BoardState, coord: Vector2i, unit: UnitState) -> bool:
	return _is_walkable_for(board, coord, unit)


static func _is_walkable_for(board: BoardState, coord: Vector2i, unit: UnitState) -> bool:
	if not GridSystem.is_in_bounds(board, coord) or GridSystem.is_wall(board, coord):
		return false
	var tile := board.get_tile(coord)
	if tile != null and not tile.is_empty():
		var occ := board.get_unit_by_id(tile.occupant_id)
		if occ != null:
			var team = unit.team if unit != null else GameEnums.Team.PLAYER
			if occ.team != team:
				if unit != null and (unit.has_status(GameEnums.StatusType.GHOST) or has_trample(unit)):
					return true # Ghost/Trample can walk through enemies
				return false # Cannot walk through enemies
	return true

## Shared trample check — used by pathfinding, move execution, and UI.
static func has_trample(unit: UnitState) -> bool:
	if unit == null:
		return false
	return unit.has_status(GameEnums.StatusType.TRAMPLE) or unit.has_passive(&"trample_move")

## Whether a unit may end a basic move on this tile (ally-occupied tiles block).
static func can_end_movement_on(board: BoardState, coord: Vector2i, unit: UnitState) -> bool:
	if unit == null or not GridSystem.is_in_bounds(board, coord):
		return false
	if not GridSystem.is_passable(board, coord):
		return false
	if not GridSystem.is_occupied(board, coord):
		return true
	var occ := board.get_unit_at(coord)
	if occ == null:
		return true
	if occ.id == unit.id:
		return true
	if occ.team != unit.team and has_trample(unit):
		return true
	return false

static func execute_move(board: BoardState, action: TimelineAction, events: Array[SimEvent]) -> void:
	var unit := board.get_unit_by_id(action.actor_id)
	if unit == null or not unit.is_alive():
		events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
			"actor": action.actor_id, "reason": "no_actor",
		}))
		return
		
	if unit.has_status(GameEnums.StatusType.ROOT) or unit.has_status(GameEnums.StatusType.STUN):
		events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
			"actor": action.actor_id, "reason": "movement_prevented_by_status",
		}))
		return
		
	if action.move_timing == GameEnums.MoveTiming.PRE_ACTION and unit.has_used_turn_action():
		events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
			"actor": action.actor_id, "reason": "cannot_move_after_action",
		}))
		return
	if action.move_timing == GameEnums.MoveTiming.POST_ACTION and not unit.has_used_turn_action():
		events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
			"actor": action.actor_id, "reason": "cannot_move_before_action",
		}))
		return
	if action.move_timing == GameEnums.MoveTiming.POST_ACTION and unit.pre_move_used_this_turn:
		if not unit.has_passive(&"canto") and not unit.has_status(GameEnums.StatusType.CANTO):
			events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
				"actor": action.actor_id, "reason": "cannot_move_after_pre_move",
			}))
			return

	if action.uses_run:
		AbilitySystem.apply_run_boost(unit, events)

	var mt := unit.definition.movement_type if unit.definition != null else GameEnums.MovementType.WALK

	# Teleporters warp directly — no path walking, no MP cost.
	if mt == GameEnums.MovementType.TELEPORT:
		var dest := action.target_coord
		if not GridSystem.is_in_bounds(board, dest) or GridSystem.is_occupied(board, dest):
			events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
				"actor": unit.id, "reason": "teleport_blocked",
			}))
			return
		var from := unit.position
		var points_before: int = unit.movement.points_left
		GridSystem.set_occupant(board, unit.position, -1)
		unit.position = dest
		GridSystem.set_occupant(board, unit.position, unit.id)
		if action.face_dir >= 0:
			unit.facing = action.face_dir as GameEnums.Facing
		else:
			unit.facing = PhysicsSystem.facing_from_vector(
				PhysicsSystem.cardinal_from_to(from, dest))
		events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
			"actor": unit.id, "from": from, "to": unit.position,
			"steps": 1, "path": [dest], "teleport": true,
			"movement_points_before": points_before,
			"movement_points_left": unit.movement.points_left,
			"movement_cost_per_tile": 0,
			"move_timing": action.move_timing,
		}))
		if action.move_timing == GameEnums.MoveTiming.PRE_ACTION:
			unit.pre_move_used_this_turn = true
		TerrainSystem.apply_landing(board, unit, events)
		return

	var has_bleed = unit.has_status(GameEnums.StatusType.BLEED)
	var has_burn = unit.has_status(GameEnums.StatusType.BURN)
	var unit_has_trample := has_trample(unit)

	var move_cost = 1
	if has_bleed: move_cost = 2

	var path: Array[Vector2i] = action.waypoints if _is_legal_walk(board, unit.position, action.waypoints, unit.movement.points_left, move_cost) else find_path(board, unit.position, action.target_coord, unit.movement.points_left, mt, move_cost)
	if path.is_empty():
		events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
			"actor": unit.id, "reason": "no_path",
		}))
		return

	var from := unit.position
	var points_before: int = unit.movement.points_left
	GridSystem.set_occupant(board, unit.position, -1)
	var trample_hit_ids: Dictionary = {}
	
	if has_burn:
		var fire_terrain = DataLibrary.get_terrain(&"fire")
		if fire_terrain != null:
			board.set_tile_terrain(unit.position, fire_terrain)
			events.append(SimEvent.make(GameEnums.SimEventType.TERRAIN_CHANGED, {
				"coord": unit.position,
				"terrain": &"fire"
			}))
			
	for step_index in range(path.size()):
		var step: Vector2i = path[step_index]
		if has_burn and step != path[path.size()-1]:
			var fire_terrain = DataLibrary.get_terrain(&"fire")
			if fire_terrain != null:
				board.set_tile_terrain(step, fire_terrain)
				events.append(SimEvent.make(GameEnums.SimEventType.TERRAIN_CHANGED, {
					"coord": step,
					"terrain": &"fire"
				}))
				
		if unit_has_trample:
			var occ := board.get_unit_at(step)
			if occ != null and occ.team != unit.team and not trample_hit_ids.has(occ.id):
				trample_hit_ids[occ.id] = true
				var prev_pos := from if step_index == 0 else path[step_index - 1]
				var move_dir := PhysicsSystem.cardinal_from_to(prev_pos, step)
				var is_final_step := step_index == path.size() - 1
				var push_dir := move_dir if is_final_step else PhysicsSystem.left_of_direction(move_dir)
				PhysicsSystem.push(board, occ, push_dir, 1, events, unit)
				events.append(SimEvent.make(GameEnums.SimEventType.TRAMPLE_HIT, {
					"actor": unit.id,
					"target": occ.id,
					"coord": step,
				}))
				if unit.has_passive(&"trample_move") and unit.is_passive_upgraded(&"trample_move"):
					occ.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, -1))

		TerrainSystem.apply_entry_at(board, unit, step, events)

	unit.position = path[path.size() - 1]
	unit.movement.points_left -= (path.size() * move_cost)
	GridSystem.set_occupant(board, unit.position, unit.id)

	# Face the direction of the final step (used for flanking/backstab), unless the
	# action requested an explicit final facing (player set it via the drop region).
	if action.face_dir >= 0:
		unit.facing = action.face_dir as GameEnums.Facing
	else:
		var prev: Vector2i = path[path.size() - 2] if path.size() >= 2 else from
		unit.facing = PhysicsSystem.facing_from_vector(unit.position - prev)



	events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
		"actor": unit.id,
		"from": from,
		"to": unit.position,
		"steps": path.size(),
		"path": path,  # ordered tiles entered, so presentation animates orthogonally
		"movement_points_before": points_before,
		"movement_points_left": unit.movement.points_left,
		"movement_cost_per_tile": move_cost,
		"move_timing": action.move_timing,
	}))
	if action.move_timing == GameEnums.MoveTiming.PRE_ACTION:
		unit.pre_move_used_this_turn = true

## True when `route` is a contiguous, in-budget walk of cardinal steps onto passable
## tiles starting from `start`. Empty routes are not legal walks (use pathfinding).
static func _is_legal_walk(board: BoardState, start: Vector2i, route: Array[Vector2i], budget: int, move_cost: int = 1) -> bool:
	if route.is_empty() or route.size() * move_cost > budget:
		return false
		
	var unit := board.get_unit_at(start)
		
	var prev := start
	for step in route:
		if GridSystem.manhattan(prev, step) != 1 or not _is_walkable_for(board, step, unit):
			return false
		prev = step
		
	if GridSystem.is_occupied(board, route[route.size() - 1]):
		return false
		
	return true

## Turn a unit in place. Free (costs no movement points); purely changes facing.
static func execute_face(board: BoardState, action: TimelineAction, events: Array[SimEvent]) -> void:
	var unit := board.get_unit_by_id(action.actor_id)
	if unit == null or not unit.is_alive() or action.face_dir < 0:
		events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
			"actor": action.actor_id, "reason": "no_actor",
		}))
		return
	unit.facing = action.face_dir as GameEnums.Facing
	events.append(SimEvent.make(GameEnums.SimEventType.UNIT_FACED, {
		"unit": unit.id, "facing": unit.facing,
	}))
