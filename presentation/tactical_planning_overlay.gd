class_name TacticalPlanningOverlay
extends Node2D

## Range tints, move route, aim icon, intent arrows, hover tile.

const _COLOR_MOVE := Color(0.35, 0.58, 0.92, 0.22)
const _COLOR_THREAT := Color(0.92, 0.38, 0.32, 0.20)
const _COLOR_MOVE_FILL_ALPHA: float = 0.22
const _COLOR_THREAT_FILL_ALPHA: float = 0.18
const _COLOR_TILE_BORDER_ALPHA: float = 0.32
const _COLOR_ROUTE := Color(0.98, 0.88, 0.38, 0.95)
const _COLOR_GHOST := Color(0.98, 0.88, 0.38, 0.45)
const _COLOR_AIM := Color(0.95, 0.95, 1.0, 0.95)
const _COLOR_HOVER := Color(0.45, 0.75, 1.0)
const _COLOR_ENEMY_ARROW := Color(0.95, 0.35, 0.35, 0.95)
const _COLOR_PLAYER_ARROW := Color(0.45, 0.85, 0.55, 0.98)
const _COLOR_TARGET := Color(0.98, 0.72, 0.38, 0.85)
const _COLOR_DRAGPATH := Color(0.98, 0.88, 0.38, 0.95)
const _COLOR_DANGER := Color(0.9, 0.2, 0.2, 0.2)
const _COLOR_SELECT_TILE := Color(0.98, 0.86, 0.32, 0.35)
## Route widths in map-local px (MapRoot scale applies on screen — do not divide by ui_scale).
const _ROUTE_GLOW_W: float = 5.0
const _ROUTE_LINE_W: float = 3.0
const _ROUTE_HEAD_LEN: float = 10.0
const _ROUTE_HEAD_PERP: float = 5.0
const _DASH_LINE_W: float = 2.0
const _DASH_WING_LEN: float = 5.0
const _INTENT_ROUTE_ALPHA: float = 0.40

signal live_preview_changed

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
var _committed_preview: CombatPlanningPreview = CombatPlanningPreview.new()
var _stashed_committed: CombatPlanningPreview = CombatPlanningPreview.new()
var _has_stashed_committed: bool = false
var _unit_layer: TacticalUnitLayer
var _planning_input: CombatPlanningInput
var _attack_target_id: int = -1
var _show_danger_area: bool = false
var _danger_tiles_cache: Dictionary = {}
var _danger_tiles_dirty: bool = true
var _hit_markers: Array = []


func setup(
	map_view: TacticalMapView,
	director: CombatDirector,
	intent_state: CombatIntentState = null,
) -> void:
	_map_view = map_view
	_director = director
	_intent_state = intent_state
	z_as_relative = false
	z_index = 8
	EventBus.board_changed.connect(_on_board_changed)
	EventBus.preview_updated.connect(_on_preview_updated)
	EventBus.selection_changed.connect(func(_id: int) -> void:
		if _director == null:
			return
		_invalidate_hover_cache()
		_recompute_hover_ranges_from_inputs()
		_update_hover_action_icon()
		queue_redraw(),
	)
	EventBus.ability_selected.connect(func(_idx: int) -> void:
		if _director == null:
			return
		_invalidate_hover_cache()
		_recompute_hover_ranges_from_inputs()
		_update_hover_action_icon()
		queue_redraw(),
	)
	EventBus.turn_phase_changed.connect(func(phase: int) -> void:
		_phase = phase
		var planning: bool = phase in [
			CombatDirector.Phase.PLANNING_PHASE_1,
			CombatDirector.Phase.PLANNING_PHASE_2,
		]
		if not planning and _planning_input != null:
			_planning_input.clear_interaction_preview()
		_invalidate_hover_cache()
		if planning:
			_recompute_hover_ranges_from_inputs()
		else:
			_hover_move_tiles.clear()
			_hover_threat_tiles.clear()
		mark_danger_dirty()
		queue_redraw(),
	)
	EventBus.sim_event.connect(_on_sim_event)
	if _intent_state != null:
		_intent_state.intents_changed.connect(func(_units: Dictionary) -> void: queue_redraw())
		_intent_state.hover_coord_changed.connect(func(coord: Vector2i) -> void:
			_hover_coord = coord
			if _director != null and _director.selected_unit_id < 0:
				_invalidate_hover_cache()
				_recompute_hover_ranges_from_inputs()
			queue_redraw(),
		)
	set_process(true)


func set_show_danger_area(enabled: bool) -> void:
	_show_danger_area = enabled
	queue_redraw()


func mark_danger_dirty() -> void:
	_danger_tiles_dirty = true


func get_show_danger_area() -> bool:
	return _show_danger_area


func bind_unit_layer(layer: TacticalUnitLayer) -> void:
	_unit_layer = layer


func bind_planning_input(input: CombatPlanningInput) -> void:
	_planning_input = input
	_invalidate_hover_cache()
	_recompute_hover_ranges_from_inputs()


func _invalidate_hover_cache() -> void:
	_cached_hover_unit_id = -1
	_cached_hover_origin = Vector2i(-999, -999)
	_cached_hover_ability = -1


func _recompute_hover_ranges_from_inputs() -> void:
	if _director == null:
		return
	var force_basic: bool = _planning_input.force_basic_movement if _planning_input != null else false
	var dragging: bool = _planning_input.dragging if _planning_input != null else false
	var drag_id: int = _planning_input.get_drag_unit_id() if _planning_input != null else -1
	recompute_hover_ranges(force_basic, _director.selected_ability_index, dragging, drag_id)


