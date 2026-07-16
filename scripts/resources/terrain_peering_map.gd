class_name TerrainPeeringMap
extends Resource

## Wang fingerprint key (e.g. `0,0,0,3,0,3,0,0`) → canonical forest atlas tile id.

const DEFAULT_PATH: String = "res://resources/terrain_peering_map.tres"

@export var pattern_to_tile: Dictionary = {}
@export var custom_wang_by_pattern: Dictionary = {}
@export var tile_category_by_id: Dictionary = {}
## When true, duplicate wang variants are stripped so only the canonical tile participates in terrain_connect.
@export var suppress_variants: bool = true


func get_tile_category_override(tile_id: int) -> String:
	for key: Variant in [str(tile_id), tile_id]:
		if tile_category_by_id.has(key):
			return str(tile_category_by_id[key])
	return ""


func set_tile_category(tile_id: int, category: String) -> void:
	tile_category_by_id.erase(tile_id)
	tile_category_by_id.erase(str(tile_id))
	if category.is_empty() or category == "misc":
		return
	tile_category_by_id[str(tile_id)] = category


func clear_tile_category_overrides() -> void:
	tile_category_by_id.clear()


func is_tile_category_overridden(tile_id: int) -> bool:
	return not get_tile_category_override(tile_id).is_empty()


func get_effective_wang(pattern_key: String) -> Array[int]:
	if custom_wang_by_pattern.has(pattern_key):
		return TerrainPeeringPatterns.parse_wang_key(str(custom_wang_by_pattern[pattern_key]))
	var pattern: Dictionary = TerrainPeeringPatterns.get_pattern(pattern_key)
	if pattern.is_empty():
		return []
	return TsxTilesetParser._as_int_array(pattern["wang"])


func set_custom_wang(pattern_key: String, wang: Array) -> void:
	custom_wang_by_pattern[pattern_key] = TerrainPeeringPatterns.wang_key(wang)


func is_customized(pattern_key: String) -> bool:
	if custom_wang_by_pattern.has(pattern_key):
		return true
	if not pattern_to_tile.has(pattern_key):
		return false
	var pattern: Dictionary = TerrainPeeringPatterns.get_pattern(pattern_key)
	if pattern.is_empty():
		return false
	return int(pattern_to_tile[pattern_key]) != int(pattern["tsx_default"])


static func load_or_create() -> TerrainPeeringMap:
	if ResourceLoader.exists(DEFAULT_PATH):
		var existing: TerrainPeeringMap = load(DEFAULT_PATH)
		if existing != null:
			_migrate_legacy_slots(existing)
			return existing
	var map: TerrainPeeringMap = TerrainPeeringMap.new()
	map.reset_from_tsx()
	return map


static func _migrate_legacy_slots(map: TerrainPeeringMap) -> void:
	if not map.pattern_to_tile.is_empty():
		return
	var legacy: Variant = map.get("slot_to_tile")
	if legacy is Dictionary and not (legacy as Dictionary).is_empty():
		map.pattern_to_tile = {}
		map.reset_from_tsx()


func reset_from_tsx() -> void:
	pattern_to_tile = TerrainPeeringPatterns.build_default_map()
	custom_wang_by_pattern = {}


func get_canonical(pattern_key: String) -> int:
	if pattern_to_tile.has(pattern_key):
		return int(pattern_to_tile[pattern_key])
	var pattern: Dictionary = TerrainPeeringPatterns.get_pattern(pattern_key)
	if pattern.is_empty():
		return -1
	return int(pattern.get("tsx_default", -1))


func set_canonical(pattern_key: String, tile_id: int) -> void:
	pattern_to_tile[pattern_key] = tile_id


func save_to_disk() -> Error:
	return ResourceSaver.save(self, DEFAULT_PATH)
