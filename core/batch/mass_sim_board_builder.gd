class_name MassSimBoardBuilder
extends RefCounted

## Procedural skirmish boards for mass simulation — varied map tags per bible L6.


static func build_skirmish(map_seed: int) -> Dictionary:
	var grid_size := Vector2i(24, 16)
	var grass: TerrainData = DataLibrary.get_terrain("grass")
	var water: TerrainData = DataLibrary.get_terrain("water")
	var board: BoardState = BoardFactory.build_empty(grid_size, grass)
	var layout_id: int = absi(map_seed) % 3
	var tags: Array[String] = ["grass"]
	match layout_id:
		0:
			tags.append("open")
		1:
			tags.append("narrow")
			_apply_narrow_walls(board, water, map_seed)
		2:
			tags.append("hazard")
			_apply_hazard_patches(board, water, map_seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var player_y: int = 6 + rng.randi() % 5
	var enemy_y: int = 6 + rng.randi() % 5
	var player_spawn := Vector2i(2, player_y)
	var enemy_spawn := Vector2i(grid_size.x - 3, enemy_y)
	var player_quadrant: String = _quadrant_name(player_spawn, grid_size)
	return {
		"board": board,
		"map_tags": tags,
		"layout_id": ["open", "narrow", "hazard"][layout_id],
		"player_spawn": player_spawn,
		"enemy_spawn": enemy_spawn,
		"player_quadrant": player_quadrant,
		"enemy_quadrant": _quadrant_name(enemy_spawn, grid_size),
	}


static func _apply_narrow_walls(board: BoardState, water: TerrainData, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed ^ 0x9E37
	for y: int in range(board.grid_size.y):
		if rng.randf() < 0.35:
			for x: int in [3, board.grid_size.x - 4]:
				var coord := Vector2i(x, y)
				var tile: TileState = board.get_tile(coord)
				if tile != null and tile.occupant_id < 0:
					tile.definition = water


static func _apply_hazard_patches(board: BoardState, water: TerrainData, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed ^ 0xBEEF
	for _i: int in range(12):
		var cx: int = 4 + rng.randi() % maxi(board.grid_size.x - 8, 1)
		var cy: int = 2 + rng.randi() % maxi(board.grid_size.y - 4, 1)
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var coord := Vector2i(cx + dx, cy + dy)
				var tile: TileState = board.get_tile(coord)
				if tile != null and tile.occupant_id < 0 and rng.randf() < 0.55:
					tile.definition = water


static func _quadrant_name(cell: Vector2i, grid_size: Vector2i) -> String:
	var north: bool = cell.y < grid_size.y / 2
	var west: bool = cell.x < grid_size.x / 2
	if north and west:
		return "northwest"
	if north:
		return "northeast"
	if west:
		return "southwest"
	return "southeast"
