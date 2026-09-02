class_name TacticalPlanningOverlay
extends Node2D

## Range tints, move route, aim icon, intent arrows, hover tile.
##
## Owner spec: docs/design/MOVE_PREVIEW_RULES.md
##
## Tile layers (_recompute_hover_ranges_from_inputs → _apply_planning_tile_layers):
## - BLUE: current movement-phase range (locked at phase-start stand).
## - RED: current non-move aim range OR next-phase range on hover (see spec).
## - YELLOW: hover-only click footprint (AOE blast); never frozen after commit.
## Floor tints are MapRoot children at Z_GROUND (0), below CharacterActor depth (min Z_UNDER_TREE = 1).
## Arrows/ghosts stay on this overlay node (z=11).

const _C = preload("res://scripts/mana_seed_constants.gd")

const _COLOR_MOVE := Color(0.35, 0.58, 0.92, 0.22)
const _COLOR_ACTION_RANGE := Color(0.92, 0.38, 0.32, 0.20)
const _COLOR_BLAST := Color(0.98, 0.84, 0.14, 0.20)
const _COLOR_MOVE_FILL_ALPHA: float = 0.22
const _COLOR_MOVE_PERIMETER_ALPHA: float = 0.72
const _COLOR_ACTION_RANGE_FILL_ALPHA: float = 0.24
const _COLOR_ACTION_RANGE_PERIMETER_ALPHA: float = 0.72
const _COLOR_BLAST_FILL_ALPHA: float = 0.34
const _COLOR_BLAST_PERIMETER_ALPHA: float = 0.82
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
const _TARGETING_INTENT_FLOW_SPEED: float = 45.0
const _TARGETING_INTENT_HEAD_SPACING: float = 90.0
const _FORCED_MOVE_INTENT_FLOW_SPEED: float = 45.0
const _FORCED_MOVE_INTENT_HEAD_SPACING: float = 48.0
const _PUSH_INTENT_DASH_LEN: float = 6.0
const _PUSH_INTENT_DASH_GAP: float = 4.0
const _PUSH_INTENT_CHEVRON_LEN: float = 5.0
const _PUSH_INTENT_CHEVRON_HALF_W: float = 3.5
const _INTENT_DOT_FLOW_SPEED: float = _TARGETING_INTENT_FLOW_SPEED * 0.4
## Hover tile/range throttle uses this interval (not chevron flow — flow redraws every frame).
const _FLOW_ANIM_REDRAW_INTERVAL_SEC: float = 1.0 / 60.0
const _DASH_LINE_W: float = 2.0
const _DASH_WING_LEN: float = 5.0
const _INTENT_ROUTE_ALPHA: float = 0.40

signal live_preview_changed

var _map_view: TacticalMapView
var _director: CombatDirector
var _intent_state: CombatIntentState
var _board: BoardState
var _preview_board: BoardState
var _aiming: bool = false
var _aim_local: Vector2 = Vector2.ZERO
var _aim_class_id: StringName = &"knight"
var _hover_coord: Vector2i = Vector2i(-999, -999)
var _phase: int = CombatDirector.Phase.PLANNING
var _hover_move_tiles: Array[Vector2i] = []
var _hover_action_range_tiles: Array[Vector2i] = []
var _hover_blast_tiles: Array[Vector2i] = []
## Cursor-following blast only (post-move stand locked). Drawn on hover layer — not static flood.
var _blast_tiles_on_hover_layer: bool = false
## Tier 3 QA: skip flow redraws from committed plan entries (drag-only pulse).
var qa_static_overlay: bool = false
var _hover_action_icon: String = ""
var _overlay_redraw_nonce: int = 0
var _live_preview: CombatPlanningPreview = CombatPlanningPreview.new()
var _committed_preview: CombatPlanningPreview = CombatPlanningPreview.new()
var _stashed_committed: CombatPlanningPreview = CombatPlanningPreview.new()
var _has_stashed_committed: bool = false
var _lock_committed_from_intent: bool = false
## Execution owns the board while its commit events are presenting; stale preview
## refreshes must not repaint the route that was just executed.
var _execution_preview_suppressed: bool = false
var _unit_layer: TacticalUnitLayer
var _planning_input: CombatPlanningInput
var _planning_cursor: TacticalPlanningCursor
var _attack_target_id: int = -1
var _show_danger_area: bool = false
var _danger_tiles_cache: Dictionary = {}
var _danger_tiles_dirty: bool = true
var _hit_markers: Array = []
var _game_settings: GameSettings
var _hover_perimeter_cache_key: int = 0
var _cached_hover_perimeter_segments: Array = []
var _static_tiles_layer: Node2D
var _hover_tile_layer: Node2D
var _flow_arrows_layer: Node2D
var _draw_target: CanvasItem = null
var _anim_redraw_accum: float = 0.0


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
	EventBus.planning_commit_events.connect(_on_planning_commit_events)
	EventBus.timeline_changed.connect(func(_plan: Timeline, _statuses: PackedStringArray) -> void:
		_invalidate_hover_cache()
		_recompute_hover_ranges_from_inputs()
	)
	EventBus.selection_changed.connect(func(_id: int) -> void:
		if _director == null:
			return
		_update_hover_action_icon()
		_queue_overlay_redraw(),
	)
	EventBus.turn_phase_changed.connect(func(phase: int) -> void:
		var was_planning: bool = CombatDirector.is_planning_phase(_phase)
		_phase = phase
		var planning: bool = CombatDirector.is_planning_phase(phase)
		if was_planning and not planning:
			_clear_execution_preview_state()
		elif planning and not was_planning:
			_execution_preview_suppressed = false
		if not planning and _planning_input != null:
			_planning_input.clear_interaction_preview()
		_invalidate_hover_cache()
		if planning:
			_recompute_hover_ranges_from_inputs()
		else:
			_hover_move_tiles.clear()
			_clear_hover_skill_tiles()
			_queue_static_tiles_redraw()
		mark_danger_dirty()
		_queue_overlay_redraw(),
	)
	EventBus.sim_event.connect(_on_sim_event)
	if _intent_state != null:
		_intent_state.intents_changed.connect(func(_units: Dictionary) -> void: _queue_overlay_redraw())
		_intent_state.hover_coord_changed.connect(func(coord: Vector2i) -> void:
			set_hover_coord(coord, true),
		)
	set_process(true)
	_ensure_static_tiles_layer()
	_ensure_flow_arrows_layer()
	_ensure_hover_tile_layer()
	_attach_floor_draw_layer_to_map_root(_static_tiles_layer)
	_attach_floor_draw_layer_to_map_root(_hover_tile_layer)


func _configure_floor_draw_layer(layer: Node2D) -> void:
	layer.z_as_relative = false
	layer.z_index = _C.Z_GROUND
	_attach_floor_draw_layer_to_map_root(layer)


func _attach_floor_draw_layer_to_map_root(layer: Node2D) -> void:
	if layer == null or _map_view == null:
		return
	var root: Node2D = _map_view.get_map_root()
	if root == null:
		return
	if layer.get_parent() != root:
		if layer.get_parent() != null:
			layer.reparent(root)
		else:
			root.add_child(layer)
	var unit_layer: Node = root.find_child("UnitLayer", false, false)
	if unit_layer != null:
		var unit_idx: int = unit_layer.get_index()
		if layer.get_index() != unit_idx:
			root.move_child(layer, unit_idx)


func _ensure_static_tiles_layer() -> void:
	if _static_tiles_layer != null:
		return
	_static_tiles_layer = Node2D.new()
	_static_tiles_layer.name = "StaticTiles"
	_static_tiles_layer.draw.connect(_draw_static_tile_layers)
	_configure_floor_draw_layer(_static_tiles_layer)
	if _static_tiles_layer.get_parent() == null:
		add_child(_static_tiles_layer)


func _ensure_flow_arrows_layer() -> void:
	if _flow_arrows_layer != null:
		return
	_flow_arrows_layer = Node2D.new()
	_flow_arrows_layer.name = "FlowArrows"
	_flow_arrows_layer.draw.connect(_draw_flow_arrows_layer)
	add_child(_flow_arrows_layer)


