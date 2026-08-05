class_name EncounterBuilder
extends RefCounted

## Builds H&I EncounterData from a generated mana-seed map.
## Phase 1+ will flesh out spawn placement and unit rosters.

static func build_from_player_grid(
	grid: PlayerGrid,
	blocked_cells: Dictionary,
	player_spawns: Array[UnitPlacement],
	enemy_spawns: Array[UnitPlacement],
) -> EncounterData:
	var encounter := EncounterData.new()
	encounter.grid_size = Vector2i(grid.width, grid.height)
	encounter.default_terrain = DataLibrary.get_terrain(&"plain")
	encounter.player_spawns = player_spawns
	encounter.enemy_spawns = enemy_spawns

	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var cell := Vector2i(x, y)
			var tile_id: int = grid.get_cell(cell)
			encounter.tile_terrains[cell] = TileIdToTerrain.terrain_for_tile_id(tile_id)
			if blocked_cells.has(cell):
				var terrain: TerrainData = encounter.tile_terrains[cell]
				if terrain != null and not terrain.blocks_movement:
					encounter.tile_terrains[cell] = DataLibrary.get_terrain(&"wall")

	return encounter
