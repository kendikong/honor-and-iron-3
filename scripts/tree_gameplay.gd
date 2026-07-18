class_name TreeGameplay
extends RefCounted

## Tree trunk blocking + canopy depth — reads TreeLayer / OverlayLayer, not provenance.

const _C = preload("res://scripts/mana_seed_constants.gd")

const TREE_FOOTPRINT: Vector2i = Vector2i(5, 6)
## Visual center of 80×96 from NW anchor; trunk foot is 2 cells south of center.
const TREE_CENTER_OFFSET: Vector2i = Vector2i(2, 3)
const TREE_TRUNK_OFFSET_FROM_CENTER: Vector2i = Vector2i(0, 2)
## Same as ShadowPlacer — empirical align with Mana Seed tree art (+ shadow bake).
const TREE_SHADOW_NUDGE_CELLS: Vector2i = Vector2i(-2, -3)
const TREE_SPRITE_SIZE: Vector2i = Vector2i(80, 96)
const TREE_CANOPY_FADE_HEIGHT_PX: int = 72
const TREE_DEPTH_WEST_SPILL_PX: int = 16
const PROP_SPRITE_SIZE: Vector2i = Vector2i(32, 32)
const TILE_PX: int = 16

const _LPC = preload("res://scripts/lpc/lpc_constants.gd")


static func nudge_cells(settings: EffectsSettings = null) -> Vector2i:
	if settings != null and settings.shadow_disable_tree_nudge:
		return Vector2i.ZERO
	return TREE_SHADOW_NUDGE_CELLS


static func visual_footprint_anchor(
	render_anchor: Vector2i,
	settings: EffectsSettings = null,
) -> Vector2i:
	return render_anchor + nudge_cells(settings)


static func tree_anchors(trees: TileMapLayer) -> Array[Vector2i]:
	var anchors: Array[Vector2i] = []
	if trees == null:
		return anchors
	for cell: Vector2i in trees.get_used_cells():
		if trees.get_cell_source_id(cell) == _C.SOURCE_TREES:
			anchors.append(cell)
	return anchors


static func trunk_foot_cell(
	anchor: Vector2i,
	grid: PlayerGrid,
	_settings: EffectsSettings = null,
) -> Vector2i:
	var foot: Vector2i = anchor + Vector2i(0, 2)
	if grid != null and _in_bounds(grid, foot):
		return foot
	return Vector2i(-1, -1)


static func trunk_block_cells(
	anchor: Vector2i,
	grid: PlayerGrid,
	settings: EffectsSettings = null,
) -> Array[Vector2i]:
	var foot: Vector2i = trunk_foot_cell(anchor, grid, settings)
	if foot.x < 0:
		return []
	# Single cell at trunk foot row (big 80×96 tree).
	var block: Vector2i = foot
	if grid != null and _in_bounds(grid, block):
		return [block]
	return []


enum BlockKind {
	NONE,
	LOGICAL_TILE,
	TREE_TRUNK,
	PROP_FOOTPRINT,
}


static func movement_block_kind(
	cell: Vector2i,
	grid: PlayerGrid,
	trees: TileMapLayer,
	overlay: TileMapLayer,
	settings: EffectsSettings = null,
) -> BlockKind:
	if grid == null or not _in_bounds(grid, cell):
		return BlockKind.LOGICAL_TILE
	if Walkability.blocks_movement_tile(grid.get_cell(cell)):
		return BlockKind.LOGICAL_TILE
	if _props_block_cell(cell, grid, overlay):
		return BlockKind.PROP_FOOTPRINT
	if _tree_trunk_blocks_cell(cell, grid, trees, settings):
		return BlockKind.TREE_TRUNK
	return BlockKind.NONE


static func blocks_movement_at(
	cell: Vector2i,
	grid: PlayerGrid,
	trees: TileMapLayer,
	overlay: TileMapLayer,
	settings: EffectsSettings = null,
) -> bool:
	if grid == null:
		return false
	if _props_block_cell(cell, grid, overlay):
		return true
	return _tree_trunk_blocks_cell(cell, grid, trees, settings)


static func cell_from_world(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / float(TILE_PX))),
		int(floor(world_pos.y / float(TILE_PX))),
	)


## Grid-snapped feet Y for canopy fade — avoids sub-pixel walk tween flicker at boundaries.
static func character_fade_sort_y(actor: Node2D) -> float:
	var cell: Vector2i = cell_from_world(actor.position)
	return (float(cell.y) + 1.0) * float(TILE_PX) - 1.0


static func character_sort_y(actor: Node2D) -> float:
	# Since the actor's origin is now exactly at their visual feet (the bottom of their grid cell),
	# we can simply use their exact Y position as the sort key. This prevents float boundary 
	# snapping issues and allows smooth depth transitions while walking.
	return actor.position.y


static func character_feet_y(actor: Node2D) -> float:
	return character_sort_y(actor)


