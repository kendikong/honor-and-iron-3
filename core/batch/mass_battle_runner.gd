class_name MassBattleRunner
extends Node

signal batch_progress(completed: int, total: int)
signal batch_completed(file_path: String, summary_stats: Dictionary)

var _battles_to_run: int = 100
var _battles_completed: int = 0
var _log_path: String = ""
var _job_label: String = "Baseline"
var _run_id_offset: int = 0
var _rules_epoch_id: String = ""
var _rules_fingerprint: String = ""
var _skirmish_setup: Dictionary = MassSimSkirmishSetup.defaults().to_dict()
var _batch_seed: int = 0

var _telemetry_results: Array[Dictionary] = []
var _group_task_id: int = -1
var _curator: SmartReplayCurator


func _ready() -> void:
	set_process(false)


func start_batch(
	num_battles: int,
	log_filename: String = "user://batch_results.jsonl",
	job_label: String = "Baseline",
	append: bool = true,
	rules_epoch_id: String = "",
	rules_fingerprint: String = "",
	skirmish_setup: MassSimSkirmishSetup = null,
) -> void:
	_battles_to_run = num_battles
	_battles_completed = 0
	_log_path = log_filename
	_job_label = job_label
	_rules_epoch_id = rules_epoch_id
	_rules_fingerprint = rules_fingerprint
	_skirmish_setup = (skirmish_setup if skirmish_setup != null else MassSimSkirmishSetup.defaults()).to_dict()
	_batch_seed = MassSimSeed.batch_seed(_rules_fingerprint)
	_run_id_offset = _next_run_id_offset() if append else 0
	_telemetry_results.clear()
	_telemetry_results.resize(num_battles)
	_curator = SmartReplayCurator.new()
	_group_task_id = WorkerThreadPool.add_group_task(
		_run_single_battle_thread, num_battles, -1, false, "MassSimulationBatch",
	)
	set_process(true)


func _next_run_id_offset() -> int:
	var rows: Array[Dictionary] = MassSimAggregator.load_jsonl(_log_path)
	return rows.size()


func _process(_delta: float) -> void:
	if _group_task_id == -1:
		set_process(false)
		return
	var completed: int = WorkerThreadPool.get_group_processed_element_count(_group_task_id)
	if completed != _battles_completed:
		_battles_completed = completed
		batch_progress.emit(_battles_completed, _battles_to_run)
	if WorkerThreadPool.is_group_task_completed(_group_task_id):
		WorkerThreadPool.wait_for_group_task_completion(_group_task_id)
		_group_task_id = -1
		set_process(false)
		_finalize_batch()


