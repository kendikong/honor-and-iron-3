class_name TileCatalog
extends RefCounted

## Metadata for gentle forest v01 atlas tiles (library scene + docs).

const _C = preload("res://scripts/mana_seed_constants.gd")

const FOREST_TEXTURE_PATH: String = "res://Assets/Mana Seed/gentle sheets/gentle forest v01.png"
const FOREST_TSX: String = _C.FOREST_TSX
const ATLAS_COLUMNS: int = 16
const TILE_COUNT: int = 256

const CORNER_LABELS: PackedStringArray = ["TL", "T", "TR", "L", "R", "BL", "B", "BR"]

# Manual tags from tile_registry.md / AutoDecorator usage.
const GRASS_INTERIOR_IDS: Array[int] = [98, 97]
# 16Ã—16 tree trunk/base â€” sample map composes with 80Ã—96 overlay; never random grass fill.
const TREE_GROUND_IDS: Array[int] = [29, 30, 31, 47]
# 16Ã—16 tree canopy fragments â€” sample overlay layer only; never scatter as pebble/flora.
const TREE_CANOPY_OVERLAY_IDS: Array[int] = [11, 12, 13, 14, 15, 27, 28]
const GRASS_DECOR_IDS: Array[int] = [91, 90]
const FLOWER_DECOR_IDS: Array[int] = [104, 105, 106]
const PEBBLE_DECOR_IDS: Array[int] = [88, 89]
const ROCK_SINGLE_IDS: Array[int] = [52]
const RUIN_SINGLE_IDS: Array[int] = [107]
## Forest scatter tiles that block movement (1Ã—1 footprint at the anchor cell).
## #88 = rock/pebble cluster â€” small boulder, non-walkable.
const SCATTER_BLOCK_IDS: Array[int] = [88]

## Atlas cells with no visible pixels â€” editor preview looks blank.
const ATLAS_EMPTY_SLOT_IDS: Array[int] = [
	118, 119, 120, 121, 122, 123, 127, 134, 135, 143,
	153, 154, 168, 169, 170, 171, 201, 202, 244, 247,
]

## Per-tile overrides (any category) â€” checked before category defaults.
const TILE_USAGE_OVERRIDES: Dictionary = {
	11: "Tree canopy leaf fragment â€” sparse pixels; preview can look empty",
	15: "Tree canopy leaf fragment â€” sparse pixels; preview can look empty",
	42: "Weed on grass overlay â€” not used procedurally (assign grass_decor)",
	75: "Elevation cliff strip accent â€” sparse; preview can look empty",
	91: "Weed/moss overlay â€” AutoDecorator scatter pool; preview can look empty",
	95: "Grass tuft edge blend â€” sparse pixels; preview can look empty",
	107: "Ruin floor prop â€” PlayerGrid RUIN stamp; dark pixels on dark preview",
	148: "Water â€” small submerged rocks â€” hand-place (sample map)",
	164: "Water â€” deep/shallow transition (open water to north) â€” hand-place (sample map)",
	180: "Water â€” deep interior â€” hand-place (sample map)",
	196: "Water â€” deep/shallow transition (open water to south) â€” hand-place (sample map)",
	212: "Water â€” two medium submerged rocks â€” hand-place (sample map)",
	228: "Water â€” one large submerged rock â€” hand-place (sample map)",
}

