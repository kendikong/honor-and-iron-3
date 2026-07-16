class_name BridgeTestRunner
extends RefCounted

## Headless smoke tests for bridge layer (Phase 1 expands coverage).

static func run_all() -> Dictionary:
	var failures: Array[String] = []
	_test_skirmish_preset(failures)
	_test_tile_id_to_terrain(failures)
	_test_walkability_baker(failures)
	_test_encounter_blocked_override(failures)
	_test_encounter_builder(failures)
	_test_headless_sim_pipeline(failures)
	return {"passed": failures.is_empty(), "failures": failures}


static func _test_skirmish_preset(failures: Array[String]) -> void:
	var idx: int = SkirmishGenerator.preset_index_for_size(Vector2i(32, 16))
	if idx < 0:
		failures.append("Skirmish preset 32x16 not registered")


static func _test_tile_id_to_terrain(failures: Array[String]) -> void:
	var grass: TerrainData = TileIdToTerrain.terrain_for_tile_id(TileId.Type.GRASS)
	if grass == null or grass.blocks_movement:
		failures.append("GRASS should map to walkable plain")

	var dirt: TerrainData = TileIdToTerrain.terrain_for_tile_id(TileId.Type.DIRT)
	if dirt == null or dirt.blocks_movement:
		failures.append("DIRT should map to walkable plain")

	var tree: TerrainData = TileIdToTerrain.terrain_for_tile_id(TileId.Type.TREE)
	if tree == null or tree.blocks_movement:
		failures.append("TREE anchor should map to walkable plain")

	for tile_id: int in [TileId.Type.WATER, TileId.Type.ROCK, TileId.Type.RUIN]:
		var terrain: TerrainData = TileIdToTerrain.terrain_for_tile_id(tile_id)
		if terrain == null or not terrain.blocks_movement:
			failures.append(
				"%s should map to blocking terrain" % TileId.type_name(tile_id),
			)


static func _test_walkability_baker(failures: Array[String]) -> void:
	var grid := PlayerGrid.new(4, 4)
	grid.set_cell(Vector2i(0, 0), TileId.Type.GRASS)
	grid.set_cell(Vector2i(1, 0), TileId.Type.DIRT)
	grid.set_cell(Vector2i(2, 0), TileId.Type.WATER)
	grid.set_cell(Vector2i(3, 0), TileId.Type.ROCK)
	grid.set_cell(Vector2i(0, 1), TileId.Type.RUIN)
	grid.set_cell(Vector2i(1, 1), TileId.Type.TREE)

	var blocked: Dictionary = WalkabilityBaker.bake(grid, null, null, null, null)
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var cell := Vector2i(x, y)
			var expect_blocked: bool = not Walkability.is_walkable(
				grid, cell, null, null, null, null,
			)
			if WalkabilityBaker.is_cell_blocked(blocked, cell) != expect_blocked:
				failures.append("WalkabilityBaker mismatch at %s" % cell)


static func _test_encounter_blocked_override(failures: Array[String]) -> void:
	var grid := PlayerGrid.new(3, 3)
	grid.set_cell(Vector2i(1, 1), TileId.Type.GRASS)
	var blocked: Dictionary = {Vector2i(1, 1): true}
	var encounter: EncounterData = EncounterBuilder.build_from_player_grid(
		grid, blocked, [], [],
	)
	var terrain: TerrainData = encounter.tile_terrains.get(Vector2i(1, 1))
	var wall: TerrainData = DataLibrary.get_terrain(&"wall")
	if terrain != wall:
		failures.append("EncounterBuilder should upgrade baker-blocked grass to wall")