func get_preview_board() -> BoardState:
	if _committed_preview.preview_board != null:
		return _committed_preview.preview_board
	return _preview_board


func get_live_intents() -> Array:
	return _live_preview.live_intents


func get_live_preview() -> CombatPlanningPreview:
	return _live_preview


func clear_live_preview() -> void:
	restore_committed_display()


func stash_committed_preview() -> void:
	_stashed_committed.copy_from(_committed_preview)
	_has_stashed_committed = true


func restore_stashed_committed() -> void:
	if _has_stashed_committed:
		_committed_preview.copy_from(_stashed_committed)
		_preview_board = _committed_preview.preview_board
		_has_stashed_committed = false
	restore_committed_display()


func restore_committed_display() -> void:
	_live_preview.clear_interaction()
	_live_preview.preview_board = null
	_live_preview.preview_paths.clear()
	_live_preview.preview_splits.clear()
	_live_preview.preview_pushes.clear()
	_attack_target_id = -1
	_preview_board = _committed_preview.preview_board
	if _unit_layer != null:
		_unit_layer.set_predicted_stats(
			_committed_preview.predicted_hp,
			_committed_preview.predicted_armor,
		)
	live_preview_changed.emit()
	queue_redraw()


func apply_preview_state(
	state: CombatPlanningPreview,
	selected_id: int,
	attack_target_id: int,
) -> void:
	_live_preview.copy_from(state)
	_attack_target_id = attack_target_id
	if _unit_layer != null:
		_unit_layer.set_predicted_stats(state.predicted_hp, state.predicted_armor)
	live_preview_changed.emit()
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
	if _director != null and _director.selected_unit_id < 0:
		_invalidate_hover_cache()
		_recompute_hover_ranges_from_inputs()
	if _planning_input != null:
		_planning_input.refresh_mouse_cursor(coord)
	else:
		_update_hover_action_icon()
	queue_redraw()


func begin_drag_sprite(unit_id: int) -> void:
	if _unit_layer != null:
		_unit_layer.begin_drag_preview(unit_id)


func update_drag_sprite(
	map_local: Vector2,
	anim_mode: int,
	facing: int,
	preview_cell: Vector2i,
	failed: bool = false,
) -> void:
	if _unit_layer != null:
		_unit_layer.update_drag_preview(map_local, anim_mode, facing, preview_cell, failed)


func end_drag_sprite() -> void:
	if _unit_layer != null:
		_unit_layer.end_drag_preview()


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
	if active and _map_view != null:
		var cell: Vector2i = _map_view.screen_to_grid(_map_view.get_viewport().get_mouse_position())
		if _board != null and _board.is_in_bounds(cell):
			_hover_coord = cell
	if _planning_input != null:
		_planning_input.refresh_mouse_cursor(_hover_coord)
	elif active:
		_update_hover_action_icon()
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
	if _board == null or _director == null:
		return
	var unit: UnitState = null
	if dragging and drag_unit_id >= 0:
		unit = _board.get_unit_by_id(drag_unit_id)
	elif _director.selected_unit_id >= 0:
		unit = _board.get_unit_by_id(_director.selected_unit_id)
	elif _board.is_in_bounds(_hover_coord):
		unit = _board.get_unit_at(_hover_coord)
	if unit == null or not unit.is_alive():
		_invalidate_hover_cache()
		_hover_move_tiles.clear()
		_hover_threat_tiles.clear()
		queue_redraw()
		return
	var origin: Vector2i = _proj_origin(unit)
	if dragging and _fixed_range_origin.x >= 0:
		origin = _fixed_range_origin
	var cache_ability: int = selected_ability if unit.id == _director.selected_unit_id else -1
	var cache_force: bool = force_basic if unit.id == _director.selected_unit_id else false
	if (
		_cached_hover_unit_id == unit.id
		and _cached_hover_origin == origin
		and _cached_hover_ability == cache_ability
		and _cached_hover_force == cache_force
	):
		return
	_cached_hover_unit_id = unit.id
	_cached_hover_origin = origin
	_cached_hover_ability = cache_ability
	_cached_hover_force = cache_force
	_hover_move_tiles.clear()
	_hover_threat_tiles.clear()
	var move_cost: int = 2 if unit.has_status(GameEnums.StatusType.BLEED) else 1
	var mt: int = (
		unit.definition.movement_type
		if unit.definition != null
		else GameEnums.MovementType.WALK
	)
	var exhausted := false
	if not unit.is_enemy() and unit.id == _director.selected_unit_id:
		var p_unit := _proj_unit(unit.id)
		if p_unit != null:
			if _phase == CombatDirector.Phase.PLANNING_PHASE_1:
				exhausted = p_unit.phase_1_action_used
			elif _phase == CombatDirector.Phase.PLANNING_PHASE_2:
				exhausted = p_unit.phase_2_action_used
	if exhausted:
		if not unit.is_enemy() and unit.id == _director.selected_unit_id:
			var p_exhausted := _proj_unit(unit.id)
			if p_exhausted != null:
				var sim_board: BoardState = (
					_director.projected_state if _director.projected_state != null else _board
				)
				var bleed_cost: int = (
					2 if p_exhausted.has_status(GameEnums.StatusType.BLEED) else 1
				)
				var p_mt: int = (
					p_exhausted.definition.movement_type
					if p_exhausted.definition != null
					else GameEnums.MovementType.WALK
				)
				_hover_move_tiles = MovementSystem.get_reachable_tiles(
					sim_board,
					p_exhausted.position,
					p_exhausted.movement.points_left,
					p_mt,
					bleed_cost,
				)
				if selected_ability >= 0:
					var p_origin: Vector2i = p_exhausted.position
					var ability: AbilityData = _selected_ability_data(p_exhausted, selected_ability)
					if ability != null and AbilitySystem.ability_has_dash(ability):
						_hover_threat_tiles = _dash_threat_tiles(p_origin, _dash_amount(ability))
					else:
						var self_aoe: Array[Vector2i] = _self_aoe_threat_tiles(
							p_exhausted, ability, p_origin,
						)
						if not self_aoe.is_empty():
							_hover_threat_tiles = self_aoe
						else:
							_populate_attack_threat_tiles(p_exhausted, p_origin, selected_ability)
		queue_redraw()
		return
	_hover_move_tiles = MovementSystem.get_reachable_tiles(
		_board,
		origin,
		unit.movement.points_left,
		mt,
		move_cost,
	)
	if force_basic and unit.id == _director.selected_unit_id and not unit.is_enemy():
		_populate_attack_threat_tiles(unit, origin, selected_ability)
		queue_redraw()
		return
	if unit.id == _director.selected_unit_id and not force_basic and selected_ability >= 0:
		var ability: AbilityData = _selected_ability_data(unit, selected_ability)
		if ability != null and AbilitySystem.ability_has_dash(ability):
			_hover_threat_tiles = _dash_threat_tiles(origin, _dash_amount(ability))
			if AbilitySystem.ability_blocks_basic_movement(ability):
				_hover_move_tiles.clear()
			queue_redraw()
			return
		if _movement_blocked_by_dash(unit, selected_ability) and not force_basic:
			_hover_move_tiles.clear()
			var dash_ab: AbilityData = _selected_ability_data(unit, selected_ability)
			if dash_ab != null:
				_hover_threat_tiles = _dash_threat_tiles(origin, _dash_amount(dash_ab))
			queue_redraw()
			return
		var self_aoe: Array[Vector2i] = _self_aoe_threat_tiles(unit, ability, origin)
		if not self_aoe.is_empty():
			_hover_threat_tiles = self_aoe
			queue_redraw()
			return
	_populate_attack_threat_tiles(
		unit,
		origin,
		selected_ability if unit.id == _director.selected_unit_id else -1,
	)
	queue_redraw()