func _queue_flow_arrows_redraw() -> void:
	if _flow_arrows_layer != null:
		_flow_arrows_layer.queue_redraw()


func _queue_overlay_redraw() -> void:
	_overlay_redraw_nonce += 1
	_anim_redraw_accum = 0.0
	queue_redraw()
	_queue_flow_arrows_redraw()


## Headless QA: main overlay redraw requests (move-preview ghost circles live here).
func overlay_redraw_nonce() -> int:
	return _overlay_redraw_nonce


func _overlay_draw_target() -> CanvasItem:
	return _draw_target if _draw_target != null else self


func _overlay_flow_interval_sec() -> float:
	if qa_static_overlay or _game_settings == null:
		return _FLOW_ANIM_REDRAW_INTERVAL_SEC
	return _game_settings.overlay_flow_interval_sec()


func _ensure_hover_tile_layer() -> void:
	if _hover_tile_layer != null:
		return
	_hover_tile_layer = Node2D.new()
	_hover_tile_layer.name = "HoverTile"
	_hover_tile_layer.draw.connect(_draw_hover_tile_layer)
	_configure_floor_draw_layer(_hover_tile_layer)
	if _hover_tile_layer.get_parent() == null:
		add_child(_hover_tile_layer)


func _queue_hover_tile_redraw() -> void:
	if _hover_tile_layer != null:
		_hover_tile_layer.queue_redraw()


func _draw_hover_tile_layer() -> void:
	if _hover_tile_layer == null:
		return
	_draw_hover_tile_on(_hover_tile_layer)


func _queue_static_tiles_redraw() -> void:
	if _static_tiles_layer != null:
		_static_tiles_layer.queue_redraw()


func _draw_static_tile_layers() -> void:
	if _board == null or _map_view == null or _director == null:
		return
	var canvas: CanvasItem = _static_tiles_layer
	if canvas == null:
		return
	if CombatDirector.is_planning_phase(_phase):
		_draw_danger_area(canvas)
	if _preview_range_overlays_enabled():
		_draw_hover_tiles(canvas)


func teardown() -> void:
	set_process(false)
	if _hover_tile_layer != null:
		_hover_tile_layer.queue_free()
		_hover_tile_layer = null
	if _flow_arrows_layer != null:
		_flow_arrows_layer.queue_free()
		_flow_arrows_layer = null
	if _static_tiles_layer != null:
		_static_tiles_layer.queue_free()
		_static_tiles_layer = null
	_map_view = null
	_director = null
	_intent_state = null
	_planning_input = null


func apply_settings(settings: GameSettings) -> void:
	_game_settings = settings
	if _planning_input != null:
		_planning_input.refresh_mouse_cursor(_hover_coord)
	_queue_static_tiles_redraw()
	_queue_overlay_redraw()


func game_settings() -> GameSettings:
	return _game_settings


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
	_queue_static_tiles_redraw()


func mark_danger_dirty() -> void:
	_danger_tiles_dirty = true
	_queue_static_tiles_redraw()


func get_show_danger_area() -> bool:
	return _show_danger_area


func bind_unit_layer(layer: TacticalUnitLayer) -> void:
	_unit_layer = layer


func bind_planning_input(input: CombatPlanningInput) -> void:
	_planning_input = input
	_invalidate_hover_cache()
	_recompute_hover_ranges_from_inputs()


func _invalidate_hover_cache() -> void:
	_hover_perimeter_cache_key = 0
	_cached_hover_perimeter_segments.clear()


func _hover_tile_perimeter_cache_key() -> int:
	return hash([_hover_move_tiles, _hover_action_range_tiles, _hover_blast_tiles])


func _ensure_hover_perimeter_cache() -> void:
	var cache_key: int = _hover_tile_perimeter_cache_key()
	if cache_key == _hover_perimeter_cache_key:
		return
	_hover_perimeter_cache_key = cache_key
	_cached_hover_perimeter_segments.clear()
	_collect_tile_perimeter_segments(
		_hover_move_tiles, _COLOR_MOVE, _COLOR_MOVE_PERIMETER_ALPHA, _cached_hover_perimeter_segments,
	)
	_collect_tile_perimeter_segments(
		_hover_action_range_tiles,
		_COLOR_ACTION_RANGE,
		_COLOR_ACTION_RANGE_PERIMETER_ALPHA,
		_cached_hover_perimeter_segments,
	)
	_collect_tile_perimeter_segments(
		_hover_blast_tiles,
		_COLOR_BLAST,
		_COLOR_BLAST_PERIMETER_ALPHA,
		_cached_hover_perimeter_segments,
	)


func _collect_tile_perimeter_segments(
	cells: Array[Vector2i],
	tint: Color,
	perimeter_alpha: float,
	out_segments: Array,
) -> void:
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
			out_segments.append([top_left, top_right, color])
		if not occupied.has(cell + Vector2i.RIGHT):
			out_segments.append([top_right, bottom_right, color])
		if not occupied.has(cell + Vector2i.DOWN):
			out_segments.append([bottom_right, bottom_left, color])
		if not occupied.has(cell + Vector2i.LEFT):
			out_segments.append([bottom_left, top_left, color])


func _planning_action_range_tiles_for_unit(
	unit: UnitState,
	origin: Vector2i,
	selected_ability: int,
	range_hover: Vector2i = Vector2i(-999999, -999999),
) -> Array[Vector2i]:
	var hover_coord: Vector2i = range_hover if range_hover.x > -900000 else _hover_coord
	return PlanningPreviewTiles.action_range_tiles(
		_director,
		_board,
		unit,
		selected_ability,
		_planning_input,
		origin,
		hover_coord,
	)
func _hover_is_walk_only_premove(unit: UnitState) -> bool:
	if _planning_input != null:
		return _planning_input.is_walk_only_hover_move(unit, _hover_coord)
	return false


func _clear_hover_skill_tiles() -> void:
	_blast_tiles_on_hover_layer = false
	_hover_action_range_tiles.clear()
	_hover_blast_tiles.clear()


func _hover_action_range_uses_blast_at_coord(
	unit: UnitState,
	_p_unit: UnitState,
	selected_ability: int,
	_cache_force: bool,
) -> bool:
	## Yellow impact tiles follow the aim hover for every skill (SINGLE and shaped).
	return _board != null and _board.is_in_bounds(_hover_coord)


func _recompute_hover_ranges_from_inputs() -> void:
	if _director == null:
		return
	var voluntary_walk: bool = (
		_planning_input._voluntary_walk_planning_active()
		if _planning_input != null else false
	)
	var dragging: bool = _planning_input.dragging if _planning_input != null else false
	var drag_id: int = _planning_input.get_drag_unit_id() if _planning_input != null else -1
	recompute_hover_ranges(voluntary_walk, _director.selected_ability_index, dragging, drag_id)


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


func _debug_intent_stand_array() -> Array:
	if _director == null or _board == null or _director.selected_unit_id < 0:
		return [-999, -999]
	var unit: UnitState = _board.get_unit_by_id(_director.selected_unit_id)
	if unit == null:
		return [-999, -999]
	var stand: Vector2i = _intent_stand_origin(unit)
	return [stand.x, stand.y]


func build_debug_context() -> Dictionary:
	return {
		"hover_coord": [_hover_coord.x, _hover_coord.y],
		"hover_move_tiles": _coords_to_arrays(_hover_move_tiles),
		"hover_action_range_tiles": _coords_to_arrays(_hover_action_range_tiles),
		"hover_blast_tiles": _coords_to_arrays(_hover_blast_tiles),
		"route": (
			_coords_to_arrays(_planning_input.get_drag_route())
			if _planning_input != null
			else []
		),
		"aiming": _aiming,
		"attack_target_id": _attack_target_id,
		"intent_stand_origin": _debug_intent_stand_array(),
		"hover_action_icon": _hover_action_icon,
	}


static func _coords_to_arrays(coords: Array[Vector2i]) -> Array[Array]:
	var result: Array[Array] = []
	for coord: Vector2i in coords:
		result.append([coord.x, coord.y])
	return result


