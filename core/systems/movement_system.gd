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
static func get_reachable_tiles(
	board: BoardState,
	start: Vector2i,
	max_steps: int,
	movement_type: GameEnums.MovementType = GameEnums.MovementType.WALK,
	move_cost: int = 1,
	ability: AbilityData = null,
) -> Array[Vector2i]:
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
			var step_cost: int = step_mp_cost(board, next, unit)
			var new_cost = cost_so_far[current] + step_cost
			if new_cost > max_steps:
				continue
			
			if cost_so_far.has(next) and cost_so_far[next] <= new_cost:
				continue
				
			if not _is_walkable_for(board, next, unit, ability):
				continue
				
			cost_so_far[next] = new_cost
			queue.append(next)
			
	return reachable

## Deterministic breadth-first shortest path from start to goal.
## Returns the list of tiles to ENTER (excluding start). Empty if unreachable or
## already there. Result is truncated to max_steps tiles.
static func find_path(
	board: BoardState,
	start: Vector2i,
	goal: Vector2i,
	max_steps: int,
	movement_type: GameEnums.MovementType = GameEnums.MovementType.WALK,
	move_cost: int = 1,
	ability: AbilityData = null,
) -> Array[Vector2i]:
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

	# Allow pathing to an enemy-occupied goal when the unit has pass-through (TRAMPLE/BULLDOZE)
	# or temporary GHOST from ghost_move during skill execution.
	var goal_tile_ok: bool = GridSystem.is_passable(board, goal)
	if not goal_tile_ok and unit != null:
		var goal_occ := board.get_unit_at(goal)
		if goal_occ != null and goal_occ.team != team:
			if (
				can_pass_through_enemy(unit, ability)
				or unit.has_status(GameEnums.StatusType.GHOST)
				or (ability != null and AbilitySystem.has_displacement_effects(ability))
			):
				goal_tile_ok = true
	if not goal_tile_ok:
		return empty

	var came_from: Dictionary = {}   # Vector2i -> Vector2i
	var cost_so_far: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == goal:
			break
		for dir in GridSystem.DIRECTIONS:
			var next: Vector2i = current + dir
			var step_cost: int = step_mp_cost(board, next, unit)
			var new_cost: int = int(cost_so_far[current]) + step_cost
			if new_cost > max_steps:
				continue
			if not _is_walkable_for(board, next, unit, ability):
				continue
			if cost_so_far.has(next) and int(cost_so_far[next]) <= new_cost:
				continue
			cost_so_far[next] = new_cost
			came_from[next] = current
			queue.append(next)

	if not came_from.has(goal):
		return empty

	var path: Array[Vector2i] = []
	var node: Vector2i = goal
	while node != start:
		path.push_front(node)
		node = came_from[node]

	var path_cost: int = 0
	var trimmed: Array[Vector2i] = []
	for step_coord: Vector2i in path:
		var step_cost_path: int = step_mp_cost(board, step_coord, unit)
		if path_cost + step_cost_path > max_steps:
			break
		path_cost += step_cost_path
		trimmed.append(step_coord)
	path = trimmed
		
	# A unit cannot end its movement on an occupied tile (e.g. an ally).
	# Backtrack until we find an empty tile — but allow ending on an enemy tile
	# if the ability grants pass-through movement (TRAMPLE/BULLDOZE pushes them aside).
	while path.size() > 0 and GridSystem.is_occupied(board, path[path.size() - 1]):
		var end_occ := board.get_unit_at(path[path.size() - 1])
		if end_occ != null and end_occ.team != team and (
			can_pass_through_enemy(unit, ability) or unit.has_status(GameEnums.StatusType.GHOST)
			or (ability != null and AbilitySystem.has_displacement_effects(ability))
		):
			break  # TRAMPLE/BULLDOZE/GHOST can land on an enemy tile; execution handles displacement
		path.pop_back()
		
	return path


