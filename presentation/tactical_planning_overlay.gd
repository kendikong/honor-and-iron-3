class_name TacticalPlanningOverlay
extends Node2D

## Range tints, move route, aim icon, intent arrows, hover tile.
##
## Planning tint contract:
## - BLUE (_hover_move_tiles): legal pre-move OR post-move destinations (MP budget only).
## - RED (_hover_action_range_tiles): selected skill range from projected unit position
##   (timeline projection). Phase-2 movement endpoints use dash/move tiles from that
##   same origin — not cursor-shifted hypothetical stand cells.

const _COLOR_MOVE := Color(0.35, 0.58, 0.92, 0.22)
const _COLOR_ACTION_RANGE := Color(0.92, 0.38, 0.32, 0.20)
const _COLOR_MOVE_FILL_ALPHA: float = 0.22
const _COLOR_MOVE_PERIMETER_ALPHA: float = 0.72
const _COLOR_ACTION_RANGE_FILL_ALPHA: float = 0.24
const _COLOR_ACTION_RANGE_PERIMETER_ALPHA: float = 0.72
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
const _COLOR_SELECT_TILE := Color(0.36, 0.62, 0.92, 0.35)
## Route widths in map-local px (MapRoot scale applies on screen — do not divide by ui_scale).
const _ROUTE_CORNER_R: float = 5.0
const _ROUTE_GLOW_W: float = 8.0
const _ROUTE_OUTLINE_W: float = 5.0
const _ROUTE_LINE_W: float = 3.75
const _ROUTE_AA: bool = false
const _ROUTE_CORE_W: float = 1.25
const _ROUTE_HEAD_LEN: float = 8.5
const _ROUTE_HEAD_HALF_W: float = 4.7
const _ROUTE_SHAFT_HEAD_OVERLAP: float = 0.55
const _FORCED_MOVE_LINE_W: float = 1.875
const _INTENT_DOT_RADIUS: float = 1.25
const _INTENT_DOT_SPACING: float = 7.0
const _INTENT_ARROW_HEAD_LEN: float = 7.0
const _INTENT_ARROW_HEAD_ANGLE_DEG: float = 28.0
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
var _phase: int = CombatDirector.Phase.PLANNING
var _hover_move_tiles: Array[Vector2i] = []
var _hover_action_range_tiles: Array[Vector2i] = []
var _cached_hover_unit_id: int = -1
var _cached_hover_origin: Vector2i = Vector2i(-999, -999)
var _cached_hover_ability: int = -1
var _cached_hover_force: bool = false
var _fixed_range_origin: Vector2i = Vector2i(-999, -999)
## Separate from move range: follows cursor during drag / aim. Invalid = use move origin.
var _action_range_origin: Vector2i = Vector2i(-999, -999)
var _cached_hover_action_range_origin: Vector2i = Vector2i(-999, -999)
var _cached_hover_proj_key: int = -1
var _cached_hover_awaiting_targeting: bool = false
var _hover_action_icon: String = ""
var _live_preview: CombatPlanningPreview = CombatPlanningPreview.new()
var _committed_preview: CombatPlanningPreview = CombatPlanningPreview.new()
var _stashed_committed: CombatPlanningPreview = CombatPlanningPreview.new()
var _has_stashed_committed: bool = false
var _lock_committed_from_intent: bool = false
var _unit_layer: TacticalUnitLayer
var _planning_input: CombatPlanningInput
var _planning_cursor: TacticalPlanningCursor
var _attack_target_id: int = -1
var _show_danger_area: bool = false
var _danger_tiles_cache: Dictionary = {}
var _danger_tiles_dirty: bool = true
var _hit_markers: Array = []
var _hover_recompute_pending: bool = false
var _drag_overlay_redraw_accum: float = 0.0
var _game_settings: GameSettings
const _DRAG_OVERLAY_REDRAW_SEC: float = 1.0 / 30.0


func setup(
	map_view: TacticalMapView,
	director: CombatDirector,
	intent_state: CombatIntentState = null,
) -> void:
	_map_view = map_view
	_director = director
	_intent_state = intent_state
	z_as_relative = false
	z_index = 11
	EventBus.board_changed.connect(_on_board_changed)
	EventBus.preview_updated.connect(_on_preview_updated)
	EventBus.timeline_changed.connect(func(_plan: Timeline, _statuses: PackedStringArray) -> void:
		_invalidate_hover_cache()
		_schedule_hover_recompute()
	)
	EventBus.selection_changed.connect(func(_id: int) -> void:
		if _director == null:
			return
		_update_hover_action_icon()
		queue_redraw(),
	)
	EventBus.ability_selected.connect(func(_idx: int) -> void:
		if _director == null:
			return
		_invalidate_hover_cache()
		_schedule_hover_recompute()
		_update_hover_action_icon()
		queue_redraw(),
	)
	EventBus.turn_phase_changed.connect(func(phase: int) -> void:
		_phase = phase
		var planning: bool = CombatDirector.is_planning_phase(phase)
		if not planning and _planning_input != null:
			_planning_input.clear_interaction_preview()
		_invalidate_hover_cache()
		if planning:
			_recompute_hover_ranges_from_inputs()
		else:
			_hover_move_tiles.clear()
			_hover_action_range_tiles.clear()
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


func apply_settings(settings: GameSettings) -> void:
	_game_settings = settings
	if _planning_input != null:
		_planning_input.refresh_mouse_cursor(_hover_coord)
	queue_redraw()


func _preview_range_overlays_enabled() -> bool:
	return _game_settings == null or _game_settings.preview_show_range_overlays


func _preview_routes_enabled() -> bool:
	return _game_settings == null or _game_settings.preview_show_routes


func _preview_live_ghosts_enabled() -> bool:
	return _game_settings == null or _game_settings.preview_show_live_ghosts


func _preview_arrows_enabled() -> bool:
	return _game_settings == null or _game_settings.preview_show_arrows


func _preview_committed_intents_enabled() -> bool:
	return _game_settings == null or _game_settings.preview_show_committed_intents


func _preview_cursor_enabled() -> bool:
	return _game_settings == null or _game_settings.preview_show_planning_cursor


func planning_cursor_display_enabled() -> bool:
	return _preview_cursor_enabled()


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
	_cached_hover_action_range_origin = Vector2i(-999, -999)
	_cached_hover_ability = -1
	_cached_hover_proj_key = -1
	_cached_hover_awaiting_targeting = false


func _planning_action_range_tiles_for_unit(
	unit: UnitState,
	origin: Vector2i,
	selected_ability: int,
) -> Array[Vector2i]:
	var ability: AbilityData = _selected_ability_data(unit, selected_ability)
	var actor: UnitState = _proj_unit(unit.id)
	if actor == null:
		actor = unit
	var plan_board: BoardState = _board
	if _director != null and _director.projected_state != null:
		plan_board = _director.projected_state
	return AbilitySystem.planning_action_range_tiles(plan_board, actor, ability, origin, [])


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


func get_committed_preview() -> CombatPlanningPreview:
	return _committed_preview


func get_hover_move_tiles() -> Array[Vector2i]:
	return _hover_move_tiles.duplicate()


func is_hover_move_tile(cell: Vector2i) -> bool:
	return _hover_move_tiles.has(cell)


func is_hover_action_range_tile(cell: Vector2i) -> bool:
	return _hover_action_range_tiles.has(cell)


func is_hover_threat_tile(cell: Vector2i) -> bool:
	return is_hover_action_range_tile(cell)


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
	_live_preview.preview_post_splits.clear()
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


## Promote the painted live intent to committed display (move-preview intent truth).
## Locks the next preview_updated so director refresh cannot replace that picture.
func promote_live_preview_to_committed() -> void:
	_committed_preview.copy_from(_live_preview)
	if _director != null and _director.base_board != null:
		_committed_preview.ensure_movement_intent_from_plan(
			_director.get_player_plan(),
			_director.base_board,
		)
	_preview_board = _committed_preview.preview_board
	_has_stashed_committed = false
	_lock_committed_from_intent = true
	restore_committed_display()


func apply_preview_state(
	state: CombatPlanningPreview,
	selected_id: int,
	attack_target_id: int,
) -> void:
	_live_preview.copy_from(state)
	_attack_target_id = attack_target_id
	if _preview_live_ghosts_enabled() and _unit_layer != null:
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
	if _planning_input == null:
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
	cursor_cell: Vector2i = Vector2i(-999999, -999999),
) -> void:
	if _unit_layer != null:
		_unit_layer.update_drag_preview(map_local, anim_mode, facing, preview_cell, failed, cursor_cell)