func get_hover_move_tiles() -> Array[Vector2i]:
	return _hover_move_tiles.duplicate()


func get_hover_action_range_tiles() -> Array[Vector2i]:
	return _hover_action_range_tiles.duplicate()


func get_hover_blast_tiles() -> Array[Vector2i]:
	return _hover_blast_tiles.duplicate()


func is_hover_move_tile(cell: Vector2i) -> bool:
	return _hover_move_tiles.has(cell)


func is_hover_action_range_tile(cell: Vector2i) -> bool:
	return _hover_action_range_tiles.has(cell)


func is_hover_blast_tile(cell: Vector2i) -> bool:
	return _hover_blast_tiles.has(cell)


func is_hover_threat_tile(cell: Vector2i) -> bool:
	return is_hover_action_range_tile(cell)


## Global movement hover route — preview_paths SSOT for premove, move module, and postmove.
func _movement_hover_route_cells(unit_id: int = -1) -> Array[Vector2i]:
	if _director == null or _board == null or _planning_input == null:
		return []
	if unit_id < 0:
		unit_id = _director.selected_unit_id
	if unit_id < 0 or not _board.is_in_bounds(_hover_coord):
		return []
	var unit: UnitState = _proj_unit(unit_id)
	if unit == null or not unit.is_alive():
		return []
	var ability: AbilityData = _selected_ability_data(unit, _director.selected_ability_index)
	if ability == null:
		var awaiting_action: TimelineAction = _director.find_awaiting_action(unit_id)
		if awaiting_action != null:
			ability = awaiting_action.ability
	if ability == null:
		return []
	if not _movement_hover_route_context_active(unit, ability):
		return []
	return _planning_input.display_move_route_cells(unit_id)


func _movement_hover_route_context_active(unit: UnitState, ability: AbilityData) -> bool:
	if _planning_input == null or unit == null or ability == null:
		return false
	return _planning_input.movement_hover_route_display_applies(unit, ability)


func _display_move_route_cells(unit_id: int) -> Array[Vector2i]:
	if _planning_input == null or unit_id < 0:
		return []
	return _planning_input.display_move_route_cells(unit_id)


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
	_live_preview.clear_route_geometry()
	_attack_target_id = -1
	_preview_board = _committed_preview.preview_board
	if _planning_input != null:
		_planning_input.clear_hover_route_preview()
	if _unit_layer != null:
		_unit_layer.clear_live_forecast()
	_push_committed_forecast_to_unit_layer()
	live_preview_changed.emit()
	_queue_overlay_redraw()


## Global HP/armor forecast — committed full-turn sim merged with live hover sim on the bar.
func _push_committed_forecast_to_unit_layer() -> void:
	if _unit_layer == null:
		return
	if not CombatDirector.is_planning_phase(_phase):
		return
	_unit_layer.set_committed_forecast(_committed_preview.forecast)


## No planning preview survives the transition into execution, including pre-move execution.
func _clear_execution_preview_state() -> void:
	_execution_preview_suppressed = true
	_live_preview.clear_all()
	_committed_preview.clear_all()
	_stashed_committed.clear_all()
	_has_stashed_committed = false
	_lock_committed_from_intent = false
	_preview_board = null
	_hover_move_tiles.clear()
	_clear_hover_skill_tiles()
	_hit_markers.clear()
	_attack_target_id = -1
	_invalidate_hover_cache()
	_queue_overlay_redraw()


## A planning commit starts execution before the phase enum changes. Clear the
## display at that boundary so premove execution cannot show its old route.
func _on_planning_commit_events(events: Array) -> void:
	if events.is_empty() or not CombatDirector.is_planning_phase(_phase):
		return
	_clear_execution_preview_state()


## Promote the painted live intent to committed display (move-preview intent truth).
## Locks the next preview_updated so director refresh cannot replace that picture.
## Keeps preview_pushes — commit ratifies the full live picture (including forced movement).
## Do not call ensure_movement_intent_from_plan here — that recalculates routes and
## violates move-preview intent truth (preview already ratified in _live_preview).
func promote_live_preview_to_committed() -> void:
	_committed_preview.copy_from(_live_preview)
	_preview_board = _committed_preview.preview_board
	_has_stashed_committed = false
	if _director != null and _committed_preview.forecast != null:
		_committed_preview.forecast.revision = _director.plan_revision
	_lock_committed_from_intent = true
	restore_committed_display()


func apply_preview_state(
	state: CombatPlanningPreview,
	selected_id: int,
	attack_target_id: int,
) -> void:
	_execution_preview_suppressed = false
	_live_preview.copy_from(state)
	_attack_target_id = attack_target_id
	if _unit_layer != null:
		if _live_preview.forecast != null:
			_unit_layer.set_live_forecast(_live_preview.forecast)
		else:
			_unit_layer.clear_live_forecast()
	live_preview_changed.emit()
	## Live route/ghost only — flow chevrons already redraw every frame; skip duplicate flow queue.
	queue_redraw()


func set_live_preview(state: CombatPlanningPreview) -> void:
	_execution_preview_suppressed = false
	_live_preview = state
	if _unit_layer != null:
		_unit_layer.set_live_forecast(_live_preview.forecast)
	_queue_overlay_redraw()


func set_board(board: BoardState) -> void:
	_board = board
	_queue_overlay_redraw()


func set_preview_board(board: BoardState) -> void:
	_preview_board = board
	_queue_overlay_redraw()


func set_hover_coord(coord: Vector2i, redraw: bool = true) -> void:
	if coord == _hover_coord:
		return
	_hover_coord = coord
	if _director != null and (
		_director.selected_unit_id < 0 or CombatDirector.is_planning_phase(_phase)
	):
		_recompute_hover_ranges_from_inputs()
	if _planning_input == null:
		_update_hover_action_icon()
	if redraw:
		_queue_hover_tile_redraw()
		_queue_overlay_redraw()


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


## Legacy test hook — drag route SSOT is CombatPlanningInput._drag_route.
func set_drag_route(_route_unused: Array[Vector2i]) -> void:
	_queue_overlay_redraw()


func clear_drag_route() -> void:
	_queue_overlay_redraw()


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
	_queue_overlay_redraw()


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
	_queue_overlay_redraw()


func is_system_mouse_override() -> bool:
	return _planning_cursor != null and _planning_cursor.is_system_mouse_override()


func clear_planning_cursor_icon() -> void:
	_hover_action_icon = ""
	if _planning_cursor != null:
		_planning_cursor.set_icon("")
	_queue_overlay_redraw()


func _is_selected_player_unit(unit: UnitState) -> bool:
	return (
		unit != null
		and not unit.is_enemy()
		and _director != null
		and unit.id == _director.selected_unit_id
	)


func _awaiting_module_index_for(unit: UnitState) -> int:
	if _director == null or unit == null:
		return 0
	var awaiting: TimelineAction = _director.find_awaiting_action(unit.id)
	if awaiting != null and awaiting.awaiting_module_index >= 0:
		return awaiting.awaiting_module_index
	return 0


func _intent_tiles_blocked(unit: UnitState, selected_ability: int) -> bool:
	return PlanningPreviewTiles.tiles_blocked(
		_director, unit, selected_ability, _planning_input, _is_selected_player_unit(unit),
	)


func _movement_status_blocked(unit: UnitState) -> bool:
	if unit == null:
		return true
	return unit.has_status(GameEnums.StatusType.ROOT) or unit.has_status(GameEnums.StatusType.STAGGER)


func _compute_move_budget(unit: UnitState, p_unit: UnitState, selected_ability: int) -> int:
	return PlanningPreviewTiles.move_budget_for_preview(
		_director, p_unit, selected_ability, _planning_input,
	)


func _can_show_move_tiles(unit: UnitState, selected_ability: int) -> bool:
	if unit == null:
		return false
	if _planning_input != null and _planning_input.awaiting_targeting_active():
		var awaiting_ability: AbilityData = _selected_ability_data(unit, selected_ability)
		if (
			awaiting_ability == null
			or not _planning_input._is_awaiting_movement_endpoint(unit, awaiting_ability)
		):
			return false
	if _director != null:
		var voluntary_walk_step: bool = (
			_planning_input == null
			or not _planning_input.active_movement_planning_step(unit)
		)
		if voluntary_walk_step:
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