## Drag-paint corridor: horizontal axis first, then vertical (matches player paint intent).
## Returns tiles to ENTER (excluding start). Falls back to BFS when corridor is blocked.
static func drag_corridor_path(
	board: BoardState,
	start: Vector2i,
	goal: Vector2i,
	max_steps: int,
	movement_type: GameEnums.MovementType = GameEnums.MovementType.WALK,
	move_cost: int = 1,
	unit: UnitState = null,
	ability: AbilityData = null,
) -> Array[Vector2i]:
	if start == goal:
		return []
	var corridor: Array[Vector2i] = []
	var cur: Vector2i = start
	var dx: int = goal.x - start.x
	var dy: int = goal.y - start.y
	if dx != 0:
		var step_x: int = 1 if dx > 0 else -1
		for _i: int in absi(dx):
			cur = Vector2i(cur.x + step_x, cur.y)
			corridor.append(cur)
	if dy != 0:
		var step_y: int = 1 if dy > 0 else -1
		for _i: int in absi(dy):
			cur = Vector2i(cur.x, cur.y + step_y)
			corridor.append(cur)
	if corridor.is_empty():
		return []
	var validated: Array[Vector2i] = []
	var prev: Vector2i = start
	for tile: Vector2i in corridor:
		if GridSystem.manhattan(prev, tile) != 1:
			break
		if not _is_walkable_for(board, tile, unit, ability):
			break
		validated.append(tile)
		prev = tile
	if validated.is_empty() or validated.back() != goal:
		return find_path(board, start, goal, max_steps, movement_type, move_cost, ability)
	validated = _trim_route_to_budget(board, validated, max_steps, unit)
	var team: GameEnums.Team = unit.team if unit != null else GameEnums.Team.PLAYER
	while validated.size() > 0 and GridSystem.is_occupied(board, validated[validated.size() - 1]):
		var end_occ: UnitState = board.get_unit_at(validated[validated.size() - 1])
		if end_occ != null and end_occ.team != team and can_pass_through_enemy(unit, ability):
			break
		validated.pop_back()
	return validated


static func move_cost_for(unit: UnitState) -> int:
	if unit != null and unit.has_status(GameEnums.StatusType.BLEED):
		return 2
	return 1


static func step_mp_cost(board: BoardState, coord: Vector2i, unit: UnitState) -> int:
	var unit_cost: int = move_cost_for(unit)
	var terrain_cost: int = 1
	var tile: TileState = board.get_tile(coord)
	if tile != null and tile.definition != null:
		terrain_cost = maxi(1, tile.definition.mp_cost_per_tile)
	return unit_cost * terrain_cost


static func route_mp_cost(board: BoardState, route: Array[Vector2i], unit: UnitState) -> int:
	var spent: int = 0
	for step_coord: Vector2i in route:
		spent += step_mp_cost(board, step_coord, unit)
	return spent


static func _trim_route_to_budget(
	board: BoardState,
	route: Array[Vector2i],
	budget: int,
	unit: UnitState,
) -> Array[Vector2i]:
	var trimmed: Array[Vector2i] = []
	var spent: int = 0
	for step_coord: Vector2i in route:
		var step_cost: int = step_mp_cost(board, step_coord, unit)
		if spent + step_cost > budget:
			break
		spent += step_cost
		trimmed.append(step_coord)
	return trimmed


static func resolve_move_path(
	board: BoardState,
	unit: UnitState,
	target_coord: Vector2i,
	waypoints: Array[Vector2i],
	max_steps: int,
	ability: AbilityData = null,
	start_coord: Vector2i = Vector2i(-1, -1),
) -> Array[Vector2i]:
	if unit == null:
		return []
	var start: Vector2i = start_coord if start_coord.x != -1 else unit.position
	var move_cost: int = move_cost_for(unit)
	var mt: GameEnums.MovementType = (
		unit.definition.movement_type
		if unit.definition != null
		else GameEnums.MovementType.WALK
	)
	if not waypoints.is_empty():
		if _is_legal_walk(board, start, waypoints, max_steps, move_cost, unit, ability):
			return waypoints.duplicate()
		## Committed waypoints are intent truth — never silently re-pathfind.
		if (
			_is_contiguous_cardinal_route(start, waypoints)
			and waypoints[waypoints.size() - 1] == target_coord
			and route_mp_cost(board, waypoints, unit) <= max_steps
		):
			return waypoints.duplicate()
		return []
	return find_path(board, start, target_coord, max_steps, mt, move_cost, ability)


static func can_reach_coord(
	board: BoardState,
	unit: UnitState,
	target_coord: Vector2i,
	waypoints: Array[Vector2i],
	max_steps: int,
) -> bool:
	var path: Array[Vector2i] = resolve_move_path(board, unit, target_coord, waypoints, max_steps)
	return not path.is_empty() and path[path.size() - 1] == target_coord


static func is_walkable_for(board: BoardState, coord: Vector2i, unit: UnitState, ability: AbilityData = null) -> bool:
	return _is_walkable_for(board, coord, unit, ability)


