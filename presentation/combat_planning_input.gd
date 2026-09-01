class_name CombatPlanningInput
extends RefCounted

## H&I planning semantics ported from board_view ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ used by TacticalInputController.

const _PlanningRoutePolicy := preload("res://core/systems/planning_route_policy.gd")
const _HoverPreviewBundle := preload("res://presentation/planning_hover_preview.gd")

var auto_use_skill_after_move: bool = true

var auto_run: bool:
	get:
		return _director.auto_run if _director != null else false
	set(value):
		if _director != null:
			_director.auto_run = value

var _map_view: Node2D
var _director: CombatDirector
var _planning: TacticalPlanningOverlay
var _intent_state: CombatIntentState
var _sfx: SfxPlayer

var dragging: bool = false
var aiming: bool = false
var _drag_armed: bool = false
var _drag_press_local: Vector2 = Vector2.ZERO
var _drag_drop_finishing: bool = false
var _drag_survive_board_cancel: bool = false

const _DRAG_THRESHOLD_PX: float = 6.0
const _ABILITY_SCROLL_SETTLE_SEC: float = 0.075
const _HOVER_HEAVY_MIN_INTERVAL_SEC: float = 0.032
## PERF GUARD (owner-mandate): live F5 hover sim throttle interval — see
## `.cursor/rules/planning-hover-perf-mandatory.mdc`. Do not remove or zero
## without owner approval; QA uses immediate sync via qa_static_overlay.
const _HOVER_SIM_MIN_INTERVAL_SEC: float = 0.045
const _HOVER_SIM_STILL_PX: float = 3.0

var _drag_unit_id: int = -1
var _drag_route: Array[Vector2i] = []
var _drag_last_free: Vector2i = Vector2i(-1, -1)
var _drag_unit_was_selected: bool = false
var _drag_saved_preview: BoardState = null
var preview_state: CombatPlanningPreview = CombatPlanningPreview.new()

func _voluntary_walk_planning_active() -> bool:
	if _director == null or _director.selected_unit_id < 0:
		return false
	var actor: UnitState = _proj_unit(_director.selected_unit_id)
	return actor != null and active_movement_planning_step(actor)

func _skill_commit_path_active() -> bool:
	if _director == null:
		return true
	return _director.selected_ability_index >= 0

var drag_sim_actor_pos: Vector2i = Vector2i.ZERO
var drag_preview_failed: bool = false
var _last_planning_hover_cell: Vector2i = Vector2i(-9999, -9999)
var _hover_preview_cache_key: String = ""
var _hover_cursor_cache_key: String = ""
var _hover_cursor_cached_icon: String = ""
var _overlay_cursor_icon: String = ""
var _overlay_cursor_cell: Vector2i = Vector2i(-9999, -9999)
var _qa_pointer_override: bool = false
var _qa_pointer_screen_pos: Vector2 = Vector2.ZERO
var _qa_pointer_grid_override: bool = false
var _qa_pointer_grid_cell: Vector2i = Vector2i.ZERO
var _last_sim_hover_refresh_cell: Vector2i = Vector2i(-9999, -9999)
var _hover_sim_schedule_generation: int = 0
var _hover_sim_schedule_cell: Vector2i = Vector2i(-9999, -9999)
var _hover_sim_schedule_key: String = ""
var _hover_sim_schedule_pointer: Vector2 = Vector2.INF
var _ability_schedule_generation: int = 0
var _ability_schedule_key: String = ""
var _drag_preview_schedule_generation: int = 0
var _drag_preview_schedule_key: String = ""
var _planning_refresh_generation: int = 0
var _planning_refresh_scheduled: bool = false
var _planning_refresh_schedule_key: String = ""
var _drag_move_commit_instant: bool = false
var _drag_preview_cache_key: int = 0
var _drag_preview_cache: Dictionary = {}
var _drag_last_cursor_cell: Vector2i = Vector2i(-999999, -999999)
var _drag_last_sprite_cell: Vector2i = Vector2i(-999999, -999999)
## Last painted intent (move-preview truth) ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ commit ratifies these slots, does not rebuild.
var _intent_snapshot_slots: Dictionary = {}
var _intent_snapshot_key: String = ""
var _intent_snapshot_valid: bool = false
var _intent_snapshot_unit_id: int = -1
var _intent_snapshot_hover_cell: Vector2i = Vector2i(-999999, -999999)
var _settled_hover_preview: _HoverPreviewBundle = null
var _intent_snapshot_plan_revision: int = -1
## Settled hover used projected-delta move-only preview when overlay range already correct at stand.
const _HOVER_PREVIEW_LRU_MAX: int = 24
var _hover_preview_lru: Dictionary = {}
var _hover_preview_lru_order: Array[String] = []


func setup(
	map_view: TacticalMapView,
	director: CombatDirector,
	planning: TacticalPlanningOverlay,
	intent_state: CombatIntentState,
	sfx: SfxPlayer,
) -> void:
	_map_view = map_view
	_director = director
	if director != null:
		director.planning_live_preview = preview_state
	_planning = planning
	_intent_state = intent_state
	_sfx = sfx
	if not _planning.live_preview_changed.is_connected(_on_planning_live_preview_changed):
		_planning.live_preview_changed.connect(_on_planning_live_preview_changed)
	_bind_event_bus()


func teardown() -> void:
	_refresh_planning_hover_at_current_cell(false)
	_disconnect_event_bus()
	if _planning != null and _planning.live_preview_changed.is_connected(_on_planning_live_preview_changed):
		_planning.live_preview_changed.disconnect(_on_planning_live_preview_changed)
	_map_view = null
	_director = null
	_planning = null
	_intent_state = null
	_sfx = null


## Test and integration hook: refresh the canonical preview immediately.
func refresh_planning_now() -> void:
	_planning_refresh_generation += 1
	_planning_refresh_scheduled = false
	_refresh_planning_hover_at_current_cell(false)


func _disconnect_event_bus() -> void:
	if EventBus.selection_changed.is_connected(_on_selection_changed):
		EventBus.selection_changed.disconnect(_on_selection_changed)
	if EventBus.ability_selected.is_connected(_on_ability_selected):
		EventBus.ability_selected.disconnect(_on_ability_selected)
	if EventBus.preview_updated.is_connected(_on_preview_updated):
		EventBus.preview_updated.disconnect(_on_preview_updated)
	if EventBus.board_changed.is_connected(_on_board_changed):
		EventBus.board_changed.disconnect(_on_board_changed)
	if EventBus.timeline_changed.is_connected(_on_timeline_changed):
		EventBus.timeline_changed.disconnect(_on_timeline_changed)


func _bind_event_bus() -> void:
	_disconnect_event_bus()
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.ability_selected.connect(_on_ability_selected)
	EventBus.preview_updated.connect(_on_preview_updated)
	EventBus.board_changed.connect(_on_board_changed)
	EventBus.timeline_changed.connect(_on_timeline_changed)


func _on_timeline_changed(_plan: Timeline, _statuses: PackedStringArray) -> void:
	_clear_intent_snapshot()
	_invalidate_planning_hover_cache()
	_drag_route.clear()
	_drag_last_free = Vector2i(-1, -1)
	preview_state.clear_interaction()
	if _planning != null:
		_planning.restore_committed_display()
	if _drag_unit_id >= 0 and selected_phase_action_exhausted(_drag_unit_id):
		_cancel_drag_if_exhausted()


func cancel_drag() -> void:
	_cancel_drag_armed()
	if not dragging:
		return
	var snap_back: bool = _drag_had_movement()
	dragging = false
	_drag_unit_id = -1
	_end_drag_interaction(true, snap_back)
	_clear_hover_preview()


func cancel_aim() -> void:
	if not aiming:
		return
	aiming = false
	if _planning != null:
		_planning.set_aim_mode(false)
		_planning._recompute_hover_ranges_from_inputs()
	_sync_intent_skill_mode()
	_restore_hover_preview()
	refresh_mouse_cursor(_intent_state.hover_coord if _intent_state != null else Vector2i(-999, -999))


func _intent_snapshot_matches_interaction(unit_id: int, cell: Vector2i) -> bool:
	if not _intent_snapshot_valid or _intent_snapshot_unit_id != unit_id:
		return false
	if _intent_snapshot_hover_cell != cell:
		return false
	return not _is_invalid_dict(_intent_snapshot_slots)


func _waypoints_for_snapshot_key_from_slots(slots: Dictionary) -> Array[Vector2i]:
	for col: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(col, []):
			if raw is TimelineAction:
				var act: TimelineAction = raw as TimelineAction
				if not act.waypoints.is_empty():
					return act.waypoints.duplicate()
	return []


func on_left_press(local: Vector2) -> void:
	var cell: Vector2i = _pointer_grid_cell()
	var board: BoardState = _director.board
	if board == null or not board.is_in_bounds(cell):
		cancel_aim()
		return
	var selected_id: int = _director.selected_unit_id
	if selected_id >= 0 and awaiting_targeting_active():
		var awaiting_actor: UnitState = _proj_unit(selected_id)
		var awaiting_ability: AbilityData = _selected_ability_data(awaiting_actor)
		if (
			awaiting_actor != null
			and awaiting_ability != null
			and _is_awaiting_movement_endpoint(awaiting_actor, awaiting_ability)
		):
			if _movement_skill_commits_tile_endpoint(awaiting_actor, awaiting_ability, cell):
				if not _commit_at_interaction_cell(selected_id, cell, local):
					_play_sfx("invalid")
				return
	var unit := _unit_at_input_cell(cell)
	if unit != null and not unit.is_enemy() and unit.is_alive():
		if NetworkManager != null and NetworkManager.is_multiplayer:
			if unit.controlling_player_id != NetworkManager.local_player_id:
				return
		if aiming and unit.id == _director.selected_unit_id:
			if not _commit_at_interaction_cell(_director.selected_unit_id, cell, local):
				_play_sfx("invalid")
			cancel_aim()
			return
		if aiming:
			cancel_aim()
		var was_selected: bool = unit.id == _director.selected_unit_id
		_arm_drag(unit, local, was_selected)
		return
	if aiming:
		var actor := _proj_unit(_director.selected_unit_id)
		if selected_phase_action_exhausted(_director.selected_unit_id):
			cancel_aim()
			return
		if actor != null and _commit_at_interaction_cell(_director.selected_unit_id, cell, local):
			cancel_aim()
			return
		_play_sfx("invalid")
		cancel_aim()
		return
	var sel_actor := _proj_unit(_director.selected_unit_id)
	if unit != null and unit.is_enemy():
		if sel_actor != null and not sel_actor.is_enemy():
			if _click_inspects_committed_target(sel_actor.id, unit):
				_director.select_unit(unit.id)
			elif not _commit_at_interaction_cell(_director.selected_unit_id, cell, local, unit.id):
				_director.select_unit(unit.id)
		else:
			_director.select_unit(unit.id)
	else:
		if sel_actor != null and not sel_actor.is_enemy():
			_commit_at_interaction_cell(_director.selected_unit_id, cell, local)


func on_left_release(local: Vector2) -> void:
	if _drag_armed and not dragging:
		if not _try_click_through_drag_armed(local):
			_process_unit_drop(local, false)
		_cancel_drag_armed()
		return
	if not dragging:
		return
	var had_movement: bool = _drag_had_movement()
	_drag_drop_finishing = true
	_refresh_drag_preview_now()
	dragging = false
	var board: BoardState = _director.board
	var cell: Vector2i = _pointer_grid_cell()
	var actor := board.get_unit_by_id(_drag_unit_id) if board != null else null
	if actor == null or board == null or not board.is_in_bounds(cell):
		_drag_unit_id = -1
		_end_drag_interaction(true, had_movement)
		_drag_drop_finishing = false
		return
	var committed: bool = _process_unit_drop(local, had_movement)
	var snap_back: bool = had_movement and not committed
	_drag_unit_id = -1
	_end_drag_interaction(false, snap_back)
	_drag_drop_finishing = false


func _try_click_through_drag_armed(local: Vector2) -> bool:
	if _director == null or _director.board == null:
		return false
	var cell: Vector2i = _pointer_grid_cell()
	var clicked_id: int = _drag_unit_id
	if clicked_id < 0:
		return false
	var clicked_unit: UnitState = _director.board.get_unit_by_id(clicked_id)
	if clicked_unit == null:
		return false
	var caster_id: int = _director.selected_unit_id
	if caster_id >= 0 and clicked_id != caster_id and _skill_commit_path_active():
		if _director.selected_ability_index >= 0:
			var caster: UnitState = _proj_unit(caster_id)
			if caster != null and not caster.is_enemy():
				var ability: AbilityData = _selected_ability_data(caster)
				if ability != null and AbilitySystem.target_passes_mode(caster, ability, clicked_unit):
					if _commit_at_interaction_cell(caster_id, cell, local, clicked_id):
						return true
				elif _can_target_unit_with_selected_ability(caster, clicked_unit):
					if _commit_at_interaction_cell(caster_id, cell, local, clicked_id):
						return true
	if clicked_id != caster_id:
		_director.select_unit(clicked_id)
	return false


func _process_unit_drop(local: Vector2, had_movement: bool) -> bool:
	## Drag drop == hover click: ratify the already-settled hover bundle.
	_drag_move_commit_instant = had_movement
	var released_unit_id: int = _drag_unit_id
	var clicked_unit: UnitState = _unit_at_input_cell(_pointer_grid_cell())
	if (
		clicked_unit != null
		and clicked_unit.id == released_unit_id
		and not _drag_unit_was_selected
	):
		_director.select_unit(released_unit_id)
		_drag_move_commit_instant = false
		return false
	if selected_phase_action_exhausted(released_unit_id):
		_play_sfx("invalid")
		_drag_move_commit_instant = false
		return false
	var committed: bool = false
	var board: BoardState = _director.board
	var actor := board.get_unit_by_id(released_unit_id) if board != null else null
	var cell: Vector2i = _pointer_grid_cell()
	if actor == null or board == null or not board.is_in_bounds(cell):
		_drag_move_commit_instant = false
		return false
	var dropped_on := _unit_at_input_cell(cell)
	if dropped_on != null and dropped_on.id != actor.id:
		if _is_selectable_player_unit(dropped_on):
			if _director.selected_ability_index < 0:
				_director.select_unit(dropped_on.id)
				_drag_move_commit_instant = false
				return false
			committed = _commit_at_interaction_cell(released_unit_id, cell, local, dropped_on.id)
			_drag_move_commit_instant = false
			return committed
		if selected_phase_action_exhausted(released_unit_id):
			_play_sfx("invalid")
			_drag_move_commit_instant = false
			return false
		committed = _commit_at_interaction_cell(released_unit_id, cell, local, dropped_on.id)
		_drag_move_commit_instant = false
		return committed
	if cell == _proj_origin(actor):
		if _drag_unit_was_selected:
			committed = _commit_at_interaction_cell(released_unit_id, cell, local)
		_drag_move_commit_instant = false
		return committed
	if dropped_on == null:
		committed = _commit_at_interaction_cell(released_unit_id, cell, local)
	_drag_move_commit_instant = false
	return committed

func on_right_click() -> void:
	if aiming:
		cancel_aim()
		_play_sfx("cancel")
		return
	if awaiting_targeting_active():
		if _director != null and _director.unit_has_undoable_action(_director.selected_unit_id):
			_director.rpc_remove_last_for_unit(_director.selected_unit_id)
			_clear_hover_drag_route()
			_invalidate_planning_hover_cache()
			if _director.find_awaiting_action(_director.selected_unit_id) != null:
				clear_awaiting_targeting()
			else:
				_restore_hover_preview()
				_request_planning_selection_refresh()
		else:
			clear_awaiting_targeting()
		_play_sfx("cancel")
		return
	if _is_planning() and _director.selected_unit_id >= 0:
		if _director.unit_has_wait_planned(_director.selected_unit_id):
			_director.rpc_plan_wait(_director.selected_unit_id)
			_play_sfx("cancel")
		elif _director.unit_has_undoable_action(_director.selected_unit_id):
			_director.rpc_remove_last_for_unit(_director.selected_unit_id)
			_play_sfx("cancel")
		else:
			_director.select_unit(-1)
			_play_sfx("cancel")


func update_drag(local: Vector2) -> void:
	if selected_phase_action_exhausted(_drag_unit_id):
		_cancel_drag_if_exhausted()
		return
	var board: BoardState = _director.board
	var cell: Vector2i = _pointer_grid_cell()
	if _intent_state != null:
		_intent_state.set_hover_coord(cell)
	if board == null or not board.is_in_bounds(cell):
		if cell != _drag_last_sprite_cell:
			_update_drag_sprite(local, cell, {})
			_drag_last_sprite_cell = cell
		else:
			_update_drag_sprite_position(local, cell)
		if cell != _drag_last_cursor_cell:
			_drag_last_cursor_cell = cell
			refresh_mouse_cursor(cell)
		return
	var occ := board.get_unit_at(cell)
	var drag_unit := board.get_unit_by_id(_drag_unit_id)
	
	var cell_changed: bool = cell != _drag_last_cursor_cell
	if dragging and _drag_unit_id >= 0:
		var clamp_actor: UnitState = _proj_unit(_drag_unit_id)
		if clamp_actor != null and _voluntary_walk_orbit_phase_open(clamp_actor):
			_clamp_voluntary_walk_drag_for_forbidden_hover(_drag_unit_id)
	if _movement_route_paint_allowed() and cell_changed:
		_extend_drag_route(cell)
		_clamp_voluntary_walk_drag_for_forbidden_hover(_drag_unit_id)
	if drag_unit != null and (occ == null or occ.id == _drag_unit_id):
		if cell == drag_unit.position or (_planning != null and _planning.is_hover_move_tile(cell)):
			_drag_last_free = cell
	elif (
		drag_unit != null
		and not drag_unit.is_enemy()
		and occ != null
		and occ.is_enemy()
		and MovementSystem.has_trample(drag_unit)
		and (
			_basic_walk_pathfinding_active(drag_unit)
			or _is_awaiting_movement_endpoint(
				drag_unit, _selected_ability_data(drag_unit),
			)
		)
		and _planning != null
		and _planning.is_hover_move_tile(occ.position)
	):
		_drag_last_free = occ.position
	if cell_changed:
		_schedule_or_refresh_drag_preview()
		var drag_actor: UnitState = _proj_unit(_drag_unit_id)
		if (
			drag_actor != null
			and _voluntary_walk_orbit_phase_open(drag_actor)
			and _director.board.is_in_bounds(cell)
		):
			_refresh_voluntary_walk_hover_preview(drag_actor, cell)
		_update_drag_sprite(local, cell, _drag_preview_cache)
		_drag_last_sprite_cell = cell
	else:
		_update_drag_sprite_position(local, cell)
	if cell != _drag_last_cursor_cell:
		_drag_last_cursor_cell = cell
		refresh_mouse_cursor(cell)


func _schedule_or_refresh_drag_preview() -> void:
	if _map_view == null or not _map_view.is_inside_tree():
		_refresh_drag_preview_now()
		return
	var schedule_key: String = _planning_interaction_revision_key()
	_drag_preview_schedule_generation += 1
	var generation: int = _drag_preview_schedule_generation
	_drag_preview_schedule_key = schedule_key
	_map_view.get_tree().create_timer(_HOVER_HEAVY_MIN_INTERVAL_SEC).timeout.connect(
		func() -> void:
			if (
				generation == _drag_preview_schedule_generation
				and schedule_key == _planning_interaction_revision_key()
				and dragging
			):
				_refresh_drag_preview_now(),
		CONNECT_ONE_SHOT,
	)


func _planning_interaction_revision_key() -> String:
	var revision: int = _director.plan_revision if _director != null else -1
	var selected_unit: int = _director.selected_unit_id if _director != null else -1
	var selected_ability: int = _director.selected_ability_index if _director != null else -1
	var hover_cell: Vector2i = (
		_intent_state.hover_coord
		if _intent_state != null
		else Vector2i(-999999, -999999)
	)
	return "%d|%d|%d|%s|%d|%s" % [
		revision,
		selected_unit,
		selected_ability,
		str(hover_cell),
		_drag_unit_id,
		str(_drag_route),
	]


func _refresh_drag_preview_now() -> void:
	if not dragging or _drag_unit_id < 0 or _director == null or _director.board == null:
		return
	var movement_drag_actor: UnitState = _proj_unit(_drag_unit_id)
	if movement_drag_actor != null and active_movement_planning_step(movement_drag_actor):
		_apply_voluntary_walk_drag_preview(_drag_unit_id, false)
		return
	var cell: Vector2i = _pointer_grid_cell()
	if not _director.board.is_in_bounds(cell):
		return
	var occ: UnitState = _director.board.get_unit_at(cell)
	var drag_unit: UnitState = _director.board.get_unit_by_id(_drag_unit_id)
	var drag_target_id: int = _drag_preview_target_id(drag_unit, occ)
	var waypoints: Array[Vector2i] = (
		_route_waypoints_for_commit() if _drag_route_commits_active() else _route_waypoints()
	)
	var preview_waypoints: Array[Vector2i] = (
		waypoints if _movement_route_paint_allowed() else []
	)
	var route_painted: bool = _movement_route_paint_allowed() and _drag_route.size() >= 2
	var cache_key: int = _drag_preview_cache_key_for(cell, drag_target_id, preview_waypoints)
	if cache_key == _drag_preview_cache_key:
		return
	_drag_preview_cache_key = cache_key
	_drag_preview_cache = _preview_at_interaction_cell(
		_drag_unit_id,
		cell,
		_drag_last_free,
		drag_target_id,
		preview_waypoints,
		_snapshot_drag_legal_move_tiles(),
	)
	_apply_live_preview(_drag_preview_cache)
	if _drag_unit_id >= 0:
		var post_drag_actor: UnitState = _proj_unit(_drag_unit_id)
		if post_drag_actor != null and _voluntary_walk_drag_trim_active(post_drag_actor):
			var live_path: Array = _authoritative_route_for_unit(_drag_unit_id)
			if live_path.size() >= 2:
				var trimmed_live: Array = _trim_route_for_prior_forbidden(
					live_path, _drag_unit_id, _active_hover_cell(),
				)
				if trimmed_live != live_path:
					var leg_origin: Vector2i = trimmed_live[0] as Vector2i
					_apply_trimmed_drag_route(trimmed_live, leg_origin)
					_apply_voluntary_walk_drag_preview(_drag_unit_id, false)
			var post_trim_actor: UnitState = _proj_unit(_drag_unit_id)
			if post_trim_actor != null:
				var leg_origin: Vector2i = _phase_entry_stand(post_trim_actor)
				var hover_cell: Vector2i = _active_hover_cell()
				var forbidden: Dictionary = CombatPlanningPreview.prior_leg_forbidden_cells(
					_director, _drag_unit_id, leg_origin,
				)
				if (
					forbidden.has(hover_cell)
					and hover_cell != leg_origin
					and not _can_move_to(post_trim_actor, hover_cell)
				):
					_drag_route = [leg_origin]
					_drag_last_free = leg_origin
					_apply_voluntary_walk_drag_preview(_drag_unit_id, false)
	if route_painted and _drag_unit_id >= 0 and not preview_waypoints.is_empty():
		var snap_actor: UnitState = _proj_unit(_drag_unit_id)
		if snap_actor != null and _voluntary_walk_orbit_phase_open(snap_actor):
			var drop_params: Dictionary = _commit_interaction_params(cell, -1)
			var snap_res: Dictionary = _preview_from_commit_slots_at_cell(
				_drag_unit_id,
				drop_params.cell as Vector2i,
				preview_waypoints,
				_snapshot_drag_legal_move_tiles(),
				drop_params.preferred as Vector2i,
				int(drop_params.get("face_dir", -1)),
			)
			if not _is_invalid_dict(snap_res):
				_apply_settled_preview_result(snap_res)
	if route_painted:
		_apply_voluntary_walk_drag_preview(_drag_unit_id, false)
	var drag_actor: UnitState = _proj_unit(_drag_unit_id)
	var drag_ability: AbilityData = (
		_selected_ability_data(drag_actor) if drag_actor != null else null
	)
	if route_painted:
		_sync_drag_route_stand()
	elif (
		drag_ability != null
		and drag_actor != null
		and _is_awaiting_movement_endpoint(drag_actor, drag_ability)
	):
		_sync_drag_route_stand()
	elif (
		_drag_unit_id >= 0
		and _voluntary_walk_orbit_phase_open(_proj_unit(_drag_unit_id))
	):
		if _drag_route.size() >= 2:
			_sync_drag_route_stand()
		else:
			_apply_voluntary_walk_drag_preview(_drag_unit_id, false)
	_refresh_action_range_overlay_when_gate_off()


func get_drag_unit_id() -> int:
	return _drag_unit_id


func refresh_live_preview() -> void:
	if not dragging or _drag_unit_id < 0:
		return
	var movement_actor: UnitState = _proj_unit(_drag_unit_id)
	if movement_actor != null and active_movement_planning_step(movement_actor):
		_apply_voluntary_walk_drag_preview(_drag_unit_id, false)
		return
	var board: BoardState = _director.board
	var cell: Vector2i = _pointer_grid_cell()
	if not board.is_in_bounds(cell):
		return
	var occ := board.get_unit_at(cell)
	var drag_unit := board.get_unit_by_id(_drag_unit_id)
	var drag_target_id: int = _drag_preview_target_id(drag_unit, occ)
	var preview: Dictionary = _preview_at_interaction_cell(
		_drag_unit_id,
		_pointer_grid_cell(),
		_drag_last_free,
		drag_target_id,
		_route_waypoints(),
		_snapshot_drag_legal_move_tiles(),
	)
	_apply_live_preview(preview)


func _apply_settled_preview_result(res: Dictionary) -> void:
	if _director == null:
		return
	preview_state.apply_result(res, _director)
	if _planning == null:
		return
	_planning.apply_preview_state(
		preview_state, _director.selected_unit_id, _hover_attack_target_id(),
	)
	_planning._recompute_hover_ranges_from_inputs()


func get_settled_hover_preview() -> _HoverPreviewBundle:
	return _settled_hover_preview


func _current_hover_receipt() -> PlanningHoverPreview:
	if _settled_hover_preview != null and _settled_hover_preview.valid:
		return _settled_hover_preview
	return null


func _authoritative_preview_paths() -> Dictionary:
	var receipt: PlanningHoverPreview = _current_hover_receipt()
	if receipt != null:
		return receipt.preview_paths.duplicate(true)
	return {}


func _authoritative_route_for_unit(unit_id: int) -> Array:
	if preview_state.is_painted_leg_sealed(unit_id):
		var painted: Variant = preview_state.preview_paths.get(unit_id, null)
		if painted is Array and (painted as Array).size() >= 2:
			return (painted as Array).duplicate()
		return []
	var receipt: PlanningHoverPreview = _current_hover_receipt()
	if receipt != null and receipt.unit_id == unit_id:
		var route: Variant = receipt.preview_paths.get(unit_id, [])
		if route is Array and (route as Array).size() >= 2:
			return (route as Array).duplicate()
	return []


func _hover_settle_fresh_at(unit_id: int, cell: Vector2i, attack_target_id: int = -999999) -> bool:
	if _director == null or unit_id < 0 or not _intent_snapshot_valid:
		return false
	var resolved_target: int = (
		_hover_attack_target_id() if attack_target_id <= -900000 else attack_target_id
	)
	var cache_key: String = _hover_interaction_cache_key(unit_id, cell, resolved_target)
	if cache_key.is_empty() or _intent_snapshot_key != cache_key:
		return false
	if _settled_hover_preview == null or not _settled_hover_preview.valid:
		return false
	return (
		_settled_hover_preview.unit_id == unit_id
		and _settled_hover_preview.hover_cell == cell
	)


func settled_hover_revision_key() -> String:
	if not _intent_snapshot_valid:
		return ""
	return _intent_snapshot_key



func _active_hover_cell() -> Vector2i:
	if _intent_state != null:
		return _intent_state.hover_coord
	return _pointer_grid_cell()


func _trim_route_for_prior_forbidden(
	route: Array,
	unit_id: int,
	hover_cell: Vector2i,
) -> Array:
	if route.size() < 2 or _director == null or unit_id < 0:
		return route
	var leg_origin: Vector2i = route[0] as Vector2i
	var forbidden: Dictionary = CombatPlanningPreview.prior_leg_forbidden_cells(
		_director, unit_id, leg_origin,
	)
	if forbidden.is_empty():
		return route
	var actor: UnitState = _proj_unit(unit_id)
	var trimmed: Array = route.duplicate()
	while trimmed.size() > 1:
		var step: Vector2i = trimmed[trimmed.size() - 1] as Vector2i
		if forbidden.has(step) and step != leg_origin:
			if actor != null and _can_move_to(actor, step):
				break
			trimmed.pop_back()
			continue
		break
	if trimmed.size() < 2:
		return []
	return trimmed


func _apply_trimmed_drag_route(trimmed: Array, leg_origin: Vector2i) -> void:
	if not dragging or _drag_unit_id < 0:
		return
	if trimmed.size() < 2:
		if leg_origin.x > -900000:
			_drag_route = [leg_origin]
			_drag_last_free = leg_origin
		return
	if trimmed != _drag_route:
		_drag_route = trimmed.duplicate()
		_drag_last_free = _drag_route.back() as Vector2i


func _clamp_voluntary_walk_drag_for_forbidden_hover(unit_id: int) -> void:
	if not dragging or _director == null or unit_id < 0:
		return
	var actor: UnitState = _proj_unit(unit_id)
	if actor == null or not _voluntary_walk_drag_trim_active(actor):
		return
	var leg_origin: Vector2i = _phase_entry_stand(actor)
	if leg_origin.x <= -900000:
		return
	var hover_cell: Vector2i = _active_hover_cell()
	var forbidden: Dictionary = CombatPlanningPreview.prior_leg_forbidden_cells(
		_director, unit_id, leg_origin,
	)
	if forbidden.is_empty():
		return
	if (
		forbidden.has(hover_cell)
		and hover_cell != leg_origin
		and not _can_move_to(actor, hover_cell)
	):
		_drag_route = [leg_origin]
		_drag_last_free = leg_origin
		_clear_stale_painted_preview_route(unit_id)
		return
	if _drag_route.size() >= 2:
		_trim_drag_route_forbidden()
		if _drag_route.size() < 2:
			_drag_route = [leg_origin]
			_drag_last_free = leg_origin
		if _drag_route.size() >= 2:
			_apply_voluntary_walk_drag_preview(unit_id, false)
		else:
			_clear_stale_painted_preview_route(unit_id)
	var live_path: Array = _authoritative_route_for_unit(unit_id)
	if live_path.size() >= 2:
		var trimmed_preview: Array = _trim_route_for_prior_forbidden(
			live_path, unit_id, hover_cell,
		)
		if trimmed_preview != live_path:
			_apply_trimmed_drag_route(trimmed_preview, leg_origin)
		_apply_voluntary_walk_drag_preview(unit_id, false)


func _apply_live_preview(preview: Dictionary) -> void:
	if preview.is_empty():
		return
	if _is_invalid_dict(preview):
		drag_preview_failed = true
		_hover_preview_cache_key = ""
		_clear_hover_preview()
		return
	_apply_settled_preview_result(preview)
	drag_preview_failed = false
	var actor_id: int = _drag_unit_id if dragging else _director.selected_unit_id
	for event: Variant in preview.get("events", []):
		if event is SimEvent:
			var sim: SimEvent = event as SimEvent
			if (
				sim.type == GameEnums.SimEventType.ACTION_FAILED
				and int(sim.data.get("actor", -1)) == actor_id
			):
				drag_preview_failed = true
				break
	var temp_board: BoardState = preview.get("temp_board")
	var pv_actor: UnitState = temp_board.get_unit_by_id(actor_id) if temp_board != null else null
	if pv_actor != null:
		drag_sim_actor_pos = pv_actor.position
		if pv_actor.movement.points_left < 0:
			drag_preview_failed = true
	elif dragging:
		drag_sim_actor_pos = _drag_last_free
	if preview.has("temp_board") and _planning != null:
		_planning.apply_preview_state(preview_state, _director.selected_unit_id, _hover_attack_target_id())
		## Preview board moved stand ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ refresh locked/next range fields (MOVE_PREVIEW_RULES two-range).
		_planning._recompute_hover_ranges_from_inputs()
	_refresh_action_range_overlay_when_gate_off()
	_sync_intent_live_board()


func _refresh_action_range_overlay_when_gate_off() -> void:
	if _planning == null or _director == null or not _is_planning():
		return
	if _director.selected_unit_id < 0:
		return
	if action_range_visible_for_hover():
		return
	_planning._invalidate_hover_cache()
	_planning._recompute_hover_ranges_from_inputs()


func _on_planning_live_preview_changed() -> void:
	_refresh_action_range_overlay_when_gate_off()


func _sync_intent_live_board() -> void:
	if _intent_state == null:
		return
	var live: bool = dragging or aiming or _skill_interaction_active()
	if live and preview_state.preview_board != null:
		_intent_state.set_live_preview_board(preview_state.preview_board)
	else:
		_intent_state.clear_live_preview_board()


func try_activate_drag(local: Vector2) -> void:
	if not _drag_armed or dragging or _director == null or _director.board == null:
		return
	if selected_phase_action_exhausted(_drag_unit_id):
		_cancel_drag_armed()
		_play_sfx("invalid")
		return
	if local.distance_to(_drag_press_local) < _DRAG_THRESHOLD_PX:
		return
	var unit: UnitState = _director.board.get_unit_by_id(_drag_unit_id)
	if unit == null or not unit.is_alive():
		_cancel_drag_armed()
		return
	_drag_armed = false
	_begin_drag(unit, local, _drag_unit_was_selected)
	update_drag(local)


func is_drag_armed() -> bool:
	return _drag_armed


func _arm_drag(unit: UnitState, local: Vector2, was_already_selected: bool) -> void:
	if selected_phase_action_exhausted(unit.id):
		if not was_already_selected:
			_director.select_unit(unit.id)
			return
		_play_sfx("invalid")
		return
	_cancel_drag_armed()
	_drag_armed = true
	_drag_press_local = local
	_drag_unit_id = unit.id
	_drag_unit_was_selected = was_already_selected
	_drag_route = [_planning_drag_origin(unit.id)]
	_drag_last_free = _drag_route[0]


func _cancel_drag_armed() -> void:
	_drag_armed = false
	_drag_press_local = Vector2.ZERO
	if dragging:
		return
	_drag_unit_id = -1
	_drag_route.clear()


func _cancel_drag_if_exhausted() -> void:
	if not dragging and not _drag_armed:
		return
	var had_movement: bool = _drag_had_movement() if dragging else false
	_drag_armed = false
	dragging = false
	_drag_unit_id = -1
	_end_drag_interaction(true, had_movement)
	_play_sfx("invalid")


func _begin_drag(unit: UnitState, local: Vector2, was_already_selected: bool) -> void:
	if selected_phase_action_exhausted(unit.id):
		_play_sfx("invalid")
		return
	if _director != null and _director.selected_unit_id != unit.id:
		_drag_survive_board_cancel = true
		_director.select_unit(unit.id)
		var selected_ability: AbilityData = _selected_ability_data(unit)
		var skill_move_leg: bool = _is_awaiting_movement_endpoint(unit, selected_ability)
		var keep_skill_drag: bool = (
			skill_move_leg
			or (
				was_already_selected
				and _director.selected_ability_index >= 0
				and (
					auto_use_skill_after_move
					or (
						_director.auto_run
						and not AbilitySystem.is_run_ability(selected_ability)
					)
				)
			)
		)
	_invalidate_planning_hover_cache()
	_clear_drag_preview_cache()
	_stash_committed_preview()
	_clear_hover_preview()
	_sync_intent_skill_mode()
	dragging = true
	_drag_unit_id = unit.id
	_clear_frozen_painted_leg(unit.id)
	_drag_unit_was_selected = was_already_selected
	_clear_planning_cursor_for_drag()
	_drag_route = [_planning_drag_origin(unit.id)]
	_drag_last_free = _drag_route[0]
	_apply_voluntary_walk_drag_preview(unit.id, false)
	preview_state.action_splits[unit.id] = 0
	if _planning != null:
		_planning.apply_preview_state(preview_state, unit.id, -1)
	_planning._recompute_hover_ranges_from_inputs()
	_planning.begin_drag_sprite(unit.id)


func _end_drag_interaction(restore_committed: bool, snap_back: bool = false) -> void:
	dragging = false
	var sealed_unit_id: int = -1
	if _drag_unit_id >= 0 and not snap_back:
		var drag_actor: UnitState = _proj_unit(_drag_unit_id)
		if drag_actor != null and _painted_drag_route_matches_leg(drag_actor):
			_apply_voluntary_walk_drag_preview(_drag_unit_id, true)
			_seal_painted_preview_landing_if_needed(drag_actor)
			if preview_state.is_painted_leg_sealed(_drag_unit_id):
				sealed_unit_id = _drag_unit_id
				_sync_preview_board_to_sealed_landing(sealed_unit_id)
	_invalidate_planning_hover_cache()
	_clear_drag_preview_cache()
	if _drag_unit_id >= 0:
		if _drag_unit_id != sealed_unit_id:
			_clear_frozen_painted_leg(_drag_unit_id)
		if _director.selected_unit_id != sealed_unit_id:
			_clear_frozen_painted_leg(_director.selected_unit_id)
	_drag_route.clear()
	drag_preview_failed = false
	preview_state.clear_interaction()
	if _planning != null:
		_planning.clear_drag_route()
		_planning.end_drag_sprite(snap_back)
		_planning.mark_danger_dirty()
		_planning._invalidate_hover_cache()
		_planning._recompute_hover_ranges_from_inputs()
	if restore_committed:
		_restore_committed_preview()
	else:
		_drag_saved_preview = null
		if _planning != null:
			_planning.restore_committed_display()
			if sealed_unit_id >= 0:
				_planning.apply_preview_state(
					preview_state, sealed_unit_id, _hover_attack_target_id(),
				)
	_sync_intent_live_board()
	_sync_intent_skill_mode()
	if _intent_state != null:
		_intent_state.recompute()
	_request_planning_selection_refresh()


func _on_board_changed(board: BoardState) -> void:
	if _director == null or board != _director.board:
		return
	var fresh_session: bool = (
		_director.plan_pre_move.size() == 0
		and _director.plan_action.size() == 0
		and _director.plan_post_move.size() == 0
	)
	if fresh_session and not aiming and not dragging and not _drag_armed:
		invalidate_hover_preview_cache()
		preview_state.clear_interaction()
	var interacting: bool = aiming or dragging or _drag_armed
	if not interacting:
		_drag_route.clear()
		if _planning != null:
			_planning.clear_drag_route()
		preview_state.clear_interaction()
		# Stale stash after drag ended must not restore over a committed plan.
		if _drag_saved_preview != null:
			_drag_saved_preview = null
		# Snap undo/move refresh emits preview_updated in the same flush ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ skip duplicate danger pass.
		if _planning != null:
			_planning.mark_danger_dirty()
		_sync_after_plan_refresh()
		return
	if _drag_survive_board_cancel:
		_drag_survive_board_cancel = false
		_invalidate_planning_hover_cache()
		if _planning != null:
			_planning._recompute_hover_ranges_from_inputs()
		_sync_after_plan_refresh()
		return
	var preserve_drag_session: bool = (
		_drag_armed
		or (dragging and _voluntary_walk_planning_active() and not _drag_drop_finishing)
	)
	if preserve_drag_session:
		_invalidate_planning_hover_cache()
		if _planning != null:
			_planning._recompute_hover_ranges_from_inputs()
		_sync_after_plan_refresh()
		return
	if aiming:
		cancel_aim()
	aiming = false
	dragging = false
	_drag_armed = false
	_drag_unit_id = -1
	_drag_route.clear()
	drag_preview_failed = false
	drag_sim_actor_pos = Vector2i.ZERO
	if _drag_saved_preview != null:
		_restore_committed_preview()
	else:
		preview_state.clear_interaction()
		if _planning != null:
			_planning.restore_committed_display()
	if _planning != null:
		_planning.clear_drag_route()
		_planning.end_drag_sprite()
		_planning.mark_danger_dirty()
		_planning._invalidate_hover_cache()
	_sync_after_plan_refresh()


func _stash_committed_preview() -> void:
	if _planning != null:
		_planning.stash_committed_preview()
		_drag_saved_preview = _planning.get_preview_board()
	if _drag_saved_preview == null and _director != null and _director.board != null:
		_drag_saved_preview = _director.board.clone()


func _restore_committed_preview() -> void:
	_drag_saved_preview = null
	preview_state.clear_all()
	if _planning != null:
		_planning.restore_stashed_committed()
	_sync_intent_live_board()


func _on_selection_changed(unit_id: int) -> void:
	if _director == null:
		return
	if unit_id < 0:
		clear_awaiting_targeting()
		_invalidate_planning_hover_cache()
		_restore_hover_preview()
		_sync_intent_skill_mode()
		if _planning != null:
			_planning._recompute_hover_ranges_from_inputs()
		return
	if not dragging and not _drag_armed:
		_restore_hover_preview()
		_drag_route.clear()
		_drag_unit_id = unit_id
	_play_sfx("select")
	_finish_selection_changed()


func _request_planning_selection_refresh() -> void:
	_schedule_planning_refresh(true)


func _schedule_planning_refresh(refresh_cursor: bool) -> void:
	if _planning_refresh_scheduled:
		if _planning_refresh_schedule_key == _planning_interaction_revision_key():
			return
		_planning_refresh_generation += 1
		_planning_refresh_scheduled = false
	var schedule_key: String = _planning_interaction_revision_key()
	_planning_refresh_scheduled = true
	_planning_refresh_generation += 1
	var generation: int = _planning_refresh_generation
	_planning_refresh_schedule_key = schedule_key
	if _map_view == null or not _map_view.is_inside_tree():
		_run_scheduled_planning_refresh(generation, schedule_key, refresh_cursor)
		return
	_map_view.get_tree().process_frame.connect(
		func() -> void:
			_run_scheduled_planning_refresh(generation, schedule_key, refresh_cursor),
		CONNECT_ONE_SHOT,
	)


func _run_scheduled_planning_refresh(
	generation: int,
	schedule_key: String,
	refresh_cursor: bool,
) -> void:
	if (
		generation != _planning_refresh_generation
	):
		return
	if schedule_key != _planning_interaction_revision_key():
		_planning_refresh_scheduled = false
		return
	_planning_refresh_scheduled = false
	if _is_planning() and not dragging:
		_refresh_planning_hover_at_current_cell(refresh_cursor)


func _refresh_planning_hover_at_current_cell(refresh_cursor: bool) -> void:
	if _director == null or _planning == null or not _is_planning():
		return
	var cell: Vector2i = _intent_state.hover_coord if _intent_state != null else Vector2i(-999, -999)
	if _director.selected_unit_id >= 0:
		_refresh_selected_interaction_preview()
	elif _director.board != null and _director.board.is_in_bounds(cell):
		_update_hover_attack_preview()
	_planning._recompute_hover_ranges_from_inputs()
	_sync_intent_skill_mode()
	if refresh_cursor and _intent_state != null:
		refresh_mouse_cursor(cell)

func _finish_selection_changed() -> void:
	if _drag_saved_preview == null and _planning != null:
		_planning.stash_committed_preview()
	_request_planning_selection_refresh()


func _on_ability_selected(index: int) -> void:
	if _director == null:
		return
	if index >= 0:
		pass
	else:
		clear_awaiting_targeting()
	_invalidate_planning_hover_cache(false)
	_clear_intent_snapshot()
	_sync_intent_skill_mode()
	if dragging:
		clear_awaiting_targeting()
		_request_planning_selection_refresh()
		refresh_live_preview()
		return
	_last_sim_hover_refresh_cell = Vector2i(-9999, -9999)
	_clear_hover_preview()
	if _planning != null:
		_planning.queue_redraw()
	_schedule_ability_settled_refresh()


func _resync_hover_after_ability_change() -> void:
	if (
		not _is_planning()
		or dragging
		or _drag_armed
		or _intent_state == null
		or _director.board == null
	):
		return
	var hover: Vector2i = _intent_state.hover_coord
	if not _director.board.is_in_bounds(hover):
		return
	_last_planning_hover_cell = Vector2i(-9999, -9999)
	_last_sim_hover_refresh_cell = Vector2i(-9999, -9999)
	_refresh_planning_hover_at_current_cell(false)


func _schedule_ability_settled_refresh() -> void:
	_ability_schedule_generation += 1
	var generation: int = _ability_schedule_generation
	var schedule_key: String = _planning_interaction_revision_key()
	_ability_schedule_key = schedule_key
	if _map_view == null or not _map_view.is_inside_tree():
		_run_ability_settled_refresh()
		return
	var tree: SceneTree = _map_view.get_tree()
	tree.create_timer(_ABILITY_SCROLL_SETTLE_SEC).timeout.connect(
		func() -> void:
			if (
				generation == _ability_schedule_generation
				and schedule_key == _planning_interaction_revision_key()
				and _is_planning()
				and not dragging
			):
				_run_ability_settled_refresh(),
		CONNECT_ONE_SHOT,
	)


func _run_ability_settled_refresh() -> void:
	if _director == null:
		return
	var actor := _director.board.get_unit_by_id(_director.selected_unit_id) if _director.board != null and _director.selected_unit_id >= 0 else null
	var cur_ability := _selected_ability_data(actor) if actor != null else null
	var awaiting := _director.find_awaiting_action(_director.selected_unit_id) if _director.selected_unit_id >= 0 else null
	if awaiting != null and cur_ability != null and awaiting.ability != null and awaiting.ability.id == cur_ability.id:
		_resync_hover_after_ability_change()
		if _intent_state != null:
			refresh_mouse_cursor(_intent_state.hover_coord)
		return
	if (
		actor != null
		and awaiting != null
		and cur_ability == null
		and _voluntary_walk_planning_active()
		and _voluntary_walk_orbit_phase_open(actor)
	):
		_resync_hover_after_ability_change()
		if _intent_state != null:
			refresh_mouse_cursor(_intent_state.hover_coord)
		return
	var had_awaiting: bool = awaiting_targeting_active()
	clear_awaiting_targeting()
	if had_awaiting:
		return
	_resync_hover_after_ability_change()
	if _intent_state != null:
		refresh_mouse_cursor(_intent_state.hover_coord)


func _on_preview_updated(_result: SimResult) -> void:
	_drag_saved_preview = null
	if dragging:
		return
	_schedule_planning_refresh(false)


func _sync_after_plan_refresh() -> void:
	_sync_intent_live_board()
	_sync_intent_skill_mode()
	if _intent_state != null:
		_intent_state.recompute()
	refresh_mouse_cursor(
		_intent_state.hover_coord if _intent_state != null else Vector2i(-999, -999),
	)


func _refresh_hover_if_planning() -> void:
	if dragging or not _is_planning() or _intent_state == null or _director == null:
		return
	var cell: Vector2i = _intent_state.hover_coord
	if _director.board == null or not _director.board.is_in_bounds(cell):
		return
	if _director.selected_unit_id >= 0:
		_refresh_selected_interaction_preview()
	else:
		_update_hover_attack_preview()


func _sync_intent_skill_mode() -> void:
	if _intent_state != null:
		_intent_state.set_skill_interaction_active(_skill_interaction_active() or aiming)


func _invalidate_planning_hover_cache(reset_hover_cell: bool = true) -> void:
	if reset_hover_cell:
		_last_planning_hover_cell = Vector2i(-9999, -9999)
	_hover_preview_cache_key = ""
	_hover_cursor_cache_key = ""
	_hover_cursor_cached_icon = ""
	_overlay_cursor_icon = ""
	_overlay_cursor_cell = Vector2i(-9999, -9999)
	_clear_hover_preview_lru()


func _clear_hover_preview_lru() -> void:
	_hover_preview_lru.clear()
	_hover_preview_lru_order.clear()


func _duplicate_preview_result(res: Dictionary) -> Dictionary:
	var copy: Dictionary = res.duplicate()
	if res.has("temp_board") and res["temp_board"] is BoardState:
		copy["temp_board"] = (res["temp_board"] as BoardState).clone()
	if res.has("events"):
		copy["events"] = (res["events"] as Array).duplicate()
	if res.has("intents"):
		copy["intents"] = (res["intents"] as Array).duplicate()
	return copy


func _store_hover_preview_lru(cache_key: String, res: Dictionary) -> void:
	if cache_key.is_empty() or res.is_empty():
		return
	_hover_preview_lru[cache_key] = _duplicate_preview_result(res)
	_hover_preview_lru_order.erase(cache_key)
	_hover_preview_lru_order.append(cache_key)
	while _hover_preview_lru_order.size() > _HOVER_PREVIEW_LRU_MAX:
		var stale_key: String = _hover_preview_lru_order[0]
		_hover_preview_lru_order.remove_at(0)
		_hover_preview_lru.erase(stale_key)


func _take_hover_preview_lru(cache_key: String) -> Dictionary:
	if cache_key.is_empty() or not _hover_preview_lru.has(cache_key):
		return {}
	return _duplicate_preview_result(_hover_preview_lru[cache_key] as Dictionary)


## Public alias for input controller / UI when ability changes outside EventBus order.
func invalidate_hover_preview_cache() -> void:
	_invalidate_planning_hover_cache()



## Input-buffer only: mutates _drag_route; preview write is _refresh_voluntary_walk_hover_preview (R6).
func _stage_voluntary_walk_drag_input(
	p_unit: UnitState,
	cell: Vector2i,
	ability: AbilityData,
	planning_cell_changed: bool,
	awaiting_move_leg: bool,
) -> void:
	if p_unit == null or _director == null:
		return
	var hover_phase_kind: int = _director.planning_timeline_phase_kind(p_unit.id)
	var move_already_planned: bool = false
	if hover_phase_kind == CombatDirector.PlanningTimelinePhaseKind.PREMOVE_MOVEMENT:
		move_already_planned = _director.unit_has_move_planned_at_timing(
			p_unit.id, GameEnums.MoveTiming.PRE_ACTION,
		)
	elif hover_phase_kind == CombatDirector.PlanningTimelinePhaseKind.POSTMOVE_MOVEMENT:
		move_already_planned = _director.unit_has_move_planned_at_timing(
			p_unit.id, GameEnums.MoveTiming.POST_ACTION,
		)
	var open_premove_hover_paint: bool = (
		not dragging
		and (not awaiting_move_leg or _voluntary_walk_corridor_paint_active(p_unit))
		and _movement_route_paint_allowed()
		and not move_already_planned
	)
	var should_paint_hover_route: bool = (
		dragging
		or _voluntary_walk_corridor_paint_active()
		or open_premove_hover_paint
	)
	var allow_hover_paint: bool = (
		should_paint_hover_route
		and not _awaiting_target_pick_blocks_premove()
		and not _is_armed_tile_skill_aim_cell(p_unit, cell, ability)
		and (
			dragging
			or (
				(
					not awaiting_move_leg
					or _voluntary_walk_corridor_paint_active(p_unit)
				)
				and _movement_route_paint_allowed()
				and not move_already_planned
			)
		)
	)
	if allow_hover_paint and painted_move_route_locked(p_unit, cell):
		allow_hover_paint = false
	var orbit_phase_corridor: bool = _voluntary_walk_orbit_phase_open(p_unit)
	var should_extend_route: bool = planning_cell_changed
	if (
		not should_extend_route
		and allow_hover_paint
		and _drag_route_commits_active()
		and _drag_unit_id == p_unit.id
		and _voluntary_walk_can_paint_cell(p_unit, cell)
	):
		should_extend_route = not _drag_route.is_empty() and cell != _drag_route.back()
	if allow_hover_paint and (not orbit_phase_corridor or _voluntary_walk_corridor_paint_active(p_unit)):
		var target_enemy_id: int = _attack_target_id_at_cell(p_unit, cell)
		if target_enemy_id >= 0:
			var enemy_unit: UnitState = (
				_director.board.get_unit_by_id(target_enemy_id) if _director.board != null else null
			)
			if enemy_unit != null and not _enemy_hover_respects_painted_route(
				p_unit, enemy_unit, ability, _route_waypoints(),
			):
				should_extend_route = false
		if should_extend_route:
			var paint_origin: Vector2i = _phase_entry_stand(p_unit)
			if paint_origin.x > -900000:
				var paint_forbidden: Dictionary = CombatPlanningPreview.prior_leg_forbidden_cells(
					_director, p_unit.id, paint_origin,
				)
				if paint_forbidden.has(cell) and cell != paint_origin and not _voluntary_walk_can_paint_cell(p_unit, cell):
					should_extend_route = false
		if should_extend_route:
			if _drag_route.is_empty() or _drag_unit_id != p_unit.id:
				_drag_unit_id = p_unit.id
				_drag_route = [_phase_entry_stand(p_unit)]
				_drag_last_free = _drag_route[0]
			_extend_drag_route(cell)
	elif (
		_drag_route.size() >= 2
		and _drag_unit_id == p_unit.id
		and not painted_move_route_locked(p_unit)
		and not _voluntary_walk_corridor_paint_active()
	):
		_clear_hover_drag_route()

func on_hover_moved(cell: Vector2i) -> void:
	if _director == null or _director.board == null:
		return
	if not dragging:
		_sync_intent_skill_mode()
		if _intent_state != null:
			_intent_state.set_hover_coord(cell)
		if _planning != null:
			_planning.set_hover_coord(cell, true)
	if not _is_planning():
		return
	var previous_hover: Vector2i = _last_planning_hover_cell
	var planning_cell_changed: bool = cell != previous_hover
	if planning_cell_changed:
		_last_planning_hover_cell = cell
		## Drop leftover live path/ghost as soon as the cursor leaves the last
		## simulated tile. Hover follow-route already moved; the parent overlay
		## otherwise keeps the old 30 fps frame until the next settle.
		if (
			not dragging
			and _planning != null
			and _last_sim_hover_refresh_cell == previous_hover
		):
			_planning.queue_redraw()
	if (
		not dragging
		and _director.board.is_in_bounds(cell)
		and _director.selected_unit_id >= 0
	):
		var p_unit := _proj_unit(_director.selected_unit_id)
		if p_unit != null:
			_discard_stale_drag_route_for_leg(p_unit)
			var ability := _selected_ability_data(p_unit)
			_discard_enemy_hover_painted_buffers_if_needed(p_unit, cell, ability)
			if active_movement_planning_step(p_unit):
				var leg_origin: Vector2i = _phase_entry_stand(p_unit)
				if (
					_drag_route_commits_active()
					and _drag_unit_id == p_unit.id
					and not _drag_route.is_empty()
					and leg_origin.x > -900000
					and (_drag_route[0] as Vector2i) != leg_origin
				):
					_clear_hover_drag_route()
				if (
					_director.planning_timeline_phase_kind(p_unit.id)
					== CombatDirector.PlanningTimelinePhaseKind.PREMOVE_MOVEMENT
					and not dragging
					and not _selection_corridor_route_staging_active(p_unit)
				):
					_seal_painted_preview_landing_if_needed(p_unit)
			_sealed_leg_hover_restore_if_blocked(p_unit, cell)
			var awaiting_move_leg: bool = (
				ability != null and _is_awaiting_movement_endpoint(p_unit, ability)
			)
			if (
				awaiting_move_leg
				and not dragging
				and planning_cell_changed
				and not _selection_corridor_route_staging_active(p_unit)
			):
				_seal_painted_preview_landing_if_needed(p_unit)
			_stage_voluntary_walk_drag_input(p_unit, cell, ability, planning_cell_changed, awaiting_move_leg)
	## PERF GUARD: live F5 must NOT sync-settle every cell here — route/drag updates
	## above are cheap; full settle runs via _schedule_hover_sim_refresh (throttle)
	## or _flush_hover_heavy_sync on commit. See planning-hover-perf-mandatory.mdc.
	if not _director.board.is_in_bounds(cell):
		if _director.selected_unit_id >= 0:
			var oob_unit: UnitState = _proj_unit(_director.selected_unit_id)
			if oob_unit != null and active_movement_planning_step(oob_unit):
				_clear_stale_painted_preview_route(oob_unit.id)
		_flush_hover_heavy_sync()
		return
	if _should_restore_stand_hover_preview(cell):
		_restore_hover_preview()
		return
	if _should_run_hover_sim_sync(cell) or _map_view == null or not _map_view.is_inside_tree():
		_run_hover_sim_refresh()
		_run_hover_overlay_refresh()
		if not dragging:
			refresh_mouse_cursor(cell)
	else:
		_schedule_hover_sim_refresh()
		_run_hover_overlay_refresh()
		if not dragging:
			refresh_mouse_cursor(cell)
	if (
		dragging
		and _drag_route.size() >= 2
		and cell == (_drag_route[_drag_route.size() - 1] as Vector2i)
	):
		_refresh_drag_preview_now()


func _movement_preview_resync_after_sim_allowed(p_unit: UnitState) -> bool:
	if _voluntary_walk_orbit_phase_open(p_unit) or active_movement_planning_step(p_unit):
		return true
	if _director == null or p_unit == null:
		return false
	if _director.selected_ability_index < 0:
		return true
	var ability: AbilityData = _selected_ability_data(p_unit)
	if ability == null:
		return false
	return _is_awaiting_movement_endpoint(p_unit, ability)


func _occupy_push_hover_tracks_immediately() -> bool:
	## Occupy-push hover is a cheap clone (no Simulator). Do not wait for the
	## pointer-still throttle used to skip expensive dash/attack replay.
	if _planning != null and _planning.qa_static_overlay:
		return false
	if _director == null or _director.selected_unit_id < 0:
		return false
	var unit: UnitState = _proj_unit(_director.selected_unit_id)
	if unit == null:
		return false
	return AbilitySystem.motion_requires_occupied_target(unit, _selected_ability_data(unit))


## PERF GUARD (owner-mandate): live F5 returns false → throttle via
## _schedule_hover_sim_refresh. QA (qa_static_overlay) always sync. Occupy-push
## sync on live. Do NOT return true for live basic move — that removes throttle.
func _should_run_hover_sim_sync(cell: Vector2i) -> bool:
	if dragging or _director == null or not _is_planning():
		return false
	if not _director.board.is_in_bounds(cell):
		return false
	if _planning != null and _planning.qa_static_overlay:
		return true
	if _occupy_push_hover_tracks_immediately():
		return true
	return false


func _schedule_hover_sim_refresh() -> void:
	if (
		dragging
		or _director == null
		or not _is_planning()
		or _intent_state == null
		or _director.board == null
	):
		return
	var cell: Vector2i = _intent_state.hover_coord
	if not _director.board.is_in_bounds(cell):
		return
	var unit_id: int = _director.selected_unit_id
	if unit_id < 0:
		return
	var schedule_key: String = _hover_interaction_cache_key(unit_id, cell, _hover_attack_target_id())
	if schedule_key.is_empty() or (
		_hover_preview_fresh_at(cell)
		and _intent_snapshot_key == schedule_key
	):
		return
	_hover_sim_schedule_generation += 1
	var generation: int = _hover_sim_schedule_generation
	_hover_sim_schedule_cell = cell
	_hover_sim_schedule_key = schedule_key
	_hover_sim_schedule_pointer = _mouse_local_for_facing()
	var wait_sec: float = _hover_sim_min_interval_sec()
	if wait_sec <= 0.0 or _map_view == null or not _map_view.is_inside_tree():
		_run_hover_sim_refresh()
		_run_hover_overlay_refresh()
		return
	_map_view.get_tree().create_timer(wait_sec).timeout.connect(
		func() -> void:
			if generation != _hover_sim_schedule_generation:
				return
			if _intent_state == null or _intent_state.hover_coord != _hover_sim_schedule_cell:
				return
			if _hover_interaction_cache_key(
				_director.selected_unit_id,
				_hover_sim_schedule_cell,
				_hover_attack_target_id(),
			) != _hover_sim_schedule_key:
				return
			if not _hover_sim_pointer_is_still():
				_schedule_hover_sim_refresh()
				return
			if _hover_settle_fresh_at(_director.selected_unit_id, _hover_sim_schedule_cell):
				_run_hover_overlay_refresh()
				return
			_run_hover_sim_refresh()
			_run_hover_overlay_refresh()
			if _director.selected_ability_index >= 0:
				_sync_movement_preview_after_hover_sim(_hover_sim_schedule_cell),
		CONNECT_ONE_SHOT,
	)


func _hover_sim_min_interval_sec() -> float:
	if _planning != null:
		var settings: GameSettings = _planning.game_settings()
		if settings != null:
			return settings.hover_sim_interval_sec()
	return _HOVER_SIM_MIN_INTERVAL_SEC


func _hover_sim_pointer_is_still() -> bool:
	if _planning != null and _planning.qa_static_overlay:
		return true
	if _hover_sim_schedule_pointer.x >= 1.0e12:
		return true
	return _mouse_local_for_facing().distance_to(_hover_sim_schedule_pointer) <= _hover_sim_still_px()


func _hover_sim_still_px() -> float:
	if _planning != null:
		var settings: GameSettings = _planning.game_settings()
		if settings != null:
			return maxf(0.0, settings.hover_settle_still_px)
	return _HOVER_SIM_STILL_PX


func _flush_hover_heavy_sync() -> void:
	## PERF GUARD: commit/drag-end must flush pending throttle and run one sync
	## settle before ratify — always call _run_hover_sim_refresh here.
	_hover_sim_schedule_generation += 1
	_drag_preview_schedule_generation += 1
	if dragging:
		_refresh_drag_preview_now()
	var flush_cell: Vector2i = (
		_intent_state.hover_coord if _intent_state != null else Vector2i(-999, -999)
	)
	_run_hover_sim_refresh()
	if _director != null and _director.selected_ability_index >= 0:
		_sync_movement_preview_after_hover_sim(flush_cell)
	_run_hover_overlay_refresh()
	_refresh_action_range_overlay_when_gate_off()
	if dragging and _drag_unit_id >= 0:
		var hover_flush_actor: UnitState = _proj_unit(_drag_unit_id)
		if hover_flush_actor != null and _voluntary_walk_orbit_phase_open(hover_flush_actor):
			_clamp_voluntary_walk_drag_for_forbidden_hover(_drag_unit_id)


## Harness/test alias: same synchronous hover settle path as production flush.
func _flush_hover_preview_refresh() -> void:
	_flush_hover_heavy_sync()


func _run_hover_overlay_refresh() -> void:
	if _director == null or _director.board == null or not _is_planning():
		return
	var cell: Vector2i = _intent_state.hover_coord if _intent_state != null else Vector2i(-999, -999)
	if not _director.board.is_in_bounds(cell):
		if _director.selected_unit_id >= 0 and action_range_visible_for_hover():
			if _planning != null:
				_planning._recompute_hover_ranges_from_inputs()
		elif _director.selected_unit_id < 0:
			_sync_intent_live_board()
			if _planning != null:
				_planning._invalidate_hover_cache()
				_planning._recompute_hover_ranges_from_inputs()
		if _planning != null:
			_planning.queue_redraw()
		return
func _run_hover_sim_refresh() -> void:
	if _director == null or _director.board == null or not _is_planning() or dragging:
		return
	var cell: Vector2i = _intent_state.hover_coord if _intent_state != null else Vector2i(-999, -999)
	if not _director.board.is_in_bounds(cell):
		if _director.selected_unit_id >= 0:
			_clear_live_preview_preserve_intent()
		else:
			_sync_intent_live_board()
		_last_sim_hover_refresh_cell = cell
		return
	var sim_cell_changed: bool = cell != _last_sim_hover_refresh_cell
	if _director.selected_unit_id >= 0:
		if _hover_settle_fresh_at(_director.selected_unit_id, cell):
			_last_sim_hover_refresh_cell = cell
			if not dragging:
				refresh_mouse_cursor(cell)
			return
		if _should_refresh_hover_preview(cell, sim_cell_changed):
			_refresh_selected_interaction_preview()
	elif sim_cell_changed:
		_update_hover_attack_preview()
	_last_sim_hover_refresh_cell = cell
	if not dragging:
		refresh_mouse_cursor(cell)

func get_hover_tile_for_ui() -> Vector2i:
	if dragging:
		return _drag_last_free
	if _intent_state != null:
		return _intent_state.hover_coord
	return Vector2i(-999, -999)


func build_debug_context() -> Dictionary:
	var context: Dictionary = {
		"dragging": dragging,
		"drag_unit_id": _drag_unit_id,
		"drag_preview_failed": drag_preview_failed,
		"voluntary_walk_planning_active": _voluntary_walk_planning_active(),
		"auto_use_skill_after_move": auto_use_skill_after_move,
		"awaiting_targeting": awaiting_targeting_active(),
		"live_preview_active": is_live_preview_active(),
	}
	var drag_cells: Array[Array] = []
	for cell: Vector2i in _drag_route:
		drag_cells.append(DebugReportRuntime._coord(cell))
	context["drag_route"] = drag_cells
	var hover: Vector2i = get_hover_tile_for_ui()
	context["hover_tile"] = DebugReportRuntime._coord(hover)
	if _director == null:
		return context
	var unit_id: int = _director.selected_unit_id
	context["selected_unit_id"] = unit_id
	context["selected_ability_index"] = _director.selected_ability_index
	if unit_id >= 0:
		var move_timing: int = _director.get_planning_move_timing(unit_id)
		context["planning_move_timing"] = move_timing
		context["planning_move_timing_name"] = DebugReportRuntime._move_timing_name(move_timing)
		context["action_column_spent"] = _director.unit_action_column_spent_for_movement(unit_id)
		context["phase_action_exhausted"] = selected_phase_action_exhausted(unit_id)
		var actor: UnitState = _proj_unit(unit_id)
		if actor != null:
			context["latest_stand"] = DebugReportRuntime._coord(
				CombatPlanningPreview.planning_latest_stand_cell(_director, _proj(), unit_id),
			)
			context["projected_position"] = DebugReportRuntime._coord(actor.position)
		if _settled_hover_preview != null:
			context["hover_commit_slots"] = DebugReportRuntime.serialize_commit_slots(
				_settled_hover_preview.duplicate_slots(),
			)
	if preview_state != null and not preview_state.preview_paths.is_empty():
		var path_summary: Dictionary = {}
		for path_unit_id: int in preview_state.preview_paths.keys():
			var path_cells: Array = preview_state.preview_paths[path_unit_id] as Array
			var serialized_path: Array[Array] = []
			for cell: Variant in path_cells:
				if cell is Vector2i:
					serialized_path.append(DebugReportRuntime._coord(cell as Vector2i))
			path_summary[str(path_unit_id)] = serialized_path
		context["preview_paths"] = path_summary
	return context


func is_live_preview_active() -> bool:
	if _director == null:
		return false
	if selected_phase_action_exhausted():
		return false
	if awaiting_targeting_active():
		var actor: UnitState = _proj_unit(_director.selected_unit_id)
		if actor == null and _director.board != null:
			actor = _director.board.get_unit_by_id(_director.selected_unit_id)
		var ability: AbilityData = _selected_ability_data(actor)
		if actor != null and ability != null and not _is_awaiting_movement_endpoint(actor, ability):
			return false
	return preview_state.preview_board != null


## True when the last hover sim is for the tile under the mouse.
## Cursor / path / tiles may already have moved; sim paint must not follow a stale cell.
func live_sim_matches_hover() -> bool:
	if dragging:
		return true
	if _planning != null and _planning.qa_static_overlay:
		return true
	if _intent_state == null:
		return false
	return _last_sim_hover_refresh_cell == _intent_state.hover_coord


func _should_refresh_hover_preview(cell: Vector2i, planning_cell_changed: bool) -> bool:
	if planning_cell_changed:
		return true
	return not _hover_preview_fresh_at(cell)


func _hover_preview_fresh_at(cell: Vector2i) -> bool:
	if preview_state.preview_board == null or _hover_preview_cache_key.is_empty():
		return false
	if _director == null or _director.selected_unit_id < 0:
		return false
	var target_id: int = _hover_attack_target_id()
	var expected_key: String = _hover_interaction_cache_key(
		_director.selected_unit_id, cell, target_id,
	)
	return expected_key == _hover_preview_cache_key


func interaction_move_hover_active(unit_id: int, cell: Vector2i) -> bool:
	if _director == null or unit_id < 0 or not _director.board.is_in_bounds(cell):
		return false
	var move_timing: int = _director.get_planning_move_timing(unit_id)
	if move_timing == -1:
		return false
	if _director.unit_has_move_planned_at_timing(unit_id, move_timing):
		return false
	var p_unit := _proj_unit(unit_id)
	if p_unit == null:
		return false
	if _is_hover_move_cell(p_unit, cell):
		return true
	var hover_unit: UnitState = _director.board.get_unit_at(cell)
	if hover_unit != null and not hover_unit.is_enemy() and hover_unit.id != p_unit.id:
		var ally_slots: Dictionary = _ally_skill_preview_slots(p_unit, cell)
		for raw: Variant in ally_slots.get("pre", []):
			if raw is TimelineAction and (raw as TimelineAction).type == GameEnums.ActionType.MOVE:
				return true
	if hover_unit != null and hover_unit.is_enemy():
		var target_id: int = _resolve_hover_attack_target(p_unit, hover_unit)
		if target_id >= 0:
			return false
		var stand: Vector2i = _predicted_stand_tile_for_enemy_hover(cell, hover_unit)
		if stand != _proj_origin(p_unit) and _director.board.is_in_bounds(stand):
			return true
	return false


func selected_phase_action_exhausted(unit_id: int = -1) -> bool:
	if _director == null:
		return false
	var id: int = unit_id if unit_id >= 0 else _director.selected_unit_id
	if id < 0:
		return false
	if _director.unit_has_wait_planned(id):
		return true
	var p_unit := _proj_unit(id)
	if p_unit == null or p_unit.is_enemy():
		return false
	return AbilitySystem.is_planning_fully_exhausted(
		p_unit, _director.get_planning_move_timing(id) >= 0,
	)


func _is_selectable_player_unit(unit: UnitState) -> bool:
	if unit == null or not unit.is_alive() or unit.is_enemy():
		return false
	if NetworkManager != null and NetworkManager.is_multiplayer:
		return unit.controlling_player_id == NetworkManager.local_player_id
	return true


func skill_interaction_active() -> bool:
	return _skill_interaction_active()


func get_drag_route() -> Array[Vector2i]:
	return _drag_route


func _clear_hover_preview() -> void:
	clear_hover_route_preview()
	preview_state.clear_interaction()
	preview_state.preview_board = null
	drag_preview_failed = false
	_clear_intent_snapshot()
	if _planning != null:
		_planning.restore_committed_display()
	_sync_intent_live_board()


func clear_interaction_preview() -> void:
	_restore_hover_preview()


func _should_restore_stand_hover_preview(cell: Vector2i) -> bool:
	if _director == null or _director.board == null:
		return true
	if _director.selected_unit_id < 0 or not _director.board.is_in_bounds(cell):
		return true
	var p_unit := _proj_unit(_director.selected_unit_id)
	if p_unit == null or p_unit.is_enemy() or not p_unit.is_alive():
		return true
	if active_movement_planning_step(p_unit):
		return false
	if selected_phase_action_exhausted() and not awaiting_targeting_active():
		return true
	if (
		_drag_route_commits_active()
		and _drag_unit_id == p_unit.id
		and _movement_route_paint_allowed()
		and (
			_drag_route.has(cell)
			or (not _drag_route.is_empty() and cell == _drag_route.back())
			or _can_move_to(p_unit, cell)
		)
	):
		return false
	if (
		_drag_route_commits_active()
		and _drag_unit_id == p_unit.id
		and _basic_move_allowed()
		and (
			_drag_route.has(cell)
			or (not _drag_route.is_empty() and cell == _drag_route.back())
			or _can_move_to(p_unit, cell)
		)
	):
		return false
	if _basic_move_allowed() and _is_hover_move_cell(p_unit, cell):
		return false
	if not _ally_skill_preview_slots(p_unit, cell).is_empty():
		return false
	if (
		_director.selected_ability_index >= 0
		and awaiting_targeting_active()
		and _director.board.is_in_bounds(cell)
	):
		var dash_ab := _selected_ability_data(p_unit)
		if (
			dash_ab != null
			and _awaiting_flow_selected(p_unit, dash_ab)
			and AbilitySystem.planning_is_valid_awaiting_endpoint(
				_proj_origin(p_unit), cell, dash_ab, p_unit, _proj(),
			)
		):
			return false
	if not p_unit.active_abilities.is_empty() and _director.selected_ability_index >= 0:
		var target_id: int = _attack_target_id_at_cell(p_unit, cell)
		if _is_hover_move_cell(p_unit, cell) or target_id >= 0:
			return false
	if _director.selected_ability_index >= 0 and is_skill_aim_hover_at(cell):
		return false
	if _director.selected_ability_index >= 0 and action_range_visible_for_hover():
		return false
	return true


func _attack_target_id_at_cell(p_unit: UnitState, cell: Vector2i) -> int:
	if p_unit == null or _director == null or _director.board == null:
		return -1
	if not _director.board.is_in_bounds(cell):
		return -1
	var hover_unit: UnitState = _director.board.get_unit_at(cell)
	if hover_unit == null:
		return -1
	if _director.selected_ability_index >= 0:
		var skill_target_id: int = _skill_hover_unit_target_id(p_unit, hover_unit)
		if skill_target_id >= 0:
			return skill_target_id
	return _resolve_hover_attack_target(p_unit, hover_unit)


func _ally_skill_preview_slots(p_unit: UnitState, cell: Vector2i) -> Dictionary:
	if (
		p_unit == null
		or _director == null
		or _director.selected_ability_index < 0
		or not _director.board.is_in_bounds(cell)
	):
		return {}
	if _reposition_skill_committed_for_unit(p_unit.id):
		return {}
	var hover_unit: UnitState = _director.board.get_unit_at(cell)
	if hover_unit == null or hover_unit.is_enemy() or hover_unit.id == p_unit.id:
		return {}
	var ability: AbilityData = _selected_ability_data(p_unit)
	if ability == null or not AbilitySystem.planning_allows_paired_premove(ability):
		return {}
	var slots: Dictionary = _build_commit_slots_at_cell(p_unit.id, cell)
	return {} if _is_invalid_dict(slots) else slots


func _refresh_hover_interaction_preview(cell: Vector2i) -> void:
	if dragging or _director == null or _director.board == null:
		return
	var p_unit := _proj_unit(_director.selected_unit_id)
	if p_unit != null and _hover_settle_fresh_at(p_unit.id, cell):
		_apply_assembler_prefix_preview_on_painted_route(p_unit, cell)
		_refresh_click_target_highlight()
		return
	if p_unit != null and _sealed_leg_hover_restore_if_blocked(p_unit, cell):
		return
	if _should_restore_stand_hover_preview(cell):
		_restore_hover_preview()
		return
	if p_unit == null:
		_restore_hover_preview()
		return
	if _director.selected_ability_index >= 0:
		var early_target_id: int = _attack_target_id_at_cell(p_unit, cell)
		if (
			not painted_move_route_locked(p_unit, cell)
			and not preview_state.is_painted_leg_sealed(p_unit.id)
			and _authoritative_route_for_unit(p_unit.id).size() < 2
			and _hover_at_committed_stand_for_range_only(p_unit, cell, early_target_id)
		):
			var stand_res: Dictionary = _preview_at_interaction_cell(
				p_unit.id, cell, cell, -1, [], _snapshot_drag_legal_move_tiles(),
			)
			if not _is_invalid_dict(stand_res):
				_apply_settled_preview_result(stand_res)
			_refresh_click_target_highlight()
			return
	if active_movement_planning_step(p_unit):
		var step_ability: AbilityData = _selected_ability_data(p_unit)
		if step_ability == null:
			var awaiting_for_refresh: TimelineAction = _awaiting_action_for(p_unit)
			if awaiting_for_refresh != null:
				step_ability = awaiting_for_refresh.ability
		if (
			step_ability != null
			and _is_awaiting_movement_endpoint(p_unit, step_ability)
		):
			var endpoint_wps: Array[Vector2i] = _hover_walk_waypoints_for_skill(
				p_unit, cell, step_ability,
			)
		var step_target_id: int = _attack_target_id_at_cell(p_unit, cell)
		if step_ability != null and step_target_id >= 0:
			var approach_wps: Array[Vector2i] = _hover_walk_waypoints_for_skill(
				p_unit, cell, step_ability,
			)
			if not approach_wps.is_empty():
				var approach_res: Dictionary = _preview_at_interaction_cell(
					p_unit.id,
					cell,
					cell,
					step_target_id,
					approach_wps,
					_snapshot_drag_legal_move_tiles(),
				)
				if not _is_invalid_dict(approach_res):
					_apply_settled_preview_result(approach_res)
				_refresh_click_target_highlight()
				return
			_clear_stale_painted_preview_route(p_unit.id)
			var in_range_res: Dictionary = _preview_at_interaction_cell(
				p_unit.id,
				cell,
				cell,
				step_target_id,
				[],
				_snapshot_drag_legal_move_tiles(),
			)
			if not _is_invalid_dict(in_range_res):
				_apply_settled_preview_result(in_range_res)
			_refresh_click_target_highlight()
			return
		var step_ally_slots: Dictionary = _ally_skill_preview_slots(p_unit, cell)
		if not step_ally_slots.is_empty():
			var step_ally: UnitState = _director.board.get_unit_at(cell)
			var step_ally_wps: Array[Vector2i] = []
			if step_ability != null:
				step_ally_wps = _hover_walk_waypoints_for_skill(p_unit, cell, step_ability)
			var ally_res: Dictionary = _preview_at_interaction_cell(
				p_unit.id,
				cell,
				cell,
				step_ally.id,
				step_ally_wps,
				_snapshot_drag_legal_move_tiles(),
			)
			if not _is_invalid_dict(ally_res):
				_apply_settled_preview_result(ally_res)
			_refresh_click_target_highlight()
			return
		if painted_move_route_locked(p_unit, cell):
			_refresh_click_target_highlight()
			return
		_refresh_voluntary_walk_hover_preview(p_unit, cell)
		_refresh_click_target_highlight()
		return
	var ally_slots: Dictionary = _ally_skill_preview_slots(p_unit, cell)
	if not ally_slots.is_empty():
		var ally: UnitState = _director.board.get_unit_at(cell)
		_refresh_live_interaction_preview(_director.selected_unit_id, cell, ally.id, [])
		_refresh_click_target_highlight()
		return
	if _voluntary_walk_hover_paint_applies(p_unit, cell):
		_refresh_voluntary_walk_hover_preview(p_unit, cell)
		_refresh_click_target_highlight()
		return
	var target_enemy_id: int = -1
	if not p_unit.active_abilities.is_empty() and _director.selected_ability_index >= 0:
		target_enemy_id = _attack_target_id_at_cell(p_unit, cell)
	if (
		_director.selected_ability_index >= 0
		and awaiting_targeting_active()
		and _director.board.is_in_bounds(cell)
	):
		var dash_ab := _selected_ability_data(p_unit)
		var sealed_orbit_extend: bool = PlanningRoutePolicy.hover_rewrite_allowed(_sealed_leg_hover_mode(p_unit, cell))
		if (
			dash_ab != null
			and _awaiting_flow_selected(p_unit, dash_ab)
			and not sealed_orbit_extend
			and not painted_move_route_locked(p_unit, cell)
			and AbilitySystem.planning_is_valid_awaiting_endpoint(
				_proj_origin(p_unit), cell, dash_ab, p_unit, _proj(),
			)
		):
			_refresh_live_interaction_preview(_director.selected_unit_id, cell, -1, [])
			_refresh_click_target_highlight()
			return
	var tile_target_ability: AbilityData = _selected_ability_data(p_unit)
	if (
		tile_target_ability != null
		and (
			AbilitySystem.active_targeting_flags(p_unit, tile_target_ability)
			& GameEnums.TargetingFlags.TILE
		) != 0
		and not AbilitySystem.ability_has_movement_effect(tile_target_ability)
		and _in_ability_range_of_coord(p_unit, cell)
	):
		_refresh_live_interaction_preview(_director.selected_unit_id, cell, -1, [])
		_refresh_click_target_highlight()
		return
	if not p_unit.active_abilities.is_empty() and _director.selected_ability_index >= 0:
		var armed_ability: AbilityData = _selected_ability_data(p_unit)
		if (
			armed_ability != null
			and _is_awaiting_movement_endpoint(p_unit, armed_ability)
			and _painted_drag_route_drives_live_preview()
			and _sealed_leg_hover_restore_if_blocked(p_unit, cell)
		):
			_refresh_click_target_highlight()
			return
		var target_id: int = _attack_target_id_at_cell(p_unit, cell)
		if _hover_at_committed_stand_for_range_only(p_unit, cell, target_id):
			var stand_res: Dictionary = _preview_at_interaction_cell(
				p_unit.id, cell, cell, -1, [], _snapshot_drag_legal_move_tiles(),
			)
			if not _is_invalid_dict(stand_res):
				_apply_settled_preview_result(stand_res)
			_refresh_click_target_highlight()
			return
		if _is_hover_move_cell(p_unit, cell) or target_id >= 0:
			if target_id < 0 and _voluntary_walk_preview_refresh_needed(p_unit, cell):
				_refresh_voluntary_walk_hover_preview(p_unit, cell)
				_refresh_click_target_highlight()
				return
			var hover_waypoints: Array[Vector2i] = []
			var ability: AbilityData = _selected_ability_data(p_unit)
			if _voluntary_walk_preview_refresh_needed(p_unit, cell):
				_refresh_voluntary_walk_hover_preview(p_unit, cell)
				_refresh_click_target_highlight()
				return
			if _drag_route_commits_active():
				var route_waypoints: Array[Vector2i] = _route_waypoints()
				var enemy: UnitState = _director.board.get_unit_by_id(target_id) if (target_id >= 0 and _director != null and _director.board != null) else null
				if enemy == null or _enemy_hover_respects_painted_route(p_unit, enemy, ability, route_waypoints):
					hover_waypoints = route_waypoints
				else:
					_clear_hover_drag_route()
					if ability != null:
						hover_waypoints = _hover_walk_waypoints_for_skill(p_unit, cell, ability)
			elif ability != null:
				hover_waypoints = _hover_walk_waypoints_for_skill(p_unit, cell, ability)
			_refresh_live_interaction_preview(_director.selected_unit_id, cell, target_id, hover_waypoints)
			_refresh_click_target_highlight()
			return
	if p_unit != null and _sealed_leg_hover_restore_if_blocked(p_unit, cell):
		_refresh_click_target_highlight()
		return
	if _director.selected_ability_index >= 0 and action_range_visible_for_hover():
		var stand_only_ability: AbilityData = _selected_ability_data(p_unit)
		if (
			not active_movement_planning_step(p_unit)
			and (
				stand_only_ability == null
				or not _is_awaiting_movement_endpoint(p_unit, stand_only_ability)
			)
		):
			var stand_res: Dictionary = _preview_at_interaction_cell(
				p_unit.id, cell, cell, -1, [], _snapshot_drag_legal_move_tiles(),
			)
			if not _is_invalid_dict(stand_res):
				_apply_settled_preview_result(stand_res)
			_refresh_click_target_highlight()
			return
	_restore_hover_preview()


func _sync_movement_preview_after_hover_sim(cell: Vector2i) -> void:
	if _director == null or not _director.board.is_in_bounds(cell):
		return
	if _director.selected_unit_id < 0:
		return
	var hover_unit: UnitState = _proj_unit(_director.selected_unit_id)
	if hover_unit == null:
		return
	if dragging and _voluntary_walk_orbit_phase_open(hover_unit):
		var leg_origin: Vector2i = _phase_entry_stand(hover_unit)
		if leg_origin.x > -900000:
			var forbidden: Dictionary = CombatPlanningPreview.prior_leg_forbidden_cells(
				_director, hover_unit.id, leg_origin,
			)
			if (
				forbidden.has(cell)
				and cell != leg_origin
				and not _can_move_to(hover_unit, cell)
			):
				return
	if dragging and not _voluntary_walk_orbit_phase_open(hover_unit):
		return
	if _sealed_leg_hover_restore_if_blocked(hover_unit, cell):
		return
	if painted_move_route_locked(hover_unit, cell):
		return
	if not active_movement_planning_step(hover_unit):
		return
	if _director.selected_ability_index < 0:
		return
	if not _movement_preview_resync_after_sim_allowed(hover_unit):
		return
	_refresh_hover_interaction_preview(cell)
	_last_sim_hover_refresh_cell = cell


func _refresh_selected_interaction_preview() -> void:
	var cell: Vector2i = _intent_state.hover_coord if _intent_state != null else Vector2i(-999, -999)
	_refresh_hover_interaction_preview(cell)


func _is_hover_move_cell(p_unit: UnitState, cell: Vector2i) -> bool:
	if p_unit == null or cell == p_unit.position:
		return false
	if _awaiting_target_pick_blocks_premove():
		return false
	if _director != null and _director.board != null:
		var occ: UnitState = _director.board.get_unit_at(cell)
		if occ != null and occ.is_enemy() and not _can_move_to(p_unit, cell):
			return false
	if _skill_interaction_active():
		var selected_ability := _selected_ability_data(p_unit)
		if selected_ability != null and _is_awaiting_movement_endpoint(p_unit, selected_ability):
			return _can_move_to(p_unit, cell)
		## Armed TARGET_PICK (Volley, traps): in-range hover is the blast cell, not a walk.
		## Unarmed TILE skills still premove ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ range often covers every walk tile.
		if _is_armed_tile_skill_aim_cell(p_unit, cell, selected_ability):
			return false
		if selected_ability != null and AbilitySystem.planning_allows_paired_premove(selected_ability):
			return _can_move_to(p_unit, cell)
		if (
			selected_ability != null
			and _awaiting_flow_selected(p_unit, selected_ability)
			and not _is_awaiting_movement_endpoint(p_unit, selected_ability)
		):
			## Armed later NEW_AIM (DAMAGE etc.) is not a walk hover. Unarmed still pre-moves.
			if awaiting_targeting_active() or (
				_director != null and _director.find_awaiting_action(p_unit.id) != null
			):
				return false
			return _can_move_to(p_unit, cell)
		if _drag_route_commits_active() and _drag_unit_id == p_unit.id:
			if not _drag_route.is_empty() and _drag_route.has(cell):
				var route_idx: int = _drag_route.find(cell)
				if route_idx > 0:
					return true
				if cell == _drag_route.back():
					return _can_move_to(p_unit, cell)
			return _can_move_to(p_unit, cell)
		return false
	if _planning != null and _planning.is_hover_move_tile(cell):
		return _can_move_to(p_unit, cell)
	return _can_move_to(p_unit, cell)


func _movement_icon_for(p_unit: UnitState, cell: Vector2i) -> String:
	var waypoints: Array[Vector2i] = []
	if dragging and _drag_unit_id == p_unit.id:
		waypoints = _route_waypoints()
	if AbilitySystem.movement_requires_run(_proj(), p_unit, cell, waypoints):
		return PlanningIcons.GLYPH_RUN
	return PlanningIcons.GLYPH_WALK


func _move_attack_icon_for(p_unit: UnitState, cell: Vector2i) -> String:
	return PlanningIcons.join_glyphs([
		_movement_icon_for(p_unit, cell),
		PlanningIcons.GLYPH_ATTACK,
	])


func _refresh_click_target_highlight() -> void:
	if _planning == null or _director == null:
		return
	var target_id: int = _hover_attack_target_id()
	if target_id < 0 and _director.board != null and _intent_state != null:
		var cell: Vector2i = _intent_state.hover_coord
		var occ := _director.board.get_unit_at(cell)
		if occ != null and occ.is_enemy():
			target_id = occ.id
	if target_id >= 0:
		_planning.set_drag_attack_target(target_id)
	else:
		_planning.set_drag_attack_target(-1)


func _restore_hover_preview() -> void:
	_hover_preview_cache_key = ""
	var preserve_painted_route: bool = (
		not dragging
		and _drag_route.size() >= 2
		and _voluntary_walk_corridor_paint_active()
	)
	if not preserve_painted_route:
		_clear_hover_drag_route()
	if _planning != null:
		_planning.set_drag_attack_target(-1)
	clear_hover_route_preview()
	preview_state.clear_interaction()
	preview_state.preview_board = null
	drag_preview_failed = false
	_clear_intent_snapshot()
	if _planning != null:
		_planning.restore_committed_display()
		if _director != null and _director.selected_unit_id >= 0 and _is_planning():
			_planning._recompute_hover_ranges_from_inputs()
			_planning.queue_redraw()
	_sync_intent_live_board()


func _clear_hover_drag_route() -> void:
	if _drag_route.is_empty() and _drag_unit_id < 0:
		return
	_drag_route.clear()
	_drag_unit_id = -1
	if _planning != null:
		_planning.clear_drag_route()


## Range 2+ enemy hover discards painted detour buffers (see _enemy_hover_respects_painted_route).
func _clear_stale_painted_preview_route(unit_id: int) -> void:
	if unit_id < 0:
		return
	if preview_state.is_painted_leg_sealed(unit_id):
		return
	_clear_frozen_painted_leg(unit_id)
	if not preview_state.preview_paths.has(unit_id):
		return
	CombatPlanningPreview.clear_unit_preview_path(preview_state, unit_id)
	if _planning != null:
		_planning.apply_preview_state(
			preview_state, unit_id, _hover_attack_target_id(),
		)


func _clear_frozen_painted_leg(unit_id: int) -> void:
	if unit_id < 0:
		return
	preview_state.clear_sealed_painted_leg(unit_id)


func _restore_locked_painted_preview_paths(unit_id: int) -> void:
	if unit_id < 0:
		return
	var actor: UnitState = _proj_unit(unit_id)
	if actor != null:
		if _sealed_leg_structurally_locked(actor):
			var sealed_route: Array = _authoritative_route_for_unit(unit_id)
			if sealed_route.size() >= 2:
				CombatPlanningPreview.set_unit_preview_path(
					preview_state, unit_id, sealed_route,
				)
		elif _painted_drag_route_matches_leg(actor) and _drag_route.size() >= 2:
			if preview_state.is_painted_leg_sealed(unit_id):
				var drag_sealed_route: Array = _authoritative_route_for_unit(unit_id)
				if drag_sealed_route != _drag_route:
					_clear_frozen_painted_leg(unit_id)
			var drag_route: Array = _authoritative_route_for_unit(unit_id)
			if drag_route.size() >= 2:
				CombatPlanningPreview.set_unit_preview_path(
					preview_state, unit_id, drag_route,
				)
		_seal_painted_preview_landing_if_needed(actor)
		_discard_drag_buffer_when_preview_route_locked(actor)
## Preview_paths is the painted landing SSOT ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ seal when it matches the active leg, then drop drag buffer.
func _sync_preview_board_to_sealed_landing(unit_id: int) -> void:
	if unit_id < 0 or _director == null:
		return
	var route: Array = _authoritative_route_for_unit(unit_id)
	if route.size() < 2:
		return
	var board: BoardState = _proj().clone()
	var unit: UnitState = board.get_unit_by_id(unit_id)
	if unit == null:
		return
	GridSystem.set_occupant(board, unit.position, -1)
	for i: int in range(1, route.size()):
		var step: Variant = route[i]
		if step is Vector2i:
			var step_cell: Vector2i = step as Vector2i
			unit.position = step_cell
			GridSystem.set_occupant(board, step_cell, unit_id)
	preview_state.preview_board = board

func _seal_painted_preview_landing_if_needed(p_unit: UnitState) -> void:
	if dragging or p_unit == null or _director == null:
		return
	if _voluntary_walk_orbit_phase_open(p_unit) and not _painted_drag_route_matches_leg(p_unit):
		return
	if preview_state.is_painted_leg_sealed(p_unit.id):
		return
	if not active_movement_planning_step(p_unit):
		return
	if not _painted_drag_route_matches_leg(p_unit):
		return
	_apply_voluntary_walk_drag_preview(p_unit.id, true)
	preview_state.seal_painted_leg(p_unit.id)
	_sync_preview_board_to_sealed_landing(p_unit.id)
	_discard_drag_buffer_when_preview_route_locked(p_unit)


func _discard_drag_buffer_when_preview_route_locked(p_unit: UnitState) -> void:
	if p_unit == null or not painted_move_route_locked(p_unit):
		return
	if _drag_unit_id == p_unit.id and not _drag_route.is_empty():
		_clear_hover_drag_route()


func _discard_enemy_hover_painted_buffers_if_needed(
	p_unit: UnitState,
	cell: Vector2i,
	ability: AbilityData,
) -> void:
	if p_unit == null or _director == null or _director.board == null:
		return
	var target_enemy_id: int = _attack_target_id_at_cell(p_unit, cell)
	if target_enemy_id < 0:
		return
	var enemy_unit: UnitState = _director.board.get_unit_by_id(target_enemy_id)
	if enemy_unit == null:
		return
	if _enemy_hover_respects_painted_route(p_unit, enemy_unit, ability, _route_waypoints()):
		return
	_clear_hover_drag_route()
	_clear_frozen_painted_leg(p_unit.id)
	if ability != null and AbilitySystem.active_range_tiles(p_unit, ability) > 1:
		_clear_stale_painted_preview_route(p_unit.id)


func _stationary_ranged_enemy_hover_suppresses_move_preview(
	actor: UnitState,
	hover_cell: Vector2i,
	ability: AbilityData,
) -> bool:
	if actor == null or ability == null or _director == null or _director.board == null:
		return false
	if AbilitySystem.active_range_tiles(actor, ability) <= 1:
		return false
	var enemy_id: int = _attack_target_id_at_cell(actor, hover_cell)
	if enemy_id < 0:
		return false
	var enemy: UnitState = _director.board.get_unit_by_id(enemy_id)
	if enemy == null:
		return false
	var stand: Vector2i = _phase_entry_stand(actor)
	return AbilitySystem.planning_is_valid_awaiting_endpoint(
		stand, enemy.position, ability, actor, _proj(),
	)


func _update_hover_attack_preview() -> void:
	if aiming or dragging or _director == null or _director.board == null:
		return
	if _phase_not_planning():
		return
	if _director.selected_unit_id < 0:
		return
	var cell: Vector2i = _intent_state.hover_coord if _intent_state != null else Vector2i(-999, -999)
	if not _director.board.is_in_bounds(cell):
		return
	var p_unit := _proj_unit(_director.selected_unit_id)
	if p_unit == null or p_unit.is_enemy() or not p_unit.is_alive():
		return
	if selected_phase_action_exhausted():
		return
	if p_unit.active_abilities.is_empty() or _director.selected_ability_index < 0:
		return
	var endpoint_ability := _selected_ability_data(p_unit)
	if (
		_should_use_awaiting_endpoint_on_input(endpoint_ability)
		and AbilitySystem.planning_is_valid_awaiting_endpoint(
			_phase_entry_stand(p_unit), cell, endpoint_ability, p_unit, _proj(),
		)
	):
		var dash_res: Dictionary = _preview_from_commit_slots_at_cell(_director.selected_unit_id, cell)
		_apply_hover_preview_dict(dash_res)
		return
	var hover_unit := _proj().get_unit_at(cell)
	if hover_unit == null:
		return
	var target_id := _resolve_hover_attack_target(p_unit, hover_unit)
	if target_id < 0:
		return
	var rng: int = _ability_range(p_unit)
	if (
		rng >= 0
		and _director != null
		and _director.phase == CombatDirector.Phase.PLANNING
		and target_id != p_unit.id
	):
		var target := _proj().get_unit_by_id(target_id)
		var range_origin: Vector2i = _ability_range_origin(p_unit)
		if target != null and GridSystem.manhattan(range_origin, target.position) > rng:
			return
	var target_unit := _director.board.get_unit_by_id(target_id)
	var preview_cell: Vector2i = target_unit.position if target_unit != null else cell
	var res: Dictionary = _preview_from_commit_slots_at_cell(
		_director.selected_unit_id, preview_cell, [], [], p_unit.position,
	)
	_apply_hover_preview_dict(res)


func _apply_hover_preview_dict(res: Dictionary) -> void:
	if res.is_empty():
		return
	if _is_invalid_dict(res):
		_clear_hover_preview()
		return
	_apply_settled_preview_result(res)
	_sync_intent_live_board()


func _refresh_live_interaction_preview(
	unit_id: int,
	move_coord: Vector2i,
	attack_target_id: int = -1,
	waypoints: Array[Vector2i] = [],
) -> void:
	if _director == null or _director.board == null or unit_id < 0:
		return
	var unit := _director.board.get_unit_by_id(unit_id)
	if unit == null:
		return
	var cell: Vector2i = _intent_state.hover_coord if _intent_state != null else move_coord
	if active_movement_planning_step(unit) and attack_target_id < 0 and waypoints.is_empty():
		_refresh_voluntary_walk_hover_preview(unit, cell)
		return
	var cache_key: String = _hover_interaction_cache_key(unit_id, cell, attack_target_id)
	if (
		cache_key == _hover_preview_cache_key
		and preview_state.preview_board != null
		and _intent_snapshot_valid
		and _intent_snapshot_key == cache_key
	):
		return
	var res: Dictionary = _take_hover_preview_lru(cache_key)
	if res.is_empty():
		res = _preview_at_interaction_cell(
			unit_id, cell, move_coord, attack_target_id, waypoints, _snapshot_drag_legal_move_tiles(),
		)
		_store_hover_preview_lru(cache_key, res)
	_apply_hover_preview_from_result(res, unit_id, move_coord, cache_key)


func _apply_hover_preview_from_result(
	res: Dictionary,
	unit_id: int,
	move_coord: Vector2i,
	cache_key: String,
) -> void:
	drag_preview_failed = _is_invalid_dict(res)
	for event: Variant in res.get("events", []):
		if event is SimEvent:
			var sim: SimEvent = event as SimEvent
			if (
				sim.type == GameEnums.SimEventType.ACTION_FAILED
				and int(sim.data.get("actor", -1)) == unit_id
			):
				drag_preview_failed = true
				break
	var temp_board: BoardState = res.get("temp_board")
	var pv_actor: UnitState = temp_board.get_unit_by_id(unit_id) if temp_board != null else null
	drag_sim_actor_pos = pv_actor.position if pv_actor != null else move_coord
	_apply_live_preview(res)
	if preview_state.preview_board != null and not drag_preview_failed:
		_hover_preview_cache_key = cache_key
	else:
		_hover_preview_cache_key = ""


func _awaiting_action_for(actor: UnitState) -> TimelineAction:
	if _director == null or actor == null:
		return null
	return _director.find_awaiting_action(actor.id)


func _awaiting_ability_for(actor: UnitState) -> AbilityData:
	var ability: AbilityData = _selected_ability_data(actor)
	if ability != null:
		return ability
	var awaiting: TimelineAction = _awaiting_action_for(actor)
	if awaiting != null:
		return awaiting.ability
	return null


func _awaiting_permits_hover_unit_target(actor: UnitState, hover_unit: UnitState) -> bool:
	if actor == null or hover_unit == null:
		return false
	var awaiting: TimelineAction = _awaiting_action_for(actor)
	if awaiting == null:
		return false
	if AbilitySystem.planning_awaiting_enemy_pick_active(actor, awaiting):
		return _can_target_unit_with_selected_ability(actor, hover_unit)
	if AbilitySystem.planning_awaiting_target_pick_open(actor, awaiting):
		return _can_target_unit_with_selected_ability(actor, hover_unit)
	return false


func _skill_hover_unit_target_id(p_unit: UnitState, hover_unit: UnitState) -> int:
	if p_unit == null or hover_unit == null or not hover_unit.is_alive():
		return -1
	if _director == null or _director.selected_ability_index < 0:
		return -1
	var ability: AbilityData = _selected_ability_data(p_unit)
	if ability == null or AbilitySystem.is_run_ability(ability):
		return -1
	if hover_unit.id == p_unit.id:
		if AbilitySystem.can_target_self(p_unit, ability):
			return p_unit.id
		return -1
	if hover_unit.is_enemy():
		return _resolve_hover_attack_target(p_unit, hover_unit)
	if not AbilitySystem.target_passes_mode(p_unit, ability, hover_unit):
		return -1
	return hover_unit.id


func _resolve_hover_attack_target(p_unit: UnitState, hover_unit: UnitState) -> int:
	if _skill_interaction_active() or aiming:
		if hover_unit.id == p_unit.id:
			var ability := _selected_ability_data(p_unit)
			if ability == null or not AbilitySystem.can_target_self(p_unit, ability):
				return -1
			var hover_cell: Vector2i = (
				_intent_state.hover_coord if _intent_state != null else hover_unit.position
			)
			if hover_cell != _proj_origin(p_unit):
				return -1
			return p_unit.id
		if hover_unit.is_enemy():
			var ability: AbilityData = _awaiting_ability_for(p_unit)
			var awaiting: TimelineAction = _awaiting_action_for(p_unit)
			if awaiting != null and _awaiting_permits_hover_unit_target(p_unit, hover_unit):
				return hover_unit.id
			if ability == null or _awaiting_flow_selected(p_unit, ability):
				return -1
			if AbilitySystem.ability_uses_attack_animation(ability, p_unit):
				return hover_unit.id
			if _can_target_unit_with_selected_ability(p_unit, hover_unit):
				return hover_unit.id
			return -1
		if _can_target_unit_with_selected_ability(p_unit, hover_unit):
			return hover_unit.id
		return -1
	if hover_unit.is_enemy():
		return hover_unit.id
	return -1


func _should_use_awaiting_endpoint_on_input(ability: AbilityData) -> bool:
	if not awaiting_targeting_active():
		return false
	if ability == null or _director == null or _director.selected_ability_index < 0:
		return false
	var actor := _proj_unit(_director.selected_unit_id)
	if actor == null or not _awaiting_flow_selected(actor, ability):
		return false
	if _skill_interaction_active() or aiming:
		return true
	if not _voluntary_walk_planning_active():
		return true
	return AbilitySystem.ability_blocks_basic_movement(ability)


func _unit_movement_blocked_by_dash(unit: UnitState) -> bool:
	if _director.selected_ability_index < 0:
		return false
	var ability := _selected_ability_data(unit)
	return ability != null and AbilitySystem.ability_blocks_basic_movement(ability)


func _phase_not_planning() -> bool:
	return not CombatDirector.is_planning_phase(_director.phase)


func _plan_approach_or_trample_on_enemy(
	unit_id: int,
	enemy: UnitState,
	local: Vector2,
	preferred_tile: Vector2i,
	waypoints: Array[Vector2i] = [],
	legal_move_tiles: Array[Vector2i] = [],
) -> bool:
	var target_cell: Vector2i = enemy.position if enemy != null else preferred_tile
	var attack_id: int = enemy.id if enemy != null else -1
	return _commit_at_interaction_cell(unit_id, target_cell, local, attack_id)


const _NO_PREFERRED_APPROACH: Vector2i = Vector2i(-999999, -999999)


## Single source for commit cell, waypoints, and approach hint ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ cursor, preview, and drop must match.
func _drag_route_commits_active() -> bool:
	if _drag_drop_finishing and _drag_route.size() >= 2:
		return true
	if dragging:
		return true
	if _drag_route.size() < 2:
		return false
	var p_unit: UnitState = null
	if _director != null and _director.selected_unit_id >= 0:
		p_unit = _proj_unit(_director.selected_unit_id)
		if p_unit != null:
			var ability := _selected_ability_data(p_unit)
			if ability != null and _is_awaiting_movement_endpoint(p_unit, ability):
				if _painted_drag_route_matches_leg(p_unit):
					return true
				if (
					not dragging
					and _voluntary_walk_corridor_paint_active()
					and _drag_route.size() >= 2
					and _drag_unit_id == p_unit.id
				):
					return true
				return false
			if _voluntary_walk_orbit_phase_open(p_unit) and not _painted_drag_route_matches_leg(p_unit):
				return false
	if _painted_drag_route_matches_leg(p_unit):
		return true
	return _voluntary_walk_corridor_paint_active()


## Painted route drives commit/slots; live preview uses drag buffer while dragging or after leg-matched paint.
func _painted_drag_route_drives_live_preview() -> bool:
	if not _drag_route_commits_active():
		return false
	if dragging:
		return true
	var actor: UnitState = _proj_unit(_drag_unit_id) if _drag_unit_id >= 0 else null
	if actor != null and _painted_drag_route_matches_leg(actor):
		return true
	return _voluntary_walk_corridor_paint_active() and _drag_route.size() >= 2



func _leg_anchor_for_painted_drag(p_unit: UnitState) -> Vector2i:
	var sealed: Vector2i = CombatPlanningPreview.sealed_phase_entry_anchor(
		preview_state, p_unit.id,
	)
	if sealed.x > -900000:
		return sealed
	var painted: Array = _authoritative_route_for_unit(p_unit.id)
	if painted.size() >= 2 and painted[0] is Vector2i:
		return painted[0] as Vector2i
	return _phase_entry_stand(p_unit)


func _painted_drag_route_matches_leg(p_unit: UnitState) -> bool:
	if p_unit == null or _drag_route.size() < 2 or _drag_unit_id != p_unit.id:
		return false
	if not _movement_route_paint_allowed():
		return false
	var painted_origin: Vector2i = _drag_route[0] as Vector2i
	var leg_anchor: Vector2i = _leg_anchor_for_painted_drag(p_unit)
	if leg_anchor.x <= -900000:
		return false
	return painted_origin == leg_anchor


func _painted_preview_route_matches_leg(p_unit: UnitState) -> bool:
	if p_unit == null or not _movement_route_paint_allowed():
		return false
	var route: Array = _authoritative_route_for_unit(p_unit.id)
	if route.size() < 2:
		return false
	var origin: Vector2i = _leg_anchor_for_painted_drag(p_unit)
	if origin.x <= -900000:
		return false
	return route[0] is Vector2i and (route[0] as Vector2i) == origin


func _painted_basic_move_route_commits_active() -> bool:
	if _director == null or _director.selected_unit_id < 0:
		return false
	var p_unit: UnitState = _proj_unit(_director.selected_unit_id)
	if not _painted_drag_route_matches_leg(p_unit):
		return false
	if not _basic_move_allowed():
		return false
	var move_timing: int = _director.get_planning_move_timing(p_unit.id)
	if move_timing == -1:
		return true
	if (
		move_timing != GameEnums.MoveTiming.PRE_ACTION
		and move_timing != GameEnums.MoveTiming.POST_ACTION
	):
		return false
	return not _director.unit_has_move_planned_at_timing(p_unit.id, move_timing)


func _commit_interaction_params(
	hover_cell: Vector2i,
	attack_target_id: int = -1,
) -> Dictionary:
	var waypoints: Array[Vector2i] = []
	var legal_moves: Array[Vector2i] = []
	var commit_cell: Vector2i = hover_cell
	var preferred: Vector2i = _NO_PREFERRED_APPROACH
	if attack_target_id >= 0 and _director != null and _director.board != null:
		var target: UnitState = _director.board.get_unit_by_id(attack_target_id)
		if target != null:
			commit_cell = target.position
			preferred = target.position
			if _drag_route_commits_active():
				var actor: UnitState = _proj_unit(_director.selected_unit_id)
				var ability: AbilityData = _selected_ability_data(actor)
				var route_waypoints: Array[Vector2i] = _route_waypoints_for_commit()
				if target.is_enemy():
					if _enemy_hover_respects_painted_route(actor, target, ability, route_waypoints):
						waypoints = route_waypoints
						legal_moves = _snapshot_drag_legal_move_tiles()
						if _drag_last_free != commit_cell:
							preferred = _drag_last_free
					elif (
						actor != null
						and ability != null
						and not AbilitySystem.is_movement_skill(ability)
						and _director.selected_ability_index >= 0
						and _director.find_awaiting_action(_director.selected_unit_id) == null
						and not _in_ability_range(actor, target)
					):
						if not dragging:
							_clear_hover_drag_route()
						var board: BoardState = _proj()
						var approach: Vector2i = _director.preview_approach_tile(
							_director.selected_unit_id,
							target.id,
							_director.selected_ability_index,
							target.position,
						)
						if approach != actor.position:
							waypoints = _resolve_commit_move_waypoints(
								_director.selected_unit_id, actor, approach,
							)
							if waypoints.is_empty():
								waypoints = _hover_walk_waypoints_for_skill(
									actor, approach, ability,
								)
				elif (
					actor != null
					and ability != null
					and AbilitySystem.planning_allows_paired_premove(ability)
					and not route_waypoints.is_empty()
				):
					waypoints = route_waypoints
					legal_moves = _snapshot_drag_legal_move_tiles()
					if _drag_route_stand_cell() != commit_cell:
						preferred = _drag_route_stand_cell()
			elif target.is_enemy():
				var actor: UnitState = _proj_unit(_director.selected_unit_id)
				var ability: AbilityData = _selected_ability_data(actor)
				if (
					actor != null
					and ability != null
					and not AbilitySystem.is_movement_skill(ability)
					and _director.selected_ability_index >= 0
					and _director.find_awaiting_action(_director.selected_unit_id) == null
					and not _in_ability_range(actor, target)
				):
					var board: BoardState = _proj()
					var approach: Vector2i = _director.preview_approach_tile(
						_director.selected_unit_id,
						target.id,
						_director.selected_ability_index,
						target.position,
					)
					if approach != actor.position:
						waypoints = _resolve_commit_move_waypoints(
							_director.selected_unit_id, actor, approach,
						)
						if waypoints.is_empty():
							waypoints = _hover_walk_waypoints_for_skill(
								actor, target.position, ability,
							)
	elif _drag_route_commits_active():
		waypoints = _route_waypoints_for_commit()
		legal_moves = _snapshot_drag_legal_move_tiles()
	else:
		var actor: UnitState = _proj_unit(_director.selected_unit_id)
		var ability: AbilityData = _selected_ability_data(actor)
		if actor != null and ability != null:
			var painted_wps: Array[Vector2i] = _resolve_commit_move_waypoints(
				_director.selected_unit_id, actor, hover_cell,
			)
			var hover_wps: Array[Vector2i] = _hover_walk_waypoints_for_skill(
				actor, hover_cell, ability,
			)
			if not painted_wps.is_empty():
				waypoints = painted_wps
			elif not hover_wps.is_empty():
				waypoints = hover_wps
			elif _movement_skill_commits_tile_endpoint(actor, ability, hover_cell):
				waypoints = hover_wps
	var face_dir: int = -1
	if _map_view != null:
		face_dir = _facing_from_drop(_mouse_local_for_facing(), hover_cell)
	return {
		"cell": commit_cell,
		"waypoints": waypoints,
		"legal_move_tiles": legal_moves,
		"preferred": preferred,
		"face_dir": face_dir,
	}


func _final_commit_slots_for_interaction(
	unit_id: int,
	cell: Vector2i,
	waypoints: Array[Vector2i] = [],
	legal_move_tiles: Array[Vector2i] = [],
	preferred_approach: Vector2i = _NO_PREFERRED_APPROACH,
	face_dir: int = -1,
	sim_validate: bool = true,
) -> Dictionary:
	var slots: Dictionary = _build_commit_slots_at_cell(
		unit_id, cell, waypoints, legal_move_tiles, preferred_approach, face_dir,
	)
	_strip_unaffordable_premove_pairs(slots, unit_id, cell, waypoints)
	_reject_orphan_skill_premove(slots, unit_id, cell)
	var hover_unit: UnitState = _resolve_hover_unit_at(cell)
	if hover_unit != null and not waypoints.is_empty():
		var actor := _proj_unit(unit_id)
		var ability := _selected_ability_data(actor)
		var needs_repath := false
		if (
			hover_unit.is_enemy()
			and (slots.get("action", []) as Array).is_empty()
			and not (slots.get("pre", []) as Array).is_empty()
		):
			needs_repath = (
				actor != null
				and not _enemy_hover_respects_painted_route(actor, hover_unit, ability, waypoints)
			)
		elif (
			not hover_unit.is_enemy()
			and hover_unit.id != unit_id
			and actor != null
			and ability != null
			and AbilitySystem.planning_allows_paired_premove(ability)
		):
			var stand_cell: Vector2i = waypoints.back() if not waypoints.is_empty() else cell
			needs_repath = not _ally_hover_respects_painted_route(
				actor, hover_unit, ability, waypoints, stand_cell,
			)
		if needs_repath:
			slots = {"invalid": "Painted route does not match hover target."}
	slots = _finalize_commit_slots(slots, unit_id, sim_validate)
	if _should_strip_action_from_basic_postmove_slots(unit_id):
		slots["action"] = []
	return slots


func _should_strip_action_from_basic_postmove_slots(unit_id: int) -> bool:
	if _director == null or unit_id < 0:
		return false
	var actor: UnitState = _proj_unit(unit_id)
	if actor == null:
		return false
	return _director.planning_timeline_phase_kind(actor.id) == CombatDirector.PlanningTimelinePhaseKind.POSTMOVE_MOVEMENT


func _strip_unaffordable_premove_pairs(
	slots: Dictionary,
	unit_id: int,
	cell: Vector2i,
	waypoints: Array[Vector2i],
) -> void:
	var actions: Array = slots.get("action", [])
	if actions.is_empty():
		return
	if (slots.get("pre", []) as Array).is_empty() and (slots.get("post", []) as Array).is_empty():
		return
	var actor := _proj_unit(unit_id)
	if actor == null and _director != null and _director.board != null:
		actor = _director.board.get_unit_by_id(unit_id)
	if actor == null:
		return
	var kept: Array = []
	var stripped_pair: bool = false
	for raw: Variant in actions:
		if raw is TimelineAction:
			var action: TimelineAction = raw as TimelineAction
			if (
				action.type == GameEnums.ActionType.ABILITY
				and action.ability != null
				and not _can_pair_run_move_with_ability(actor, cell, waypoints, action.ability)
			):
				stripped_pair = true
				continue
		kept.append(raw)
	slots["action"] = kept


func _reject_orphan_skill_premove(slots: Dictionary, unit_id: int, cell: Vector2i) -> void:
	if _is_invalid_dict(slots):
		return
	if not (slots.get("action", []) as Array).is_empty():
		return
	if (slots.get("pre", []) as Array).is_empty() and (slots.get("post", []) as Array).is_empty():
		return
	if _director == null or _director.selected_ability_index < 0:
		return
	var actor := _proj_unit(unit_id)
	if actor == null:
		return
	var ability := _selected_ability_data(actor)
	if ability == null or AbilitySystem.is_movement_skill(ability):
		return
	var hover_unit: UnitState = _resolve_hover_unit_at(cell)
	if hover_unit == null or not hover_unit.is_enemy():
		return
	slots["pre"] = []
	slots["post"] = []
	slots["invalid"] = "Not enough AP to run and use this skill."


func _commit_at_interaction_cell(
	unit_id: int,
	cell: Vector2i,
	local: Vector2,
	attack_target_id: int = -1,
) -> bool:
	return _commit_at_cell(
		unit_id,
		cell,
		local,
	)

func _commit_at_cell(
	unit_id: int,
	cell: Vector2i,
	local: Vector2,
	waypoints: Array[Vector2i] = [],
	legal_move_tiles: Array[Vector2i] = [],
	preferred_approach: Vector2i = _NO_PREFERRED_APPROACH,
	face_dir: int = -1,
	_intent_slots_unused: Dictionary = {},
) -> bool:
	if selected_phase_action_exhausted(unit_id):
		_play_sfx("invalid")
		return false
	_flush_hover_heavy_sync()
	var slots: Dictionary = {}
	if (
		_settled_hover_preview != null
		and _settled_hover_preview.matches_ratification_context(
			cell, unit_id, settled_hover_revision_key(), _director.selected_ability_index
		)
	):
		slots = _settled_hover_preview.duplicate_slots()
	else:
		push_warning("SSOT: commit rejected - no settled hover preview for unit %d at %s" % [unit_id, cell])
		_play_sfx("invalid")
		return false
	if slots.get("_noop", false) == true:
		_play_sfx("ability")
		return true
	if _is_invalid_dict(slots):
		_play_sfx("invalid")
		_clear_intent_snapshot()
		return false
	_notify_drag_plan_move_committed(unit_id)
	if _director != null:
		_director.stash_commit_intent_preview_paths(_authoritative_preview_paths())
	if _director == null or not _director.ratify_sealed_intent(
		unit_id,
		_settled_hover_preview,
		cell,
		settled_hover_revision_key(),
		_director.selected_ability_index,
	):
		if _drag_move_commit_instant and _director != null:
			_director.clear_planning_move_instant(unit_id)
		_play_sfx("invalid")
		return false
	_play_commit_sfx(slots)
	_promote_intent_preview_after_commit()
	_on_commit_slots_applied(unit_id, slots)
	_clear_hover_drag_route()
	_clear_intent_snapshot()
	return true

func _promote_intent_preview_after_commit() -> void:
	if _planning == null:
		return
	var unit_id: int = _director.selected_unit_id if _director != null else -1
	var fallback_board: BoardState = _proj() if _director != null else null
	var intent_paths: Dictionary = _authoritative_preview_paths()
	if preview_state.preview_board != null:
		_planning.apply_preview_state(
			preview_state,
			unit_id,
			_hover_attack_target_id(),
		)
	_planning.promote_live_preview_to_committed()
	var committed: CombatPlanningPreview = _planning.get_committed_preview()
	var preserve_full_route: bool = false
	if unit_id >= 0 and _director != null:
		for action: TimelineAction in _director.plan_pre_move.entries:
			if action != null and action.actor_id == unit_id and not action.waypoints.is_empty():
				preserve_full_route = true
				break
		if preserve_full_route and intent_paths.has(unit_id):
			var route: Variant = intent_paths[unit_id]
			if route is Array and (route as Array).size() > 1:
				CombatPlanningPreview.set_unit_preview_path(
					committed, unit_id, route as Array,
				)
	if unit_id >= 0 and _director != null:
		CombatPlanningPreview.trim_committed_paths_after_slot_promote(
			_director, committed, unit_id, fallback_board, preserve_full_route,
		)
	preview_state.sync_route_geometry_from(committed)
	preview_state.clear_interaction()
	preview_state.preview_board = null
	_sync_intent_live_board()
	_apply_post_commit_hover_truth()


## Harness/test hook: seal explicit slots at current hover and apply preview before commit_from_slots.
func _paint_intent_slots_before_commit(unit_id: int, slots: Dictionary) -> void:
	if _director == null or unit_id < 0 or _is_invalid_dict(slots):
		return
	var hover_cell: Vector2i = (
		_intent_state.hover_coord if _intent_state != null else Vector2i(-999999, -999999)
	)
	var wp: Array[Vector2i] = _HoverPreviewBundle.move_waypoints_from_slots(slots)
	var legal_moves: Array[Vector2i] = []
	if _drag_route_commits_active():
		legal_moves = _snapshot_drag_legal_move_tiles()
	var snapshot_key: String = _intent_snapshot_key_for(
		unit_id, hover_cell, wp, legal_moves, _NO_PREFERRED_APPROACH, -1,
	)
	var paths_snapshot: Dictionary = _preview_paths_snapshot_for_settle(
		unit_id, hover_cell, slots, wp,
	)
	var actions: Array[TimelineAction] = _actions_from_slots(slots)
	var result: Dictionary = _director.preview_actions(unit_id, actions)
	if _is_invalid_dict(result):
		return
	result["settled_preview_paths"] = paths_snapshot.duplicate(true)
	_store_intent_snapshot(
		snapshot_key, slots, unit_id, hover_cell, -1, paths_snapshot, result,
	)
	preview_state.apply_result(result, _director)
	if _planning != null:
		_planning.apply_preview_state(
			preview_state, unit_id, _hover_attack_target_id(),
		)
	_sync_intent_live_board()


func _apply_post_commit_hover_truth() -> void:
	if _planning == null or _director == null or _intent_state == null:
		return
	_planning.restore_committed_display()
	_planning._recompute_hover_ranges_from_inputs()
	var cell: Vector2i = _intent_state.hover_coord
	if _director.selected_unit_id >= 0 and _director.board.is_in_bounds(cell):
		pass
	refresh_mouse_cursor(cell)



func _intent_snapshot_key_for(
	unit_id: int,
	cell: Vector2i,
	waypoints: Array[Vector2i],
	legal_move_tiles: Array[Vector2i],
	preferred_approach: Vector2i,
	face_dir: int,
) -> String:
	var ability_index: int = _director.selected_ability_index if _director != null else -1
	var plan_rev: int = _director.plan_revision if _director != null else 0
	var wp_parts: PackedStringArray = PackedStringArray()
	for wp: Vector2i in waypoints:
		wp_parts.append("%d,%d" % [wp.x, wp.y])
	var awaiting_bit: int = 1 if awaiting_targeting_active() else 0
	var unarmed_walk_bit: int = 1 if (_director != null and _director.selected_ability_index < 0) else 0
	var legal_fp: int = _legal_move_tiles_fingerprint(legal_move_tiles)
	var wp_joined: String = ",".join(wp_parts)
	return "%d|%d|%s|%s|%d|%d|%d|%s|%d|%d" % [
		plan_rev,
		unit_id,
		str(cell),
		str(preferred_approach),
		ability_index,
		face_dir,
		awaiting_bit,
		wp_joined,
		legal_fp,
		unarmed_walk_bit,
	]


func _legal_move_tile_sort_less(a: Vector2i, b: Vector2i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	return a.y < b.y


func _legal_move_tiles_fingerprint(legal_move_tiles: Array[Vector2i]) -> int:
	var legal_sorted: Array[Vector2i] = legal_move_tiles.duplicate()
	legal_sorted.sort_custom(_legal_move_tile_sort_less)
	return hash(legal_sorted)


func _duplicate_commit_slots(slots: Dictionary) -> Dictionary:
	var out: Dictionary = _empty_commit_slots()
	for col: String in ["pre", "action", "post"]:
		var steps: Array = []
		for raw: Variant in slots.get(col, []):
			steps.append(raw)
		out[col] = steps
	if slots.has("invalid"):
		out["invalid"] = slots["invalid"]
	if slots.has("_noop"):
		out["_noop"] = slots["_noop"]
	if slots.has("_preview_validated"):
		out["_preview_validated"] = slots["_preview_validated"]
	return out


func _store_intent_snapshot(
	key: String,
	slots: Dictionary,
	unit_id: int = -1,
	hover_cell: Vector2i = Vector2i(-999999, -999999),
	face_dir: int = -1,
	preview_paths_snapshot: Dictionary = {},
	preview_result: Dictionary = {},
) -> void:
	if _is_invalid_dict(slots) or slots.get("_noop", false) == true:
		_clear_intent_snapshot()
		return
	_intent_snapshot_key = key
	_intent_snapshot_slots = _duplicate_commit_slots(slots)
	_intent_snapshot_unit_id = unit_id
	_intent_snapshot_hover_cell = hover_cell
	_intent_snapshot_valid = true
	_intent_snapshot_plan_revision = _director.plan_revision if _director != null else -1
	var actor: UnitState = _proj_unit(unit_id)
	var move_origin: Vector2i = _phase_entry_stand(actor) if actor != null else Vector2i(-999999, -999999)
	var paths_for_seal: Dictionary = preview_paths_snapshot
	var sealed_board: Variant = preview_result.get("temp_board", null)
	var settled_board: BoardState = sealed_board as BoardState
	var paint_actor: UnitState = actor
	if paint_actor == null and settled_board != null:
		paint_actor = settled_board.get_unit_by_id(unit_id)
	var paint: Dictionary = PlanningPreviewTiles.resolve_paint(
		_director,
		_director.board,
		paint_actor,
		_director.selected_ability_index,
		self,
		hover_cell,
		settled_board,
		paths_for_seal,
		move_origin,
		_intent_snapshot_slots,
	)
	if sealed_board is BoardState:
		paint["preview_board"] = sealed_board
	_settled_hover_preview = _HoverPreviewBundle.seal(
		unit_id,
		hover_cell,
		key,
		_intent_snapshot_slots,
		paths_for_seal,
		face_dir,
		move_origin,
		paint,
	)
	_hover_preview_cache_key = key
	if unit_id >= 0:
		var sealed_route: Variant = paths_for_seal.get(unit_id, null)
		if sealed_route is Array and (sealed_route as Array).size() >= 2:
			CombatPlanningPreview.set_unit_preview_path(
				preview_state, unit_id, sealed_route as Array,
			)
		elif not preview_state.is_painted_leg_sealed(unit_id):
			CombatPlanningPreview.clear_unit_preview_path(preview_state, unit_id)


func _preview_paths_snapshot_for_settle(
	unit_id: int,
	_hover_cell: Vector2i,
	slots: Dictionary,
	waypoints: Array[Vector2i],
) -> Dictionary:
	## Settling unit route comes from commit slots only — never the mutable drag/hover buffer.
	var snapshot: Dictionary = {}
	var settle_actor: UnitState = _proj_unit(unit_id)
	if (
		settle_actor != null
		and preview_state.is_painted_leg_sealed(unit_id)
		and not PlanningRoutePolicy.hover_rewrite_allowed(
			_sealed_leg_hover_mode(settle_actor, _hover_cell),
		)
	):
		var frozen_route: Variant = preview_state.preview_paths.get(unit_id, null)
		if frozen_route is Array and (frozen_route as Array).size() >= 2:
			snapshot[unit_id] = (frozen_route as Array).duplicate()
			return snapshot
	var slot_wps: Array[Vector2i] = _HoverPreviewBundle.move_waypoints_from_slots(slots)
	if slot_wps.is_empty() and waypoints.is_empty():
		if preview_state.is_painted_leg_sealed(unit_id):
			var sealed_route: Variant = preview_state.preview_paths.get(unit_id, null)
			if sealed_route is Array and (sealed_route as Array).size() >= 2:
				snapshot[unit_id] = (sealed_route as Array).duplicate()
		return snapshot
	var move_origin_settle: Vector2i = (
		_settle_phase_entry_stand(settle_actor)
		if settle_actor != null
		else Vector2i(-999999, -999999)
	)
	var built: Array[Vector2i] = []
	if move_origin_settle.x > -900000:
		built.append(move_origin_settle)
	var route_cells: Array[Vector2i] = slot_wps if not slot_wps.is_empty() else waypoints
	for wp_i: int in range(route_cells.size()):
		built.append(route_cells[wp_i])
	if built.size() >= 2:
		snapshot[unit_id] = built
	return snapshot


func _clear_intent_snapshot() -> void:
	_hover_sim_schedule_generation += 1
	_intent_snapshot_valid = false
	_intent_snapshot_key = ""
	_intent_snapshot_slots = {}
	_intent_snapshot_unit_id = -1
	_intent_snapshot_hover_cell = Vector2i(-999999, -999999)
	_settled_hover_preview = null
	_intent_snapshot_plan_revision = -1


func _hover_at_committed_stand_for_range_only(
	p_unit: UnitState,
	cell: Vector2i,
	target_id: int,
) -> bool:
	if p_unit == null or _director == null or target_id >= 0:
		return false
	if not action_range_visible_for_hover():
		return false
	var stand: Vector2i = CombatPlanningPreview.planning_latest_stand_cell(
		_director, _proj(), p_unit.id, null,
	)
	return stand.x > -900000 and cell == stand


func _clear_live_preview_preserve_intent() -> void:
	_hover_preview_cache_key = ""
	clear_hover_route_preview()
	preview_state.clear_interaction()
	preview_state.preview_board = null
	drag_preview_failed = false
	if _planning != null:
		_planning.restore_committed_display()
	_sync_intent_live_board()


func _mouse_local_for_facing() -> Vector2:
	if _map_view == null:
		return Vector2.ZERO
	if _qa_pointer_grid_override:
		return _map_view.grid_to_local(_qa_pointer_grid_cell)
	if _qa_pointer_override:
		return _map_view.grid_to_local(_map_view.screen_to_grid(_qa_pointer_screen_pos))
	return _map_view.get_local_mouse_position()


func set_qa_pointer_screen_pos(screen_pos: Vector2) -> void:
	_qa_pointer_override = true
	_qa_pointer_screen_pos = screen_pos
	_qa_pointer_grid_override = false


func set_qa_pointer_grid_cell(cell: Vector2i) -> void:
	_qa_pointer_grid_override = true
	_qa_pointer_grid_cell = cell
	_qa_pointer_override = false


func clear_qa_pointer_override() -> void:
	_qa_pointer_override = false
	_qa_pointer_screen_pos = Vector2.ZERO
	_qa_pointer_grid_override = false
	_qa_pointer_grid_cell = Vector2i.ZERO


## Hover poll owner: respects QA grid override so live tests can hop tiles without sweep.
func pointer_grid_cell() -> Vector2i:
	return _pointer_grid_cell()


func _pointer_screen_pos() -> Vector2:
	if _qa_pointer_override:
		return _qa_pointer_screen_pos
	if _map_view == null:
		return Vector2.ZERO
	return _map_view.get_viewport().get_mouse_position()


func _pointer_grid_cell() -> Vector2i:
	if _qa_pointer_grid_override:
		return _qa_pointer_grid_cell
	if _map_view == null:
		return Vector2i.ZERO
	return _map_view.screen_to_grid(_pointer_screen_pos())


func _move_origin_for_commit_facing(unit_id: int, move_action: TimelineAction) -> Vector2i:
	if move_action.move_timing == GameEnums.MoveTiming.POST_ACTION:
		return CombatPlanningPreview.committed_plan_action_end_cell(
			_director,
			_proj(),
			unit_id,
		)
	var actor: UnitState = _proj_unit(unit_id)
	if actor != null:
		return _phase_entry_stand(actor)
	var board: BoardState = _director.base_board if _director.base_board != null else _director.board
	var unit: UnitState = board.get_unit_by_id(unit_id) if board != null else null
	return unit.position if unit != null else Vector2i.ZERO


func _apply_facing_to_slots(
	slots: Dictionary,
	local: Vector2,
	cell: Vector2i,
	unit_id: int,
) -> void:
	if unit_id < 0 or _director == null:
		return
	for col: String in ["pre", "post"]:
		for raw: Variant in slots.get(col, []):
			if not raw is TimelineAction:
				continue
			var move_action: TimelineAction = raw as TimelineAction
			if move_action.type != GameEnums.ActionType.MOVE:
				continue
			var origin: Vector2i = _move_origin_for_commit_facing(unit_id, move_action)
			var cells: Array = CombatPlanningPreview.movement_intent_cells(origin, move_action)
			var displaces: bool = (
				cells.size() >= 2
				and cells[0] is Vector2i
				and cells[cells.size() - 1] is Vector2i
				and (cells[0] as Vector2i) != (cells[cells.size() - 1] as Vector2i)
			)
			if displaces:
				## Path-based facing in MovementSystem ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ mouse quadrant must not override travel.
				move_action.face_dir = -1
				continue
			var drop_face: int = _facing_from_drop(local, cell)
			move_action.face_dir = drop_face if drop_face >= 0 else -1


func _play_commit_sfx(slots: Dictionary) -> void:
	if not (slots.get("action", []) as Array).is_empty():
		_play_sfx("ability")
	elif not (slots.get("pre", []) as Array).is_empty() or not (slots.get("post", []) as Array).is_empty():
		_play_sfx("move")


func _on_commit_slots_applied(unit_id: int, slots: Dictionary) -> void:
	if _director == null:
		return
	for column: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(column, []):
			if raw is TimelineAction:
				var action: TimelineAction = raw as TimelineAction
				if action.type != GameEnums.ActionType.ABILITY or action.ability == null:
					continue
				if action.ability.is_universal_wait():
					_director.select_ability(-1)
					return
				if action.awaiting_target:
					_preserve_ability_selection_for_action(unit_id, action)
					_request_planning_selection_refresh()
					return
				var actor := _proj_unit(unit_id)
				if actor == null and _director.board != null:
					actor = _director.board.get_unit_by_id(unit_id)
				if (
					actor != null
					and AbilitySystem.planning_commit_flow(actor, action.ability)
					== GameEnums.PlanningCommitFlow.AWAITING_TARGET
				):
					var saved_route_snapshot := CombatPlanningPreview.new()
					saved_route_snapshot.sync_route_geometry_from(preview_state)
					clear_awaiting_targeting()
					_preserve_ability_selection_for_action(unit_id, action)
					if not saved_route_snapshot.preview_paths.is_empty():
						preview_state.sync_route_geometry_from(saved_route_snapshot)
				elif (
					not AbilitySystem.is_run_ability(action.ability)
					and not AbilitySystem.is_wait_ability(action.ability)
				):
					_director.select_ability(-1)
				return


func _preserve_ability_selection_for_action(unit_id: int, action: TimelineAction) -> void:
	if _director == null or action == null or action.ability == null:
		return
	var actor := _proj_unit(unit_id)
	if actor == null and _director.board != null:
		actor = _director.board.get_unit_by_id(unit_id)
	if actor == null:
		return
	for i: int in range(actor.active_abilities.size()):
		var ability: AbilityData = actor.active_abilities[i] as AbilityData
		if ability == action.ability:
			_director.select_ability(i)
			return


func _preview_from_commit_slots_at_cell(
	unit_id: int,
	cell: Vector2i,
	waypoints: Array[Vector2i] = [],
	legal_move_tiles: Array[Vector2i] = [],
	preferred_approach: Vector2i = _NO_PREFERRED_APPROACH,
	face_dir: int = -1,
) -> Dictionary:
	if _director == null or unit_id < 0:
		_clear_intent_snapshot()
		return {"intents": [], "events": [], "temp_board": BoardState.new(), "invalid": true}
	var effective_face: int = face_dir
	if effective_face < 0 and _map_view != null:
		effective_face = _facing_from_drop(_mouse_local_for_facing(), cell)
	var hover_sim_validate: bool = _planning != null and _planning.qa_static_overlay
	var slots: Dictionary = _final_commit_slots_for_interaction(
		unit_id, cell, waypoints, legal_move_tiles, preferred_approach, -1,
		false,
	)
	_apply_facing_to_slots(slots, _mouse_local_for_facing(), cell, unit_id)
	if hover_sim_validate and not _is_invalid_dict(slots):
		slots = _finalize_commit_slots(slots, unit_id, true)
	if _is_invalid_dict(slots):
		_clear_intent_snapshot()
		return {"intents": [], "events": [], "temp_board": BoardState.new(), "invalid": true}
	var wp_for_key: Array[Vector2i] = _waypoints_for_snapshot_key_from_slots(slots)
	if wp_for_key.is_empty():
		wp_for_key = waypoints
	var snapshot_key: String = _intent_snapshot_key_for(
		unit_id, cell, wp_for_key, legal_move_tiles, preferred_approach, -1,
	)
	var paths_snapshot: Dictionary = _preview_paths_snapshot_for_settle(
		unit_id, cell, slots, wp_for_key,
	)
	var actions: Array[TimelineAction] = _actions_from_slots(slots)
	var result: Dictionary
	if _hover_can_preview_move_without_simulate(slots, cell):
		result = {
			"intents": [],
			"events": [],
			"temp_board": _hover_empty_move_preview_board(slots, cell),
			"actions": actions,
			"intent_preview": true,
		}
	elif _hover_can_preview_occupy_push_without_simulate(slots, cell):
		var occupy_board: BoardState = _hover_occupy_push_preview_board(slots, cell)
		var occupy_source: BoardState = _director.projected_state
		if occupy_source == null:
			occupy_source = _director.board
		result = {
			"intents": [],
			"events": _hover_displacement_events(occupy_source, occupy_board, unit_id),
			"temp_board": occupy_board,
			"actions": actions,
			"intent_preview": true,
		}
	else:
		result = _director.preview_actions(unit_id, actions)
	## The route snapshot is part of the same settled receipt as the simulation board.
	result["settled_preview_paths"] = paths_snapshot.duplicate(true)
	_store_intent_snapshot(
		snapshot_key,
		slots,
		unit_id,
		cell,
		effective_face,
		paths_snapshot,
		result,
	)
	return result


## PERF GUARD (owner-mandate): live F5 empty-tile walk hover uses board clone +
## same commit slots — NOT full Simulator.simulate per cell. QA + commit flush
## still use full preview when required. Do not delete for "SSOT purity".
func _hover_empty_move_preview_board(slots: Dictionary, cell: Vector2i) -> BoardState:
	var source: BoardState = _director.projected_state
	if source == null:
		source = _director.board
	if source == null:
		return BoardState.new()
	var cheap: BoardState = source.clone()
	var move_action: TimelineAction = null
	for col: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(col, []):
			if raw is TimelineAction and (raw as TimelineAction).type == GameEnums.ActionType.MOVE:
				move_action = raw as TimelineAction
				break
		if move_action != null:
			break
	if move_action != null:
		var dummy_events: Array[SimEvent] = []
		MovementSystem.execute_move(cheap, move_action, dummy_events)
	else:
		var uid: int = _director.selected_unit_id
		var u: UnitState = cheap.get_unit_by_id(uid)
		if u != null and u.position != cell:
			GridSystem.set_occupant(cheap, u.position, -1)
			u.position = cell
			GridSystem.set_occupant(cheap, cell, uid)
	return cheap


func _hover_can_preview_move_without_simulate(slots: Dictionary, cell: Vector2i) -> bool:
	if _planning == null or _planning.qa_static_overlay:
		return false
	if awaiting_targeting_active() or dragging:
		return false
	if _director == null or _director.board == null:
		return false
	var occupant: UnitState = _director.board.get_unit_at(cell)
	if occupant != null and occupant.id != _director.selected_unit_id:
		return false
	var has_move: bool = false
	for col: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(col, []):
			if not raw is TimelineAction:
				continue
			var action: TimelineAction = raw as TimelineAction
			if action.type == GameEnums.ActionType.ABILITY:
				return false
			if action.type == GameEnums.ActionType.MOVE:
				has_move = true
	return has_move


func _hover_can_preview_occupy_push_without_simulate(slots: Dictionary, cell: Vector2i) -> bool:
	if _planning == null or _planning.qa_static_overlay:
		return false
	if awaiting_targeting_active() or dragging:
		return false
	if _director == null or _director.board == null:
		return false
	var occupant: UnitState = _director.board.get_unit_at(cell)
	if occupant == null or occupant.id == _director.selected_unit_id or occupant.is_enemy():
		return false
	var actor: UnitState = _proj_unit(_director.selected_unit_id)
	var occupy_ability: AbilityData = null
	for col: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(col, []):
			if not raw is TimelineAction:
				continue
			var action: TimelineAction = raw as TimelineAction
			if action.type == GameEnums.ActionType.MOVE:
				continue
			if action.type != GameEnums.ActionType.ABILITY or action.ability == null:
				return false
			if not AbilitySystem.motion_requires_occupied_target(actor, action.ability):
				return false
			if occupy_ability != null:
				return false
			occupy_ability = action.ability
	if occupy_ability == null or actor == null:
		return false
	var origin: Vector2i = actor.position
	for col: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(col, []):
			if not raw is TimelineAction:
				continue
			var move_action: TimelineAction = raw as TimelineAction
			if move_action.type == GameEnums.ActionType.MOVE:
				origin = move_action.target_coord
	return AbilitySystem.occupied_push_from_origin_valid(
		_proj(), actor, occupy_ability, origin, occupant.position,
	)


func _hover_occupy_push_preview_board(slots: Dictionary, cell: Vector2i) -> BoardState:
	var source: BoardState = _director.projected_state
	if source == null:
		source = _director.board
	if source == null:
		return BoardState.new()
	var cheap: BoardState = source.clone()
	var uid: int = _director.selected_unit_id
	var actor: UnitState = cheap.get_unit_by_id(uid)
	if actor == null:
		return cheap
	for col: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(col, []):
			if not raw is TimelineAction:
				continue
			var move_action: TimelineAction = raw as TimelineAction
			if move_action.type != GameEnums.ActionType.MOVE:
				continue
			var dest: Vector2i = move_action.target_coord
			if dest != actor.position:
				GridSystem.set_occupant(cheap, actor.position, -1)
				actor.position = dest
				GridSystem.set_occupant(cheap, dest, uid)
	var occupant: UnitState = cheap.get_unit_at(cell)
	if occupant == null or occupant.id == uid:
		occupant = cheap.get_unit_at(actor.position)
		if occupant == null or occupant.id == uid:
			return cheap
	var old_pos: Vector2i = occupant.position
	var push_dir: Vector2i = PhysicsSystem.cardinal_from_to(actor.position, old_pos)
	if push_dir == Vector2i.ZERO:
		return cheap
	var behind: Vector2i = old_pos + push_dir
	if (
		not cheap.is_in_bounds(behind)
		or GridSystem.is_wall(cheap, behind)
		or GridSystem.is_occupied(cheap, behind)
	):
		return cheap
	GridSystem.set_occupant(cheap, old_pos, -1)
	occupant.position = behind
	GridSystem.set_occupant(cheap, behind, occupant.id)
	if actor.position != old_pos:
		GridSystem.set_occupant(cheap, actor.position, -1)
	actor.position = old_pos
	GridSystem.set_occupant(cheap, old_pos, uid)
	return cheap


func _hover_displacement_events(
	source: BoardState,
	cheap: BoardState,
	actor_id: int,
) -> Array:
	var events: Array = []
	if source == null or cheap == null:
		return events
	for unit: UnitState in source.units:
		if unit == null:
			continue
		var after: UnitState = cheap.get_unit_by_id(unit.id)
		if after == null or after.position == unit.position:
			continue
		if unit.id == actor_id:
			events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
				"actor": actor_id,
				"from": unit.position,
				"to": after.position,
				"path": [after.position],
			}))
		else:
			events.append(SimEvent.make(GameEnums.SimEventType.UNIT_PUSHED, {
				"unit": unit.id,
				"from": unit.position,
				"to": after.position,
				"pusher": actor_id,
			}))
	return events


func _hover_interaction_cache_key(
	unit_id: int,
	hover_cell: Vector2i,
	attack_target_id: int = -1,
) -> String:
	if _director == null or unit_id < 0:
		return ""
	var resolved_target: int = attack_target_id
	var hover_unit: UnitState = _resolve_hover_unit_at(hover_cell)
	if hover_unit != null and hover_unit.is_enemy():
		resolved_target = hover_unit.id
	elif hover_unit != null and hover_unit.id == unit_id:
		resolved_target = unit_id
	var params: Dictionary = _commit_interaction_params(hover_cell, resolved_target)
	var legal_tiles: Array[Vector2i] = params.legal_move_tiles as Array[Vector2i]
	if legal_tiles.is_empty():
		legal_tiles = _snapshot_drag_legal_move_tiles()
	## Mouse facing does not change walk/sim events; commit still keys facing separately.
	return _intent_snapshot_key_for(
		unit_id,
		params.cell,
		params.waypoints as Array[Vector2i],
		legal_tiles,
		params.preferred,
		-1,
	)



func settle_hover_preview_at_cell(
	unit_id: int,
	cell: Vector2i,
	waypoints: Array[Vector2i] = [],
	legal_move_tiles: Array[Vector2i] = [],
	preferred_approach: Vector2i = _NO_PREFERRED_APPROACH,
	face_dir: int = -1,
) -> Dictionary:
	return _preview_from_commit_slots_at_cell(
		unit_id, cell, waypoints, legal_move_tiles, preferred_approach, face_dir,
	)

func _preview_at_interaction_cell(
	unit_id: int,
	hover_cell: Vector2i,
	_move_coord: Vector2i,
	attack_target_id: int = -1,
	waypoints: Array[Vector2i] = [],
	legal_move_tiles: Array[Vector2i] = [],
) -> Dictionary:
	var params: Dictionary = _commit_interaction_params(hover_cell, attack_target_id)
	var effective_waypoints: Array[Vector2i] = waypoints
	if effective_waypoints.is_empty():
		effective_waypoints = params.waypoints as Array[Vector2i]
	if (
		effective_waypoints.is_empty()
		and _drag_route_commits_active()
	):
		effective_waypoints = _route_waypoints_for_commit()
	elif not waypoints.is_empty() and attack_target_id < 0:
		params.waypoints = waypoints.duplicate()
	var tiles: Array[Vector2i] = legal_move_tiles
	if tiles.is_empty():
		tiles = params.legal_move_tiles
	return _preview_from_commit_slots_at_cell(
		unit_id,
		params.cell,
		effective_waypoints,
		tiles,
		params.preferred,
		int(params.get("face_dir", -1)),
	)


func _prefer_approach_over_trample_move(actor: UnitState, enemy: UnitState) -> bool:
	if _voluntary_walk_planning_active():
		return false
	if actor == null or enemy == null or not enemy.is_enemy():
		return false
	if _director.selected_ability_index < 0:
		return false
	return MovementSystem.has_trample(actor) and _can_move_to(actor, enemy.position)


func _notify_drag_plan_move_committed(_unit_id: int) -> void:
	## Premove walk animation is owned by planning_commit_events ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ do not mark instant.
	pass


func _unit_move_slot_open(unit_id: int, cell: Vector2i = Vector2i(-999999, -999999)) -> bool:
	if _director == null or unit_id < 0:
		return false
	var move_timing: int = _director.get_planning_move_timing(unit_id)
	if cell.x > -900000 and _director.board != null and _director.board.is_in_bounds(cell):
		var actor: UnitState = _proj_unit(unit_id)
		if actor == null:
			actor = _director.board.get_unit_by_id(unit_id)
		if actor != null:
			move_timing = _move_slot_timing_for_commit(unit_id, actor, cell)
	if move_timing == -1:
		return false
	return not _director.unit_has_move_planned_at_timing(unit_id, move_timing)


## Post-move hover/commit ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ action column already spent; never re-pair selected skill.
## Exception: committed action with an open pre-move slot still uses enemy/tile approach
## commit slots (pre + action), not post-move-only placement.
func _planning_post_move_only(actor: UnitState, unit_id: int, cell: Vector2i) -> bool:
	if _director == null or actor == null or unit_id < 0:
		return false
	if _hover_commit_slots_are_post_reposition_walk_only(actor, unit_id, cell):
		return true
	if not (
		_director.get_planning_move_timing(unit_id) == GameEnums.MoveTiming.POST_ACTION
		and _director.unit_action_column_spent_for_movement(unit_id)
	):
		return false
	if _should_replan_premove_approach(unit_id, cell):
		return false
	return true


## Reposition already locked on timeline ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ armed icon is cosmetic; walk hover is move-only.
func _hover_commit_slots_are_post_reposition_walk_only(
	actor: UnitState,
	unit_id: int,
	cell: Vector2i,
) -> bool:
	if actor == null or unit_id < 0 or not _reposition_skill_committed_for_unit(unit_id):
		return false
	var hover_unit: UnitState = _resolve_hover_unit_at(cell)
	if hover_unit != null and hover_unit.id != unit_id:
		return false
	return _is_hover_move_cell(actor, cell)


func _reposition_skill_committed_for_unit(unit_id: int) -> bool:
	if _director == null or unit_id < 0:
		return false
	var committed: TimelineAction = _committed_class_action(unit_id)
	if (
		committed != null
		and committed.ability != null
		and _ability_is_reposition_kind(committed.ability)
	):
		return true
	for action: TimelineAction in _director.plan_pre_move.entries:
		if action.actor_id != unit_id:
			continue
		if action.type != GameEnums.ActionType.ABILITY or action.ability == null:
			continue
		if action.awaiting_target:
			continue
		if _ability_is_reposition_kind(action.ability):
			return true
	return false


func _ability_is_reposition_kind(ability: AbilityData) -> bool:
	if ability == null:
		return false
	if AbilitySystem.ability_has_swap_effect(ability):
		return true
	return ability.is_movement_kind() and ability.is_pre_move_planner()


func _should_replan_premove_approach(unit_id: int, cell: Vector2i) -> bool:
	if _director == null or _director.board == null or unit_id < 0:
		return false
	if _director.unit_has_move_planned_at_timing(unit_id, GameEnums.MoveTiming.PRE_ACTION):
		return false
	if not _director.unit_has_committed_class_action(unit_id):
		return false
	if _director.unit_action_column_spent_for_movement(unit_id):
		var spent_committed: TimelineAction = _committed_class_action(unit_id)
		if (
			spent_committed != null
			and spent_committed.ability != null
			and _ability_is_reposition_kind(spent_committed.ability)
		):
			return false
	var hover_unit: UnitState = _resolve_hover_unit_at(cell)
	if hover_unit != null and hover_unit.is_enemy():
		return true
	if _director.selected_ability_index >= 0:
		return _is_committed_action_approach_cell(unit_id, cell)
	return false


func _committed_class_action(unit_id: int) -> TimelineAction:
	if _director == null:
		return null
	for action: TimelineAction in _director.plan_action.entries:
		if action.actor_id != unit_id:
			continue
		if action.type != GameEnums.ActionType.ABILITY:
			continue
		if action.ability != null and action.ability.kind == GameEnums.AbilityKind.UNIVERSAL_WAIT:
			continue
		return action
	return null


## Clicking the unit already targeted by a locked class action inspects them
## instead of re-committing the same shot.
func _click_inspects_committed_target(actor_id: int, clicked: UnitState) -> bool:
	if clicked == null:
		return false
	var action: TimelineAction = _committed_class_action(actor_id)
	if action == null or action.awaiting_target:
		return false
	if action.target_unit_id == clicked.id:
		return true
	return action.target_coord == clicked.position


func _ability_index_on_unit(actor: UnitState, ability: AbilityData) -> int:
	if actor == null or ability == null:
		return -1
	for i: int in range(actor.active_abilities.size()):
		var entry: AbilityData = actor.active_abilities[i] as AbilityData
		if entry != null and entry.id == ability.id:
			return i
	return -1


func _is_committed_action_approach_cell(unit_id: int, cell: Vector2i) -> bool:
	var committed: TimelineAction = _committed_class_action(unit_id)
	if committed == null or committed.target_unit_id < 0:
		return false
	var enemy: UnitState = _director.board.get_unit_by_id(committed.target_unit_id)
	if enemy == null or not enemy.is_alive() or not enemy.is_enemy():
		return false
	var actor: UnitState = _proj_unit(unit_id)
	if actor == null or committed.ability == null:
		return false
	var ability_index: int = _ability_index_on_unit(actor, committed.ability)
	if ability_index < 0:
		return false
	var approach: Vector2i = _director.preview_approach_tile(
		unit_id, committed.target_unit_id, ability_index, cell,
	)
	return approach == cell


func _move_slot_timing_for_commit(unit_id: int, actor: UnitState, cell: Vector2i) -> int:
	if _should_replan_premove_approach(unit_id, cell):
		return GameEnums.MoveTiming.PRE_ACTION
	return _director.get_planning_move_timing(unit_id)


func _voluntary_walk_economy_open(p_unit: UnitState) -> bool:
	if _awaiting_target_pick_blocks_premove():
		return false
	if _movement_blocked_by_dash():
		return false
	return true


func _basic_move_allowed() -> bool:
	if _director == null or _director.selected_unit_id < 0:
		return _voluntary_walk_economy_open(null)
	var move_actor: UnitState = _proj_unit(_director.selected_unit_id)
	if not _voluntary_walk_economy_open(move_actor):
		return false
	if move_actor == null:
		return false
	if active_movement_planning_step(move_actor) or _voluntary_walk_orbit_phase_open(move_actor):
		return true
	var awaiting: TimelineAction = _awaiting_action_for(move_actor)
	if AbilitySystem.planning_modular_post_move_open(move_actor, awaiting):
		return true
	if selected_phase_action_exhausted(_director.selected_unit_id):
		return false
	return true

func _basic_move_economy_gate(p_unit: UnitState) -> bool:
	if _director == null:
		return _voluntary_walk_economy_open(null)
	if p_unit == null:
		p_unit = _proj_unit(_director.selected_unit_id)
	if not _voluntary_walk_economy_open(p_unit):
		return false
	if p_unit == null:
		return false
	var awaiting: TimelineAction = _awaiting_action_for(p_unit)
	if AbilitySystem.planning_modular_post_move_open(p_unit, awaiting):
		return true
	if selected_phase_action_exhausted(p_unit.id):
		return false
	return true

func _voluntary_walk_postmove_slot_open(p_unit: UnitState) -> bool:
	if _director == null or p_unit == null:
		return false
	if not _voluntary_walk_economy_open(p_unit):
		return false
	if _director.unit_has_move_planned_at_timing(p_unit.id, GameEnums.MoveTiming.POST_ACTION):
		return false
	var phase_kind: int = _director.planning_timeline_phase_kind(p_unit.id)
	if phase_kind == CombatDirector.PlanningTimelinePhaseKind.POSTMOVE_MOVEMENT:
		return true
	var awaiting: TimelineAction = _awaiting_action_for(p_unit)
	if AbilitySystem.planning_modular_post_move_open(p_unit, awaiting):
		return true
	if (
		_director.selected_ability_index < 0
		and _director.unit_has_committed_class_action(p_unit.id)
	):
		var action_end: Vector2i = CombatPlanningPreview.committed_plan_action_end_cell(
			_director, _proj(), p_unit.id,
		)
		if (
			_director.board != null
			and _director.board.is_in_bounds(action_end)
			and _proj_unit(p_unit.id) != null
			and _proj_unit(p_unit.id).position == action_end
		):
			return true
	if not _director._unit_can_post_move(p_unit.id, p_unit):
		return false
	if (
		_director.unit_has_committed_class_action(p_unit.id)
		and _director.unit_action_column_spent_for_movement(p_unit.id)
	):
		return true
	return false


## MOVE_PREVIEW_RULES SSOT ÃƒÅ½Ã¢â‚¬Å“ÃƒÆ’Ã¢â‚¬Â¡ÃƒÆ’Ã‚Â¶ true only while the player is choosing a voluntary walk leg.
func _movement_planning_excluding_autorun(p_unit: UnitState) -> bool:
	if _director == null or p_unit == null:
		return false
	var phase_kind: int = _director.planning_timeline_phase_kind(p_unit.id)
	if phase_kind == CombatDirector.PlanningTimelinePhaseKind.WAIT:
		return false
	if CombatDirector.is_wait_ability_index(_director.selected_ability_index):
		return false
	var ability: AbilityData = _selected_ability_data(p_unit)
	if phase_kind == CombatDirector.PlanningTimelinePhaseKind.SKILL_AWAITING:
		var awaiting_action: TimelineAction = _awaiting_action_for(p_unit)
		var awaiting_ability: AbilityData = ability
		if awaiting_ability == null and awaiting_action != null:
			awaiting_ability = awaiting_action.ability
		if awaiting_ability != null and _is_awaiting_movement_endpoint(p_unit, awaiting_ability):
			return true
		if AbilitySystem.planning_modular_post_move_open(p_unit, awaiting_action):
			return true
		return false
	if phase_kind == CombatDirector.PlanningTimelinePhaseKind.POSTMOVE_MOVEMENT:
		if _director.unit_has_move_planned_at_timing(p_unit.id, GameEnums.MoveTiming.POST_ACTION):
			return false
		return _voluntary_walk_postmove_slot_open(p_unit) and _basic_move_economy_gate(p_unit)
	if phase_kind == CombatDirector.PlanningTimelinePhaseKind.PREMOVE_MOVEMENT:
		if _director.unit_has_move_planned_at_timing(p_unit.id, GameEnums.MoveTiming.PRE_ACTION):
			return false
		if ability != null and _director.selected_ability_index >= 0:
			if _is_awaiting_movement_endpoint(p_unit, ability):
				return true
			if not _awaiting_target_pick_blocks_premove() and _basic_move_economy_gate(p_unit):
				var tile_flags: int = AbilitySystem.active_targeting_flags(p_unit, ability)
				if (tile_flags & GameEnums.TargetingFlags.TILE) != 0:
					return true
			if (
				AbilitySystem.ability_has_movement_effect(ability)
				and not AbilitySystem.motion_requires_occupied_target(p_unit, ability)
			):
				return _basic_move_economy_gate(p_unit)
		return _basic_move_economy_gate(p_unit)
	if phase_kind == CombatDirector.PlanningTimelinePhaseKind.NON_MOVEMENT:
		return _voluntary_walk_postmove_slot_open(p_unit) and _basic_move_economy_gate(p_unit)
	return false


func active_movement_planning_step(p_unit: UnitState) -> bool:
	if _movement_planning_excluding_autorun(p_unit):
		return true
	if _director == null or p_unit == null:
		return false
	var step_ability: AbilityData = _selected_ability_data(p_unit)
	if step_ability == null:
		var awaiting_for_step: TimelineAction = _awaiting_action_for(p_unit)
		if awaiting_for_step != null:
			step_ability = awaiting_for_step.ability
	if step_ability == null:
		return false
	if _director.selected_ability_index < 0:
		return _is_awaiting_movement_endpoint(p_unit, step_ability)
	if auto_run_movement_active(p_unit):
		return _basic_move_economy_gate(p_unit)
	return false

## Sealed leg anchor matches active leg (structural). Per-cell block: painted_move_route_locked(unit, cell).
func _sealed_leg_structurally_locked(p_unit: UnitState) -> bool:
	if dragging or p_unit == null:
		return false
	if not active_movement_planning_step(p_unit):
		return false
	if not preview_state.is_painted_leg_sealed(p_unit.id):
		return false
	var sealed_route: Array = _authoritative_route_for_unit(p_unit.id)
	if sealed_route.size() < 2:
		_clear_frozen_painted_leg(p_unit.id)
		return false
	var leg_anchor: Vector2i = _leg_anchor_for_painted_drag(p_unit)
	if leg_anchor.x <= -900000 or (sealed_route[0] as Vector2i) != leg_anchor:
		_clear_frozen_painted_leg(p_unit.id)
		return false
	return true


func painted_move_route_locked(
	p_unit: UnitState,
	hover_cell: Vector2i = Vector2i(-999999, -999999),
) -> bool:
	if not _sealed_leg_structurally_locked(p_unit):
		return false
	if hover_cell.x > -900000:
		return not PlanningRoutePolicy.hover_rewrite_allowed(
			_sealed_leg_hover_mode(p_unit, hover_cell),
		)
	return true


## PRE / MOVE-module / POST ÃƒÅ½Ã¢â‚¬Å“ÃƒÆ’Ã¢â‚¬Â¡ÃƒÆ’Ã‚Â¶ single voluntary-walk hover paint gate (R6).
func _voluntary_walk_hover_paint_applies(p_unit: UnitState, cell: Vector2i) -> bool:
	if dragging:
		return false
	if p_unit == null or _director == null or not _director.board.is_in_bounds(cell):
		return false
	if (
		preview_state.is_painted_leg_sealed(p_unit.id)
		and not PlanningRoutePolicy.hover_rewrite_allowed(_sealed_leg_hover_mode(p_unit, cell))
	):
		return false
	if _attack_target_id_at_cell(p_unit, cell) >= 0:
		return false
	if (
		_voluntary_walk_corridor_paint_active(p_unit)
		and _is_hover_move_cell(p_unit, cell)
	):
		if live_move_hover_rewrite_applies(p_unit, cell):
			return true
	if painted_move_route_locked(p_unit, cell):
		return false
	var target_enemy_id: int = _attack_target_id_at_cell(p_unit, cell)
	if (
		target_enemy_id < 0
		and _is_hover_move_cell(p_unit, cell)
		and _movement_route_paint_allowed()
		and not _awaiting_target_pick_blocks_premove()
	):
		if _voluntary_walk_corridor_paint_active(p_unit):
			var move_timing: int = _director.get_planning_move_timing(p_unit.id)
			if move_timing < 0 or not _director.unit_has_move_planned_at_timing(p_unit.id, move_timing):
				return true
	if not live_move_hover_rewrite_applies(p_unit, cell):
		return false
	if (
		target_enemy_id < 0
		and not _awaiting_target_pick_blocks_premove()
		and _drag_route_commits_active()
		and _drag_unit_id == p_unit.id
		and _movement_route_paint_allowed()
		and (
			cell == _drag_route_stand_cell()
			or _drag_route.has(cell)
			or _can_move_to(p_unit, cell)
		)
	):
		return true
	if target_enemy_id < 0 and _is_hover_move_cell(p_unit, cell):
		return true
	if (
		_voluntary_walk_corridor_paint_active(p_unit)
		and not _awaiting_target_pick_blocks_premove()
		and _movement_route_paint_allowed()
		and _voluntary_walk_can_paint_cell(p_unit, cell)
	):
		return true
	return false


func _sealed_painted_preview_active(p_unit: UnitState) -> bool:
	if p_unit == null:
		return false
	if not preview_state.is_painted_leg_sealed(p_unit.id):
		return false
	return _authoritative_route_for_unit(p_unit.id).size() >= 2


## True when hover may rewrite preview_paths / live corridor for this cell.
func _sealed_leg_hover_mode(p_unit: UnitState, cell: Vector2i) -> int:
	if p_unit == null or _director == null or not _director.board.is_in_bounds(cell):
		return PlanningRoutePolicy.SealedLegHoverMode.NONE
	var sealed_route: Array = _authoritative_route_for_unit(p_unit.id)
	return PlanningRoutePolicy.sealed_leg_hover_mode(
		preview_state.is_painted_leg_sealed(p_unit.id),
		sealed_route.size(),
		_voluntary_walk_corridor_paint_active(p_unit),
		_hover_extends_walk_geometry(p_unit, cell),
		_attack_target_id_at_cell(p_unit, cell) >= 0,
	)


## Policy owner: restore sealed route when hover is freeze/restore, not corridor-extend.
func _sealed_leg_hover_restore_if_blocked(p_unit: UnitState, cell: Vector2i) -> bool:
	if not _sealed_painted_preview_active(p_unit):
		return false
	# Illegal movement-step hover: no preview (never re-show sealed blue path).
	if active_movement_planning_step(p_unit):
		if not _can_move_to(p_unit, cell) and not _is_hover_move_cell(p_unit, cell):
			return false
	var mode: int = _sealed_leg_hover_mode(p_unit, cell)
	if not PlanningRoutePolicy.should_restore_locked_route(mode):
		return false
	_restore_locked_painted_preview_paths(p_unit.id)
	return true


## Policy geometry only: hover extends walk (not legality). Used by sealed-leg mode; must not call _can_move_to.
func _hover_extends_walk_geometry(p_unit: UnitState, cell: Vector2i) -> bool:
	if p_unit == null or cell == p_unit.position:
		return false
	if _awaiting_target_pick_blocks_premove():
		return false
	if _attack_target_id_at_cell(p_unit, cell) >= 0:
		return false
	if _voluntary_walk_corridor_paint_active(p_unit) and active_movement_planning_step(p_unit):
		if _director != null and _director.board != null and _director.board.is_in_bounds(cell):
			var geom_origin: Vector2i = _proj_origin(p_unit)
			if geom_origin.x > -900000:
				var corridor_geom: Array[Vector2i] = CombatPlanningPreview.voluntary_walk_corridor_waypoints(
					_corridor_board_for_voluntary_walk(p_unit), p_unit, geom_origin, cell, _move_budget(p_unit), _director,
				)
				if not corridor_geom.is_empty() and corridor_geom.back() == cell:
					return true
	if _skill_interaction_active():
		var selected_ability := _selected_ability_data(p_unit)
		if selected_ability != null and _is_awaiting_movement_endpoint(p_unit, selected_ability):
			return active_movement_planning_step(p_unit)
		if _drag_route_commits_active() and _drag_unit_id == p_unit.id:
			if not _drag_route.is_empty() and _drag_route.has(cell):
				var route_idx: int = _drag_route.find(cell)
				if route_idx > 0:
					return true
	if _planning != null and _planning.is_hover_move_tile(cell):
		return true
	if _director != null and _director.board != null:
		var occ: UnitState = _director.board.get_unit_at(cell)
		if occ != null and occ.is_enemy() and MovementSystem.has_trample(p_unit):
			return active_movement_planning_step(p_unit)
	return false


## True when hover may rewrite preview_paths / live corridor for this cell.
func live_move_hover_rewrite_applies(p_unit: UnitState, cell: Vector2i) -> bool:
	if not active_movement_planning_step(p_unit):
		return false
	if not preview_state.is_painted_leg_sealed(p_unit.id):
		return true
	return PlanningRoutePolicy.hover_rewrite_allowed(_sealed_leg_hover_mode(p_unit, cell))


## Live hover corridor ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ preview_state only; non-move steps return frozen slice without committed bleed.
## Painted corridor waypoints for blue move-tile extension ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ preview_paths SSOT, not _drag_route peek.
func painted_corridor_waypoints_for_blue_tiles(unit_id: int) -> Array[Vector2i]:
	if not _drag_route_commits_active() or _drag_unit_id != unit_id:
		return []
	var route: Array[Vector2i] = display_move_route_cells(unit_id)
	if route.size() < 2:
		return []
	return route.slice(1)


func movement_hover_route_display_applies(actor: UnitState, ability: AbilityData) -> bool:
	if actor == null:
		return false
	if ability == null:
		return active_movement_planning_step(actor)
	if AbilitySystem.planning_allows_paired_premove(ability):
		return true
	if (
		AbilitySystem.ability_uses_direct_relocation(ability, actor)
		and _is_awaiting_movement_endpoint(actor, ability)
	):
		return true
	return false

func display_move_route_cells(unit_id: int) -> Array[Vector2i]:
	if _director == null or unit_id < 0:
		return []
	var actor: UnitState = _proj_unit(unit_id)
	if actor == null and _director.board != null:
		actor = _director.board.get_unit_by_id(unit_id)
	if actor == null:
		return []
	if unit_id == _director.selected_unit_id:
		var sealed_route: Array = _authoritative_route_for_unit(unit_id)
		if sealed_route.size() >= 2:
			return CombatPlanningPreview.frozen_move_route_cells_from_array(sealed_route)
	var movement_step: bool = active_movement_planning_step(actor)
	if movement_step:
		var route_ability: AbilityData = _selected_ability_data(actor)
		if not movement_hover_route_display_applies(actor, route_ability):
			return []
	if unit_id == _director.selected_unit_id:
		return []
	return CombatPlanningPreview.display_route_cells_from_preview(
		unit_id,
		preview_state,
		_director,
		_proj(),
		movement_step,
	)
func clear_hover_route_preview() -> void:
	var preserved_paths: Dictionary = {}
	for uid: Variant in preview_state.painted_leg_sealed.keys():
		var unit_id: int = int(uid)
		if not preview_state.is_painted_leg_sealed(unit_id):
			continue
		var path: Array = _authoritative_route_for_unit(unit_id)
		if path.size() < 2:
			var stored: Variant = preview_state.preview_paths.get(unit_id, null)
			if stored is Array:
				path = stored as Array
		if path.size() >= 2:
			preserved_paths[unit_id] = path.duplicate()
	preview_state.clear_route_geometry()
	for unit_id: Variant in preserved_paths.keys():
		var path: Array = preserved_paths[unit_id] as Array
		var uid: int = int(unit_id)
		if path.size() >= 2:
			CombatPlanningPreview.set_unit_preview_path(preview_state, uid, path)
			if preview_state.is_painted_leg_sealed(uid):
				preview_state.seal_painted_leg(uid)
	if _planning != null:
		_planning.queue_redraw()


func committed_route_preview() -> CombatPlanningPreview:
	if _planning != null:
		return _planning.get_committed_preview()
	return preview_state


func preview_board_for_display() -> BoardState:
	if is_live_preview_active() and preview_state.preview_board != null:
		return preview_state.preview_board
	if _planning != null:
		var committed: CombatPlanningPreview = _planning.get_committed_preview()
		if committed.preview_board != null:
			return committed.preview_board
	return _proj()


func display_committed_move_route_leg(
	unit_id: int,
	timing: int,
	visual_cell: Vector2i = CombatPlanningPreview.INVALID_VISUAL_CELL,
) -> Array:
	if _director == null:
		return []
	return CombatPlanningPreview.committed_move_route_leg(
		unit_id,
		committed_route_preview(),
		_director,
		_proj(),
		timing,
		visual_cell,
	)


func display_frozen_route_cells(unit_id: int) -> Array[Vector2i]:
	if _director == null or unit_id < 0:
		return []
	return CombatPlanningPreview.frozen_move_route_cells(
		unit_id, committed_route_preview(),
	)


func display_committed_action_route_cells(
	unit_id: int,
	action: TimelineAction,
	start_pos: Vector2i,
) -> Array:
	if _director == null or action == null:
		return []
	return CombatPlanningPreview.display_committed_action_route_cells(
		unit_id,
		committed_route_preview(),
		_director,
		_proj(),
		action,
		start_pos,
	)


func display_units_with_route_preview() -> Array[int]:
	var ids: Dictionary = {}
	var committed: CombatPlanningPreview = committed_route_preview()
	if committed != null:
		for uid: Variant in committed.preview_paths.keys():
			ids[int(uid)] = true
	if is_live_preview_active():
		var receipt: PlanningHoverPreview = _current_hover_receipt()
		if receipt != null and receipt.unit_id >= 0:
			ids[receipt.unit_id] = true
	var out: Array[int] = []
	for uid: Variant in ids.keys():
		out.append(int(uid))
	return out


func preview_push_draw_sources() -> Array[CombatPlanningPreview]:
	var sources: Array[CombatPlanningPreview] = []
	if is_live_preview_active() and preview_state.preview_board != null:
		sources.append(preview_state)
	var committed: CombatPlanningPreview = committed_route_preview()
	if committed != null and committed.preview_board != null:
		if sources.is_empty() or sources[0] != committed:
			sources.append(committed)
	return sources


func route_preview_for_push_checks() -> CombatPlanningPreview:
	return committed_route_preview()


## Predicted stand at hover for next-phase range field (two-range tile model).
func predicted_stand_at_hover(unit_id: int, hover_coord: Vector2i) -> Vector2i:
	if _director == null or unit_id < 0:
		return Vector2i(-999999, -999999)
	var actor: UnitState = _proj_unit(unit_id)
	if actor == null and _director.board != null:
		actor = _director.board.get_unit_by_id(unit_id)
	if actor == null:
		return Vector2i(-999999, -999999)
	if is_live_preview_active() and preview_state.preview_board != null:
		var live_unit: UnitState = preview_state.preview_board.get_unit_by_id(unit_id)
		if live_unit != null:
			return live_unit.position
	if active_movement_planning_step(actor):
		if _director.board.is_in_bounds(hover_coord) and _is_hover_move_cell(actor, hover_coord):
			return hover_coord
		return _phase_entry_stand(actor)
	return action_range_intent_stand_cell(unit_id)


## Walk-only hover orbit ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ no yellow blast, no next-phase aim field.
func is_walk_only_hover_move(unit: UnitState, hover_coord: Vector2i) -> bool:
	if unit == null or _director == null or not _director.board.is_in_bounds(hover_coord):
		return false
	var actor: UnitState = _proj_unit(unit.id)
	if actor == null:
		actor = unit
	return active_movement_planning_step(actor) and _is_hover_move_cell(actor, hover_coord)


func _typed_route_cells(route: Array) -> Array[Vector2i]:
	var typed: Array[Vector2i] = []
	for tile: Variant in route:
		if tile is Vector2i:
			typed.append(tile as Vector2i)
	return typed


func _discard_stale_drag_route_for_leg(p_unit: UnitState) -> void:
	if p_unit == null or _drag_route.is_empty():
		return
	var origin: Vector2i = _phase_entry_stand(p_unit)
	if origin.x <= -900000:
		return
	if (_drag_route[0] as Vector2i) != origin:
		_drag_route.clear()
		_drag_unit_id = -1
		_drag_last_free = Vector2i(-999999, -999999)


## Premove, postmove, and armed MOVE module legs share the same painted-route input.
func _movement_route_paint_allowed() -> bool:
	if _basic_move_allowed():
		return true
	if _director == null:
		return false
	var unit_id: int = _drag_unit_id if dragging else _director.selected_unit_id
	if unit_id < 0:
		return false
	var actor: UnitState = _proj_unit(unit_id)
	if actor == null:
		actor = _director.board.get_unit_by_id(unit_id) if _director.board != null else null
	if actor == null:
		return false
	var ability: AbilityData = _selected_ability_data(actor)
	return _is_awaiting_movement_endpoint(actor, ability)


func _movement_blocked_by_dash() -> bool:
	if _director.selected_unit_id < 0:
		return false
	var unit := _proj_unit(_director.selected_unit_id)
	if unit == null:
		unit = _director.board.get_unit_by_id(_director.selected_unit_id) if _director.board != null else null
	return unit != null and AbilitySystem.ability_blocks_basic_movement(_selected_ability_data(unit))


func _drag_max_steps(unit: UnitState) -> int:
	var ability: AbilityData = _selected_ability_data(unit)
	if ability != null and _is_awaiting_movement_endpoint(unit, ability):
		return AbilitySystem.active_motion_max_range(unit, ability)
	var max_steps: int = _move_budget(unit)
	if _skill_commit_path_active():
		if ability != null and AbilitySystem.ability_has_movement_effect(ability):
			if AbilitySystem.motion_requires_occupied_target(unit, ability):
				pass
			elif _awaiting_flow_selected(unit, ability) and not awaiting_targeting_active():
				pass
			else:
				max_steps = AbilitySystem.active_range_tiles(unit, ability)
	return max_steps


func _route_has_left_origin_ring(move_origin: Vector2i) -> bool:
	for c: Vector2i in _drag_route:
		if GridSystem.manhattan(move_origin, c) > 1:
			return true
	return false


## Basic premove drag orbit must not corridor-repath a sealed painted leg.
func _basic_painted_drag_orbit_guard_active() -> bool:
	if not dragging:
		return false
	if _director == null or _director.selected_ability_index >= 0:
		return false
	var actor: UnitState = _proj_unit(_drag_unit_id)
	if actor == null or not _painted_drag_route_matches_leg(actor) or _drag_route.size() < 2:
		return false
	if _voluntary_walk_orbit_phase_open(actor):
		return false
	var move_origin: Vector2i = _phase_entry_stand(actor)
	var cell: Vector2i = _pointer_grid_cell()
	var last: Vector2i = _drag_route[_drag_route.size() - 1]
	if _drag_route.find(cell) >= 0:
		return false
	# Multi-step premove paint sealed ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ orbit may backtrack only, not extend the tail.
	if move_origin.x > -900000 and _route_has_left_origin_ring(move_origin):
		return true
	if GridSystem.manhattan(last, cell) == 1:
		return false
	return true


func _painted_premove_orbit_sealed() -> bool:
	if not dragging:
		return false
	var actor: UnitState = _proj_unit(_drag_unit_id)
	if actor == null or _voluntary_walk_orbit_phase_open(actor):
		return false
	if not _painted_drag_route_matches_leg(actor) or _drag_route.size() < 2:
		return false
	var move_origin: Vector2i = _phase_entry_stand(actor)
	return move_origin.x > -900000 and _route_has_left_origin_ring(move_origin)


func _extend_drag_route(cell: Vector2i) -> void:
	if _drag_route.is_empty():
		return
	var idx := _drag_route.find(cell)
	if idx >= 0:
		if idx < _drag_route.size() - 1 and not _painted_premove_orbit_sealed():
			_drag_route = _drag_route.slice(0, idx + 1)
			_finish_drag_route_extension()
			return
	var last: Vector2i = _drag_route[_drag_route.size() - 1]
	var board: BoardState = _proj()
	var unit := _proj_unit(_drag_unit_id)
	if unit == null:
		return
	if _basic_painted_drag_orbit_guard_active():
		return
	var move_origin: Vector2i = _phase_entry_stand(unit)
	# Orbit-hover around stand: hop between origin-adjacent tiles without corridor repath.
	# Keep this when a skill is armed / auto-run is on ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ circling is not a painted path.
	# Once the route has left the origin ring (manhattan > 1), keep corridor paint
	# so U-shaped selection paths (K4 east-then-south) still extend.
	if (
		not dragging
		and last != cell
		and GridSystem.manhattan(move_origin, cell) == 1
		and not _route_has_left_origin_ring(move_origin)
	):
		_drag_route = [move_origin]
		_append_route_tile(cell)
		_finish_drag_route_extension()
		return
	var ability: AbilityData = _route_pathfinding_ability(unit)
	var budget: int = _drag_max_steps(unit)
	var move_cost: int = MovementSystem.move_cost_for(unit)
	var mt: GameEnums.MovementType = (
		unit.definition.movement_type
		if unit.definition != null
		else GameEnums.MovementType.WALK
	)
	if GridSystem.manhattan(last, cell) != 1:
		var corridor: Array[Vector2i] = MovementSystem.drag_corridor_path(
			board, last, cell, budget, mt, move_cost, unit, ability,
		)
		for c: Vector2i in corridor:
			_append_route_tile(c)
		if not _drag_route.is_empty() and _drag_route.back() != cell:
			_repath_drag_route_to(cell, unit, board, mt, budget, move_cost, ability)
		_finish_drag_route_extension()
		return
	_append_route_tile(cell)
	if _drag_route.back() != cell:
		## Adjacent past budget: repath within budget instead of silently ignoring.
		_repath_drag_route_to(cell, unit, board, mt, budget, move_cost, ability)
	_finish_drag_route_extension()
	if dragging:
		_drag_preview_cache_key = 0


func _repath_drag_route_to(
	cell: Vector2i,
	unit: UnitState,
	board: BoardState,
	mt: GameEnums.MovementType,
	budget: int,
	move_cost: int,
	ability: AbilityData,
) -> void:
	var move_origin: Vector2i = _phase_entry_stand(unit)
	var path: Array[Vector2i] = MovementSystem.drag_corridor_path(
		board, move_origin, cell, budget, mt, move_cost, unit, ability,
	)
	if path.is_empty() or path.back() != cell:
		return
	_drag_route = [move_origin]
	_drag_route.append_array(path)
	_trim_drag_route_forbidden()


func _append_route_tile(coord: Vector2i) -> void:
	var board: BoardState = _proj()
	var unit := _proj_unit(_drag_unit_id)
	if unit == null or _drag_route.is_empty():
		return
	var idx := _drag_route.find(coord)
	if idx >= 0:
		if idx < _drag_route.size() - 1:
			_drag_route = _drag_route.slice(0, idx + 1)
		return
	## size includes start; waypoints = size - 1. Cap at budget steps.
	if _drag_route.size() - 1 >= _drag_max_steps(unit):
		return
	var last: Vector2i = _drag_route[_drag_route.size() - 1]
	var ability: AbilityData = _route_pathfinding_ability(unit)
	if GridSystem.manhattan(last, coord) != 1 or not MovementSystem.is_walkable_for(board, coord, unit, ability):
		return
	if _director != null:
		var trial: Array = _drag_route.duplicate()
		trial.append(coord)
		var forbidden: Dictionary = CombatPlanningPreview.prior_leg_forbidden_cells(
			_director, _drag_unit_id, _drag_route[0] as Vector2i,
		)
		if CombatPlanningPreview.route_touches_forbidden(trial, forbidden):
			return
	_drag_route.append(coord)


## Drag buffer staging only — preview/settle is _sync_drag_route_stand → voluntary-walk hover refresh.
func _finish_drag_route_extension() -> void:
	if _drag_route.size() <= 1:
		_sync_drag_route_stand()
		return
	var unit: UnitState = _proj_unit(_drag_unit_id)
	if unit == null:
		_sync_drag_route_stand()
		return
	var board: BoardState = _proj()
	var origin: Vector2i = _drag_route[0]
	var final_cell: Vector2i = _drag_route.back()
	var selected_ability: AbilityData = _selected_ability_data(unit)
	if (
		selected_ability != null
		and _is_awaiting_movement_endpoint(unit, selected_ability)
		and not AbilitySystem.planning_is_valid_awaiting_endpoint(
			origin, final_cell, selected_ability, unit, board,
		)
	):
		_drag_route = [origin]
		_sync_drag_route_stand()
		return
	if dragging and _voluntary_walk_drag_trim_active(unit):
		_trim_drag_route_forbidden()
	_sync_drag_route_stand()


func _trim_drag_route_forbidden() -> void:
	if _drag_route.size() <= 1 or _director == null:
		return
	var origin: Vector2i = _drag_route[0]
	var forbidden: Dictionary = CombatPlanningPreview.prior_leg_forbidden_cells(
		_director, _drag_unit_id, origin,
	)
	if forbidden.is_empty():
		return
	while (
		_drag_route.size() > 1
		and CombatPlanningPreview.route_touches_forbidden(_drag_route, forbidden)
	):
		_drag_route.pop_back()


func _sync_drag_route_stand() -> void:
	if _drag_route.size() >= 2:
		_drag_last_free = _drag_route[_drag_route.size() - 1]
	elif not _drag_route.is_empty():
		_drag_last_free = _drag_route[0]
	if _drag_unit_id < 0 or _director == null:
		return
	if not dragging and not _drag_route_commits_active():
		return
	if _voluntary_walk_orbit_overrides_drag_paint(_drag_unit_id):
		var actor: UnitState = _proj_unit(_drag_unit_id)
		var cell: Vector2i = _pointer_grid_cell()
		if actor != null and _director.board != null and _director.board.is_in_bounds(cell):
			_refresh_voluntary_walk_hover_preview(actor, cell)
		return
	var hover_cell: Vector2i = _pointer_grid_cell()
	var drag_actor: UnitState = _proj_unit(_drag_unit_id)
	if _drag_route.size() >= 2:
		_apply_voluntary_walk_drag_preview(_drag_unit_id, false)
	elif _drag_route.size() == 1:
		_apply_voluntary_walk_drag_preview(_drag_unit_id, false)
		if (
			drag_actor != null
			and _voluntary_walk_orbit_phase_open(drag_actor)
			and _director.board != null
			and _director.board.is_in_bounds(hover_cell)
		):
			_refresh_voluntary_walk_hover_preview(drag_actor, hover_cell)
	else:
		_clear_stale_painted_preview_route(_drag_unit_id)


## Voluntary-walk per-hover corridor (POST landing orbit) ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ not sealed/painted drag legs or MOVE-module paint.
## Voluntary-walk per-hover corridor paint (PRE/POST orbit + MOVE-module awaiting).
func _basic_walk_pathfinding_active(p_unit: UnitState) -> bool:
	if p_unit == null or _director == null:
		return false
	if preview_state.is_painted_leg_sealed(p_unit.id):
		return true
	if _director.selected_ability_index < 0:
		return true
	var pk: int = _director.planning_timeline_phase_kind(p_unit.id)
	return (
		pk == CombatDirector.PlanningTimelinePhaseKind.PREMOVE_MOVEMENT
		or pk == CombatDirector.PlanningTimelinePhaseKind.POSTMOVE_MOVEMENT
	)


func _voluntary_walk_drag_trim_active(p_unit: UnitState) -> bool:
	if not dragging or p_unit == null or _director == null:
		return false
	if not active_movement_planning_step(p_unit):
		return false
	return _painted_drag_route_matches_leg(p_unit)


func _voluntary_walk_corridor_waypoints_to_cell(actor: UnitState, cell: Vector2i) -> Array[Vector2i]:
	if actor == null or _director == null or not _director.board.is_in_bounds(cell):
		return []
	if not _voluntary_walk_corridor_paint_active(actor):
		return []
	return _corridor_waypoints_to_cell(actor, cell)


func _voluntary_walk_corridor_reaches_cell(actor: UnitState, cell: Vector2i) -> bool:
	var corridor: Array[Vector2i] = _voluntary_walk_corridor_waypoints_to_cell(actor, cell)
	return not corridor.is_empty() and corridor.back() == cell


func _voluntary_walk_can_paint_cell(p_unit: UnitState, cell: Vector2i) -> bool:
	if p_unit == null:
		return false
	if _can_move_to(p_unit, cell):
		return true
	return _voluntary_walk_corridor_reaches_cell(p_unit, cell)


func _selection_corridor_route_staging_active(p_unit: UnitState) -> bool:
	if dragging or p_unit == null:
		return false
	if not _voluntary_walk_corridor_paint_active(p_unit):
		return false
	if not _movement_route_paint_allowed():
		return false
	if _drag_route.size() < 2 or _drag_unit_id != p_unit.id:
		return _voluntary_walk_hover_paint_applies(p_unit, _active_hover_cell())
	return true


func _voluntary_walk_corridor_paint_active(p_unit: UnitState = null) -> bool:
	if _director == null:
		return false
	if p_unit == null:
		if _director.selected_unit_id < 0:
			return false
		p_unit = _proj_unit(_director.selected_unit_id)
	if p_unit == null:
		return false
	if preview_state.is_painted_leg_sealed(p_unit.id):
		return false
	if _authoritative_route_for_unit(p_unit.id).size() >= 2:
		return false
	if dragging:
		if not _basic_move_economy_gate(p_unit):
			return false
		if _director.selected_ability_index < 0:
			return active_movement_planning_step(p_unit)
		var drag_ability: AbilityData = _selected_ability_data(p_unit)
		if drag_ability == null:
			return false
		if _is_awaiting_movement_endpoint(p_unit, drag_ability):
			return _drag_route.size() >= 2
		if (
			AbilitySystem.ability_has_movement_effect(drag_ability)
			and not AbilitySystem.motion_requires_occupied_target(p_unit, drag_ability)
		):
			return true
		return auto_run_movement_active(p_unit)
	var walk_phase: int = _director.planning_timeline_phase_kind(p_unit.id)
	if (
		walk_phase != CombatDirector.PlanningTimelinePhaseKind.PREMOVE_MOVEMENT
		and walk_phase != CombatDirector.PlanningTimelinePhaseKind.POSTMOVE_MOVEMENT
		and walk_phase != CombatDirector.PlanningTimelinePhaseKind.SKILL_AWAITING
	):
		return false
	var ability: AbilityData = _selected_ability_data(p_unit)
	if ability != null and _is_awaiting_movement_endpoint(p_unit, ability):
		if (
			AbilitySystem.ability_has_movement_effect(ability)
			and not AbilitySystem.motion_requires_occupied_target(p_unit, ability)
		):
			return true
		if not dragging and _voluntary_walk_economy_open(p_unit):
			return true
		return dragging and _drag_route.size() >= 2
	if (
		ability != null
		and AbilitySystem.ability_has_movement_effect(ability)
		and not AbilitySystem.motion_requires_occupied_target(p_unit, ability)
		and not _is_awaiting_movement_endpoint(p_unit, ability)
	):
		return _basic_move_economy_gate(p_unit)
	if ability != null and AbilitySystem.ability_uses_direct_relocation(ability, p_unit):
		return false
	if not _basic_move_economy_gate(p_unit):
		return false
	return true

func _voluntary_walk_orbit_phase_open(p_unit: UnitState) -> bool:
	if p_unit == null or _director == null:
		return false
	if not active_movement_planning_step(p_unit):
		return false
	if not _voluntary_walk_economy_open(p_unit):
		return false
	var timing: int = _director.get_planning_move_timing(p_unit.id)
	if timing < 0:
		return false
	return not _director.unit_has_move_planned_at_timing(p_unit.id, timing)

func _voluntary_walk_orbit_overrides_drag_paint(unit_id: int) -> bool:
	if not dragging or unit_id < 0:
		return false
	var actor: UnitState = _proj_unit(unit_id)
	if actor == null:
		return false
	if _drag_route.size() >= 2:
		var leg_origin: Vector2i = _phase_entry_stand(actor)
		if leg_origin.x > -900000 and _route_has_left_origin_ring(leg_origin):
			return false
	return _voluntary_walk_orbit_phase_open(actor)


## Movement-step hover path is authoritative — sim merge must not stomp it.

## Single painted-route ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã¢â‚¬ËœÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â¥ preview_paths writer (drag buffer ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã¢â‚¬ËœÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â¥ route truth).
func _apply_voluntary_walk_drag_preview(unit_id: int, require_leg_match: bool) -> void:
	## Drag buffer staging may precede this call; preview write is voluntary-walk refresh only (R6).
	var actor: UnitState = _proj_unit(unit_id) if unit_id >= 0 else null
	if actor == null or _director == null:
		return
	if require_leg_match and not _painted_drag_route_matches_leg(actor):
		return
	var cell: Vector2i = _active_hover_cell()
	if not _voluntary_walk_preview_refresh_needed(actor, cell):
		return
	_refresh_voluntary_walk_hover_preview(actor, cell)


## R6 ÃƒÅ½Ã¢â‚¬Å“ÃƒÆ’Ã¢â‚¬Â¡ÃƒÆ’Ã‚Â¶ single gate for hover + drag voluntary-walk preview refresh.
func _voluntary_walk_preview_refresh_needed(p_unit: UnitState, cell: Vector2i) -> bool:
	if p_unit == null or _director == null:
		return false
	if dragging and _drag_unit_id == p_unit.id:
		if _drag_route.size() >= 2 and active_movement_planning_step(p_unit):
			return true
		if _voluntary_walk_corridor_paint_active(p_unit):
			return _movement_route_paint_allowed() or _drag_route.size() >= 2
	return _voluntary_walk_hover_paint_applies(p_unit, cell)

## PRE / ACTION (move module) / POST — one corridor preview owner for all move slots.
func _refresh_voluntary_walk_hover_preview(p_unit: UnitState, cell: Vector2i) -> void:
	if _hover_settle_fresh_at(p_unit.id, cell):
		_apply_assembler_prefix_preview_on_painted_route(p_unit, cell)
		_refresh_click_target_highlight()
		return
	if painted_move_route_locked(p_unit, cell):
		_refresh_click_target_highlight()
		return
	var settle_waypoints: Array[Vector2i] = _hover_paint_waypoints_for_cell(p_unit, cell)
	if active_movement_planning_step(p_unit):
		if (
			not _voluntary_walk_corridor_paint_active(p_unit)
			and _authoritative_route_for_unit(p_unit.id).size() >= 2
		):
			var orbit_path: Array[Vector2i] = _assemble_voluntary_walk_preview_path(
				p_unit.id, p_unit, cell, settle_waypoints,
			)
			if orbit_path.size() >= 2:
				CombatPlanningPreview.set_unit_preview_path(
					preview_state, p_unit.id, orbit_path,
				)
				_sync_movement_hover_paths_to_overlay(p_unit.id)
				_refresh_click_target_highlight()
				return
	if (
		active_movement_planning_step(p_unit)
		and not _voluntary_walk_can_paint_cell(p_unit, cell)
		and not _is_hover_move_cell(p_unit, cell)
	):
		_clear_stale_painted_preview_route(p_unit.id)
		_refresh_click_target_highlight()
		return
	if _voluntary_walk_corridor_paint_active(p_unit):
		var probe_path: Array[Vector2i] = []
		if (
			_drag_route_commits_active()
			and _drag_unit_id == p_unit.id
			and _drag_route.size() >= 2
			and not _voluntary_walk_orbit_overrides_drag_paint(p_unit.id)
		):
			for drag_probe_i: int in range(_drag_route.size()):
				probe_path.append(_drag_route[drag_probe_i] as Vector2i)
		else:
			probe_path = _assemble_voluntary_walk_preview_path(
				p_unit.id, p_unit, cell, settle_waypoints,
			)
		if probe_path.size() < 2:
			var existing_paint: Array = _authoritative_route_for_unit(p_unit.id)
			if existing_paint.size() >= 2:
				var paint_tail: Vector2i = existing_paint[existing_paint.size() - 1] as Vector2i
				if (
					paint_tail != cell
					and GridSystem.manhattan(paint_tail, cell) == 1
					and _voluntary_walk_hover_extends_preview_path(p_unit, cell)
				):
					probe_path = []
					for paint_step: Variant in existing_paint:
						probe_path.append(paint_step as Vector2i)
					probe_path.append(cell)
			if probe_path.size() < 2:
				_clear_stale_painted_preview_route(p_unit.id)
				_refresh_click_target_highlight()
				return
		var leg_origin: Vector2i = _phase_entry_stand(p_unit)
		var leg_wps: Array[Vector2i] = CombatPlanningPreview.destination_cells_from_route(
			probe_path, leg_origin, cell,
		)
		if not leg_wps.is_empty():
			settle_waypoints = leg_wps
	elif (
		_drag_route_commits_active()
		and _drag_unit_id == p_unit.id
		and _drag_route.size() >= 2
	):
		settle_waypoints = _route_waypoints()
	if active_movement_planning_step(p_unit):
		var walk_res: Dictionary = _preview_at_interaction_cell(
			p_unit.id, cell, cell, -1, settle_waypoints, _snapshot_drag_legal_move_tiles(),
		)
		if not _is_invalid_dict(walk_res):
			_apply_settled_preview_result(walk_res)
		_refresh_click_target_highlight()
		return
	_refresh_live_interaction_preview(_director.selected_unit_id, cell, -1, settle_waypoints)
	_refresh_click_target_highlight()


func _apply_assembler_prefix_preview_on_painted_route(p_unit: UnitState, cell: Vector2i) -> void:
	if p_unit == null or _director == null:
		return
	if _authoritative_route_for_unit(p_unit.id).size() < 2:
		return
	var prefix_path: Array[Vector2i] = _assemble_voluntary_walk_preview_path(
		p_unit.id, p_unit, cell, [],
	)
	if prefix_path.size() < 2:
		return
	CombatPlanningPreview.set_unit_preview_path(
		preview_state, p_unit.id, prefix_path,
	)
	_sync_movement_hover_paths_to_overlay(p_unit.id)


func _sync_movement_hover_paths_to_overlay(unit_id: int) -> void:
	if _planning != null:
		_planning.apply_preview_state(
			preview_state, unit_id, _hover_attack_target_id(),
		)


func _voluntary_walk_hover_extends_preview_path(actor: UnitState, hover_cell: Vector2i) -> bool:
	if actor == null or _director == null or not _director.board.is_in_bounds(hover_cell):
		return false
	if painted_move_route_locked(actor, hover_cell):
		return false
	if not active_movement_planning_step(actor):
		return false
	if _attack_target_id_at_cell(actor, hover_cell) >= 0:
		return false
	return live_move_hover_rewrite_applies(actor, hover_cell)


## PRE / MOVE module / POST ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ one standÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã¢â‚¬ËœÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â¥hover path assembler (forbidden trim + adjacent hop).
func _assemble_voluntary_walk_preview_path(
	unit_id: int,
	actor: UnitState,
	hover_cell: Vector2i,
	waypoints: Array[Vector2i],
) -> Array[Vector2i]:
	if actor == null or _director == null:
		return []
	if painted_move_route_locked(actor, hover_cell):
		var locked_route: Array = _authoritative_route_for_unit(unit_id)
		for locked_idx: int in range(locked_route.size()):
			var locked_step: Vector2i = locked_route[locked_idx] as Vector2i
			if locked_step == hover_cell and locked_idx > 0:
				var locked_prefix: Array[Vector2i] = []
				for prefix_idx: int in range(locked_idx + 1):
					locked_prefix.append(locked_route[prefix_idx] as Vector2i)
				return locked_prefix
		var frozen: Variant = preview_state.preview_paths.get(unit_id, null)
		if frozen is Array and (frozen as Array).size() >= 2:
			return (frozen as Array).duplicate()
		return []
	var origin: Vector2i = _leg_anchor_for_painted_drag(actor)
	if origin.x <= -900000:
		return []
	if (
		preview_state.is_painted_leg_sealed(unit_id)
		and GridSystem.manhattan(origin, hover_cell) == 1
		and not _route_has_left_origin_ring(origin)
	):
		return [origin, hover_cell]
	var forbidden: Dictionary = CombatPlanningPreview.prior_leg_forbidden_cells(
		_director, unit_id, origin,
	)
	var painted_leg: Array = []
	if preview_state.is_painted_leg_sealed(unit_id):
		var sealed_paint: Variant = preview_state.preview_paths.get(unit_id, null)
		if sealed_paint is Array and (sealed_paint as Array).size() >= 2:
			painted_leg = (sealed_paint as Array).duplicate()
	if painted_leg.size() < 2:
		painted_leg = _authoritative_route_for_unit(unit_id)
	if painted_leg.size() >= 2:
		for route_idx: int in range(painted_leg.size()):
			var on_route: Vector2i = painted_leg[route_idx] as Vector2i
			if on_route == hover_cell and route_idx > 0:
				var route_prefix: Array[Vector2i] = []
				for prefix_idx: int in range(route_idx + 1):
					route_prefix.append(painted_leg[prefix_idx] as Vector2i)
				return route_prefix
		var painted_tail: Vector2i = painted_leg[painted_leg.size() - 1] as Vector2i
		if (
			painted_tail != hover_cell
			and GridSystem.manhattan(painted_tail, hover_cell) == 1
			and _voluntary_walk_hover_extends_preview_path(actor, hover_cell)
		):
			var extended_paint: Array[Vector2i] = []
			for painted_step: Variant in painted_leg:
				extended_paint.append(painted_step as Vector2i)
			extended_paint.append(hover_cell)
			if not CombatPlanningPreview.route_touches_forbidden(extended_paint, forbidden):
				return extended_paint
	if (
		forbidden.has(hover_cell)
		and hover_cell != origin
		and not _can_move_to(actor, hover_cell)
	):
		return []
	if waypoints.is_empty():
		if (
			GridSystem.manhattan(origin, hover_cell) == 1
			and _voluntary_walk_hover_extends_preview_path(actor, hover_cell)
		):
			return [origin, hover_cell]
		if (
			_voluntary_walk_corridor_paint_active(actor)
			or _hover_orbit_extends_painted_receipt(actor, hover_cell)
		):
			var corridor_fill: Array[Vector2i] = _corridor_waypoints_to_cell(actor, hover_cell)


			if not corridor_fill.is_empty() and corridor_fill.back() == hover_cell:
				var filled: Array[Vector2i] = [origin]
				for wp_fill: Vector2i in corridor_fill:
					filled.append(wp_fill)
				if not CombatPlanningPreview.route_touches_forbidden(filled, forbidden):
					return filled
		if not _can_move_to(actor, hover_cell) and not _is_hover_move_cell(actor, hover_cell):
			return []
		return []
	var path: Array[Vector2i] = [origin]
	for wp: Vector2i in waypoints:
		path.append(wp)
	if CombatPlanningPreview.route_touches_forbidden(path, forbidden):
		return []
	var tail: Vector2i = path[path.size() - 1] as Vector2i
	if (
		tail != hover_cell
		and GridSystem.manhattan(tail, hover_cell) == 1
		and _voluntary_walk_hover_extends_preview_path(actor, hover_cell)
	):
		path.append(hover_cell)
	return path


## Shared hover/drag paint: premove, postmove, and MOVE module legs use one corridor owner.
func _hover_paint_waypoints_for_cell(actor: UnitState, cell: Vector2i) -> Array[Vector2i]:
	if actor == null or _director == null or not _director.board.is_in_bounds(cell):
		return []
	if painted_move_route_locked(actor, cell):
		return []
	if (
		_painted_drag_route_drives_live_preview()
		and _drag_unit_id == actor.id
		and _movement_route_paint_allowed()
	):
		var route_idx: int = _drag_route.find(cell)
		if route_idx > 0:
			var partial: Array[Vector2i] = []
			for i: int in range(1, route_idx + 1):
				partial.append(_drag_route[i] as Vector2i)
			return _normalize_adjacent_single_step_waypoints(
				partial, _drag_route[0] as Vector2i,
			)
		if not _drag_route.is_empty() and cell == _drag_route.back():
			return _route_waypoints()
		if (
			cell == _drag_route_stand_cell()
			or _drag_route.has(cell)
			or _voluntary_walk_can_paint_cell(actor, cell)
		):
			var painted: Array[Vector2i] = _route_waypoints()
			if not painted.is_empty():
				return painted
	if _voluntary_walk_corridor_paint_active(actor):
		var corridor_wps: Array[Vector2i] = _corridor_waypoints_to_cell(actor, cell)
		if not corridor_wps.is_empty() and corridor_wps.back() == cell:
			return corridor_wps
	if _hover_orbit_extends_painted_receipt(actor, cell):
		var receipt_corridor: Array[Vector2i] = _corridor_waypoints_to_cell(actor, cell)
		if not receipt_corridor.is_empty() and receipt_corridor.back() == cell:
			return receipt_corridor

	if _can_move_to(actor, cell):
		return _corridor_waypoints_to_cell(actor, cell)
	return []


func _drag_route_stand_cell() -> Vector2i:
	if _drag_route.size() >= 2:
		return _drag_route[_drag_route.size() - 1]
	if _director != null and _director.board != null and _director.board.is_in_bounds(_drag_last_free):
		return _drag_last_free
	if _drag_unit_id >= 0 and _director != null and _director.board != null:
		var unit := _director.board.get_unit_by_id(_drag_unit_id)
		if unit != null:
			return unit.position
	return Vector2i.ZERO


func _route_waypoints() -> Array[Vector2i]:
	var waypoints: Array[Vector2i] = []
	if _drag_route.size() >= 2:
		for i: int in range(1, _drag_route.size()):
			waypoints.append(_drag_route[i])
	return _normalize_adjacent_single_step_waypoints(waypoints, _drag_route[0] if not _drag_route.is_empty() else Vector2i.ZERO)


func _route_waypoints_for_commit(dest_cell: Vector2i = Vector2i(-999999, -999999)) -> Array[Vector2i]:
	var unit_id: int = _drag_unit_id if (_drag_route_commits_active() or dragging) else (
		_director.selected_unit_id if _director != null else -1
	)
	var actor: UnitState = _proj_unit(unit_id) if unit_id >= 0 else null
	if actor == null:
		return []
	if dest_cell.x <= -900000:
		if _drag_route.size() >= 2:
			dest_cell = _drag_route.back() as Vector2i
		else:
			var painted_path: Array = _authoritative_route_for_unit(unit_id)
			if painted_path.size() >= 2 and painted_path.back() is Vector2i:
				dest_cell = painted_path.back() as Vector2i
			elif (
				_intent_state != null
				and _director != null
				and _director.board.is_in_bounds(_intent_state.hover_coord)
			):
				dest_cell = _intent_state.hover_coord
	if dest_cell.x <= -900000:
		return []
	return _resolve_commit_move_waypoints(unit_id, actor, dest_cell)


## Commit MOVE waypoints ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ leg from latest stand to destination only (never full stale preview tail).
func _resolve_commit_move_waypoints(unit_id: int, actor: UnitState, cell: Vector2i) -> Array[Vector2i]:
	if actor == null or _director == null:
		return []
	var move_origin: Vector2i = _settle_phase_entry_stand(actor)
	if cell == move_origin:
		return []
	if _drag_route.size() >= 2:
		var drag_wps: Array[Vector2i] = _route_waypoints()
		if not drag_wps.is_empty() and drag_wps.back() == cell:
			return drag_wps
	var painted_path: Array = _authoritative_route_for_unit(unit_id)
	if painted_path.size() >= 2:
		var leg: Array[Vector2i] = CombatPlanningPreview.destination_cells_from_route(
			painted_path, move_origin, cell,
		)
		if not leg.is_empty() and leg.back() == cell:
			return leg
	var ability: AbilityData = _selected_ability_data(actor)
	if ability != null:
		var skill_wps: Array[Vector2i] = _hover_walk_waypoints_for_skill(actor, cell, ability)
		if not skill_wps.is_empty() and skill_wps.back() == cell:
			return skill_wps
	var corridor_wps: Array[Vector2i] = _hover_paint_waypoints_for_cell(actor, cell)
	if not corridor_wps.is_empty() and corridor_wps.back() == cell:
		return corridor_wps
	return []


## Global corridor paint: premove and MOVE module legs share MovementSystem + forbidden trim.
## Voluntary-walk corridor prefers live preview_board so premove and MOVE-module share occupancy.
func _corridor_board_for_voluntary_walk(actor: UnitState) -> BoardState:
	if actor == null or not _voluntary_walk_corridor_paint_active(actor):
		return _proj()
	if preview_state.preview_board != null:
		return preview_state.preview_board
	return _proj()

func _hover_orbit_extends_painted_receipt(p_unit: UnitState, cell: Vector2i) -> bool:
	var auth_route: Array = _authoritative_route_for_unit(p_unit.id)
	if auth_route.size() < 2:
		return false
	for step: Variant in auth_route:
		if step is Vector2i and (step as Vector2i) == cell:
			return false
	return _hover_extends_walk_geometry(p_unit, cell)


func _corridor_waypoints_to_cell(actor: UnitState, cell: Vector2i) -> Array[Vector2i]:
	if actor == null or _director == null:
		return []
	if not _voluntary_walk_corridor_paint_active(actor):
		if _painted_drag_route_drives_live_preview() and _drag_unit_id == actor.id:
			var painted: Array[Vector2i] = _route_waypoints()
			if not painted.is_empty() and painted.back() == cell:
				return painted
	var auth_route: Array = _authoritative_route_for_unit(actor.id)
	var orbit_extend_from_receipt: bool = _hover_orbit_extends_painted_receipt(actor, cell)
	var origin: Vector2i = (
		_leg_anchor_for_painted_drag(actor)
		if auth_route.size() >= 2
		else _settle_phase_entry_stand(actor)
	)
	if origin.x <= -900000:
		return []
	var sealed_mode: int = _sealed_leg_hover_mode(actor, cell)
	var corridor_budget: int = _drag_max_steps(actor)
	var corridor_ability: AbilityData = _route_pathfinding_ability(actor, cell)
	if preview_state.is_painted_leg_sealed(actor.id):
		corridor_budget = _move_budget(actor)
		corridor_ability = null
	elif orbit_extend_from_receipt:
		corridor_budget = _move_budget(actor)
		corridor_ability = null
	elif (
		_voluntary_walk_corridor_paint_active(actor)
		or PlanningRoutePolicy.use_basic_walk_corridor_legality(sealed_mode)
	):
		corridor_budget = _move_budget(actor)
		corridor_ability = null
	if (
		PlanningRoutePolicy.use_basic_walk_corridor_legality(sealed_mode)
		or orbit_extend_from_receipt
	):
		if preview_state.preview_board == null:
			_sync_preview_board_to_sealed_landing(actor.id)
	var corridor_board: BoardState = _corridor_board_for_voluntary_walk(actor)
	return CombatPlanningPreview.voluntary_walk_corridor_waypoints(
		corridor_board,
		actor,
		origin,
		cell,
		corridor_budget,
		_director,
	)


func _normalize_adjacent_single_step_waypoints(
	waypoints: Array[Vector2i],
	origin: Vector2i,
) -> Array[Vector2i]:
	if waypoints.size() == 1 and GridSystem.manhattan(origin, waypoints[0]) == 1:
		return []
	return waypoints


## True when the hover cell is a live skill aim (TILE/AOE in range, or dash endpoint).
## Restore must not wipe this ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ HP forecast and targeting arrows both need the live sim.
func is_skill_aim_hover_at(cell: Vector2i) -> bool:
	if _director == null or _director.board == null or _director.selected_unit_id < 0:
		return false
	if not _director.board.is_in_bounds(cell):
		return false
	var actor: UnitState = _proj_unit(_director.selected_unit_id)
	if actor == null:
		actor = _director.board.get_unit_by_id(_director.selected_unit_id)
	if actor == null:
		return false
	var ability: AbilityData = _selected_ability_data(actor)
	if ability == null:
		return false
	if awaiting_targeting_active() and _is_awaiting_movement_endpoint(actor, ability):
		return AbilitySystem.planning_is_valid_awaiting_endpoint(
			_phase_entry_stand(actor), cell, ability, actor, _proj(),
		)
	return _is_in_range_tile_skill_aim(actor, cell)


func _is_in_range_tile_skill_aim(actor: UnitState, cell: Vector2i) -> bool:
	return _is_armed_tile_skill_aim_cell(actor, cell, _selected_ability_data(actor))


func awaiting_targeting_active() -> bool:
	if _director == null or _director.selected_unit_id < 0:
		return false
	return _director.find_awaiting_action(_director.selected_unit_id) != null


func clear_awaiting_targeting() -> void:
	if _director == null or _director.selected_unit_id < 0:
		return
	if _director.find_awaiting_action(_director.selected_unit_id) == null:
		return
	_director.clear_awaiting_action(_director.selected_unit_id)
	_clear_hover_drag_route()
	if _planning != null:
		_planning._invalidate_hover_cache()
	_invalidate_planning_hover_cache()
	_restore_hover_preview()
	_request_planning_selection_refresh()


## Occupancy for painted hover/drag. Unarmed premove uses basic walk; armed awaiting uses the skill.
## Overlay/legal-tile read API ÃƒÅ½Ã¢â‚¬Å“ÃƒÆ’Ã¢â‚¬Â¡ÃƒÆ’Ã‚Â¶ delegates to corridor pathfinding owner.
func route_pathfinding_ability_for_hover(
	unit: UnitState,
	hover_cell: Vector2i = Vector2i(-999999, -999999),
) -> AbilityData:
	return _route_pathfinding_ability(unit, hover_cell)


func _route_pathfinding_ability(
	unit: UnitState,
	hover_cell: Vector2i = Vector2i(-999999, -999999),
) -> AbilityData:
	if unit == null or _director == null:
		return null
	if preview_state.is_painted_leg_sealed(unit.id):
		return null
	if hover_cell.x > -900000:
		if PlanningRoutePolicy.use_basic_walk_corridor_legality(
			_sealed_leg_hover_mode(unit, hover_cell),
		):
			return null
	if _basic_walk_pathfinding_active(unit):
		return null
	var ability := _selected_ability_data(unit)
	if ability == null:
		return null
	if AbilitySystem.motion_requires_occupied_target(unit, ability):
		return null
	if awaiting_targeting_active():
		if _is_awaiting_movement_endpoint(unit, ability):
			return ability
		return null
	if _is_awaiting_movement_endpoint(unit, ability):
		return ability
	return null


## Walk/dash tile pathfinding only. Same gate as painted routes: unarmed = basic walk.
func _walk_pathfinding_ability(unit: UnitState) -> AbilityData:
	return _route_pathfinding_ability(unit)


func _awaiting_flow_selected(actor: UnitState, ability: AbilityData) -> bool:
	return (
		ability != null
		and actor != null
		and AbilitySystem.planning_commit_flow(actor, ability)
		== GameEnums.PlanningCommitFlow.AWAITING_TARGET
	)


## True while an armed awaiting skill is choosing a movement/dash tile endpoint.
func _enemy_adjacent_to_attack_tile(
	actor: UnitState,
	ability: AbilityData,
	cell: Vector2i,
) -> int:
	var board: BoardState = _proj()
	if board == null or actor == null or ability == null:
		return -1
	for dir: Vector2i in GridSystem.DIRECTIONS:
		var adj: Vector2i = cell + dir
		if not board.is_in_bounds(adj):
			continue
		var unit: UnitState = board.get_unit_at(adj)
		if (
			unit != null
			and unit.is_enemy()
			and unit.is_alive()
			and AbilitySystem.target_passes_mode(actor, ability, unit)
		):
			return unit.id
	return -1


## TILE / TARGET_PICK awaiting is skill aim. Walk hover, walk preview, and walk
## commit stay off until that pick finishes (or the awaiting action is cleared).
func _awaiting_target_pick_blocks_premove() -> bool:
	if not awaiting_targeting_active() or _director == null:
		return false
	var actor := _proj_unit(_director.selected_unit_id)
	if actor == null:
		return false
	var awaiting: TimelineAction = _director.find_awaiting_action(actor.id)
	var ability: AbilityData = awaiting.ability if awaiting != null else _selected_ability_data(actor)
	if ability == null:
		return false
	var module_index: int = 0
	if awaiting != null and awaiting.awaiting_module_index >= 0:
		module_index = awaiting.awaiting_module_index
	return (
		AbilitySystem.planning_awaiting_phase_for_module(actor, ability, module_index)
		== GameEnums.PlanningAwaitingPhase.TARGET_PICK
	)


func _is_awaiting_movement_endpoint(actor: UnitState, ability: AbilityData) -> bool:
	var armed_action := (
		_director.find_awaiting_action(actor.id)
		if _director != null and actor != null
		else null
	)
	if not awaiting_targeting_active() and armed_action == null:
		return false
	if not _awaiting_flow_selected(actor, ability) and armed_action == null:
		return false
	var module_index: int = 0
	if armed_action != null and armed_action.awaiting_module_index >= 0:
		module_index = armed_action.awaiting_module_index
	return (
		AbilitySystem.planning_awaiting_phase_for_module(actor, ability, module_index)
		== GameEnums.PlanningAwaitingPhase.MOVEMENT_ENDPOINT
	)


func _movement_skill_commits_tile_endpoint(
	actor: UnitState,
	ability: AbilityData,
	cell: Vector2i,
) -> bool:
	if not _is_awaiting_movement_endpoint(actor, ability):
		return false
	if actor == null or ability == null:
		return false
	if (
		AbilitySystem.active_targeting_flags(actor, ability)
		& GameEnums.TargetingFlags.TILE
	) == 0:
		return false
	if not AbilitySystem.ability_has_movement_effect(ability, actor):
		return false
	return AbilitySystem.planning_is_valid_awaiting_endpoint(
		_phase_entry_stand(actor), cell, ability, actor, _proj(),
	)


func _cell_on_dash_line_from_stand(
	actor: UnitState,
	ability: AbilityData,
	cell: Vector2i,
) -> bool:
	if actor == null or ability == null:
		return false
	var origin: Vector2i = _phase_entry_stand(actor)
	if cell == origin:
		return true
	var delta: Vector2i = cell - origin
	if delta.x != 0 and delta.y != 0:
		return false
	return AbilitySystem.planning_target_is_in_range(
		_proj(), actor, ability, origin, cell,
	)


func _tile_target_movement_skill_commits_at_cell(
	actor: UnitState,
	ability: AbilityData,
	cell: Vector2i,
	painted_waypoints: Array[Vector2i] = [],
) -> bool:
	if actor == null or ability == null:
		return false
	if (
		AbilitySystem.active_targeting_flags(actor, ability)
		& GameEnums.TargetingFlags.TILE
	) == 0:
		return false
	if not AbilitySystem.ability_has_movement_effect(ability, actor):
		return false
	if _is_awaiting_movement_endpoint(actor, ability):
		return _movement_skill_commits_tile_endpoint(actor, ability, cell)
	## auto_use_skill_after_move is the spend flag. With it off, hover is walk/run
	## while the TILE movement skill stays armed (K4 detour). Awaiting aim still commits.
	if not auto_use_skill_after_move:
		return false
	var motion: AbilityModule = AbilitySystem.active_motion_module(actor, ability)
	if motion != null and motion.primary_type == GameEnums.EffectType.DASH:
		## Painted move waypoints (selection/drag route) are pre-move intent ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ not dash pickup.
		if (
			not painted_waypoints.is_empty()
			and not _is_awaiting_movement_endpoint(actor, ability)
			and not _drag_route_commits_active()
		):
			return false
		if (
			_drag_route_commits_active()
			and _drag_unit_id == actor.id
			and _route_has_left_origin_ring(_phase_entry_stand(actor))
		):
			return false
		if (
			_director != null
			and _director.auto_run
			and AbilitySystem.movement_requires_run(_proj(), actor, cell, [])
		):
			return false
		if (
			_drag_route_commits_active()
			and _drag_unit_id == actor.id
			and not _cell_on_dash_line_from_stand(actor, ability, cell)
		):
			return false
		return _dash_tile_endpoint_one_click_commit(actor, ability, cell)
	if (
		motion != null
		and (
			GameEnums.is_adjacent_destination(motion.primary_type)
			or GameEnums.is_behind_destination(motion.primary_type)
			or GameEnums.is_toward_destination(motion.primary_type)
			or GameEnums.is_jump_motion(motion.primary_type)
			or GameEnums.is_teleport_motion(motion.primary_type)
		)
	):
		if not _in_ability_range_of_coord(actor, cell):
			return false
		return AbilitySystem.motion_landing_legal(_proj(), actor, ability, cell)
	if not _in_ability_range_of_coord(actor, cell):
		return false
	if _reposition_skill_committed_for_unit(actor.id) and not awaiting_targeting_active():
		return false
	if ability.is_pre_move_planner():
		return true
	if AbilitySystem.planning_commit_flow(actor, ability) == GameEnums.PlanningCommitFlow.IMMEDIATE:
		return true
	## DASH primary + TILE: one-click dash endpoint (straight-line legality from DASH primary).
	if _dash_tile_endpoint_one_click_commit(actor, ability, cell):
		return true
	return false


func _dash_tile_endpoint_one_click_commit(
	actor: UnitState,
	ability: AbilityData,
	cell: Vector2i,
) -> bool:
	if actor == null or ability == null:
		return false
	var motion: AbilityModule = AbilitySystem.active_motion_module(actor, ability)
	if motion == null or motion.primary_type != GameEnums.EffectType.DASH:
		return false
	if (
		AbilitySystem.active_targeting_flags(actor, ability)
		& GameEnums.TargetingFlags.TILE
	) == 0:
		return false
	if _proj() == null:
		return false
	var hover_unit: UnitState = _resolve_hover_unit_at(cell)
	if hover_unit == null or not hover_unit.is_alive() or not hover_unit.is_enemy():
		return false
	if not _cell_on_dash_line_from_stand(actor, ability, cell):
		return false
	if (
		_drag_route_commits_active()
		and _drag_unit_id == actor.id
		and dragging
	):
		return false
	if (
		_director != null
		and _director.auto_run
		and AbilitySystem.movement_requires_run(_proj(), actor, cell, [])
	):
		return false
	return AbilitySystem.motion_landing_legal(_proj(), actor, ability, cell)


func _drag_had_movement() -> bool:
	if _drag_route.is_empty():
		return false
	return _drag_last_free != _drag_route[0]


func _clear_drag_preview_cache() -> void:
	_drag_preview_cache_key = 0
	_drag_preview_cache = {}
	_drag_last_cursor_cell = Vector2i(-999999, -999999)
	_drag_last_sprite_cell = Vector2i(-999999, -999999)


func _drag_preview_cache_key_for(
	cell: Vector2i,
	attack_target_id: int,
	waypoints: Array[Vector2i],
) -> int:
	var key: int = cell.x
	key = key * 1000 + cell.y
	key = key * 1000 + _drag_last_free.x
	key = key * 1000 + _drag_last_free.y
	key = key * 10000 + (attack_target_id + 1)
	key = key * 10 + (1 if (_director != null and _director.selected_ability_index < 0) else 0)
	key = key * 100 + _director.selected_ability_index if _director != null else key
	for wp: Vector2i in waypoints:
		key = key * 1000 + wp.x
		key = key * 1000 + wp.y
	return key


func _self_tile_allows_wait(actor: UnitState, ability_index: int) -> bool:
	if _director == null or not _is_planning() or actor == null:
		return false
	if selected_phase_action_exhausted(actor.id):
		return false
	if CombatDirector.is_wait_ability_index(ability_index):
		return true
	if ability_index >= 0:
		var ability: AbilityData = _selected_ability_data(actor)
		if ability != null and AbilitySystem.can_target_self(actor, ability):
			return false
	return true


func _append_wait_action_slot(slots: Dictionary, unit_id: int, actor: UnitState) -> void:
	var wait_ability: AbilityData = DataLibrary.get_universal_wait()
	if wait_ability == null:
		slots["invalid"] = true
		return
	slots["action"].append(
		TimelineAction.make_ability(unit_id, wait_ability, actor.position, unit_id),
	)


func _build_self_tile_commit_slots(
	slots: Dictionary,
	actor: UnitState,
	unit_id: int,
	ability_index: int,
	ability: AbilityData,
	face_dir: int,
) -> Dictionary:
	if CombatDirector.is_wait_ability_index(ability_index) and ability != null:
		slots["action"].append(
			TimelineAction.make_ability(unit_id, ability, actor.position, unit_id),
		)
		return slots
	if ability != null and AbilitySystem.planning_arms_on_self_tile(actor, ability):
		if _director.find_awaiting_action(unit_id) != null:
			slots["_noop"] = true
			return slots
		slots["action"].append(
			TimelineAction.make_ability_awaiting(unit_id, ability, actor.position),
		)
		return slots
	if (
		ability != null
		and AbilitySystem.can_target_self(actor, ability)
		and not AbilitySystem.is_run_ability(ability)
	):
		slots["action"].append(
			TimelineAction.make_ability(unit_id, ability, actor.position, unit_id),
		)
		return slots
	if face_dir >= 0 and dragging:
		slots["action"].append(TimelineAction.make_face(unit_id, face_dir))
		return slots
	if _self_tile_allows_wait(actor, ability_index):
		_append_wait_action_slot(slots, unit_id, actor)
		return slots
	slots["invalid"] = "Invalid self-targeting action."
	return slots


func _selected_ability_data(unit: UnitState) -> AbilityData:
	if _director == null or unit == null:
		return null
	return CombatDirector.resolve_selected_ability(unit, _director.selected_ability_index)


func run_mode_selected(unit: UnitState = null) -> bool:
	return _run_mode_selected(unit)


func auto_run_movement_active(unit: UnitState = null) -> bool:
	if _director == null or not _director.auto_run:
		return false
	var guard_actor: UnitState = _proj_unit(_director.selected_unit_id)
	if (
		guard_actor != null
		and awaiting_targeting_active()
		and _movement_planning_excluding_autorun(guard_actor)
	):
		return false
	var actor := unit if unit != null else _proj_unit(_director.selected_unit_id)
	if actor == null and _director.board != null:
		actor = _director.board.get_unit_by_id(_director.selected_unit_id)
	if actor == null:
		return false
	var selected: AbilityData = _selected_ability_data(actor)
	if selected != null and not selected.is_universal_run():
		## Swap and other paired pre-move skills still use the walk column. Auto Run
		## stays on whenever that walk (or a later post-move) can spend AP.
		if (
			selected.is_pre_move_planner()
			and not AbilitySystem.planning_allows_paired_premove(selected)
		):
			return false
		var dest_motion: AbilityModule = AbilitySystem.active_motion_module(actor, selected)
		if (
			dest_motion != null
			and (
				GameEnums.is_jump_motion(dest_motion.primary_type)
				or GameEnums.is_teleport_motion(dest_motion.primary_type)
			)
		):
			return false
	return AbilitySystem.can_afford_run(actor)


## Armed TILE skills: red range stays on projected stand until commit/clear (not hover ghost).
## Where red action-range tiles anchor ÃƒÅ½Ã¢â‚¬Å“ÃƒÆ’Ã¢â‚¬Â¡ÃƒÆ’Ã‚Â¶ delegates to phase-entry stand (R1/R3).
## Exceptions (documented): module handoff prior stand; committed move target;
## armed-tile range lock; live_path terminus only during active movement step (not locked red).
func action_range_intent_stand_cell(unit_id: int = -1) -> Vector2i:
	if unit_id < 0 and _director != null:
		unit_id = _director.selected_unit_id
	return settled_action_range_stand_cell(unit_id)

## Locked move intent (timeline or painted drag) used for action-range economy ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ not hover stand.
## Red tiles show only when the selected skill is legal from the canonical settled stand.
func action_range_visible_for_hover() -> bool:
	if dragging:
		return false
	if _director == null or _director.selected_unit_id < 0 or _director.board == null:
		return false
	var unit_id: int = _director.selected_unit_id
	var actor: UnitState = _proj_unit(unit_id)
	if actor == null:
		actor = _director.board.get_unit_by_id(unit_id)
	if actor == null:
		return false
	var ability: AbilityData = _selected_ability_data(actor)
	if ability == null or AbilitySystem.is_run_ability(ability) or AbilitySystem.is_wait_ability(ability):
		return false
	var board: BoardState = _proj()
	var auto_run_move: bool = auto_run_movement_active(actor)
	if unit_move_requires_run(unit_id):
		auto_run_move = true
	var stand: Vector2i = settled_action_range_stand_cell(unit_id)
	var economy_board: BoardState = board
	var economy_actor: UnitState = actor
	if awaiting_targeting_active():
		return AbilitySystem.can_plan(economy_actor, ability, economy_board)
	var premove_cell: Vector2i = stand
	var intent_dest: Vector2i = move_intent_destination(unit_id)
	if (
		economy_board.is_in_bounds(intent_dest)
		and intent_dest != economy_actor.position
	):
		premove_cell = intent_dest
	elif auto_run_move:
		var hover_cell: Vector2i = get_hover_tile_for_ui()
		if (
			economy_board.is_in_bounds(hover_cell)
			and hover_cell != economy_actor.position
			and AbilitySystem.movement_requires_run(economy_board, economy_actor, hover_cell, [])
		):
			premove_cell = hover_cell
	return AbilitySystem.can_show_planning_action_range_after_premove(
		economy_board, economy_actor, ability, premove_cell, auto_run_move,
	)


## True when this unit's current planning intent (drag / live path / committed move) needs Run.
func unit_move_requires_run(unit_id: int) -> bool:
	if _director == null or unit_id < 0:
		return false
	var board: BoardState = _proj()
	var actor: UnitState = board.get_unit_by_id(unit_id) if board != null else null
	if actor == null:
		return false
	if dragging and _drag_unit_id == unit_id and not _drag_route.is_empty():
		var dest: Vector2i = _drag_route[_drag_route.size() - 1]
		return AbilitySystem.movement_requires_run(board, actor, dest, _route_waypoints())
	for step: TimelineAction in _director.get_unit_plan_steps(unit_id):
		if step != null and step.type == GameEnums.ActionType.MOVE and step.uses_run:
			return true
	if unit_id == _director.selected_unit_id:
		var live_path: Array = _authoritative_route_for_unit(unit_id)
		if live_path.size() >= 2:
			var live_waypoints: Array[Vector2i] = []
			for i: int in range(1, live_path.size()):
				live_waypoints.append(live_path[i] as Vector2i)
			return AbilitySystem.movement_requires_run(
				board, actor, live_path[live_path.size() - 1] as Vector2i, live_waypoints,
			)
		var hover: Vector2i = get_hover_tile_for_ui()
		if board.is_in_bounds(hover) and hover != actor.position and _is_hover_move_cell(actor, hover):
			return AbilitySystem.movement_requires_run(board, actor, hover, [])
	return false


## True when this unit's current planning intent (hover slots or committed plan) spends Steady Aim.
func unit_intent_uses_steady_aim(unit_id: int) -> bool:
	if _director == null or unit_id < 0:
		return false
	if (
		unit_id == _director.selected_unit_id
		and _intent_snapshot_valid
		and not _is_invalid_dict(_intent_snapshot_slots)
	):
		for col: String in ["pre", "action", "post"]:
			for raw: Variant in _intent_snapshot_slots.get(col, []):
				if raw is TimelineAction and (raw as TimelineAction).uses_steady_aim:
					return true
	for step: TimelineAction in _director.get_unit_plan_steps(unit_id):
		if step != null and step.uses_steady_aim:
			return true
	return false


## End tile for the current move intent (live path, drag route, or hover).
func move_intent_destination(unit_id: int) -> Vector2i:
	if _director == null or unit_id < 0:
		return Vector2i(-999, -999)
	var live_path: Array = _authoritative_route_for_unit(unit_id)
	if live_path.size() >= 2:
		return live_path[live_path.size() - 1] as Vector2i
	if _drag_route_commits_active() and _drag_unit_id == unit_id and not _drag_route.is_empty():
		return _drag_route_stand_cell()
	if unit_id == _director.selected_unit_id:
		var hover: Vector2i = get_hover_tile_for_ui()
		if _director.board != null and _director.board.is_in_bounds(hover):
			var actor: UnitState = _proj_unit(unit_id)
			if actor != null and _is_hover_move_cell(actor, hover):
				return hover
	return Vector2i(-999, -999)


## Single AP read for planning UI ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ delegates to AbilitySystem.planning_display_ap_left.
func planning_display_ap_left(unit_id: int) -> int:
	if _director == null or unit_id < 0:
		return -1
	var committed: UnitState = _proj_unit(unit_id)
	if committed == null and _director.board != null:
		committed = _director.board.get_unit_by_id(unit_id)
	if committed == null:
		return -1
	var selected_ability: AbilityData = null
	if unit_id == _director.selected_unit_id and _director.selected_ability_index >= 0:
		selected_ability = _selected_ability_data(committed)
	var live_actor: UnitState = null
	var live_valid: bool = false
	if is_live_preview_active() and not drag_preview_failed and preview_state.preview_board != null:
		live_actor = preview_state.preview_board.get_unit_by_id(unit_id)
		if live_actor != null:
			live_valid = true
	var requires_run: bool = unit_move_requires_run(unit_id)
	var dest: Vector2i = move_intent_destination(unit_id)
	## auto_use_skill_after_move is the spend flag. A walk hover with it off is
	## walk economy ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ do not subtract the armed skill on the fallback path.
	## Skill-scroll / run-dest with no walk hover still subtracts (F5 stale AP).
	## Live preview remains AP truth when live_valid.
	var walk_hover: bool = (
		dest.x > -900
		and dest != committed.position
		and not requires_run
	)
	if (
		selected_ability != null
		and not auto_use_skill_after_move
		and walk_hover
		and not selected_ability.is_universal_run()
	):
		selected_ability = null
	var auto_run_scroll: bool = (
		auto_run
		and selected_ability != null
		and selected_ability.is_universal_run()
	)
	var auto_run_move: bool = false
	if unit_id == _director.selected_unit_id:
		auto_run_move = extended_move_budget_active(committed)
	return AbilitySystem.planning_display_ap_left(
		_proj(),
		committed,
		selected_ability,
		live_actor,
		live_valid,
		requires_run,
		auto_run_scroll,
		auto_run_move,
		move_intent_destination(unit_id),
	)


## Single MP read for planning UI ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ projected economy; reject overspend display from live sim.
func planning_display_mp_left(unit_id: int) -> int:
	if _director == null or unit_id < 0:
		return -1
	var committed: UnitState = _proj_unit(unit_id)
	if committed == null and _director.board != null:
		committed = _director.board.get_unit_by_id(unit_id)
	if committed == null:
		return -1
	var live_actor: UnitState = null
	var live_valid: bool = false
	if is_live_preview_active() and not drag_preview_failed and preview_state.preview_board != null:
		live_actor = preview_state.preview_board.get_unit_by_id(unit_id)
		if live_actor != null:
			live_valid = true
	if (
		not live_valid
	):
		var settled: PlanningHoverPreview = _settled_hover_preview
		if (
			settled != null
			and settled.matches_display_context(
				unit_id, settled_hover_revision_key(), _director.selected_ability_index,
			)
			and settled.preview_board != null
		):
			live_actor = settled.preview_board.get_unit_by_id(unit_id)
			live_valid = live_actor != null
	if unit_intent_uses_steady_aim(unit_id):
		return 0
	return AbilitySystem.planning_display_mp_left(committed, live_actor, live_valid)


## Cache key for timeline ghost refresh (intent snapshot identity).
func timeline_refresh_key(unit_id: int) -> String:
	if not _hover_intent_ghost_active(unit_id):
		return ""
	return _intent_snapshot_key


## Pending plan columns that differ from committed ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ for timeline ghost text.
func timeline_ghost_slots(unit_id: int) -> Dictionary:
	var empty: Dictionary = {"pre": [], "action": [], "post": []}
	if not _hover_intent_ghost_active(unit_id):
		return empty
	var intent: Dictionary = _duplicate_commit_slots(_intent_snapshot_slots)
	var committed: Dictionary = _committed_plan_slots(unit_id)
	for col: String in ["pre", "action", "post"]:
		var intent_steps: Array = intent.get(col, []) as Array
		var committed_steps: Array = committed.get(col, []) as Array
		if not _plan_column_equal(intent_steps, committed_steps):
			empty[col] = intent_steps.duplicate(true)
	return empty


func _hover_intent_ghost_active(unit_id: int) -> bool:
	if _director == null or unit_id < 0 or unit_id != _director.selected_unit_id:
		return false
	if not CombatDirector.is_planning_phase(_director.phase):
		return false
	if selected_phase_action_exhausted(unit_id):
		return false
	if not _intent_snapshot_valid or _is_invalid_dict(_intent_snapshot_slots):
		return false
	if drag_preview_failed:
		return false
	var receipt: PlanningHoverPreview = _current_hover_receipt()
	if receipt != null and receipt.preview_board != null:
		return true
	return preview_state.preview_board != null


func _committed_plan_slots(unit_id: int) -> Dictionary:
	var pre_moves: Array = []
	var abilities: Array = []
	var post_moves: Array = []
	if _director == null or unit_id < 0:
		return {"pre": pre_moves, "action": abilities, "post": post_moves}
	var plan: Timeline = _director.get_player_plan()
	if plan == null:
		return {"pre": pre_moves, "action": abilities, "post": post_moves}
	for action: TimelineAction in plan.entries:
		if action.actor_id != unit_id:
			continue
		if (
			action.type == GameEnums.ActionType.ABILITY
			and action.ability != null
			and action.ability.is_universal_wait()
		):
			continue
		match action.timeline_column():
			GameEnums.TimelineColumn.PRE_MOVE:
				pre_moves.append(action)
			GameEnums.TimelineColumn.POST_MOVE:
				post_moves.append(action)
			_:
				abilities.append(action)
	return {"pre": pre_moves, "action": abilities, "post": post_moves}


func _plan_column_equal(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for i: int in range(left.size()):
		if not _plan_action_equal(left[i] as TimelineAction, right[i] as TimelineAction):
			return false
	return true


func _plan_action_equal(a: TimelineAction, b: TimelineAction) -> bool:
	if a == null or b == null:
		return a == b
	if a.type != b.type or a.actor_id != b.actor_id:
		return false
	if a.target_coord != b.target_coord or a.target_unit_id != b.target_unit_id:
		return false
	if (
		a.face_dir != b.face_dir
		or a.waypoints != b.waypoints
		or a.module_target_coords != b.module_target_coords
		or a.module_target_unit_ids != b.module_target_unit_ids
	):
		return false
	if (
		a.uses_run != b.uses_run
		or a.uses_steady_aim != b.uses_steady_aim
		or a.awaiting_target != b.awaiting_target
		or a.awaiting_module_index != b.awaiting_module_index
		or a.irreversible != b.irreversible
		or a.is_free_reaction != b.is_free_reaction
	):
		return false
	if a.move_timing != b.move_timing:
		return false
	var a_ab: StringName = a.ability.id if a.ability != null else &""
	var b_ab: StringName = b.ability.id if b.ability != null else &""
	var a_authored: StringName = a.authored_ability.id if a.authored_ability != null else &""
	var b_authored: StringName = b.authored_ability.id if b.authored_ability != null else &""
	return a_ab == b_ab and a_authored == b_authored


func extended_move_budget_active(unit: UnitState = null) -> bool:
	return _run_mode_selected(unit) or auto_run_movement_active(unit)


func _run_mode_selected(unit: UnitState = null) -> bool:
	if _director == null or _director.selected_unit_id < 0:
		return false
	var actor := unit if unit != null else _proj_unit(_director.selected_unit_id)
	if actor == null:
		actor = _director.board.get_unit_by_id(_director.selected_unit_id) if _director.board != null else null
	if actor == null:
		return false
	var ability := _selected_ability_data(actor)
	if not AbilitySystem.is_run_ability(ability):
		return false
	return AbilitySystem.can_afford_run(actor)


func _move_budget(unit: UnitState) -> int:
	if unit == null:
		return 0
	var actor: UnitState = _proj_unit(unit.id) if _director != null else unit
	if actor == null:
		actor = unit
	if _director != null and _voluntary_walk_orbit_phase_open(actor):
		var via_director: int = _director.planning_move_budget(actor, _proj())
		if via_director > 0:
			return via_director
		var remaining: int = AbilitySystem.planning_available_movement_points(actor)
		if remaining > 0:
			return remaining
		if actor.movement != null:
			return actor.movement.max_points
	if extended_move_budget_active(unit):
		return AbilitySystem.planning_move_budget(unit, true)
	return AbilitySystem.planning_available_movement_points(actor)


func _ability_range(actor: UnitState) -> int:
	var abilities := actor.active_abilities
	var idx: int = _director.selected_ability_index
	if idx < 0 or idx >= abilities.size():
		return -1
	return AbilitySystem.planning_max_target_distance(actor, abilities[idx])


func _in_ability_range(actor: UnitState, target: UnitState) -> bool:
	return _in_ability_range_from(actor, target.position, target)


func _in_ability_range_from(actor: UnitState, coord: Vector2i, target: UnitState = null) -> bool:
	var rng := _ability_range(actor)
	if rng < 0:
		return false
	var actor_pos: Vector2i = _ability_range_origin(actor)
	var target_pos: Vector2i = coord
	if target != null and aiming and target.is_enemy():
		target_pos = _aim_enemy_pos(target.id)
	var ability: AbilityData = _selected_ability_data(actor)
	var plan_board: BoardState = _proj()
	if ability != null and plan_board != null:
		return AbilitySystem.planning_target_is_in_range(
			plan_board, actor, ability, actor_pos, target_pos,
		)
	return GridSystem.manhattan(actor_pos, target_pos) <= rng


func _ability_range_origin(actor: UnitState) -> Vector2i:
	if actor == null:
		return Vector2i.ZERO
	if _director != null:
		var awaiting: TimelineAction = _director.find_awaiting_action(actor.id)
		if awaiting != null and awaiting.awaiting_module_index > 0:
			var prior_stand: Vector2i = AbilitySystem.module_target_coord(
				awaiting, awaiting.awaiting_module_index - 1,
			)
			if _director.board != null and _director.board.is_in_bounds(prior_stand):
				return prior_stand
	if aiming:
		return _proj_origin(actor)
	if (
		_drag_route_commits_active()
		and _director != null
		and actor.id == _drag_unit_id
		and not _drag_route.is_empty()
	):
		var ability := _selected_ability_data(actor)
		if ability != null and AbilitySystem.planning_allows_paired_premove(ability):
			var stand: Vector2i = _drag_route_stand_cell()
			if _director.board != null and _director.board.is_in_bounds(stand):
				return stand
	return _settle_phase_entry_stand(actor)


func _in_ability_range_of_coord(actor: UnitState, coord: Vector2i) -> bool:
	var rng := _ability_range(actor)
	if rng < 0:
		return false
	var actor_pos: Vector2i = _ability_range_origin(actor)
	return GridSystem.manhattan(actor_pos, coord) <= rng


func _can_target_unit_with_selected_ability(actor: UnitState, target: UnitState) -> bool:
	if actor == null or target == null or not target.is_alive():
		return false
	if _director == null or _director.selected_ability_index < 0:
		return false
	var ability := _selected_ability_data(actor)
	if ability == null or AbilitySystem.is_run_ability(ability):
		return false
	if target.id == actor.id:
		return AbilitySystem.can_target_self(actor, ability)
	var dash_tile_target: bool = (
		AbilitySystem.ability_has_dash(ability, actor)
		and (
			AbilitySystem.active_targeting_flags(actor, ability)
			& GameEnums.TargetingFlags.TILE
		) != 0
	)
	if not dash_tile_target and not AbilitySystem.target_passes_mode(actor, ability, target):
		return false
	return _in_ability_range_from(actor, target.position, target)


func _can_move_to(unit: UnitState, coord: Vector2i) -> bool:
	if unit == null:
		return false
	var move_origin: Vector2i = _phase_entry_stand(unit)
	if move_origin.x <= -900000 or coord == move_origin:
		return false
	var ability: AbilityData = _selected_ability_data(unit)
	var skill_move_leg: bool = ability != null and _is_awaiting_movement_endpoint(unit, ability)
	if _voluntary_walk_corridor_paint_active(unit):
		skill_move_leg = false
	var budget: int = _drag_max_steps(unit)
	if skill_move_leg:
		if not AbilitySystem.planning_is_valid_awaiting_endpoint(
			move_origin, coord, ability, unit, _proj(),
		):
			return false
		var board_leg: BoardState = _proj()
		if not MovementSystem.can_end_movement_on(board_leg, coord, unit):
			return false
		var leg_corridor: Array[Vector2i] = CombatPlanningPreview.corridor_waypoints_to_cell(
			board_leg,
			unit,
			move_origin,
			coord,
			budget,
			_route_pathfinding_ability(unit),
			_director,
			unit.id,
		)
		return not leg_corridor.is_empty() and leg_corridor.back() == coord
	elif budget <= 0 and not extended_move_budget_active(unit):
		return false
	if (
		_planning != null
		and not _voluntary_walk_corridor_paint_active(unit)
		and not _planning.get_hover_move_tiles().is_empty()
		and not skill_move_leg
	):
		if budget <= 0 and not extended_move_budget_active(unit):
			return false
		if not _planning.is_hover_move_tile(coord):
			return false
		if _director != null and GridSystem.manhattan(move_origin, coord) == 1:
			var hop_route: Array = [move_origin, coord]
			var hop_forbidden: Dictionary = CombatPlanningPreview.prior_leg_forbidden_cells(
				_director, unit.id, move_origin,
			)
			if CombatPlanningPreview.route_touches_forbidden(hop_route, hop_forbidden):
				return false
		return true
	var board := _proj()
	if not MovementSystem.can_end_movement_on(board, coord, unit):
		return false
	var path_ability: AbilityData = _route_pathfinding_ability(unit)
	var move_cost: int = MovementSystem.move_cost_for(unit)
	var mt: GameEnums.MovementType = (
		unit.definition.movement_type
		if unit.definition != null
		else GameEnums.MovementType.WALK
	)
	var path: Array[Vector2i] = MovementSystem.find_path(
		board, move_origin, coord, budget, mt, move_cost, path_ability,
	)
	if path.is_empty():
		return false
	if _director == null:
		return true
	var route: Array = [move_origin]
	route.append_array(path)
	var forbidden: Dictionary = CombatPlanningPreview.prior_leg_forbidden_cells(
		_director, unit.id, move_origin,
	)
	return not CombatPlanningPreview.route_touches_forbidden(route, forbidden)


func _snapshot_drag_legal_move_tiles() -> Array[Vector2i]:
	if _planning == null:
		return []
	return _planning.get_hover_move_tiles()


func _drop_allows_move_tile(
	cell: Vector2i,
	legal_move_tiles: Array[Vector2i],
	actor: UnitState,
) -> bool:
	if actor == null or cell == actor.position:
		return false
	var move_origin: Vector2i = _phase_entry_stand(actor)
	if move_origin.x <= -900000 or cell == move_origin:
		return false
	var effective_legal: Array[Vector2i] = legal_move_tiles
	if effective_legal.is_empty() and _skill_interaction_active() and _planning != null:
		effective_legal = _planning.get_hover_move_tiles()
	if _skill_interaction_active():
		var ability: AbilityData = _selected_ability_data(actor)
		if ability != null and _is_awaiting_movement_endpoint(actor, ability):
			return _can_move_to(actor, cell)
		if effective_legal.is_empty():
			## Awaiting TARGET_PICK hides blue tiles on purpose. Unarmed TILE
			## skills still walk ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ do not require a populated overlay snapshot.
			if _awaiting_target_pick_blocks_premove():
				return false
			if awaiting_targeting_active() or (
				_director != null
				and _director.selected_unit_id >= 0
				and _director.find_awaiting_action(_director.selected_unit_id) != null
			):
				return false
			return _can_move_to(actor, cell)
		return effective_legal.has(cell)
	if not effective_legal.is_empty():
		return effective_legal.has(cell)
	return _can_move_to(actor, cell)


func _enemy_attackable_from_legal_tiles(
	actor: UnitState,
	enemy: UnitState,
	legal_move_tiles: Array[Vector2i],
) -> bool:
	if actor == null or enemy == null:
		return false
	if _in_ability_range(actor, enemy):
		return true
	if not _unit_move_slot_open(actor.id) or not _basic_move_allowed() or _move_budget(actor) <= 0:
		return false
	var ability := _selected_ability_data(actor)
	var rng: int = 1
	if ability != null:
		rng = AbilitySystem.active_range_tiles(actor, ability)
	elif _director.selected_ability_index >= 0:
		return false
	var origin: Vector2i = _proj_origin(actor)
	if GridSystem.manhattan(origin, enemy.position) <= rng:
		return true
	var effective_tiles: Array[Vector2i] = legal_move_tiles
	if effective_tiles.is_empty():
		effective_tiles = _snapshot_drag_legal_move_tiles()
	if not effective_tiles.is_empty():
		for tile: Vector2i in effective_tiles:
			if GridSystem.manhattan(tile, enemy.position) <= rng:
				return true
		return false
	if _director != null:
		var ability_idx: int = _director.selected_ability_index if _director.selected_ability_index >= 0 else 0
		var approach := _director.preview_approach_tile(actor.id, enemy.id, ability_idx, enemy.position)
		if approach != actor.position and _can_move_to(actor, approach):
			return GridSystem.manhattan(approach, enemy.position) <= rng
	return false


func _unit_at_input_cell(cell: Vector2i) -> UnitState:
	if _director == null or _director.board == null:
		return null
	var occ := _proj().get_unit_at(cell)
	if occ == null and _director.board != null:
		occ = _director.board.get_unit_at(cell)
	if occ == null:
		return null
	return _director.board.get_unit_by_id(occ.id)


func _proj() -> BoardState:
	if _director.projected_state != null:
		return _director.projected_state
	return _director.board


func projected_unit_for_preview(unit_id: int) -> UnitState:
	return _proj_unit(unit_id)

func _proj_unit(unit_id: int) -> UnitState:
	if unit_id < 0:
		return null
	return _proj().get_unit_by_id(unit_id)


func _proj_origin(unit: UnitState) -> Vector2i:
	return _phase_entry_stand(unit)


## Forecast stand at current planning phase entry (walk paint, commit, locked tiles).
func phase_entry_stand_cell(unit_id: int) -> Vector2i:
	if unit_id < 0:
		return Vector2i(-999999, -999999)
	var unit: UnitState = _proj_unit(unit_id)
	if unit == null and _director != null and _director.board != null:
		unit = _director.board.get_unit_by_id(unit_id)
	if unit == null:
		return Vector2i(-999999, -999999)
	return _phase_entry_stand(unit)


## Settled action-range origin; never follows stale live preview paths.
func settled_action_range_stand_cell(unit_id: int) -> Vector2i:
	if _director == null or unit_id < 0:
		return Vector2i(-999999, -999999)
	if unit_id == _director.selected_unit_id:
		var receipt: PlanningHoverPreview = _current_hover_receipt()
		if (
			receipt != null
			and receipt.matches_paint_context(
				_active_hover_cell(),
				unit_id,
				settled_hover_revision_key(),
				_director.selected_ability_index,
			)
			and receipt.stand_origin.x > -900000
		):
			return receipt.stand_origin
	return CombatPlanningPreview.planning_latest_stand_cell(
		_director, _proj(), unit_id, null,
	)


func _phase_entry_stand(unit: UnitState) -> Vector2i:
	if unit == null or _director == null:
		return Vector2i(-999999, -999999)
	return CombatPlanningPreview.forecast_stand_at_phase_entry(
		_director, _proj(), unit.id, preview_state,
	)


func _settle_phase_entry_stand(unit: UnitState) -> Vector2i:
	if unit == null or _director == null:
		return Vector2i(-999999, -999999)
	var board: BoardState = _director.live_planning_board()
	if board == null:
		board = _director.board
	return CombatPlanningPreview.planning_latest_stand_cell(
		_director, board, unit.id, null,
	)


func _planning_drag_origin(unit_id: int) -> Vector2i:
	var unit: UnitState = _proj_unit(unit_id)
	if unit == null:
		return Vector2i(-999999, -999999)
	return _leg_anchor_for_painted_drag(unit)

func _aim_enemy_pos(unit_id: int) -> Vector2i:
	var live := _director.board.get_unit_by_id(unit_id) if _director.board != null else null
	if live == null:
		return Vector2i.ZERO
	if not aiming or not live.is_enemy():
		return live.position
	var preview_unit := _aim_enemy_board().get_unit_by_id(unit_id)
	return preview_unit.position if preview_unit != null else live.position


func awaiting_enemy_pick_active() -> bool:
	if not awaiting_targeting_active() or _director == null:
		return false
	var actor: UnitState = _proj_unit(_director.selected_unit_id)
	if actor == null:
		return false
	return AbilitySystem.planning_awaiting_enemy_pick_active(
		actor, _awaiting_action_for(actor),
	)


func awaiting_movement_endpoint_ghost_visible(unit: UnitState) -> bool:
	if unit == null or not awaiting_targeting_active():
		return false
	var ability: AbilityData = _awaiting_ability_for(unit)
	if ability == null:
		return false
	return _is_awaiting_movement_endpoint(unit, ability)


func voluntary_walk_suppresses_targeting_arrow() -> bool:
	return _voluntary_walk_planning_active() and not awaiting_enemy_pick_active()


func enemy_unit_at_hover_cell() -> UnitState:
	if _director == null or _director.board == null:
		return null
	var cell: Vector2i = get_hover_tile_for_ui()
	if not _director.board.is_in_bounds(cell):
		return null
	var actor: UnitState = _proj_unit(_director.selected_unit_id)
	if actor == null:
		return null
	for board_variant: Variant in _boards_for_hover_target():
		var board: BoardState = board_variant as BoardState
		if board == null:
			continue
		var unit: UnitState = board.get_unit_at(cell)
		if unit == null or not unit.is_enemy():
			continue
		if _resolve_hover_attack_target(actor, unit) >= 0:
			return unit
	return null


func targeting_intent_arrow_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if _director == null or _director.board == null or _director.selected_unit_id < 0:
		return cells
	if dragging or voluntary_walk_suppresses_targeting_arrow():
		return cells
	var unit_id: int = _director.selected_unit_id
	var actor: UnitState = _proj_unit(unit_id)
	if actor == null:
		actor = _director.board.get_unit_by_id(unit_id)
	if actor == null:
		return cells
	var awaiting: TimelineAction = _awaiting_action_for(actor)
	if awaiting_targeting_active():
		if _append_targeting_arrow_for_awaiting_enemy_pick(cells, actor, awaiting):
			return cells
	if selected_phase_action_exhausted() and not awaiting_targeting_active():
		return cells
	var sel_ability: AbilityData = _awaiting_ability_for(actor)
	if sel_ability != null and AbilitySystem.can_target_self(actor, sel_ability):
		if awaiting == null:
			return cells
		if not AbilitySystem.planning_awaiting_target_pick_open(actor, awaiting):
			return cells
	if sel_ability != null and AbilitySystem.ability_has_movement_effect(sel_ability, actor):
		if awaiting == null or not AbilitySystem.planning_awaiting_enemy_pick_active(actor, awaiting):
			if awaiting == null or _is_awaiting_movement_endpoint(actor, sel_ability):
				return cells
	var origin: Vector2i = action_range_intent_stand_cell(unit_id)
	var attack_target_id: int = _hover_attack_target_id()
	if attack_target_id >= 0:
		var arrow_ability: AbilityData = sel_ability
		if arrow_ability == null:
			arrow_ability = _selected_ability_data(actor)
		if arrow_ability != null and AbilitySystem.ability_has_movement_effect(arrow_ability, actor):
			if _is_awaiting_movement_endpoint(actor, arrow_ability):
				return cells
			if active_movement_planning_step(actor):
				if awaiting == null or not AbilitySystem.planning_awaiting_enemy_pick_active(actor, awaiting):
					return cells
		var target_coord: Vector2i = get_hover_tile_for_ui()
		var target_unit: UnitState = _director.board.get_unit_by_id(attack_target_id)
		if target_unit == null and preview_state.preview_board != null:
			target_unit = preview_state.preview_board.get_unit_by_id(attack_target_id)
		if target_unit != null:
			target_coord = target_unit.position
		if origin != target_coord:
			cells.append(origin)
			cells.append(target_coord)
		return cells
	var hover_cell: Vector2i = get_hover_tile_for_ui()
	if (
		sel_ability != null
		and is_skill_aim_hover_at(hover_cell)
		and origin != hover_cell
		and not _is_awaiting_movement_endpoint(actor, sel_ability)
	):
		cells.append(origin)
		cells.append(hover_cell)
	return cells


func _append_targeting_arrow_for_awaiting_enemy_pick(
	cells: Array[Vector2i],
	actor: UnitState,
	awaiting: TimelineAction,
) -> bool:
	if awaiting == null:
		return false
	if not AbilitySystem.planning_awaiting_enemy_pick_active(actor, awaiting):
		return false
	var hover_enemy: UnitState = enemy_unit_at_hover_cell()
	if hover_enemy == null or not hover_enemy.is_enemy():
		return false
	var aim_origin: Vector2i = action_range_intent_stand_cell(actor.id)
	var aim_target: Vector2i = hover_enemy.position
	var hover_cell: Vector2i = get_hover_tile_for_ui()
	if aim_origin != aim_target:
		cells.append(aim_origin)
		cells.append(aim_target)
	elif _director.board.is_in_bounds(hover_cell) and aim_origin != hover_cell:
		cells.append(aim_origin)
		cells.append(hover_cell)
	return cells.size() >= 2


## Live hover enemy/unit id for skill targeting overlays (presentation only).
func hover_attack_target_id() -> int:
	return _hover_attack_target_id()


func _hover_attack_target_id() -> int:
	if _director == null or _director.board == null:
		return -1
	var cell: Vector2i = get_hover_tile_for_ui()
	if not _director.board.is_in_bounds(cell):
		return -1
	var actor := _proj_unit(_director.selected_unit_id)
	if actor == null:
		return -1
	for board: Variant in _boards_for_hover_target():
		if board == null:
			continue
		var hover_unit: UnitState = (board as BoardState).get_unit_at(cell)
		if hover_unit == null:
			continue
		var target_id := _resolve_hover_attack_target(actor, hover_unit)
		if target_id >= 0:
			return target_id
	return -1


func _boards_for_hover_target() -> Array:
	var boards: Array = []
	if _director != null and _director.board != null:
		boards.append(_director.board)
	var proj := _proj()
	if proj != null:
		boards.append(proj)
	if preview_state.preview_board != null:
		boards.append(preview_state.preview_board)
	if _planning != null:
		var committed_pb := _planning.get_preview_board()
		if committed_pb != null:
			boards.append(committed_pb)
	return boards


func _aim_enemy_board() -> BoardState:
	if _planning != null:
		var pb := _planning.get_preview_board()
		if pb != null:
			return pb
	return _proj()


func _facing_from_drop(local: Vector2, coord: Vector2i) -> int:
	if _map_view == null:
		return -1
	var center: Vector2 = _map_view.grid_to_local(coord)
	var offset: Vector2 = local - center
	var threshold: float = float(TacticalConstants.TILE_PX) * 0.22
	if offset.length() < threshold:
		return -1
	if absf(offset.x) >= absf(offset.y):
		return GameEnums.Facing.EAST if offset.x > 0.0 else GameEnums.Facing.WEST
	return GameEnums.Facing.SOUTH if offset.y > 0.0 else GameEnums.Facing.NORTH


func _is_planning() -> bool:
	if _director == null:
		return false
	return CombatDirector.is_planning_phase(_director.phase)


func _play_sfx(key: String) -> void:
	if _sfx != null and is_instance_valid(_sfx) and _sfx.is_inside_tree():
		_sfx.play(key)


func _empty_commit_slots() -> Dictionary:
	return {"pre": [], "action": [], "post": [], "invalid": false}


func _ability_plan_column(ability: AbilityData) -> String:
	return (
		"pre"
		if TimelineAction.timeline_column_for_ability(ability) == GameEnums.TimelineColumn.PRE_MOVE
		else "action"
	)


func _can_pair_run_move_with_ability(
	actor: UnitState,
	cell: Vector2i,
	waypoints: Array[Vector2i],
	ability: AbilityData,
) -> bool:
	if ability == null:
		return false
	if not AbilitySystem.movement_requires_run(_proj(), actor, cell, waypoints):
		return true
	return AbilitySystem.can_afford_run_for_commit(actor, ability)


func _enemy_hover_respects_painted_route(
	actor: UnitState,
	enemy: UnitState,
	ability: AbilityData,
	route_waypoints: Array[Vector2i],
) -> bool:
	if actor == null or enemy == null or route_waypoints.is_empty() or ability == null:
		return false
	var move_origin: Vector2i = _phase_entry_stand(actor)
	var stand_in_range: bool = AbilitySystem.planning_target_is_in_range(
		_proj(), actor, ability, route_waypoints.back(), enemy.position,
	)
	var approach_tile: Vector2i = Vector2i(-999999, -999999)
	if _director != null:
		approach_tile = _director.preview_approach_tile(
			actor.id,
			enemy.id,
			_director.selected_ability_index,
			enemy.position,
		)
	if not _PlanningRoutePolicy.enemy_hover_respects_painted_corridor(
		actor,
		enemy,
		ability,
		route_waypoints,
		move_origin,
		_in_ability_range_from(actor, enemy.position, enemy),
		stand_in_range,
		approach_tile,
		dragging,
		_can_pair_run_move_with_ability(actor, enemy.position, route_waypoints, ability),
	):
		return false
	if _director == null:
		return true
	var slots: Dictionary = _empty_commit_slots()
	var dest: Vector2i = route_waypoints.back()
	var timing: int = GameEnums.MoveTiming.PRE_ACTION
	if not _try_commit_voluntary_walk(slots, actor.id, actor, dest, route_waypoints, [dest]):
		return false
	if ability != null and not AbilitySystem.is_movement_skill(ability):
		slots["action"].append(
			TimelineAction.make_ability(
				actor.id,
				ability,
				enemy.position,
				AbilitySystem.planning_commit_target_unit_id(ability, enemy.id),
				timing,
				route_waypoints,
			),
		)
	return _director.preview_commit_valid(actor.id, _actions_from_slots(slots)) == ""


## PRE / MOVE module / POST ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ one voluntary-walk commit entry (slot timing differs only).
func _try_commit_voluntary_walk(
	slots: Dictionary,
	unit_id: int,
	actor: UnitState,
	cell: Vector2i,
	waypoints: Array[Vector2i],
	legal_move_tiles: Array[Vector2i],
) -> bool:
	if not _basic_move_allowed():
		return false
	if not _unit_move_slot_open(unit_id, cell):
		return false
	if not _drop_allows_move_tile(cell, legal_move_tiles, actor):
		return false
	var move_timing: int = _move_slot_timing_for_commit(unit_id, actor, cell)
	if move_timing < 0:
		return false
	if _director.unit_has_move_planned_at_timing(unit_id, move_timing):
		return false
	var resolved: Array[Vector2i] = waypoints
	if resolved.is_empty():
		resolved = _resolve_commit_move_waypoints(actor.id, actor, cell)
	_append_move_to_commit_slots(slots, unit_id, cell, resolved, actor)
	return not _is_invalid_dict(slots)


## R8 internal ÃƒÅ½Ã¢â‚¬Å“ÃƒÆ’Ã¢â‚¬Â¡ÃƒÆ’Ã‚Â¶ only _try_commit_voluntary_walk appends voluntary-walk timeline actions.
func _append_move_to_commit_slots(
	slots: Dictionary,
	unit_id: int,
	cell: Vector2i,
	waypoints: Array[Vector2i],
	actor: UnitState,
) -> void:
	if _director == null or actor == null:
		return
	var timing: int = _move_slot_timing_for_commit(unit_id, actor, cell)
	if timing < 0:
		return
	var move_origin: Vector2i = _phase_entry_stand(actor)

	var safe_waypoints: Array[Vector2i] = waypoints.duplicate()
	if safe_waypoints.is_empty() and cell != move_origin:
		safe_waypoints = _resolve_commit_move_waypoints(unit_id, actor, cell)
		if safe_waypoints.is_empty() and (_drag_route_commits_active() or dragging):
			safe_waypoints = _route_waypoints_for_commit(cell)
		if safe_waypoints.is_empty():
			slots["invalid"] = "Move requires preview waypoints."
			return
	var trust_painted_route: bool = (
		not safe_waypoints.is_empty()
		and (_drag_route_commits_active() or _painted_preview_route_matches_leg(actor))
	)
	if not trust_painted_route:
		for step: Vector2i in safe_waypoints:
			if not MovementSystem._is_walkable_for(_proj(), step, actor, null):
				slots["invalid"] = "Cannot reach this tile with basic movement."
				return
		
	var move: TimelineAction = TimelineAction.make_move(unit_id, cell, -1, safe_waypoints, timing)
	if AbilitySystem.movement_requires_run(_proj(), actor, cell, safe_waypoints):
		if _run_mode_selected(actor) or auto_run_movement_active(actor):
			move = TimelineAction.make_run_move(unit_id, cell, -1, safe_waypoints, timing)
		else:
			slots["invalid"] = "Cannot run without selecting run mode."
			return
	var col: String = "post" if timing == GameEnums.MoveTiming.POST_ACTION else "pre"
	slots[col].append(move)


func _append_springboard_reaction_to_commit_slots(
	slots: Dictionary,
	unit_id: int,
	actor: UnitState,
	cell: Vector2i,
	ability_index: int,
) -> bool:
	if (
		ability_index >= 0
		or actor == null
		or _director == null
		or _director.unit_has_move_planned_at_timing(
			unit_id, GameEnums.MoveTiming.POST_ACTION,
		)
	):
		return false
	var pending_variant: Variant = actor.passive_flags.get("springboard_pending_coord", null)
	if not pending_variant is Vector2i or pending_variant != cell:
		return false
	slots["post"].append(
		TimelineAction.make_free_reaction_move(unit_id, cell),
	)
	return true


func _maybe_append_premove_action_pair(
	slots: Dictionary,
	unit_id: int,
	actor: UnitState,
	cell: Vector2i,
	ability: AbilityData,
	waypoints: Array[Vector2i],
) -> void:
	if not _composite_cursors_enabled() or ability == null or actor == null:
		return
	if _director != null and _director.get_planning_move_timing(unit_id) == GameEnums.MoveTiming.POST_ACTION:
		return
	if _director.unit_action_column_spent_for_movement(unit_id):
		return
	if _reposition_skill_committed_for_unit(unit_id):
		return
	if (slots.get("pre", []) as Array).is_empty() and (slots.get("post", []) as Array).is_empty():
		return
	if not (slots.get("action", []) as Array).is_empty():
		return
	if selected_phase_action_exhausted(unit_id) or awaiting_targeting_active():
		return
	if AbilitySystem.planning_pairs_with_premove(actor, ability):
		if not _can_pair_run_move_with_ability(actor, cell, waypoints, ability):
			return
		slots["action"].append(
			TimelineAction.make_ability(unit_id, ability, cell, unit_id),
		)
	elif AbilitySystem.planning_auto_arms_after_premove(actor, ability):
		if not _can_pair_run_move_with_ability(actor, cell, waypoints, ability):
			return
		slots["action"].append(
			TimelineAction.make_ability_awaiting(unit_id, ability, cell, waypoints),
		)


func _build_commit_slots_at_cell(
	unit_id: int,
	cell: Vector2i,
	waypoints: Array[Vector2i] = [],
	legal_move_tiles: Array[Vector2i] = [],
	preferred_approach: Vector2i = _NO_PREFERRED_APPROACH,
	face_dir: int = -1,
) -> Dictionary:
	var slots: Dictionary = _empty_commit_slots()
	if _director == null or unit_id < 0 or _director.board == null:
		return slots
	if not _director.board.is_in_bounds(cell):
		slots["invalid"] = "Out of bounds."
		return slots
	var actor: UnitState = _proj_unit(unit_id)
	if actor == null:
		actor = _director.board.get_unit_by_id(unit_id)
	if actor == null or actor.is_enemy() or not actor.is_alive():
		return slots
	var can_offer_springboard := (
		_director.selected_ability_index < 0
		and actor.passive_flags.has("springboard_pending_coord")
		and not _director.unit_has_move_planned_at_timing(
			unit_id, GameEnums.MoveTiming.POST_ACTION,
		)
	)
	var has_awaiting_action := _director.find_awaiting_action(unit_id) != null
	if (
		selected_phase_action_exhausted(unit_id)
		and not can_offer_springboard
		and not has_awaiting_action
	):
		slots["invalid"] = "Action already exhausted this phase."
		return slots
	var move_timing: int = _move_slot_timing_for_commit(unit_id, actor, cell)
	var ability_index: int = _director.selected_ability_index
	var ability: AbilityData = _selected_ability_data(actor)
	var hover_unit: UnitState = _resolve_hover_unit_at(cell)

	if _append_springboard_reaction_to_commit_slots(
		slots, unit_id, actor, cell, ability_index,
	):
		return slots

	var awaiting_action: TimelineAction = (
		_director.find_awaiting_action(unit_id) if has_awaiting_action else null
	)
	if awaiting_action != null:
		AbilitySystem.prepare_planning_action(_proj(), awaiting_action)
	## DASH / teleport primary aim stays on the waypoint endpoint
	if (
		awaiting_action != null
		and awaiting_action.awaiting_module_index >= 0
		and (cell != actor.position or awaiting_action.awaiting_module_index > 0)
	):
		if _append_module_awaiting_target(
			slots, actor, awaiting_action, cell, hover_unit, waypoints,
		):
			return slots
		if slots.has("invalid"):
			return slots
	if (
		cell == actor.position
		and (
			awaiting_action == null
			or awaiting_action.target_coord == actor.position
		)
	):
		return _build_self_tile_commit_slots(
			slots, actor, unit_id, ability_index, ability, face_dir,
		)

	if _planning_post_move_only(actor, unit_id, cell) and not has_awaiting_action:
		if _try_commit_voluntary_walk(slots, unit_id, actor, cell, waypoints, legal_move_tiles):
			return slots
		if _skill_interaction_active() and _invalid_hover_target(actor, cell, hover_unit):
			slots["invalid"] = "Invalid target."
		return slots

	## Awaiting movement-endpoint skills (DASH etc.) commit a TILE. Occupant is incidental ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢
	## do not divert into enemy/ally unit-target commit slots.
	## First click on an ALLY-targeted dash (paired charger) still uses ally slots.
	var awaiting_tile_endpoint: bool = _is_awaiting_movement_endpoint(actor, ability)
	if (
		ability != null
		and (awaiting_action == null or awaiting_action.awaiting_module_index == 0)
		and AbilitySystem.ability_has_dash(ability, actor)
		and (
			awaiting_tile_endpoint
			or (
				AbilitySystem.active_targeting_flags(actor, ability)
				& GameEnums.TargetingFlags.ALLY
			) == 0
		)
	):
		awaiting_tile_endpoint = true
	var target_pick_skill: bool = (
		ability != null
		and _awaiting_flow_selected(actor, ability)
		and not AbilitySystem.ability_has_movement_effect(ability)
	)
	var awaiting_target_pick: bool = target_pick_skill and has_awaiting_action

	var targeted_move_attack: bool = (
		ability != null
		and AbilitySystem.ability_has_modifier(
			ability, &"target_after_move_adjacent", actor,
		)
	)
	if hover_unit != null and hover_unit.is_enemy() and (
		(not awaiting_tile_endpoint and not target_pick_skill) or targeted_move_attack
	):
		return _build_enemy_commit_slots(
			slots, actor, unit_id, cell, hover_unit, ability, ability_index,
			legal_move_tiles, waypoints, preferred_approach,
		)

	if (
		hover_unit != null
		and hover_unit.is_alive()
		and not hover_unit.is_enemy()
		and not awaiting_tile_endpoint
		and not target_pick_skill
		and not _reposition_skill_committed_for_unit(unit_id)
	):
		if (
			ability_index >= 0
			and ability != null
			and (
				not _voluntary_walk_planning_active()
				or AbilitySystem.target_passes_mode(actor, ability, hover_unit)
			)
		):
			return _build_ally_commit_slots(
				slots, actor, unit_id, hover_unit, ability, ability_index,
					waypoints, legal_move_tiles, preferred_approach,
			)
		if _skill_interaction_active() and hover_unit.id != actor.id:
			slots["invalid"] = "Cannot target this unit with selected skill."
			return slots

	if ability_index >= 0 and ability != null and _skill_commit_path_active():
		var effective_waypoints: Array[Vector2i] = waypoints
		if effective_waypoints.is_empty() and _drag_route_commits_active():
			var painted: Array[Vector2i] = _resolve_commit_move_waypoints(unit_id, actor, cell)
			if not painted.is_empty() and painted.back() == cell:
				effective_waypoints = painted
		if (
			effective_waypoints.is_empty()
			and AbilitySystem.ability_has_movement_effect(ability)
			and _is_awaiting_movement_endpoint(actor, ability)
		):
			effective_waypoints = _resolve_commit_move_waypoints(unit_id, actor, cell)
		if (
			effective_waypoints.is_empty()
			and _dash_tile_endpoint_one_click_commit(actor, ability, cell)
		):
			effective_waypoints = _resolve_commit_move_waypoints(unit_id, actor, cell)

		if (
			not has_awaiting_action
			and AbilitySystem.planning_arms_on_self_tile(actor, ability)
			and (cell == _phase_entry_stand(actor) or (hover_unit != null and hover_unit.id == actor.id))
		):
			slots[_ability_plan_column(ability)].append(
				TimelineAction.make_ability_awaiting(
					unit_id, ability, _phase_entry_stand(actor), effective_waypoints,
				),
			)
			return slots

		if (
			awaiting_action != null
			and awaiting_action.awaiting_module_index >= 0
			and (cell != actor.position or awaiting_action.awaiting_module_index > 0)
		):
			if _append_module_awaiting_target(
				slots, actor, awaiting_action, cell, hover_unit, effective_waypoints,
			):
				return slots
			if slots.has("invalid"):
				return slots

		if (
			has_awaiting_action
			or (
				not AbilitySystem.planning_arms_on_self_tile(actor, ability)
				and awaiting_targeting_active()
				and _awaiting_flow_selected(actor, ability)
				and AbilitySystem.planning_awaiting_phase(ability, actor)
					== GameEnums.PlanningAwaitingPhase.MOVEMENT_ENDPOINT
			)
		):
			if awaiting_targeting_active() or has_awaiting_action:
				var awaiting_origin := _phase_entry_stand(actor)
				if AbilitySystem.planning_is_valid_awaiting_endpoint(
					awaiting_origin, cell, ability, actor, _proj(),
				):
					var occupant_id := hover_unit.id if hover_unit != null else -1
					var committed_target_id := AbilitySystem.planning_commit_target_unit_id(
						ability, occupant_id,
					)
					if AbilitySystem.ability_has_modifier(
						ability, &"target_after_move_adjacent", actor,
					):
						if hover_unit != null and hover_unit.is_enemy():
							committed_target_id = hover_unit.id
						else:
							committed_target_id = _enemy_adjacent_to_attack_tile(
								actor, ability, cell,
							)
					var act := TimelineAction.make_ability(
						unit_id,
						ability,
						cell,
						committed_target_id,
						GameEnums.MoveTiming.PRE_ACTION,
						effective_waypoints,
					)
					AbilitySystem.prepare_planning_action(_proj(), act)
					slots[_ability_plan_column(ability)].append(act)
					return slots
				slots["invalid"] = "Invalid target or distance for this ability."
				return slots
		else:
			## Painted hover/drag route is pre-move intent while the class skill stays armed (K4 detour).
			## Armed TILE aim cells are the skill target, not a walk destination.
			if (
				not effective_waypoints.is_empty()
				and not _is_armed_tile_skill_aim_cell(actor, cell, ability)
				and _basic_move_allowed()
				and _unit_move_slot_open(unit_id, cell)
				and _drop_allows_move_tile(cell, legal_move_tiles, actor)
				and move_timing >= 0
				and not _director.unit_has_move_planned_at_timing(unit_id, move_timing)
				and not _movement_skill_commits_tile_endpoint(actor, ability, cell)
				and not _tile_target_movement_skill_commits_at_cell(actor, ability, cell, effective_waypoints)
			):
				if _try_commit_voluntary_walk(slots, unit_id, actor, cell, effective_waypoints, legal_move_tiles):
					if not AbilitySystem.ability_has_movement_effect(ability):
						_maybe_append_premove_action_pair(
							slots, unit_id, actor, cell, ability, effective_waypoints,
						)
					elif not _is_awaiting_movement_endpoint(actor, ability):
						_maybe_append_premove_action_pair(
							slots, unit_id, actor, cell, ability, effective_waypoints,
						)
				return slots
			if (
				hover_unit == null
				and AbilitySystem.ability_has_movement_effect(ability, actor)
				and not _is_awaiting_movement_endpoint(actor, ability)
				and _basic_move_allowed()
				and _unit_move_slot_open(unit_id, cell)
				and _drop_allows_move_tile(cell, legal_move_tiles, actor)
			):
				var walk_waypoints: Array[Vector2i] = waypoints
				if walk_waypoints.is_empty():
					walk_waypoints = _resolve_commit_move_waypoints(unit_id, actor, cell)
				if not _tile_target_movement_skill_commits_at_cell(actor, ability, cell, walk_waypoints):
					if _try_commit_voluntary_walk(slots, unit_id, actor, cell, walk_waypoints, legal_move_tiles):
						_maybe_append_premove_action_pair(
							slots, unit_id, actor, cell, ability, walk_waypoints,
						)
					return slots
			if AbilitySystem.can_target_self(actor, ability) and not _tile_target_movement_skill_commits_at_cell(actor, ability, cell, effective_waypoints):
				if AbilitySystem.is_run_ability(ability):
					if effective_waypoints.is_empty():
						effective_waypoints = _resolve_commit_move_waypoints(unit_id, actor, cell)
					if effective_waypoints.is_empty():
						slots["invalid"] = "Run requires preview waypoints."
						return slots
					_try_commit_voluntary_walk(slots, unit_id, actor, cell, effective_waypoints, legal_move_tiles)
					return slots
				if effective_waypoints.is_empty():
					effective_waypoints = _resolve_commit_move_waypoints(unit_id, actor, cell)
				if effective_waypoints.is_empty():
					slots["invalid"] = "Move requires preview waypoints."
					return slots
				if _try_commit_voluntary_walk(slots, unit_id, actor, cell, effective_waypoints, legal_move_tiles):
					_maybe_append_premove_action_pair(
						slots, unit_id, actor, cell, ability, effective_waypoints,
					)
				return slots

			if (
				hover_unit != null
				and hover_unit.id != actor.id
				and not hover_unit.is_enemy()
				and _reposition_skill_committed_for_unit(unit_id)
			):
				if _skill_interaction_active() and _invalid_hover_target(actor, cell, hover_unit):
					slots["invalid"] = "Invalid target."
				return slots

			if hover_unit != null and _in_ability_range(actor, hover_unit):
				if target_pick_skill and not has_awaiting_action:
					slots[_ability_plan_column(ability)].append(
						TimelineAction.make_ability_awaiting(
							unit_id, ability, actor.position, effective_waypoints,
						),
					)
					return slots
				slots[_ability_plan_column(ability)].append(
					_prepare_and_make_ability(
						unit_id,
						ability,
						hover_unit.position,
						AbilitySystem.planning_commit_target_unit_id(ability, hover_unit.id),
						GameEnums.MoveTiming.PRE_ACTION,
						effective_waypoints,
					),
				)
				return slots
			if (
				hover_unit == null
				and (
					AbilitySystem.active_targeting_flags(actor, ability)
					& GameEnums.TargetingFlags.TILE
				) != 0
			):
				if _in_ability_range_of_coord(actor, cell):
					if AbilitySystem.ability_has_movement_effect(ability, actor):
						if (
							_is_awaiting_movement_endpoint(actor, ability)
							or _tile_target_movement_skill_commits_at_cell(
								actor, ability, cell, effective_waypoints,
							)
						):
							var board: BoardState = _proj()
							if (
								_is_awaiting_movement_endpoint(actor, ability)
								and AbilitySystem.has_pass_through_effects(ability)
							):
								var path: Array[Vector2i] = MovementSystem.find_path(
									board,
									_proj_origin(actor),
									cell,
									AbilitySystem.active_range_tiles(actor, ability),
								)
								if path.is_empty():
									slots["invalid"] = "No valid path to target tile."
									return slots
							slots[_ability_plan_column(ability)].append(
								TimelineAction.make_ability(
									unit_id, ability, cell, -1, GameEnums.MoveTiming.PRE_ACTION,
									effective_waypoints,
								),
							)
							return slots
					else:
						## Unarmed TILE AOE on a legal empty walk tile is premove, not aim.
						## Volley range 4 covers Archer MP 4, so in-range-alone cannot steal walk.
						var empty_tile_is_premove := (
							not has_awaiting_action
							and _basic_move_allowed()
							and _unit_move_slot_open(unit_id, cell)
							and _drop_allows_move_tile(cell, legal_move_tiles, actor)
						)
						if not empty_tile_is_premove:
							if target_pick_skill and not has_awaiting_action:
								slots["action"].append(
									TimelineAction.make_ability_awaiting(
										unit_id, ability, cell, effective_waypoints,
									),
								)
								return slots
							var board_nm: BoardState = _proj()
							if AbilitySystem.has_pass_through_effects(ability):
								var path_nm: Array[Vector2i] = MovementSystem.find_path(
									board_nm,
									actor.position,
									cell,
									AbilitySystem.active_range_tiles(actor, ability),
								)
								if path_nm.is_empty():
									slots["invalid"] = "No valid path to target tile."
									return slots
							slots[_ability_plan_column(ability)].append(
								TimelineAction.make_ability(
									unit_id, ability, cell, -1, GameEnums.MoveTiming.PRE_ACTION,
									effective_waypoints,
								),
							)
							return slots

	if _try_commit_voluntary_walk(slots, unit_id, actor, cell, waypoints, legal_move_tiles):
		if ability_index >= 0 and ability != null and _skill_commit_path_active():
			var pair_wps: Array[Vector2i] = waypoints
			if pair_wps.is_empty():
				pair_wps = _resolve_commit_move_waypoints(unit_id, actor, cell)
			_maybe_append_premove_action_pair(
				slots, unit_id, actor, cell, ability, pair_wps,
			)
		return slots
	if _skill_interaction_active() and _invalid_hover_target(actor, cell, hover_unit):
		slots["invalid"] = "Invalid target."
	return slots


func _ally_hover_respects_painted_route(
	actor: UnitState,
	ally: UnitState,
	ability: AbilityData,
	route_waypoints: Array[Vector2i],
	stand_cell: Vector2i,
) -> bool:
	if actor == null or ally == null or ability == null or route_waypoints.is_empty():
		return false
	if not AbilitySystem.planning_allows_paired_premove(ability):
		return false
	if not AbilitySystem.target_passes_mode(actor, ability, ally):
		return false
	var slots: Dictionary = _empty_commit_slots()
	if stand_cell != _phase_entry_stand(actor):
		if not _try_commit_voluntary_walk(slots, actor.id, actor, stand_cell, route_waypoints, [stand_cell]):
			return false
	_append_movement_skill_to_premove_slots(slots, actor.id, ability, ally, [])
	if _director == null:
		return true
	if AbilitySystem.motion_requires_occupied_target(actor, ability):
		return AbilitySystem.occupied_push_from_origin_valid(
			_proj(), actor, ability, stand_cell, ally.position,
		)
	return _director.preview_commit_valid(actor.id, _actions_from_slots(slots)) == ""


func _append_movement_skill_to_premove_slots(
	slots: Dictionary,
	unit_id: int,
	ability: AbilityData,
	target: UnitState,
	waypoints: Array[Vector2i],
) -> void:
	if ability == null or target == null:
		return
	slots["pre"].append(
		TimelineAction.make_ability(
			unit_id,
			ability,
			target.position,
			AbilitySystem.planning_commit_target_unit_id(ability, target.id),
			GameEnums.MoveTiming.PRE_ACTION,
			waypoints,
		),
	)


func _build_ally_commit_slots(
	slots: Dictionary,
	actor: UnitState,
	unit_id: int,
	ally: UnitState,
	ability: AbilityData,
	ability_index: int,
	waypoints: Array[Vector2i],
	legal_move_tiles: Array[Vector2i],
	preferred_approach: Vector2i,
) -> Dictionary:
	if ability == null or actor == null or ally == null:
		slots["invalid"] = "Invalid target."
		return slots
	if not AbilitySystem.target_passes_mode(actor, ability, ally):
		slots["invalid"] = "Invalid target for this skill."
		return slots
	if AbilitySystem.ability_has_modifier(ability, &"relocate_subject_only", actor):
		var relocate_action := TimelineAction.make_ability(
			unit_id,
			ability,
			ally.position,
			ally.id,
			GameEnums.MoveTiming.PRE_ACTION,
			[],
		)
		AbilitySystem.set_module_target(relocate_action, 0, ally.position, ally.id)
		AbilitySystem.prepare_planning_action(_proj(), relocate_action)
		slots[_ability_plan_column(ability)].append(relocate_action)
		return slots
	if not AbilitySystem.ability_is_pre_move(actor, ability):
		if _can_target_unit_with_selected_ability(actor, ally):
			slots["action"].append(
				TimelineAction.make_ability(
					unit_id,
					ability,
					ally.position,
					AbilitySystem.planning_commit_target_unit_id(ability, ally.id),
					GameEnums.MoveTiming.PRE_ACTION,
					[],
				),
			)
		else:
			slots["invalid"] = "Invalid target."
		return slots
	var board: BoardState = _proj()
	var move_wps: Array[Vector2i] = waypoints.duplicate()
	var move_dest: Vector2i = _phase_entry_stand(actor)
	if not move_wps.is_empty():
		move_dest = move_wps[move_wps.size() - 1]
		if _drag_route_commits_active() and _director.board.is_in_bounds(_drag_route_stand_cell()):
			move_dest = _drag_route_stand_cell()
	if move_wps.is_empty():
		var swap_range: int = _ability_range(actor)
		var live_origin: Vector2i = _phase_entry_stand(actor)
		if _director != null:
			var live_unit: UnitState = _director.live_planning_board().get_unit_by_id(unit_id)
			if live_unit != null:
				live_origin = live_unit.position
		if (
			swap_range >= 0
			and GridSystem.manhattan(live_origin, ally.position) <= swap_range
		):
			_append_movement_skill_to_premove_slots(slots, unit_id, ability, ally, [])
			return slots
	if (
		not move_wps.is_empty()
		and _ally_hover_respects_painted_route(actor, ally, ability, move_wps, move_dest)
	):
		if (
			_unit_move_slot_open(unit_id, move_dest)
			and move_dest != _phase_entry_stand(actor)
		):
			_try_commit_voluntary_walk(slots, unit_id, actor, move_dest, move_wps, legal_move_tiles)
		_append_movement_skill_to_premove_slots(slots, unit_id, ability, ally, [])
		return slots
	var approach_hint: Vector2i = ally.position
	if preferred_approach != _NO_PREFERRED_APPROACH:
		approach_hint = preferred_approach
	var approach: Vector2i = _director.preview_approach_tile(
		unit_id, ally.id, ability_index, approach_hint,
	)
	var live_origin: Vector2i = _phase_entry_stand(actor)
	if _director != null:
		var live_unit: UnitState = _director.live_planning_board().get_unit_by_id(unit_id)
		if live_unit != null:
			live_origin = live_unit.position
	if approach == live_origin and not _in_ability_range_from(actor, ally.position, ally):
		slots["invalid"] = "Target is out of range."
		return slots
	if approach != live_origin and _unit_move_slot_open(unit_id, approach):
		var approach_path: Array[Vector2i] = []
		if _ally_hover_respects_painted_route(actor, ally, ability, move_wps, move_dest):
			approach_path = move_wps
		_try_commit_voluntary_walk(slots, unit_id, actor, approach, approach_path, legal_move_tiles)
	_append_movement_skill_to_premove_slots(slots, unit_id, ability, ally, [])
	return slots


func _build_enemy_commit_slots(
	slots: Dictionary,
	actor: UnitState,
	unit_id: int,
	cell: Vector2i,
	enemy: UnitState,
	ability: AbilityData,
	ability_index: int,
	legal_move_tiles: Array[Vector2i],
	waypoints: Array[Vector2i],
	preferred_approach: Vector2i = _NO_PREFERRED_APPROACH,
) -> Dictionary:
	var use_skill: bool = (
		_skill_commit_path_active()
		and ability != null
	)
	var effective_waypoints: Array[Vector2i] = waypoints.duplicate()
	if use_skill and not AbilitySystem.target_passes_mode(actor, ability, enemy):
		slots["invalid"] = "Invalid target for this skill."
		return slots
	if use_skill and AbilitySystem.ability_has_modifier(
		ability, &"target_after_move_adjacent", actor,
	):
		var endpoint := MovementSystem.l_shape_attack_endpoint(
			_proj(), actor, enemy, ability,
		)
		if endpoint.x < 0:
			slots["invalid"] = "No legal L-shaped side-attack endpoint."
			return slots
		var l_path := MovementSystem._l_shape_path(
			_proj(),
			_proj_origin(actor),
			endpoint,
			AbilitySystem.effect_amount(ability, GameEnums.EffectType.MOVE, actor),
			actor,
			ability,
		)
		slots["action"].append(
			TimelineAction.make_ability(
				unit_id,
				ability,
				endpoint,
				enemy.id,
				GameEnums.MoveTiming.PRE_ACTION,
				l_path,
			),
		)
		return slots
	if (
		use_skill
		and AbilitySystem.ability_has_movement_effect(ability)
		and not AbilitySystem.ability_has_modifier(ability, &"target_after_move_adjacent", actor)
		and not _in_ability_range(actor, enemy)
		and GridSystem.manhattan(_proj_origin(actor), enemy.position)
			<= AbilitySystem.planning_max_target_distance(actor, ability)
	):
		var charge_endpoint: Vector2i = MovementSystem.adjacent_attack_endpoint(
			_proj(), actor, enemy, ability,
		)
		if charge_endpoint.x < 0:
			slots["invalid"] = "No legal charge endpoint for this target."
			return slots
		var charge_path: Array[Vector2i] = MovementSystem.resolve_move_path(
			_proj(),
			actor,
			charge_endpoint,
			effective_waypoints,
			AbilitySystem.effect_amount(ability, GameEnums.EffectType.MOVE, actor),
			ability,
		)
		slots["action"].append(
			TimelineAction.make_ability(
				unit_id,
				ability,
				charge_endpoint,
				enemy.id,
				GameEnums.MoveTiming.PRE_ACTION,
				charge_path,
			),
		)
		return slots
	if use_skill and _is_awaiting_movement_endpoint(actor, ability):
		if AbilitySystem.planning_is_valid_awaiting_endpoint(
			_phase_entry_stand(actor), enemy.position, ability, actor, _proj(),
		):
			var committed_target_id := AbilitySystem.planning_commit_target_unit_id(
				ability, enemy.id,
			)
			slots["action"].append(
				TimelineAction.make_ability(
					unit_id,
					ability,
					enemy.position,
					committed_target_id,
					GameEnums.MoveTiming.PRE_ACTION,
					effective_waypoints,
				),
			)
			return slots
		slots["invalid"] = "Invalid endpoint for this skill."
		return slots
	if use_skill and _awaiting_flow_selected(actor, ability):
		if awaiting_targeting_active():
			slots["invalid"] = "Invalid endpoint for this skill."
			return slots
	if use_skill and _in_ability_range(actor, enemy):
		var committed_target_id := AbilitySystem.planning_commit_target_unit_id(ability, enemy.id)
		if effective_waypoints.is_empty():
			slots["action"].append(
				TimelineAction.make_ability(
					unit_id,
					ability,
					enemy.position,
					committed_target_id,
					GameEnums.MoveTiming.PRE_ACTION,
					[],
				),
			)
			return slots
		else:
			var stand_cell: Vector2i = effective_waypoints.back()
			var needs_run: bool = AbilitySystem.movement_requires_run(
				_proj(), actor, stand_cell, effective_waypoints,
			)
			if needs_run and not AbilitySystem.can_afford_run_for_commit(actor, ability):
				slots["invalid"] = "Not enough AP to run and use this skill."
				return slots
			if not _try_commit_voluntary_walk(
				slots, unit_id, actor, stand_cell, effective_waypoints, legal_move_tiles,
			):
				slots["invalid"] = "Cannot commit approach move."
				return slots
			slots["action"].append(
				TimelineAction.make_ability(
					unit_id,
					ability,
					enemy.position,
					committed_target_id,
					GameEnums.MoveTiming.PRE_ACTION,
					effective_waypoints,
				),
			)
			return slots
	if not use_skill and _in_attack_range_from(_proj_origin(actor), enemy, actor):
		var basic: AbilityData = actor.active_abilities[0] if not actor.active_abilities.is_empty() else null
		if basic != null:
			slots["action"].append(
				TimelineAction.make_ability(
					unit_id,
					basic,
					enemy.position,
					AbilitySystem.planning_commit_target_unit_id(basic, enemy.id),
					GameEnums.MoveTiming.PRE_ACTION,
					effective_waypoints,
				),
			)
		return slots
	if use_skill and _prefer_approach_over_trample_move(actor, enemy):
		if not _enemy_attackable_from_legal_tiles(actor, enemy, legal_move_tiles):
			slots["invalid"] = "Enemy is not attackable from legal move tiles."
			return slots
	elif (
		_drop_allows_move_tile(enemy.position, legal_move_tiles, actor)
		and not (
			use_skill
			and AbilitySystem.ability_is_offensive_dash(ability)
		)
	):
		if _try_commit_voluntary_walk(slots, unit_id, actor, enemy.position, waypoints, legal_move_tiles):
			return slots
	elif not _enemy_attackable_from_legal_tiles(actor, enemy, legal_move_tiles):
		slots["invalid"] = "Enemy is not attackable from legal move tiles."
		return slots
	if use_skill:
		if AbilitySystem.ability_is_pre_move(actor, ability):
			slots["invalid"] = "Cannot pair this action with a pre-move."
			return slots
		var approach_hint: Vector2i = cell
		if preferred_approach != _NO_PREFERRED_APPROACH:
			approach_hint = preferred_approach
		if not effective_waypoints.is_empty():
			approach_hint = effective_waypoints.back()
		var approach: Vector2i = _director.preview_approach_tile(
			unit_id, enemy.id, ability_index, approach_hint,
		)
		if approach == actor.position and not _in_ability_range(actor, enemy):
			slots["invalid"] = "Target is out of range."
			return slots
		if approach != actor.position:
			if not _unit_move_slot_open(unit_id, approach) or not _basic_move_allowed() or not _can_move_to(actor, approach):
				slots["invalid"] = "Cannot move to approach target."
				return slots
			var board: BoardState = _proj()
			var approach_path: Array[Vector2i] = []
			if _enemy_hover_respects_painted_route(actor, enemy, ability, waypoints):
				approach_path = waypoints.duplicate()
			elif not waypoints.is_empty():
				approach_path = waypoints.duplicate()
			else:
				approach_path = _resolve_commit_move_waypoints(unit_id, actor, approach)
				if approach_path.is_empty():
					approach_path = _hover_walk_waypoints_for_skill(
						actor, enemy.position, ability,
					)
				if approach_path.is_empty():
					slots["invalid"] = "Approach requires preview waypoints."
					return slots
			var rng: int = _ability_range(actor)
			if rng >= 0 and GridSystem.manhattan(approach, enemy.position) > rng:
				slots["invalid"] = "Target is out of range."
				return slots
			var needs_run: bool = AbilitySystem.movement_requires_run(
				board, actor, approach, approach_path,
			)
			if needs_run and not AbilitySystem.can_afford_run_for_commit(actor, ability):
				slots["invalid"] = "Not enough AP to run and use this skill."
				return slots
			if not _try_commit_voluntary_walk(
				slots, unit_id, actor, approach, approach_path, legal_move_tiles,
			):
				slots["invalid"] = "Cannot commit approach move."
				return slots
			slots["action"].append(
				_prepare_and_make_ability(
					unit_id,
					ability,
					enemy.position,
					AbilitySystem.planning_commit_target_unit_id(ability, enemy.id),
					GameEnums.MoveTiming.PRE_ACTION,
					approach_path,
				),
			)
			return slots
		slots["action"].append(
			_prepare_and_make_ability(
				unit_id,
				ability,
				enemy.position,
				AbilitySystem.planning_commit_target_unit_id(ability, enemy.id),
				GameEnums.MoveTiming.PRE_ACTION,
				[],
			),
		)
		return slots
	if _try_commit_voluntary_walk(slots, unit_id, actor, cell, waypoints, legal_move_tiles):
		return slots
	slots["invalid"] = "Tile is not reachable."
	return slots


func _prepare_and_make_ability(
	unit_id: int,
	ability: AbilityData,
	target_coord: Vector2i,
	target_unit_id: int,
	timing: GameEnums.MoveTiming,
	waypoints: Array[Vector2i] = [],
) -> TimelineAction:
	var act := TimelineAction.make_ability(unit_id, ability, target_coord, target_unit_id, timing, waypoints)
	AbilitySystem.prepare_planning_action(_proj(), act)
	AbilitySystem.stamp_steady_aim_on_action(_proj(), act)
	return act


func _step_cursor_glyph(action: TimelineAction, _unit: UnitState = null) -> String:
	return PlanningIcons.action_glyph(action)


func _actions_from_slots(slots: Dictionary) -> Array[TimelineAction]:
	var out: Array[TimelineAction] = []
	for col: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(col, []):
			if raw is TimelineAction:
				out.append(raw as TimelineAction)
	return out


func _append_module_awaiting_target(
	slots: Dictionary,
	actor: UnitState,
	awaiting_action: TimelineAction,
	cell: Vector2i,
	hover_unit: UnitState,
	waypoints: Array[Vector2i],
) -> bool:
	var module_index: int = awaiting_action.awaiting_module_index
	var target_unit_id: int = hover_unit.id if hover_unit != null else -1
	var targeting_flags: int = AbilitySystem.active_targeting_flags(
		actor, awaiting_action.ability, module_index,
	)
	var targets_units: bool = (
		targeting_flags & (
			GameEnums.TargetingFlags.ALLY
			| GameEnums.TargetingFlags.ENEMY
			| GameEnums.TargetingFlags.SELF
		)
	) != 0
	if not targets_units:
		target_unit_id = -1
	if not AbilitySystem.planning_module_target_valid(
		_proj(), awaiting_action, module_index, cell, target_unit_id,
	):
		slots["invalid"] = "Invalid target or distance for this ability."
		return false
	var committed: TimelineAction = awaiting_action.clone()
	if committed.authored_ability != null:
		committed.ability = committed.authored_ability
	AbilitySystem.set_module_target(committed, module_index, cell, target_unit_id)
	committed.awaiting_target = false
	committed.awaiting_module_index = -1
	if module_index == 0:
		committed.target_coord = cell
		committed.target_unit_id = target_unit_id
		var wps: Array[Vector2i] = waypoints.duplicate()
		if wps.is_empty() and AbilitySystem.ability_has_movement_effect(committed.ability, actor):
			wps = _resolve_commit_move_waypoints(actor.id, actor, cell)
			if (wps.is_empty() or wps.back() != cell) and committed.ability != null:
				wps = _hover_walk_waypoints_for_skill(actor, cell, committed.ability)
			if wps.is_empty() or wps.back() != cell:
				slots["invalid"] = "Ability move requires preview waypoints."
				return false
		committed.waypoints = wps
	AbilitySystem.prepare_planning_action(_proj(), committed)
	slots[_ability_plan_column(awaiting_action.ability)].append(committed)
	return true


func _finalize_commit_slots(
	slots: Dictionary,
	unit_id: int,
	sim_validate: bool = true,
) -> Dictionary:
	if _is_invalid_dict(slots):
		return slots
	if slots.get("_noop", false) == true:
		slots["_preview_validated"] = true
		return slots
	var actions: Array[TimelineAction] = _actions_from_slots(slots)
	if actions.is_empty():
		slots["invalid"] = "No valid actions generated."
		return slots
	if _slots_are_wait_only(actions):
		slots["_preview_validated"] = true
		return slots
	for action: TimelineAction in actions:
		AbilitySystem.prepare_planning_action(_proj(), action)
	AbilitySystem.stamp_steady_aim_on_slots(_proj(), slots)
	if not sim_validate:
		return slots
	var error_reason: String = _director.validate_commit_slots(unit_id, slots) if _director != null else ""
	if error_reason != "":
		slots["invalid"] = error_reason
		return slots
	slots["_preview_validated"] = true
	return slots


func _slots_are_wait_only(actions: Array[TimelineAction]) -> bool:
	if actions.size() != 1:
		return false
	var action: TimelineAction = actions[0]
	return (
		action.type == GameEnums.ActionType.ABILITY
		and action.ability != null
		and action.ability.is_universal_wait()
	)


func _composite_cursors_enabled() -> bool:
	return auto_use_skill_after_move and _skill_commit_path_active()


## Test adapter: drag-drop commit slots use the same interaction builder as click.
func _final_commit_slots_for_drop_at_cell(
	unit_id: int,
	cell: Vector2i,
	local: Vector2,
	legal_move_tiles: Array[Vector2i] = [],
) -> Dictionary:
	if _director == null or _director.board == null or unit_id < 0:
		return _empty_commit_slots()
	if not _director.board.is_in_bounds(cell):
		return _empty_commit_slots()
	if (
		selected_phase_action_exhausted(unit_id)
		and _director.find_awaiting_action(unit_id) == null
	):
		return _empty_commit_slots()
	var dropped_on: UnitState = _unit_at_input_cell(cell)
	var target_id: int = -1
	if dropped_on != null and dropped_on.id != unit_id:
		target_id = dropped_on.id
	var params: Dictionary = _commit_interaction_params(cell, target_id)
	var waypoints: Array[Vector2i] = params.waypoints as Array[Vector2i]
	var legal: Array[Vector2i] = (
		legal_move_tiles
		if not legal_move_tiles.is_empty()
		else params.legal_move_tiles as Array[Vector2i]
	)
	var face_dir: int = int(params.get("face_dir", -1))
	if face_dir < 0:
		face_dir = _facing_from_drop(local, params.cell)
	var slots: Dictionary = _final_commit_slots_for_interaction(
		unit_id,
		params.cell,
		waypoints,
		legal,
		params.preferred,
		face_dir,
	)
	_apply_facing_to_slots(slots, local, params.cell, unit_id)
	return slots


## Test adapter: delegates directly to the canonical interaction-slot builder.
func _final_commit_slots_for_click_at_cell(
	unit_id: int,
	cell: Vector2i,
	local: Vector2,
) -> Dictionary:
	var params: Dictionary = _commit_interaction_params(cell, -1)
	var face_dir: int = int(params.get("face_dir", -1))
	if face_dir < 0:
		face_dir = _facing_from_drop(local, cell)
	return _final_commit_slots_for_interaction(
		unit_id,
		params.cell,
		params.waypoints,
		params.legal_move_tiles,
		params.preferred,
		face_dir,
	)


func _cursor_icon_from_commit_slots(slots: Dictionary, unit: UnitState = null) -> String:
	if _is_invalid_dict(slots):
		return PlanningIcons.GLYPH_NULL
	var glyphs: PackedStringArray = []
	for col: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(col, []):
			if not raw is TimelineAction:
				continue
			var glyph: String = _step_cursor_glyph(raw as TimelineAction, unit)
			if glyph != "":
				glyphs.append(glyph)
	if glyphs.is_empty():
		return ""
	if not _composite_cursors_enabled() or glyphs.size() == 1:
		return glyphs[0]
	return PlanningIcons.join_glyphs(glyphs)


func _clear_planning_cursor_for_drag() -> void:
	_overlay_cursor_icon = ""
	_overlay_cursor_cell = Vector2i(-999999, -999999)
	_hover_cursor_cache_key = ""
	_hover_cursor_cached_icon = ""
	if _planning != null:
		_planning.clear_planning_cursor_icon()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func refresh_mouse_cursor(cell: Vector2i) -> void:
	var icon: String = _compute_hover_action_icon(cell)
	if icon == _overlay_cursor_icon and cell == _overlay_cursor_cell:
		return
	_overlay_cursor_icon = icon
	_overlay_cursor_cell = cell
	if _planning != null:
		_planning.set_hover_action_icon(icon)
	if _planning != null and _planning.is_system_mouse_override():
		return
	if icon != "" and (_planning == null or _planning.planning_cursor_display_enabled()):
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func compute_hover_action_icon(cell: Vector2i) -> String:
	return _compute_hover_action_icon(cell)


func _compute_hover_action_icon(cell: Vector2i) -> String:
	if _director == null or _director.board == null or not _director.board.is_in_bounds(cell):
		return ""
	if dragging:
		## F5: drag preview is the unit sprite only ÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¬ÃƒÆ’Ã‚Â´ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬Â¢Ã‚Â¢ hide planning emoji cursor.
		return ""
	var sel_id: int = _director.selected_unit_id
	if sel_id < 0:
		return ""
	var sel_unit := _director.board.get_unit_by_id(sel_id)
	if sel_unit == null or sel_unit.is_enemy():
		return ""
	var p_unit := _proj_unit(sel_id)
	if p_unit == null:
		return ""
	var hover_unit: UnitState = _resolve_hover_unit_at(cell)
	var attack_target_id: int = -1
	if hover_unit != null:
		attack_target_id = hover_unit.id
	var cache_key: String = _hover_interaction_cache_key(sel_id, cell, attack_target_id)
	if cache_key == _hover_cursor_cache_key:
		return _hover_cursor_cached_icon
	var slots: Dictionary = {}
	var receipt: PlanningHoverPreview = _current_hover_receipt()
	if (
		receipt != null
		and receipt.matches_paint_context(
			cell,
			sel_id,
			settled_hover_revision_key(),
			_director.selected_ability_index,
		)
	):
		slots = receipt.duplicate_slots()
	elif _intent_snapshot_valid and _intent_snapshot_key == cache_key:
		slots = _duplicate_commit_slots(_intent_snapshot_slots)
	else:
		return PlanningIcons.GLYPH_NULL
	var icon: String = _cursor_icon_from_commit_slots(slots, p_unit)
	_hover_cursor_cache_key = cache_key
	_hover_cursor_cached_icon = icon
	return icon


func _resolve_hover_unit_at(cell: Vector2i) -> UnitState:
	if _director == null or _director.board == null or not _director.board.is_in_bounds(cell):
		return null
	var actor: UnitState = _proj_unit(_director.selected_unit_id)
	var ability: AbilityData = _selected_ability_data(actor) if actor != null else null
	if (
		ability != null
		and AbilitySystem.ability_occupant_is(
			actor,
			ability,
			GameEnums.ModuleTargetFilterOccupant.ALLY_CORPSE,
		)
	):
		var corpse: UnitState = AbilitySystem.ally_corpse_at(_director.board, actor, cell)
		if corpse == null:
			corpse = AbilitySystem.ally_corpse_at(_proj(), actor, cell)
		if corpse != null:
			return corpse
	var live: UnitState = _director.board.get_unit_at(cell)
	if live == null:
		return null
	var projected: UnitState = _proj().get_unit_by_id(live.id)
	return projected if projected != null else live


func _attack_range_for(actor: UnitState) -> int:
	var ability: AbilityData = _selected_ability_data(actor)
	if ability != null:
		return AbilitySystem.active_range_tiles(actor, ability)
	if _director != null and _director.selected_ability_index >= 0:
		return -1
	return 1


func _in_attack_range_from(origin: Vector2i, enemy: UnitState, actor: UnitState) -> bool:
	var rng: int = _attack_range_for(actor)
	if rng < 0:
		return false
	return GridSystem.manhattan(origin, enemy.position) <= rng


func _drag_preview_includes_attack(actor_id: int) -> bool:
	if preview_state.preview_board == null or actor_id < 0:
		return false
	if int(preview_state.preview_splits.get(actor_id, 1)) <= 1:
		return false
	var pv: UnitState = preview_state.preview_board.get_unit_by_id(actor_id)
	if pv == null:
		return false
	for unit: UnitState in preview_state.preview_board.units:
		if unit.is_enemy() and unit.is_alive():
			if _in_attack_range_from(pv.position, unit, pv):
				return true
	return false


func _drag_hover_icon(actor: UnitState, cell: Vector2i) -> String:
	if actor == null:
		return ""
	if (
		_settled_hover_preview == null
		or not _settled_hover_preview.matches_ratification_context(
			cell,
			actor.id,
			settled_hover_revision_key(),
			_director.selected_ability_index,
		)
	):
		return PlanningIcons.GLYPH_NULL
	return _cursor_icon_from_commit_slots(
		_settled_hover_preview.duplicate_slots(),
		actor,
	)


func _invalid_hover_target(p_unit: UnitState, cell: Vector2i, hover_unit: UnitState) -> bool:
	if not _skill_interaction_active():
		return false
	var ability: AbilityData = _selected_ability_data(p_unit)
	if ability == null:
		return false
	if hover_unit != null and hover_unit.id == p_unit.id:
		return not AbilitySystem.can_target_self(p_unit, ability) and not AbilitySystem.is_run_ability(ability)
	if hover_unit != null and not hover_unit.is_enemy() and hover_unit.id != p_unit.id:
		return not _can_target_unit_with_selected_ability(p_unit, hover_unit)
	if _awaiting_flow_selected(p_unit, ability) and _planning != null:
		if awaiting_targeting_active() and (
			_planning.is_hover_action_range_tile(cell)
			and not AbilitySystem.planning_is_valid_awaiting_endpoint(
				_proj_origin(p_unit), cell, ability, p_unit, _proj(),
			)
		):
			return true
	return false


func _is_armed_tile_skill_aim_cell(
	p_unit: UnitState,
	cell: Vector2i,
	ability: AbilityData,
) -> bool:
	if p_unit == null or ability == null:
		return false
	if _director != null and _director.unit_has_committed_class_action(p_unit.id):
		return false
	## "Armed" means TARGET_PICK is already awaiting. Selected-but-unarmed TILE
	## skills (Volley) must still accept basic premove on empty walk tiles.
	if not awaiting_targeting_active() and (
		_director == null or _director.find_awaiting_action(p_unit.id) == null
	):
		return false
	if (
		AbilitySystem.active_targeting_flags(p_unit, ability)
		& GameEnums.TargetingFlags.TILE
	) == 0:
		return false
	if AbilitySystem.ability_has_movement_effect(ability, p_unit):
		return _is_tile_dash_skill_aim_cell(p_unit, cell, ability)
	return _in_ability_range_of_coord(p_unit, cell)


func _is_tile_dash_skill_aim_cell(
	p_unit: UnitState,
	cell: Vector2i,
	ability: AbilityData,
) -> bool:
	if p_unit == null or ability == null:
		return false
	if _is_awaiting_movement_endpoint(p_unit, ability):
		return _movement_skill_commits_tile_endpoint(p_unit, ability, cell)
	return _dash_tile_endpoint_one_click_commit(p_unit, ability, cell)


func _hover_walk_waypoints_for_skill(
	actor: UnitState,
	cell: Vector2i,
	ability: AbilityData,
) -> Array[Vector2i]:
	if actor == null or ability == null or _director == null:
		return []
	var target_id: int = _attack_target_id_at_cell(actor, cell)
	if target_id >= 0 and _director.board != null:
		var target: UnitState = _director.board.get_unit_by_id(target_id)
		if (
			target != null
			and not AbilitySystem.is_movement_skill(ability)
			and not _in_ability_range(actor, target)
		):
			var approach: Vector2i = _director.preview_approach_tile(
				actor.id, target.id, _director.selected_ability_index, target.position,
			)
			var origin: Vector2i = _settle_phase_entry_stand(actor)
			if approach != origin:
				return _director.preview_waypoints_for_hover(
					_proj(), actor, approach, [], ability, false, preview_state)
			return []
	if _is_awaiting_movement_endpoint(actor, ability):
		if (
			_painted_drag_route_drives_live_preview()
			and _drag_unit_id == actor.id
			and _drag_route.size() >= 2
		):
			return _hover_paint_waypoints_for_cell(actor, cell)
		var skill_path: Array[Vector2i] = _director.preview_waypoints_for_hover(
			_proj(), actor, cell, [], ability, true, preview_state,
		)
		if not skill_path.is_empty():
			var origin: Vector2i = _phase_entry_stand(actor)
			var trimmed: Array[Vector2i] = []
			for wp: Vector2i in skill_path:
				if trimmed.is_empty() and wp == origin:
					continue
				trimmed.append(wp)
			if not trimmed.is_empty():
				return _normalize_adjacent_single_step_waypoints(trimmed, origin)
		return _hover_paint_waypoints_for_cell(actor, cell)
	var empty: Array[Vector2i] = []
	if not _is_hover_move_cell(actor, cell):
		return empty
	if _is_tile_dash_skill_aim_cell(actor, cell, ability):
		return empty
	if _tile_target_movement_skill_commits_at_cell(actor, ability, cell):
		return empty
	return _hover_paint_waypoints_for_cell(actor, cell)

func _skill_takes_priority_over_basic_move() -> bool:
	if _director == null:
		return false
	if _run_mode_selected():
		return false
	return _skill_commit_path_active()


func _skill_interaction_active() -> bool:
	return _skill_takes_priority_over_basic_move() and _director.selected_unit_id >= 0 and not dragging


func _predicted_stand_tile_for_enemy_hover(cell: Vector2i, enemy: UnitState) -> Vector2i:
	if _director == null or enemy == null:
		return Vector2i(-999, -999)
	var unit_id: int = _director.selected_unit_id
	if unit_id < 0:
		return Vector2i(-999, -999)
	var actor: UnitState = _proj_unit(unit_id)
	if actor == null:
		return Vector2i(-999, -999)
	var origin: Vector2i = _proj_origin(actor)
	var ability_index: int = _director.selected_ability_index
	var ability: AbilityData = null
	if ability_index >= 0:
		ability = _selected_ability_data(actor)
		if ability != null and AbilitySystem.is_movement_skill(ability):
			return origin
	else:
		if not actor.active_abilities.is_empty():
			var basic_ability: AbilityData = CombatDirector.resolve_selected_ability(actor, 0)
			if basic_ability != null and AbilitySystem.is_movement_skill(basic_ability):
				return origin

	if is_live_preview_active() and preview_state.preview_board != null:
		var pv: UnitState = preview_state.preview_board.get_unit_by_id(unit_id)
		if pv != null:
			return pv.position
			
	if ability_index >= 0:
		if ability != null and _in_ability_range(actor, enemy):
			return origin
		return _director.preview_approach_tile(unit_id, enemy.id, ability_index, cell)
	if _in_attack_range_from(origin, enemy, actor):
		return origin
	if actor.active_abilities.is_empty():
		return origin
	return _director.preview_approach_tile(unit_id, enemy.id, 0, cell)


func _drag_preview_target_id(drag_unit: UnitState, occ: UnitState) -> int:
	if occ != null and drag_unit != null and occ.id != drag_unit.id:
		return occ.id
	return -1


func _set_drag_attack_target(target_id: int, preview: Dictionary) -> void:
	if target_id < 0:
		target_id = _preview_attack_target_id(preview, _drag_unit_id)
	if target_id >= 0:
		_planning.set_drag_attack_target(target_id)
	else:
		_planning.set_drag_attack_target(-1)


func _preview_attack_target_id(preview: Dictionary, actor_id: int) -> int:
	for event: Variant in preview.get("events", []):
		if not event is SimEvent:
			continue
		var sim: SimEvent = event as SimEvent
		if sim.type != GameEnums.SimEventType.ABILITY_USED:
			continue
		if int(sim.data.get("actor", -1)) != actor_id:
			continue
		var target_unit_id: int = int(sim.data.get("target_unit", -1))
		if target_unit_id >= 0:
			return target_unit_id
	return -1


func _drag_move_preview_mode(unit: UnitState, dest: Vector2i) -> int:
	if unit != null and dest != unit.position:
		var waypoints: Array[Vector2i] = []
		if _drag_route.size() >= 2:
			for i: int in range(1, _drag_route.size()):
				waypoints.append(_drag_route[i])
		if AbilitySystem.movement_requires_run(_proj(), unit, dest, waypoints):
			return TacticalUnitLayer.DragPreviewAnim.RUN
	if preview_state.preview_board != null and unit != null:
		var pv := preview_state.preview_board.get_unit_by_id(unit.id)
		if pv != null and pv.has_run_boost():
			return TacticalUnitLayer.DragPreviewAnim.RUN
	return TacticalUnitLayer.DragPreviewAnim.WALK


func _drag_ability_preview_mode(
	ability: AbilityData,
	actor: UnitState,
	_moving: bool,
) -> int:
	var presentation_anim: int = AbilitySystem.resolve_presentation_anim(ability, actor)
	match presentation_anim:
		GameEnums.PresentationAnim.ATTACK:
			return TacticalUnitLayer.DragPreviewAnim.ATTACK
		GameEnums.PresentationAnim.SPELL:
			return TacticalUnitLayer.DragPreviewAnim.SPELL
		GameEnums.PresentationAnim.SUPER_RUN:
			return TacticalUnitLayer.DragPreviewAnim.RUN
		GameEnums.PresentationAnim.RUN:
			return TacticalUnitLayer.DragPreviewAnim.RUN
		GameEnums.PresentationAnim.WALK:
			return TacticalUnitLayer.DragPreviewAnim.WALK
		GameEnums.PresentationAnim.NONE:
			return TacticalUnitLayer.DragPreviewAnim.IDLE
		_:
			return TacticalUnitLayer.DragPreviewAnim.SPELL


func _update_drag_sprite(local: Vector2, cell: Vector2i, preview: Dictionary) -> void:
	if _planning == null or not dragging:
		return
	var active_unit_id: int = _drag_unit_id
	if active_unit_id < 0:
		_planning.set_drag_attack_target(-1)
		return
	var drag_target_id: int = -1
	var unit := _director.board.get_unit_by_id(active_unit_id) if _director.board != null else null
	if unit == null:
		_planning.set_drag_attack_target(-1)
		return
	var emit_drag_sprite := func(
		anim_mode: int, facing: int, p_cell: Vector2i, failed: bool,
	) -> void:
		_planning.update_drag_sprite(local, anim_mode, facing, p_cell, failed, cell)
	var preview_cell: Vector2i = _drag_last_free
	if preview_state.preview_board != null:
		var pv := preview_state.preview_board.get_unit_by_id(active_unit_id)
		if pv != null:
			preview_cell = pv.position
	for event: Variant in preview.get("events", []):
		if event is SimEvent:
			var sim: SimEvent = event as SimEvent
			if (
				sim.type == GameEnums.SimEventType.ACTION_FAILED
				and int(sim.data.get("actor", -1)) == active_unit_id
			):
				emit_drag_sprite.call(
					TacticalUnitLayer.DragPreviewAnim.IDLE,
					unit.facing,
					preview_cell,
					true,
				)
				_planning.set_drag_attack_target(-1)
				return
	var actor := _proj_unit(active_unit_id)
	if actor == null:
		actor = unit
	var occ := _director.board.get_unit_at(cell)
	if occ != null and occ.is_enemy() and occ.id != active_unit_id:
		var atk_face: int = _facing_toward(_drag_last_free, occ.position)
		if _prefer_approach_over_trample_move(actor, occ) or not _can_move_to(actor, occ.position):
			drag_target_id = occ.id
			var ability := _selected_ability_data(actor)
			emit_drag_sprite.call(
				_drag_ability_preview_mode(ability, actor, false),
				atk_face,
				preview_cell,
				drag_preview_failed,
			)
			_set_drag_attack_target(drag_target_id, preview)
			return
		if _can_move_to(actor, occ.position):
			var walk_face: int = _facing_toward(actor.position, occ.position)
			emit_drag_sprite.call(_drag_move_preview_mode(actor, occ.position), walk_face, preview_cell, drag_preview_failed)
			_planning.set_drag_attack_target(-1)
			return
	if cell == actor.position and _drag_unit_was_selected:
		if _director.selected_ability_index >= 0:
			var self_ability := _selected_ability_data(actor)
			if AbilitySystem.can_target_self(actor, self_ability):
				var self_face: int = _facing_from_drop(local, cell)
				if self_face < 0:
					self_face = actor.facing
				emit_drag_sprite.call(
					_drag_ability_preview_mode(self_ability, actor, false),
					self_face,
					preview_cell,
					drag_preview_failed,
				)
				_planning.set_drag_attack_target(-1)
				return
	if _skill_commit_path_active():
		var endpoint_ability := _selected_ability_data(actor)
		if (
			endpoint_ability != null
			and _awaiting_flow_selected(actor, endpoint_ability)
			and awaiting_targeting_active()
			and AbilitySystem.planning_is_valid_awaiting_endpoint(
				_phase_entry_stand(actor), cell, endpoint_ability, actor, _proj(),
			)
		):
			var dash_face: int = _facing_toward(_phase_entry_stand(actor), cell)
			var mode: int = _drag_ability_preview_mode(endpoint_ability, actor, false)
			var dash_target := _director.board.get_unit_at(cell)
			if dash_target != null and dash_target.is_enemy():
				drag_target_id = dash_target.id
			emit_drag_sprite.call(mode, dash_face, preview_cell, drag_preview_failed)
			_set_drag_attack_target(drag_target_id, preview)
			return
	if _drag_last_free != unit.position:
		if _skill_commit_path_active():
			var move_self_ability := _selected_ability_data(actor)
			if (
				AbilitySystem.can_target_self(actor, move_self_ability)
				and not AbilitySystem.is_run_ability(move_self_ability)
			):
				var self_move_face: int = _facing_toward(unit.position, _drag_last_free)
				emit_drag_sprite.call(
					_drag_ability_preview_mode(move_self_ability, actor, true),
					self_move_face,
					preview_cell,
					drag_preview_failed,
				)
				_set_drag_attack_target(-1, preview)
				return
		var move_face: int = _facing_toward(unit.position, _drag_last_free)
		emit_drag_sprite.call(_drag_move_preview_mode(actor, _drag_last_free), move_face, preview_cell, drag_preview_failed)
		_set_drag_attack_target(-1, preview)
		return
	var idle_face: int = _facing_from_drop(local, cell)
	if idle_face < 0:
		idle_face = actor.facing
	emit_drag_sprite.call(TacticalUnitLayer.DragPreviewAnim.IDLE, idle_face, preview_cell, drag_preview_failed)
	_planning.set_drag_attack_target(-1)


func _update_drag_sprite_position(local: Vector2, cell: Vector2i) -> void:
	if _planning == null or not dragging or _drag_unit_id < 0:
		return
	var preview_cell: Vector2i = _drag_last_free
	if preview_state.preview_board != null:
		var pv := preview_state.preview_board.get_unit_by_id(_drag_unit_id)
		if pv != null:
			preview_cell = pv.position
	_planning.update_drag_sprite_position(local, preview_cell, cell)


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


func _is_invalid_dict(d: Dictionary) -> bool:
	if not d.has('invalid'):
		return false
	var v: Variant = d['invalid']
	if typeof(v) == TYPE_BOOL:
		return v
	if typeof(v) == TYPE_STRING:
		return v != ''
	return false
