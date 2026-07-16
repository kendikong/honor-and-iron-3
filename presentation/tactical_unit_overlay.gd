class_name TacticalUnitOverlay
extends Node2D

## Unit tokens + range tint on the mana-seed tactical map (Phase 4 shell).

const TOKEN_RADIUS: float = 6.0

var _map_view: TacticalMapView
var _director: CombatDirector
var _board: BoardState
var _preview_board: BoardState

const _COLOR_PLAYER := Color(0.36, 0.62, 0.92, 0.92)
const _COLOR_ENEMY := Color(0.86, 0.38, 0.34, 0.92)
const _COLOR_SELECT := Color(0.98, 0.86, 0.32, 0.95)
const _COLOR_GHOST := Color(0.98, 0.88, 0.38, 0.35)
const _COLOR_REACH := Color(0.28, 0.58, 0.48, 0.28)


func setup(map_view: TacticalMapView, director: CombatDirector) -> void:
	_map_view = map_view
	_director = director
	z_as_relative = false
	z_index = 6
	EventBus.selection_changed.connect(func(_id: int) -> void: queue_redraw())
	queue_redraw()


func set_board(board: BoardState) -> void:
	_board = board
	queue_redraw()


func set_preview_board(board: BoardState) -> void:
	_preview_board = board
	queue_redraw()


func apply_sim_event(event: SimEvent) -> void:
	if _board == null:
		return
	match event.type:
		GameEnums.SimEventType.UNIT_MOVED, GameEnums.SimEventType.UNIT_PUSHED:
			var unit_id: int = int(event.data.get("actor", event.data.get("unit", -1)))
			var to_coord: Variant = event.data.get("to", null)
			if to_coord is Vector2i:
				var unit := _board.get_unit_by_id(unit_id)
				if unit != null:
					unit.position = to_coord
		GameEnums.SimEventType.UNIT_DAMAGED:
			var target_id: int = int(event.data.get("unit", -1))
			var hp: int = int(event.data.get("hp", 0))
			var target := _board.get_unit_by_id(target_id)
			if target != null:
				target.health.current_hp = hp
		GameEnums.SimEventType.UNIT_DIED:
			var dead_id: int = int(event.data.get("unit", -1))
			var dead := _board.get_unit_by_id(dead_id)
			if dead != null:
				dead.health.current_hp = 0
	queue_redraw()


func handle_grid_click(cell: Vector2i) -> void:
	if _director == null or _board == null:
		return
	if (
		_director.phase != CombatDirector.Phase.PLANNING_PHASE_1
		and _director.phase != CombatDirector.Phase.PLANNING_PHASE_2
	):
		return
	var occupant := _board.get_unit_at(cell)
	if occupant != null and occupant.team == GameEnums.Team.PLAYER and occupant.is_alive():
		_director.select_unit(occupant.id)
		return
	if _director.selected_unit_id <= 0:
		return
	var actor := _board.get_unit_by_id(_director.selected_unit_id)
	if actor == null or not actor.is_alive():
		return
	if occupant != null and occupant.team == GameEnums.Team.ENEMY:
		_director.rpc_plan_attack(_director.selected_unit_id, _director.selected_ability_index, occupant.id)
		return
	var face: int = _facing_toward(actor.position, cell)
	_director.rpc_plan_move(_director.selected_unit_id, cell, face, [])


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


func _draw() -> void:
	if _board == null or _map_view == null:
		return
	var used: Rect2i = _map_view.get_ground_used_rect()
	if used.size == Vector2i.ZERO:
		return
	var selected_id: int = _director.selected_unit_id if _director != null else -1
	if _preview_board != null:
		_draw_reach_tiles(_preview_board, selected_id)
	for unit in _board.units:
		if not unit.is_alive():
			continue
		var center: Vector2 = _map_view.grid_to_local(unit.position)
		var color: Color = _COLOR_ENEMY if unit.team == GameEnums.Team.ENEMY else _COLOR_PLAYER
		if unit.id == selected_id:
			draw_arc(center, TOKEN_RADIUS + 3.0, 0.0, TAU, 24, _COLOR_SELECT, 2.0)
		draw_circle(center, TOKEN_RADIUS, color)
		draw_arc(center, TOKEN_RADIUS, 0.0, TAU, 20, Color(0.05, 0.05, 0.08, 0.8), 1.0)
	if _preview_board != null and selected_id > 0:
		var ghost := _preview_board.get_unit_by_id(selected_id)
		if ghost != null and ghost.is_alive():
			draw_circle(_map_view.grid_to_local(ghost.position), TOKEN_RADIUS - 1.0, _COLOR_GHOST)


func _draw_reach_tiles(state: BoardState, unit_id: int) -> void:
	if unit_id <= 0:
		return
	var unit := state.get_unit_by_id(unit_id)
	if unit == null or not unit.is_alive():
		return
	var tiles: Array[Vector2i] = MovementSystem.get_reachable_tiles(
		state,
		unit.position,
		unit.movement.points_left,
		unit.definition.movement_type,
	)
	for cell: Vector2i in tiles:
		var rect := Rect2(_map_view.grid_to_local(cell) - Vector2(TacticalConstants.TILE_PX * 0.5, TacticalConstants.TILE_PX * 0.5), Vector2(TacticalConstants.TILE_PX, TacticalConstants.TILE_PX))
		draw_rect(rect, _COLOR_REACH, false, 1.0)