const MISC_TILE_USAGE: Dictionary = {
	6: "Dirt path accent tile (non-wang) â€” not used",
	7: "Dirt path accent tile (non-wang) â€” not used",
	8: "Dirt path accent tile (non-wang) â€” not used",
	9: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	10: "Dirt path accent tile (non-wang) â€” not used",
	22: "Dirt path filler (non-wang) â€” not used",
	23: "Dirt path filler (non-wang) â€” not used",
	24: "Dirt path filler (non-wang) â€” not used",
	25: "Dirt path filler (non-wang) â€” not used",
	26: "Dirt path filler (non-wang) â€” not used",
	38: "Dirt/cliff transition accent â€” not used",
	39: "Dirt/cliff transition accent â€” not used",
	40: "Dirt/cliff transition accent â€” not used",
	41: "Dirt/cliff transition accent â€” not used",
	42: "Weed on grass overlay â€” not used procedurally (assign grass_decor)",
	43: "Dirt/cliff transition accent â€” not used",
	44: "Dirt/cliff transition accent â€” not used",
	45: "Dirt/cliff transition accent â€” not used",
	46: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	54: "Cliff/rock dirt face fragment â€” not used",
	55: "Cliff/rock dirt face fragment â€” not used",
	56: "Cliff/rock dirt face fragment â€” not used",
	57: "Fallen log set-piece â€” manual only; do not scatter (tile_registry)",
	58: "Cliff/rock dirt face fragment â€” not used",
	59: "Cliff/rock dirt face fragment â€” not used",
	60: "Cliff/rock dirt face fragment â€” not used",
	61: "Cliff/rock dirt face fragment â€” not used",
	62: "Cliff/rock dirt face fragment â€” not used",
	63: "Cliff/rock dirt face fragment â€” not used",
	70: "Elevation cliff vertical strip â€” not used",
	71: "Elevation cliff vertical strip â€” not used",
	72: "Elevation cliff vertical strip â€” not used",
	73: "Elevation cliff vertical strip â€” not used",
	74: "Large rock set-piece â€” manual only; do not scatter (tile_registry)",
	75: "Elevation cliff strip accent â€” sparse; preview can look empty",
	76: "Elevation cliff vertical strip â€” not used",
	77: "Elevation cliff vertical strip â€” not used",
	78: "Elevation cliff vertical strip â€” not used",
	79: "Elevation cliff vertical strip â€” not used",
	82: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	86: "Grass edge / tuft blend â€” not used",
	87: "Grass edge / tuft blend â€” not used",
	92: "Grass edge / tuft blend â€” not used",
	93: "Grass edge / tuft blend â€” not used",
	94: "Grass edge / tuft blend â€” not used",
	95: "Grass tuft edge blend â€” sparse pixels; preview can look empty",
	102: "Grass fringe under trees â€” not used",
	103: "Grass fringe under trees â€” not used",
	108: "Small cliff rubble / rock chip â€” not used",
	109: "Small cliff rubble / rock chip â€” not used",
	110: "Small cliff rubble / rock chip â€” not used",
	111: "Small cliff rubble / rock chip â€” not used",
	118: "Atlas slot empty â€” no Mana Seed art (blank preview)",
	119: "Atlas slot empty â€” no Mana Seed art (blank preview)",
	120: "Atlas slot empty â€” no Mana Seed art (blank preview)",
	121: "Atlas slot empty â€” no Mana Seed art (blank preview)",
	122: "Atlas slot empty â€” no Mana Seed art (blank preview)",
	123: "Atlas slot empty â€” no Mana Seed art (blank preview)",
	124: "Cliff stair / ledge set-piece fragment â€” not used",
	125: "Cliff stair / ledge set-piece fragment â€” not used",
	126: "Cliff stair / ledge set-piece fragment â€” not used",
	127: "Atlas slot empty â€” no Mana Seed art (blank preview)",
	134: "Atlas slot empty â€” no Mana Seed art (blank preview)",
	135: "Atlas slot empty â€” no Mana Seed art (blank preview)",
	136: "Water shore foam/rim accent (hand-layer) â€” not used",
	137: "Water shore foam/rim accent (hand-layer) â€” not used",
	138: "Water shore foam/rim accent (hand-layer) â€” not used",
	139: "Water shore foam/rim accent (hand-layer) â€” not used",
	140: "Water shore foam/rim accent (hand-layer) â€” not used",
	141: "Water shore foam/rim accent (hand-layer) â€” not used",
	142: "Water shore foam/rim accent (hand-layer) â€” not used",
	143: "Atlas slot empty â€” no Mana Seed art (blank preview)",
	148: "Water â€” small submerged rocks â€” hand-place (sample map)",
	149: "Water depth gradient tile (hand-layer) â€” not used",
	150: "Water depth gradient tile (hand-layer) â€” not used",
	151: "Water depth gradient tile (hand-layer) â€” not used",
	152: "Water depth gradient tile (hand-layer) â€” not used",
	153: "Atlas slot empty â€” no Mana Seed art (blank preview)",
	154: "Atlas slot empty â€” no Mana Seed art (blank preview)",
	155: "Water depth gradient tile (hand-layer) â€” not used",
	156: "Water depth gradient tile (hand-layer) â€” not used",
	157: "Water depth gradient tile (hand-layer) â€” not used",
	158: "Water depth gradient tile (hand-layer) â€” not used",
	159: "Water depth gradient tile (hand-layer) â€” not used",
	164: "Water â€” deep/shallow transition (open water to north) â€” hand-place (sample map)",
	165: "Deep navy water interior (hand-painted) â€” not used",
	166: "Deep navy water interior (hand-painted) â€” not used",
	167: "Deep navy water interior (hand-painted) â€” not used",
	168: "Atlas slot empty â€” no Mana Seed art (blank preview)",
	169: "Atlas slot empty â€” no Mana Seed art (blank preview)",
	170: "Atlas slot empty â€” no Mana Seed art (blank preview)",
	171: "Atlas slot empty â€” no Mana Seed art (blank preview)",
	172: "Deep navy water interior (hand-painted) â€” not used",
	173: "Deep navy water interior (hand-painted) â€” not used",
	174: "Deep navy water interior (hand-painted) â€” not used",
	175: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	180: "Water â€” deep interior â€” hand-place (sample map)",
	181: "Deep water / dark stream tile (hand-painted) â€” not used",
	182: "Deep water / dark stream tile (hand-painted) â€” not used",
	183: "Deep water / dark stream tile (hand-painted) â€” not used",
	184: "Deep water / dark stream tile (hand-painted) â€” not used",
	185: "Deep water / dark stream tile (hand-painted) â€” not used",
	186: "Deep water / dark stream tile (hand-painted) â€” not used",
	187: "Deep water / dark stream tile (hand-painted) â€” not used",
	188: "Deep water / dark stream tile (hand-painted) â€” not used",
	189: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	190: "Deep water / dark stream tile (hand-painted) â€” not used",
	191: "Deep water / dark stream tile (hand-painted) â€” not used",
	192: "Shallow pebble water interior (hand-painted) â€” not used",
	193: "Shallow pebble water interior (hand-painted) â€” not used",
	194: "Shallow pebble water interior (hand-painted) â€” not used",
	195: "Shallow pebble water interior (hand-painted) â€” not used",
	196: "Water â€” deep/shallow transition (open water to south) â€” hand-place (sample map)",
	197: "Shallow pebble water interior (hand-painted) â€” not used",
	198: "Shallow pebble water interior (hand-painted) â€” not used",
	199: "Shallow pebble water interior (hand-painted) â€” not used",
	200: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	201: "Atlas slot empty â€” no Mana Seed art (blank preview)",
	202: "Atlas slot empty â€” no Mana Seed art (blank preview)",
	203: "Shallow pebble water interior (hand-painted) â€” not used",
	204: "Shallow pebble water interior (hand-painted) â€” not used",
	205: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	206: "Shallow pebble water interior (hand-painted) â€” not used",
	207: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	208: "Stream / waterfall approach water tile â€” not used",
	209: "Stream / waterfall approach water tile â€” not used",
	210: "Stream / waterfall approach water tile â€” not used",
	211: "Stream / waterfall approach water tile â€” not used",
	212: "Water â€” two medium submerged rocks â€” hand-place (sample map)",
	213: "Stream / waterfall approach water tile â€” not used",
	214: "Stream / waterfall approach water tile â€” not used",
	215: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	216: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	217: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	218: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	219: "Stream / waterfall approach water tile â€” not used",
	220: "Stream / waterfall approach water tile â€” not used",
	221: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	222: "Stream / waterfall approach water tile â€” not used",
	223: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	224: "Waterfall column / demo cascade tile â€” not used",
	225: "Waterfall column / demo cascade tile â€” not used",
	226: "Waterfall column / demo cascade tile â€” not used",
	227: "Waterfall column / demo cascade tile â€” not used",
	228: "Water â€” one large submerged rock â€” hand-place (sample map)",
	229: "Waterfall column / demo cascade tile â€” not used",
	230: "Waterfall column / demo cascade tile â€” not used",
	231: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	232: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	233: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	234: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	235: "Waterfall column / demo cascade tile â€” not used",
	236: "Waterfall column / demo cascade tile â€” not used",
	237: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	238: "Waterfall column / demo cascade tile â€” not used",
	239: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	240: "Waterfall column / demo cascade tile â€” not used",
	241: "Waterfall column / demo cascade tile â€” not used",
	242: "Waterfall column / demo cascade tile â€” not used",
	243: "Waterfall column / demo cascade tile â€” not used",
	244: "Atlas slot empty â€” no Mana Seed art (blank preview)",
	245: "Waterfall column / demo cascade tile â€” not used",
	246: "Waterfall column / demo cascade tile â€” not used",
	247: "Atlas slot empty â€” no Mana Seed art (blank preview)",
	248: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	249: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	250: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
	251: "Waterfall column / demo cascade tile â€” not used",
	252: "Waterfall column / demo cascade tile â€” not used",
	253: "Waterfall column / demo cascade tile â€” not used",
	254: "Waterfall column / demo cascade tile â€” not used",
	255: "Phase 0 sample map (SampleMapLoader) â€” hand-painted only",
}