func _on_board_changed(board: BoardState) -> void:
	set_board(board)
	_danger_tiles_dirty = true
	_invalidate_hover_cache()
	_recompute_hover_ranges_from_inputs()


func _process(delta: float) -> void:
	for i: int in range(_hit_markers.size() - 1, -1, -1):
		var entry: Array = _hit_markers[i]
		entry[1] = float(entry[1]) - delta
		if float(entry[1]) <= 0.0:
			_hit_markers.remove_at(i)
	if _phase in [
		CombatDirector.Phase.PLANNING_PHASE_1,
		CombatDirector.Phase.PLANNING_PHASE_2,
	]:
		queue_redraw()
	elif not _hit_markers.is_empty():
		queue_redraw()


func _on_sim_event(event: SimEvent) -> void:
	if event == null or _board == null or _map_view == null:
		return
	if event.type in [
		GameEnums.SimEventType.UNIT_DAMAGED,
		GameEnums.SimEventType.UNIT_DIED,
	]:
		var unit_id: int = int(event.data.get("unit", event.data.get("actor", -1)))
		var marker_pos: Vector2i = Vector2i(-999, -999)
		if event.data.has("to") and event.data["to"] is Vector2i:
			marker_pos = event.data["to"]
		elif event.data.has("position") and event.data["position"] is Vector2i:
			marker_pos = event.data["position"]
		if marker_pos.x <= -900:
			var unit := _board.get_unit_by_id(unit_id)
			if unit != null:
				marker_pos = unit.position
			elif _committed_preview.preview_board != null:
				var pv := _committed_preview.preview_board.get_unit_by_id(unit_id)
				if pv != null:
					marker_pos = pv.position
		if _board.is_in_bounds(marker_pos):
			_hit_markers.append([marker_pos, 0.4])


func _on_preview_updated(result: SimResult) -> void:
	set_preview_board(result.final_state)
	_invalidate_hover_cache()
	if _director != null and _board != null:
		_committed_preview = CombatPlanningPreview.from_sim_result(result, _director, _board)
		_preview_board = _committed_preview.preview_board
	_has_stashed_committed = false
	_recompute_hover_ranges_from_inputs()
	if _planning_input == null or not _planning_input.is_live_preview_active():
		if _unit_layer != null:
			_unit_layer.set_predicted_stats(
				_committed_preview.predicted_hp,
				_committed_preview.predicted_armor,
			)
		live_preview_changed.emit()
	queue_redraw()