func recompute_hover_ranges(
	voluntary_walk: bool,
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
		_clear_hover_skill_tiles()
		_queue_static_tiles_redraw()
		return
	var cache_force: bool = voluntary_walk if unit.id == _director.selected_unit_id else false
	_hover_move_tiles.clear()
	_clear_hover_skill_tiles()
	_apply_planning_tile_layers(unit, cache_force, selected_ability, dragging)
	_queue_static_tiles_redraw()


## MOVE_PREVIEW_RULES tile SSOT — one apply path (two-range model via PlanningPreviewTiles).
## EX-LOCKED-FIELD: locked current-phase blue/red always from resolve_layer_origins (not bundle-gated).
## Bundle when matched supplies hover-shaped layers only (next-field range, next move flood, blast).
func _apply_planning_tile_layers(
	unit: UnitState,
	voluntary_walk: bool,
	selected_ability: int,
	dragging: bool,
) -> void:
	if _board == null or _director == null or unit == null:
		return
	var is_selected_player: bool = _is_selected_player_unit(unit)
	if PlanningPreviewTiles.tiles_blocked(
		_director, unit, selected_ability, _planning_input, is_selected_player,
	):
		return
	var paint_hover: Vector2i = _hover_coord
	var settled: PlanningHoverPreview = null
	var paint_matches: bool = false
	if is_selected_player and _planning_input != null:
		paint_hover = _planning_input.pointer_grid_cell()
		settled = _planning_input.get_settled_hover_preview()
		if settled != null:
			paint_matches = settled.matches_paint_context(
				paint_hover,
				unit.id,
				"",
				selected_ability,
			)
			if (
				not paint_matches
				and _board != null
				and not _board.is_in_bounds(paint_hover)
			):
				paint_matches = settled.matches_display_context(
					unit.id,
					"",
					selected_ability,
				)
	var layer_plan: Dictionary = PlanningPreviewTiles.resolve_layer_origins(
		_director, _board, unit, selected_ability, _planning_input, paint_hover,
	)
	var phase: int = int(layer_plan.get("phase", PlanningPreviewTiles.PhaseKind.NON_MOVEMENT))
	var locked_phase: int = phase
	var locked_plan: Dictionary = layer_plan
	if settled != null and settled.valid and not paint_matches:
		locked_plan = PlanningPreviewTiles.resolve_layer_origins(
			_director, _board, unit, selected_ability, _planning_input, settled.hover_cell,
		)
		locked_phase = int(
			locked_plan.get("phase", PlanningPreviewTiles.PhaseKind.NON_MOVEMENT),
		)
	var locked_stand: Vector2i = Vector2i(-999999, -999999)
	var show_locked_action_range: bool = bool(locked_plan.get("show_action_range", false))
	var committed_class_action: bool = (
		_director != null and _director.unit_has_committed_class_action(unit.id)
	)
	match locked_phase:
		PlanningPreviewTiles.PhaseKind.MOVEMENT:
			locked_stand = locked_plan.get("locked_move_origin", locked_stand)
		PlanningPreviewTiles.PhaseKind.NON_MOVEMENT:
			locked_stand = locked_plan.get("locked_aim_origin", locked_stand)
	match locked_phase:
		PlanningPreviewTiles.PhaseKind.WAIT:
			return
		PlanningPreviewTiles.PhaseKind.MOVEMENT:
			if locked_stand.x > -900000 and _can_show_move_tiles(unit, selected_ability):
				_hover_move_tiles = PlanningPreviewTiles.reachable_move_tiles(
					_director, _board, unit, selected_ability, _planning_input, locked_stand,
				)
		PlanningPreviewTiles.PhaseKind.NON_MOVEMENT:
			if locked_stand.x > -900000 and show_locked_action_range:
				_blast_tiles_on_hover_layer = false
				_hover_action_range_tiles = _planning_action_range_tiles_for_unit(
					unit,
					locked_stand,
					selected_ability if is_selected_player else -1,
					locked_stand,
				)
	if is_selected_player and _planning_input != null and settled != null:
		if paint_matches:
			match phase:
				PlanningPreviewTiles.PhaseKind.MOVEMENT:
					_hover_action_range_tiles = settled.action_range_tiles.duplicate()
					if committed_class_action and not settled.blast_on_hover_layer:
						_hover_blast_tiles.clear()
						_blast_tiles_on_hover_layer = false
					else:
						_hover_blast_tiles = settled.blast_tiles.duplicate()
						_blast_tiles_on_hover_layer = settled.blast_on_hover_layer
				PlanningPreviewTiles.PhaseKind.NON_MOVEMENT:
					_hover_move_tiles = settled.move_tiles.duplicate()
					if not settled.action_range_tiles.is_empty():
						_hover_action_range_tiles = settled.action_range_tiles.duplicate()
					if committed_class_action and not settled.blast_on_hover_layer:
						_hover_blast_tiles.clear()
						_blast_tiles_on_hover_layer = false
					else:
						_hover_blast_tiles = settled.blast_tiles.duplicate()
						_blast_tiles_on_hover_layer = settled.blast_on_hover_layer
			return
		## Bundle mismatch: locked fields painted above; hold last sealed hover-shaped layers.
		if settled.valid:
			match locked_phase:
				PlanningPreviewTiles.PhaseKind.MOVEMENT:
					_hover_action_range_tiles = settled.action_range_tiles.duplicate()
					if not committed_class_action:
						_hover_blast_tiles = settled.blast_tiles.duplicate()
						_blast_tiles_on_hover_layer = settled.blast_on_hover_layer
				PlanningPreviewTiles.PhaseKind.NON_MOVEMENT:
					_hover_move_tiles = settled.move_tiles.duplicate()
					if not settled.action_range_tiles.is_empty():
						_hover_action_range_tiles = settled.action_range_tiles.duplicate()
					if not committed_class_action:
						_hover_blast_tiles = settled.blast_tiles.duplicate()
						_blast_tiles_on_hover_layer = settled.blast_on_hover_layer
		elif committed_class_action:
			_hover_blast_tiles.clear()
			_blast_tiles_on_hover_layer = false
		return
	match phase:
		PlanningPreviewTiles.PhaseKind.MOVEMENT:
			var next_aim: Vector2i = layer_plan.get("next_aim_origin", Vector2i(-999999, -999999))
			if next_aim.x > -900000:
				_blast_tiles_on_hover_layer = false
				_hover_action_range_tiles = _planning_action_range_tiles_for_unit(
					unit,
					next_aim,
					selected_ability if is_selected_player else -1,
					paint_hover,
				)
		PlanningPreviewTiles.PhaseKind.NON_MOVEMENT:
			var next_move: Vector2i = layer_plan.get("next_move_origin", Vector2i(-999999, -999999))
			if next_move.x > -900000 and _can_show_move_tiles(unit, selected_ability):
				_hover_move_tiles = PlanningPreviewTiles.reachable_move_tiles(
					_director, _board, unit, selected_ability, _planning_input, next_move,
				)
func _on_board_changed(board: BoardState) -> void:
	set_board(board)
	_danger_tiles_dirty = true
	_invalidate_hover_cache()
	_queue_static_tiles_redraw()


func _process(delta: float) -> void:
	var need_redraw := false
	for i: int in range(_hit_markers.size() - 1, -1, -1):
		var entry: Array = _hit_markers[i]
		entry[1] = float(entry[1]) - delta
		if float(entry[1]) <= 0.0:
			_hit_markers.remove_at(i)
		need_redraw = true
	if need_redraw:
		_queue_overlay_redraw()
		return
	if not CombatDirector.is_planning_phase(_phase) or not _overlay_needs_flow_animation():
		return
	## Chevron motion only — redraw flow layer every frame (uncapped).
	_queue_flow_arrows_redraw()


func _overlay_needs_flow_animation() -> bool:
	if qa_static_overlay:
		return _planning_input != null and _planning_input.dragging
	return _preview_arrows_enabled() or _preview_committed_intents_enabled()


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
	if _execution_preview_suppressed:
		return
	## Intent truth: after promote_live_preview_to_committed, do not rebuild ghosts from a
	## second sim — keep the ratified picture (including preview_board pointer).
	if _lock_committed_from_intent:
		_lock_committed_from_intent = false
		_has_stashed_committed = false
		_queue_overlay_redraw()
		return
	_apply_committed_preview_update(result)


func _apply_committed_preview_update(result: SimResult) -> void:
	_hit_markers.clear()
	set_preview_board(result.final_state)
	if _director != null and _board != null:
		_committed_preview = CombatPlanningPreview.from_sim_result(result, _director, _board)
		_preview_board = _committed_preview.preview_board
	_has_stashed_committed = false
	_invalidate_hover_cache()
	_recompute_hover_ranges_from_inputs()
	_push_committed_forecast_to_unit_layer()
	if _planning_input == null or not _planning_input.is_live_preview_active():
		live_preview_changed.emit()
	_queue_overlay_redraw()


func _draw() -> void:
	_draw_target = self
	if _board == null or _map_view == null or _director == null:
		_draw_target = null
		return
	var show_planning: bool = CombatDirector.is_planning_phase(_phase)
	if show_planning:
		if _preview_live_ghosts_enabled():
			_draw_move_ghosts()
		if _preview_live_ghosts_enabled():
			_draw_ghosts()
		if _preview_arrows_enabled():
			_draw_preview_arrows()
		if _preview_routes_enabled() and _should_draw_interaction_overlay():
			_draw_interaction_overlay(false)
		if _preview_committed_intents_enabled():
			_draw_ability_intents(false)
	if _aiming:
		var aim_scale: float = 0.55 / _ui_scale()
		ClassIconDrawer.draw_icon(self, _aim_local, _aim_class_id, _COLOR_AIM, aim_scale)
	for entry: Array in _hit_markers:
		if entry.size() >= 2 and entry[0] is Vector2i:
			_draw_death_marker(entry[0] as Vector2i)
	_draw_target = null


func _draw_flow_arrows_layer() -> void:
	if _flow_arrows_layer == null or _board == null or _map_view == null or _director == null:
		return
	if not CombatDirector.is_planning_phase(_phase):
		return
	_draw_target = _flow_arrows_layer
	if _preview_arrows_enabled():
		if _preview_routes_enabled() and _should_draw_interaction_overlay():
			_draw_interaction_overlay(true)
		_draw_forced_movement_arrows()
	if _preview_committed_intents_enabled():
		_draw_ability_intents(true)
	_draw_target = null


func _draw_hover_tiles(canvas: CanvasItem) -> void:
	if canvas == null:
		return
	for cell: Vector2i in _hover_move_tiles:
		_draw_tile_tint(canvas, cell, _COLOR_MOVE, _COLOR_MOVE_FILL_ALPHA, false)
	for cell: Vector2i in _hover_action_range_tiles:
		_draw_tile_tint(canvas, cell, _COLOR_ACTION_RANGE, _COLOR_ACTION_RANGE_FILL_ALPHA, false)
	if not _blast_tiles_on_hover_layer:
		for cell: Vector2i in _hover_blast_tiles:
			_draw_tile_tint(canvas, cell, _COLOR_BLAST, _COLOR_BLAST_FILL_ALPHA, false)
	_ensure_hover_perimeter_cache()
	for entry: Variant in _cached_hover_perimeter_segments:
		if entry is Array and entry.size() >= 3:
			var segment: Array = entry as Array
			canvas.draw_line(segment[0] as Vector2, segment[1] as Vector2, segment[2] as Color, 1.0)


func _draw_tile_tint(
	canvas: CanvasItem,
	cell: Vector2i,
	tint: Color,
	fill_alpha: float,
	draw_border: bool = false,
) -> void:
	if canvas == null or _map_view == null:
		return
	var tile_px: float = float(TacticalConstants.TILE_PX)
	var rect := Rect2(
		_map_view.grid_to_local(cell) - Vector2(tile_px * 0.5, tile_px * 0.5),
		Vector2(tile_px, tile_px),
	).grow(-2.0)
	canvas.draw_rect(rect, Color(tint.r, tint.g, tint.b, fill_alpha), true)
	if draw_border:
		canvas.draw_rect(rect, Color(tint.r, tint.g, tint.b, _COLOR_TILE_BORDER_ALPHA), false, 1.0)


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


func _draw_hover_tile_on(canvas: CanvasItem) -> void:
	if canvas == null or _board == null or _map_view == null:
		return
	if not _preview_routes_enabled():
		return
	if not _board.is_in_bounds(_hover_coord):
		return
	if _planning_input != null and _director != null and _director.selected_unit_id >= 0:
		if _planning_input.selected_phase_action_exhausted(_director.selected_unit_id):
			return
		if CombatDirector.is_wait_ability_index(_director.selected_ability_index):
			return
	var in_field: bool = (
		_hover_move_tiles.has(_hover_coord)
		or _hover_action_range_tiles.has(_hover_coord)
		or _hover_blast_tiles.has(_hover_coord)
	)
	if not in_field:
		_draw_hover_follow_route_on(canvas)
		return
	var tile_px: float = float(TacticalConstants.TILE_PX)
	var center: Vector2 = _map_view.grid_to_local(_hover_coord)
	var rect := Rect2(center - Vector2(tile_px * 0.5, tile_px * 0.5), Vector2(tile_px, tile_px)).grow(-2.0)
	canvas.draw_rect(rect, Color(_COLOR_HOVER, 0.10), true)
	canvas.draw_rect(rect, Color(_COLOR_HOVER.r, _COLOR_HOVER.g, _COLOR_HOVER.b, 0.45), false, 1.0)
	if _blast_tiles_on_hover_layer:
		for cell: Vector2i in _hover_blast_tiles:
			_draw_tile_tint(canvas, cell, _COLOR_BLAST, _COLOR_BLAST_FILL_ALPHA, false)
	_draw_hover_follow_route_on(canvas)


func _draw_ability_intents(flowing: bool) -> void:
	if _director == null or _board == null:
		return
	var plan_to_use: Timeline = _director.get_player_plan()
	if plan_to_use != null:
		for action: TimelineAction in plan_to_use.entries:
			if not _should_draw_player_move_preview():
				break
			if action.type != GameEnums.ActionType.ABILITY:
				continue
			var draw_action: TimelineAction = action
			if action.awaiting_target:
				draw_action = AbilitySystem.planning_committed_prefix(action)
				if draw_action == null:
					continue
			if CombatPlanningPreview.premove_displacement_realized(_director, draw_action, _board):
				continue
			var base_board: BoardState = _director.base_board if _director.base_board != null else _board
			var actor := base_board.get_unit_by_id(draw_action.actor_id)
			if actor == null:
				continue
			var start_pos: Vector2i = CombatUiFormatters.plan_action_origin_cell(
				base_board, plan_to_use, draw_action, actor,
			)
			var dest_pos: Vector2i = draw_action.target_coord
			if not draw_action.module_target_coords.is_empty():
				dest_pos = draw_action.module_target_coords[draw_action.module_target_coords.size() - 1]
			if start_pos == dest_pos:
				continue
			var p_col: Color = _player_color_for_unit(actor)
			var draw_route: Array = _planning_input.display_committed_action_route_cells(
				draw_action.actor_id,
				draw_action,
				start_pos,
			)
			if draw_route.size() >= 2:
				var from_cell: Vector2i = draw_route[0] as Vector2i
				var to_cell: Vector2i = draw_route[draw_route.size() - 1] as Vector2i
				if (
					draw_action.ability != null
					and AbilitySystem.ability_has_effect(
						draw_action.ability, GameEnums.EffectType.TELEPORT_CASTER,
					)
				):
					if flowing:
						_draw_dashed_route([from_cell, to_cell], p_col)
				elif (
					draw_action.ability != null
					and AbilitySystem.ability_has_movement_effect(draw_action.ability)
				):
					if not flowing:
						_draw_route_line(draw_route, p_col, true, true)
				elif flowing:
					if action.target_unit_id >= 0:
						var tgt: UnitState = _board.get_unit_by_id(action.target_unit_id)
						if tgt != null:
							to_cell = tgt.position
					_draw_targeting_intent_arrow(from_cell, to_cell, p_col)
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
					if not flowing:
						continue
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
					if flowing:
						continue
					if action.target_coord != enemy_pos:
						var preview_for_push: CombatPlanningPreview = (
							_planning_input.route_preview_for_push_checks()
							if _planning_input != null
							else _committed_preview
						)
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
			or (
				_planning_input.live_sim_matches_hover()
				and (
					_planning_input.skill_interaction_active()
					or _planning_input.aiming
					or _planning_input.run_mode_selected()
					or _planning_input.is_live_preview_active()
				)
			)
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
		or _planning_input._voluntary_walk_planning_active()
		or _planning_input.run_mode_selected()
		or _planning_input.is_live_preview_active()
	):
		return _live_preview.preview_board != null
	return false


