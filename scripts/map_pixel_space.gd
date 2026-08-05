class_name MapPixelSpace
extends RefCounted

## Map-root local pixel coordinates for cloud/shadow sampling.
## Matches TacticalMapView grid_to_local / grid_to_foot_local (used_rect-relative).

const TILE_PX: float = 16.0


static func size_px_from_grid(grid: PlayerGrid) -> Vector2:
	if grid == null:
		return Vector2.ZERO
	return Vector2(grid.width, grid.height) * TILE_PX


static func size_px_from_ground(ground: TileMapLayer) -> Vector2:
	if ground == null:
		return Vector2.ZERO
	var used: Rect2i = ground.get_used_rect()
	if used.size == Vector2i.ZERO:
		return Vector2.ZERO
	return Vector2(used.size) * TILE_PX


static func used_origin_cell(ground: TileMapLayer) -> Vector2i:
	if ground == null:
		return Vector2i.ZERO
	return ground.get_used_rect().position


static func map_world_origin(map_root: Node2D) -> Vector2:
	if map_root == null:
		return Vector2.ZERO
	return map_root.global_position


static func map_scale(map_root: Node2D) -> float:
	if map_root == null:
		return 1.0
	return map_root.scale.x


## Top-left of GroundLayer used_rect in map-root local space (shadow quad origin).
static func content_top_left_px(ground: TileMapLayer) -> Vector2:
	if ground == null:
		return Vector2.ZERO
	return ground.position


## Map-root local position â†’ content-relative pixel (shadow bake / shade_at).
static func content_map_px(ground: TileMapLayer, map_root_local: Vector2) -> Vector2:
	return map_root_local - content_top_left_px(ground)


static func cell_top_left_px(ground: TileMapLayer, cell: Vector2i) -> Vector2:
	if ground == null:
		return Vector2(cell) * TILE_PX
	var used: Rect2i = ground.get_used_rect()
	var local_cell: Vector2i = cell - used.position
	return ground.position + Vector2(local_cell) * TILE_PX


static func cell_foot_px(ground: TileMapLayer, cell: Vector2i) -> Vector2:
	return cell_top_left_px(ground, cell) + Vector2(TILE_PX * 0.5, TILE_PX)


static func foot_map_px(foot_px: Vector2) -> Vector2:
	return Vector2(floor(foot_px.x), floor(foot_px.y))


static func cell_from_foot_px(ground: TileMapLayer, foot_px: Vector2) -> Vector2i:
	if ground == null:
		return Vector2i(
			int(floor((foot_px.x - TILE_PX * 0.5) / TILE_PX)),
			int(floor((foot_px.y - TILE_PX) / TILE_PX)),
		)
	var used: Rect2i = ground.get_used_rect()
	var layer_local: Vector2 = foot_px - ground.position
	var local_cell: Vector2i = Vector2i(
		int(round((layer_local.x - TILE_PX * 0.5) / TILE_PX)),
		int(round((layer_local.y - TILE_PX) / TILE_PX)),
	)
	return local_cell + used.position
