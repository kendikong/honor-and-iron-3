class_name GridSystem
extends RefCounted

## Purpose: Owns grid queries and occupancy (and nothing else).
## Responsibilities: Bounds/wall/occupancy checks, distance, neighbor directions,
##   and the single helper that mutates tile occupancy.
## Dependencies: BoardState, TileState.
## Lifecycle: stateless; only static functions. Never instantiated.

## Fixed cardinal order (N, E, S, W). Used by pathfinding so results never vary.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

## Cardinal + diagonal directions for straight-line dashes and range display.
const ALL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(1, -1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
]

static func is_in_bounds(board: BoardState, coord: Vector2i) -> bool:
	return board.is_in_bounds(coord)

static func is_wall(board: BoardState, coord: Vector2i) -> bool:
	var tile := board.get_tile(coord)
	if tile == null:
		return true
	return tile.definition != null and tile.definition.blocks_movement

static func stops_displacement(board: BoardState, coord: Vector2i) -> bool:
	if not is_in_bounds(board, coord):
		return true
	var tile := board.get_tile(coord)
	if tile == null:
		return true
	return tile.definition != null and tile.definition.stops_displacement

static func is_occupied(board: BoardState, coord: Vector2i) -> bool:
	var tile := board.get_tile(coord)
	return tile != null and not tile.is_empty()

## True if entering this tile harms the unit (pit, spikes, ...).
static func is_hazard(board: BoardState, coord: Vector2i) -> bool:
	var tile := board.get_tile(coord)
	return tile != null and tile.definition != null and tile.definition.hazard_damage > 0

## A tile a unit may walk onto: in bounds, not a wall, and empty.
static func is_passable(board: BoardState, coord: Vector2i) -> bool:
	return is_in_bounds(board, coord) and not is_wall(board, coord) and not is_occupied(board, coord)

static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

## The single place tile occupancy changes. id of -1 clears the tile.
static func set_occupant(board: BoardState, coord: Vector2i, unit_id: int) -> void:
	var tile := board.get_tile(coord)
	if tile != null:
		tile.occupant_id = unit_id

## Resolves geometric targeting shapes based on origin, target, shape, and size.
static func get_affected_tiles(board: BoardState, origin: Vector2i, target: Vector2i, shape: GameEnums.TargetShape, size: int) -> Array[Vector2i]:
	match shape:
		GameEnums.TargetShape.SINGLE:
			return [target]
		GameEnums.TargetShape.AOE_SQUARE:
			var tiles: Array[Vector2i] = []
			var radius = size
			for x in range(-radius, radius + 1):
				for y in range(-radius, radius + 1):
					tiles.append(target + Vector2i(x, y))
			return tiles
		GameEnums.TargetShape.AOE_DIAMOND:
			var tiles: Array[Vector2i] = []
			for x in range(-size, size + 1):
				for y in range(-size, size + 1):
					if absi(x) + absi(y) <= size:
						tiles.append(target + Vector2i(x, y))
			return tiles
		GameEnums.TargetShape.AOE_CROSS:
			var tiles: Array[Vector2i] = [target]
			for dir in DIRECTIONS:
				for i in range(1, size + 1):
					tiles.append(target + dir * i)
			return tiles
		GameEnums.TargetShape.ARC:
			# 3-tile sweep perpendicular to attack direction, centered on target
			var tiles: Array[Vector2i] = [target]
			var dir = PhysicsSystem.cardinal_from_to(origin, target)
			if dir != Vector2i.ZERO:
				var perp1 = Vector2i(-dir.y, dir.x)
				var perp2 = Vector2i(dir.y, -dir.x)
				tiles.append(target + perp1)
				tiles.append(target + perp2)
			return tiles
		GameEnums.TargetShape.CONE:
			var tiles: Array[Vector2i] = []
			var dir = PhysicsSystem.cardinal_from_to(origin, target)
			if dir != Vector2i.ZERO:
				var perp1 = Vector2i(-dir.y, dir.x)
				var perp2 = Vector2i(dir.y, -dir.x)
				for distance in range(1, size + 1):
					var center = origin + dir * distance
					tiles.append(center)
					# Width expands with distance
					for w in range(1, distance + 1):
						tiles.append(center + perp1 * w)
						tiles.append(center + perp2 * w)
			return tiles
		GameEnums.TargetShape.LINE:
			var tiles: Array[Vector2i] = []
			var dir = PhysicsSystem.cardinal_from_to(origin, target)
			if dir != Vector2i.ZERO:
				for i in range(1, size + 1):
					tiles.append(origin + dir * i)
			return tiles
	
	return [target]
