class_name TacticalPlanningOverlay
extends Node2D

## Range tints, move route, aim icon, intent arrows, hover tile.

const _COLOR_MOVE := Color(0.35, 0.58, 0.92, 0.22)
const _COLOR_THREAT := Color(0.92, 0.38, 0.32, 0.20)
const _COLOR_MOVE_FILL_ALPHA: float = 0.40
const _COLOR_THREAT_FILL_ALPHA: float = 0.38
const _COLOR_ROUTE := Color(0.98, 0.88, 0.38, 0.95)
const _COLOR_GHOST := Color(0.98, 0.88, 0.38, 0.45)
const _COLOR_AIM := Color(0.95, 0.95, 1.0, 0.95)
const _COLOR_HOVER := Color(0.45, 0.75, 1.0)
const _COLOR_ENEMY_ARROW := Color(0.95, 0.35, 0.35, 0.95)
const _COLOR_PLAYER_ARROW := Color(0.45, 0.85, 0.55, 0.98)

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
var _cached_hover_unit_id: int = -1
var _cached_hover_origin: Vector2i = Vector2i(-999, -999)
var _cached_hover_ability: int = -1
var _cached_hover_force: bool = false
var _fixed_range_origin: Vector2i = Vector2i(-999, -999)
var _hover_action_icon: String = ""
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
	z_index = 5
	EventBus.board_changed.connect(_on_board_changed)
	EventBus.preview_updated.connect(_on_preview_updated)
	EventBus.selection_changed.connect(func(_id: int) -> void:
		_cached_hover_unit_id = -1
		recompute_hover_ranges(false, _director.selected_ability_index, false, -1)
		_update_hover_action_icon()
		queue_redraw(),
	)
	EventBus.ability_selected.connect(func(_idx: int) -> void:
		_cached_hover_unit_id = -1
		recompute_hover_ranges(false, _director.selected_ability_index, false, -1)
		_update_hover_action_icon()
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
	_update_hover_action_icon()
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


func set_fixed_range_origin(coord: Vector2i) -> void:
	_fixed_range_origin = coord


func clear_fixed_range_origin() -> void:
	_fixed_range_origin = Vector2i(-999, -999)


func set_hover_action_icon(icon: String) -> void:
	_hover_action_icon = icon
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
		_cached_hover_unit_id = -1
		return
	var origin: Vector2i = _proj_origin(unit)
	if dragging and _fixed_range_origin.x >= 0:
		origin = _fixed_range_origin
	var cache_ability: int = selected_ability if unit.id == _director.selected_unit_id else -1
	if (
		_cached_hover_unit_id == unit.id
		and _cached_hover_origin == origin
		and _cached_hover_ability == cache_ability
		and _cached_hover_force == force_basic
	):
		return
	_cached_hover_unit_id = unit.id
	_cached_hover_origin = origin
	_cached_hover_ability = cache_ability
	_cached_hover_force = force_basic
	if not unit.is_enemy() and unit.id == _director.selected_unit_id:
		var p_unit := _proj_unit(unit.id)
		if p_unit != null:
			if _phase == CombatDirector.Phase.PLANNING_PHASE_1 and p_unit.phase_1_action_used:
				return
			if _phase == CombatDirector.Phase.PLANNING_PHASE_2 and p_unit.phase_2_action_used:
				return
	var move_cost: int = 2 if unit.has_status(GameEnums.StatusType.BLEED) else 1
	var mt: int = unit.definition.movement_type if unit.definition != null else GameEnums.MovementType.WALK
	_hover_move_tiles = MovementSystem.get_reachable_tiles(
		_board,
		origin,
		unit.movement.points_left,
		mt,
		move_cost,
	)
	if force_basic and unit.id == _director.selected_unit_id and not unit.is_enemy():
		_add_attack_threat_tiles(unit, origin, selected_ability)
		return
	if unit.id == _director.selected_unit_id and not force_basic and selected_ability >= 0:
		var ability: AbilityData = _selected_ability_data(unit, selected_ability)
		if ability != null and AbilitySystem.ability_has_dash(ability):
			_hover_threat_tiles = _dash_threat_tiles(origin, _dash_amount(ability))
			if AbilitySystem.ability_blocks_basic_movement(ability):
				_hover_move_tiles.clear()
			return
		if _movement_blocked_by_dash(unit, selected_ability) and not force_basic:
			_hover_move_tiles.clear()
			var dash_ab: AbilityData = _selected_ability_data(unit, selected_ability)
			if dash_ab != null:
				_hover_threat_tiles = _dash_threat_tiles(origin, _dash_amount(dash_ab))
			return
		var self_aoe: Array[Vector2i] = _self_aoe_threat_tiles(unit, ability, origin)
		if not self_aoe.is_empty():
			_hover_threat_tiles = self_aoe
			return
	_add_attack_threat_tiles(unit, origin, selected_ability if unit.id == _director.selected_unit_id else -1)
	queue_redraw()


func _on_board_changed(board: BoardState) -> void:
	set_board(board)
	if _director != null:
		recompute_hover_ranges(false, _director.selected_ability_index, false, -1)


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
			draw_line(a, b, _COLOR_ROUTE, 3.0)
	_draw_ability_intents()
	_draw_hover_tile()
	if _aiming:
		ClassIconDrawer.draw_icon(self, _aim_local, _aim_class_id, _COLOR_AIM, 1.2)
	if _hover_action_icon != "":
		_draw_centered_icon(get_global_mouse_position() + Vector2(10.0, 10.0), _hover_action_icon, Color.WHITE, 28)


func _draw_hover_tiles() -> void:
	for cell: Vector2i in _hover_threat_tiles:
		_draw_tile_tint(cell, _COLOR_THREAT, _COLOR_THREAT_FILL_ALPHA)
	for cell: Vector2i in _hover_move_tiles:
		_draw_tile_tint(cell, _COLOR_MOVE, _COLOR_MOVE_FILL_ALPHA)


func _draw_tile_tint(cell: Vector2i, tint: Color, fill_alpha: float) -> void:
	var tile_px: float = float(TacticalConstants.TILE_PX)
	var rect := Rect2(
		_map_view.grid_to_local(cell) - Vector2(tile_px * 0.5, tile_px * 0.5),
		Vector2(tile_px, tile_px),
	).grow(-2.0)
	draw_rect(rect, Color(tint.r, tint.g, tint.b, fill_alpha), true)
	draw_rect(rect, Color(tint.r, tint.g, tint.b, 0.9), false, 2.0)


func _draw_hover_tile() -> void:
	if not _board.is_in_bounds(_hover_coord):
		return
	var tile_px: float = float(TacticalConstants.TILE_PX)
	var center: Vector2 = _map_view.grid_to_local(_hover_coord)
	var rect := Rect2(center - Vector2(tile_px * 0.5, tile_px * 0.5), Vector2(tile_px, tile_px)).grow(-2.0)
	draw_rect(rect, Color(_COLOR_HOVER, 0.28), true)
	draw_rect(rect, _COLOR_HOVER, false, 2.5)


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
		draw_circle(p1 + dir * d, 4.0, color)
		d += 7.0


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
		draw_line(a, b, color, 3.0)


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
		draw_circle(p1 + dir * d, 4.0, color)
		d += 7.0


func _proj_unit(unit_id: int) -> UnitState:
	if _preview_board != null:
		var u := _preview_board.get_unit_by_id(unit_id)
		if u != null:
			return u
	if _board != null:
		return _board.get_unit_by_id(unit_id)
	return null


func _proj_origin(unit: UnitState) -> Vector2i:
	var pv := _proj_unit(unit.id)
	if pv != null:
		return pv.position
	return unit.position


func _selected_ability_data(unit: UnitState, ability_index: int) -> AbilityData:
	if unit == null or ability_index < 0 or ability_index >= unit.active_abilities.size():
		return null
	return unit.active_abilities[ability_index]


func _dash_amount(ability: AbilityData) -> int:
	if ability == null:
		return 0
	for eff: EffectData in ability.effects:
		if eff.type == GameEnums.EffectType.DASH:
			return eff.amount
	return 0


func _dash_threat_tiles(origin: Vector2i, steps: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for dir: Vector2i in GridSystem.DIRECTIONS:
		for i: int in range(1, steps + 1):
			var coord: Vector2i = origin + dir * i
			if _board.is_in_bounds(coord):
				tiles.append(coord)
	return tiles


func _movement_blocked_by_dash(unit: UnitState, selected_ability: int) -> bool:
	var ability: AbilityData = _selected_ability_data(unit, selected_ability)
	return ability != null and AbilitySystem.ability_blocks_basic_movement(ability)


func _self_aoe_threat_tiles(unit: UnitState, ability: AbilityData, origin: Vector2i) -> Array[Vector2i]:
	if ability == null or ability.target_shape == GameEnums.TargetShape.SINGLE:
		return []
	if ability.range_tiles != 0:
		return []
	var shape: GameEnums.TargetShape = ability.target_shape
	var shape_size: int = ability.target_shape_size
	if unit.is_ability_upgraded(ability.id):
		if ability.upgraded_target_shape != GameEnums.TargetShape.SINGLE:
			shape = ability.upgraded_target_shape
		if ability.upgraded_target_shape_size >= 0:
			shape_size = ability.upgraded_target_shape_size
	return GridSystem.get_affected_tiles(_board, origin, origin, shape, shape_size)


func _unit_attack_range(unit: UnitState, selected_ability: int) -> int:
	if unit == null:
		return 0
	if unit.id == _director.selected_unit_id and selected_ability >= 0:
		var ability: AbilityData = _selected_ability_data(unit, selected_ability)
		if ability != null:
			return unit.get_ability_range(ability)
	if unit.is_enemy() and unit.definition != null and unit.definition.behavior != null:
		var att: AbilityData = unit.definition.behavior.attack
		if att != null:
			return att.range_tiles
	var best: int = 0
	for ability: AbilityData in unit.active_abilities:
		best = maxi(best, unit.get_ability_range(ability))
	return best


func _add_attack_threat_tiles(unit: UnitState, origin: Vector2i, selected_ability: int) -> void:
	var rng: int = _unit_attack_range(unit, selected_ability)
	if rng <= 0:
		return
	var threat_sources: Array[Vector2i] = [origin]
	if unit.is_enemy():
		threat_sources = _hover_move_tiles.duplicate()
		if threat_sources.is_empty():
			threat_sources = [origin]
	for y: int in range(_board.grid_size.y):
		for x: int in range(_board.grid_size.x):
			var coord := Vector2i(x, y)
			for src: Vector2i in threat_sources:
				if GridSystem.manhattan(coord, src) <= rng:
					_hover_threat_tiles.append(coord)
					break


func _draw_centered_icon(pos: Vector2, text: String, color: Color, size_px: int) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
	draw_string(font, pos - Vector2(sz.x * 0.5, sz.y * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func _update_hover_action_icon() -> void:
	_hover_action_icon = ""
	if _director == null or _board == null or not _board.is_in_bounds(_hover_coord):
		return
	var sel_id: int = _director.selected_unit_id
	if sel_id < 0:
		return
	var unit := _proj_unit(sel_id)
	if unit == null or not unit.is_alive():
		return
	if _aiming:
		var ability: AbilityData = _selected_ability_data(unit, _director.selected_ability_index)
		if ability != null:
			_hover_action_icon = _ability_action_icon(ability)
		return
	var occ := _board.get_unit_at(_hover_coord)
	if occ != null and occ.is_enemy() and occ.id != sel_id:
		_hover_action_icon = "⚔️"
	elif _hover_move_tiles.has(_hover_coord):
		_hover_action_icon = "🏃"


func _ability_action_icon(ability: AbilityData) -> String:
	if ability == null:
		return ""
	if AbilitySystem.ability_is_offensive_dash(ability):
		return "⚔️"
	if AbilitySystem.ability_has_dash(ability):
		return "✨"
	for eff: EffectData in ability.effects:
		match eff.type:
			GameEnums.EffectType.DAMAGE:
				return "⚔️"
			GameEnums.EffectType.HEAL:
				return "💚"
			GameEnums.EffectType.ARMOR_UP:
				return "🛡️"
			GameEnums.EffectType.SWAP:
				return "🔄"
	return "✨"
