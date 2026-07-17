class_name TacticalPlanningOverlay
extends Node2D

## Range tints, move route, aim icon, intent arrows, hover tile.

const _COLOR_REACH := Color(0.28, 0.58, 0.48, 0.28)
const _COLOR_THREAT := Color(0.95, 0.45, 0.35, 0.22)
const _COLOR_ROUTE := Color(0.98, 0.88, 0.38, 0.85)
const _COLOR_GHOST := Color(0.98, 0.88, 0.38, 0.35)
const _COLOR_AIM := Color(0.95, 0.95, 1.0, 0.95)
const _COLOR_HOVER := Color(0.45, 0.75, 1.0)
const _COLOR_ENEMY_ARROW := Color(0.95, 0.35, 0.35, 0.9)
const _COLOR_PLAYER_ARROW := Color(0.45, 0.85, 0.55, 0.95)

var _map_view: TacticalMapView
var _director: CombatDirector
var _intent_state: CombatIntentState
var _board: BoardState
var _preview_board: BoardState
var _route: Array[Vector2i] = []
var _aiming: bool = false
var _aim_local: Vector2 = Vector2.ZERO
var _aim_class_id: StringName = &"knight"
var _hover_coord: Vector2i = Vector2i(-999, -999)
var _phase: int = CombatDirector.Phase.PLANNING_PHASE_1
var _hover_move_tiles: Array[Vector2i] = []
var _hover_threat_tiles: Array[Vector2i] = []
var _live_preview: CombatPlanningPreview = CombatPlanningPreview.new()
var _unit_layer: TacticalUnitLayer
var _attack_target_id: int = -1


func setup(
	map_view: TacticalMapView,
	director: CombatDirector,
	intent_state: CombatIntentState = null,
) -> void:
	_map_view = map_view
	_director = director
	_intent_state = intent_state
	z_as_relative = false
	z_index = 4
	EventBus.board_changed.connect(_on_board_changed)
	EventBus.preview_updated.connect(_on_preview_updated)
	EventBus.selection_changed.connect(func(_id: int) -> void:
		recompute_hover_ranges(false, _director.selected_ability_index, false, -1)
		queue_redraw(),
	)
	EventBus.turn_phase_changed.connect(func(phase: int) -> void:
		_phase = phase
		queue_redraw(),
	)
	if _intent_state != null:
		_intent_state.intents_changed.connect(func(_units: Dictionary) -> void: queue_redraw())
		_intent_state.hover_coord_changed.connect(func(coord: Vector2i) -> void:
			_hover_coord = coord
			queue_redraw(),
		)


func bind_unit_layer(layer: TacticalUnitLayer) -> void:
	_unit_layer = layer


func get_preview_board() -> BoardState:
	return _preview_board


func clear_live_preview() -> void:
	_live_preview.clear_all()
	_attack_target_id = -1
	if _unit_layer != null:
		_unit_layer.clear_predicted_stats()
	queue_redraw()


func apply_preview_state(
	state: CombatPlanningPreview,
	selected_id: int,
	attack_target_id: int,
) -> void:
	_live_preview = state
	_attack_target_id = attack_target_id
	if state.preview_board != null:
		_preview_board = state.preview_board
	if _unit_layer != null:
		_unit_layer.set_predicted_stats(state.predicted_hp, state.predicted_armor)
	queue_redraw()


func set_live_preview(state: CombatPlanningPreview) -> void:
	_live_preview = state
	queue_redraw()


func set_board(board: BoardState) -> void:
	_board = board
	queue_redraw()


func set_preview_board(board: BoardState) -> void:
	_preview_board = board
	queue_redraw()


func set_hover_coord(coord: Vector2i) -> void:
	if coord == _hover_coord:
		return
	_hover_coord = coord
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


