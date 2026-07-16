class_name TacticalInputController
extends Node

## Drag, aim, and grid planning input for tactical combat (Phase 6).

var _map_view: TacticalMapView
var _director: CombatDirector
var _planning: TacticalPlanningOverlay
var _sfx: SfxPlayer

var _dragging: bool = false
var _drag_unit_id: int = -1
var _drag_route: Array[Vector2i] = []
var _drag_last_free: Vector2i = Vector2i(-1, -1)
var _aiming: bool = false
var _input_blocked: Callable


func setup(
	map_view: TacticalMapView,
	director: CombatDirector,
	planning: TacticalPlanningOverlay,
	sfx: SfxPlayer,
	input_blocked: Callable = Callable(),
) -> void:
	_map_view = map_view
	_director = director
	_planning = planning
	_sfx = sfx
	_input_blocked = input_blocked
	EventBus.board_changed.connect(_on_board_changed)


func _on_board_changed(_board: BoardState) -> void:
	_cancel_drag()
	_cancel_aim()


func handle_input(event: InputEvent) -> bool:
	if _input_blocked.is_valid() and bool(_input_blocked.call()):
		return false
	if _director == null:
		return false
	if not _is_planning():
		return false
	if event is InputEventMouseMotion:
		var local: Vector2 = _screen_to_map_local(event.position)
		if _dragging:
			_update_drag(local)
		elif _aiming:
			_planning.set_aim_mode(true, local, _selected_class_id())
		return _dragging or _aiming
	if event is InputEventMouseButton:
		return _handle_mouse_button(event as InputEventMouseButton)
	if event is InputEventKey and event.pressed and not event.echo:
		return _handle_key(event as InputEventKey)
	return false


func _handle_mouse_button(event: InputEventMouseButton) -> bool:
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _aiming:
			_cancel_aim()
			_play_sfx("cancel")
			return true
		if _director.selected_unit_id > 0:
			_director.select_unit(-1)
			_play_sfx("cancel")
			return true
		return false
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
		_on_left_press(local)
	else:
		_on_left_release(local)
	return true


func _handle_key(event: InputEventKey) -> bool:
	if event.keycode == KEY_A and _director.selected_unit_id > 0:
		_aiming = not _aiming
		if _aiming:
			_cancel_drag()
			_planning.set_aim_mode(true, _screen_to_map_local(get_viewport().get_mouse_position()), _selected_class_id())
			_play_sfx("select")
		else:
			_cancel_aim()
		return true
	return false


func _on_left_press(local: Vector2) -> void:
	var cell: Vector2i = _map_view.screen_to_grid(get_viewport().get_mouse_position())
	var board: BoardState = _director.board
	if board == null or not board.is_in_bounds(cell):
		_cancel_aim()
		return
	var unit := board.get_unit_at(cell)
	if unit != null and unit.team == GameEnums.Team.PLAYER and unit.is_alive():
		if _aiming:
			_cancel_aim()
		_director.select_unit(unit.id)
		_begin_drag(unit, cell)
		_play_sfx("select")
		return
	if _aiming and _director.selected_unit_id > 0:
		_try_aim_click(cell)
		return
	if unit != null and unit.team == GameEnums.Team.ENEMY and _director.selected_unit_id > 0:
		_director.rpc_plan_attack(
			_director.selected_unit_id,
			_director.selected_ability_index,
			unit.id,
		)
		_play_sfx("ability")
		return
	if _director.selected_unit_id > 0 and unit == null:
		var actor := board.get_unit_by_id(_director.selected_unit_id)
		if actor != null:
			var face: int = _facing_toward(actor.position, cell)
			_director.rpc_plan_move(_director.selected_unit_id, cell, face, [])
			_play_sfx("move")


