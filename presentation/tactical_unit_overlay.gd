class_name TacticalUnitOverlay
extends Node2D

## Unit tokens + range tint on the mana-seed tactical map (Phase 4 shell).

const TOKEN_RADIUS: float = 6.0

var _map_view: TacticalMapView
var _director: CombatDirector
var _board: BoardState
var _preview_board: BoardState
var _unit_layer: TacticalUnitLayer

const _COLOR_PLAYER := Color(0.36, 0.62, 0.92, 0.92)
const _COLOR_ENEMY := Color(0.86, 0.38, 0.34, 0.92)
const _COLOR_SELECT := Color(0.98, 0.86, 0.32, 0.95)


func setup(map_view: TacticalMapView, director: CombatDirector, unit_layer: TacticalUnitLayer = null) -> void:
	_map_view = map_view
	_director = director
	_unit_layer = unit_layer
	z_as_relative = false
	z_index = 7
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


func _draw() -> void:
	if _board == null or _map_view == null:
		return
	var used: Rect2i = _map_view.get_ground_used_rect()
	if used.size == Vector2i.ZERO:
		return
	var selected_id: int = _director.selected_unit_id if _director != null else -1
	for unit in _board.units:
		if not unit.is_alive():
			continue
		if _unit_layer != null and _unit_layer.is_sprites_active():
			continue
		var center: Vector2 = _map_view.grid_to_local(unit.position)
		var color: Color = _COLOR_ENEMY if unit.team == GameEnums.Team.ENEMY else _COLOR_PLAYER
		if unit.id == selected_id:
			draw_arc(center, TOKEN_RADIUS + 3.0, 0.0, TAU, 24, _COLOR_SELECT, 2.0)
		draw_circle(center, TOKEN_RADIUS, color)
		draw_arc(center, TOKEN_RADIUS, 0.0, TAU, 20, Color(0.05, 0.05, 0.08, 0.8), 1.0)
