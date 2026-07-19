class_name MapPixelSpace
extends RefCounted

## Canonical map-root pixel coordinates for cloud/shadow sampling (ground + CPU + debug).

const TILE_PX: float = 16.0


static func used_rect(ground: TileMapLayer) -> Rect2i:
	if ground == null:
		return Rect2i(0, 0, 0, 0)
	return ground.get_used_rect()


static func origin_cells(ground: TileMapLayer) -> Vector2i:
	return used_rect(ground).position


static func origin_px(ground: TileMapLayer) -> Vector2:
	return Vector2(origin_cells(ground)) * TILE_PX


static func size_px(ground: TileMapLayer, grid: PlayerGrid = null) -> Vector2:
	var used: Rect2i = used_rect(ground)
	if used.size != Vector2i.ZERO:
		return Vector2(used.size) * TILE_PX
	if grid != null:
		return Vector2(grid.width, grid.height) * TILE_PX
	return Vector2.ZERO


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
	return ground.local_to_map(ground.to_local(foot_px))


static func map_origin_global(ground: TileMapLayer, map_root: Node2D) -> Vector2:
	if map_root == null:
		return Vector2.ZERO
	return map_root.to_global(origin_px(ground))