static func _test_encounter_builder(failures: Array[String]) -> void:
	var config := SkirmishGenerator.SkirmishConfig.new()
	config.size_preset = Vector2i(16, 8)
	config.map_seed = 12345
	var skirmish: SkirmishGenerator.SkirmishResult = SkirmishGenerator.generate(config)
	if skirmish.grid.width != 16 or skirmish.grid.height != 8:
		failures.append("SkirmishGenerator size mismatch")
	var blocked: Dictionary = WalkabilityBaker.bake(skirmish.grid, null, null, null, null)
	var encounter: EncounterData = EncounterBuilder.build_from_player_grid(
		skirmish.grid, blocked, [], [],
	)
	if encounter.grid_size != Vector2i(16, 8):
		failures.append("EncounterBuilder grid_size mismatch")
	if encounter.tile_terrains.is_empty():
		failures.append("EncounterBuilder produced no tile_terrains")


static func _test_headless_sim_pipeline(failures: Array[String]) -> void:
	var config := SkirmishGenerator.SkirmishConfig.new()
	config.size_preset = Vector2i(16, 8)
	config.map_seed = 12345
	var skirmish: SkirmishGenerator.SkirmishResult = SkirmishGenerator.generate(config)
	var blocked: Dictionary = WalkabilityBaker.bake(skirmish.grid, null, null, null, null)

	var player_spawn: Vector2i = Walkability.find_spawn_cell(
		skirmish.grid, Vector2i(2, 4), null, null, null, null,
	)
	var enemy_spawn: Vector2i = Walkability.find_spawn_cell(
		skirmish.grid, Vector2i(13, 4), null, null, null, null,
	)
	if not Walkability.is_walkable(skirmish.grid, player_spawn, null, null, null, null):
		failures.append("headless sim pipeline: player spawn not walkable")
	if not Walkability.is_walkable(skirmish.grid, enemy_spawn, null, null, null, null):
		failures.append("headless sim pipeline: enemy spawn not walkable")

	var knight: UnitData = DataLibrary.get_unit(&"knight")
	var hatchling: UnitData = DataLibrary.get_unit(&"hatchling")
	if knight == null or hatchling == null:
		failures.append("headless sim pipeline: DataLibrary missing knight or hatchling")
		return

	var player_placements: Array[UnitPlacement] = []
	var player_placement := UnitPlacement.new()
	player_placement.unit = knight
	player_placement.coord = player_spawn
	player_placements.append(player_placement)

	var enemy_placements: Array[UnitPlacement] = []
	var enemy_placement := UnitPlacement.new()
	enemy_placement.unit = hatchling
	enemy_placement.coord = enemy_spawn
	enemy_placements.append(enemy_placement)

	var encounter: EncounterData = EncounterBuilder.build_from_player_grid(
		skirmish.grid, blocked, player_placements, enemy_placements,
	)
	var board: BoardState = BoardFactory.build_from_encounter(encounter)
	board.intents = EnemyPlanner.plan(board)

	var plan := Timeline.new()
	var result_a := Simulator.simulate(board, plan)
	var result_b := Simulator.simulate(board, plan)

	if result_a.final_state.units.size() < 2:
		failures.append("headless sim pipeline: expected at least 2 units on board")
	if _hash_board(result_a.final_state) != _hash_board(result_b.final_state):
		failures.append("headless sim pipeline: board state not deterministic")
	if _hash_events(result_a.events) != _hash_events(result_b.events):
		failures.append("headless sim pipeline: event log not deterministic")


static func _hash_board(board: BoardState) -> String:
	var ids: Array[int] = []
	for unit in board.units:
		ids.append(unit.id)
	ids.sort()
	var parts: Array[String] = ["turn=%d" % board.turn_index]
	for id: int in ids:
		var unit := board.get_unit_by_id(id)
		parts.append(
			"u%d[pos=%s,hp=%d,team=%d]" % [unit.id, unit.position, unit.health.current_hp, unit.team],
		)
	return ";".join(parts)


static func _hash_events(events: Array[SimEvent]) -> String:
	var lines: Array[String] = []
	for event in events:
		lines.append(event.describe())
	return "\n".join(lines)
