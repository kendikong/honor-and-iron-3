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
	_test_spawn_placer_bands(failures)
	_test_skirmish_all_presets(failures)
	_test_spawn_validation_10x7(failures)
	_test_headless_sim_pipeline(failures)
	_test_generate_encounter_board(failures)
	_test_combat_intent_state(failures)
	_test_combat_planning_preview(failures)
	_test_combat_ui_formatters(failures)
	_test_battle_arena(failures)
	PlanningInputTest.run_all(failures)
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


static func _test_spawn_placer_bands(failures: Array[String]) -> void:
	var config := SkirmishGenerator.SkirmishConfig.new()
	config.size_preset = Vector2i(32, 16)
	config.map_seed = 42
	var skirmish: SkirmishGenerator.SkirmishResult = SkirmishGenerator.generate(config)
	if skirmish.player_spawns.size() != SpawnPlacer.MVP_PLAYER_COUNT:
		failures.append("SpawnPlacer: expected %d player spawns, got %d" % [
			SpawnPlacer.MVP_PLAYER_COUNT, skirmish.player_spawns.size(),
		])
	if skirmish.enemy_spawns.size() != SpawnPlacer.MVP_ENEMY_COUNT:
		failures.append("SpawnPlacer: expected %d enemy spawns, got %d" % [
			SpawnPlacer.MVP_ENEMY_COUNT, skirmish.enemy_spawns.size(),
		])
	for placement: UnitPlacement in skirmish.player_spawns:
		if not SpawnPlacer.is_in_player_spawn_zone(
			placement.coord, skirmish.grid.width, skirmish.grid.height,
		):
			failures.append("SpawnPlacer: player spawn %s outside center-left zone" % placement.coord)
	for placement: UnitPlacement in skirmish.enemy_spawns:
		if not SpawnPlacer.is_in_enemy_spawn_zone(
			placement.coord, skirmish.grid.width, skirmish.grid.height,
		):
			failures.append("SpawnPlacer: enemy spawn %s outside center-right zone" % placement.coord)


static func _test_skirmish_all_presets(failures: Array[String]) -> void:
	for preset: Vector2i in TacticalConstants.SKIRMISH_PRESETS:
		var config := SkirmishGenerator.SkirmishConfig.new()
		config.size_preset = preset
		config.map_seed = 1
		var skirmish: SkirmishGenerator.SkirmishResult = SkirmishGenerator.generate(config)
		if skirmish.grid.width != preset.x or skirmish.grid.height != preset.y:
			failures.append("SkirmishGenerator preset %s produced %dx%d" % [
				preset, skirmish.grid.width, skirmish.grid.height,
			])
		if skirmish.player_spawns.is_empty() or skirmish.enemy_spawns.is_empty():
			failures.append("SkirmishGenerator preset %s produced empty spawns" % preset)


const _PHASE2_TEST_SEEDS: Array[int] = [
	1, 42, 123, 999, 12345, 54321, 777, 2024, 65536, 314159,
]