func update_drag_sprite_position(
	map_local: Vector2,
	preview_cell: Vector2i,
	cursor_cell: Vector2i,
) -> void:
	if _unit_layer != null:
		_unit_layer.update_drag_preview_position(map_local, preview_cell, cursor_cell)


func end_drag_sprite(snap_back: bool = false) -> void:
	if _unit_layer != null:
		_unit_layer.end_drag_preview(snap_back)


func set_drag_attack_target(unit_id: int) -> void:
	if _unit_layer == null:
		return
	if unit_id >= 0:
		_unit_layer.set_drag_attack_target(unit_id)
	else:
		_unit_layer.clear_drag_attack_target()


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


func set_action_range_origin(coord: Vector2i) -> void:
	if coord == _action_range_origin:
		return
	_action_range_origin = coord
	_invalidate_hover_cache()


func set_threat_origin(coord: Vector2i) -> void:
	set_action_range_origin(coord)


func clear_action_range_origin() -> void:
	if _action_range_origin.x <= -900:
		return
	_action_range_origin = Vector2i(-999, -999)
	_invalidate_hover_cache()


func clear_threat_origin() -> void:
	clear_action_range_origin()


func bind_planning_cursor(cursor: TacticalPlanningCursor) -> void:
	_planning_cursor = cursor
	if _planning_cursor != null:
		_planning_cursor.set_icon(_hover_action_icon)


func set_hover_action_icon(icon: String) -> void:
	_hover_action_icon = icon
	if _planning_cursor != null:
		if _preview_cursor_enabled():
			_planning_cursor.set_icon(icon)
		else:
			_planning_cursor.set_icon("")
	queue_redraw()


func clear_planning_cursor_icon() -> void:
	_hover_action_icon = ""
	if _planning_cursor != null:
		_planning_cursor.set_icon("")
	queue_redraw()


func _is_selected_player_unit(unit: UnitState) -> bool:
	return (
		unit != null
		and not unit.is_enemy()
		and _director != null
		and unit.id == _director.selected_unit_id
	)


func _intent_tiles_blocked(unit: UnitState, selected_ability: int) -> bool:
	if not _is_selected_player_unit(unit):
		return false
	if CombatDirector.is_wait_ability_index(selected_ability):
		return true
	if _director.unit_has_wait_planned(unit.id):
		return true
	if _planning_input != null and _planning_input.selected_phase_action_exhausted(unit.id):
		return true
	return false


func _movement_status_blocked(unit: UnitState) -> bool:
	if unit == null:
		return true
	return unit.has_status(GameEnums.StatusType.ROOT) or unit.has_status(GameEnums.StatusType.STAGGER)


func _hover_proj_cache_key(unit: UnitState) -> int:
	if unit == null or _director == null:
		return 0
	var p_unit := _proj_unit(unit.id)
	if p_unit == null:
		return 0
	var key: int = p_unit.position.x
	key = key * 1000 + p_unit.position.y
	key = key * 100 + p_unit.movement.points_left
	key = key * 10 + p_unit.ability.points_left
	key = key * 10 + (1 if p_unit.turn_action_used else 0)
	if _director.unit_has_wait_planned(unit.id):
		key += 10000000
	return key


func _compute_move_budget(unit: UnitState, p_unit: UnitState, selected_ability: int) -> int:
	if p_unit == null or _movement_status_blocked(p_unit):
		return 0
	if _director.get_planning_move_timing(unit.id) < 0:
		return 0
	if (
		_planning_input != null
		and _planning_input.auto_run_movement_active(p_unit)
	):
		return _move_budget_for_hover(p_unit, selected_ability)
	if p_unit.movement.points_left <= 0:
		return 0
	return _move_budget_for_hover(p_unit, selected_ability)


func _can_show_move_tiles(unit: UnitState, selected_ability: int) -> bool:
	if unit == null:
		return false
	if _planning_input != null and _planning_input.awaiting_targeting_active():
		return false
	if _director != null:
		var move_timing: int = _director.get_planning_move_timing(unit.id)
		if (
			move_timing != -1
			and _director.unit_has_move_planned_at_timing(unit.id, move_timing)
		):
			return false
	if _intent_tiles_blocked(unit, selected_ability):
		return false
	if _is_selected_player_unit(unit):
		return _compute_move_budget(unit, _proj_unit(unit.id), selected_ability) > 0
	return unit.movement.points_left > 0 and not _movement_status_blocked(unit)


