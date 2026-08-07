class_name Walkability
extends RefCounted

## Tactics walk rules â€” Phase 10 bridge from PlayerGrid logical IDs to movement.

static func is_in_bounds(grid: PlayerGrid, cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < grid.width
		and cell.y < grid.height
	)


static func is_walkable_tile(tile_id: int) -> bool:
	return tile_id == TileId.Type.GRASS or tile_id == TileId.Type.DIRT


static func blocks_movement_tile(tile_id: int) -> bool:
	if is_walkable_tile(tile_id):
		return false
	# TREE trunk blocking comes from TreeLayer, not the anchor logical cell.
	if tile_id == TileId.Type.TREE:
		return false
	return true


static func scatter_blocks_cell(scatter: TileMapLayer, cell: Vector2i) -> bool:
	## Returns true if a blocking scatter tile (e.g. forest rock #88) is on this cell.
	if scatter == null:
		return false
	var source_id: int = scatter.get_cell_source_id(cell)
	if source_id < 0:
		return false
	var atlas: Vector2i = scatter.get_cell_atlas_coords(cell)
	var local_id: int = atlas.y * 16 + atlas.x
	return local_id in TileCatalog.SCATTER_BLOCK_IDS


static func is_walkable(
	grid: PlayerGrid,
	cell: Vector2i,
	trees: TileMapLayer = null,
	overlay: TileMapLayer = null,
	settings: EffectsSettings = null,
	scatter: TileMapLayer = null,
) -> bool:
	if not is_in_bounds(grid, cell):
		return false
	if blocks_movement_tile(grid.get_cell(cell)):
		return false
	if TreeGameplay.blocks_movement_at(cell, grid, trees, overlay, settings):
		return false
	if scatter_blocks_cell(scatter, cell):
		return false
	return true


static func find_spawn_cell(
	grid: PlayerGrid,
	prefer: Vector2i,
	trees: TileMapLayer = null,
	overlay: TileMapLayer = null,
	settings: EffectsSettings = null,
	scatter: TileMapLayer = null,
) -> Vector2i:
	if is_walkable(grid, prefer, trees, overlay, settings, scatter):
		return prefer
	var max_radius: int = maxi(grid.width, grid.height)
	for radius: int in range(1, max_radius + 1):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cell: Vector2i = prefer + Vector2i(dx, dy)
				if is_walkable(grid, cell, trees, overlay, settings, scatter):
					return cell
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var cell: Vector2i = Vector2i(x, y)
			if is_walkable(grid, cell, trees, overlay, settings, scatter):
				return cell
	push_warning("Walkability: no walkable cell in %dx%d grid" % [grid.width, grid.height])
	return prefer