func _run_single_battle_thread(index: int) -> void:
	var setup: MassSimSkirmishSetup = MassSimSkirmishSetup.from_dict(_skirmish_setup)
	var run_id: int = index + _run_id_offset
	var map_seed: int = MassSimSeed.battle_seed(_batch_seed, run_id)
	var skirmish: Dictionary = MassSimBoardBuilder.build_skirmish(map_seed)
	var board: BoardState = skirmish["board"] as BoardState
	var grid_size: Vector2i = board.grid_size
	var player_roster: Array[UnitData] = SpawnPlacer._pick_random_player_roster(setup.player_count, map_seed)
	var player_spawn: Vector2i = skirmish["player_spawn"] as Vector2i
	for i: int in range(player_roster.size()):
		var cfg: Dictionary = MassSimUnitConfig.build(
			player_roster[i], GameEnums.Team.PLAYER, map_seed, i, setup, run_id,
		)
		BoardFactory.place_configured_unit(
			board, 10 + i, player_roster[i], GameEnums.Team.PLAYER,
			Vector2i(player_spawn.x + i * 2, player_spawn.y), cfg,
		)
	var enemy_roster: Array[UnitData] = SpawnPlacer._pick_enemy_roster(setup.enemy_count, map_seed)
	var enemy_spawn: Vector2i = skirmish["enemy_spawn"] as Vector2i
	for i: int in range(enemy_roster.size()):
		var ecfg: Dictionary = MassSimUnitConfig.build(
			enemy_roster[i], GameEnums.Team.ENEMY, map_seed, i, setup, run_id,
		)
		BoardFactory.place_configured_unit(
			board, 20 + i, enemy_roster[i], GameEnums.Team.ENEMY,
			Vector2i(grid_size.x - 3 - i * 2, enemy_spawn.y), ecfg,
		)
	var telemetry := SimulationTelemetry.new()
	telemetry.run_id = run_id
	telemetry.map_seed = map_seed
	telemetry.map_tags = skirmish["map_tags"]
	telemetry.map_layout_id = String(skirmish["layout_id"])
	telemetry.player_spawn_quadrant = String(skirmish["player_quadrant"])
	telemetry.enemy_spawn_quadrant = String(skirmish["enemy_quadrant"])
	telemetry.job_label = _job_label
	telemetry.rules_epoch_id = _rules_epoch_id
	telemetry.rules_fingerprint = _rules_fingerprint
	telemetry.skirmish_setup = setup.to_dict()
	telemetry.skirmish_player_count = setup.player_count
	telemetry.skirmish_enemy_count = setup.enemy_count
	telemetry.skirmish_player_level = setup.player_level
	telemetry.skirmish_enemy_level = setup.enemy_level
	telemetry.skirmish_player_passive_count = setup.player_passive_count
	telemetry.skirmish_player_class_skill_count = setup.player_class_skill_count
	for unit: UnitData in player_roster:
		telemetry.player_classes.append(unit.id)
	for unit: UnitData in enemy_roster:
		telemetry.enemy_classes.append(unit.id)
	var combat_stats := MassSimCombatStatsCollector.new()
	combat_stats.register_board(board)
	var p1_ai := AutobattlerAI.new(null, 0.5)
	var turns: int = 0
	var max_turns: int = 100
	var winner: int = GameEnums.Team.NEUTRAL
	while turns < max_turns:
		board.intents = EnemyPlanner.plan(board)
		combat_stats.begin_turn(turns)
		var p1_vector: TeamVector = p1_ai.decide_team_vector(board)
		combat_stats.record_ai_decision(board, p1_vector, p1_ai)
		var timeline := Timeline.new()
		if p1_vector != null and not p1_vector.actions.is_empty():
			for act: TimelineAction in p1_vector.actions:
				timeline.add(act)
			if not p1_vector.telemetry.is_empty():
				telemetry.ai_telemetry.append({
					"turn": turns,
					"telemetry": p1_vector.telemetry.duplicate(),
				})
		var sim_result: SimResult = Simulator.simulate(board, timeline)
		board = sim_result.final_state
		MassSimTelemetryAccumulator.apply_events(telemetry, sim_result.events)
		combat_stats.apply_events(sim_result.events, board)
		combat_stats.end_turn()
		winner = _check_win_condition(board)
		if winner != GameEnums.Team.NEUTRAL:
			break
		turns += 1
	telemetry.winner = winner
	telemetry.turns_taken = turns
	telemetry.completion_reason = "victory" if winner != GameEnums.Team.NEUTRAL else "timeout"
	for u: UnitState in board.units:
		if u.is_alive():
			telemetry.surviving_units.append(u.id)
	telemetry.combat_meta = combat_stats.to_dict()
	telemetry.roster_meta = _build_roster_meta(board, winner)
	_telemetry_results[index] = telemetry.to_dict()


func _build_roster_meta(board: BoardState, winner: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for unit: UnitState in board.units:
		if unit.definition == null:
			continue
		var passive_ids: PackedStringArray = PackedStringArray()
		for p: PassiveData in unit.active_passives:
			if p != null:
				passive_ids.append(str(p.id))
		var team_won: bool = (
			(unit.team == GameEnums.Team.PLAYER and winner == GameEnums.Team.PLAYER)
			or (unit.team == GameEnums.Team.ENEMY and winner == GameEnums.Team.ENEMY)
		)
		out.append({
			"class_id": str(unit.definition.id),
			"team": unit.team,
			"level": unit.level,
			"passive_ids": passive_ids,
			"ability_count": unit.active_abilities.size(),
			"team_won": team_won,
		})
	return out


func _check_win_condition(board: BoardState) -> int:
	var p_alive: bool = false
	var e_alive: bool = false
	for u: UnitState in board.units:
		if u.is_alive():
			if u.team == GameEnums.Team.PLAYER:
				p_alive = true
			elif u.team == GameEnums.Team.ENEMY:
				e_alive = true
	if p_alive and not e_alive:
		return GameEnums.Team.PLAYER
	if e_alive and not p_alive:
		return GameEnums.Team.ENEMY
	return GameEnums.Team.NEUTRAL


func _finalize_batch() -> void:
	var file: FileAccess = FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(_log_path, FileAccess.WRITE)
	else:
		file.seek_end()
	if file != null:
		for t_dict: Variant in _telemetry_results:
			if t_dict != null:
				file.store_line(JSON.stringify(t_dict))
		file.close()
	var all_rows: Array[Dictionary] = MassSimAggregator.load_jsonl(_log_path)
	_curator.curate(all_rows)
	var stats: Dictionary = _curator.to_dict()
	stats["total_battles"] = all_rows.size()
	stats["job_label"] = _job_label
	batch_completed.emit(_log_path, stats)