static func _test_spawn_validation_10x7(failures: Array[String]) -> void:
	for preset: Vector2i in TacticalConstants.SKIRMISH_PRESETS:
		for map_seed: int in _PHASE2_TEST_SEEDS:
			var config := SkirmishGenerator.SkirmishConfig.new()
			config.size_preset = preset
			config.map_seed = map_seed
			var skirmish: SkirmishGenerator.SkirmishResult = SkirmishGenerator.generate(config)
			if skirmish.player_spawns.size() != SpawnPlacer.MVP_PLAYER_COUNT:
				failures.append(
					"spawn validation: seed=%d preset=%s missing player spawns" % [map_seed, preset],
				)
				continue
			if skirmish.enemy_spawns.size() != SpawnPlacer.MVP_ENEMY_COUNT:
				failures.append(
					"spawn validation: seed=%d preset=%s missing enemy spawns" % [map_seed, preset],
				)
				continue
			var occupied: Dictionary = {}
			for placement: UnitPlacement in skirmish.player_spawns:
				if not Walkability.is_walkable(
					skirmish.grid, placement.coord, null, null, null, null,
				):
					failures.append(
						"spawn validation: player %s not walkable (seed=%d preset=%s)" % [
							placement.coord, map_seed, preset,
						],
					)
				if not SpawnPlacer.is_in_player_spawn_zone(
					placement.coord, skirmish.grid.width, skirmish.grid.height,
				):
					failures.append(
						"spawn validation: player %s outside center-left zone (seed=%d)" % [
							placement.coord, map_seed,
						],
					)
				if occupied.has(placement.coord):
					failures.append("spawn validation: duplicate spawn at %s" % placement.coord)
				occupied[placement.coord] = true
			for placement: UnitPlacement in skirmish.enemy_spawns:
				if not Walkability.is_walkable(
					skirmish.grid, placement.coord, null, null, null, null,
				):
					failures.append(
						"spawn validation: enemy %s not walkable (seed=%d preset=%s)" % [
							placement.coord, map_seed, preset,
						],
					)
				if not SpawnPlacer.is_in_enemy_spawn_zone(
					placement.coord, skirmish.grid.width, skirmish.grid.height,
				):
					failures.append(
						"spawn validation: enemy %s outside center-right zone (seed=%d)" % [
							placement.coord, map_seed,
						],
					)
				if occupied.has(placement.coord):
					failures.append("spawn validation: duplicate spawn at %s" % placement.coord)
				occupied[placement.coord] = true


static func _test_headless_sim_pipeline(failures: Array[String]) -> void:
	var config := SkirmishGenerator.SkirmishConfig.new()
	config.size_preset = Vector2i(16, 8)
	config.map_seed = 12345
	var skirmish: SkirmishGenerator.SkirmishResult = SkirmishGenerator.generate(config)

	if skirmish.player_spawns.is_empty() or skirmish.enemy_spawns.is_empty():
		failures.append("headless sim pipeline: SkirmishGenerator returned empty spawns")
		return

	var encounter: EncounterData = EncounterBuilder.build_from_player_grid(
		skirmish.grid,
		skirmish.blocked_cells,
		skirmish.player_spawns,
		skirmish.enemy_spawns,
	)
	var board: BoardState = BoardFactory.build_from_encounter(encounter)
	board.intents = EnemyPlanner.plan(board)

	var plan := Timeline.new()
	var board_hash_before: String = _hash_board(board)
	var result_a := Simulator.simulate(board, plan)
	var result_b := Simulator.simulate(board, plan)

	if _hash_board(board) != board_hash_before:
		failures.append("headless sim pipeline: Simulator mutated input board")

	if result_a.final_state.units.size() < 2:
		failures.append("headless sim pipeline: expected at least 2 units on board")
	if _hash_board(result_a.final_state) != _hash_board(result_b.final_state):
		failures.append("headless sim pipeline: board state not deterministic")
	if _hash_events(result_a.events) != _hash_events(result_b.events):
		failures.append("headless sim pipeline: event log not deterministic")


static func _test_generate_encounter_board(failures: Array[String]) -> void:
	var config := SkirmishGenerator.SkirmishConfig.new()
	config.size_preset = Vector2i(24, 12)
	config.map_seed = 4242
	var encounter: EncounterData = SkirmishGenerator.generate_encounter(config)
	var board: BoardState = BoardFactory.build_from_encounter(encounter)
	if board.units.size() < SpawnPlacer.MVP_PLAYER_COUNT + SpawnPlacer.MVP_ENEMY_COUNT:
		failures.append("generate_encounter board missing units")
	if not board.has_living_team(GameEnums.Team.PLAYER):
		failures.append("generate_encounter board has no living player team")
	if not board.has_living_team(GameEnums.Team.ENEMY):
		failures.append("generate_encounter board has no living enemy team")