func _draw() -> void:
	if _board == null or _map_view == null or _director == null:
		return
	var show_planning: bool = _phase in [
		CombatDirector.Phase.PLANNING_PHASE_1,
		CombatDirector.Phase.PLANNING_PHASE_2,
	]
	if show_planning:
		_draw_selected_unit_tile()
		_draw_danger_area()
		_draw_move_ghosts()
	_draw_hover_tiles()
	_draw_target_rings()
	if show_planning:
		_draw_ghosts()
		_draw_preview_arrows()
		if _should_draw_interaction_overlay():
			_draw_interaction_overlay()
		if _planning_input != null and _planning_input.dragging:
			_draw_drag_path()
	elif _route.size() >= 2:
		_draw_route_line(_route, _COLOR_ROUTE, true, true)
	_draw_ability_intents()
	_draw_hover_tile()
	if _aiming:
		var aim_scale: float = 0.55 / _ui_scale()
		ClassIconDrawer.draw_icon(self, _aim_local, _aim_class_id, _COLOR_AIM, aim_scale)
	if _hover_action_icon != "":
		var icon_pos: Vector2 = get_local_mouse_position() + Vector2(10.0, 10.0) / _ui_scale()
		ActionIconDrawer.draw(
			self,
			icon_pos,
			ActionIconDrawer.key_from_emoji(_hover_action_icon),
			Color.WHITE,
			1.15 / _ui_scale(),
		)
	for entry: Array in _hit_markers:
		if entry.size() >= 2 and entry[0] is Vector2i:
			_draw_death_marker(entry[0] as Vector2i)


func _draw_selected_unit_tile() -> void:
	if _director == null or _director.selected_unit_id < 0:
		return
	var unit := _proj_unit(_director.selected_unit_id)
	if unit == null or not unit.is_alive() or unit.is_enemy():
		return
	_draw_tile_tint(unit.position, _COLOR_SELECT_TILE, 0.28)
	var tile_px: float = float(TacticalConstants.TILE_PX)
	var center: Vector2 = _map_view.grid_to_local(unit.position)
	var rect := Rect2(
		center - Vector2(tile_px * 0.5, tile_px * 0.5),
		Vector2(tile_px, tile_px),
	).grow(-1.0)
	draw_rect(rect, Color(_COLOR_SELECT_TILE.r, _COLOR_SELECT_TILE.g, _COLOR_SELECT_TILE.b, 0.95), false, 1.0)


func _draw_hover_tiles() -> void:
	# Move under threat so attack-range cells stay visible on overlap (H&I readability).
	for cell: Vector2i in _hover_move_tiles:
		_draw_tile_tint(cell, _COLOR_MOVE, _COLOR_MOVE_FILL_ALPHA, false)
	for cell: Vector2i in _hover_threat_tiles:
		_draw_tile_tint(cell, _COLOR_THREAT, _COLOR_THREAT_FILL_ALPHA, false)


func _draw_tile_tint(cell: Vector2i, tint: Color, fill_alpha: float, draw_border: bool = false) -> void:
	var tile_px: float = float(TacticalConstants.TILE_PX)
	var rect := Rect2(
		_map_view.grid_to_local(cell) - Vector2(tile_px * 0.5, tile_px * 0.5),
		Vector2(tile_px, tile_px),
	).grow(-2.0)
	draw_rect(rect, Color(tint.r, tint.g, tint.b, fill_alpha), true)
	if draw_border:
		draw_rect(rect, Color(tint.r, tint.g, tint.b, _COLOR_TILE_BORDER_ALPHA), false, 1.0)


func _draw_hover_tile() -> void:
	if not _board.is_in_bounds(_hover_coord):
		return
	var tile_px: float = float(TacticalConstants.TILE_PX)
	var center: Vector2 = _map_view.grid_to_local(_hover_coord)
	var rect := Rect2(center - Vector2(tile_px * 0.5, tile_px * 0.5), Vector2(tile_px, tile_px)).grow(-2.0)
	draw_rect(rect, Color(_COLOR_HOVER, 0.10), true)
	draw_rect(rect, Color(_COLOR_HOVER.r, _COLOR_HOVER.g, _COLOR_HOVER.b, 0.45), false, 1.0)


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
			var p_col: Color = _player_color_for_unit(actor)
			_draw_dashed_route(
				[start_pos, action.target_coord],
				Color(p_col.r, p_col.g, p_col.b, _INTENT_ROUTE_ALPHA),
			)
	var preview_board: BoardState = _display_preview_board()
	for intent: Variant in _display_intent_list():
		if not intent is Intent:
			continue
		var row: Intent = intent as Intent
		var enemy := _board.get_unit_by_id(row.enemy_id)
		if enemy == null or not enemy.is_alive():
			continue
		if not _intent_visible(enemy):
			continue
		var enemy_pos: Vector2i = enemy.position
		var pv := preview_board.get_unit_by_id(enemy.id) if preview_board != null else null
		if pv != null:
			enemy_pos = pv.position
		for action: TimelineAction in row.actions:
			match action.type:
				GameEnums.ActionType.ABILITY:
					_draw_dashed_route(
						[enemy_pos, action.target_coord],
						Color(
							_COLOR_ENEMY_ARROW.r,
							_COLOR_ENEMY_ARROW.g,
							_COLOR_ENEMY_ARROW.b,
							_INTENT_ROUTE_ALPHA,
						),
					)
				GameEnums.ActionType.MOVE:
					if action.target_coord != enemy_pos:
						_draw_route_line([enemy_pos, action.target_coord], _COLOR_ENEMY_ARROW, true, true)


func _display_intent_list() -> Array:
	if _planning_input != null and _planning_input.selected_phase_action_exhausted():
		if _board != null:
			return _board.intents
		return []
	if _planning_input != null:
		var use_live: bool = (
			_planning_input.dragging
			or _planning_input.skill_interaction_active()
			or _planning_input.aiming
		)
		if use_live:
			var live: Array = _live_preview.live_intents
			if live.is_empty():
				live = _planning_input.preview_state.live_intents
			if not live.is_empty():
				return live
	if _board != null:
		return _board.intents
	return []