const PROPS_32_LABELS: PackedStringArray = [
	"Tree stump (32Ã—32)",
	"Boulder cluster (32Ã—32)",
	"Large bush (32Ã—32)",
	"Tall plant (32Ã—32)",
]
## Prop movement blocks per atlas column â€” offset from 32Ã—32 anchor (NW of 2Ã—2 spill).
## Atlas 3 (tall plant) omitted â€” walkable.
const PROP_MOVEMENT_BLOCKS: Dictionary = {
	0: {"offset": Vector2i(0, 0), "size": Vector2i(1, 1)},  # stump â€” upper-west only
	1: {"offset": Vector2i(0, 0), "size": Vector2i(1, 1)},  # boulder â€” upper-west cell
	2: {"offset": Vector2i(0, 0), "size": Vector2i(1, 2)},  # bush â€” west column
}
const PROP_RENDER_FOOTPRINT: Vector2i = Vector2i(2, 2)
const TREE_80_LABELS: PackedStringArray = [
	"Large tree A (80Ã—96)",
	"Large tree B (80Ã—96)",
]


static func prop_movement_block_cells(anchor: Vector2i, atlas_x: int) -> Array[Vector2i]:
	if not PROP_MOVEMENT_BLOCKS.has(atlas_x):
		return []
	var spec: Dictionary = PROP_MOVEMENT_BLOCKS[atlas_x]
	var off: Vector2i = spec["offset"] as Vector2i
	var size: Vector2i = spec["size"] as Vector2i
	var cells: Array[Vector2i] = []
	for dy: int in range(size.y):
		for dx: int in range(size.x):
			cells.append(anchor + off + Vector2i(dx, dy))
	return cells


