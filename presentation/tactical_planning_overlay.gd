class_name TacticalPlanningOverlay
extends Node2D

## Range tints, move route, and aim icon on the tactical grid (Phase 6).

const _COLOR_REACH := Color(0.28, 0.58, 0.48, 0.28)
const _COLOR_ROUTE := Color(0.98, 0.88, 0.38, 0.85)
const _COLOR_GHOST := Color(0.98, 0.88, 0.38, 0.35)
const _COLOR_AIM := Color(0.95, 0.95, 1.0, 0.95)

var _map_view: TacticalMapView
var _director: CombatDirector
var _board: BoardState
var _preview_board: BoardState
var _route: Array[Vector2i] = []
var _aiming: bool = false
var _aim_local: Vector2 = Vector2.ZERO
var _aim_class_id: StringName = &"knight"


func setup(map_view: TacticalMapView, director: CombatDirector) -> void:
	_map_view = map_view
	_director = director
	z_as_relative = false
	z_index = 4
	EventBus.board_changed.connect(_on_board_changed)
	EventBus.preview_updated.connect(_on_preview_updated)
	EventBus.selection_changed.connect(func(_id: int) -> void: queue_redraw())


func set_board(board: BoardState) -> void:
	_board = board
	queue_redraw()


func set_preview_board(board: BoardState) -> void:
	_preview_board = board
	queue_redraw()


func set_drag_route(route: Array[Vector2i]) -> void:
	_route = route
	queue_redraw()


func clear_drag_route() -> void:
	_route.clear()
	queue_redraw()


func set_aim_mode(active: bool, local_pos: Vector2 = Vector2.ZERO, class_id: StringName = &"knight") -> void:
	_aiming = active
	_aim_local = local_pos
	_aim_class_id = class_id
	queue_redraw()


func _on_board_changed(board: BoardState) -> void:
	set_board(board)


func _on_preview_updated(result: SimResult) -> void:
	set_preview_board(result.final_state)


func _draw() -> void:
	if _board == null or _map_view == null:
		return
	var selected_id: int = _director.selected_unit_id if _director != null else -1
	var preview: BoardState = _preview_board if _preview_board != null else _board
	if preview != null and selected_id > 0:
		_draw_reach_tiles(preview, selected_id)
		var ghost := preview.get_unit_by_id(selected_id)
		if ghost != null and ghost.is_alive():
			draw_circle(_map_view.grid_to_local(ghost.position), 5.0, _COLOR_GHOST)
	if _route.size() >= 2:
		for i: int in range(_route.size() - 1):
			var a: Vector2 = _map_view.grid_to_local(_route[i])
			var b: Vector2 = _map_view.grid_to_local(_route[i + 1])
			draw_line(a, b, _COLOR_ROUTE, 2.0)
	if _aiming:
		ClassIconDrawer.draw_icon(self, _aim_local, _aim_class_id, _COLOR_AIM, 1.2)


func _draw_reach_tiles(state: BoardState, unit_id: int) -> void:
	var unit := state.get_unit_by_id(unit_id)
	if unit == null or not unit.is_alive():
		return
	var tiles: Array[Vector2i] = MovementSystem.get_reachable_tiles(
		state,
		unit.position,
		unit.movement.points_left,
		unit.definition.movement_type,
	)
	var tile_px: float = float(TacticalConstants.TILE_PX)
	for cell: Vector2i in tiles:
		var rect := Rect2(
			_map_view.grid_to_local(cell) - Vector2(tile_px * 0.5, tile_px * 0.5),
			Vector2(tile_px, tile_px),
		)
		draw_rect(rect, _COLOR_REACH, false, 1.0)