func _active_preview() -> CombatPlanningPreview:
	if _planning_input != null and _planning_input.selected_phase_action_exhausted():
		return _committed_preview
	if _planning_input != null:
		var use_live: bool = (
			_planning_input.dragging
			or _planning_input.skill_interaction_active()
			or _planning_input.aiming
		)
		if use_live and _live_preview.preview_board != null:
			return _live_preview
	return _committed_preview


func _should_draw_interaction_overlay() -> bool:
	if _planning_input != null and _planning_input.selected_phase_action_exhausted():
		return false
	if _planning_input == null:
		return _live_preview.preview_board != null
	if _planning_input.dragging:
		return false
	if (
		_planning_input.skill_interaction_active()
		or _planning_input.aiming
		or _planning_input.force_basic_movement
	):
		return _live_preview.preview_board != null
	return false


func _display_preview_board() -> BoardState:
	var preview: CombatPlanningPreview = _active_preview()
	if preview.preview_board != null:
		return preview.preview_board
	return _preview_board


func _ui_scale() -> float:
	if _map_view == null:
		return 1.0
	return maxf(_map_view.get_map_root_scale(), 0.25)


func _token_radius() -> float:
	return float(TacticalConstants.TILE_PX) * 0.42


func _intent_visible(unit: UnitState) -> bool:
	if _intent_state != null:
		return _intent_state.intent_visible(unit)
	if not unit.is_enemy():
		return true
	return _phase == CombatDirector.Phase.ENEMY_TURN


func _draw_dashed_route(cells: Array, color: Color) -> void:
	if cells.size() < 2:
		return
	var dash := 6.0
	var gap := 4.0
	var offset := _token_radius() + 4.0
	for i: int in range(cells.size() - 1):
		var p1: Vector2 = _map_view.grid_to_local(cells[i])
		var p2: Vector2 = _map_view.grid_to_local(cells[i + 1])
		var dir: Vector2 = (p2 - p1).normalized()
		var dist: float = p1.distance_to(p2)
		var start_d: float = offset if i == 0 else 0.0
		var end_d: float = dist - offset if i == cells.size() - 2 else dist
		var d: float = start_d
		while d < end_d:
			var draw_end: float = minf(d + dash, end_d)
			draw_line(p1 + dir * d, p1 + dir * draw_end, color, _DASH_LINE_W)
			d += dash + gap
	var t: float = Time.get_ticks_msec() / 1000.0
	var flow_speed := 45.0
	var wave_spacing := 90.0
	var total_len := 0.0
	var segment_lengths: Array[float] = []
	var segment_dirs: Array[Vector2] = []
	var segment_starts: Array[Vector2] = []
	for i: int in range(cells.size() - 1):
		var p1: Vector2 = _map_view.grid_to_local(cells[i])
		var p2: Vector2 = _map_view.grid_to_local(cells[i + 1])
		var dir: Vector2 = (p2 - p1).normalized()
		var dist: float = p1.distance_to(p2)
		segment_starts.append(p1)
		segment_dirs.append(dir)
		segment_lengths.append(dist)
		total_len += dist
	var path_offset: float = fmod(t * flow_speed, wave_spacing)
	var arrow_pos: float = path_offset
	while arrow_pos < total_len - offset:
		if arrow_pos > offset:
			var current_d: float = arrow_pos
			var seg_idx := 0
			while seg_idx < segment_lengths.size() and current_d > segment_lengths[seg_idx]:
				current_d -= segment_lengths[seg_idx]
				seg_idx += 1
			if seg_idx < segment_lengths.size():
				var p1: Vector2 = segment_starts[seg_idx]
				var dir: Vector2 = segment_dirs[seg_idx]
				var tip: Vector2 = p1 + dir * current_d
				var wing_len := _DASH_WING_LEN
				var wing1: Vector2 = tip - dir.rotated(deg_to_rad(30.0)) * wing_len
				var wing2: Vector2 = tip - dir.rotated(deg_to_rad(-30.0)) * wing_len
				draw_line(tip, wing1, color, _ROUTE_LINE_W)
				draw_line(tip, wing2, color, _ROUTE_LINE_W)
		arrow_pos += wave_spacing


func _draw_danger_area() -> void:
	if not _show_danger_area or _board == null or _director == null:
		return
	if _danger_tiles_dirty:
		_danger_tiles_cache.clear()
		for u: UnitState in _board.units:
			if not u.is_alive() or not u.is_enemy():
				continue
			var reach: Array[Vector2i] = [u.position]
			for y: int in range(_board.grid_size.y):
				for x: int in range(_board.grid_size.x):
					var c := Vector2i(x, y)
					if c == u.position:
						continue
					var path: Array = MovementSystem.find_path(
						_board, u.position, c, u.movement.points_left,
					)
					if not path.is_empty() and path[path.size() - 1] == c:
						reach.append(c)
			var rng: int = _unit_attack_range(u, -1)
			for r: Vector2i in reach:
				for y2: int in range(_board.grid_size.y):
					for x2: int in range(_board.grid_size.x):
						var c2 := Vector2i(x2, y2)
						if GridSystem.manhattan(c2, r) <= rng:
							_danger_tiles_cache[c2] = true
		_danger_tiles_dirty = false
	for c: Variant in _danger_tiles_cache:
		if c is Vector2i:
			_draw_tile_tint(c as Vector2i, _COLOR_DANGER, _COLOR_DANGER.a)