func _display_preview_board() -> BoardState:
	if _planning_input != null:
		var board: BoardState = _planning_input.preview_board_for_display()
		if board != null:
			return board
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
			_overlay_draw_target().draw_line(p1 + dir * d, p1 + dir * draw_end, color, _DASH_LINE_W)
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
	flow_speed: float = _TARGETING_INTENT_FLOW_SPEED,
	head_spacing: float = _TARGETING_INTENT_HEAD_SPACING,
) -> void:
	var delta: Vector2 = end_pt - start_pt
	var total_len: float = delta.length()
	if total_len < 0.001:
		return
	var dir: Vector2 = delta / total_len
	var draw_on: CanvasItem = _overlay_draw_target()
	var t: float = Time.get_ticks_msec() / 1000.0
	var path_offset: float = fmod(t * flow_speed, head_spacing)
	var arrow_pos: float = path_offset
	while arrow_pos < total_len - end_offset:
		if arrow_pos > start_offset:
			var tip: Vector2 = start_pt + dir * arrow_pos
			var wing1: Vector2 = tip - dir.rotated(deg_to_rad(wing_angle_deg)) * wing_len
			var wing2: Vector2 = tip - dir.rotated(deg_to_rad(-wing_angle_deg)) * wing_len
			draw_on.draw_line(tip, wing1, color, line_w)
			draw_on.draw_line(tip, wing2, color, line_w)
		arrow_pos += head_spacing