static func prop_render_footprint_cells(anchor: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dy: int in range(PROP_RENDER_FOOTPRINT.y):
		for dx: int in range(PROP_RENDER_FOOTPRINT.x):
			cells.append(anchor + Vector2i(dx, dy))
	return cells


static func prop_movement_block_cell_set(anchor: Vector2i, atlas_x: int) -> Dictionary:
	var blocked: Dictionary = {}
	for cell: Vector2i in prop_movement_block_cells(anchor, atlas_x):
		blocked[cell_key(cell)] = true
	return blocked


static func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


const CATEGORY_ORDER: PackedStringArray = [
	"grass_interior",
	"grass_decor",
	"tree_ground",
	"tree_canopy",
	"dirt_wang",
	"elevation_wang",
	"water_wang",
	"ruin_single",
	"forbidden",
	"misc",
]

const CATEGORY_TITLES: Dictionary = {
	"grass_interior": "Grass interior",
	"grass_decor": "Grass decor (overlay)",
	"tree_ground": "Tree trunk / base (ground)",
	"tree_canopy": "Tree canopy fragment (overlay)",
	"dirt_wang": "Dirt (Wang autotile)",
	"elevation_wang": "Elevation / cliff (Wang)",
	"water_wang": "Water (Wang autotile)",
	"ruin_single": "Ruin floor prop",
	"forbidden": "Do not use (manual only)",
	"misc": "Misc / unassigned",
}

## Non-wang tiles the peering editor can assign (empty string = clear override).
const ASSIGNABLE_CATEGORY_KEYS: PackedStringArray = [
	"",
	"grass_interior",
	"grass_decor",
	"tree_ground",
	"ruin_single",
	"forbidden",
]


static func category_title(category_key: String) -> String:
	if category_key.is_empty():
		return "Unassigned (auto-detect)"
	return str(CATEGORY_TITLES.get(category_key, category_key))


static func is_random_scatter_allowed(local_id: int) -> bool:
	return local_id not in TREE_GROUND_IDS and local_id not in TREE_CANOPY_OVERLAY_IDS


static func build_forest_entries(peering_map: TerrainPeeringMap = null) -> Array[Dictionary]:
	var wang_by_id: Dictionary = _load_wang_map()
	if peering_map == null:
		peering_map = _load_peering_map()
	var entries: Array[Dictionary] = []
	for local_id: int in range(TILE_COUNT):
		var tsx_wang: Array[int] = wang_by_id.get(local_id, _empty_wang())
		var wang: Array[int] = _effective_wang_for_tile(local_id, tsx_wang, peering_map)
		var category: String = effective_category(local_id, tsx_wang, peering_map)
		entries.append({
			"id": local_id,
			"atlas": _local_id_to_atlas(local_id),
			"category": category,
			"use_case": _use_case_for(local_id, category, tsx_wang),
			"orientation": _orientation_for_tile(local_id, wang, peering_map),
		})
	return entries


static func entries_grouped() -> Dictionary:
	var grouped: Dictionary = {}
	for key: String in CATEGORY_ORDER:
		grouped[key] = [] as Array[Dictionary]
	var entries: Array[Dictionary] = build_forest_entries()
	for entry: Dictionary in entries:
		var cat: String = str(entry["category"])
		if not grouped.has(cat):
			grouped[cat] = [] as Array[Dictionary]
		grouped[cat].append(entry)
	for key: String in grouped.keys():
		var bucket: Array = grouped[key]
		bucket.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["id"]) < int(b["id"])
		)
	return grouped


