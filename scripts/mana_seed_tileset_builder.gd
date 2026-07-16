class_name ManaSeedTilesetBuilder
extends RefCounted

## Builds Godot TileSet resources from Mana Seed .tsx + PNG assets.

const _C = preload("res://scripts/mana_seed_constants.gd")
const _PEERING_MAP_PATH: String = TerrainPeeringMap.DEFAULT_PATH


static func build_forest_tileset_from_tsx(tsx_path: String = "") -> Dictionary:
	if tsx_path.is_empty():
		tsx_path = _C.FOREST_TSX
	var parsed: Dictionary = TsxTilesetParser.parse_file(tsx_path)
	if parsed.is_empty():
		return {"tile_set": null, "parsed": {}, "stats": {}}

	var tile_set: TileSet = TileSet.new()
	ManaSeedTerrainPeering.configure_terrain_set(tile_set)
	var source: TileSetAtlasSource = _build_atlas_source_from_parsed(parsed)
	if source == null:
		return {"tile_set": null, "parsed": parsed, "stats": {}}
	tile_set.add_source(source, 0)
	var stats: Dictionary = ManaSeedTerrainPeering.apply_wangset_to_source(source, parsed)
	_apply_forest_peering_map(source, parsed)
	return {"tile_set": tile_set, "parsed": parsed, "stats": stats}


static func build_combined_tileset(variant: int = 1) -> TileSet:
	var tile_set: TileSet = TileSet.new()
	ManaSeedTerrainPeering.configure_terrain_set(tile_set)
	_add_forest_source(tile_set, variant)
	_add_waterfall_source(tile_set, variant)
	_add_trees_source(tile_set, variant)
	_add_sparkles_source(tile_set, variant)
	_add_props_source(tile_set, variant)
	return tile_set


static func _add_forest_source(tile_set: TileSet, variant: int = 1) -> void:
	var parsed: Dictionary = TsxTilesetParser.parse_file(_C.tsx_path("gentle forest", variant))
	var source: TileSetAtlasSource = _build_atlas_source_from_parsed(parsed)
	if source == null:
		push_error("ManaSeedTilesetBuilder: forest atlas failed")
		return
	tile_set.add_source(source, _C.SOURCE_FOREST)
	ManaSeedTerrainPeering.apply_wangset_to_source(source, parsed)
	_apply_forest_peering_map(source, parsed)


static func _apply_forest_peering_map(source: TileSetAtlasSource, parsed: Dictionary) -> void:
	if not ResourceLoader.exists(_PEERING_MAP_PATH):
		return
	var peering_map: TerrainPeeringMap = load(_PEERING_MAP_PATH)
	if peering_map == null:
		return
	var columns: int = maxi(int(parsed.get("columns", 16)), 1)
	ManaSeedTerrainPeering.apply_peering_map_to_source(source, peering_map, columns)


static func _build_atlas_source_from_parsed(parsed: Dictionary) -> TileSetAtlasSource:
	var image_path: String = str(parsed.get("image_res_path", ""))
	if image_path.is_empty():
		push_error("ManaSeedTilesetBuilder: missing image path in parsed tsx")
		return null
	var texture: Texture2D = load(image_path)
	if texture == null:
		push_error("ManaSeedTilesetBuilder: could not load texture %s" % image_path)
		return null

	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(
		int(parsed.get("tile_width", 16)),
		int(parsed.get("tile_height", 16)),
	)
	var columns: int = maxi(int(parsed.get("columns", 16)), 1)
	var tile_count: int = int(parsed.get("tile_count", columns))
	var rows: int = int(ceil(float(tile_count) / float(columns)))
	var skip_ids: Dictionary = _animation_follower_ids(parsed)
	for y: int in range(rows):
		for x: int in range(columns):
			var local_id: int = y * columns + x
			if local_id >= tile_count:
				break
			if skip_ids.has(local_id):
				continue
			source.create_tile(Vector2i(x, y))
	return source


static func _animation_follower_ids(parsed: Dictionary) -> Dictionary:
	var skip: Dictionary = {}
	var animations: Dictionary = parsed.get("tile_animations", {})
	for tile_id: Variant in animations.keys():
		var frames: Array = (animations[tile_id] as Dictionary).get("frames", [])
		for i: int in range(1, frames.size()):
			var frame_id: int = int((frames[i] as Dictionary).get("tile_id", int(tile_id) + i))
			skip[frame_id] = true
	return skip


static func build_animated_atlas_from_tsx(tsx_path: String) -> TileSetAtlasSource:
	var parsed: Dictionary = TsxTilesetParser.parse_file(tsx_path)
	if parsed.is_empty():
		return null
	var source: TileSetAtlasSource = _build_atlas_source_from_parsed(parsed)
	if source == null:
		return null
	_apply_tsx_animations(source, parsed)
	return source