func recompute_hover_ranges(
	force_basic: bool,
	selected_ability: int,
	dragging: bool,
	drag_unit_id: int,
) -> void:
	_hover_move_tiles.clear()
	_hover_threat_tiles.clear()
	if _board == null or _director == null:
		return
	var unit: UnitState = null
	if dragging and drag_unit_id >= 0:
		unit = _board.get_unit_by_id(drag_unit_id)
	elif _director.selected_unit_id >= 0:
		unit = _board.get_unit_by_id(_director.selected_unit_id)
	if unit == null or not unit.is_alive():
		return
	var origin: Vector2i = unit.position
	var proj := _preview_board if _preview_board != null else _board
	var pv := proj.get_unit_by_id(unit.id)
	if pv != null:
		origin = pv.position
	if not unit.is_enemy() and not force_basic and selected_ability >= 0:
		if selected_ability < unit.active_abilities.size():
			var ability: AbilityData = unit.active_abilities[selected_ability]
			if AbilitySystem.ability_has_dash(ability):
				for dir in GridSystem.DIRECTIONS:
					for i in range(1, ability.range_tiles + 1):
						var coord: Vector2i = origin + dir * i
						if _board.is_in_bounds(coord):
							_hover_threat_tiles.append(coord)
				if AbilitySystem.ability_blocks_basic_movement(ability):
					return
	var move_cost: int = 2 if unit.has_status(GameEnums.StatusType.BLEED) else 1
	var mt: int = unit.definition.movement_type if unit.definition != null else GameEnums.MovementType.WALK
	_hover_move_tiles = MovementSystem.get_reachable_tiles(
		proj,
		origin,
		unit.movement.points_left,
		mt,
		move_cost,
	)
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
		var ghost := preview.get_unit_by_id(selected_id)
		if ghost != null and ghost.is_alive():
			draw_circle(_map_view.grid_to_local(ghost.position), 5.0, _COLOR_GHOST)
	_draw_hover_tiles()
	_draw_preview_arrows()
	_draw_interaction_overlay()
	if _route.size() >= 2:
		for i: int in range(_route.size() - 1):
			var a: Vector2 = _map_view.grid_to_local(_route[i])
			var b: Vector2 = _map_view.grid_to_local(_route[i + 1])
			draw_line(a, b, _COLOR_ROUTE, 2.0)
	_draw_ability_intents()
	_draw_hover_tile()
	if _aiming:
		ClassIconDrawer.draw_icon(self, _aim_local, _aim_class_id, _COLOR_AIM, 1.2)


func _draw_hover_tiles() -> void:
	var tile_px: float = float(TacticalConstants.TILE_PX)
	for cell: Vector2i in _hover_move_tiles:
		var rect := Rect2(
			_map_view.grid_to_local(cell) - Vector2(tile_px * 0.5, tile_px * 0.5),
			Vector2(tile_px, tile_px),
		)
		draw_rect(rect, _COLOR_REACH, false, 1.0)
	for cell: Vector2i in _hover_threat_tiles:
		var rect2 := Rect2(
			_map_view.grid_to_local(cell) - Vector2(tile_px * 0.5, tile_px * 0.5),
			Vector2(tile_px, tile_px),
		)
		draw_rect(rect2, _COLOR_THREAT, true)
		draw_rect(rect2, _COLOR_THREAT, false, 1.0)


func _draw_hover_tile() -> void:
	if not _board.is_in_bounds(_hover_coord):
		return
	var tile_px: float = float(TacticalConstants.TILE_PX)
	var center: Vector2 = _map_view.grid_to_local(_hover_coord)
	var rect := Rect2(center - Vector2(tile_px * 0.5, tile_px * 0.5), Vector2(tile_px, tile_px)).grow(-2.0)
	draw_rect(rect, Color(_COLOR_HOVER, 0.12), true)
	draw_rect(rect, _COLOR_HOVER, false, 2.0)


func _draw_ability_intents() -> void:
	if _director == null or _board == null:
		return
	var plan_to_use: Timeline = (
		_director.plan_phase_1
		if _phase == CombatDirector.Phase.PLANNING_PHASE_1
		else _director.plan_phase_2
	)
	if plan_to_use != null:
		for action: TimelineAction in plan_to_use.entries:
			if action.type != GameEnums.ActionType.ABILITY:
				continue
			var actor := _board.get_unit_by_id(action.actor_id)
			if actor == null:
				continue
			var start_pos: Vector2i = actor.position
			for act: TimelineAction in plan_to_use.entries:
				if act.actor_id == action.actor_id and act.type == GameEnums.ActionType.MOVE:
					start_pos = act.target_coord
					break
			_draw_dashed_route([start_pos, action.target_coord], _COLOR_PLAYER_ARROW)
	for intent in _board.intents:
		var enemy := _board.get_unit_by_id(intent.enemy_id)
		if enemy == null or not enemy.is_alive():
			continue
		if not _intent_visible(enemy):
			continue
		var enemy_pos: Vector2i = enemy.position
		var pv := _preview_board.get_unit_by_id(enemy.id) if _preview_board != null else null
		if pv != null:
			enemy_pos = pv.position
		for action: TimelineAction in intent.actions:
			if action.type == GameEnums.ActionType.ABILITY:
				_draw_dashed_route([enemy_pos, action.target_coord], _COLOR_ENEMY_ARROW)