func _can_show_action_range_tiles(unit: UnitState, selected_ability: int, force_basic: bool) -> bool:
	if unit == null:
		return false
	if _intent_tiles_blocked(unit, selected_ability):
		return false
	if not _is_selected_player_unit(unit):
		return unit.is_enemy()
	var p_unit := _proj_unit(unit.id)
	if p_unit == null:
		return false
	if not p_unit.can_use_action_slot():
		return false
	if p_unit.has_status(GameEnums.StatusType.STAGGER) or p_unit.has_status(GameEnums.StatusType.SILENCE):
		return false
	if selected_ability < 0 and not force_basic:
		return false
	var ability: AbilityData = _selected_ability_data(unit, selected_ability)
	if force_basic and (ability == null or AbilitySystem.is_wait_ability(ability)):
		if not p_unit.active_abilities.is_empty():
			ability = p_unit.active_abilities[0]
	if ability == null or AbilitySystem.is_wait_ability(ability):
		return false
	if AbilitySystem.is_run_ability(ability):
		return false
	## Phase 1 (selected AWAITING_TARGET, not yet armed) and phase 2 (awaiting armed)
	## both show action-range tiles from projected stand — dash/move tiles in phase 2.
	var premove_cell: Vector2i = _intent_stand_origin(unit)
	var plan_board: BoardState = _director.projected_state if _director.projected_state != null else _board
	var auto_run_active: bool = (
		_planning_input != null and _planning_input.auto_run_movement_active(p_unit)
	)
	if not (
		_planning_input != null
		and _planning_input.awaiting_targeting_active()
	):
		if not AbilitySystem.can_show_planning_action_range_after_premove(
			plan_board, p_unit, ability, premove_cell, auto_run_active,
		):
			return false
	if force_basic:
		return true
	return p_unit.ability.points_left >= ability.action_point_cost


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
		_hover_action_range_tiles.clear()
		queue_redraw()
		return
	var move_origin: Vector2i = _proj_origin(unit)
	if dragging and _fixed_range_origin.x >= 0:
		move_origin = _fixed_range_origin
	# Intent stand (projection + live move preview). Drag may override via set_threat_origin.
	var action_range_origin: Vector2i = _intent_stand_origin(unit)
	if _action_range_origin.x > -900:
		action_range_origin = _action_range_origin
	var cache_ability: int = selected_ability if unit.id == _director.selected_unit_id else -1
	var cache_force: bool = force_basic if unit.id == _director.selected_unit_id else false
	var proj_key: int = _hover_proj_cache_key(unit) if _is_selected_player_unit(unit) else 0
	var cache_awaiting_targeting: bool = (
		_planning_input != null and _planning_input.awaiting_targeting_active()
	)
	if (
		_cached_hover_unit_id == unit.id
		and _cached_hover_origin == move_origin
		and _cached_hover_action_range_origin == action_range_origin
		and _cached_hover_ability == cache_ability
		and _cached_hover_force == cache_force
		and _cached_hover_proj_key == proj_key
		and _cached_hover_awaiting_targeting == cache_awaiting_targeting
	):
		return
	_cached_hover_unit_id = unit.id
	_cached_hover_origin = move_origin
	_cached_hover_action_range_origin = action_range_origin
	_cached_hover_ability = cache_ability
	_cached_hover_force = cache_force
	_cached_hover_proj_key = proj_key
	_cached_hover_awaiting_targeting = cache_awaiting_targeting
	_hover_move_tiles.clear()
	_hover_action_range_tiles.clear()
	if _intent_tiles_blocked(unit, selected_ability):
		queue_redraw()
		return
	var move_cost: int = 2 if unit.has_status(GameEnums.StatusType.BLEED) else 1
	var mt: int = (
		unit.definition.movement_type
		if unit.definition != null
		else GameEnums.MovementType.WALK
	)
	var is_selected_player: bool = _is_selected_player_unit(unit)
	var p_unit: UnitState = _proj_unit(unit.id) if is_selected_player else null
	if _can_show_move_tiles(unit, selected_ability):
		var move_board: BoardState = _board
		var move_from: Vector2i = move_origin
		var move_budget: int = 0
		if is_selected_player and p_unit != null:
			move_cost = 2 if p_unit.has_status(GameEnums.StatusType.BLEED) else 1
			mt = (
				p_unit.definition.movement_type
				if p_unit.definition != null
				else GameEnums.MovementType.WALK
			)
			move_board = CombatPlanningPreview.planning_projection_board(_director, _board)
			move_from = move_origin
			move_budget = _compute_move_budget(unit, p_unit, selected_ability)
		else:
			move_budget = unit.movement.points_left
		if move_budget > 0:
			var move_ability: AbilityData = null
			if is_selected_player and selected_ability >= 0:
				move_ability = _selected_ability_data(unit, selected_ability)
			_hover_move_tiles = MovementSystem.get_reachable_tiles(
				move_board,
				move_from,
				move_budget,
				mt,
				move_cost,
				move_ability,
			)
	if not _can_show_action_range_tiles(unit, selected_ability, cache_force):
		queue_redraw()
		return
	var ability_index: int = selected_ability if is_selected_player else -1
	if cache_force and is_selected_player:
		ability_index = selected_ability
	if ability_index >= 0 and is_selected_player:
		var ability: AbilityData = _selected_ability_data(unit, ability_index)
		var budget_unit: UnitState = p_unit if p_unit != null else unit
		if (
			ability != null
			and AbilitySystem.is_run_ability(ability)
			and budget_unit != null
			and budget_unit.ability.points_left >= ability.action_point_cost
		):
			queue_redraw()
			return
		_hover_action_range_tiles = _planning_action_range_tiles_for_unit(
			unit, action_range_origin, ability_index,
		)
	else:
		_populate_action_range_tiles(unit, action_range_origin, ability_index)
	queue_redraw()


func _on_board_changed(board: BoardState) -> void:
	set_board(board)
	_danger_tiles_dirty = true
	_invalidate_hover_cache()


func _process(delta: float) -> void:
	var need_redraw := false
	for i: int in range(_hit_markers.size() - 1, -1, -1):
		var entry: Array = _hit_markers[i]
		entry[1] = float(entry[1]) - delta
		if float(entry[1]) <= 0.0:
			_hit_markers.remove_at(i)
		need_redraw = true
	if need_redraw:
		queue_redraw()
	elif CombatDirector.is_planning_phase(_phase) and _overlay_needs_flow_animation():
		if _planning_input != null and _planning_input.dragging:
			_drag_overlay_redraw_accum += delta
			if _drag_overlay_redraw_accum >= _DRAG_OVERLAY_REDRAW_SEC:
				_drag_overlay_redraw_accum = 0.0
				queue_redraw()
		else:
			queue_redraw()
	elif not _hit_markers.is_empty():
		queue_redraw()


func _overlay_needs_flow_animation() -> bool:
	if _planning_input != null and _planning_input.dragging:
		return true
	var prev: CombatPlanningPreview = _active_preview()
	if prev != null:
		for push_list: Variant in prev.preview_pushes.values():
			if push_list is Array and not push_list.is_empty():
				return true
	if _director != null:
		var plan: Timeline = _director.get_player_plan()
		if plan != null:
			for action: TimelineAction in plan.entries:
				if action.type == GameEnums.ActionType.ABILITY:
					return true
	if _route.size() >= 2:
		return true
	return false


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


func _schedule_hover_recompute() -> void:
	if _hover_recompute_pending:
		return
	_hover_recompute_pending = true
	call_deferred("_flush_hover_recompute")


func _flush_hover_recompute() -> void:
	_hover_recompute_pending = false
	_recompute_hover_ranges_from_inputs()


func _on_preview_updated(result: SimResult) -> void:
	## Intent truth: after promote_live_preview_to_committed, do not rebuild ghosts from a
	## second sim — keep the ratified picture (including preview_board pointer).
	if _lock_committed_from_intent:
		_lock_committed_from_intent = false
		_has_stashed_committed = false
		queue_redraw()
		return
	set_preview_board(result.final_state)
	var movement_only: bool = (
		_director != null and _director.consume_movement_only_refresh()
	)
	if movement_only and _board != null:
		if _committed_preview.preview_board == null:
			_committed_preview = CombatPlanningPreview.from_sim_result(result, _director, _board)
		else:
			CombatPlanningPreview.apply_movement_result(
				_committed_preview, result, _director, _board,
			)
		_preview_board = _committed_preview.preview_board
		_has_stashed_committed = false
		if _planning_input == null or not _planning_input.is_live_preview_active():
			if _unit_layer != null:
				_unit_layer.set_predicted_stats(
					_committed_preview.predicted_hp,
					_committed_preview.predicted_armor,
				)
			live_preview_changed.emit()
		queue_redraw()
		return
	_invalidate_hover_cache()
	if _director != null and _board != null:
		_committed_preview = CombatPlanningPreview.from_sim_result(result, _director, _board)
		_preview_board = _committed_preview.preview_board
	_has_stashed_committed = false
	_schedule_hover_recompute()
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
	var show_planning: bool = CombatDirector.is_planning_phase(_phase)
	if show_planning:
		_draw_danger_area()
		if _preview_live_ghosts_enabled():
			_draw_move_ghosts()
	if _preview_range_overlays_enabled():
		_draw_hover_tiles()
	if show_planning:
		if _preview_live_ghosts_enabled():
			_draw_ghosts()
		if _preview_arrows_enabled():
			_draw_preview_arrows()
		if _preview_routes_enabled() and _should_draw_interaction_overlay():
			_draw_interaction_overlay()
		if _preview_committed_intents_enabled():
			_draw_ability_intents()
		if _preview_arrows_enabled():
			_draw_forced_movement_arrows()
	elif _preview_routes_enabled() and _route.size() >= 2:
		_draw_route_line(_route, _COLOR_ROUTE, true, true)
	if _preview_routes_enabled():
		_draw_hover_tile()
	if _aiming:
		var aim_scale: float = 0.55 / _ui_scale()
		ClassIconDrawer.draw_icon(self, _aim_local, _aim_class_id, _COLOR_AIM, aim_scale)
	for entry: Array in _hit_markers:
		if entry.size() >= 2 and entry[0] is Vector2i:
			_draw_death_marker(entry[0] as Vector2i)


