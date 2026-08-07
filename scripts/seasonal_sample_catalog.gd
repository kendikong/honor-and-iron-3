class_name SeasonalSampleCatalog
extends RefCounted

## Seasonal reference maps under Assets/Mana Seed/tilesets/.
## Same composition as the gentle forest sample map; palette = v07â€“v10 (PNGs not on disk).

const ASSET_ROOT: String = "res://Assets/Mana Seed/tilesets/"

const SEASON_ORDER: PackedStringArray = ["spring", "summer", "autumn", "winter"]

const SEASONS: Array[Dictionary] = [
	{
		"key": "spring",
		"label": "Spring",
		"variant": 7,
		"palette": "v07 spring",
		"path": ASSET_ROOT + "seasonal sample (spring).png",
	},
	{
		"key": "summer",
		"label": "Summer",
		"variant": 8,
		"palette": "v08 summer",
		"path": ASSET_ROOT + "seasonal sample (summer).png",
	},
	{
		"key": "autumn",
		"label": "Autumn",
		"variant": 9,
		"palette": "v09 autumn",
		"path": ASSET_ROOT + "seasonal sample (autumn).png",
	},
	{
		"key": "winter",
		"label": "Winter",
		"variant": 10,
		"palette": "v10 winter",
		"path": ASSET_ROOT + "seasonal sample (winter).png",
	},
]

static var _forest_ids_cache: Array[int] = []
static var _overlay_cache: Array[Dictionary] = []


static func season_label_list() -> String:
	var labels: PackedStringArray = []
	for season: Dictionary in SEASONS:
		labels.append(str(season["label"]).to_lower())
	return "/".join(labels)


static func featured_forest_local_ids() -> Array[int]:
	if not _forest_ids_cache.is_empty():
		return _forest_ids_cache.duplicate()
	var seen: Dictionary = {}
	for layer: Array in SampleMapData.all_layers():
		for gid: int in layer:
			if gid <= 0:
				continue
			var cell: Dictionary = TileSetFactory.global_id_to_cell(gid)
			if cell.is_empty():
				continue
			if int(cell["source_id"]) != TileSetFactory.SOURCE_FOREST:
				continue
			var atlas: Vector2i = cell["atlas_coords"]
			var local_id: int = atlas.x + atlas.y * TileCatalog.ATLAS_COLUMNS
			seen[local_id] = true
	var result: Array[int] = []
	for key: int in seen.keys():
		result.append(key)
	result.sort()
	_forest_ids_cache = result
	return _forest_ids_cache.duplicate()


static func is_featured_forest_tile(local_id: int) -> bool:
	return local_id in featured_forest_local_ids()


static func featured_overlay_entries() -> Array[Dictionary]:
	if not _overlay_cache.is_empty():
		return _overlay_cache.duplicate(true)
	var seen: Dictionary = {}
	for layer: Array in SampleMapData.all_layers():
		for gid: int in layer:
			if gid <= 0:
				continue
			var cell: Dictionary = TileSetFactory.global_id_to_cell(gid)
			if cell.is_empty():
				continue
			var source_id: int = int(cell["source_id"])
			if source_id == TileSetFactory.SOURCE_FOREST:
				continue
			var atlas: Vector2i = cell["atlas_coords"]
			var key: String = "%d:%d:%d" % [source_id, atlas.x, atlas.y]
			if seen.has(key):
				continue
			seen[key] = {
				"source_id": source_id,
				"atlas_coords": atlas,
				"label": _overlay_label(source_id, atlas),
				"use_case": _overlay_use_case(source_id, atlas),
			}
	var result: Array[Dictionary] = []
	for value: Dictionary in seen.values():
		result.append(value)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["source_id"]) != int(b["source_id"]):
			return int(a["source_id"]) < int(b["source_id"])
		var aa: Vector2i = a["atlas_coords"]
		var bb: Vector2i = b["atlas_coords"]
		if aa.y != bb.y:
			return aa.y < bb.y
		return aa.x < bb.x
	)
	_overlay_cache = result
	return _overlay_cache.duplicate(true)


static func seasonal_use_case_suffix() -> String:
	return "Featured in seasonal sample (%s)" % season_label_list()


static func make_sample_texture(season_key: String) -> Texture2D:
	for season: Dictionary in SEASONS:
		if str(season["key"]) == season_key:
			return load(str(season["path"]))
	return null


static func make_overlay_preview_texture(source_id: int, atlas: Vector2i) -> Texture2D:
	var path: String = _overlay_texture_path(source_id)
	if path.is_empty():
		return null
	var sheet: Texture2D = load(path)
	if sheet == null:
		return null
	var tile_size: Vector2i = _overlay_tile_size(source_id)
	var tex: AtlasTexture = AtlasTexture.new()
	tex.atlas = sheet
	tex.region = Rect2(atlas.x * tile_size.x, atlas.y * tile_size.y, tile_size.x, tile_size.y)
	tex.filter_clip = true
	return tex


static func _overlay_texture_path(source_id: int) -> String:
	const C = preload("res://scripts/mana_seed_constants.gd")
	match source_id:
		TileSetFactory.SOURCE_TREES:
			return C.ASSET_ROOT + "gentle sheets/gentle trees 80x96 v01.png"
		TileSetFactory.SOURCE_PROPS_32:
			return C.ASSET_ROOT + "gentle sheets/gentle 32x32 v01.png"
		TileSetFactory.SOURCE_WATERFALL:
			return C.ASSET_ROOT + "gentle animations/gentle waterfall A v01.png"
		TileSetFactory.SOURCE_SPARKLES:
			return C.ASSET_ROOT + "gentle animations/gentle water sparkles A v01.png"
		_:
			return ""


static func _overlay_tile_size(source_id: int) -> Vector2i:
	match source_id:
		TileSetFactory.SOURCE_TREES:
			return Vector2i(80, 96)
		TileSetFactory.SOURCE_PROPS_32:
			return Vector2i(32, 32)
		TileSetFactory.SOURCE_WATERFALL:
			return Vector2i(16, 16)
		TileSetFactory.SOURCE_SPARKLES:
			return Vector2i(16, 16)
		_:
			return Vector2i(16, 16)


static func _overlay_label(source_id: int, atlas: Vector2i) -> String:
	match source_id:
		TileSetFactory.SOURCE_TREES:
			var idx: int = clampi(atlas.x, 0, TileCatalog.TREE_80_LABELS.size() - 1)
			return TileCatalog.TREE_80_LABELS[idx]
		TileSetFactory.SOURCE_PROPS_32:
			var pidx: int = clampi(atlas.x, 0, TileCatalog.PROPS_32_LABELS.size() - 1)
			return TileCatalog.PROPS_32_LABELS[pidx]
		TileSetFactory.SOURCE_WATERFALL:
			return "Waterfall A (%d, %d)" % [atlas.x, atlas.y]
		TileSetFactory.SOURCE_SPARKLES:
			return "Water sparkles A (%d, %d)" % [atlas.x, atlas.y]
		_:
			return "Source %d (%d, %d)" % [source_id, atlas.x, atlas.y]


static func _overlay_use_case(source_id: int, atlas: Vector2i) -> String:
	var base: String = TileCatalog.describe_overlay_source(source_id, atlas)
	return "%s Â· %s" % [base, seasonal_use_case_suffix()]
