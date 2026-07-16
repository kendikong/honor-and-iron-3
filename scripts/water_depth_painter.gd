class_name WaterDepthPainter
extends RefCounted

## Paints reference water depth using only the six hand-placed Mana Seed tiles
## identified from the sample map — no other atlas overrides.

const SOURCE_FOREST: int = TileSetFactory.SOURCE_FOREST

# Allowed water art only — do not substitute other local ids.
const TILE_DEEP: int = 180
const TILE_TRANS_OPEN_NORTH: int = 164  # shallow/normal water cell to the north
const TILE_TRANS_OPEN_SOUTH: int = 196  # shallow/normal water cell to the south
const TILE_ROCK_SMALL: int = 148
const TILE_ROCK_MED: int = 212
const TILE_ROCK_LARGE: int = 228

const _NORTH: Vector2i = Vector2i(0, -1)
const _SOUTH: Vector2i = Vector2i(0, 1)

const _SHALLOW_ROCK_CHANCE: float = 0.2


static func apply(
	grid: PlayerGrid,
	ground: TileMapLayer,
	rng: RandomNumberGenerator,
	render_provenance: MapRenderProvenance = null,
) -> void:
	if grid == null or ground == null:
		return
	var depths: Dictionary = WaterCellMask.build_depth_field(grid)
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			if grid.get_cell(pos) != TileId.Type.WATER:
				continue
			var depth: int = int(depths.get(pos, 0))
			if depth <= 0:
				continue
			if not WaterCellMask.may_apply_depth_paint(ground, pos):
				continue
			var local_id: int = _pick_tile(grid, depths, pos, depth, rng)
			if local_id < 0:
				continue
			var atlas: Vector2i = Vector2i(local_id % 16, local_id / 16)
			ground.set_cell(pos, SOURCE_FOREST, atlas, 0)
			if render_provenance != null:
				render_provenance.record_ground(
					pos,
					SOURCE_FOREST,
					atlas,
					"water_depth_ref",
					"Reference water #%d (ring %d)" % [local_id, depth],
				)


static func _pick_tile(
	grid: PlayerGrid,
	depths: Dictionary,
	pos: Vector2i,
	depth: int,
	rng: RandomNumberGenerator,
) -> int:
	if depth >= 2:
		var north: Vector2i = pos + _NORTH
		if depths.get(north, -1) == 1:
			return TILE_TRANS_OPEN_NORTH
		var south: Vector2i = pos + _SOUTH
		if depths.get(south, -1) == 1:
			return TILE_TRANS_OPEN_SOUTH
		return TILE_DEEP
	if depth == 1:
		if rng.randf() >= _SHALLOW_ROCK_CHANCE:
			return -1
		var roll: float = rng.randf()
		if roll < 0.55:
			return TILE_ROCK_SMALL
		if roll < 0.85:
			return TILE_ROCK_MED
		return TILE_ROCK_LARGE
	return -1
