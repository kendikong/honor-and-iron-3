class_name MassBattleRunner
extends Node

## Purpose: Headless mass battle simulator for analytics.
## Responsibilities: Sets up two AI-controlled teams, runs N simulations as fast as possible, and outputs statistics to a JSONL file.

signal batch_completed(file_path: String)

var _battles_to_run: int = 100
var _battles_completed: int = 0
var _output_file: FileAccess
var _log_path: String

func start_batch(num_battles: int, log_filename: String = "user://batch_results.jsonl") -> void:
	_battles_to_run = num_battles
	_battles_completed = 0
	_log_path = log_filename
	_output_file = FileAccess.open(_log_path, FileAccess.WRITE)
	
	if _output_file == null:
		printerr("MassBattleRunner: Failed to open log file for writing.")
		return
		
	print("Starting mass battle simulation: %d runs..." % _battles_to_run)
	
	# In a real scenario, this should be chunked across frames or threads
	# to avoid freezing the editor/game if running thousands of iterations.
	for i in range(_battles_to_run):
		_run_single_battle(i)
	
	_output_file.close()
	print("Batch complete. Logs saved to: ", _log_path)
	batch_completed.emit(_log_path)

func _run_single_battle(run_index: int) -> void:
	var board = _generate_test_board()
	var team1_ai = AutobattlerAI.new(null, 0.5)
	var team2_ai = AutobattlerAI.new(null, 0.8) # More aggressive
	
	var turns = 0
	var max_turns = 50
	var winner = GameEnums.Team.NEUTRAL
	
	while turns < max_turns:
		# Simulate a round where both sides act
		# (Simplified for example; real game has specific turn order logic)
		_execute_team_turn(board, GameEnums.Team.PLAYER, team1_ai)
		if _check_win_condition(board) != GameEnums.Team.NEUTRAL:
			winner = _check_win_condition(board)
			break
			
		_execute_team_turn(board, GameEnums.Team.ENEMY, team2_ai)
		if _check_win_condition(board) != GameEnums.Team.NEUTRAL:
			winner = _check_win_condition(board)
			break
			
		turns += 1
		
	if winner == GameEnums.Team.NEUTRAL:
		winner = GameEnums.Team.NEUTRAL # Draw/Timeout
		
	_log_battle_result(run_index, winner, turns, board)

func _execute_team_turn(board: BoardState, team: int, ai: AutobattlerAI) -> void:
	for unit in board.units:
		if unit.is_alive() and unit.team == team:
			var decision = ai.decide_best_action(board, unit)
			if decision.action != null:
				var timeline = Timeline.new()
				for event in decision.action.events:
					timeline.add_event(event)
				# Mutate the board
				var sim_result = Simulator.simulate(board, timeline)
				# Update current board to the final state
				board.copy_from(sim_result.final_state)

func _check_win_condition(board: BoardState) -> int:
	var player_alive = false
	var enemy_alive = false
	for u in board.units:
		if u.is_alive():
			if u.team == GameEnums.Team.PLAYER: player_alive = true
			elif u.team == GameEnums.Team.ENEMY: enemy_alive = true
	
	if player_alive and not enemy_alive: return GameEnums.Team.PLAYER
	if enemy_alive and not player_alive: return GameEnums.Team.ENEMY
	return GameEnums.Team.NEUTRAL

func _generate_test_board() -> BoardState:
	var board = BoardState.new()
	# Dummy generation
	return board

func _log_battle_result(run_id: int, winner: int, turns: int, final_board: BoardState) -> void:
	if _output_file == null:
		return
		
	var data = {
		"run_id": run_id,
		"winner": winner,
		"turns_taken": turns,
		"units_surviving": []
	}
	
	for u in final_board.units:
		if u.is_alive():
			data["units_surviving"].append(u.id)
			
	_output_file.store_line(JSON.stringify(data))
