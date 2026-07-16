class_name TileSetFactory
extends RefCounted

## Builds combined TileSet from verified Mana Seed v01 assets (Phase 0).

const _C = preload("res://scripts/mana_seed_constants.gd")

const SOURCE_FOREST: int = _C.SOURCE_FOREST
const SOURCE_WATERFALL: int = _C.SOURCE_WATERFALL
const SOURCE_TREES: int = _C.SOURCE_TREES
const SOURCE_SPARKLES: int = _C.SOURCE_SPARKLES
const SOURCE_PROPS_32: int = _C.SOURCE_PROPS_32

const TERRAIN_SET: int = _C.TERRAIN_SET
const TERRAIN_DIRT: int = _C.TERRAIN_DIRT
const TERRAIN_ELEVATION: int = _C.TERRAIN_ELEVATION
const TERRAIN_WATER: int = _C.TERRAIN_WATER

const GID_FOREST_START: int = _C.GID_FOREST_START
const GID_WATERFALL_START: int = _C.GID_WATERFALL_START
const GID_TREES_START: int = _C.GID_TREES_START
const GID_SPARKLES_START: int = _C.GID_SPARKLES_START
const GID_PROPS_START: int = _C.GID_PROPS_START


static func build_combined_tileset(variant: int = 1) -> TileSet:
	var v: int = clampi(variant, _C.MIN_TILESET_VARIANT, _C.MAX_TILESET_VARIANT)
	var baked_path: String = _C.baked_combined_path(v)
	var tile_set: TileSet = null
	if ResourceLoader.exists(baked_path):
		var baked: TileSet = load(baked_path)
		if baked != null:
			tile_set = baked
	if tile_set == null:
		tile_set = ManaSeedTilesetBuilder.build_combined_tileset(v)
	_apply_forest_peering_map(tile_set)
	# Baked .tres ships static atlases — always rebuild animated sources from .tsx.
	_replace_animated_source(
		tile_set,
		SOURCE_SPARKLES,
		_C.tsx_path("gentle water sparkles A", v),
	)
	_replace_animated_source(
		tile_set,
		SOURCE_WATERFALL,
		_C.tsx_path("gentle waterfall A", v),
	)
	return tile_set


static func _replace_animated_source(tile_set: TileSet, source_id: int, tsx_path: String) -> void:
	if tile_set == null:
		return
	var fresh: TileSetAtlasSource = ManaSeedTilesetBuilder.build_animated_atlas_from_tsx(tsx_path)
	if fresh == null:
		push_error("TileSetFactory: failed to build animated source %s" % tsx_path)
		return
	if tile_set.has_source(source_id):
		tile_set.remove_source(source_id)
	tile_set.add_source(fresh, source_id)


static func _apply_forest_peering_map(tile_set: TileSet) -> void:
	if not ResourceLoader.exists(TerrainPeeringMap.DEFAULT_PATH):
		return
	var peering_map: TerrainPeeringMap = load(TerrainPeeringMap.DEFAULT_PATH)
	if peering_map == null:
		return
	var source: TileSetSource = tile_set.get_source(SOURCE_FOREST)
	if source is TileSetAtlasSource:
		ManaSeedTerrainPeering.apply_peering_map_to_source(source, peering_map, 16)


static func global_id_to_cell(gid: int) -> Dictionary:
	if gid <= 0:
		return {}
	var decoded: Dictionary = TiledGid.decode(gid)
	var global_id: int = decoded["id"]
	var source_id: int = -1
	var local_id: int = -1
	if global_id >= GID_PROPS_START:
		source_id = SOURCE_PROPS_32
		local_id = global_id - GID_PROPS_START
	elif global_id >= GID_SPARKLES_START:
		source_id = SOURCE_SPARKLES
		local_id = global_id - GID_SPARKLES_START
	elif global_id >= GID_TREES_START:
		source_id = SOURCE_TREES
		local_id = global_id - GID_TREES_START
	elif global_id >= GID_WATERFALL_START:
		source_id = SOURCE_WATERFALL
		local_id = global_id - GID_WATERFALL_START
	elif global_id >= GID_FOREST_START:
		source_id = SOURCE_FOREST
		local_id = global_id - GID_FOREST_START
	else:
		return {}
	return {
		"source_id": source_id,
		"atlas_coords": local_id_to_atlas(source_id, local_id),
		"alternative_tile": TiledGid.alternative_from_flips(decoded),
	}


static func layer_for_source(source_id: int) -> StringName:
	match source_id:
		SOURCE_FOREST, SOURCE_WATERFALL:
			return &"ground"
		SOURCE_TREES, SOURCE_PROPS_32:
			return &"overlay"
		SOURCE_SPARKLES:
			return &"vfx"
		_:
			return &"ground"


static func local_id_to_atlas(source_id: int, local_id: int) -> Vector2i:
	match source_id:
		SOURCE_FOREST:
			return Vector2i(local_id % 16, int(local_id / 16))
		SOURCE_WATERFALL:
			return Vector2i(local_id % 6, int(local_id / 6))
		SOURCE_TREES:
			return Vector2i(local_id % 2, int(local_id / 2))
		SOURCE_SPARKLES:
			return Vector2i(local_id % 3, int(local_id / 3))
		SOURCE_PROPS_32:
			return Vector2i(local_id % 4, 0)
		_:
			return Vector2i.ZERO
