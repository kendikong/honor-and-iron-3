class_name CombatIntentState
extends RefCounted

## Single owner for enemy-intent visibility, hover coord, and timeline hover highlight.

signal intents_changed(intent_units: Dictionary)
signal hover_coord_changed(coord: Vector2i)
signal timeline_hover_changed(unit_id: int)

var hover_coord: Vector2i = Vector2i(-999, -999)
var timeline_hover_id: int = -1
var intent_units: Dictionary = {}

var _board: BoardState
var _preview_board: BoardState
var _director: CombatDirector
var _selected_id: int = -1
var _phase: int = CombatDirector.Phase.PLANNING_PHASE_1
var _skill_interaction_active: bool = false


func bind(director: CombatDirector) -> void:
	_director = director


func set_board(board: BoardState) -> void:
	_board = board
	recompute()


func set_preview_board(board: BoardState) -> void:
	_preview_board = board
	recompute()


func set_phase(phase: int) -> void:
	_phase = phase
	recompute()


func set_selection(unit_id: int) -> void:
	_selected_id = unit_id
	recompute()


func set_skill_interaction_active(active: bool) -> void:
	_skill_interaction_active = active
	recompute()


func is_skill_interaction_active() -> bool:
	return _skill_interaction_active


func set_hover_coord(coord: Vector2i) -> void:
	if coord == hover_coord:
		return
	hover_coord = coord
	hover_coord_changed.emit(coord)
	recompute()


func set_timeline_hover(unit_id: int) -> void:
	if unit_id == timeline_hover_id:
		return
	timeline_hover_id = unit_id
	timeline_hover_changed.emit(unit_id)
	recompute()


func clear_timeline_hover() -> void:
	set_timeline_hover(-1)


func recompute() -> void:
	var next: Dictionary = {}
	if _board == null:
		intent_units = next
		intents_changed.emit(intent_units)
		return
	var selected: int = _selected_id
	if selected < 0 and _director != null:
		selected = _director.selected_unit_id
	if selected >= 0:
		for intent in _board.intents:
			for action: TimelineAction in intent.actions:
				if action.target_unit_id == selected:
					next[intent.enemy_id] = true
					break
	if timeline_hover_id >= 0:
		var tl_unit := _board.get_unit_by_id(timeline_hover_id)
		if tl_unit != null and tl_unit.is_enemy():
			next[timeline_hover_id] = true
	if _board.is_in_bounds(hover_coord):
		var hovered: UnitState = null
		if _skill_interaction_active:
			for board: BoardState in [_board, _preview_board, _projected_board()]:
				if board == null:
					continue
				hovered = board.get_unit_at(hover_coord)
				if hovered != null:
					break
		else:
			hovered = _board.get_unit_at(hover_coord)
		if hovered != null and hovered.is_enemy():
			next[hovered.id] = true
	intent_units = next
	intents_changed.emit(intent_units)


func intent_visible(unit: UnitState) -> bool:
	if unit == null:
		return false
	if not unit.is_enemy():
		return true
	if _skill_interaction_active:
		return true
	if _phase == CombatDirector.Phase.ENEMY_TURN:
		return true
	if _phase in [
		CombatDirector.Phase.PLANNING_PHASE_1,
		CombatDirector.Phase.PLANNING_PHASE_2,
		CombatDirector.Phase.EXECUTING_PHASE_1,
		CombatDirector.Phase.EXECUTING_PHASE_2,
	]:
		return intent_units.has(unit.id)
	return false


func _projected_board() -> BoardState:
	if _director != null and _director.projected_state != null:
		return _director.projected_state
	return null
