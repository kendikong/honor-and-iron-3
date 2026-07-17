class_name TacticalInputController
extends Node

## Drag, aim, and grid planning input — delegates H&I semantics to CombatPlanningInput.

var _map_view: TacticalMapView
var _director: CombatDirector
var _planning: TacticalPlanningOverlay
var _sfx: SfxPlayer
var _planning_input: CombatPlanningInput
var _intent_state: CombatIntentState
var _input_blocked: Callable


func setup(
	map_view: TacticalMapView,
	director: CombatDirector,
	planning: TacticalPlanningOverlay,
	sfx: SfxPlayer,
	planning_input: CombatPlanningInput = null,
	intent_state: CombatIntentState = null,
	input_blocked: Callable = Callable(),
) -> void:
	_map_view = map_view
	_director = director
	_planning = planning
	_sfx = sfx
	_planning_input = planning_input
	_intent_state = intent_state
	_input_blocked = input_blocked
	EventBus.board_changed.connect(_on_board_changed)


func _on_board_changed(_board: BoardState) -> void:
	cancel_drag()
	cancel_aim()


func handle_input(event: InputEvent) -> bool:
	if _input_blocked.is_valid() and bool(_input_blocked.call()):
		return false
	if _director == null or _planning_input == null:
		return false
	if not _is_planning():
		return false
	if event is InputEventMouseMotion:
		var local: Vector2 = _screen_to_map_local(event.position)
		if _planning_input.dragging:
			_planning_input.update_drag(local)
		elif _planning_input.aiming:
			var cell: Vector2i = _map_view.screen_to_grid(event.position)
			if _intent_state != null:
				_intent_state.set_hover_coord(cell)
			_planning.set_hover_coord(cell)
			_planning.set_aim_mode(true, local, _selected_class_id())
			_planning.recompute_hover_ranges(
				_planning_input.force_basic_movement,
				_director.selected_ability_index,
				false,
				-1,
			)
		return _planning_input.dragging or _planning_input.aiming
	if event is InputEventMouseButton:
		return _handle_mouse_button(event as InputEventMouseButton)
	if event is InputEventKey and event.pressed and not event.echo:
		return _handle_key(event as InputEventKey)
	return false


func _handle_mouse_button(event: InputEventMouseButton) -> bool:
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_planning_input.on_right_click()
		return true
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_cycle_ability(-1)
		return true
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_cycle_ability(1)
		return true
	if event.button_index != MOUSE_BUTTON_LEFT:
		return false
	var local: Vector2 = _screen_to_map_local(event.position)
	if event.pressed:
		_planning_input.on_left_press(local)
	else:
		_planning_input.on_left_release(local)
	return true


func _handle_key(event: InputEventKey) -> bool:
	if event.keycode == KEY_A and _director.selected_unit_id > 0:
		_planning_input.aiming = not _planning_input.aiming
		if _planning_input.aiming:
			cancel_drag()
			if _intent_state != null:
				_intent_state.set_skill_interaction_active(true)
			_planning.set_aim_mode(
				true,
				_screen_to_map_local(get_viewport().get_mouse_position()),
				_selected_class_id(),
			)
			_play_sfx("select")
		else:
			cancel_aim()
		return true
	return false


func cancel_drag() -> void:
	if _planning_input != null:
		_planning_input.cancel_drag()


func cancel_aim() -> void:
	if _planning_input != null:
		_planning_input.cancel_aim()


func _cycle_ability(delta: int) -> void:
	if _director.selected_unit_id <= 0:
		return
	var unit := _director.board.get_unit_by_id(_director.selected_unit_id)
	if unit == null or unit.active_abilities.is_empty():
		return
	var count: int = unit.active_abilities.size()
	var next: int = (_director.selected_ability_index + delta + count) % count
	_director.select_ability(next)
	_play_sfx("select")
	if _planning_input != null and _planning_input.dragging:
		_planning_input.refresh_live_preview()
	if _planning != null:
		_planning.recompute_hover_ranges(
			_planning_input.force_basic_movement if _planning_input != null else false,
			_director.selected_ability_index,
			_planning_input.dragging if _planning_input != null else false,
			_planning_input.get_drag_unit_id() if _planning_input != null else -1,
		)


func _selected_class_id() -> StringName:
	var unit := _director.board.get_unit_by_id(_director.selected_unit_id) if _director != null else null
	if unit != null and unit.definition != null:
		return unit.definition.id
	return &"knight"


func _is_planning() -> bool:
	return _director.phase in [
		CombatDirector.Phase.PLANNING_PHASE_1,
		CombatDirector.Phase.PLANNING_PHASE_2,
	]


func _screen_to_map_local(screen_pos: Vector2) -> Vector2:
	var zoom: float = _map_view.get_node("WorldModulate/MapRoot").scale.x
	return (screen_pos - _map_view.position) / maxf(zoom, 0.001)


func _play_sfx(key: String) -> void:
	if _sfx != null:
		_sfx.play(key)