func _draw_hover_tiles() -> void:
	for cell: Vector2i in _hover_move_tiles:
		_draw_tile_tint(cell, _COLOR_MOVE, _COLOR_MOVE_FILL_ALPHA, false)
	for cell: Vector2i in _hover_action_range_tiles:
		_draw_tile_tint(cell, _COLOR_ACTION_RANGE, _COLOR_ACTION_RANGE_FILL_ALPHA, false)
	_draw_tile_perimeter(_hover_move_tiles, _COLOR_MOVE, _COLOR_MOVE_PERIMETER_ALPHA)
	_draw_tile_perimeter(_hover_action_range_tiles, _COLOR_ACTION_RANGE, _COLOR_ACTION_RANGE_PERIMETER_ALPHA)


func _draw_tile_tint(cell: Vector2i, tint: Color, fill_alpha: float, draw_border: bool = false) -> void:
	var tile_px: float = float(TacticalConstants.TILE_PX)
	var rect := Rect2(
		_map_view.grid_to_local(cell) - Vector2(tile_px * 0.5, tile_px * 0.5),
		Vector2(tile_px, tile_px),
	).grow(-2.0)
	draw_rect(rect, Color(tint.r, tint.g, tint.b, fill_alpha), true)
	if draw_border:
		draw_rect(rect, Color(tint.r, tint.g, tint.b, _COLOR_TILE_BORDER_ALPHA), false, 1.0)


func _draw_tile_perimeter(cells: Array[Vector2i], tint: Color, perimeter_alpha: float) -> void:
	if cells.is_empty() or _map_view == null:
		return
	var occupied: Dictionary = {}
	for cell: Vector2i in cells:
		occupied[cell] = true
	var half_extent: float = float(TacticalConstants.TILE_PX) * 0.5 - 1.0
	var color := Color(tint.r, tint.g, tint.b, perimeter_alpha)
	for cell: Vector2i in cells:
		var center: Vector2 = _map_view.grid_to_local(cell)
		var top_left := center + Vector2(-half_extent, -half_extent)
		var top_right := center + Vector2(half_extent, -half_extent)
		var bottom_right := center + Vector2(half_extent, half_extent)
		var bottom_left := center + Vector2(-half_extent, half_extent)
		if not occupied.has(cell + Vector2i.UP):
			draw_line(top_left, top_right, color, 1.0)
		if not occupied.has(cell + Vector2i.RIGHT):
			draw_line(top_right, bottom_right, color, 1.0)
		if not occupied.has(cell + Vector2i.DOWN):
			draw_line(bottom_right, bottom_left, color, 1.0)
		if not occupied.has(cell + Vector2i.LEFT):
			draw_line(bottom_left, top_left, color, 1.0)


func _draw_hover_tile() -> void:
	if not _board.is_in_bounds(_hover_coord):
		return
	if _planning_input != null and _director != null and _director.selected_unit_id >= 0:
		if _planning_input.selected_phase_action_exhausted(_director.selected_unit_id):
			return
		if CombatDirector.is_wait_ability_index(_director.selected_ability_index):
			return
	var tile_px: float = float(TacticalConstants.TILE_PX)
	var center: Vector2 = _map_view.grid_to_local(_hover_coord)
	var rect := Rect2(center - Vector2(tile_px * 0.5, tile_px * 0.5), Vector2(tile_px, tile_px)).grow(-2.0)
	draw_rect(rect, Color(_COLOR_HOVER, 0.10), true)
	draw_rect(rect, Color(_COLOR_HOVER.r, _COLOR_HOVER.g, _COLOR_HOVER.b, 0.45), false, 1.0)


