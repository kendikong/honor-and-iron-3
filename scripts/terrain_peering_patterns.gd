class_name TerrainPeeringPatterns
extends RefCounted

## Full Tiled wang fingerprints from gentle forest v01.tsx â€” the real terrain-matching keys.

const _C = preload("res://scripts/mana_seed_constants.gd")

const TERRAIN_DIRT: int = _C.TERRAIN_DIRT
const TERRAIN_ELEVATION: int = _C.TERRAIN_ELEVATION
const TERRAIN_WATER: int = _C.TERRAIN_WATER

const PEER_LABELS: PackedStringArray = ["TL", "T", "TR", "L", "R", "BL", "B", "BR"]
const TERRAIN_NAMES: PackedStringArray = ["dirt", "elevation", "water"]
const TERRAIN_ORDER: PackedInt32Array = [TERRAIN_DIRT, TERRAIN_ELEVATION, TERRAIN_WATER]

const SHAPE_ORDER: PackedStringArray = ["interior", "corner", "edge", "complex"]
const NON_TERRAIN_CATEGORIES: PackedStringArray = [
	"grass_interior",
	"grass_decor",
	"tree_ground",
	"ruin_single",
	"forbidden",
	"misc",
]

const CATEGORY_TITLES: Dictionary = {
	"grass_interior": "Grass interior â€” AutoDecorator fill (no terrain slot)",
	"grass_decor": "Overlay scatter â€” never terrain_connect",
	"tree_ground": "Tree trunk / base â€” sample-map composition",
	"ruin_single": "Ruin floor â€” PlayerGrid RUIN stamp",
	"forbidden": "Do not use procedurally",
	"misc": "Misc â€” unassigned (usage note per tile)",
}


static func wang_key(wang: Array) -> String:
	var parts: PackedStringArray = []
	for value: Variant in wang:
		parts.append(str(int(value)))
	return ",".join(parts)


static func parse_wang_key(key: String) -> Array[int]:
	var result: Array[int] = []
	for part: String in key.split(","):
		if part.is_empty():
			continue
		result.append(int(part))
	return result


static func terrain_title(terrain: int) -> String:
	match terrain:
		TERRAIN_DIRT:
			return "Dirt on grass"
		TERRAIN_ELEVATION:
			return "Elevation / cliff"
		TERRAIN_WATER:
			return "Water on grass"
		_:
			return "All terrains"


static func build_default_map() -> Dictionary:
	var map: Dictionary = {}
	for pattern: Dictionary in all_patterns():
		map[str(pattern["key"])] = int(pattern["tsx_default"])
	return map


static func all_patterns() -> Array[Dictionary]:
	var grouped: Dictionary = _group_wang_tiles()
	var patterns: Array[Dictionary] = []
	for key: String in grouped.keys():
		patterns.append(_build_pattern(key, grouped[key]))
	patterns.sort_custom(_sort_patterns)
	return patterns


static func patterns_for_terrain(terrain: int) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for pattern: Dictionary in all_patterns():
		if int(pattern["terrain"]) == terrain:
			filtered.append(pattern)
	return filtered


static func get_pattern(pattern_key: String) -> Dictionary:
	for pattern: Dictionary in all_patterns():
		if str(pattern["key"]) == pattern_key:
			return pattern
	return {}


static func pattern_for_tile(tile_id: int) -> Dictionary:
	var wang_map: Dictionary = _load_wang_map()
	if not wang_map.has(tile_id):
		return {}
	return get_pattern(wang_key(TsxTilesetParser._as_int_array(wang_map[tile_id])))


static func non_terrain_entries(peering_map: TerrainPeeringMap = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var wang_map: Dictionary = _load_wang_map()
	for entry: Dictionary in TileCatalog.build_forest_entries(peering_map):
		var tile_id: int = int(entry["id"])
		if wang_map.has(tile_id):
			continue
		result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["id"]) < int(b["id"])
	)
	return result


static func coverage_stats(map: TerrainPeeringMap) -> Dictionary:
	var patterns: Array[Dictionary] = all_patterns()
	var customized: int = 0
	for pattern: Dictionary in patterns:
		var key: String = str(pattern["key"])
		if map.is_customized(key):
			customized += 1
	return {
		"pattern_count": patterns.size(),
		"customized": customized,
		"non_terrain": non_terrain_entries().size(),
		"wang_tiles": _load_wang_map().size(),
	}


static func _group_wang_tiles() -> Dictionary:
	var wang_map: Dictionary = _load_wang_map()
	var grouped: Dictionary = {}
	for tile_id: int in wang_map.keys():
		var wang: Array[int] = TsxTilesetParser._as_int_array(wang_map[tile_id])
		var key: String = wang_key(wang)
		if not grouped.has(key):
			grouped[key] = [] as Array[int]
		(grouped[key] as Array).append(tile_id)
	for key: String in grouped.keys():
		var ids: Array = grouped[key]
		ids.sort()
	return grouped


static func _build_pattern(key: String, tile_ids: Array) -> Dictionary:
	var wang: Array[int] = parse_wang_key(key)
	var terrain: int = ManaSeedTerrainPeering.dominant_terrain_from_wangid(wang)
	return {
		"key": key,
		"wang": wang,
		"terrain": terrain,
		"terrain_name": TERRAIN_NAMES[terrain] if terrain >= 0 and terrain < TERRAIN_NAMES.size() else "",
		"label": TerrainPeeringBridge.orientation_label(wang),
		"shape": _classify_shape(wang),
		"candidates": tile_ids.duplicate(),
		"tsx_default": int(tile_ids[0]),
		"variant_count": tile_ids.size(),
	}


static func _sort_patterns(a: Dictionary, b: Dictionary) -> bool:
	var terrain_a: int = int(a.get("terrain", 99))
	var terrain_b: int = int(b.get("terrain", 99))
	if terrain_a != terrain_b:
		return terrain_a < terrain_b
	var shape_a: int = SHAPE_ORDER.find(str(a.get("shape", "")))
	var shape_b: int = SHAPE_ORDER.find(str(b.get("shape", "")))
	if shape_a != shape_b:
		return shape_a < shape_b
	return str(a.get("label", "")) < str(b.get("label", ""))


static func _classify_shape(wang: Array[int]) -> String:
	var active: int = 0
	var first_nonzero: int = -1
	var all_same: bool = true
	for value: int in wang:
		if value <= 0:
			if first_nonzero >= 0:
				all_same = false
			continue
		active += 1
		if first_nonzero < 0:
			first_nonzero = value
		elif value != first_nonzero:
			all_same = false
	if active == 0:
		return "complex"
	if all_same and active == 8:
		return "interior"
	if active == 1:
		return "corner"
	if active == 2:
		return "edge"
	return "complex"


static func _orientation_label(wang: Array[int]) -> String:
	var parts: PackedStringArray = []
	for i: int in range(wang.size()):
		var value: int = int(wang[i])
		if value <= 0:
			continue
		var terrain_name: String = (
			TERRAIN_NAMES[value - 1] if value >= 1 and value <= TERRAIN_NAMES.size() else "?"
		)
		parts.append("%s=%s" % [PEER_LABELS[i], terrain_name])
	if parts.is_empty():
		return "all grass"
	return ", ".join(parts)


static func _load_wang_map() -> Dictionary:
	var parsed: Dictionary = TsxTilesetParser.parse_file(_C.FOREST_TSX)
	return TsxTilesetParser.wang_map_by_id(parsed)