static func _add_sparkles_source(tile_set: TileSet, variant: int = 1) -> void:
	var tsx_path: String = _C.tsx_path("gentle water sparkles A", variant)
	var source: TileSetAtlasSource = build_animated_atlas_from_tsx(tsx_path)
	if source == null:
		return
	tile_set.add_source(source, _C.SOURCE_SPARKLES)


static func _add_waterfall_source(tile_set: TileSet, variant: int = 1) -> void:
	var tsx_path: String = _C.tsx_path("gentle waterfall A", variant)
	var source: TileSetAtlasSource = build_animated_atlas_from_tsx(tsx_path)
	if source == null:
		return
	tile_set.add_source(source, _C.SOURCE_WATERFALL)


static func _add_trees_source(tile_set: TileSet, variant: int = 1) -> void:
	var parsed: Dictionary = TsxTilesetParser.parse_file(_C.tsx_path("gentle trees 80x96", variant))
	var source: TileSetAtlasSource = _build_atlas_source_from_parsed(parsed)
	if source == null:
		return
	tile_set.add_source(source, _C.SOURCE_TREES)
	_set_y_sort_origin_for_all_tiles(source)


static func _add_props_source(tile_set: TileSet, variant: int = 1) -> void:
	var parsed: Dictionary = TsxTilesetParser.parse_file(_C.tsx_path("gentle 32x32", variant))
	var source: TileSetAtlasSource = _build_atlas_source_from_parsed(parsed)
	if source == null:
		return
	tile_set.add_source(source, _C.SOURCE_PROPS_32)
	_set_y_sort_origin_for_all_tiles(source)


static func _set_y_sort_origin_for_all_tiles(source: TileSetAtlasSource) -> void:
	var half_y: int = int(source.texture_region_size.y) / 2
	var sort_y: int = half_y
	if source.texture_region_size.y == 96:
		# Tree base is 2 tiles (32px) below the center anchor
		sort_y = 32
	for i: int in range(source.get_tiles_count()):
		var coords: Vector2i = source.get_tile_id(i)
		var tile_data: TileData = source.get_tile_data(coords, 0)
		if tile_data != null:
			tile_data.y_sort_origin = sort_y


static func _apply_tsx_animations(source: TileSetAtlasSource, parsed: Dictionary) -> void:
	var columns: int = maxi(int(parsed.get("columns", 1)), 1)
	var animations: Dictionary = parsed.get("tile_animations", {})
	var follower_ids: Dictionary = _animation_follower_ids(parsed)
	var anchor_ids: Array[int] = []
	for tile_id: Variant in animations.keys():
		var id: int = int(tile_id)
		if follower_ids.has(id):
			continue
		anchor_ids.append(id)
	anchor_ids.sort()
	for tile_id: int in anchor_ids:
		var entry: Dictionary = animations[tile_id] as Dictionary
		var frames: Array = entry.get("frames", [])
		if frames.is_empty():
			continue
		if not _tsx_frames_are_horizontal(frames, tile_id, columns):
			push_warning(
				"ManaSeedTilesetBuilder: skip non-horizontal animation for tile %d" % tile_id,
			)
			continue
		var anchor: Vector2i = Vector2i(tile_id % columns, int(tile_id / columns))
		if not source.has_tile(anchor):
			continue
		var frame_count: int = frames.size()
		if _animation_is_configured(source, anchor, frame_count):
			continue
		# TSX frames are consecutive atlas cells on one row — no separation gap.
		source.set_tile_animation_columns(anchor, frame_count)
		source.set_tile_animation_frames_count(anchor, frame_count)
		source.set_tile_animation_separation(anchor, Vector2i.ZERO)
		source.set_tile_animation_speed(anchor, 1.0)
		source.set_tile_animation_mode(
			anchor,
			TileSetAtlasSource.TILE_ANIMATION_MODE_RANDOM_START_TIMES,
		)
		for i: int in range(frame_count):
			var duration_sec: float = float((frames[i] as Dictionary).get("duration_ms", 200)) / 1000.0
			source.set_tile_animation_frame_duration(anchor, i, duration_sec)


static func _animation_is_configured(
	source: TileSetAtlasSource,
	anchor: Vector2i,
	frame_count: int,
) -> bool:
	if source.get_tile_animation_frames_count(anchor) != frame_count:
		return false
	if source.get_tile_animation_columns(anchor) != frame_count:
		return false
	if source.get_tile_animation_separation(anchor) != Vector2i.ZERO:
		return false
	for i: int in range(frame_count):
		if source.get_tile_animation_frame_duration(anchor, i) <= 0.0:
			return false
	return true


static func _tsx_frames_are_horizontal(frames: Array, tile_id: int, columns: int) -> bool:
	for i: int in range(frames.size()):
		var frame_id: int = int((frames[i] as Dictionary).get("tile_id", -1))
		if frame_id != tile_id + i:
			return false
		var expected: Vector2i = Vector2i((tile_id + i) % columns, int((tile_id + i) / columns))
		var anchor_y: int = int(tile_id / columns)
		if expected.y != anchor_y:
			return false
	return true