static func _test_combat_intent_state(failures: Array[String]) -> void:
	var state := CombatIntentState.new()
	var board := BoardState.new()
	board.grid_size = Vector2i(5, 5)
	var player := UnitState.new()
	player.id = 1
	player.team = GameEnums.Team.PLAYER
	player.position = Vector2i(1, 1)
	var enemy := UnitState.new()
	enemy.id = 2
	enemy.team = GameEnums.Team.ENEMY
	enemy.position = Vector2i(3, 3)
	board.units = [player, enemy]
	var intent := Intent.new()
	intent.enemy_id = 2
	var action := TimelineAction.new()
	action.type = GameEnums.ActionType.ABILITY
	action.target_unit_id = 1
	intent.actions = [action]
	board.intents = [intent]
	state.set_board(board)
	state.set_selection(1)
	if not state.intent_units.has(2):
		failures.append("CombatIntentState: enemy targeting selected player not visible")
	state.set_selection(-1)
	state.set_timeline_hover(2)
	if not state.intent_units.has(2):
		failures.append("CombatIntentState: timeline hover should show enemy intent")
	state.clear_timeline_hover()
	if state.intent_units.has(2):
		failures.append("CombatIntentState: clear timeline hover should remove highlight when nothing else selected")


static func _test_combat_planning_preview(failures: Array[String]) -> void:
	var preview := CombatPlanningPreview.new()
	var paths: Dictionary = {}
	var splits: Dictionary = {}
	var pushes: Dictionary = {}
	var move := SimEvent.new()
	move.type = GameEnums.SimEventType.UNIT_MOVED
	move.data = {"actor": 1, "path": [Vector2i(2, 1), Vector2i(3, 1)]}
	var push := SimEvent.new()
	push.type = GameEnums.SimEventType.UNIT_PUSHED
	push.data = {"unit": 2, "to": Vector2i(4, 1)}
	CombatPlanningPreview.build_preview_paths([move, push], null, paths, splits, pushes)
	if paths.is_empty():
		failures.append("CombatPlanningPreview: paths empty without director (expected no crash)")
	var route: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	var cells: Array[Vector2i] = CombatPlanningPreview.destination_cells_from_route(
		route, Vector2i(0, 0), Vector2i(3, 0),
	)
	if cells.size() != 3 or cells[2] != Vector2i(3, 0):
		failures.append("CombatPlanningPreview: destination_cells_from_route full leg mismatch")
	preview.preview_paths[1] = route
	preview.preview_splits[1] = route.size()
	var director := CombatDirector.new()
	var board := BoardState.new()
	var leg: Array = CombatPlanningPreview.pending_move_route_leg(1, preview, director, board)
	var anim: Array[Vector2i] = CombatPlanningPreview.planning_animation_cells(
		1, preview, Vector2i(0, 0), Vector2i(3, 0), director, board,
	)
	if leg.size() != 4 or anim.size() != 3 or anim[0] != Vector2i(1, 0):
		failures.append("CombatPlanningPreview: pending_move_route_leg / planning_animation_cells mismatch")
	var action := TimelineAction.make_ability(1, AbilityData.new(), Vector2i(3, 0), -1)
	var committed_leg: Array = CombatPlanningPreview.committed_action_route_leg(
		1, preview, action, Vector2i(0, 0),
	)
	if committed_leg.size() != 4 or committed_leg[2] != Vector2i(2, 0):
		failures.append("CombatPlanningPreview: committed_action_route_leg should slice to action target")
	preview.preview_post_splits[1] = 3
	var capped_leg: Array = CombatPlanningPreview.committed_action_route_leg(
		1, preview, action, Vector2i(0, 0),
	)
	if capped_leg.size() != 3 or capped_leg[2] != Vector2i(2, 0):
		failures.append("CombatPlanningPreview: committed_action_route_leg should cap before post-move split")
	var director_stub := CombatDirector.new()
	var board_stub := BoardState.new()
	board_stub.grid_size = Vector2i(8, 8)
	director_stub.board = board_stub
	director_stub.base_board = board_stub
	director_stub.plan_action = Timeline.new()
	var trample := TimelineAction.make_ability(1, AbilityData.new(), Vector2i(2, 0), -1)
	director_stub.plan_action.entries.append(trample)
	preview.preview_post_splits[1] = 3
	var post_leg: Array = CombatPlanningPreview.move_route_leg_from_preview(
		1, preview, director_stub, board_stub, GameEnums.MoveTiming.POST_ACTION, true,
	)
	if post_leg.size() != 2 or post_leg[0] != Vector2i(2, 0) or post_leg[1] != Vector2i(3, 0):
		failures.append("CombatPlanningPreview: post move leg should start at action end")
	var l_path: Array = [
		Vector2i(0, 0), Vector2i(0, 1), Vector2i(2, 0), Vector2i(3, 0),
	]
	preview.preview_paths[1] = l_path
	preview.preview_post_splits[1] = 2
	var stale_post: Array = CombatPlanningPreview.move_route_leg_from_preview(
		1, preview, director_stub, board_stub, GameEnums.MoveTiming.POST_ACTION, true,
	)
	if stale_post.size() != 2 or stale_post[0] != Vector2i(2, 0) or stale_post[1] != Vector2i(3, 0):
		failures.append("CombatPlanningPreview: post move leg must ignore stale post_split vs action end")
	var intent_preview := CombatPlanningPreview.new()
	intent_preview.preview_paths[1] = l_path.duplicate()
	var trample_action := TimelineAction.make_ability(1, AbilityData.new(), Vector2i(2, 0), -1)
	intent_preview.ensure_movement_intent_from_actions([trample_action], board_stub)
	var kept: Array = intent_preview.preview_paths.get(1, [])
	if kept.size() != 4:
		failures.append("CombatPlanningPreview: ensure_movement_intent must not shorten sim L-path")
	var plan_unit := UnitState.new()
	plan_unit.id = 1
	plan_unit.team = GameEnums.Team.PLAYER
	plan_unit.position = Vector2i(0, 0)
	board_stub.units = [plan_unit]
	var plan := Timeline.new()
	var pre_move := TimelineAction.make_move(
		1, Vector2i(1, 0), -1, [], GameEnums.MoveTiming.PRE_ACTION,
	)
	plan.entries.append(pre_move)
	var origin: Vector2i = CombatUiFormatters.plan_action_origin_cell(board_stub, plan, pre_move)
	if origin != Vector2i(0, 0):
		failures.append("CombatUiFormatters: pre-move origin should be turn-start cell")
	var post_move := TimelineAction.make_move(
		1, Vector2i(5, 0), -1, [], GameEnums.MoveTiming.POST_ACTION,
	)
	plan.entries.append(post_move)
	var post_origin: Vector2i = CombatUiFormatters.plan_action_origin_cell(board_stub, plan, post_move)
	if post_origin != Vector2i(1, 0):
		failures.append("CombatUiFormatters: post-move origin should follow prior plan steps")
	var move_label: String = CombatUiFormatters.action_symbol_text(board_stub, post_move, plan_unit, plan)
	if move_label.find("(1,0)→(5,0)") < 0:
		failures.append("CombatUiFormatters: move label should show origin and destination")
	var ghost_move := TimelineAction.make_move(
		1, Vector2i(5, 6), -1, [], GameEnums.MoveTiming.POST_ACTION,
	)
	var ghost_unit: UnitState = plan_unit.clone()
	ghost_unit.position = Vector2i(1, 0)
	var ghost_label: String = CombatUiFormatters.action_symbol_text(
		board_stub, ghost_move, ghost_unit, plan,
	)
	if ghost_label.find("(1,0)→(5,6)") < 0:
		failures.append("CombatUiFormatters: ghost post-move label should show origin and destination")
	var move_only := BoardState.new()
	move_only.grid_size = Vector2i(8, 8)
	var turn_start := UnitState.new()
	turn_start.id = 1
	turn_start.team = GameEnums.Team.PLAYER
	turn_start.position = Vector2i(0, 0)
	move_only.units = [turn_start]
	plan_unit.position = Vector2i(2, 0)
	plan_unit.turn_action_used = true
	board_stub.units = [plan_unit]
	director_stub.projected_state = board_stub
	director_stub.plan_post_move = Timeline.new()
	var post_timing_origin: Vector2i = CombatPlanningPreview.planning_move_origin_cell(
		director_stub, move_only, 1,
	)
	if post_timing_origin != Vector2i(2, 0):
		failures.append(
			"CombatPlanningPreview: post-move origin must use projection, not move-only board",
		)
	director_stub.plan_post_move = Timeline.new()
	director_stub.plan_pre_move = Timeline.new()
	director_stub.plan_pre_move.entries.append(
		TimelineAction.make_move(1, Vector2i(1, 0), -1, [], GameEnums.MoveTiming.PRE_ACTION),
	)
	director_stub.plan_action = Timeline.new()
	director_stub.plan_action.entries.append(
		TimelineAction.make_ability(1, AbilityData.new(), Vector2i(2, 0), -1),
	)
	var idle_origin: Vector2i = CombatPlanningPreview.planning_move_origin_cell(
		director_stub, move_only, 1,
	)
	if idle_origin != Vector2i(2, 0):
		failures.append(
			"CombatPlanningPreview: idle move origin should fall back to projected stand",
		)
	preview.preview_paths[1] = [Vector2i(0, 0), Vector2i(2, 0)]
	var post_action := TimelineAction.make_move(
		1, Vector2i(7, 2), -1, [Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2)],
		GameEnums.MoveTiming.POST_ACTION,
	)
	director_stub.plan_post_move = Timeline.new()
	director_stub.plan_post_move.entries.append(post_action)
	var committed_post: Array = CombatPlanningPreview.committed_move_route_leg(
		1, preview, director_stub, board_stub, GameEnums.MoveTiming.POST_ACTION,
	)
	if committed_post.size() < 2 or committed_post[0] != Vector2i(2, 0) or committed_post.back() != Vector2i(7, 2):
		failures.append(
			"CombatPlanningPreview: committed_move_route_leg post should fall back to plan geometry",
		)
	plan_unit.position = Vector2i(0, 0)
	board_stub.units = [plan_unit]
	director_stub.plan_pre_move = Timeline.new()
	director_stub.plan_pre_move.entries.append(
		TimelineAction.make_move(1, Vector2i(1, 0), -1, [], GameEnums.MoveTiming.PRE_ACTION),
	)
	director_stub.plan_action = Timeline.new()
	var trample_after_pre := TimelineAction.make_ability(1, AbilityData.new(), Vector2i(2, 0), -1)
	director_stub.plan_action.entries.append(trample_after_pre)
	preview.preview_paths[1] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var committed_pre: Array = CombatPlanningPreview.committed_move_route_leg(
		1, preview, director_stub, board_stub, GameEnums.MoveTiming.PRE_ACTION,
	)
	if committed_pre.size() != 2 or committed_pre[0] != Vector2i(0, 0) or committed_pre[1] != Vector2i(1, 0):
		failures.append(
			"CombatPlanningPreview: committed_move_route_leg pre should slice turn-start to pre target",
		)
	director_stub.projected_state = board_stub
	plan_unit.position = Vector2i(1, 0)
	board_stub.units = [plan_unit]
	var realized_pre: Array = CombatPlanningPreview.committed_move_route_leg(
		1, preview, director_stub, board_stub, GameEnums.MoveTiming.PRE_ACTION,
	)
	if not realized_pre.is_empty():
		failures.append(
			"CombatPlanningPreview: committed pre leg must hide when unit already at move target",
		)
	preview.preview_paths[1] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	plan_unit.position = Vector2i(2, 0)
	board_stub.units = [plan_unit]
	director_stub.projected_state = board_stub
	var l_pre := TimelineAction.make_move(
		1, Vector2i(2, 0), -1, [Vector2i(1, 0)], GameEnums.MoveTiming.PRE_ACTION,
	)
	director_stub.plan_pre_move.entries[0] = l_pre
	var realized_l_pre: Array = CombatPlanningPreview.committed_move_route_leg(
		1, preview, director_stub, board_stub, GameEnums.MoveTiming.PRE_ACTION,
	)
	if not realized_l_pre.is_empty():
		failures.append(
			"CombatPlanningPreview: L-shaped pre leg must hide when unit already at target",
		)
	preview.preview_paths[1] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 0)]
	plan_unit.position = Vector2i(0, 0)
	board_stub.units = [plan_unit]
	director_stub.projected_state = board_stub
	var loop_move := TimelineAction.make_move(
		1, Vector2i(0, 0), -1, [Vector2i(1, 0)], GameEnums.MoveTiming.PRE_ACTION,
	)
	director_stub.plan_pre_move.entries[0] = loop_move
	var loop_leg: Array = CombatPlanningPreview.committed_move_route_leg(
		1, preview, director_stub, board_stub, GameEnums.MoveTiming.PRE_ACTION,
	)
	if loop_leg.size() < 3:
		failures.append(
			"CombatPlanningPreview: same-tile-end loop move must still show multi-cell route",
		)
	var action_origin: Vector2i = CombatUiFormatters.plan_action_origin_cell(
		board_stub, director_stub.get_player_plan(), trample_after_pre, plan_unit,
	)
	if action_origin != Vector2i(1, 0):
		failures.append(
			"CombatUiFormatters: action origin should follow committed pre-move",
		)
	var pre_plus_action_plan := Timeline.new()
	pre_plus_action_plan.entries.append(
		TimelineAction.make_move(1, Vector2i(1, 0), -1, [], GameEnums.MoveTiming.PRE_ACTION),
	)
	pre_plus_action_plan.entries.append(trample_after_pre)
	var intent_with_pre := CombatPlanningPreview.new()
	intent_with_pre.preview_paths[1] = l_path.duplicate()
	intent_with_pre.ensure_movement_intent_from_plan(pre_plus_action_plan, board_stub)
	var kept_with_pre: Array = intent_with_pre.preview_paths.get(1, [])
	if kept_with_pre.size() != 4:
		failures.append(
			"CombatPlanningPreview: ensure_movement_intent must keep full path when pre-move is committed",
		)


static func _test_combat_ui_formatters(failures: Array[String]) -> void:
	var formula: String = CombatUiFormatters.format_damage_telemetry(
		{"base": 3, "wpn": 2, "stat_val": 5, "stat_name": "STR", "multiplier_raw": 7.0, "target_def": 1, "fortitude": 0},
		6, 4, 2,
	)
	if formula.find("[color=#F39C12]Base[/color]") < 0:
		failures.append("CombatUiFormatters: format_damage_telemetry missing color-coded formula labels")
	if formula.find("(3.0 + 2.0)") < 0:
		failures.append("CombatUiFormatters: format_damage_telemetry missing numeric calculation line")
	var desc: String = CombatUiFormatters.reason_text("no_path")
	if desc != "can't reach":
		failures.append("CombatUiFormatters: reason_text no_path mismatch")


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


static func _test_battle_arena(failures: Array[String]) -> void:
	var result: Dictionary = TestBattleTestRunner.run_all()
	for failure: String in result.get("failures", []):
		failures.append(failure)