static func character_behind_trees(
	char_x: float,
	sort_y: float,
	grid: PlayerGrid,
	trees: TileMapLayer,
	settings: EffectsSettings = null,
) -> bool:
	if grid == null or trees == null:
		return false
	for anchor: Vector2i in tree_anchors(trees):
		if tree_occludes_character(char_x, sort_y, cell_from_world(Vector2(char_x, sort_y)), anchor, grid, trees, settings):
			return true
	return false


static func tree_occludes_character(
	char_x: float,
	sort_y: float,
	char_cell: Vector2i,
	anchor: Vector2i,
	grid: PlayerGrid,
	trees: TileMapLayer,
	settings: EffectsSettings = null,
) -> bool:
	if trees == null or grid == null:
		return false
	if not _sprite_depth_overlap(char_x, sort_y, trees, anchor, TREE_SPRITE_SIZE, TREE_DEPTH_WEST_SPILL_PX):
		return false
	if sort_y < trunk_sort_line_y(anchor, grid, trees, settings):
		return true
	return _under_canopy(char_cell, anchor, settings)


static func spawn_cell_occluded_by_tree(
	cell: Vector2i,
	trees: TileMapLayer,
	settings: EffectsSettings = null,
) -> bool:
	if trees == null:
		return false
	for anchor: Vector2i in tree_anchors(trees):
		if _under_canopy(cell, anchor, settings):
			return true
	return false


static func character_behind_props(
	char_x: float,
	sort_y: float,
	grid: PlayerGrid,
	overlay: TileMapLayer,
) -> bool:
	if grid == null or overlay == null:
		return false
	for anchor: Vector2i in prop_anchors(overlay):
		var atlas_x: int = overlay.get_cell_atlas_coords(anchor).x
		if not _sprite_depth_overlap(char_x, sort_y, overlay, anchor, PROP_SPRITE_SIZE, 0):
			continue
		if sort_y < prop_sort_line_y(anchor, atlas_x, grid):
			return true
	return false


static func character_behind_ground_rocks(
	char_x: float,
	sort_y: float,
	grid: PlayerGrid,
) -> bool:
	if grid == null:
		return false
	var char_cell: Vector2i = Vector2i(
		int(floor(char_x / float(TILE_PX))),
		int(sort_y / float(TILE_PX)) - 1,
	)
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var cell: Vector2i = char_cell + Vector2i(dx, dy)
			if not _in_bounds(grid, cell):
				continue
			var tile_id: int = grid.get_cell(cell)
			if tile_id != TileId.Type.ROCK and tile_id != TileId.Type.RUIN:
				continue
			if not _cell_depth_overlap_x(char_x, cell):
				continue
			if sort_y < (float(cell.y) + 1.0) * float(TILE_PX):
				return true
	return false


## Canopy fade only — stricter than depth sort; unit feet must sit inside the upper canopy.
static func canopy_fade_rect(layer: TileMapLayer, anchor: Vector2i) -> Rect2:
	return _canopy_fade_rect(layer, anchor)


static func tree_should_fade_canopy(
	char_x: float,
	sort_y: float,
	anchor: Vector2i,
	grid: PlayerGrid,
	trees: TileMapLayer,
	settings: EffectsSettings = null,
	margin_px: float = 0.0,
) -> bool:
	if trees == null or grid == null:
		return false
	if sort_y >= trunk_sort_line_y(anchor, grid, trees, settings):
		return false
	var canopy_rect: Rect2 = _canopy_fade_rect(trees, anchor)
	if margin_px > 0.0:
		canopy_rect = canopy_rect.grow(margin_px)
	return canopy_rect.has_point(Vector2(char_x, sort_y))


static func prop_anchors(overlay: TileMapLayer) -> Array[Vector2i]:
	var anchors: Array[Vector2i] = []
	if overlay == null:
		return anchors
	for cell: Vector2i in overlay.get_used_cells():
		if overlay.get_cell_source_id(cell) == _C.SOURCE_PROPS_32:
			anchors.append(cell)
	return anchors


static func prop_sort_line_y(anchor: Vector2i, atlas_x: int, grid: PlayerGrid) -> float:
	var south_row: int = -1
	if TileCatalog.PROP_MOVEMENT_BLOCKS.has(atlas_x):
		for block_cell: Vector2i in TileCatalog.prop_movement_block_cells(anchor, atlas_x):
			if grid != null and not _in_bounds(grid, block_cell):
				continue
			south_row = maxi(south_row, block_cell.y)
	else:
		south_row = anchor.y + TileCatalog.PROP_RENDER_FOOTPRINT.y - 1
	if south_row < 0:
		return INF
	return (float(south_row) + 1.0) * float(TILE_PX)


static func apply_character_depth(
	actor: Node2D,
	grid: PlayerGrid,
	trees: TileMapLayer,
	overlay: TileMapLayer = null,
	settings: EffectsSettings = null,
) -> void:
	if actor == null:
		return
	actor.z_as_relative = false
	var sort_y: float = character_sort_y(actor)
	var char_x: float = actor.position.x
	var behind_tree: bool = character_behind_trees(char_x, sort_y, grid, trees, settings)
	var behind_prop: bool = (
		character_behind_props(char_x, sort_y, grid, overlay)
		or character_behind_ground_rocks(char_x, sort_y, grid)
	)
	if behind_prop:
		actor.z_index = _C.Z_UNDER_TREE
	elif behind_tree:
		actor.z_index = _C.Z_TREE - 1
	else:
		actor.z_index = _LPC.Z_CHARACTER