func _draw_preview_arrows() -> void:
	var prev: CombatPlanningPreview = _active_preview()
	if _board == null or prev.preview_board == null:
		return
	var dragging: bool = _planning_input != null and _planning_input.dragging
	var drag_unit_id: int = _planning_input.get_drag_unit_id() if _planning_input != null else -1
	var selected_id: int = _director.selected_unit_id if _director != null else -1
	var skill_priority: bool = _planning_input.skill_interaction_active() if _planning_input != null else false
	for unit: UnitState in _board.units:
		if not unit.is_alive() or not _intent_visible(unit):
			continue
		var route: Array = prev.preview_paths.get(unit.id, [])
		if route.is_empty():
			continue
		var split: int = int(prev.preview_splits.get(unit.id, route.size()))
		var player_leg: Array = route.slice(0, split)
		var enemy_leg: Array = route.slice(maxi(split - 1, 0))
		if player_leg.size() >= 2:
			var skip_live_route := false
			if not unit.is_enemy() and unit.id == selected_id:
				if dragging and unit.id == drag_unit_id:
					skip_live_route = true
				elif skill_priority and not dragging:
					skip_live_route = true
			if not skip_live_route:
				var p_col: Color = _player_color_for_unit(unit)
				var dim_col := Color(p_col.r, p_col.g, p_col.b, 0.35)
				_draw_route_line(player_leg, dim_col, true, true)
		if enemy_leg.size() >= 2:
			var dim_enemy := Color(_COLOR_ENEMY_ARROW.r, _COLOR_ENEMY_ARROW.g, _COLOR_ENEMY_ARROW.b, 0.35)
			_draw_route_line(enemy_leg, dim_enemy, split <= 1, true)
		var pushes: Array = prev.preview_pushes.get(unit.id, [])
		for push: Variant in pushes:
			if push is Array and push.size() >= 2:
				_draw_push_arrow(push[0], push[1])
		var pv := prev.preview_board.get_unit_by_id(unit.id)
		if pv == null or not pv.is_alive():
			var end_tile: Vector2i = unit.position
			if not pushes.is_empty():
				var last_push: Variant = pushes[pushes.size() - 1]
				if last_push is Array and last_push.size() >= 2:
					end_tile = last_push[1]
			elif route.size() > 0:
				end_tile = route[route.size() - 1]
			_draw_death_marker(end_tile)


func _draw_interaction_overlay() -> void:
	if _director == null or _director.selected_unit_id < 0:
		return
	var prev: CombatPlanningPreview = _active_preview()
	if prev.preview_board == null:
		return
	var actor := prev.preview_board.get_unit_by_id(_director.selected_unit_id)
	if actor == null:
		actor = _board.get_unit_by_id(_director.selected_unit_id)
	if actor == null:
		return
	var route: Array = prev.preview_paths.get(actor.id, [])
	var p_col: Color = _player_color_for_unit(actor)
	if route.size() >= 2:
		_draw_route_line(route, Color(p_col.r, p_col.g, p_col.b, 0.95), true, true)
	if _attack_target_id >= 0:
		var origin: Vector2i = actor.position
		var target_coord: Vector2i = _hover_coord
		var target_unit := prev.preview_board.get_unit_by_id(_attack_target_id)
		if target_unit == null and _board != null:
			target_unit = _board.get_unit_by_id(_attack_target_id)
		if target_unit != null:
			target_coord = target_unit.position
		if origin != target_coord:
			_draw_dashed_route([origin, target_coord], Color(p_col.r, p_col.g, p_col.b, 0.95))


func _draw_route_line(route: Array, color: Color, trim_start: bool, with_head: bool) -> void:
	if route.size() < 2:
		return
	var pts := PackedVector2Array()
	for tile: Variant in route:
		if tile is Vector2i:
			pts.append(_map_view.grid_to_local(tile))
	if pts.size() < 2:
		return
	var last: int = pts.size() - 1
	var token_r: float = _token_radius()
	if trim_start:
		var d0: Vector2 = pts[1] - pts[0]
		if d0.length() > 0.0:
			pts[0] += d0.normalized() * token_r
	var end_dir: Vector2 = (pts[last] - pts[last - 1]).normalized()
	if with_head:
		pts[last] -= end_dir * token_r
	var glow := Color(color.r, color.g, color.b, color.a * 0.22)
	draw_polyline(pts, glow, _ROUTE_GLOW_W)
	draw_polyline(pts, color, _ROUTE_LINE_W)
	if with_head:
		var tip: Vector2 = pts[last]
		var perp: Vector2 = Vector2(-end_dir.y, end_dir.x) * _ROUTE_HEAD_PERP
		draw_line(tip, tip - end_dir * _ROUTE_HEAD_LEN + perp, color, _ROUTE_LINE_W)
		draw_line(tip, tip - end_dir * _ROUTE_HEAD_LEN - perp, color, _ROUTE_LINE_W)


func _draw_death_marker(cell: Vector2i) -> void:
	var center: Vector2 = _map_view.grid_to_local(cell)
	var token_r: float = _token_radius()
	var death_col := Color(0.95, 0.25, 0.25, 0.9)
	draw_arc(center, token_r + 2.0, 0.0, TAU, 24, Color(death_col, 0.25), 2.5 / _ui_scale())
	var r: float = token_r * 0.65
	draw_line(center + Vector2(-r, -r), center + Vector2(r, r), death_col, 2.5 / _ui_scale())
	draw_line(center + Vector2(-r, r), center + Vector2(r, -r), death_col, 2.5 / _ui_scale())


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