## True when the unit may path through an enemy-occupied tile.
static func can_pass_through_enemy(unit: UnitState, ability: AbilityData = null) -> bool:
	if has_trample(unit):
		return true
	if ability != null and AbilitySystem.has_pass_through_effects(ability):
		return true
	return false


static func _is_walkable_for(board: BoardState, coord: Vector2i, unit: UnitState, ability: AbilityData = null) -> bool:
	if not GridSystem.is_in_bounds(board, coord) or GridSystem.is_wall(board, coord):
		return false
	var tile := board.get_tile(coord)
	if tile != null and not tile.is_empty():
		var occ := board.get_unit_by_id(tile.occupant_id)
		if occ != null:
			var team = unit.team if unit != null else GameEnums.Team.PLAYER
			if occ.team != team:
				if unit != null and (unit.has_status(GameEnums.StatusType.GHOST) or can_pass_through_enemy(unit, ability)):
					return true # Ghost/Trample/BULLDOZE can walk through enemies
				return false # Cannot walk through enemies
			return false # Allied units block transit; only explicit pass-through may enter occupants
	return true

## Shared trample check — used by pathfinding, move execution, and UI.
static func has_trample(unit: UnitState) -> bool:
	if unit == null:
		return false
	return unit.has_status(GameEnums.StatusType.TRAMPLE)

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

## Walk the caster along a path when the ability has TRAMPLE/BULLDOZE or MOVE.
static func execute_skill_walk(
	board: BoardState,
	unit: UnitState,
	goal: Vector2i,
	waypoints: Array[Vector2i],
	ability: AbilityData,
	events: Array[SimEvent],
	effects: Array,
	walk_steps: int = -1,
) -> void:
	if unit == null or not unit.is_alive() or ability == null:
		return
	var mods: Dictionary = AbilitySystem.pass_through_modifiers_from(effects)
	var trample_atk: int = int(mods.get("trample_atk", 0))
	var bulldoze: int = int(mods.get("bulldoze", 0))
	var trample_push: int = int(mods.get("push", 0))
	var has_move := false
	for eff in effects:
		if eff.type == GameEnums.EffectType.MOVE:
			has_move = true
			break
	if trample_atk <= 0 and bulldoze <= 0 and not has_move:
		return
	var move_cost: int = move_cost_for(unit)
	var mt: GameEnums.MovementType = (
		unit.definition.movement_type
		if unit.definition != null
		else GameEnums.MovementType.WALK
	)
	if walk_steps < 0:
		walk_steps = ability.range_tiles
	var path: Array[Vector2i] = resolve_move_path(
		board, unit, goal, waypoints, walk_steps, ability
	)
	var from := unit.position
	GridSystem.set_occupant(board, unit.position, -1)
	var trample_hit_ids: Dictionary = {}
	var trampled_restore: Dictionary = {}
	var ability_id: StringName = ability.id
	for step_index in range(path.size()):
		var step: Vector2i = path[step_index]
		var prev_pos: Vector2i = from if step_index == 0 else path[step_index - 1]
		var move_dir: Vector2i = PhysicsSystem.cardinal_from_to(prev_pos, step)
		var is_final_step: bool = step_index == path.size() - 1
		var exit_dir: Vector2i = move_dir
		if not is_final_step:
			exit_dir = PhysicsSystem.cardinal_from_to(step, path[step_index + 1])
		var pre_trample_ev_count: int = events.size()
		if not PhysicsSystem.resolve_pass_through_tile(
			board, unit, step, move_dir, exit_dir, is_final_step,
			trample_atk, bulldoze, trample_push, events, ability_id,
			trample_hit_ids, trampled_restore, ability.display_name
		):
			# Tag any partial events that were emitted before the block
			for tag_i in range(pre_trample_ev_count, events.size()):
				events[tag_i].data["trample_step"] = step_index
			unit.position = from if step_index == 0 else path[step_index - 1]
			if not is_final_step:
				GridSystem.set_occupant(board, unit.position, unit.id)
				events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
					"actor": unit.id, "reason": "pass_through_blocked",
				}))
				return
			path = path.slice(0, step_index)
			break
		# Tag any trample side-effect events with the step they occurred on
		for tag_i in range(pre_trample_ev_count, events.size()):
			events[tag_i].data["trample_step"] = step_index
		if trampled_restore.has(unit.position):
			var restore_id: int = int(trampled_restore[unit.position])
			trampled_restore.erase(unit.position)
			GridSystem.set_occupant(board, unit.position, restore_id)
		unit.position = step
		
		var tile = board.get_tile(step)
		if tile != null and tile.definition != null and tile.definition.id != &"plain":
			unit.passive_flags["passed_through_terrain"] = true
			
		TerrainSystem.apply_entry_at(board, unit, step, events)
	# Rubber-band backwards if we halted on a trampled tile.
	while trampled_restore.has(unit.position):
		if path.size() > 0:
			path.pop_back()
			unit.position = from if path.is_empty() else path[path.size() - 1]
		else:
			break
	for restore_coord: Vector2i in trampled_restore.keys():
		var restore_unit_id: int = int(trampled_restore[restore_coord])
		if board.get_unit_at(restore_coord) == null:
			GridSystem.set_occupant(board, restore_coord, restore_unit_id)
	GridSystem.set_occupant(board, unit.position, unit.id)
	if path.size() >= 1:
		var prev_pos: Vector2i = from if path.size() == 1 else path[path.size() - 2]
		unit.facing = PhysicsSystem.facing_from_vector(unit.position - prev_pos)
	events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
		"actor": unit.id,
		"from": from,
		"to": unit.position,
		"steps": path.size(),
		"path": path,
		"is_pass_through_walk": true,
		"ability_id": ability_id,
		"presentation_anim": ability.presentation_anim,
	}))
	TerrainSystem.apply_landing(board, unit, events)


