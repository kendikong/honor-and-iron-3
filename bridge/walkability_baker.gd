class_name WalkabilityBaker
extends RefCounted

## Bakes render-aware walkability into a tactics passability grid at encounter load.

static func bake(
	grid: PlayerGrid,
	trees: TileMapLayer,
	overlay: TileMapLayer,
	scatter: TileMapLayer,
	settings: EffectsSettings,
) -> Dictionary:
	var blocked: Dictionary = {}
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var cell := Vector2i(x, y)
			if not Walkability.is_walkable(grid, cell, trees, overlay, settings, scatter):
				blocked[cell] = true
	return blocked


static func is_cell_blocked(blocked: Dictionary, cell: Vector2i) -> bool:
	return blocked.has(cell)
