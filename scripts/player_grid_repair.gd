class_name PlayerGridRepair
extends RefCounted

## Normalizes PlayerGrid so terrain bodies are paintable (Phase 3).
## Primary: thin water/dirt â†’ grass, grass pockets â†’ water (incl. map-edge water pockets).
## Post: water/dirt without a 2Ã—2 corner block â†’ flip the fewest grass cells needed to
##       complete one 2Ã—2 (cheapest corner only â€” never bulk neighborhoods, never waterâ†’grass).
## Post (corner cardinals): single L-corners only (#132/#133 handled after terrain_connect).
## Off-map cells count as matching terrain (hidden map extension).

const MAX_PASSES: int = 64

## Water wang shore tiles that require all four cardinal neighbors to be water on PlayerGrid.
const WATER_DOUBLE_CORNER_ATLAS_IDS: Array[int] = [132, 133]

## TL offsets for each 2Ã—2 where `pos` is BR, BL, TR, or TL respectively.
const _CORNER_TOP_LEFT_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i.ZERO,
]


static func repair(grid: PlayerGrid, provenance: PlayerGridProvenance = null) -> void:
	for _pass: int in range(MAX_PASSES):
		var primary_changed: bool = _primary_pass(grid, provenance)
		var post_changed: bool = _post_2x2_pass(grid, provenance)
		var corner_changed: bool = _post_terrain_corner_cardinals_pass(grid, provenance)
		if not primary_changed and not post_changed and not corner_changed:
			return


static func _primary_pass(grid: PlayerGrid, provenance: PlayerGridProvenance) -> bool:
	var changes: Array[Dictionary] = []
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			var tile: int = grid.get_cell(pos)
			var repaired: int = _suggest_primary_repair(grid, pos, tile)
			if repaired != tile:
				changes.append({"pos": pos, "from": tile, "tile": repaired})
	for change: Dictionary in changes:
		var pos: Vector2i = change["pos"]
		grid.set_cell(pos, int(change["tile"]))
		if provenance != null:
			provenance.add_step(
				pos,
				"repair_primary",
				int(change["tile"]),
				"PlayerGridRepair primary: %s â†’ %s"
				% [TileId.type_name(int(change["from"])), TileId.type_name(int(change["tile"]))],
			)
	return not changes.is_empty()


static func _post_2x2_pass(grid: PlayerGrid, provenance: PlayerGridProvenance) -> bool:
	var changes: Array[Dictionary] = []
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			var tile: int = grid.get_cell(pos)
			if tile == TileId.Type.WATER:
				_collect_minimal_2x2_widen(grid, pos, TileId.Type.WATER, changes)
			elif tile == TileId.Type.DIRT:
				_collect_minimal_2x2_widen(grid, pos, TileId.Type.DIRT, changes)
	_apply_unique_changes(grid, changes, provenance)
	return not changes.is_empty()


## Post-process: single L-corners fill 2 arm cardinals + notch.
static func _post_terrain_corner_cardinals_pass(
	grid: PlayerGrid,
	provenance: PlayerGridProvenance,
) -> bool:
	var changes: Array[Dictionary] = []
	for terrain_id: int in [TileId.Type.WATER, TileId.Type.DIRT]:
		for y: int in range(grid.height):
			for x: int in range(grid.width):
				var corner_pos: Vector2i = Vector2i(x, y)
				if grid.get_cell(corner_pos) != terrain_id:
					continue
				var arm_dirs: Array[Vector2i] = _perpendicular_terrain_cardinal_arms(
					grid, corner_pos, terrain_id,
				)
				if arm_dirs.size() == 2:
					var arm_a: Vector2i = arm_dirs[0]
					var arm_b: Vector2i = arm_dirs[1]
					_queue_grass_to_terrain(
						grid,
						changes,
						corner_pos + arm_a,
						terrain_id,
						"single corner arm cardinal",
					)
					_queue_grass_to_terrain(
						grid,
						changes,
						corner_pos + arm_b,
						terrain_id,
						"single corner arm cardinal",
					)
					_queue_grass_to_terrain(
						grid,
						changes,
						corner_pos + arm_a + arm_b,
						terrain_id,
						"single corner notch between arms",
					)
	_apply_corner_cardinal_changes(grid, changes, provenance)
	return not changes.is_empty()


## After terrain_connect: any cell painted #132/#133 â†’ flip cardinal grass on PlayerGrid to water.
static func repair_painted_water_double_corners(
	grid: PlayerGrid,
	ground: TileMapLayer,
	provenance: PlayerGridProvenance = null,
) -> bool:
	var changes: Array[Dictionary] = []
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var pos: Vector2i = Vector2i(x, y)
			if grid.get_cell(pos) != TileId.Type.WATER:
				continue
			var atlas_id: int = _ground_forest_atlas_id(ground, pos)
			if atlas_id not in WATER_DOUBLE_CORNER_ATLAS_IDS:
				continue
			for offset: Vector2i in _cardinal_offsets():
				_queue_grass_to_terrain(
					grid,
					changes,
					pos + offset,
					TileId.Type.WATER,
					"wang #%d cardinal arm" % atlas_id,
				)
	_apply_corner_cardinal_changes(grid, changes, provenance)
	return not changes.is_empty()


