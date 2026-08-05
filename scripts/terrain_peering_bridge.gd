class_name TerrainPeeringBridge
extends RefCounted

## UI helpers: wang arrays â†” peering labels â†” 3Ã—3 neighborhood grids.

const PEER_SHORT: PackedStringArray = ["TL", "T", "TR", "L", "R", "BL", "B", "BR"]
const PEER_FULL: PackedStringArray = [
	"Top-left", "Top", "Top-right", "Left", "Right", "Bottom-left", "Bottom", "Bottom-right",
]

# 3Ã—3 grid index â†’ peering bit index (center cell index 4 has no peering slot).
const GRID3_TO_PEER: PackedInt32Array = [0, 1, 2, 3, -1, 4, 5, 6, 7]

const TERRAIN_GRASS: int = -1
const TERRAIN_DIRT: int = 0
const TERRAIN_ELEVATION: int = 1
const TERRAIN_WATER: int = 2

const CYCLE_TERRAINS: PackedInt32Array = [
	TERRAIN_GRASS, TERRAIN_DIRT, TERRAIN_ELEVATION, TERRAIN_WATER,
]


static func wang_digit_to_terrain(digit: int) -> int:
	match digit:
		0:
			return TERRAIN_GRASS
		1:
			return TERRAIN_DIRT
		2:
			return TERRAIN_ELEVATION
		3:
			return TERRAIN_WATER
		_:
			return TERRAIN_GRASS


static func terrain_to_wang_digit(terrain: int) -> int:
	match terrain:
		TERRAIN_DIRT:
			return 1
		TERRAIN_ELEVATION:
			return 2
		TERRAIN_WATER:
			return 3
		_:
			return 0


static func cycle_terrain(current: int) -> int:
	var index: int = CYCLE_TERRAINS.find(current)
	if index < 0:
		return TERRAIN_GRASS
	return CYCLE_TERRAINS[(index + 1) % CYCLE_TERRAINS.size()]


static func terrain_label(terrain: int) -> String:
	match terrain:
		TERRAIN_DIRT:
			return "Dirt"
		TERRAIN_ELEVATION:
			return "Cliff"
		TERRAIN_WATER:
			return "Water"
		_:
			return "Grass"


static func terrain_color(terrain: int) -> Color:
	match terrain:
		TERRAIN_DIRT:
			return Color(0.55, 0.35, 0.2)
		TERRAIN_ELEVATION:
			return Color(0.45, 0.5, 0.35)
		TERRAIN_WATER:
			return Color(0.2, 0.35, 0.7)
		_:
			return Color(0.25, 0.45, 0.28)


static func orientation_label(wang: Array) -> String:
	var parts: PackedStringArray = []
	for i: int in range(mini(wang.size(), PEER_FULL.size())):
		var digit: int = int(wang[i])
		if digit <= 0:
			continue
		parts.append("%s=%s" % [PEER_FULL[i], terrain_label(wang_digit_to_terrain(digit))])
	if parts.is_empty():
		return "All grass"
	return ", ".join(parts)


static func default_neighborhood(pattern: Dictionary) -> Array[int]:
	var cells: Array[int] = []
	cells.resize(9)
	cells.fill(TERRAIN_GRASS)
	cells[4] = int(pattern.get("terrain", TERRAIN_GRASS))
	return cells


static func neighborhood_from_wang(wang: Array) -> Array[int]:
	# Test map: center uses pattern terrain; each direction shows what sits on that map cell.
	var cells: Array[int] = []
	cells.resize(9)
	cells.fill(TERRAIN_GRASS)
	for grid_i: int in range(9):
		if grid_i == 4:
			continue
		var peer_i: int = GRID3_TO_PEER[grid_i]
		if peer_i < 0 or peer_i >= wang.size():
			continue
		cells[grid_i] = wang_digit_to_terrain(int(wang[peer_i]))
	# Center = dominant terrain of wang pattern
	cells[4] = ManaSeedTerrainPeering.dominant_terrain_from_wangid(wang)
	if cells[4] < 0:
		cells[4] = TERRAIN_GRASS
	return cells


static func cycle_neighborhood_cell(cells: Array[int], grid_index: int) -> Array[int]:
	var copy: Array[int] = cells.duplicate()
	if grid_index < 0 or grid_index >= copy.size():
		return copy
	copy[grid_index] = cycle_terrain(int(copy[grid_index]))
	return copy


static func cycle_wang_peer(wang: Array, peer_index: int) -> Array[int]:
	var copy: Array[int] = []
	for value: Variant in wang:
		copy.append(int(value))
	if peer_index < 0 or peer_index >= copy.size():
		return copy
	var terrain: int = wang_digit_to_terrain(int(copy[peer_index]))
	copy[peer_index] = terrain_to_wang_digit(cycle_terrain(terrain))
	return copy


static func grid_offset(grid_index: int) -> Vector2i:
	match grid_index:
		0:
			return Vector2i(-1, -1)
		1:
			return Vector2i(0, -1)
		2:
			return Vector2i(1, -1)
		3:
			return Vector2i(-1, 0)
		4:
			return Vector2i(0, 0)
		5:
			return Vector2i(1, 0)
		6:
			return Vector2i(-1, 1)
		7:
			return Vector2i(0, 1)
		8:
			return Vector2i(1, 1)
		_:
			return Vector2i.ZERO
