class_name SampleMapLoader
extends RefCounted

## Paints Tiled sample GIDs onto TileMapLayer nodes (Phase 0 reference render).


static func load_sample_map(
	ground: TileMapLayer,
	overlay: TileMapLayer,
	vfx: TileMapLayer,
	tile_set: TileSet,
) -> void:
	ground.tile_set = tile_set
	overlay.tile_set = tile_set
	vfx.tile_set = tile_set
	ground.clear()
	overlay.clear()
	vfx.clear()
	_paint_layer(ground, overlay, vfx, SampleMapData.GROUND_LAYER)
	_paint_layer(ground, overlay, vfx, SampleMapData.OVERLAY_LAYER)


static func _paint_layer(
	ground: TileMapLayer,
	overlay: TileMapLayer,
	vfx: TileMapLayer,
	gids: Array[int],
) -> void:
	for index: int in gids.size():
		var gid: int = gids[index]
		if gid == 0:
			continue
		var x: int = index % SampleMapData.WIDTH
		var y: int = index / SampleMapData.WIDTH
		var cell: Dictionary = TileSetFactory.global_id_to_cell(gid)
		if cell.is_empty():
			push_warning("Unmapped GID: %d at (%d, %d)" % [gid, x, y])
			continue
		var target: TileMapLayer = _layer_node(ground, overlay, vfx, cell["source_id"])
		target.set_cell(
			Vector2i(x, y),
			cell["source_id"],
			cell["atlas_coords"],
			cell["alternative_tile"],
		)


static func _layer_node(
	ground: TileMapLayer,
	overlay: TileMapLayer,
	vfx: TileMapLayer,
	source_id: int,
) -> TileMapLayer:
	match TileSetFactory.layer_for_source(source_id):
		&"overlay":
			return overlay
		&"vfx":
			return vfx
		_:
			return ground
