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


static func build_from_board(board: BoardState) -> EncounterData:
	var encounter := EncounterData.new()
	if board == null:
		return encounter
	encounter.grid_size = board.grid_size
	encounter.default_terrain = DataLibrary.get_terrain(&"plain")
	for coord: Vector2i in board.tiles:
		var tile: TileState = board.tiles[coord]
		var terrain: TerrainData = tile.definition if tile != null else encounter.default_terrain
		encounter.tile_terrains[coord] = terrain
	for unit: UnitState in board.units:
		if unit == null or unit.definition == null:
			continue
		var placement := UnitPlacement.new()
		placement.unit = unit.definition
		placement.coord = unit.position
		if unit.team == GameEnums.Team.PLAYER:
			encounter.player_spawns.append(placement)
		else:
			encounter.enemy_spawns.append(placement)
	return encounter


static func player_grid_for_encounter(encounter: EncounterData) -> PlayerGrid:
	if encounter == null:
		return PlayerGrid.new(1, 1)
	var grid := PlayerGrid.new(
		encounter.grid_size.x,
		encounter.grid_size.y,
		TileId.Type.GRASS,
	)
	for coord: Vector2i in encounter.tile_terrains:
		grid.set_cell(
			coord,
			TileIdToTerrain.tile_id_for_terrain(encounter.tile_terrains[coord]),
		)
	return grid