func _draw_dashed_shaft_on_line(
	start_pt: Vector2,
	end_pt: Vector2,
	color: Color,
	line_w: float,
	dash_len: float,
	gap_len: float,
) -> void:
	var delta: Vector2 = end_pt - start_pt
	var dist: float = delta.length()
	if dist < 0.001:
		return
	var travel_dir: Vector2 = delta / dist
	var d: float = 0.0
	while d < dist:
		var draw_end: float = minf(d + dash_len, dist)
		_overlay_draw_target().draw_line(start_pt + travel_dir * d, start_pt + travel_dir * draw_end, color, line_w)
		d += dash_len + gap_len


func _draw_filled_chevron_at(
	tip: Vector2,
	dir: Vector2,
	color: Color,
	chevron_len: float,
	half_w: float,
) -> void:
	var travel_dir: Vector2 = dir
	if travel_dir.length_squared() < 0.0001:
		travel_dir = Vector2.RIGHT
	else:
		travel_dir = travel_dir.normalized()
	var perp: Vector2 = Vector2(-travel_dir.y, travel_dir.x)
	var base: Vector2 = tip - travel_dir * chevron_len
	var wing_l: Vector2 = base + perp * half_w
	var wing_r: Vector2 = base - perp * half_w
	var head := PackedVector2Array([
		Vector2(round(tip.x), round(tip.y)),
		Vector2(round(wing_l.x), round(wing_l.y)),
		Vector2(round(wing_r.x), round(wing_r.y)),
	])
	_overlay_draw_target().draw_colored_polygon(head, color)


func _draw_flowing_filled_chevrons_on_line(
	start_pt: Vector2,
	end_pt: Vector2,
	color: Color,
	start_offset: float = 0.0,
	end_offset: float = 0.0,
	flow_speed: float = _FORCED_MOVE_INTENT_FLOW_SPEED,
	head_spacing: float = _FORCED_MOVE_INTENT_HEAD_SPACING,
) -> void:
	var delta: Vector2 = end_pt - start_pt
	var total_len: float = delta.length()
	if total_len < 0.001:
		return
	var dir: Vector2 = delta / total_len
	var t: float = Time.get_ticks_msec() / 1000.0
	var path_offset: float = fmod(t * flow_speed, head_spacing)
	var arrow_pos: float = path_offset
	while arrow_pos < total_len - end_offset:
		if arrow_pos > start_offset:
			var tip: Vector2 = start_pt + dir * arrow_pos
			_draw_filled_chevron_at(
				tip,
				dir,
				color,
				_PUSH_INTENT_CHEVRON_LEN,
				_PUSH_INTENT_CHEVRON_HALF_W,
			)
		arrow_pos += head_spacing


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
				var draw_on: CanvasItem = _overlay_draw_target()
				draw_on.draw_line(tip, wing1, color, line_w)
				draw_on.draw_line(tip, wing2, color, line_w)
		arrow_pos += wave_spacing


func _draw_danger_area(canvas: CanvasItem) -> void:
	if canvas == null or not _show_danger_area or _board == null or _director == null:
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
			_draw_tile_tint(canvas, c as Vector2i, _COLOR_DANGER, _COLOR_DANGER.a)


func _draw_preview_arrows() -> void:
	if _board == null or _director == null or _planning_input == null:
		return
	var prev: CombatPlanningPreview = _planning_input.committed_route_preview()
	for unit: UnitState in _board.units:
		if not unit.is_alive() or not _intent_visible(unit):
			continue
		if not unit.is_enemy():
			if not _should_draw_player_move_preview():
				continue
			var p_col: Color = _player_color_for_unit(unit)
			for move_timing: int in [
				GameEnums.MoveTiming.PRE_ACTION,
				GameEnums.MoveTiming.POST_ACTION,
			]:
				var visual_cell: Vector2i = CombatPlanningPreview.INVALID_VISUAL_CELL
				if _unit_layer != null:
					visual_cell = _unit_layer.actor_grid_cell(unit.id)
				var leg: Array = _planning_input.display_committed_move_route_leg(
					unit.id, move_timing, visual_cell,
				)
				if leg.size() < 2:
					continue
				if _skip_committed_move_leg_draw(unit.id, move_timing):
					continue
				_draw_route_line(leg, p_col, true, true)
		if prev.preview_board == null:
			continue
		var route: Array = _planning_input.display_frozen_route_cells(unit.id)
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
	if _board == null or not _should_draw_player_move_preview():
		return
	if not _should_draw_forced_movement_arrows():
		return
	if _planning_input == null:
		return
	var sources: Array[CombatPlanningPreview] = _planning_input.preview_push_draw_sources()
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
	var actor: UnitState = null
	if _board != null:
		actor = _board.get_unit_by_id(unit_id)
	if actor == null and _director.base_board != null:
		actor = _director.base_board.get_unit_by_id(unit_id)
	if actor == null or not _planning_input.active_movement_planning_step(actor):
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


func _should_draw_player_move_preview() -> bool:
	return (
		CombatDirector.is_planning_phase(_phase)
		and not _execution_preview_suppressed
	)


func _pending_move_route_leg(unit_id: int, prev: CombatPlanningPreview) -> Array:
	return CombatPlanningPreview.pending_move_route_leg(unit_id, prev, _director, _board)


## Live/drag move arrow — live corridor while choosing; frozen committed path otherwise.
func _interaction_move_route(unit_id: int, _prev: CombatPlanningPreview, _route: Array) -> Array:
	return _display_move_route_cells(unit_id)


func _resolve_overlay_attack_target_id() -> int:
	if _planning_input != null:
		return _planning_input.hover_attack_target_id()
	return _attack_target_id