static func make_atlas_texture(local_id: int) -> AtlasTexture:
	if _atlas_tex_cache.has(local_id):
		return _atlas_tex_cache[local_id] as AtlasTexture
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = load(FOREST_TEXTURE_PATH)
	var coords: Vector2i = _local_id_to_atlas(local_id)
	atlas.region = Rect2(coords.x * 16, coords.y * 16, 16, 16)
	atlas.filter_clip = true
	_atlas_tex_cache[local_id] = atlas
	return atlas


static func is_atlas_empty_slot(local_id: int) -> bool:
	return local_id in ATLAS_EMPTY_SLOT_IDS


static func clear_atlas_texture_cache() -> void:
	_atlas_tex_cache.clear()


static func _local_id_to_atlas(local_id: int) -> Vector2i:
	return Vector2i(local_id % ATLAS_COLUMNS, int(local_id / ATLAS_COLUMNS))


static func _empty_wang() -> Array[int]:
	var empty: Array[int] = []
	return empty


static func _load_peering_map() -> TerrainPeeringMap:
	if ResourceLoader.exists(TerrainPeeringMap.DEFAULT_PATH):
		return load(TerrainPeeringMap.DEFAULT_PATH) as TerrainPeeringMap
	return null


static func _effective_wang_for_tile(
	local_id: int,
	tsx_wang: Array[int],
	peering_map: TerrainPeeringMap,
) -> Array[int]:
	if peering_map == null or tsx_wang.is_empty():
		return tsx_wang
	var pattern: Dictionary = TerrainPeeringPatterns.pattern_for_tile(local_id)
	if pattern.is_empty():
		return tsx_wang
	var pattern_key: String = str(pattern["key"])
	if peering_map.get_canonical(pattern_key) != local_id:
		return tsx_wang
	return peering_map.get_effective_wang(pattern_key)


static func _orientation_for_tile(
	local_id: int,
	wang: Array[int],
	peering_map: TerrainPeeringMap,
) -> String:
	var text: String = _orientation_for(wang)
	if peering_map == null or wang.is_empty():
		return text
	var pattern: Dictionary = TerrainPeeringPatterns.pattern_for_tile(local_id)
	if pattern.is_empty():
		return text
	var pattern_key: String = str(pattern["key"])
	if peering_map.get_canonical(pattern_key) == local_id and peering_map.custom_wang_by_pattern.has(pattern_key):
		text += " Â· override"
	return text


static func _load_wang_map() -> Dictionary:
	var parsed: Dictionary = TsxTilesetParser.parse_file(FOREST_TSX)
	return TsxTilesetParser.wang_map_by_id(parsed)


static func effective_category(
	local_id: int,
	tsx_wang: Array[int],
	peering_map: TerrainPeeringMap = null,
) -> String:
	if peering_map == null:
		peering_map = _load_peering_map()
	if peering_map != null:
		var override_key: String = peering_map.get_tile_category_override(local_id)
		if not override_key.is_empty():
			return override_key
	return _default_category_for(local_id, tsx_wang)