func _draw_ghosts() -> void:
	var prev: CombatPlanningPreview = _active_preview()
	if prev.preview_board == null or _board == null or _director == null:
		return
	var plan_to_use: Timeline = (
		_director.plan_phase_1
		if _phase == CombatDirector.Phase.PLANNING_PHASE_1
		else _director.plan_phase_2
	)
	for unit: UnitState in _board.units:
		if not unit.is_alive() or not _intent_visible(unit):
			continue
		if not unit.is_enemy() and plan_to_use != null:
			for action: TimelineAction in plan_to_use.entries:
				if (
					action.actor_id == unit.id
					and action.type == GameEnums.ActionType.ABILITY
					and action.ability != null
					and AbilitySystem.ability_has_dash(action.ability)
				):
					var start_pos: Vector2i = _proj_origin(unit)
					if action.target_coord != start_pos:
						var center: Vector2 = _map_view.grid_to_local(action.target_coord)
						var ghost_col: Color = _player_color_for_unit(unit)
						draw_circle(center, _token_radius(), Color(ghost_col.r, ghost_col.g, ghost_col.b, 0.35))
						_draw_facing_wedge(center, unit.facing, Color(ghost_col.r, ghost_col.g, ghost_col.b, 0.8))
					break
		if unit.is_enemy():
			var route: Array = prev.preview_paths.get(unit.id, [])
			var voluntary_dest: Vector2i = route[route.size() - 1] if route.size() > 0 else unit.position
			if voluntary_dest != unit.position:
				var ghost_center: Vector2 = _map_view.grid_to_local(voluntary_dest)
				var alpha: float = 0.25 if (_planning_input != null and _planning_input.skill_interaction_active()) else 0.1
				var ghost_col := Color(_COLOR_ENEMY_ARROW.r, _COLOR_ENEMY_ARROW.g, _COLOR_ENEMY_ARROW.b, alpha)
				draw_circle(ghost_center, _token_radius(), Color(ghost_col.r, ghost_col.g, ghost_col.b, alpha * 0.55))
				draw_arc(ghost_center, _token_radius(), 0.0, TAU, 24, ghost_col, 2.0)
				var pv_enemy := prev.preview_board.get_unit_by_id(unit.id) if prev.preview_board != null else null
				var face: int = pv_enemy.facing if pv_enemy != null else unit.facing
				_draw_facing_wedge(ghost_center, face, Color(_COLOR_ENEMY_ARROW.r, _COLOR_ENEMY_ARROW.g, _COLOR_ENEMY_ARROW.b, alpha + 0.15))


func _draw_move_ghosts() -> void:
	if _director == null or _board == null or _planning_input == null:
		return
	if _director.selected_unit_id < 0 or not _board.is_in_bounds(_hover_coord):
		return
	var unit := _proj_unit(_director.selected_unit_id)
	if unit == null or not unit.is_alive():
		return
	var ability: AbilityData = _selected_ability_data(unit, _director.selected_ability_index)
	if ability == null or not AbilitySystem.ability_has_dash(ability):
		return
	var origin: Vector2i = _proj_origin(unit)
	if not _is_valid_dash_hover(origin, _hover_coord, ability.range_tiles):
		return
	var center: Vector2 = _map_view.grid_to_local(_hover_coord)
	var p_col: Color = _player_color_for_unit(unit)
	draw_circle(center, _token_radius() + 1.0, Color(p_col.r, p_col.g, p_col.b, 0.45))
	var dash_face: int = _facing_toward(origin, _hover_coord)
	_draw_facing_wedge(center, dash_face, Color(p_col.r, p_col.g, p_col.b, 0.85))
	_draw_dashed_route([origin, _hover_coord], Color(p_col.r, p_col.g, p_col.b, 0.85))


func _facing_toward(from: Vector2i, to: Vector2i) -> int:
	if to.x > from.x:
		return GameEnums.Facing.EAST
	if to.x < from.x:
		return GameEnums.Facing.WEST
	if to.y > from.y:
		return GameEnums.Facing.SOUTH
	if to.y < from.y:
		return GameEnums.Facing.NORTH
	return GameEnums.Facing.SOUTH


func _draw_drag_path() -> void:
	if _planning_input == null or _board == null or not _planning_input.dragging:
		return
	var drag_unit := _board.get_unit_by_id(_planning_input.get_drag_unit_id())
	if drag_unit == null:
		return
	var ability: AbilityData = _selected_ability_data(drag_unit, _director.selected_ability_index)
	var p_col: Color = _player_color_for_unit(drag_unit)
	var route_col: Color = Color(p_col.r, p_col.g, p_col.b, 0.95)
	if (
		ability != null
		and AbilitySystem.ability_has_dash(ability)
		and _is_valid_dash_hover(_proj_origin(drag_unit), _hover_coord, ability.range_tiles)
	):
		_draw_dashed_route([_proj_origin(drag_unit), _hover_coord], route_col)
		return
	if _route.size() >= 2:
		var hovered_unit := _board.get_unit_at(_hover_coord) if _board.is_in_bounds(_hover_coord) else null
		if hovered_unit != null and hovered_unit.id != _planning_input.get_drag_unit_id():
			var idx: int = _route.find(_planning_input.drag_sim_actor_pos)
			var move_route: Array = _route.slice(0, idx + 1) if idx >= 0 else _route.slice(0, _route.size() - 1)
			if move_route.size() >= 2:
				_draw_route_line(move_route, _COLOR_DRAGPATH, true, true)
			_draw_dashed_route([_planning_input.drag_sim_actor_pos, _hover_coord], route_col)
		else:
			_draw_route_line(_route, _COLOR_DRAGPATH, true, true)


