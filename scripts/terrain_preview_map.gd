class_name TerrainPreviewMap
extends Node2D

## Live Godot terrain_connect preview — shows which atlas tile the engine actually picks.

const GRID_RADIUS: int = 3
const TILE_PX: int = 16
const SOURCE_FOREST: int = 0
const GRASS_FILL_ID: int = 97

var _layer: TileMapLayer


func _ready() -> void:
	_layer = TileMapLayer.new()
	_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_layer)


func run_preview(
	tile_set: TileSet,
	pattern: Dictionary,
	neighborhood: Array[int],
	expected_local_id: int,
) -> Dictionary:
	_layer.tile_set = tile_set
	_layer.clear()

	var center: Vector2i = Vector2i(GRID_RADIUS, GRID_RADIUS)
	var dirt_cells: Array[Vector2i] = []
	var water_cells: Array[Vector2i] = []
	var elevation_cells: Array[Vector2i] = []
	var grass_cells: Array[Vector2i] = []

	for y: int in range(GRID_RADIUS * 2 + 1):
		for x: int in range(GRID_RADIUS * 2 + 1):
			var pos: Vector2i = Vector2i(x, y)
			var rel: Vector2i = pos - center
			var grid_i: int = _offset_to_grid_index(rel)
			var terrain: int = TerrainPeeringBridge.TERRAIN_GRASS
			if grid_i >= 0 and grid_i < neighborhood.size():
				terrain = int(neighborhood[grid_i])
			match terrain:
				TerrainPeeringBridge.TERRAIN_DIRT:
					dirt_cells.append(pos)
				TerrainPeeringBridge.TERRAIN_WATER:
					water_cells.append(pos)
				TerrainPeeringBridge.TERRAIN_ELEVATION:
					elevation_cells.append(pos)
				_:
					grass_cells.append(pos)

	for pos: Vector2i in grass_cells:
		_paint_grass(pos)

	if not dirt_cells.is_empty():
		_layer.set_cells_terrain_connect(dirt_cells, 0, TerrainPeeringBridge.TERRAIN_DIRT, false)
	if not elevation_cells.is_empty():
		_layer.set_cells_terrain_connect(elevation_cells, 0, TerrainPeeringBridge.TERRAIN_ELEVATION, false)
	if not water_cells.is_empty():
		_layer.set_cells_terrain_connect(water_cells, 0, TerrainPeeringBridge.TERRAIN_WATER, false)

	var picked_id: int = _local_id_at(center)
	var region_ids: Array[int] = _region_ids(center)
	var match_expected: bool = picked_id == expected_local_id
	return {
		"picked_id": picked_id,
		"expected_id": expected_local_id,
		"match": match_expected,
		"pattern_label": str(pattern.get("label", "")),
		"region_ids": region_ids,
	}


func _paint_grass(pos: Vector2i) -> void:
	var atlas: Vector2i = Vector2i(GRASS_FILL_ID % 16, int(GRASS_FILL_ID / 16))
	_layer.set_cell(pos, SOURCE_FOREST, atlas, 0)


func _region_ids(center: Vector2i) -> Array[int]:
	var ids: Array[int] = []
	for grid_i: int in range(9):
		var pos: Vector2i = center + TerrainPeeringBridge.grid_offset(grid_i)
		ids.append(_local_id_at(pos))
	return ids


func _local_id_at(pos: Vector2i) -> int:
	if _layer.get_cell_source_id(pos) != SOURCE_FOREST:
		return -1
	var atlas: Vector2i = _layer.get_cell_atlas_coords(pos)
	return atlas.y * 16 + atlas.x


static func _offset_to_grid_index(rel: Vector2i) -> int:
	if rel == Vector2i(-1, -1):
		return 0
	if rel == Vector2i(0, -1):
		return 1
	if rel == Vector2i(1, -1):
		return 2
	if rel == Vector2i(-1, 0):
		return 3
	if rel == Vector2i.ZERO:
		return 4
	if rel == Vector2i(1, 0):
		return 5
	if rel == Vector2i(-1, 1):
		return 6
	if rel == Vector2i(0, 1):
		return 7
	if rel == Vector2i(1, 1):
		return 8
	return -1