static func _default_category_for(local_id: int, wang: Array[int]) -> String:
	if local_id in GRASS_INTERIOR_IDS:
		return "grass_interior"
	if local_id in TREE_GROUND_IDS:
		return "tree_ground"
	if local_id in TREE_CANOPY_OVERLAY_IDS:
		return "tree_canopy"
	if local_id in GRASS_DECOR_IDS or local_id in FLOWER_DECOR_IDS or local_id in PEBBLE_DECOR_IDS:
		return "grass_decor"
	if local_id in RUIN_SINGLE_IDS:
		return "ruin_single"
	if not wang.is_empty():
		match ManaSeedTerrainPeering.dominant_terrain_from_wangid(wang):
			ManaSeedTerrainPeering.TERRAIN_DIRT:
				return "dirt_wang"
			ManaSeedTerrainPeering.TERRAIN_ELEVATION:
				return "elevation_wang"
			ManaSeedTerrainPeering.TERRAIN_WATER:
				return "water_wang"
	return "misc"


static func _category_for(local_id: int, wang: Array[int]) -> String:
	return effective_category(local_id, wang, null)


static func seasonal_sample_suffix(local_id: int) -> String:
	if SeasonalSampleCatalog.is_featured_forest_tile(local_id):
		return " Â· " + SeasonalSampleCatalog.seasonal_use_case_suffix()
	return ""


static func _use_case_for(local_id: int, category: String, wang: Array[int]) -> String:
	if TILE_USAGE_OVERRIDES.has(local_id):
		return str(TILE_USAGE_OVERRIDES[local_id]) + seasonal_sample_suffix(local_id)
	if is_atlas_empty_slot(local_id):
		return "Atlas slot empty â€” no Mana Seed art (blank preview)"
	var seasonal_suffix: String = seasonal_sample_suffix(local_id)
	match category:
		"grass_interior":
			return "GroundLayer grass fill â€” seeded interior (AutoDecorator)" + seasonal_suffix
		"grass_decor":
			if local_id in PEBBLE_DECOR_IDS:
				return "OverlayLayer pebble scatter" + seasonal_suffix
			if local_id in FLOWER_DECOR_IDS:
				return "OverlayLayer flower scatter â€” never sole ground" + seasonal_suffix
			return "OverlayLayer weed/moss scatter â€” never sole ground" + seasonal_suffix
		"tree_ground":
			return "Tree base / trunk â€” ground under 80Ã—96 overlay" + seasonal_suffix
		"tree_canopy":
			return "Tree canopy leaf fragment â€” overlay beside 80Ã—96 tree only" + seasonal_suffix
		"ruin_single":
			return "PlayerGrid RUIN â€” ruin floor prop" + seasonal_suffix
		"forbidden":
			return "Do not use procedurally â€” hand-place / sample map only" + seasonal_suffix
		"misc":
			return _misc_tile_use_case(local_id) + seasonal_suffix
	if local_id in ROCK_SINGLE_IDS:
		return "PlayerGrid ROCK â€” single tile (elevation art; terrain peer Phase 9)" + seasonal_suffix
	if wang.is_empty():
		return _misc_tile_use_case(local_id) + seasonal_suffix
	return _wang_use_case(category, wang) + seasonal_suffix


static func _misc_tile_use_case(local_id: int) -> String:
	return str(MISC_TILE_USAGE.get(local_id, "Not used"))


static func _wang_use_case(category: String, wang: Array[int]) -> String:
	# Interior fill = every wang corner matches (incl. grass=0 on edges).
	# Do not use unique non-zero values â€” shore corners only have water in their mask.
	if _all_same(wang) and not wang.is_empty() and int(wang[0]) > 0:
		match int(wang[0]):
			1:
				return "Dirt interior â€” terrain_connect(DIRT) fill"
			2:
				return "Elevation interior â€” cliff plateau fill"
			3:
				return "Water interior â€” terrain_connect(WATER) deep cell"
	if category == "water_wang":
		return "Water shoreline / corner â€” terrain_connect(WATER) edge"
	if category == "dirt_wang":
		return "Dirt path edge / corner â€” terrain_connect(DIRT)"
	if category == "elevation_wang":
		return "Cliff / ledge transition â€” terrain_connect(ELEVATION) Phase 9"
	return "Wang transition tile â€” terrain_connect by dominant terrain"