func _draw_target_rings() -> void:
	if _director == null or _director.selected_unit_id < 0 or _board == null:
		return
	var unit := _proj_unit(_director.selected_unit_id)
	if unit == null or not unit.is_alive() or unit.is_enemy():
		return
	var ability: AbilityData = _selected_ability_data(unit, _director.selected_ability_index)
	if ability == null:
		return
	var origin: Vector2i = _proj_origin(unit)
	if AbilitySystem.ability_has_dash(ability):
		for cell: Vector2i in _dash_threat_tiles(origin, _dash_amount(ability)):
			_draw_tile_tint(cell, _COLOR_TARGET, 0.35)
		return
	var self_aoe: Array[Vector2i] = _self_aoe_threat_tiles(unit, ability, origin)
	if not self_aoe.is_empty():
		for cell: Vector2i in self_aoe:
			_draw_tile_tint(cell, _COLOR_TARGET, 0.35)
		return
	var rng: int = ability.range_tiles
	if rng < 0:
		return
	var preview_board: BoardState = _display_preview_board()
	for other: UnitState in preview_board.units:
		if not other.is_alive() or other.id == unit.id:
			continue
		if GridSystem.manhattan(origin, other.position) <= rng:
			var center: Vector2 = _map_view.grid_to_local(other.position)
			draw_arc(center, _token_radius() + 4.0, 0.0, TAU, 24, _COLOR_TARGET, 2.0)


func _is_valid_dash_hover(origin: Vector2i, coord: Vector2i, max_range: int) -> bool:
	if coord == origin or max_range <= 0:
		return false
	var delta: Vector2i = coord - origin
	if delta.x != 0 and delta.y != 0:
		return false
	var dist: int = GridSystem.manhattan(origin, coord)
	return dist >= 1 and dist <= max_range


func _proj_unit(unit_id: int) -> UnitState:
	if unit_id < 0:
		return null
	# Match board_view: ranges/selection use committed projection only — never live hover board.
	if _director != null and _director.projected_state != null:
		var proj_u := _director.projected_state.get_unit_by_id(unit_id)
		if proj_u != null:
			return proj_u
	if _board != null:
		return _board.get_unit_by_id(unit_id)
	return null


func _player_color_for_unit(unit: UnitState) -> Color:
	if unit == null:
		return _COLOR_PLAYER_ARROW
	return CombatUiFormatters.player_color(unit.controlling_player_id)


func _facing_vector(facing: int) -> Vector2:
	match facing:
		GameEnums.Facing.NORTH:
			return Vector2(0.0, -1.0)
		GameEnums.Facing.SOUTH:
			return Vector2(0.0, 1.0)
		GameEnums.Facing.WEST:
			return Vector2(-1.0, 0.0)
		_:
			return Vector2(1.0, 0.0)


func _draw_facing_wedge(center: Vector2, facing: int, color: Color) -> void:
	var dir: Vector2 = _facing_vector(facing)
	if dir == Vector2.ZERO:
		return
	var perp := Vector2(-dir.y, dir.x)
	var radius: float = _token_radius()
	var tip: Vector2 = center + dir * (radius + 6.0)
	var base: Vector2 = center + dir * (radius - 3.0)
	var pts := PackedVector2Array([tip, base + perp * 6.0, base - perp * 6.0])
	draw_colored_polygon(pts, color)


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
	if unit == null or _director == null:
		return 0
	if unit.id == _director.selected_unit_id and selected_ability >= 0:
		var ability: AbilityData = _selected_ability_data(unit, selected_ability)
		if ability != null:
			return unit.get_ability_range(ability)
	if unit.is_enemy():
		if unit.definition != null and unit.definition.behavior != null:
			var att: AbilityData = unit.definition.behavior.attack
			if att != null:
				return att.range_tiles
		var best: int = 0
		for ability: AbilityData in unit.active_abilities:
			best = maxi(best, unit.get_ability_range(ability))
		return best if best > 0 else 1
	var best: int = 0
	for ability: AbilityData in unit.active_abilities:
		best = maxi(best, unit.get_ability_range(ability))
	return best


func _populate_attack_threat_tiles(unit: UnitState, origin: Vector2i, selected_ability: int) -> void:
	var rng: int = _unit_attack_range(unit, selected_ability)
	if rng <= 0:
		return
	var threat_sources: Array[Vector2i] = [origin]
	if unit.is_enemy():
		threat_sources = _hover_move_tiles.duplicate()
		if threat_sources.is_empty():
			threat_sources = [origin]
	if unit.id == _director.selected_unit_id:
		var sel_ability: AbilityData = _selected_ability_data(unit, selected_ability)
		if sel_ability != null and AbilitySystem.ability_has_dash(sel_ability):
			_hover_threat_tiles = _dash_threat_tiles(origin, _dash_amount(sel_ability))
			return
	for y: int in range(_board.grid_size.y):
		for x: int in range(_board.grid_size.x):
			var coord := Vector2i(x, y)
			if _hover_threat_tiles.has(coord):
				continue
			for src: Vector2i in threat_sources:
				if GridSystem.manhattan(coord, src) <= rng:
					_hover_threat_tiles.append(coord)
					break


func _add_attack_threat_tiles(unit: UnitState, origin: Vector2i, selected_ability: int) -> void:
	_populate_attack_threat_tiles(unit, origin, selected_ability)


func _draw_centered_icon(pos: Vector2, text: String, color: Color, size_px: int) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
	draw_string(font, pos - Vector2(sz.x * 0.5, sz.y * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func _update_hover_action_icon() -> void:
	if _planning_input != null:
		_hover_action_icon = _planning_input.compute_hover_action_icon(_hover_coord)
		return
	_hover_action_icon = ""


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
