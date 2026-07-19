class_name TestBattleEncounterBuilder
extends RefCounted

## Builds the 6×6 grass-only training arena and configured BoardState.


static func build_grass_grid(size: Vector2i = TestBattleSession.MAP_SIZE) -> PlayerGrid:
	return PlayerGrid.new(size.x, size.y, TileId.Type.GRASS)


static func build_encounter(session: TestBattleSession) -> EncounterData:
	var encounter := EncounterData.new()
	encounter.display_name = "Training Arena"
	encounter.grid_size = TestBattleSession.MAP_SIZE
	encounter.default_terrain = DataLibrary.get_terrain(&"plain")
	var grid: PlayerGrid = build_grass_grid()
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var cell := Vector2i(x, y)
			encounter.tile_terrains[cell] = TileIdToTerrain.terrain_for_tile_id(grid.get_cell(cell))

	var player_def: UnitData = DataLibrary.get_unit(session.player_class_id)
	var player_spawn := UnitPlacement.new()
	player_spawn.unit = player_def
	player_spawn.coord = TestBattleSession.DEFAULT_PLAYER_CELL
	encounter.player_spawns.append(player_spawn)

	for coord: Vector2i in session.extra_player_coords:
		var extra := UnitPlacement.new()
		extra.unit = player_def
		extra.coord = coord
		encounter.player_spawns.append(extra)

	var dummy_def: UnitData = DataLibrary.get_training_dummy()
	for coord: Vector2i in session.dummy_coords:
		var dummy_spawn := UnitPlacement.new()
		dummy_spawn.unit = dummy_def
		dummy_spawn.coord = coord
		encounter.enemy_spawns.append(dummy_spawn)

	return encounter


static func build_board(session: TestBattleSession) -> BoardState:
	var plain: TerrainData = DataLibrary.get_terrain(&"plain")
	var board: BoardState = BoardFactory.build_empty(TestBattleSession.MAP_SIZE, plain)
	var id_counter: int = 1

	var player_def: UnitData = DataLibrary.get_unit(session.player_class_id)
	var player_config: Dictionary = session.player_unit_config()
	BoardFactory.place_configured_unit(
		board,
		id_counter,
		player_def,
		GameEnums.Team.PLAYER,
		TestBattleSession.DEFAULT_PLAYER_CELL,
		player_config,
	)
	id_counter += 1

	for coord: Vector2i in session.extra_player_coords:
		BoardFactory.place_configured_unit(
			board,
			id_counter,
			player_def,
			GameEnums.Team.PLAYER,
			coord,
			player_config,
		)
		id_counter += 1

	var dummy_def: UnitData = DataLibrary.get_training_dummy()
	for coord: Vector2i in session.dummy_coords:
		BoardFactory.place_configured_unit(
			board,
			id_counter,
			dummy_def,
			GameEnums.Team.ENEMY,
			coord,
			{},
		)
		id_counter += 1

	if session.infinite_player_ap:
		for unit: UnitState in board.units:
			if unit.team == GameEnums.Team.PLAYER:
				unit.ability.max_points = 99
				unit.ability.points_left = 99
				unit.movement.max_points = 99
				unit.movement.points_left = 99

	return board