func _draw_ability_intents() -> void:
	if _director == null or _board == null:
		return
	var plan_to_use: Timeline = _director.get_player_plan()
	if plan_to_use != null:
		for action: TimelineAction in plan_to_use.entries:
			if action.type != GameEnums.ActionType.ABILITY:
				continue
			if action.awaiting_target:
				continue
			var base_board: BoardState = _director.base_board if _director.base_board != null else _board
			var actor := base_board.get_unit_by_id(action.actor_id)
			if actor == null:
				continue
			var start_pos: Vector2i = CombatUiFormatters.plan_action_origin_cell(
				base_board, plan_to_use, action, actor,
			)
			if start_pos == action.target_coord:
				continue
			var p_col: Color = _player_color_for_unit(actor)
			var intent_cells: Array = CombatPlanningPreview.movement_intent_cells(start_pos, action)
			var draw_route: Array = intent_cells
			if (
				action.ability != null
				and AbilitySystem.ability_has_movement_effect(action.ability)
				and action.waypoints.is_empty()
			):
				## Committed action path must not use _pending_move_route_leg — that follows the
				## active move-timing slot (post-move) and falls back to a straight diagonal.
				if intent_cells.size() <= 2:
					var path_leg: Array = CombatPlanningPreview.committed_action_route_leg(
						action.actor_id, _committed_preview, action, start_pos,
					)
					if path_leg.size() >= 2:
						draw_route = path_leg
			if draw_route.size() >= 2:
				_draw_route_line(draw_route, p_col, true, true)
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
						var preview_for_push: CombatPlanningPreview = _active_preview()
						if _is_push_preview_segment(
							preview_for_push, enemy_pos, action.target_coord
						):
							continue
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
			or _planning_input.run_mode_selected()
			or _planning_input.is_live_preview_active()
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
			or _planning_input.run_mode_selected()
			or _planning_input.is_live_preview_active()
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
		return _live_preview.preview_board != null
	if (
		_planning_input.skill_interaction_active()
		or _planning_input.aiming
		or _planning_input.force_basic_movement
		or _planning_input.run_mode_selected()
		or _planning_input.is_live_preview_active()
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
		var end_d: float = dist
		var d: float = start_d
		while d < end_d:
			var draw_end: float = minf(d + dash, end_d)
			draw_line(p1 + dir * d, p1 + dir * draw_end, color, _DASH_LINE_W)
			d += dash + gap
	_draw_flowing_arrowheads_for_route(
		cells, color, _ROUTE_LINE_W, _DASH_WING_LEN, 30.0, 0.0,
	)


func _draw_flowing_arrowheads_on_line(
	start_pt: Vector2,
	end_pt: Vector2,
	color: Color,
	line_w: float,
	wing_len: float,
	wing_angle_deg: float,
	start_offset: float = 0.0,
	end_offset: float = 0.0,
) -> void:
	var delta: Vector2 = end_pt - start_pt
	var total_len: float = delta.length()
	if total_len < 0.001:
		return
	var dir: Vector2 = delta / total_len
	var t: float = Time.get_ticks_msec() / 1000.0
	var flow_speed := 45.0
	var wave_spacing := 90.0
	var path_offset: float = fmod(t * flow_speed, wave_spacing)
	var arrow_pos: float = path_offset
	while arrow_pos < total_len - end_offset:
		if arrow_pos > start_offset:
			var tip: Vector2 = start_pt + dir * arrow_pos
			var wing1: Vector2 = tip - dir.rotated(deg_to_rad(wing_angle_deg)) * wing_len
			var wing2: Vector2 = tip - dir.rotated(deg_to_rad(-wing_angle_deg)) * wing_len
			draw_line(tip, wing1, color, line_w)
			draw_line(tip, wing2, color, line_w)
		arrow_pos += wave_spacing


func _draw_flowing_arrowheads_for_route(
	cells: Array,
	color: Color,
	line_w: float,
	wing_len: float,
	wing_angle_deg: float,
	end_offset: float,
) -> void:
	if cells.size() < 2 or _map_view == null:
		return
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
	while arrow_pos < total_len - end_offset:
		if arrow_pos > end_offset:
			var current_d: float = arrow_pos
			var seg_idx := 0
			while seg_idx < segment_lengths.size() and current_d > segment_lengths[seg_idx]:
				current_d -= segment_lengths[seg_idx]
				seg_idx += 1
			if seg_idx < segment_lengths.size():
				var p1: Vector2 = segment_starts[seg_idx]
				var dir: Vector2 = segment_dirs[seg_idx]
				var tip: Vector2 = p1 + dir * current_d
				var wing1: Vector2 = tip - dir.rotated(deg_to_rad(wing_angle_deg)) * wing_len
				var wing2: Vector2 = tip - dir.rotated(deg_to_rad(-wing_angle_deg)) * wing_len
				draw_line(tip, wing1, color, line_w)
				draw_line(tip, wing2, color, line_w)
		arrow_pos += wave_spacing


func _draw_danger_area() -> void:
	if not _show_danger_area or _board == null or _director == null:
		return
	if _danger_tiles_dirty:
		_danger_tiles_cache.clear()
		for u: UnitState in _board.units:
			if not u.is_alive() or not u.is_enemy():
				continue
			var move_cost: int = 2 if u.has_status(GameEnums.StatusType.BLEED) else 1
			var mt: int = (
				u.definition.movement_type
				if u.definition != null
				else GameEnums.MovementType.WALK
			)
			var reach: Array[Vector2i] = MovementSystem.get_reachable_tiles(
				_board,
				u.position,
				u.movement.points_left,
				mt,
				move_cost,
			)
			var rng: int = _unit_attack_range(u, -1)
			for r: Vector2i in reach:
				for dy: int in range(-rng, rng + 1):
					for dx: int in range(-rng, rng + 1):
						if absi(dx) + absi(dy) > rng:
							continue
						var c2 := r + Vector2i(dx, dy)
						if _board.is_in_bounds(c2):
							_danger_tiles_cache[c2] = true
		_danger_tiles_dirty = false
	for c: Variant in _danger_tiles_cache:
		if c is Vector2i:
			_draw_tile_tint(c as Vector2i, _COLOR_DANGER, _COLOR_DANGER.a)


func _draw_preview_arrows() -> void:
	if _board == null or _director == null:
		return
	var prev: CombatPlanningPreview = _active_preview()
	for unit: UnitState in _board.units:
		if not unit.is_alive() or not _intent_visible(unit):
			continue
		if not unit.is_enemy():
			var p_col: Color = _player_color_for_unit(unit)
			for move_timing: int in [
				GameEnums.MoveTiming.PRE_ACTION,
				GameEnums.MoveTiming.POST_ACTION,
			]:
				var leg: Array = CombatPlanningPreview.committed_move_route_leg(
					unit.id, _committed_preview, _director, _board, move_timing,
				)
				if leg.size() < 2:
					continue
				if _skip_committed_move_leg_draw(unit.id, move_timing):
					continue
				_draw_route_line(leg, p_col, true, true)
		if prev.preview_board == null:
			continue
		var route: Array = prev.preview_paths.get(unit.id, [])
		if route.is_empty():
			continue
		var split: int = int(prev.preview_splits.get(unit.id, route.size()))
		var pushes: Array = prev.preview_pushes.get(unit.id, [])
		var enemy_leg: Array = []
		if unit.is_enemy() and split < route.size() and pushes.is_empty():
			enemy_leg = route.slice(maxi(split - 1, 0))
		if enemy_leg.size() >= 2:
			var dim_enemy := Color(_COLOR_ENEMY_ARROW.r, _COLOR_ENEMY_ARROW.g, _COLOR_ENEMY_ARROW.b, 0.35)
			_draw_route_line(enemy_leg, dim_enemy, split <= 1, true)
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


func _draw_forced_movement_arrows() -> void:
	if _board == null:
		return
	var sources: Array[CombatPlanningPreview] = []
	if _live_preview.preview_board != null:
		sources.append(_live_preview)
	if (
		_committed_preview.preview_board != null
		and _committed_preview != _live_preview
		and (
			_planning_input == null
			or not _planning_input.is_live_preview_active()
		)
	):
		sources.append(_committed_preview)
	if sources.is_empty() and _committed_preview.preview_board != null:
		sources.append(_committed_preview)
	var drawn: Dictionary = {}
	for prev: CombatPlanningPreview in sources:
		if prev.preview_board == null:
			continue
		for unit_id: Variant in prev.preview_pushes.keys():
			var pushes: Array = prev.preview_pushes.get(unit_id, [])
			for push: Variant in pushes:
				if not push is Array or push.size() < 2:
					continue
				var from_cell: Vector2i = push[0] as Vector2i
				var to_cell: Vector2i = push[1] as Vector2i
				var key: String = "%d|%s|%s" % [int(unit_id), str(from_cell), str(to_cell)]
				if drawn.has(key):
					continue
				drawn[key] = true
				var unit: UnitState = _board.get_unit_by_id(int(unit_id))
				if unit != null and unit.is_alive():
					_draw_push_arrow(from_cell, to_cell, unit)


func _interaction_move_hover_active(unit_id: int) -> bool:
	if _planning_input != null:
		return _planning_input.interaction_move_hover_active(unit_id, _hover_coord)
	if _director == null or unit_id < 0 or not _board.is_in_bounds(_hover_coord):
		return false
	var move_timing: int = _director.get_planning_move_timing(unit_id)
	if move_timing == -1:
		return false
	if _director.unit_has_move_planned_at_timing(unit_id, move_timing):
		return false
	return is_hover_move_tile(_hover_coord)


func _skip_committed_move_leg_draw(unit_id: int, leg_timing: int) -> bool:
	if _director == null or _planning_input == null or unit_id != _director.selected_unit_id:
		return false
	## Post committed leg hides during any move drag/hover (legacy overlay behavior).
	if leg_timing == GameEnums.MoveTiming.POST_ACTION:
		if _planning_input.dragging:
			return true
		if (
			_planning_input.is_live_preview_active()
			and _interaction_move_hover_active(unit_id)
		):
			return true
		return false
	var active_timing: int = _director.get_planning_move_timing(unit_id)
	if active_timing != leg_timing:
		return false
	if _planning_input.dragging:
		return true
	return (
		_planning_input.is_live_preview_active()
		and _interaction_move_hover_active(unit_id)
	)


func _pending_move_route_leg(unit_id: int, prev: CombatPlanningPreview) -> Array:
	return CombatPlanningPreview.pending_move_route_leg(unit_id, prev, _director, _board)


## Live/drag move arrow — same leg slice as commit preview.
func _interaction_move_route(unit_id: int, prev: CombatPlanningPreview, route: Array) -> Array:
	var leg: Array = _pending_move_route_leg(unit_id, prev)
	if leg.size() >= 2:
		return leg
	return []


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
	var p_col: Color = _player_color_for_unit(actor)
	var route: Array = prev.preview_paths.get(actor.id, [])
	if _planning_input != null and _planning_input.dragging:
		if route.size() >= 2 and _unit_can_still_move(actor.id):
			var drag_route: Array = _interaction_move_route(actor.id, prev, route)
			if drag_route.size() >= 2:
				_draw_route_line(drag_route, p_col, true, true)
	elif (
		_planning_input != null
		and not _planning_input.drag_preview_failed
		and _planning_input.is_live_preview_active()
		and _interaction_move_hover_active(actor.id)
	):
		var draw_route: Array = _interaction_move_route(actor.id, prev, route)
		if draw_route.size() >= 2:
			_draw_route_line(draw_route, p_col, true, true)
	var sel_ability := _selected_ability_data(actor, _director.selected_ability_index)
	var route_col := Color(p_col.r, p_col.g, p_col.b, 0.95)
	
	if _attack_target_id >= 0:
		var origin: Vector2i = actor.position
		var target_coord: Vector2i = _hover_coord
		var target_unit := prev.preview_board.get_unit_by_id(_attack_target_id)
		if target_unit == null and _board != null:
			target_unit = _board.get_unit_by_id(_attack_target_id)
		if target_unit != null:
			target_coord = target_unit.position
		if origin != target_coord and not _unit_has_push_preview(prev, _attack_target_id):
			_draw_route_line([origin, target_coord], route_col, true, true)
	elif (
		sel_ability != null
		and _planning_input != null
		and _planning_input.awaiting_targeting_active()
		and not AbilitySystem.ability_has_movement_effect(sel_ability)
		and AbilitySystem.planning_commit_flow(actor, sel_ability) == GameEnums.PlanningCommitFlow.AWAITING_TARGET
		and AbilitySystem.planning_is_valid_awaiting_endpoint(_proj_origin(actor), _hover_coord, sel_ability)
	):
		_draw_dashed_route([actor.position, _hover_coord], route_col)


func _unit_can_still_move(unit_id: int) -> bool:
	if unit_id < 0 or _director == null:
		return false
	var move_timing: int = _director.get_planning_move_timing(unit_id)
	if move_timing == -1:
		return false
	if _director.unit_has_move_planned_at_timing(unit_id, move_timing):
		return false
	var projected := _director.projected_state
	if projected == null:
		return false
	var unit: UnitState = projected.get_unit_by_id(unit_id)
	if unit == null or unit.is_enemy():
		return false
	if unit.movement.points_left <= 0:
		if _planning_input == null or not AbilitySystem.can_afford_run(unit):
			return false
	return true


func _draw_route_line(route: Array, color: Color, trim_start: bool, with_head: bool) -> void:
	if route.size() < 2:
		return
	var pts := PackedVector2Array()
	for tile: Variant in route:
		if tile is Vector2i:
			pts.append(_map_view.grid_to_local(tile))
	if pts.size() < 2:
		return
	var dest_center: Vector2 = pts[pts.size() - 1]
	if trim_start:
		var d0: Vector2 = pts[1] - pts[0]
		if d0.length() > 0.0:
			pts[0] += d0.normalized() * _token_radius()
	var smooth: PackedVector2Array = _rounded_route_polyline(pts, _ROUTE_CORNER_R)
	if smooth.size() < 2:
		return
	var end_dir: Vector2 = _route_terminal_direction_tiles(route)
	if end_dir.length_squared() < 0.001:
		end_dir = _route_end_direction(smooth)
	else:
		end_dir = end_dir.normalized()
	var flat_col := Color(color.r, color.g, color.b, 1.0)
	var shaft: PackedVector2Array = smooth
	if with_head:
		shaft = _clip_route_for_arrowhead(
			smooth,
			dest_center,
			end_dir,
			_ROUTE_HEAD_LEN * _ROUTE_SHAFT_HEAD_OVERLAP,
		)
	draw_polyline(shaft, flat_col, _ROUTE_LINE_W, _ROUTE_AA)
	if with_head:
		_draw_route_arrowhead(dest_center, end_dir, flat_col)


func _rounded_route_polyline(pts: PackedVector2Array, corner_r: float) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array()
	out.append(pts[0])
	for i: int in range(1, pts.size() - 1):
		var prev: Vector2 = pts[i - 1]
		var corner: Vector2 = pts[i]
		var next: Vector2 = pts[i + 1]
		var in_vec: Vector2 = corner - prev
		var out_vec: Vector2 = next - corner
		var in_len: float = in_vec.length()
		var out_len: float = out_vec.length()
		if in_len < 0.001 or out_len < 0.001:
			out.append(corner)
			continue
		var in_dir: Vector2 = in_vec / in_len
		var out_dir: Vector2 = out_vec / out_len
		if absf(in_dir.dot(out_dir)) > 0.995:
			out.append(corner)
			continue
		var r: float = minf(corner_r, minf(in_len * 0.48, out_len * 0.48))
		var p_before: Vector2 = corner - in_dir * r
		var p_after: Vector2 = corner + out_dir * r
		out.append(p_before)
		_append_quadratic_corner(out, p_before, corner, p_after, 7)
	out.append(pts[pts.size() - 1])
	return out


func _append_quadratic_corner(
	out: PackedVector2Array,
	a: Vector2,
	b: Vector2,
	c: Vector2,
	steps: int,
) -> void:
	for step: int in range(1, steps + 1):
		var t: float = float(step) / float(steps)
		var u: float = 1.0 - t
		out.append(u * u * a + 2.0 * u * t * b + t * t * c)


func _clip_route_for_arrowhead(
	path: PackedVector2Array,
	tip: Vector2,
	dir: Vector2,
	inset: float,
) -> PackedVector2Array:
	if path.is_empty():
		return path
	var travel_dir: Vector2 = dir
	if travel_dir.length_squared() < 0.0001:
		travel_dir = Vector2.RIGHT
	else:
		travel_dir = travel_dir.normalized()
	var base_pt: Vector2 = tip - travel_dir * inset
	var out := PackedVector2Array()
	for p: Vector2 in path:
		if p.distance_to(tip) > inset * 0.95:
			out.append(p)
	if out.is_empty():
		out.append(path[0])
	out.append(base_pt)
	return out


func _route_terminal_direction_tiles(route: Array) -> Vector2:
	if route.size() < 2 or _map_view == null:
		return Vector2.ZERO
	var from_tile: Variant = route[route.size() - 2]
	var to_tile: Variant = route[route.size() - 1]
	if not (from_tile is Vector2i) or not (to_tile is Vector2i):
		return Vector2.ZERO
	var delta: Vector2 = (
		_map_view.grid_to_local(to_tile as Vector2i)
		- _map_view.grid_to_local(from_tile as Vector2i)
	)
	if delta.length_squared() < 0.001:
		return Vector2.ZERO
	return delta.normalized()


func _draw_route_arrowhead(tip: Vector2, dir: Vector2, fill: Color) -> void:
	var travel_dir: Vector2 = dir
	if travel_dir.length_squared() < 0.0001:
		travel_dir = Vector2.RIGHT
	else:
		travel_dir = travel_dir.normalized()
	var perp: Vector2 = Vector2(-travel_dir.y, travel_dir.x)
	var base: Vector2 = tip - travel_dir * _ROUTE_HEAD_LEN
	var wing_l: Vector2 = base + perp * _ROUTE_HEAD_HALF_W
	var wing_r: Vector2 = base - perp * _ROUTE_HEAD_HALF_W
	var head := PackedVector2Array([tip, wing_l, wing_r])
	draw_colored_polygon(head, fill)


func _route_end_direction(path: PackedVector2Array) -> Vector2:
	if path.size() < 2:
		return Vector2.RIGHT
	var lookback: int = mini(3, path.size() - 1)
	var delta: Vector2 = path[path.size() - 1] - path[path.size() - 1 - lookback]
	if delta.length_squared() < 0.001:
		return Vector2.RIGHT
	return delta.normalized()


func _draw_death_marker(cell: Vector2i) -> void:
	var center: Vector2 = _map_view.grid_to_local(cell)
	var token_r: float = _token_radius()
	var death_col := Color(0.95, 0.25, 0.25, 0.9)
	draw_arc(center, token_r + 2.0, 0.0, TAU, 24, Color(death_col, 0.25), 2.5 / _ui_scale())
	var r: float = token_r * 0.65
	draw_line(center + Vector2(-r, -r), center + Vector2(r, r), death_col, 2.5 / _ui_scale())
	draw_line(center + Vector2(-r, r), center + Vector2(r, -r), death_col, 2.5 / _ui_scale())


func _draw_line_arrowhead(tip: Vector2, dir: Vector2, color: Color, line_w: float, head_len: float, angle_deg: float) -> void:
	var travel_dir: Vector2 = dir
	if travel_dir.length_squared() < 0.0001:
		travel_dir = Vector2.RIGHT
	else:
		travel_dir = travel_dir.normalized()
	var wing1: Vector2 = tip - travel_dir.rotated(deg_to_rad(angle_deg)) * head_len
	var wing2: Vector2 = tip - travel_dir.rotated(deg_to_rad(-angle_deg)) * head_len
	draw_line(tip, wing1, color, line_w)
	draw_line(tip, wing2, color, line_w)


func _forced_movement_intent_color(_pushed_unit: UnitState = null) -> Color:
	return Color(_COLOR_TARGET.r, _COLOR_TARGET.g, _COLOR_TARGET.b, 0.95)


func _is_push_preview_segment(
	prev: CombatPlanningPreview,
	from: Vector2i,
	to: Vector2i,
) -> bool:
	if prev == null:
		return false
	for push_list: Variant in prev.preview_pushes.values():
		if not push_list is Array:
			continue
		for seg: Variant in push_list:
			if seg is Array and seg.size() >= 2:
				if seg[0] == from and seg[1] == to:
					return true
	return false


func _unit_has_push_preview(prev: CombatPlanningPreview, unit_id: int) -> bool:
	if prev == null or unit_id < 0:
		return false
	var pushes: Array = prev.preview_pushes.get(unit_id, [])
	return not pushes.is_empty()


func _draw_dotted_intent_route(route: Array, color: Color, trim_start: bool) -> void:
	if route.size() < 2 or _map_view == null:
		return
	for i: int in range(route.size() - 1):
		if not (route[i] is Vector2i) or not (route[i + 1] is Vector2i):
			continue
		var is_last: bool = i == route.size() - 2
		_draw_dotted_intent_segment(
			route[i] as Vector2i,
			route[i + 1] as Vector2i,
			color,
			trim_start and i == 0,
			is_last,
		)


func _draw_dotted_intent_segment(
	from: Vector2i,
	to: Vector2i,
	color: Color,
	trim_start: bool,
	with_head: bool,
	flowing_head: bool = false,
) -> void:
	if _map_view == null:
		return
	var start_center: Vector2 = _map_view.grid_to_local(from)
	var dest_center: Vector2 = _map_view.grid_to_local(to)
	var delta: Vector2 = dest_center - start_center
	if delta.length_squared() < 0.001:
		return
	var travel_dir: Vector2 = delta.normalized()
	var start_pt: Vector2 = start_center
	if trim_start:
		start_pt = start_center + travel_dir * _token_radius()
	var shaft_end: Vector2 = dest_center
	if with_head:
		var inset: float = _INTENT_ARROW_HEAD_LEN * _ROUTE_SHAFT_HEAD_OVERLAP
		shaft_end = dest_center - travel_dir * inset
	if start_pt.distance_to(shaft_end) < 1.0:
		if with_head:
			if flowing_head:
				_draw_flowing_arrowheads_on_line(
					start_pt,
					dest_center,
					color,
					_FORCED_MOVE_LINE_W,
					_INTENT_ARROW_HEAD_LEN,
					_INTENT_ARROW_HEAD_ANGLE_DEG,
				)
			else:
				_draw_line_arrowhead(
					dest_center,
					travel_dir,
					color,
					_FORCED_MOVE_LINE_W,
					_INTENT_ARROW_HEAD_LEN,
					_INTENT_ARROW_HEAD_ANGLE_DEG,
				)
		return
	var dist: float = start_pt.distance_to(shaft_end)
	var d: float = 0.0
	while d < dist:
		draw_circle(start_pt + travel_dir * d, _INTENT_DOT_RADIUS, color)
		d += _INTENT_DOT_SPACING
	if with_head:
		if flowing_head:
			_draw_flowing_arrowheads_on_line(
				start_pt,
				dest_center,
				color,
				_FORCED_MOVE_LINE_W,
				_INTENT_ARROW_HEAD_LEN,
				_INTENT_ARROW_HEAD_ANGLE_DEG,
			)
		else:
			_draw_line_arrowhead(
				dest_center,
				travel_dir,
				color,
				_FORCED_MOVE_LINE_W,
				_INTENT_ARROW_HEAD_LEN,
				_INTENT_ARROW_HEAD_ANGLE_DEG,
			)


func _draw_displacement_intent_arrow(from: Vector2i, to: Vector2i, color: Color) -> void:
	_draw_dotted_intent_segment(from, to, color, true, true, true)


func _draw_push_arrow(from: Vector2i, to: Vector2i, pushed_unit: UnitState = null) -> void:
	_draw_displacement_intent_arrow(from, to, _forced_movement_intent_color(pushed_unit))


func _draw_ghosts() -> void:
	var prev: CombatPlanningPreview = _active_preview()
	if prev.preview_board == null or _board == null or _director == null:
		return
	var plan_to_use: Timeline = _director.get_player_plan()
	for unit: UnitState in _board.units:
		if not unit.is_alive() or not _intent_visible(unit):
			continue
		if not unit.is_enemy() and plan_to_use != null:
			var base_board: BoardState = (
				_director.base_board if _director.base_board != null else _board
			)
			for action: TimelineAction in plan_to_use.entries:
				if (
					action.actor_id == unit.id
					and action.type == GameEnums.ActionType.ABILITY
					and action.ability != null
					and AbilitySystem.planning_awaiting_endpoint_range(action.ability) > 0
					and not action.awaiting_target
				):
					var leg_origin: Vector2i = CombatUiFormatters.plan_action_origin_cell(
						base_board, plan_to_use, action, unit,
					)
					if action.target_coord == leg_origin:
						break
					var stand: Vector2i = unit.position
					var pv_unit: UnitState = (
						prev.preview_board.get_unit_by_id(unit.id)
						if prev.preview_board != null
						else null
					)
					if pv_unit != null:
						stand = pv_unit.position
					if action.target_coord == stand:
						break
					var center: Vector2 = _map_view.grid_to_local(action.target_coord)
					var ghost_col: Color = _player_color_for_unit(unit)
					var leg_face: int = CombatPlanningPreview.facing_along_planned_action(
						base_board, plan_to_use, action, prev,
					)
					if leg_face < 0:
						leg_face = unit.facing
					draw_circle(center, _token_radius(), Color(ghost_col.r, ghost_col.g, ghost_col.b, 0.35))
					_draw_facing_wedge(center, leg_face, Color(ghost_col.r, ghost_col.g, ghost_col.b, 0.8))
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
				var enemy_leg: Array = route.slice(maxi(route.size() - 2, 0))
				var face: int = CombatPlanningPreview.facing_from_route_leg(enemy_leg)
				if face < 0:
					var pv_enemy := prev.preview_board.get_unit_by_id(unit.id) if prev.preview_board != null else null
					face = pv_enemy.facing if pv_enemy != null else unit.facing
				_draw_facing_wedge(ghost_center, face, Color(_COLOR_ENEMY_ARROW.r, _COLOR_ENEMY_ARROW.g, _COLOR_ENEMY_ARROW.b, alpha + 0.15))


func _draw_move_ghosts() -> void:
	if _director == null or _board == null or _planning_input == null:
		return
	if _director.selected_unit_id < 0 or not _board.is_in_bounds(_hover_coord):
		return
	var unit := _proj_unit(_director.selected_unit_id)
	if unit == null or not unit.is_alive():
		return
	var force_basic: bool = _planning_input.force_basic_movement
	if not _can_show_action_range_tiles(unit, _director.selected_ability_index, force_basic):
		return
	var ability: AbilityData = _selected_ability_data(unit, _director.selected_ability_index)
	if ability == null or AbilitySystem.planning_commit_flow(unit, ability) != GameEnums.PlanningCommitFlow.AWAITING_TARGET:
		return
	if _planning_input != null and not _planning_input.awaiting_targeting_active():
		return
	var origin: Vector2i = _proj_origin(unit)
	if not AbilitySystem.planning_is_valid_awaiting_endpoint(origin, _hover_coord, ability):
		return
	var center: Vector2 = _map_view.grid_to_local(_hover_coord)
	var p_col: Color = _player_color_for_unit(unit)
	draw_circle(center, _token_radius() + 1.0, Color(p_col.r, p_col.g, p_col.b, 0.45))
	var dash_face: int = _facing_toward(origin, _hover_coord)
	_draw_facing_wedge(center, dash_face, Color(p_col.r, p_col.g, p_col.b, 0.85))
	if ability != null and AbilitySystem.ability_has_movement_effect(ability):
		var drag_route: Array = []
		var sim_path: Array = []
		var action_split: int = -1
		if _planning_input != null:
			drag_route = _planning_input.get_drag_route()
			var hover_preview: CombatPlanningPreview = _planning_input.preview_state
			if hover_preview != null:
				sim_path = hover_preview.preview_paths.get(unit.id, [])
				action_split = int(hover_preview.action_splits.get(unit.id, -1))
		var route_cells: Array[Vector2i] = CombatPlanningPreview.awaiting_movement_route_cells(
			origin, _hover_coord, drag_route, sim_path, action_split,
		)
		_draw_route_line(route_cells, Color(p_col.r, p_col.g, p_col.b, 0.85), true, true)
	else:
		_draw_route_line([origin, _hover_coord], Color(p_col.r, p_col.g, p_col.b, 0.85), true, true)


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
	if unit == null or _director == null:
		return Vector2i(-999999, -999999)
	return CombatPlanningPreview.planning_move_origin_cell(_director, _board, unit.id)


## Action-range anchor: committed projection plus live move-preview stand (intent truth).
## Phase-2 armed movement skills keep projected stand — dash endpoints come from there.
func _intent_stand_origin(unit: UnitState) -> Vector2i:
	var projected: Vector2i = _proj_origin(unit)
	if unit == null:
		return projected
	if _planning_input != null and _planning_input.awaiting_targeting_active():
		var sel_idx: int = _director.selected_ability_index if _director != null else -1
		var ability: AbilityData = _selected_ability_data(unit, sel_idx)
		if ability != null and AbilitySystem.is_movement_skill(ability):
			return projected
	if _planning_input != null and _planning_input.is_live_preview_active():
		var live_board: BoardState = _live_preview.preview_board
		if live_board != null:
			var live_unit: UnitState = live_board.get_unit_by_id(unit.id)
			if live_unit != null:
				return live_unit.position
	return projected


func _selected_ability_data(unit: UnitState, ability_index: int) -> AbilityData:
	return CombatDirector.resolve_selected_ability(unit, ability_index)


func _dash_amount(ability: AbilityData) -> int:
	if ability == null:
		return 0
	for eff: EffectData in ability.effects:
		if eff.type == GameEnums.EffectType.DASH:
			return eff.amount
	return 0


func _dash_threat_tiles(origin: Vector2i, steps: int) -> Array[Vector2i]:
	return AbilitySystem.dash_line_threat_tiles(_board, origin, steps)


func _movement_blocked_by_dash(unit: UnitState, selected_ability: int) -> bool:
	var ability: AbilityData = _selected_ability_data(unit, selected_ability)
	return ability != null and AbilitySystem.ability_blocks_basic_movement(ability)


func _move_budget_for_hover(unit: UnitState, selected_ability: int) -> int:
	var p_unit := _proj_unit(unit.id)
	var budget_unit: UnitState = p_unit if p_unit != null else unit
	if _planning_input != null and _planning_input.extended_move_budget_active(budget_unit):
		return AbilitySystem.preview_move_budget_with_run(budget_unit)
	if selected_ability < 0:
		return budget_unit.movement.points_left
	var ability: AbilityData = _selected_ability_data(unit, selected_ability)
	if (
		ability != null
		and AbilitySystem.is_run_ability(ability)
		and budget_unit.ability.points_left >= ability.action_point_cost
	):
		return AbilitySystem.preview_move_budget_with_run(budget_unit)
	return budget_unit.movement.points_left


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


func _populate_action_range_tiles(unit: UnitState, origin: Vector2i, selected_ability: int) -> void:
	if unit.is_enemy():
		var origins: Array[Vector2i] = _hover_move_tiles.duplicate()
		if origins.is_empty():
			origins.append(origin)
		for ability: AbilityData in unit.active_abilities:
			for src: Vector2i in origins:
				var tiles: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
					_board, unit, ability, src, [],
				)
				for tile: Vector2i in tiles:
					if not _hover_action_range_tiles.has(tile):
						_hover_action_range_tiles.append(tile)
		return
	var rng: int = _unit_attack_range(unit, selected_ability)
	if rng <= 0:
		if unit.id == _director.selected_unit_id and selected_ability >= 0:
			var sel_ability: AbilityData = _selected_ability_data(unit, selected_ability)
			if sel_ability != null and unit.get_ability_range(sel_ability) == 0:
				var self_tile: Array[Vector2i] = []
				self_tile.append(origin)
				_hover_action_range_tiles = self_tile
		return
	var threat_sources: Array[Vector2i] = []
	threat_sources.append(origin)
	for y: int in range(_board.grid_size.y):
		for x: int in range(_board.grid_size.x):
			var coord := Vector2i(x, y)
			if _hover_action_range_tiles.has(coord):
				continue
			for src: Vector2i in threat_sources:
				if GridSystem.manhattan(coord, src) <= rng:
					_hover_action_range_tiles.append(coord)
					break


func _add_action_range_tiles(unit: UnitState, origin: Vector2i, selected_ability: int) -> void:
	_populate_action_range_tiles(unit, origin, selected_ability)


func _update_hover_action_icon() -> void:
	if _planning_input != null:
		_hover_action_icon = _planning_input.compute_hover_action_icon(_hover_coord)
		return
	_hover_action_icon = ""