static func execute_move(board: BoardState, action: TimelineAction, events: Array[SimEvent]) -> void:
	var unit := board.get_unit_by_id(action.actor_id)
	if unit == null or not unit.is_alive():
		events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
			"actor": action.actor_id, "reason": "no_actor",
		}))
		return
		
	if unit.has_status(GameEnums.StatusType.ROOT) or unit.has_status(GameEnums.StatusType.STAGGER):
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
		if not AbilitySystem.spend_run_for_move(unit, events):
			events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
				"actor": action.actor_id, "reason": "cannot_use_ability",
			}))
			return

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

	var path: Array[Vector2i] = action.waypoints.duplicate() if not action.waypoints.is_empty() else find_path(board, unit.position, action.target_coord, unit.movement.points_left, mt, move_cost, action.ability)
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
				var pre_trample_ev_count: int = events.size()
				PhysicsSystem.push(board, occ, push_dir, 1, events, unit)
				events.append(SimEvent.make(GameEnums.SimEventType.TRAMPLE_HIT, {
					"actor": unit.id,
					"target": occ.id,
					"coord": step,
					"trample_step": step_index,
				}))
				# Tag push/damage events emitted by the push with this step index
				for tag_i in range(pre_trample_ev_count, events.size() - 1):
					events[tag_i].data["trample_step"] = step_index

		TerrainSystem.apply_entry_at(board, unit, step, events)

	unit.position = path[path.size() - 1]
	var mp_spent: int = 0
	for step_coord: Vector2i in path:
		mp_spent += step_mp_cost(board, step_coord, unit)
	unit.movement.points_left -= mp_spent
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

static func _is_contiguous_cardinal_route(start: Vector2i, route: Array[Vector2i]) -> bool:
	if route.is_empty():
		return false
	var prev: Vector2i = start
	for step: Vector2i in route:
		if GridSystem.manhattan(prev, step) != 1:
			return false
		prev = step
	return true


## True when `route` is a contiguous, in-budget walk of cardinal steps onto passable
## tiles starting from `start`. Empty routes are not legal walks (use pathfinding).
static func _is_legal_walk(
	board: BoardState,
	start: Vector2i,
	route: Array[Vector2i],
	budget: int,
	move_cost: int = 1,
	unit: UnitState = null,
	ability: AbilityData = null,
) -> bool:
	if route.is_empty():
		return false
	if unit == null:
		unit = board.get_unit_at(start)
	var spent: int = 0
	for step: Vector2i in route:
		spent += step_mp_cost(board, step, unit)
	if spent > budget:
		return false
		
	var prev := start
	for step in route:
		if GridSystem.manhattan(prev, step) != 1 or not _is_walkable_for(board, step, unit, ability):
			return false
		prev = step
		
	var end_tile: Vector2i = route[route.size() - 1]
	if GridSystem.is_occupied(board, end_tile):
		if ability != null and AbilitySystem.effect_amount(ability, GameEnums.EffectType.TRAMPLE) > 0:
			var end_occ := board.get_unit_at(end_tile)
			if end_occ != null and end_occ.id != unit.id:
				return false
		elif not can_pass_through_enemy(unit, ability):
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