static func _ground_forest_atlas_id(ground: TileMapLayer, pos: Vector2i) -> int:
	if ground.get_cell_source_id(pos) != TileSetFactory.SOURCE_FOREST:
		return -1
	var atlas: Vector2i = ground.get_cell_atlas_coords(pos)
	return atlas.x + atlas.y * 16


static func _perpendicular_terrain_cardinal_arms(
	grid: PlayerGrid,
	pos: Vector2i,
	terrain_id: int,
) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = []
	for offset: Vector2i in _cardinal_offsets():
		if _cardinal_has_type_or_hidden(grid, pos, offset, terrain_id):
			dirs.append(offset)
	if dirs.size() != 2:
		return []
	if not _cardinal_offsets_perpendicular(dirs[0], dirs[1]):
		return []
	return dirs


static func _cardinal_offsets_perpendicular(a: Vector2i, b: Vector2i) -> bool:
	return (a.x == 0 and b.y == 0) or (a.y == 0 and b.x == 0)


static func _queue_grass_to_terrain(
	grid: PlayerGrid,
	changes: Array[Dictionary],
	pos: Vector2i,
	terrain_id: int,
	reason: String,
) -> void:
	if not _in_bounds(grid, pos):
		return
	if grid.get_cell(pos) != TileId.Type.GRASS:
		return
	changes.append({"pos": pos, "tile": terrain_id, "detail": reason})


static func _apply_corner_cardinal_changes(
	grid: PlayerGrid,
	changes: Array[Dictionary],
	provenance: PlayerGridProvenance,
) -> void:
	var seen: Dictionary = {}
	for change: Dictionary in changes:
		var change_pos: Vector2i = change["pos"]
		if seen.has(change_pos):
			continue
		seen[change_pos] = true
		var from_type: int = grid.get_cell(change_pos)
		var to_type: int = int(change["tile"])
		grid.set_cell(change_pos, to_type)
		if provenance != null:
			provenance.add_step(
				change_pos,
				"repair_corner_cardinals",
				to_type,
				"PlayerGridRepair corner cardinals: %s â†’ %s (%s)"
				% [TileId.type_name(from_type), TileId.type_name(to_type), str(change["detail"])],
			)


static func _suggest_primary_repair(grid: PlayerGrid, pos: Vector2i, tile: int) -> int:
	match tile:
		TileId.Type.GRASS:
			return _repair_grass_primary(grid, pos)
		TileId.Type.WATER:
			return _repair_water_primary(grid, pos)
		TileId.Type.DIRT:
			return _repair_dirt_primary(grid, pos)
		_:
			return tile


static func _repair_grass_primary(grid: PlayerGrid, pos: Vector2i) -> int:
	if _all_cardinal_neighbors(grid, pos, TileId.Type.WATER):
		return TileId.Type.WATER
	if _is_water_trapped_edge_grass(grid, pos):
		return TileId.Type.WATER
	return TileId.Type.GRASS


## Map-edge grass with no in-bounds land neighbor â€” only water (or void) beside it.
## No wang art for this case; extend water so terrain_connect can paint a shore.
static func _is_water_trapped_edge_grass(grid: PlayerGrid, pos: Vector2i) -> bool:
	var touches_map_edge: bool = false
	for offset: Vector2i in _cardinal_offsets():
		var neighbor: Vector2i = pos + offset
		if not _in_bounds(grid, neighbor):
			touches_map_edge = true
			continue
		if grid.get_cell(neighbor) != TileId.Type.WATER:
			return false
	return touches_map_edge


static func _repair_water_primary(grid: PlayerGrid, pos: Vector2i) -> int:
	if _is_too_thin_terrain(grid, pos, TileId.Type.WATER):
		return TileId.Type.GRASS
	return TileId.Type.WATER


static func _repair_dirt_primary(grid: PlayerGrid, pos: Vector2i) -> int:
	if _is_too_thin_terrain(grid, pos, TileId.Type.DIRT):
		return TileId.Type.GRASS
	return TileId.Type.DIRT


## Pick the single corner 2Ã—2 that needs the fewest grassâ†’terrain flips; queue only those.
static func _collect_minimal_2x2_widen(
	grid: PlayerGrid,
	pos: Vector2i,
	tile_id: int,
	changes: Array[Dictionary],
) -> void:
	if _has_2x2_corner_block(grid, pos, tile_id):
		return
	var grass_cells: Array[Vector2i] = _cheapest_grass_to_complete_2x2(grid, pos, tile_id)
	for grass_pos: Vector2i in grass_cells:
		changes.append({"pos": grass_pos, "tile": tile_id})


