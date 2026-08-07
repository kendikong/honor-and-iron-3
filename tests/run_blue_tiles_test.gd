extends SceneTree

## Minimal blue tiles test — standalone to avoid hang issues.
## Run: godot --headless --path . --script res://tests/run_blue_tiles_test.gd

func _initialize() -> void:
	var failures: Array[String] = []
	
	# Build minimal board
	var board := BoardState.new()
	board.grid_size = Vector2i(6, 6)
	var terrain := TerrainData.new()
	terrain.id = &"plain"
	for y in range(6):
		for x in range(6):
			board.tiles[Vector2i(x, y)] = TileState.create(Vector2i(x, y), terrain)
	
	var def: UnitData = DataLibrary.get_unit(&"knight")
	var unit := UnitState.create(1, def, GameEnums.Team.PLAYER, Vector2i(2, 2), {
		"active_abilities": DataLibrary.build_training_abilities(def),
	})
	board.units.append(unit)
	GridSystem.set_occupant(board, Vector2i(2, 2), 1)
	unit.movement.points_left = 3
	
	# Test the exact source used by TacticalPlanningOverlay for blue tiles.
	var reachable: Array[Vector2i] = MovementSystem.get_reachable_tiles(
		board, unit.position, unit.movement.points_left, unit.definition.movement_type,
	)
	if not reachable.has(Vector2i(3, 2)):
		failures.append("blue/adjacent: (3,2) is missing from reachable tiles")
	if not reachable.has(Vector2i(4, 2)):
		failures.append("blue/two_tiles: (4,2) is missing from reachable tiles")
	if reachable.has(Vector2i(5, 0)):
		failures.append("blue/beyond_budget: (5,0) should not be reachable with 3 MP")
	
	if failures.is_empty():
		print("[PASS] BlueTiles: all checks passed")
		quit(0)
	else:
		for f in failures:
			printerr("[FAIL] %s" % f)
		quit(1)