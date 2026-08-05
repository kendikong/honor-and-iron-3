class_name PlayerGrid
extends RefCounted

## Logical terrain grid. Flat Array[int] â€” Godot 4.7 does not support Array[Array[int]].

var width: int
var height: int
var _cells: Array[int] = []

## South-edge phantom grass rings below y = height-1 (tree overhang + peering).
const BOTTOM_PHANTOM_GRASS_DEPTH: int = 3


func _init(grid_width: int, grid_height: int, fill: int = TileId.Type.GRASS) -> void:
	width = grid_width
	height = grid_height
	_cells.clear()
	_cells.resize(grid_width * grid_height)
	_cells.fill(fill)


func get_cell(pos: Vector2i) -> int:
	return _cells[_index(pos)]


func set_cell(pos: Vector2i, tile_id: int) -> void:
	_cells[_index(pos)] = tile_id


func duplicate_grid() -> PlayerGrid:
	var copy: PlayerGrid = PlayerGrid.new(width, height)
	for i: int in range(_cells.size()):
		copy._cells[i] = _cells[i]
	return copy


func to_export_dict(seed: int = -1, include_walkable: bool = true) -> Dictionary:
	var tile_ids: Array[int] = []
	tile_ids.assign(_cells)
	var payload: Dictionary = {
		"version": 1,
		"width": width,
		"height": height,
		"seed": seed,
		"tile_enum": TileId.Type.keys(),
		"tile_ids": tile_ids,
	}
	if include_walkable:
		var walkable: Array[bool] = []
		walkable.resize(_cells.size())
		for i: int in range(_cells.size()):
			walkable[i] = Walkability.is_walkable_tile(_cells[i])
		payload["walkable"] = walkable
	return payload


func to_export_json(seed: int = -1, pretty: bool = true) -> String:
	var data: Dictionary = to_export_dict(seed)
	if pretty:
		return JSON.stringify(data, "\t")
	return JSON.stringify(data)


static func from_export_dict(data: Dictionary) -> PlayerGrid:
	var w: int = int(data.get("width", 0))
	var h: int = int(data.get("height", 0))
	var raw: Variant = data.get("tile_ids", [])
	if w < 1 or h < 1 or typeof(raw) != TYPE_ARRAY:
		push_error("PlayerGrid.from_export_dict: invalid export payload")
		return PlayerGrid.new(1, 1)
	var grid: PlayerGrid = PlayerGrid.new(w, h)
	var expected: int = w * h
	if raw.size() != expected:
		push_warning(
			"PlayerGrid.from_export_dict: tile_ids size %d != %d" % [raw.size(), expected]
		)
	for i: int in range(mini(expected, raw.size())):
		grid._cells[i] = int(raw[i])
	return grid


func save_export(path: String, seed: int = -1) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(to_export_json(seed))
	file.close()
	return OK


static func create_hardcoded_test_16() -> PlayerGrid:
	var grid: PlayerGrid = PlayerGrid.new(16, 16, TileId.Type.GRASS)
	for y: int in range(10, 16):
		for x: int in range(10, 16):
			grid.set_cell(Vector2i(x, y), TileId.Type.WATER)
	for x: int in range(2, 14):
		grid.set_cell(Vector2i(x, 8), TileId.Type.DIRT)
	grid.set_cell(Vector2i(5, 5), TileId.Type.TREE)
	grid.set_cell(Vector2i(12, 4), TileId.Type.RUIN)
	grid.set_cell(Vector2i(3, 12), TileId.Type.ROCK)
	return grid


func _index(pos: Vector2i) -> int:
	return pos.y * width + pos.x


static func tile_extends_grass_phantom(tile_id: int) -> bool:
	match tile_id:
		TileId.Type.GRASS, TileId.Type.TREE, TileId.Type.ROCK, TileId.Type.RUIN:
			return true
		_:
			return false


## Rows below map bottom: height â†’ 1 â€¦ height+2 â†’ 3. Else -1.
static func bottom_phantom_depth(grid: PlayerGrid, oob: Vector2i) -> int:
	if oob.x < 0 or oob.x >= grid.width or oob.y < grid.height:
		return -1
	return oob.y - grid.height + 1


static func bottom_phantom_owner(grid: PlayerGrid, oob: Vector2i) -> Vector2i:
	var depth: int = bottom_phantom_depth(grid, oob)
	if depth < 1 or depth > BOTTOM_PHANTOM_GRASS_DEPTH:
		return Vector2i(-1, -1)
	return Vector2i(oob.x, grid.height - 1)
