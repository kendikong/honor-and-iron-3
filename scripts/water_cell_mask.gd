class_name WaterCellMask
extends RefCounted

## Classifies WATER cells — shore wang sprites mix grass pixels and must not use ground ripple.

const SOURCE_FOREST: int = TileSetFactory.SOURCE_FOREST

## terrain_connect open-water fill only — never wang shore/corner ids (132, 133, …).
const OPEN_WATER_CONNECT_IDS: Array[int] = [145, 146, 161, 162]

const _DEPTH_PAINT_OUTPUT_IDS: Array[int] = [180, 164, 196, 148, 212, 228]

const _CARDINALS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]


static func is_shore_water(grid: PlayerGrid, pos: Vector2i) -> bool:
	if grid.get_cell(pos) != TileId.Type.WATER:
		return false
	for offset: Vector2i in _CARDINALS:
		var neighbor: Vector2i = pos + offset
		if not in_bounds(grid, neighbor):
			return true
		if grid.get_cell(neighbor) != TileId.Type.WATER:
			return true
	return false


## Grid interior — all in-bounds cardinals are water (excludes map-edge shore).
static func is_interior_water(grid: PlayerGrid, pos: Vector2i) -> bool:
	if grid.get_cell(pos) != TileId.Type.WATER:
		return false
	return not is_shore_water(grid, pos)


## BFS ring from shore-water: 0 = shore, 1 = shallow interior, 2+ = deep.
static func build_depth_field(grid: PlayerGrid) -> Dictionary:
	var depths: Dictionary = {}
	if grid == null:
		return depths
	var queue: Array[Vector2i] = []
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			if grid.get_cell(pos) != TileId.Type.WATER:
				continue
			if is_shore_water(grid, pos):
				depths[pos] = 0
				queue.append(pos)
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		var next_depth: int = int(depths[cur]) + 1
		for offset: Vector2i in _CARDINALS:
			var neighbor: Vector2i = cur + offset
			if not in_bounds(grid, neighbor):
				continue
			if grid.get_cell(neighbor) != TileId.Type.WATER:
				continue
			if depths.has(neighbor):
				continue
			depths[neighbor] = next_depth
			queue.append(neighbor)
	return depths


static func depth_at(grid: PlayerGrid, pos: Vector2i, field: Dictionary = {}) -> int:
	if not field.is_empty() and field.has(pos):
		return int(field[pos])
	if grid.get_cell(pos) != TileId.Type.WATER:
		return -1
	if is_shore_water(grid, pos):
		return 0
	var built: Dictionary = build_depth_field(grid)
	return int(built.get(pos, 1))


static func is_deep_water(grid: PlayerGrid, pos: Vector2i, field: Dictionary = {}) -> bool:
	return depth_at(grid, pos, field) >= 2


static func is_shallow_interior(grid: PlayerGrid, pos: Vector2i, field: Dictionary = {}) -> bool:
	return depth_at(grid, pos, field) == 1


## Only terrain_connect open fill or prior depth-paint outputs may be overwritten.
static func may_apply_depth_paint(ground: TileMapLayer, pos: Vector2i) -> bool:
	if ground == null or ground.get_cell_source_id(pos) != SOURCE_FOREST:
		return false
	var atlas: Vector2i = ground.get_cell_atlas_coords(pos)
	var local_id: int = atlas.x + atlas.y * 16
	if local_id in _DEPTH_PAINT_OUTPUT_IDS:
		return true
	return local_id in OPEN_WATER_CONNECT_IDS


## Ground ripple weight: interior grid cells only; skip painted shoreline wang art.
static func ripple_weight(grid: PlayerGrid, ground: TileMapLayer, pos: Vector2i) -> float:
	if not is_interior_water(grid, pos):
		return 0.0
	if ground == null or ground.get_cell_source_id(pos) != SOURCE_FOREST:
		return 1.0
	var atlas: Vector2i = ground.get_cell_atlas_coords(pos)
	var local_id: int = atlas.x + atlas.y * 16
	var entry: Dictionary = TileCatalog.describe_forest_tile(local_id)
	var use_case: String = str(entry.get("use_case", ""))
	if use_case.contains("shoreline") or use_case.contains("edge"):
		return 0.0
	return 1.0


static func in_bounds(grid: PlayerGrid, pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < grid.width and pos.y < grid.height