## Hover cell for overlay draw helpers — intent SSOT from CombatPlanningInput.
func _intent_hover_cell() -> Vector2i:
	if _planning_input == null or _board == null:
		return Vector2i(-999, -999)
	var cell: Vector2i = _planning_input.get_hover_tile_for_ui()
	if _board.is_in_bounds(cell):
		return cell
	return Vector2i(-999, -999)


## Dotted targeting arrow from latest stand to aim cell. Tests and draw share this.
func targeting_intent_arrow_cells() -> Array[Vector2i]:
	if _planning_input != null:
		return _planning_input.targeting_intent_arrow_cells()
	return []


func _draw_interaction_overlay(flowing: bool) -> void:
	if _director == null or _director.selected_unit_id < 0 or _planning_input == null:
		return
	var preview_board: BoardState = _planning_input.preview_board_for_display()
	if preview_board == null:
		return
	var actor := preview_board.get_unit_by_id(_director.selected_unit_id)
	if actor == null:
		actor = _board.get_unit_by_id(_director.selected_unit_id)
	if actor == null:
		return
	var p_col: Color = _player_color_for_unit(actor)
	var sel_ability := _selected_ability_data(actor, _director.selected_ability_index)
	var caster_teleport_hover: bool = (
		sel_ability != null
		and AbilitySystem.ability_uses_caster_teleport(sel_ability, actor)
	)
	if not flowing:
		if caster_teleport_hover:
			var hop: Array[Vector2i] = _movement_hover_route_cells(actor.id)
			if hop.size() >= 2:
				_draw_dashed_route(hop, p_col)
			return
		if not caster_teleport_hover and _planning_input != null and _planning_input.dragging:
			var drag_route: Array = _display_move_route_cells(actor.id)
			if drag_route.size() >= 2:
				_draw_route_line(drag_route, p_col, true, true)
		elif (
			not caster_teleport_hover
			and _planning_input != null
			and not _planning_input.drag_preview_failed
		):
			var draw_route: Array = _display_move_route_cells(actor.id)
			if draw_route.size() >= 2:
				_draw_route_line(draw_route, p_col, true, true)
		return
	if (
		_planning_input != null
		and _planning_input.is_live_preview_active()
		and not _planning_input.drag_preview_failed
	):
		for other_id: int in _planning_input.display_units_with_route_preview():
			if other_id == actor.id:
				continue
			var other_route: Array[Vector2i] = _planning_input.display_frozen_route_cells(other_id)
			if other_route.size() < 2:
				continue
			var other_unit: UnitState = _board.get_unit_by_id(other_id) if _board != null else null
			var other_col: Color = (
				_player_color_for_unit(other_unit)
				if other_unit != null
				else p_col
			)
			_draw_dashed_route(other_route, Color(other_col.r, other_col.g, other_col.b, 0.85))
	var route_col := Color(p_col.r, p_col.g, p_col.b, 0.95)
	var arrow_cells: Array[Vector2i] = targeting_intent_arrow_cells()
	if arrow_cells.size() >= 2:
		_draw_targeting_intent_arrow(arrow_cells[0], arrow_cells[1], route_col)


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


func _draw_hover_follow_route_on(canvas: CanvasItem) -> void:
	if canvas == null or _map_view == null or _director == null or _planning_input == null:
		return
	if _planning_input.dragging:
		return
	if _resolve_overlay_attack_target_id() >= 0:
		return
	if _director.selected_unit_id < 0:
		return
	var unit: UnitState = _proj_unit(_director.selected_unit_id)
	if unit == null:
		return
	var cells: Array[Vector2i] = _display_move_route_cells(_director.selected_unit_id)
	if cells.size() < 2:
		return
	var p_col: Color = _player_color_for_unit(unit)
	var ability: AbilityData = _selected_ability_data(unit, _director.selected_ability_index)
	if AbilitySystem.ability_uses_direct_relocation(ability, unit):
		return
	_draw_route_line(cells, Color(p_col.r, p_col.g, p_col.b, 0.85), true, true, canvas)


func _draw_route_line(
	route: Array,
	color: Color,
	trim_start: bool,
	with_head: bool,
	canvas: CanvasItem = null,
) -> void:
	if route.size() < 2 or _map_view == null:
		return
	var draw_on: CanvasItem = canvas if canvas != null else self
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
	draw_on.draw_polyline(shaft, flat_col, _ROUTE_LINE_W, _ROUTE_AA)
	if with_head:
		_draw_route_arrowhead_on(draw_on, dest_center, end_dir, flat_col)


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
	_draw_route_arrowhead_on(self, tip, dir, fill)


func _draw_route_arrowhead_on(canvas: CanvasItem, tip: Vector2, dir: Vector2, fill: Color) -> void:
	if canvas == null:
		return
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
	canvas.draw_colored_polygon(head, fill)


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
	var draw_on: CanvasItem = _overlay_draw_target()
	draw_on.draw_line(tip, wing1, color, line_w)
	draw_on.draw_line(tip, wing2, color, line_w)


func _forced_movement_intent_color(_pushed_unit: UnitState = null) -> Color:
	return Color(_COLOR_TARGET.r, _COLOR_TARGET.g, _COLOR_TARGET.b, 0.95)


func _should_draw_forced_movement_arrows() -> bool:
	if _director == null:
		return true
	var plan: Timeline = _director.get_player_plan()
	var has_plan: bool = plan != null and not plan.entries.is_empty()
	if has_plan:
		return true
	if _planning_input != null and _planning_input.is_live_preview_active():
		return true
	return false


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
	flow_speed: float = _TARGETING_INTENT_FLOW_SPEED,
	head_spacing: float = _TARGETING_INTENT_HEAD_SPACING,
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
					0.0,
					0.0,
					flow_speed,
					head_spacing,
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
	if flowing_head:
		var t: float = Time.get_ticks_msec() / 1000.0
		d = fmod(t * _INTENT_DOT_FLOW_SPEED, _INTENT_DOT_SPACING)
	while d < dist:
		_overlay_draw_target().draw_circle(start_pt + travel_dir * d, _INTENT_DOT_RADIUS, color)
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
				0.0,
				0.0,
				flow_speed,
				head_spacing,
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


func _draw_displacement_intent_segment(
	from: Vector2i,
	to: Vector2i,
	color: Color,
	trim_start: bool,
	with_head: bool,
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
	if not with_head:
		_draw_dashed_shaft_on_line(
			start_pt,
			dest_center,
			color,
			_FORCED_MOVE_LINE_W,
			_PUSH_INTENT_DASH_LEN,
			_PUSH_INTENT_DASH_GAP,
		)
		return
	var shaft_end: Vector2 = dest_center
	var inset: float = _PUSH_INTENT_CHEVRON_LEN * _ROUTE_SHAFT_HEAD_OVERLAP
	shaft_end = dest_center - travel_dir * inset
	if start_pt.distance_to(shaft_end) >= 1.0:
		_draw_dashed_shaft_on_line(
			start_pt,
			shaft_end,
			color,
			_FORCED_MOVE_LINE_W,
			_PUSH_INTENT_DASH_LEN,
			_PUSH_INTENT_DASH_GAP,
		)
	_draw_flowing_filled_chevrons_on_line(
		start_pt,
		dest_center,
		color,
	)


func _draw_displacement_intent_arrow(from: Vector2i, to: Vector2i, color: Color) -> void:
	_draw_displacement_intent_segment(from, to, color, true, true)


func _draw_targeting_intent_arrow(from: Vector2i, to: Vector2i, color: Color) -> void:
	_draw_dotted_intent_segment(
		from,
		to,
		color,
		true,
		true,
		true,
		_TARGETING_INTENT_FLOW_SPEED,
		_TARGETING_INTENT_HEAD_SPACING,
	)


func _draw_push_arrow(from: Vector2i, to: Vector2i, pushed_unit: UnitState = null) -> void:
	_draw_displacement_intent_arrow(from, to, _forced_movement_intent_color(pushed_unit))


func _draw_ghosts() -> void:
	if _planning_input == null or _board == null or _director == null:
		return
	var preview_board: BoardState = _planning_input.preview_board_for_display()
	if preview_board == null:
		return
	var prev: CombatPlanningPreview = _planning_input.committed_route_preview()
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
				):
					var ghost_action: TimelineAction = action
					if action.awaiting_target:
						ghost_action = AbilitySystem.planning_committed_prefix(action)
						if ghost_action == null:
							continue
					var leg_origin: Vector2i = CombatUiFormatters.plan_action_origin_cell(
						base_board, plan_to_use, ghost_action, unit,
					)
					if ghost_action.target_coord == leg_origin:
						break
					var stand: Vector2i = unit.position
					var pv_unit: UnitState = preview_board.get_unit_by_id(unit.id)
					if pv_unit != null:
						stand = pv_unit.position
					if ghost_action.target_coord == stand:
						break
					var center: Vector2 = _map_view.grid_to_local(ghost_action.target_coord)
					var ghost_col: Color = _player_color_for_unit(unit)
					var leg_face: int = CombatPlanningPreview.facing_along_planned_action(
						base_board, plan_to_use, ghost_action, prev,
					)
					if leg_face < 0:
						leg_face = unit.facing
					draw_circle(center, _token_radius(), Color(ghost_col.r, ghost_col.g, ghost_col.b, 0.35))
					_draw_facing_wedge(center, leg_face, Color(ghost_col.r, ghost_col.g, ghost_col.b, 0.8))
					break
		if unit.is_enemy():
			var route: Array = _planning_input.display_frozen_route_cells(unit.id)
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
					var pv_enemy := preview_board.get_unit_by_id(unit.id)
					face = pv_enemy.facing if pv_enemy != null else unit.facing
				_draw_facing_wedge(ghost_center, face, Color(_COLOR_ENEMY_ARROW.r, _COLOR_ENEMY_ARROW.g, _COLOR_ENEMY_ARROW.b, alpha + 0.15))


