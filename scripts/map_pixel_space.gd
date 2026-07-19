class_name MapPixelSpace
extends RefCounted

## Map-root local pixel coordinates for cloud/shadow sampling.
## Cell (0,0) top-left is always pixel (0,0) — do NOT offset by TileMap used_rect.position.

const TILE_PX: float = 16.0


static func size_px_from_grid(grid: PlayerGrid) -> Vector2:
	if grid == null:
		return Vector2.ZERO
	return Vector2(grid.width, grid.height) * TILE_PX


static func map_world_origin(map_root: Node2D) -> Vector2:
	if map_root == null:
		return Vector2.ZERO
	return map_root.global_position


static func map_scale(map_root: Node2D) -> float:
	if map_root == null:
		return 1.0
	return map_root.scale.x


static func cell_top_left_px(ground: TileMapLayer, cell: Vector2i) -> Vector2:
	if ground == null:
		return Vector2(cell) * TILE_PX
	return ground.position + ground.map_to_local(cell)


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
	var layer_local: Vector2 = foot_px - ground.position
	return ground.local_to_map(layer_local)
