class_name MassBattleRunner
extends Node

## Purpose: Headless mass battle simulator for analytics.
## Responsibilities: Sets up AI-controlled teams, runs simulations concurrently using WorkerThreadPool,
## tracks telemetry, curates replays, and outputs statistics to a JSONL file.

signal batch_progress(completed: int, total: int)
signal batch_completed(file_path: String, summary_stats: Dictionary)

var _battles_to_run: int = 100
var _battles_completed: int = 0
var _log_path: String

var _telemetry_results: Array[Dictionary] = []
var _group_task_id: int = -1
var _curator: SmartReplayCurator

func _ready() -> void:
	set_process(false)

func start_batch(num_battles: int, log_filename: String = "user://batch_results.jsonl") -> void:
	_battles_to_run = num_battles
	_battles_completed = 0
	_log_path = log_filename
	
	_telemetry_results.clear()
	_telemetry_results.resize(num_battles)
	
	_curator = SmartReplayCurator.new()
	
	print("Starting Mass Battle Batch: %d runs on background threads..." % _battles_to_run)
	
	_group_task_id = WorkerThreadPool.add_group_task(_run_single_battle_thread, _battles_to_run, "MassSimulationBatch")
	set_process(true)

func _process(_delta: float) -> void:
	if _group_task_id == -1:
		set_process(false)
		return
		
	var completed = WorkerThreadPool.get_group_processed_element_count(_group_task_id)
	if completed != _battles_completed:
		_battles_completed = completed
		batch_progress.emit(_battles_completed, _battles_to_run)
		
	if WorkerThreadPool.is_group_task_completed(_group_task_id):
		WorkerThreadPool.wait_for_group_task_completion(_group_task_id)
		_group_task_id = -1
		set_process(false)
		_finalize_batch()

func _run_single_battle_thread(index: int) -> void:
	var map_seed = hash(Time.get_ticks_usec() + index * 31)
	
	var grid_size = Vector2i(24, 16)
	var terrain = DataLibrary.get_terrain("grass")
	var board = BoardFactory.build_empty(grid_size, terrain)
	
	# Spawn players
	var player_roster = SpawnPlacer._pick_random_player_roster(4, map_seed)
	for i in range(player_roster.size()):
		BoardFactory.place_unit(board, 10 + i, player_roster[i], GameEnums.Team.PLAYER, Vector2i(i*2 + 2, 8))
		
	# Spawn enemies
	var enemy_roster = SpawnPlacer._pick_enemy_roster(6, map_seed)
	for i in range(enemy_roster.size()):
		BoardFactory.place_unit(board, 20 + i, enemy_roster[i], GameEnums.Team.ENEMY, Vector2i(grid_size.x - 3 - i*2, 8))
	
	var telemetry = SimulationTelemetry.new()
	telemetry.run_id = index
	telemetry.map_seed = map_seed
	telemetry.map_tags = ["grass", "open"]
	
	for unit in player_roster:
		telemetry.player_classes.append(unit.id)
	for unit in enemy_roster:
		telemetry.enemy_classes.append(unit.id)
	
	var p1_ai = AutobattlerAI.new(null, 0.5)
	var p2_ai = AutobattlerAI.new(null, 0.8)
	
	var turns = 0
	var max_turns = 100
	var winner = GameEnums.Team.NEUTRAL
	
	while turns < max_turns:
		# Player Turn (Phase 1)
		var p1_vector = p1_ai.decide_team_vector(board)
		if p1_vector != null and not p1_vector.actions.is_empty():
			var timeline = Timeline.new()
			for act in p1_vector.actions:
				timeline.add_event(act)
			var sim_result = Simulator.simulate(board, timeline)
			board = sim_result.final_state
			_accumulate_telemetry(telemetry, sim_result.events)
			
		winner = _check_win_condition(board)
		if winner != GameEnums.Team.NEUTRAL:
			break
			
		# Enemy Turn (Phase 2)
		var p2_vector = p2_ai.decide_team_vector(board)
		if p2_vector != null and not p2_vector.actions.is_empty():
			var timeline = Timeline.new()
			for act in p2_vector.actions:
				timeline.add_event(act)
			var sim_result = Simulator.simulate(board, timeline)
			board = sim_result.final_state
			_accumulate_telemetry(telemetry, sim_result.events)
			
		winner = _check_win_condition(board)
		if winner != GameEnums.Team.NEUTRAL:
			break
			
		turns += 1
		
	telemetry.winner = winner
	telemetry.turns_taken = turns
	telemetry.completion_reason = "victory" if winner != GameEnums.Team.NEUTRAL else "timeout"
	
	for u in board.units:
		if u.is_alive():
			telemetry.surviving_units.append(u.id)
			
	_telemetry_results[index] = telemetry.to_dict()

func _accumulate_telemetry(telemetry: SimulationTelemetry, events: Array) -> void:
	for e in events:
		if e.type == GameEnums.EventType.UNIT_MOVED and e.get("collision_target") != null:
			telemetry.wall_collisions += 1
		elif e.type == GameEnums.EventType.DAMAGE_TAKEN:
			var amt = e.get("amount", 0)
			telemetry.assisted_damage += amt

func _check_win_condition(board: BoardState) -> int:
	var p_alive = false
	var e_alive = false
	for u in board.units:
		if u.is_alive():
			if u.team == GameEnums.Team.PLAYER: p_alive = true
			elif u.team == GameEnums.Team.ENEMY: e_alive = true
			
	if p_alive and not e_alive: return GameEnums.Team.PLAYER
	if e_alive and not p_alive: return GameEnums.Team.ENEMY
	return GameEnums.Team.NEUTRAL

func _finalize_batch() -> void:
	var file = FileAccess.open(_log_path, FileAccess.WRITE)
	if file != null:
		for t_dict in _telemetry_results:
			if t_dict != null:
				file.store_line(JSON.stringify(t_dict))
		file.close()
	
	_curator.curate(_telemetry_results)
	var stats = _curator.to_dict()
	stats["total_battles"] = _battles_to_run
	
	print("Batch complete. Logs saved to: ", _log_path)
	batch_completed.emit(_log_path, stats)
