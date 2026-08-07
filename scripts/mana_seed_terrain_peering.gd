class_name ManaSeedTerrainPeering
extends RefCounted

## Applies Tiled corner-wang metadata to Godot TileData terrain + peering bits.

const _C = preload("res://scripts/mana_seed_constants.gd")

const TERRAIN_SET: int = _C.TERRAIN_SET
const TERRAIN_DIRT: int = _C.TERRAIN_DIRT
const TERRAIN_ELEVATION: int = _C.TERRAIN_ELEVATION
const TERRAIN_WATER: int = _C.TERRAIN_WATER

# Tiled corner wang order: TL, T, TR, L, R, BL, B, BR â†’ Godot 4.7 CellNeighbor.
const TILED_CORNER_TO_GODOT: Array[int] = [
	11, # CELL_NEIGHBOR_TOP_LEFT_CORNER
	12, # CELL_NEIGHBOR_TOP_SIDE
	15, # CELL_NEIGHBOR_TOP_RIGHT_CORNER
	8,  # CELL_NEIGHBOR_LEFT_SIDE
	0,  # CELL_NEIGHBOR_RIGHT_SIDE
	7,  # CELL_NEIGHBOR_BOTTOM_LEFT_CORNER
	4,  # CELL_NEIGHBOR_BOTTOM_SIDE
	3,  # CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER
]


static func configure_terrain_set(tile_set: TileSet, terrain_set: int = TERRAIN_SET) -> void:
	while tile_set.get_terrain_sets_count() <= terrain_set:
		tile_set.add_terrain_set()
	while tile_set.get_terrains_count(terrain_set) < 3:
		tile_set.add_terrain(terrain_set)
	tile_set.set_terrain_set_mode(terrain_set, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	tile_set.set_terrain_name(terrain_set, TERRAIN_DIRT, "dirt")
	tile_set.set_terrain_name(terrain_set, TERRAIN_ELEVATION, "elevation")
	tile_set.set_terrain_name(terrain_set, TERRAIN_WATER, "water")
	tile_set.set_terrain_color(terrain_set, TERRAIN_DIRT, Color(0.9, 0.2, 0.2))
	tile_set.set_terrain_color(terrain_set, TERRAIN_ELEVATION, Color(0.2, 0.9, 0.2))
	tile_set.set_terrain_color(terrain_set, TERRAIN_WATER, Color(0.2, 0.3, 0.9))


static func apply_wangset_to_source(
	source: TileSetAtlasSource,
	parsed: Dictionary,
	terrain_set: int = TERRAIN_SET,
) -> Dictionary:
	var columns: int = maxi(int(parsed.get("columns", 16)), 1)
	var stats: Dictionary = {
		"wang_tiles": 0,
		"dirt": 0,
		"elevation": 0,
		"water": 0,
	}
	var wangsets: Array = parsed.get("wangsets", [])
	for wangset_variant: Variant in wangsets:
		var wangset: Dictionary = wangset_variant
		var tiles: Array = wangset.get("tiles", [])
		for tile_variant: Variant in tiles:
			var tile: Dictionary = tile_variant
			var local_id: int = int(tile["tile_id"])
			var wangid: Array[int] = TsxTilesetParser._as_int_array(tile["wangid"])
			var coords: Vector2i = Vector2i(local_id % columns, int(local_id / columns))
			if not source.has_tile(coords):
				continue
			var tile_data: TileData = source.get_tile_data(coords, 0)
			var terrain: int = dominant_terrain_from_wangid(wangid)
			if terrain >= 0:
				tile_data.terrain_set = terrain_set
				tile_data.terrain = terrain
				match terrain:
					TERRAIN_DIRT:
						stats["dirt"] = int(stats["dirt"]) + 1
					TERRAIN_ELEVATION:
						stats["elevation"] = int(stats["elevation"]) + 1
					TERRAIN_WATER:
						stats["water"] = int(stats["water"]) + 1
			_apply_peering_bits(tile_data, wangid)
			stats["wang_tiles"] = int(stats["wang_tiles"]) + 1
	return stats


static func apply_peering_map_to_source(
	source: TileSetAtlasSource,
	peering_map: TerrainPeeringMap,
	columns: int = 16,
	terrain_set: int = TERRAIN_SET,
) -> int:
	if peering_map == null:
		return 0
	var applied: int = 0
	var canonical_by_pattern: Dictionary = {}
	for pattern_key: String in peering_map.pattern_to_tile.keys():
		var tile_id: int = int(peering_map.pattern_to_tile[pattern_key])
		var pattern: Dictionary = TerrainPeeringPatterns.get_pattern(pattern_key)
		if pattern.is_empty():
			continue
		var wang: Array[int] = peering_map.get_effective_wang(pattern_key)
		if wang.is_empty():
			wang = TsxTilesetParser._as_int_array(pattern["wang"])
		var coords: Vector2i = Vector2i(tile_id % columns, int(tile_id / columns))
		if not source.has_tile(coords):
			continue
		var tile_data: TileData = source.get_tile_data(coords, 0)
		tile_data.terrain_set = terrain_set
		tile_data.terrain = int(pattern["terrain"])
		_apply_peering_bits(tile_data, wang)
		canonical_by_pattern[pattern_key] = tile_id
		applied += 1
	if peering_map.suppress_variants:
		_suppress_wang_variants(source, canonical_by_pattern, columns, terrain_set)
	return applied


static func _suppress_wang_variants(
	source: TileSetAtlasSource,
	canonical_by_pattern: Dictionary,
	columns: int,
	terrain_set: int,
) -> void:
	for pattern: Dictionary in TerrainPeeringPatterns.all_patterns():
		var pattern_key: String = str(pattern["key"])
		var canonical: int = int(canonical_by_pattern.get(pattern_key, pattern["tsx_default"]))
		for candidate: Variant in pattern["candidates"]:
			var tile_id: int = int(candidate)
			if tile_id == canonical:
				continue
			var coords: Vector2i = Vector2i(tile_id % columns, int(tile_id / columns))
			if not source.has_tile(coords):
				continue
			var tile_data: TileData = source.get_tile_data(coords, 0)
			tile_data.terrain = -1
			_clear_peering_bits(tile_data)


static func _clear_peering_bits(tile_data: TileData) -> void:
	for peering: int in TILED_CORNER_TO_GODOT:
		if tile_data.is_valid_terrain_peering_bit(peering):
			tile_data.set_terrain_peering_bit(peering, -1)


static func wang_index_to_terrain(wang_index: int) -> int:
	match wang_index:
		1:
			return TERRAIN_DIRT
		2:
			return TERRAIN_ELEVATION
		3:
			return TERRAIN_WATER
		_:
			return -1


static func dominant_terrain_from_wangid(wangid: Array) -> int:
	var counts: Dictionary = {}
	for raw: Variant in wangid:
		var value: int = int(raw)
		if value <= 0:
			continue
		counts[value] = int(counts.get(value, 0)) + 1
	if counts.is_empty():
		return -1
	var best_index: int = 0
	var best_count: int = -1
	for value: int in counts.keys():
		var count: int = int(counts[value])
		if count > best_count:
			best_index = value
			best_count = count
	return wang_index_to_terrain(best_index)


static func _apply_peering_bits(tile_data: TileData, wangid: Array[int]) -> void:
	if wangid.size() != 8:
		return
	for i: int in range(8):
		var peering: int = TILED_CORNER_TO_GODOT[i]
		if not tile_data.is_valid_terrain_peering_bit(peering):
			continue
		tile_data.set_terrain_peering_bit(peering, wang_index_to_terrain(int(wangid[i])))
