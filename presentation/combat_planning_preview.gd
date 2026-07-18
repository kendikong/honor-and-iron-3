class_name CombatPlanningPreview
extends RefCounted

## Shared live-preview state for tactical planning (paths, predicted HP/armor).

var predicted_hp: Dictionary = {}
var predicted_armor: Dictionary = {}
var preview_paths: Dictionary = {}
var preview_splits: Dictionary = {}
var preview_post_splits: Dictionary = {}
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
	preview_post_splits.clear()
	preview_pushes.clear()
	preview_board = null
	live_intents.clear()


func apply_result(res: Dictionary, director: CombatDirector) -> void:
	var temp_board: BoardState = res.get("temp_board")
	if temp_board == null:
		return
	preview_board = temp_board
	var base_board: BoardState = director.base_board if director.base_board != null else director.board
	predicted_hp.clear()
	predicted_armor.clear()
	if base_board != null:
		for unit: UnitState in base_board.units:
			var pv := temp_board.get_unit_by_id(unit.id)
			if pv != null and pv.is_alive():
				predicted_hp[unit.id] = pv.health.current_hp
				predicted_armor[unit.id] = pv.armor
			else:
				predicted_hp[unit.id] = 0
				predicted_armor[unit.id] = 0
	var events: Array = res.get("events", [])
	live_intents = res.get("intents", [])
	build_preview_paths(events, director, preview_paths, preview_splits, preview_pushes, preview_post_splits)


static func from_sim_result(
	result: SimResult,
	director: CombatDirector,
	base_board: BoardState,
) -> CombatPlanningPreview:
	var preview := CombatPlanningPreview.new()
	if result == null or result.final_state == null:
		return preview
	preview.preview_board = result.final_state
	build_preview_paths(
		result.events,
		director,
		preview.preview_paths,
		preview.preview_splits,
		preview.preview_pushes,
		preview.preview_post_splits,
	)
	if base_board != null:
		for unit: UnitState in base_board.units:
			var pv := result.final_state.get_unit_by_id(unit.id)
			if pv != null and pv.is_alive():
				preview.predicted_hp[unit.id] = pv.health.current_hp
				preview.predicted_armor[unit.id] = pv.armor
			else:
				preview.predicted_hp[unit.id] = 0
				preview.predicted_armor[unit.id] = 0
	return preview


static func build_preview_paths(
	events: Array,
	director: CombatDirector,
	paths: Dictionary,
	splits: Dictionary,
	pushes: Dictionary,
	post_splits: Dictionary = {},
) -> void:
	paths.clear()
	splits.clear()
	pushes.clear()
	post_splits.clear()
	var start_board: BoardState = director.base_board if director.base_board != null else director.board
	if start_board == null:
		return
	var current_positions: Dictionary = {}
	for unit: UnitState in start_board.units:
		paths[unit.id] = [unit.position]
		splits[unit.id] = 1
		post_splits[unit.id] = 1
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
					var move_timing: int = int(
						d.get("move_timing", GameEnums.MoveTiming.PRE_ACTION)
					)
					for c: Variant in path:
						if (
							not enemy_phase
							and move_timing == GameEnums.MoveTiming.POST_ACTION
							and int(post_splits[id]) == int(splits[id])
						):
							post_splits[id] = (paths[id] as Array).size()
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


func copy_from(other: CombatPlanningPreview) -> void:
	predicted_hp = other.predicted_hp.duplicate()
	predicted_armor = other.predicted_armor.duplicate()
	live_intents = other.live_intents.duplicate()
	preview_board = other.preview_board
	preview_paths = other.preview_paths.duplicate(true)
	preview_splits = other.preview_splits.duplicate()
	preview_post_splits = other.preview_post_splits.duplicate()
	preview_pushes = other.preview_pushes.duplicate(true)
