class_name BoardFactory
extends RefCounted

## Purpose: Creates BoardState instances from definitions (EncounterData) or
## custom parameters. Isolates board setup from the presentation layer.

static func build_from_encounter(data: EncounterData, player_assignments: Dictionary = {}) -> BoardState:
	var board := BoardState.new()
	board.grid_size = data.grid_size
	
	# 1. Base terrain
	for y in range(data.grid_size.y):
		for x in range(data.grid_size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, data.default_terrain)
			
	# 2. Wall overrides (legacy support)
	for coord in data.wall_coords:
		var tile = board.get_tile(coord)
		if tile != null:
			tile.definition = data.wall_terrain
			
	# 3. Tile terrain overrides (new system)
	for coord in data.tile_terrains:
		var tile = board.get_tile(coord)
		if tile != null:
			tile.definition = data.tile_terrains[coord]
			
	# 4. Spawns (Player) â€” default slot index â†’ player id (P1..P4 co-op)
	var id_counter = 1
	for i: int in range(data.player_spawns.size()):
		var p: UnitPlacement = data.player_spawns[i]
		var slot: int = i + 1
		var pid: int = int(player_assignments.get(slot, slot))
		_place_placement(board, id_counter, p, GameEnums.Team.PLAYER, pid)
		id_counter += 1
		
	# 5. Spawns (Enemy)
	for e: UnitPlacement in data.enemy_spawns:
		_place_placement(board, id_counter, e, GameEnums.Team.ENEMY)
		id_counter += 1
		
	return board


static func _place_placement(
	target_board: BoardState,
	unit_id: int,
	placement: UnitPlacement,
	team: GameEnums.Team,
	controlling_player_id: int = 1,
) -> UnitState:
	if placement == null or placement.unit == null:
		return null
	if not placement.spawn_config.is_empty():
		place_configured_unit(
			target_board, unit_id, placement.unit, team, placement.coord,
			placement.spawn_config, controlling_player_id,
		)
		return target_board.get_unit_by_id(unit_id)
	return _place(target_board, unit_id, placement.unit, team, placement.coord, controlling_player_id)

static func _place(target_board: BoardState, unit_id: int, def: UnitData, team: GameEnums.Team, coord: Vector2i, controlling_player_id: int = 1) -> UnitState:
	if def == null: return null
	var unit := UnitState.create(unit_id, def, team, coord)
	unit.controlling_player_id = controlling_player_id
	if team == GameEnums.Team.PLAYER:
		unit.facing = GameEnums.Facing.EAST
	elif team == GameEnums.Team.ENEMY:
		unit.facing = GameEnums.Facing.WEST
	target_board.units.append(unit)
	
	var tile := target_board.get_tile(coord)
	if tile != null:
		tile.occupant_id = unit_id
	return unit

static func build_empty(grid_size: Vector2i, default_terrain: TerrainData) -> BoardState:
	var board := BoardState.new()
	board.grid_size = grid_size
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, default_terrain)
	return board

static func place_unit(board: BoardState, unit_id: int, def: UnitData, team: GameEnums.Team, coord: Vector2i, controlling_player_id: int = 1) -> void:
	_place(board, unit_id, def, team, coord, controlling_player_id)

static func place_configured_unit(board: BoardState, unit_id: int, def: UnitData, team: GameEnums.Team, coord: Vector2i, config: Dictionary, controlling_player_id: int = 1) -> void:
	if def == null: return
	var unit := UnitState.create(unit_id, def, team, coord, config)
	unit.controlling_player_id = controlling_player_id
	if team == GameEnums.Team.PLAYER:
		unit.facing = GameEnums.Facing.EAST
	elif team == GameEnums.Team.ENEMY:
		unit.facing = GameEnums.Facing.WEST
	board.units.append(unit)
	
	var tile := board.get_tile(coord)
	if tile != null:
		tile.occupant_id = unit_id