static func trunk_sort_line_y(
	anchor: Vector2i,
	grid: PlayerGrid,
	trees: TileMapLayer = null,
	settings: EffectsSettings = null,
) -> float:
	if trees != null:
		var td: TileData = trees.get_cell_tile_data(anchor)
		if td != null:
			var top_left: Vector2 = trees.map_to_local(anchor) - Vector2(td.texture_origin) - Vector2(TREE_SPRITE_SIZE) * 0.5
			var foot: Vector2i = trunk_foot_cell(anchor, grid, settings)
			if foot.x >= 0:
				return (float(foot.y) + 1.0) * float(TILE_PX)
			return top_left.y + float(td.y_sort_origin)
	var foot_cell: Vector2i = trunk_foot_cell(anchor, grid, settings)
	if foot_cell.x < 0:
		return INF
	return (float(foot_cell.y) + 1.0) * float(TILE_PX)


static func _sprite_rect(layer: TileMapLayer, anchor: Vector2i, sprite_size: Vector2i) -> Rect2:
	var td: TileData = layer.get_cell_tile_data(anchor)
	if td == null:
		var fallback: Vector2 = Vector2(anchor) * float(TILE_PX)
		return Rect2(fallback - Vector2(sprite_size) * 0.5, Vector2(sprite_size))
	var top_left: Vector2 = layer.map_to_local(anchor) - Vector2(td.texture_origin) - Vector2(sprite_size) * 0.5
	return Rect2(top_left, Vector2(sprite_size))


static func _canopy_fade_rect(layer: TileMapLayer, anchor: Vector2i) -> Rect2:
	var full: Rect2 = _sprite_rect(layer, anchor, TREE_SPRITE_SIZE)
	var canopy_h: float = minf(float(TREE_CANOPY_FADE_HEIGHT_PX), full.size.y)
	return Rect2(full.position, Vector2(full.size.x, canopy_h))


static func _sprite_depth_overlap(
	char_x: float,
	sort_y: float,
	layer: TileMapLayer,
	anchor: Vector2i,
	sprite_size: Vector2i,
	west_spill_px: int,
) -> bool:
	var rect: Rect2 = _sprite_rect(layer, anchor, sprite_size)
	var left: float = rect.position.x - float(west_spill_px)
	var right: float = rect.position.x + rect.size.x + float(west_spill_px)
	if char_x < left or char_x > right:
		return false
	# If the character's feet (sort_y) are above the TOP of the sprite, they are not interacting
	if sort_y < rect.position.y:
		return false
	return true


static func _cell_depth_overlap_x(char_x: float, cell: Vector2i) -> bool:
	var left: float = float(cell.x) * float(TILE_PX)
	var right: float = left + float(TILE_PX)
	return char_x >= left and char_x <= right


static func _tree_trunk_blocks_cell(
	cell: Vector2i,
	grid: PlayerGrid,
	trees: TileMapLayer,
	settings: EffectsSettings = null,
) -> bool:
	for anchor: Vector2i in tree_anchors(trees):
		for trunk_cell: Vector2i in trunk_block_cells(anchor, grid, settings):
			if cell == trunk_cell:
				return true
	return false


static func _props_block_cell(
	cell: Vector2i,
	grid: PlayerGrid,
	overlay: TileMapLayer,
) -> bool:
	if overlay == null:
		return false
	for anchor: Vector2i in overlay.get_used_cells():
		if overlay.get_cell_source_id(anchor) != _C.SOURCE_PROPS_32:
			continue
		var atlas_x: int = overlay.get_cell_atlas_coords(anchor).x
		for block_cell: Vector2i in TileCatalog.prop_movement_block_cells(anchor, atlas_x):
			if not _in_bounds(grid, block_cell):
				continue
			if cell == block_cell:
				return true
	return false


static func _under_canopy(
	char_cell: Vector2i,
	tree_anchor: Vector2i,
	settings: EffectsSettings = null,
) -> bool:
	var footprint_anchor: Vector2i = visual_footprint_anchor(tree_anchor, settings)
	if _cell_in_footprint(char_cell, footprint_anchor, TREE_FOOTPRINT):
		return true
	return MapRenderProvenance.forest_occluded_by_tree_canopy(footprint_anchor, char_cell)


static func _cell_in_footprint(pos: Vector2i, anchor: Vector2i, footprint: Vector2i) -> bool:
	return (
		pos.x >= anchor.x
		and pos.y >= anchor.y
		and pos.x < anchor.x + footprint.x
		and pos.y < anchor.y + footprint.y
	)


static func _in_bounds(grid: PlayerGrid, cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < grid.width
		and cell.y < grid.height
	)