static func _cheapest_grass_to_complete_2x2(
	grid: PlayerGrid,
	pos: Vector2i,
	tile_id: int,
) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	var best_count: int = 4
	for top_left_offset: Vector2i in _CORNER_TOP_LEFT_OFFSETS:
		var grass_cells: Array[Vector2i] = _grass_cells_to_complete_block(
			grid, pos + top_left_offset, tile_id,
		)
		if grass_cells.is_empty():
			continue
		if grass_cells.size() < best_count:
			best_count = grass_cells.size()
			best = grass_cells
	return best


## Grass cells in this 2Ã—2 that must flip to `tile_id`. Empty if block impossible or already full.
static func _grass_cells_to_complete_block(
	grid: PlayerGrid,
	top_left: Vector2i,
	tile_id: int,
) -> Array[Vector2i]:
	var grass_cells: Array[Vector2i] = []
	var has_non_grass_gap: bool = false
	for dy: int in 2:
		for dx: int in 2:
			var cell: Vector2i = top_left + Vector2i(dx, dy)
			if _cell_is_type_or_hidden(grid, cell, tile_id):
				continue
			if not _in_bounds(grid, cell):
				return []
			if grid.get_cell(cell) == TileId.Type.GRASS:
				grass_cells.append(cell)
				continue
			has_non_grass_gap = true
	if has_non_grass_gap:
		return []
	return grass_cells


static func _has_2x2_corner_block(grid: PlayerGrid, pos: Vector2i, tile_id: int) -> bool:
	for top_left_offset: Vector2i in _CORNER_TOP_LEFT_OFFSETS:
		if _is_2x2_block(grid, pos + top_left_offset, tile_id):
			return true
	return false


static func _is_2x2_block(grid: PlayerGrid, top_left: Vector2i, tile_id: int) -> bool:
	for dy: int in 2:
		for dx: int in 2:
			if not _cell_is_type_or_hidden(grid, top_left + Vector2i(dx, dy), tile_id):
				return false
	return true


static func _is_too_thin_terrain(grid: PlayerGrid, pos: Vector2i, tile_id: int) -> bool:
	var thin_vertical: bool = (
		not _cardinal_has_type_or_hidden(grid, pos, Vector2i(-1, 0), tile_id)
		and not _cardinal_has_type_or_hidden(grid, pos, Vector2i(1, 0), tile_id)
	)
	var thin_horizontal: bool = (
		not _cardinal_has_type_or_hidden(grid, pos, Vector2i(0, -1), tile_id)
		and not _cardinal_has_type_or_hidden(grid, pos, Vector2i(0, 1), tile_id)
	)
	return thin_vertical or thin_horizontal


static func _cardinal_has_type_or_hidden(grid: PlayerGrid, pos: Vector2i, offset: Vector2i, tile_id: int) -> bool:
	return _cell_is_type_or_hidden(grid, pos + offset, tile_id)


static func _cell_is_type_or_hidden(grid: PlayerGrid, pos: Vector2i, tile_id: int) -> bool:
	if not _in_bounds(grid, pos):
		return true
	return grid.get_cell(pos) == tile_id


static func _apply_unique_changes(
	grid: PlayerGrid,
	changes: Array[Dictionary],
	provenance: PlayerGridProvenance = null,
) -> void:
	var seen: Dictionary = {}
	for change: Dictionary in changes:
		var change_pos: Vector2i = change["pos"]
		if seen.has(change_pos):
			continue
		seen[change_pos] = true
		var from_type: int = grid.get_cell(change_pos)
		var to_type: int = int(change["tile"])
		grid.set_cell(change_pos, to_type)
		if provenance != null:
			provenance.add_step(
				change_pos,
				"repair_2x2",
				to_type,
				"PlayerGridRepair 2Ã—2 widen: %s â†’ %s"
				% [TileId.type_name(from_type), TileId.type_name(to_type)],
			)


static func _all_cardinal_neighbors(grid: PlayerGrid, pos: Vector2i, tile_id: int) -> bool:
	for offset: Vector2i in _cardinal_offsets():
		if _neighbor_tile(grid, pos, offset) != tile_id:
			return false
	return true


static func _neighbor_tile(grid: PlayerGrid, pos: Vector2i, offset: Vector2i) -> int:
	var neighbor: Vector2i = pos + offset
	if not _in_bounds(grid, neighbor):
		return -1
	return grid.get_cell(neighbor)


static func _cardinal_offsets() -> Array[Vector2i]:
	return [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


static func _in_bounds(grid: PlayerGrid, pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < grid.width and pos.y < grid.height