func _on_left_release(local: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	_planning.clear_drag_route()
	var board: BoardState = _director.board
	var actor := board.get_unit_by_id(_drag_unit_id)
	var cell: Vector2i = _map_view.screen_to_grid(get_viewport().get_mouse_position())
	if actor == null or not board.is_in_bounds(cell):
		return
	var dropped_on := board.get_unit_at(cell)
	if dropped_on != null and dropped_on.id != actor.id and dropped_on.team == GameEnums.Team.ENEMY:
		var waypoints: Array[Vector2i] = _route_waypoints()
		if waypoints.is_empty() and _drag_last_free != actor.position:
			var face: int = _facing_toward(actor.position, _drag_last_free)
			_director.rpc_plan_move(_drag_unit_id, _drag_last_free, face, [])
		_director.rpc_plan_attack(_drag_unit_id, _director.selected_ability_index, dropped_on.id)
		_play_sfx("ability")
	elif dropped_on == null:
		var target: Vector2i = cell
		if _drag_route.size() >= 2 and _drag_route[_drag_route.size() - 1] == cell:
			target = cell
		elif _drag_last_free != Vector2i(-1, -1):
			target = _drag_last_free
		var waypoints: Array[Vector2i] = _route_waypoints()
		var face: int = _facing_from_drop(local, target)
		if face < 0:
			face = _facing_toward(actor.position, target)
		_director.rpc_plan_move(_drag_unit_id, target, face, waypoints)
		_play_sfx("move")
	elif cell == actor.position:
		var face: int = _facing_from_drop(local, cell)
		if face >= 0:
			_director.rpc_plan_face(_drag_unit_id, face)
			_play_sfx("move")
	_drag_route.clear()


func _try_aim_click(cell: Vector2i) -> void:
	var board: BoardState = _director.board
	var actor := board.get_unit_by_id(_director.selected_unit_id)
	if actor == null:
		_cancel_aim()
		return
	var target := board.get_unit_at(cell)
	if target != null and target.team == GameEnums.Team.ENEMY:
		_director.rpc_plan_attack(_director.selected_unit_id, _director.selected_ability_index, target.id)
		_play_sfx("ability")
	else:
		_play_sfx("invalid")
	_cancel_aim()


func _begin_drag(unit: UnitState, _cell: Vector2i) -> void:
	_dragging = true
	_drag_unit_id = unit.id
	_drag_route = [unit.position]
	_drag_last_free = unit.position
	_planning.set_drag_route(_drag_route)


func _update_drag(local: Vector2) -> void:
	var board: BoardState = _director.board
	var cell: Vector2i = _map_view.screen_to_grid(get_viewport().get_mouse_position())
	if not board.is_in_bounds(cell):
		return
	_extend_drag_route(cell)
	var occupant := board.get_unit_at(cell)
	var drag_target_id: int = -1
	if occupant != null and occupant.id != _drag_unit_id:
		drag_target_id = occupant.id
	elif occupant == null:
		_drag_last_free = cell
	var preview: Dictionary = _director.preview_drag(
		_drag_unit_id,
		_drag_last_free,
		drag_target_id,
		_route_waypoints(),
	)
	if preview.has("temp_board"):
		_planning.set_preview_board(preview["temp_board"])
	_planning.set_drag_route(_drag_route)


func _extend_drag_route(cell: Vector2i) -> void:
	if _drag_route.is_empty():
		return
	var last: Vector2i = _drag_route[_drag_route.size() - 1]
	if cell == last:
		return
	if _drag_route.size() >= 2 and cell == _drag_route[_drag_route.size() - 2]:
		_drag_route.remove_at(_drag_route.size() - 1)
		return
	if GridSystem.manhattan(last, cell) != 1:
		return
	var board: BoardState = _director.board
	var unit := board.get_unit_by_id(_drag_unit_id)
	if unit == null:
		return
	if not MovementSystem._is_walkable_for(board, cell, unit):
		return
	if _drag_route.size() - 1 >= unit.movement.points_left:
		return
	_drag_route.append(cell)


func _route_waypoints() -> Array[Vector2i]:
	var waypoints: Array[Vector2i] = []
	if _drag_route.size() >= 2:
		for i: int in range(1, _drag_route.size()):
			waypoints.append(_drag_route[i])
	return waypoints


func cancel_drag() -> void:
	_dragging = false
	_drag_unit_id = -1
	_drag_route.clear()
	if _planning != null:
		_planning.clear_drag_route()


func cancel_aim() -> void:
	_aiming = false
	if _planning != null:
		_planning.set_aim_mode(false)


func _cancel_drag() -> void:
	cancel_drag()


func _cancel_aim() -> void:
	cancel_aim()


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


func _selected_class_id() -> StringName:
	var unit := _director.board.get_unit_by_id(_director.selected_unit_id) if _director != null else null
	if unit != null and unit.definition != null:
		return unit.definition.id
	return &"knight"


func _is_planning() -> bool:
	return (
		_director.phase == CombatDirector.Phase.PLANNING_PHASE_1
		or _director.phase == CombatDirector.Phase.PLANNING_PHASE_2
	)


func _screen_to_map_local(screen_pos: Vector2) -> Vector2:
	var zoom: float = _map_view.get_node("WorldModulate/MapRoot").scale.x
	return (screen_pos - _map_view.position) / maxf(zoom, 0.001)


func _facing_toward(from: Vector2i, to: Vector2i) -> int:
	if to.x > from.x:
		return GameEnums.Facing.EAST
	if to.x < from.x:
		return GameEnums.Facing.WEST
	if to.y > from.y:
		return GameEnums.Facing.SOUTH
	if to.y < from.y:
		return GameEnums.Facing.NORTH
	return GameEnums.Facing.EAST


func _facing_from_drop(local: Vector2, coord: Vector2i) -> int:
	var center: Vector2 = _map_view.grid_to_local(coord)
	var offset: Vector2 = local - center
	var threshold: float = float(TacticalConstants.TILE_PX) * 0.22
	if offset.length() < threshold:
		return -1
	if absf(offset.x) >= absf(offset.y):
		return GameEnums.Facing.EAST if offset.x > 0.0 else GameEnums.Facing.WEST
	return GameEnums.Facing.SOUTH if offset.y > 0.0 else GameEnums.Facing.NORTH


func _play_sfx(key: String) -> void:
	if _sfx != null:
		_sfx.play(key)