func _intent_visible(unit: UnitState) -> bool:
	if _intent_state != null:
		return _intent_state.intent_visible(unit)
	if not unit.is_enemy():
		return true
	return _phase == CombatDirector.Phase.ENEMY_TURN


func _draw_dashed_route(cells: Array, color: Color) -> void:
	if cells.size() < 2:
		return
	var p1: Vector2 = _map_view.grid_to_local(cells[0])
	var p2: Vector2 = _map_view.grid_to_local(cells[cells.size() - 1])
	var dir: Vector2 = (p2 - p1).normalized()
	var end_d: float = p1.distance_to(p2)
	var d: float = 0.0
	while d < end_d:
		draw_circle(p1 + dir * d, 2.5, color)
		d += 8.0


func _draw_preview_arrows() -> void:
	if _board == null or _live_preview.preview_board == null:
		return
	for unit: UnitState in _board.units:
		if not unit.is_alive() or not _intent_visible(unit):
			continue
		var route: Array = _live_preview.preview_paths.get(unit.id, [])
		if route.size() < 2:
			continue
		var split: int = int(_live_preview.preview_splits.get(unit.id, route.size()))
		var player_leg: Array = route.slice(0, split)
		if player_leg.size() >= 2:
			_draw_route_line(player_leg, _COLOR_PLAYER_ARROW.lightened(0.2), true)
		var pushes: Array = _live_preview.preview_pushes.get(unit.id, [])
		for push: Variant in pushes:
			if push is Array and push.size() >= 2:
				_draw_push_arrow(push[0], push[1])


func _draw_interaction_overlay() -> void:
	if _director == null or _director.selected_unit_id < 0:
		return
	var actor := _live_preview.preview_board.get_unit_by_id(_director.selected_unit_id) \
		if _live_preview.preview_board != null else _board.get_unit_by_id(_director.selected_unit_id)
	if actor == null:
		return
	var route: Array = _live_preview.preview_paths.get(actor.id, [])
	if route.size() >= 2:
		_draw_route_line(route, _COLOR_PLAYER_ARROW, true)
	if _attack_target_id >= 0:
		var origin: Vector2i = actor.position
		var target_coord: Vector2i = _hover_coord
		var target_unit := _live_preview.preview_board.get_unit_by_id(_attack_target_id) \
			if _live_preview.preview_board != null else _board.get_unit_by_id(_attack_target_id)
		if target_unit != null:
			target_coord = target_unit.position
		if origin != target_coord:
			_draw_dashed_route([origin, target_coord], _COLOR_PLAYER_ARROW)


func _draw_route_line(route: Array, color: Color, cardinal_only: bool) -> void:
	if route.size() < 2:
		return
	for i: int in range(route.size() - 1):
		var a: Vector2 = _map_view.grid_to_local(route[i])
		var b: Vector2 = _map_view.grid_to_local(route[i + 1])
		draw_line(a, b, color, 2.0)


func _draw_push_arrow(from: Vector2i, to: Vector2i) -> void:
	var p1: Vector2 = _map_view.grid_to_local(from)
	var p2: Vector2 = _map_view.grid_to_local(to)
	var dir: Vector2 = (p2 - p1).normalized()
	var dist: float = p1.distance_to(p2)
	var start_d: float = 8.0
	var end_d: float = dist - 8.0
	if start_d >= end_d:
		return
	var color := Color(1.0, 0.65, 0.2, 0.95)
	var d: float = start_d
	while d < end_d:
		draw_circle(p1 + dir * d, 2.5, color)
		d += 8.0