static func _orientation_for(wang: Array[int]) -> String:
	if wang.is_empty():
		return "â€”"
	if _all_same(wang):
		var value: int = wang[0]
		if value == 0:
			return "All grass (unused wang)"
		var terrain: int = ManaSeedTerrainPeering.wang_index_to_terrain(value)
		return "Interior fill (%s all edges)" % TerrainPeeringBridge.terrain_label(terrain).to_lower()
	var parts: PackedStringArray = []
	for i: int in range(8):
		var value: int = wang[i]
		if value <= 0:
			continue
		var terrain: int = ManaSeedTerrainPeering.wang_index_to_terrain(value)
		parts.append("%s=%s" % [CORNER_LABELS[i], TerrainPeeringBridge.terrain_label(terrain).to_lower()])
	return ", ".join(parts)


static func _all_same(wang: Array[int]) -> bool:
	if wang.is_empty():
		return true
	var first: int = wang[0]
	for value: int in wang:
		if value != first:
			return false
	return true


static func tile_ids_in_category(category: String, peering_map: TerrainPeeringMap = null) -> Array[int]:
	var result: Array[int] = []
	for entry: Dictionary in build_forest_entries(peering_map):
		if str(entry["category"]) == category:
			result.append(int(entry["id"]))
	result.sort()
	return result


static func describe_forest_tile(local_id: int) -> Dictionary:
	_ensure_forest_entry_cache()
	return _forest_entry_cache.get(
		local_id,
		{
			"id": local_id,
			"category": "misc",
			"use_case": "Unknown forest atlas tile",
			"orientation": "â€”",
		},
	)


static var _forest_entry_cache: Dictionary = {}


static func _ensure_forest_entry_cache() -> void:
	if not _forest_entry_cache.is_empty():
		return
	for entry: Dictionary in build_forest_entries():
		_forest_entry_cache[int(entry["id"])] = entry


static func invalidate_runtime_cache() -> void:
	_forest_entry_cache.clear()
	clear_atlas_texture_cache()
static var _atlas_tex_cache: Dictionary = {}


static func describe_source_tile(source_id: int, atlas: Vector2i, local_id: int = -1) -> String:
	match source_id:
		TileSetFactory.SOURCE_FOREST:
			var id: int = local_id if local_id >= 0 else atlas.x + atlas.y * ATLAS_COLUMNS
			var entry: Dictionary = describe_forest_tile(id)
			return (
				"Forest [b]#%d[/b] â€” %s\n%s"
				% [
					id,
					category_title(str(entry["category"])),
					str(entry["use_case"]),
				]
			)
		TileSetFactory.SOURCE_PROPS_32:
			return describe_overlay_source(source_id, atlas)
		TileSetFactory.SOURCE_TREES:
			return describe_overlay_source(source_id, atlas)
		TileSetFactory.SOURCE_WATERFALL:
			return "Waterfall atlas (%d, %d)" % [atlas.x, atlas.y]
		TileSetFactory.SOURCE_SPARKLES:
			return "Water sparkle (%d, %d)" % [atlas.x, atlas.y]
		_:
			return "Source %d atlas (%d, %d)" % [source_id, atlas.x, atlas.y]


static func describe_overlay_source(source_id: int, atlas: Vector2i) -> String:
	match source_id:
		TileSetFactory.SOURCE_PROPS_32:
			var idx: int = clampi(atlas.x, 0, PROPS_32_LABELS.size() - 1)
			return (
				"32Ã—32 prop [b]%s[/b] (atlas x=%d)\nSpans 2Ã—2 cells from anchor â€” not a PlayerGrid type"
				% [PROPS_32_LABELS[idx], atlas.x]
			)
		TileSetFactory.SOURCE_TREES:
			var tidx: int = clampi(atlas.x, 0, TREE_80_LABELS.size() - 1)
			return (
				"80Ã—96 sprite [b]%s[/b] (variant %d)\nAnchor = PlayerGrid TREE cell; spans ~5Ã—6 cells"
				% [TREE_80_LABELS[tidx], atlas.x]
			)
		TileSetFactory.SOURCE_FOREST:
			var local: int = atlas.x + atlas.y * ATLAS_COLUMNS
			var entry: Dictionary = describe_forest_tile(local)
			return "16Ã—16 overlay forest #%d â€” %s" % [local, str(entry["use_case"])]
		_:
			return "Overlay source %d (%d,%d)" % [source_id, atlas.x, atlas.y]
