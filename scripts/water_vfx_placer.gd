class_name WaterVfxPlacer
extends RefCounted

## Places Mana Seed water sparkle tiles on VFXLayer â€” shore foam + deep sparkles.
## Asset guide: row 0 = full tile, row 1 = diagonal (inside corner), row 2 = quarter (outside).

const SOURCE_SPARKLES: int = TileSetFactory.SOURCE_SPARKLES

# Animated sparkle anchors (atlas coords) â€” 3-frame loops in gentle water sparkles A v01.
const SPARKLE_FULL: Vector2i = Vector2i(0, 0)
const SPARKLE_DIAG: Vector2i = Vector2i(0, 1)
const SPARKLE_QUARTER: Vector2i = Vector2i(0, 2)

const _CARDINALS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]

const _DEEP_SPARKLE_CHANCE: float = 0.70

var foam_cells: Array[Vector2i] = []
var sparkle_cells: Array[Vector2i] = []
var _foam_atlas: Dictionary = {}
var _sparkle_atlas: Dictionary = {}


func rebuild(grid: PlayerGrid, rng: RandomNumberGenerator) -> void:
	foam_cells.clear()
	sparkle_cells.clear()
	_foam_atlas.clear()
	_sparkle_atlas.clear()
	if grid == null:
		return
	var depths: Dictionary = WaterCellMask.build_depth_field(grid)
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			if grid.get_cell(pos) != TileId.Type.WATER:
				continue
			if WaterCellMask.is_shore_water(grid, pos):
				if rng.randf() < 0.72:
					foam_cells.append(pos)
					_foam_atlas[pos] = _pick_shore_sparkle(grid, pos)
			elif WaterCellMask.is_deep_water(grid, pos, depths) and rng.randf() < _DEEP_SPARKLE_CHANCE:
				sparkle_cells.append(pos)
				_sparkle_atlas[pos] = SPARKLE_FULL


func foam_atlas_at(pos: Vector2i) -> Vector2i:
	return _foam_atlas.get(pos, SPARKLE_DIAG) as Vector2i


func apply(vfx: TileMapLayer, foam_on: bool, sparkles_on: bool) -> void:
	## Sparkles/foam render via WaterSparkleSprites â€” clear legacy static tiles only.
	if vfx == null:
		return
	_clear_sparkle_source(vfx)


func erase_sparkle_cells(vfx: TileMapLayer) -> void:
	if vfx == null:
		return
	_clear_sparkle_source(vfx)


static func _clear_sparkle_source(vfx: TileMapLayer) -> void:
	var used: Array[Vector2i] = vfx.get_used_cells()
	for pos: Vector2i in used:
		if vfx.get_cell_source_id(pos) == SOURCE_SPARKLES:
			vfx.erase_cell(pos)


static func _pick_shore_sparkle(grid: PlayerGrid, pos: Vector2i) -> Vector2i:
	var land_mask: int = 0
	for i: int in range(_CARDINALS.size()):
		var neighbor: Vector2i = pos + _CARDINALS[i]
		if not WaterCellMask.in_bounds(grid, neighbor):
			land_mask |= 1 << i
			continue
		if grid.get_cell(neighbor) != TileId.Type.WATER:
			land_mask |= 1 << i
	var land_count: int = 0
	for i: int in range(4):
		if land_mask & (1 << i):
			land_count += 1
	if land_count >= 3:
		return SPARKLE_QUARTER
	if land_count == 2:
		return SPARKLE_DIAG
	return SPARKLE_DIAG
