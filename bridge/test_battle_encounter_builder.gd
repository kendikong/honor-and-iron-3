class_name TestBattleEncounterBuilder
extends RefCounted

## Builds the 10×10 grass-only training arena and configured BoardState.


static func build_grass_grid(size: Vector2i = TestBattleSession.MAP_SIZE) -> PlayerGrid:
	return PlayerGrid.new(size.x, size.y, TileId.Type.GRASS)


static func _collect_placements(session: TestBattleSession) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var player_def: UnitData = DataLibrary.get_unit(session.player_class_id)
	if player_def == null:
		player_def = DataLibrary.get_unit(TestBattleSession.DEFAULT_PLAYER_CLASS)
	if player_def == null:
		return out
	var player_config: Dictionary = session.player_unit_config()
	out.append({
		"unit": player_def,
		"coord": TestBattleSession.DEFAULT_PLAYER_CELL,
		"team": GameEnums.Team.PLAYER,
		"config": player_config,
	})
	for coord: Vector2i in session.extra_player_coords:
		out.append({
			"unit": player_def,
			"coord": coord,
			"team": GameEnums.Team.PLAYER,
			"config": player_config,
		})
	var dummy_def: UnitData = DataLibrary.get_training_dummy()
	if dummy_def == null:
		return out
	for coord: Vector2i in session.dummy_coords:
		out.append({
			"unit": dummy_def,
			"coord": coord,
			"team": GameEnums.Team.ENEMY,
			"config": {},
		})
	return out


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

	for placement: Dictionary in _collect_placements(session):
		var spawn := UnitPlacement.new()
		spawn.unit = placement["unit"]
		spawn.coord = placement["coord"]
		if int(placement["team"]) == GameEnums.Team.PLAYER:
			encounter.player_spawns.append(spawn)
		else:
			encounter.enemy_spawns.append(spawn)

	return encounter


static func build_board(session: TestBattleSession) -> BoardState:
	var plain: TerrainData = DataLibrary.get_terrain(&"plain")
	var board: BoardState = BoardFactory.build_empty(TestBattleSession.MAP_SIZE, plain)
	var id_counter: int = 1
	for placement: Dictionary in _collect_placements(session):
		BoardFactory.place_configured_unit(
			board,
			id_counter,
			placement["unit"],
			int(placement["team"]),
			placement["coord"],
			placement["config"],
		)
		id_counter += 1
	_apply_training_modifiers(board, session)
	return board


static func _apply_training_modifiers(board: BoardState, session: TestBattleSession) -> void:
	if not session.infinite_player_ap:
		return
	for unit: UnitState in board.units:
		if unit.team != GameEnums.Team.PLAYER:
			continue
		unit.ability.max_points = 99
		unit.ability.points_left = 99
		unit.movement.max_points = 99
		unit.movement.points_left = 99
		unit.passive_flags["training_unlimited_actions"] = true


static func maintain_training_dummies(board: BoardState, session: TestBattleSession) -> void:
	if board == null or not session.unkillable_dummies:
		return
	var dummy_def: UnitData = DataLibrary.get_training_dummy()
	var covered: Dictionary = {}
	for unit: UnitState in board.units:
		if unit.definition == null or unit.definition.id != &"training_dummy":
			continue
		covered[unit.position] = true
		unit.health.current_hp = unit.health.max_hp
	var next_id: int = _max_unit_id(board) + 1
	for coord: Vector2i in session.dummy_coords:
		if covered.has(coord):
			continue
		BoardFactory.place_configured_unit(
			board,
			next_id,
			dummy_def,
			GameEnums.Team.ENEMY,
			coord,
			{},
		)
		next_id += 1


static func _max_unit_id(board: BoardState) -> int:
	var max_id: int = 0
	for unit: UnitState in board.units:
		max_id = maxi(max_id, unit.id)
	return max_id