func movement_ghost_paint_applies(unit: UnitState) -> bool:
	if _director == null or _board == null or _planning_input == null:
		return false
	if _director.selected_unit_id < 0 or not _board.is_in_bounds(_hover_coord):
		return false
	if unit == null or not unit.is_alive():
		return false
	if not _planning_input.awaiting_movement_endpoint_ghost_visible(unit):
		return false
	var ability: AbilityData = _selected_ability_data(unit, _director.selected_ability_index)
	if ability == null or AbilitySystem.planning_commit_flow(unit, ability) != GameEnums.PlanningCommitFlow.AWAITING_TARGET:
		return false
	if not _planning_input.awaiting_targeting_active():
		return false
	if (
		AbilitySystem.planning_awaiting_phase(ability)
		!= GameEnums.PlanningAwaitingPhase.MOVEMENT_ENDPOINT
	):
		return false
	var origin: Vector2i = _intent_stand_origin(unit)
	return AbilitySystem.planning_is_valid_awaiting_endpoint(
		origin, _hover_coord, ability, unit, _planning_board(),
	)


## Headless QA: route endpoint _draw_move_ghosts would use (display route, else staged drag).
func movement_ghost_route_endpoint(unit: UnitState) -> Vector2i:
	if not movement_ghost_paint_applies(unit):
		return Vector2i(-999999, -999999)
	var ability: AbilityData = _selected_ability_data(unit, _director.selected_ability_index)
	if ability != null and AbilitySystem.ability_has_movement_effect(ability):
		var route_cells: Array[Vector2i] = _display_move_route_cells(unit.id)
		if route_cells.size() >= 2:
			return route_cells[route_cells.size() - 1]
		if _planning_input != null:
			var drag_route: Array[Vector2i] = _planning_input.get_drag_route()
			if not drag_route.is_empty():
				return drag_route[drag_route.size() - 1] as Vector2i
	return _hover_coord


func _draw_move_ghosts() -> void:
	if _director == null or _board == null or _planning_input == null:
		return
	if _director.selected_unit_id < 0 or not _board.is_in_bounds(_hover_coord):
		return
	var unit := _proj_unit(_director.selected_unit_id)
	if unit == null or not unit.is_alive():
		return
	if not movement_ghost_paint_applies(unit):
		return
	var ability: AbilityData = _selected_ability_data(unit, _director.selected_ability_index)
	var center: Vector2 = _map_view.grid_to_local(_hover_coord)
	var p_col: Color = _player_color_for_unit(unit)
	draw_circle(center, _token_radius() + 1.0, Color(p_col.r, p_col.g, p_col.b, 0.45))
	var dash_face: int = _facing_toward(_intent_stand_origin(unit), _hover_coord)
	_draw_facing_wedge(center, dash_face, Color(p_col.r, p_col.g, p_col.b, 0.85))
	if ability != null and AbilitySystem.ability_has_effect(
		ability, GameEnums.EffectType.TELEPORT_CASTER,
	):
		_draw_dashed_route(
			[_intent_stand_origin(unit), _hover_coord],
			Color(p_col.r, p_col.g, p_col.b, 0.85),
		)
	elif ability != null and AbilitySystem.ability_has_movement_effect(ability):
		var route_cells: Array[Vector2i] = _display_move_route_cells(unit.id)
		_draw_route_line(route_cells, Color(p_col.r, p_col.g, p_col.b, 0.85), true, true)
	else:
		var arrow_cells: Array[Vector2i] = targeting_intent_arrow_cells()
		if arrow_cells.size() >= 2:
			_draw_targeting_intent_arrow(
				arrow_cells[0], arrow_cells[1], Color(p_col.r, p_col.g, p_col.b, 0.85),
			)


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


func _planning_board() -> BoardState:
	if _director != null and _director.projected_state != null:
		return _director.projected_state
	return _board


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
	var preview: CombatPlanningPreview = _planning_input.preview_state if _planning_input != null else null
	return CombatPlanningPreview.forecast_stand_at_phase_entry(_director, _board, unit.id, preview)


## Action-range anchor: phase-entry stand when bundle pending (EX-LOCKED-FIELD); settled stand when sealed.
func _intent_stand_origin(unit: UnitState) -> Vector2i:
	if unit == null:
		return Vector2i(-999999, -999999)
	if _planning_input != null and _is_selected_player_unit(unit):
		var settled: PlanningHoverPreview = _planning_input.get_settled_hover_preview()
		if (
			settled != null
			and settled.valid
			and settled.unit_id == unit.id
			and settled.stand_origin.x > -900000
		):
			return settled.stand_origin
		return _proj_origin(unit)
	return _proj_origin(unit)


func _selected_ability_data(unit: UnitState, ability_index: int) -> AbilityData:
	return CombatDirector.resolve_selected_ability(unit, ability_index)


func _dash_amount(ability: AbilityData) -> int:
	return AbilitySystem.effect_amount(ability, GameEnums.EffectType.DASH)


func _dash_threat_tiles(origin: Vector2i, steps: int) -> Array[Vector2i]:
	return AbilitySystem.dash_line_threat_tiles(_board, origin, steps)


func _movement_blocked_by_dash(unit: UnitState, selected_ability: int) -> bool:
	var ability: AbilityData = _selected_ability_data(unit, selected_ability)
	return ability != null and AbilitySystem.ability_blocks_basic_movement(ability)


func _unit_attack_range(unit: UnitState, selected_ability: int) -> int:
	if unit == null or _director == null:
		return 0
	if unit.id == _director.selected_unit_id and selected_ability >= 0:
		var ability: AbilityData = _selected_ability_data(unit, selected_ability)
		if ability != null:
			return AbilitySystem.active_range_tiles(unit, ability)
	if unit.is_enemy():
		if unit.definition != null and unit.definition.behavior != null:
			var att: AbilityData = unit.definition.behavior.attack
			if att != null:
				return AbilitySystem.active_range_tiles(unit, att)
		var best: int = 0
		for ability: AbilityData in unit.active_abilities:
			best = maxi(best, AbilitySystem.active_range_tiles(unit, ability))
		return best if best > 0 else 1
	var best: int = 0
	for ability: AbilityData in unit.active_abilities:
		best = maxi(best, AbilitySystem.active_range_tiles(unit, ability))
	return best


func _update_hover_action_icon() -> void:
	if _planning_input != null:
		_hover_action_icon = _planning_input.compute_hover_action_icon(_hover_coord)
		return
	_hover_action_icon = ""
