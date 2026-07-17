class_name CombatPlanningPreview
extends RefCounted

## Shared live-preview state for tactical planning (paths, predicted HP/armor).

var predicted_hp: Dictionary = {}
var predicted_armor: Dictionary = {}
var preview_paths: Dictionary = {}
var preview_splits: Dictionary = {}
var preview_pushes: Dictionary = {}
var preview_board: BoardState = null
var live_intents: Array = []


func clear_interaction() -> void:
	predicted_hp.clear()
	predicted_armor.clear()
	live_intents.clear()


func clear_all() -> void:
	clear_interaction()
	preview_paths.clear()
	preview_splits.clear()
	preview_pushes.clear()
	preview_board = null
	live_intents.clear()


func apply_result(res: Dictionary, director: CombatDirector) -> void:
	var temp_board: BoardState = res.get("temp_board")
	if temp_board == null:
		return
	preview_board = temp_board
	predicted_hp.clear()
	predicted_armor.clear()
	for unit: UnitState in temp_board.units:
		predicted_hp[unit.id] = unit.health.current_hp
		predicted_armor[unit.id] = unit.armor
	var events: Array = res.get("events", [])
	live_intents = res.get("intents", [])
	build_preview_paths(events, director, preview_paths, preview_splits, preview_pushes)


static func build_preview_paths(
	events: Array,
	director: CombatDirector,
	paths: Dictionary,
	splits: Dictionary,
	pushes: Dictionary,
) -> void:
	paths.clear()
	splits.clear()
	pushes.clear()
	var start_board: BoardState = director.base_board if director.base_board != null else director.board
	if start_board == null:
		return
	var current_positions: Dictionary = {}
	for unit: UnitState in start_board.units:
		paths[unit.id] = [unit.position]
		splits[unit.id] = 1
		pushes[unit.id] = []
		current_positions[unit.id] = unit.position
	var enemy_phase: bool = false
	for event: Variant in events:
		if not event is SimEvent:
			continue
		var d: Dictionary = (event as SimEvent).data
		match (event as SimEvent).type:
			GameEnums.SimEventType.ENEMY_PHASE_BEGAN:
				enemy_phase = true
			GameEnums.SimEventType.UNIT_MOVED:
				var id: int = int(d.get("actor", -1))
				if paths.has(id):
					var path: Array = d.get("path", [])
					for c: Variant in path:
						(paths[id] as Array).append(c)
						if not enemy_phase:
							splits[id] = int(splits[id]) + 1
					if not path.is_empty():
						current_positions[id] = path[path.size() - 1]
			GameEnums.SimEventType.UNIT_PUSHED:
				var pid: int = int(d.get("unit", -1))
				var to_pos: Vector2i = d.get("to", Vector2i.ZERO)
				if pushes.has(pid):
					var from_unit := start_board.get_unit_by_id(pid)
					var from_pos: Vector2i = current_positions.get(
						pid,
						from_unit.position if from_unit != null else to_pos,
					)
					(pushes[pid] as Array).append([from_pos, to_pos])
					current_positions[pid] = to_pos


func get_predicted_hp(unit_id: int, current: int) -> int:
	return int(predicted_hp.get(unit_id, current))


func get_predicted_armor(unit_id: int, current: int) -> int:
	return int(predicted_armor.get(unit_id, current))
