extends Node

## Passes SkirmishConfig from BattleSetup into TacticalCombat (scene-tree safe).

var _pending: SkirmishGenerator.SkirmishConfig = null
var _pending_encounter: EncounterData = null
var _pending_assignments: Dictionary = {}
var _pending_board: BoardState = null


func set_pending(config: SkirmishGenerator.SkirmishConfig) -> void:
	_pending = config
	_pending_encounter = null
	_pending_assignments.clear()
	_pending_board = null


func set_pending_encounter(encounter: EncounterData, assignments: Dictionary = {}) -> void:
	_pending = null
	_pending_encounter = encounter
	_pending_assignments = assignments.duplicate(true)
	_pending_board = null


func set_pending_board(board: BoardState) -> void:
	_pending = null
	_pending_encounter = null
	_pending_assignments.clear()
	_pending_board = board


func take_pending() -> SkirmishGenerator.SkirmishConfig:
	var config: SkirmishGenerator.SkirmishConfig = _pending
	_pending = null
	if config == null:
		config = SkirmishGenerator.SkirmishConfig.new()
	return config


func take_pending_encounter() -> EncounterData:
	var encounter: EncounterData = _pending_encounter
	_pending_encounter = null
	return encounter


func take_pending_assignments() -> Dictionary:
	var assignments: Dictionary = _pending_assignments.duplicate(true)
	_pending_assignments.clear()
	return assignments


func take_pending_board() -> BoardState:
	var board: BoardState = _pending_board
	_pending_board = null
	return board


func has_pending() -> bool:
	return _pending != null
