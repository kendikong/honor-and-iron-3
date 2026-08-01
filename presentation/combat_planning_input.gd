class_name CombatPlanningInput
extends RefCounted

## H&I planning semantics ported from board_view — used by TacticalInputController.


var force_basic_movement: bool = false
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

const _DRAG_THRESHOLD_PX: float = 6.0
const _ABILITY_SCROLL_SETTLE_SEC: float = 0.075
const _HOVER_HEAVY_MIN_INTERVAL_SEC: float = 0.032

var _drag_unit_id: int = -1
var _drag_route: Array[Vector2i] = []
var _drag_last_free: Vector2i = Vector2i(-1, -1)
var _drag_unit_was_selected: bool = false
var _drag_saved_preview: BoardState = null
var preview_state: CombatPlanningPreview = CombatPlanningPreview.new()
var drag_sim_actor_pos: Vector2i = Vector2i.ZERO
var drag_preview_failed: bool = false
var _last_planning_hover_cell: Vector2i = Vector2i(-9999, -9999)
var _hover_preview_cache_key: String = ""
var _hover_cursor_cache_key: String = ""
var _hover_cursor_cached_icon: String = ""
var _overlay_cursor_icon: String = ""
var _overlay_cursor_cell: Vector2i = Vector2i(-9999, -9999)
var _selection_refresh_pending: bool = false
var _plan_refresh_followup_pending: bool = false
var _hover_preview_refresh_pending: bool = false
var _ability_scroll_settle_generation: int = 0
var _ability_hover_settle_pending: bool = false
var _qa_pointer_override: bool = false
var _qa_pointer_screen_pos: Vector2 = Vector2.ZERO
var _qa_pointer_grid_override: bool = false
var _qa_pointer_grid_cell: Vector2i = Vector2i.ZERO
var _hover_heavy_frame_pending: bool = false
var _hover_heavy_throttle_gen: int = 0
var _hover_heavy_last_flush_usec: int = 0
var _last_heavy_hover_refresh_cell: Vector2i = Vector2i(-9999, -9999)
var _drag_move_commit_instant: bool = false
var _drag_preview_cache_key: int = 0
var _drag_preview_cache: Dictionary = {}
var _drag_last_cursor_cell: Vector2i = Vector2i(-999999, -999999)
var _drag_last_sprite_cell: Vector2i = Vector2i(-999999, -999999)
## Last painted intent (move-preview truth) — commit ratifies these slots, does not rebuild.
var _intent_snapshot_slots: Dictionary = {}
var _intent_snapshot_key: String = ""
var _intent_snapshot_valid: bool = false
var _suppress_post_commit_hover_refresh: bool = false


func setup(
	map_view: TacticalMapView,
	director: CombatDirector,
	planning: TacticalPlanningOverlay,
	intent_state: CombatIntentState,
	sfx: SfxPlayer,
) -> void:
	_map_view = map_view
	_director = director
	_planning = planning
	_intent_state = intent_state
	_sfx = sfx
	_bind_event_bus()


func teardown() -> void:
	_disconnect_event_bus()
	_map_view = null
	_director = null
	_planning = null
	_intent_state = null
	_sfx = null


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
		_planning.clear_threat_origin()
		_planning._recompute_hover_ranges_from_inputs()
	_sync_intent_skill_mode()
	_restore_hover_preview()
	refresh_mouse_cursor(_intent_state.hover_coord if _intent_state != null else Vector2i(-999, -999))


func on_left_press(local: Vector2) -> void:
	var cell: Vector2i = _pointer_grid_cell()
	var board: BoardState = _director.board
	if board == null or not board.is_in_bounds(cell):
		cancel_aim()
		return
	var unit := _unit_at_input_cell(cell)
	if unit != null and not unit.is_enemy() and unit.is_alive():
		if NetworkManager != null and NetworkManager.is_multiplayer:
			if unit.controlling_player_id != NetworkManager.local_player_id:
				return
		if _director.selected_unit_id >= 0 and unit.id != _director.selected_unit_id:
			var caster := _proj_unit(_director.selected_unit_id)
			if caster != null and _can_target_unit_with_selected_ability(caster, unit):
				if selected_phase_action_exhausted(_director.selected_unit_id):
					_play_sfx("invalid")
				else:
					_commit_at_interaction_cell(_director.selected_unit_id, cell, local, unit.id)
				return
		if aiming and unit.id == _director.selected_unit_id:
			if not _commit_at_interaction_cell(_director.selected_unit_id, cell, local):
				_play_sfx("invalid")
			cancel_aim()
			return
		if aiming:
			cancel_aim()
		var was_selected: bool = unit.id == _director.selected_unit_id
		if not was_selected:
			_director.select_unit(unit.id)
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
	if unit != null and unit.is_enemy():
		var sel := board.get_unit_by_id(_director.selected_unit_id) if _director.selected_unit_id >= 0 else null
		if sel != null and not sel.is_enemy():
			if selected_phase_action_exhausted(sel.id):
				_director.select_unit(unit.id)
			else:
				_plan_approach_or_trample_on_enemy(
					_director.selected_unit_id, unit, local, unit.position,
				)
		else:
			_director.select_unit(unit.id)
	else:
		var sel_unit := board.get_unit_by_id(_director.selected_unit_id) if _director.selected_unit_id >= 0 else null
		if sel_unit != null and not sel_unit.is_enemy():
			if selected_phase_action_exhausted(sel_unit.id):
				return
			_commit_at_interaction_cell(_director.selected_unit_id, cell, local)


func on_left_release(local: Vector2) -> void:
	if _drag_armed and not dragging:
		_process_unit_drop(local, false)
		_cancel_drag_armed()
		return
	if not dragging:
		return
	var had_movement: bool = _drag_had_movement()
	var board: BoardState = _director.board
	var cell: Vector2i = _pointer_grid_cell()
	var actor := board.get_unit_by_id(_drag_unit_id) if board != null else null
	if actor == null or board == null or not board.is_in_bounds(cell):
		dragging = false
		_drag_unit_id = -1
		_end_drag_interaction(true, had_movement)
		return
	var committed: bool = _process_unit_drop(local, had_movement)
	dragging = false
	var snap_back: bool = had_movement and not committed
	_drag_unit_id = -1
	_end_drag_interaction(false, snap_back)


func _process_unit_drop(local: Vector2, had_movement: bool) -> bool:
	_drag_move_commit_instant = had_movement
	var released_unit_id: int = _drag_unit_id
	if selected_phase_action_exhausted(released_unit_id):
		_play_sfx("invalid")
		_drag_move_commit_instant = false
		return false
	var legal_move_tiles: Array[Vector2i] = _snapshot_drag_legal_move_tiles()
	var committed: bool = false
	var board: BoardState = _director.board
	var actor := board.get_unit_by_id(released_unit_id) if board != null else null
	var cell: Vector2i = _pointer_grid_cell()
	if actor == null or board == null or not board.is_in_bounds(cell):
		return false
	var dropped_on := _unit_at_input_cell(cell)
	if dropped_on != null and dropped_on.id != actor.id:
		if _is_selectable_player_unit(dropped_on):
			if _can_target_unit_with_selected_ability(actor, dropped_on):
				if selected_phase_action_exhausted(released_unit_id):
					_play_sfx("invalid")
				else:
					return _commit_at_interaction_cell(released_unit_id, cell, local, dropped_on.id)
			_director.select_unit(dropped_on.id)
			return false
		if selected_phase_action_exhausted(released_unit_id):
			_play_sfx("invalid")
			return false
		return _plan_approach_or_trample_on_enemy(
			released_unit_id, dropped_on, local, cell, [], legal_move_tiles,
		)
	if cell == _proj_origin(actor):
		if _drag_unit_was_selected:
			var origin_params: Dictionary = _commit_interaction_params(cell, -1)
			committed = _commit_at_cell(
				released_unit_id,
				origin_params.cell,
				local,
				origin_params.waypoints,
				origin_params.legal_move_tiles,
				origin_params.preferred,
				int(origin_params.get("face_dir", -1)),
			)
		return committed
	if dropped_on == null:
		var params: Dictionary = _commit_interaction_params(cell, -1)
		committed = _commit_at_cell(
			released_unit_id,
			params.cell,
			local,
			params.waypoints,
			params.legal_move_tiles,
			params.preferred,
			int(params.get("face_dir", -1)),
		)
	_drag_move_commit_instant = false
	return committed


func on_right_click() -> void:
	if aiming:
		cancel_aim()
		_play_sfx("cancel")
		return
	if awaiting_targeting_active():
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
	
	if _basic_move_allowed():
		_extend_drag_route(cell)
		
	if drag_unit != null and (occ == null or occ.id == _drag_unit_id):
		if cell == drag_unit.position or (_planning != null and _planning.is_hover_move_tile(cell)):
			_drag_last_free = cell
	elif (
		drag_unit != null
		and not drag_unit.is_enemy()
		and occ != null
		and occ.is_enemy()
		and MovementSystem.has_trample(drag_unit)
		and force_basic_movement
		and _planning != null
		and _planning.is_hover_move_tile(occ.position)
	):
		_drag_last_free = occ.position
	var drag_target_id: int = _drag_preview_target_id(drag_unit, occ)
	var waypoints: Array[Vector2i] = _route_waypoints()
	var cache_key: int = _drag_preview_cache_key_for(cell, drag_target_id, waypoints)
	var cache_miss: bool = cache_key != _drag_preview_cache_key
	if cache_miss:
		_drag_preview_cache_key = cache_key
		_drag_preview_cache = _preview_at_interaction_cell(
			_drag_unit_id,
			cell,
			_drag_last_free,
			drag_target_id,
			[],
			_snapshot_drag_legal_move_tiles(),
		)
		_apply_live_preview(_drag_preview_cache)
	if cache_miss or cell != _drag_last_sprite_cell:
		_update_drag_sprite(local, cell, _drag_preview_cache)
		_drag_last_sprite_cell = cell
	else:
		_update_drag_sprite_position(local, cell)
	if cell != _drag_last_cursor_cell:
		_drag_last_cursor_cell = cell
		refresh_mouse_cursor(cell)


func get_drag_unit_id() -> int:
	return _drag_unit_id


func refresh_live_preview() -> void:
	if not dragging or _drag_unit_id < 0:
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


func _apply_live_preview(preview: Dictionary) -> void:
	if preview.is_empty():
		return
	if _is_invalid_dict(preview):
		## Do not erase movement intent when the hover cell is still a valid TILE endpoint —
		## slot legality is the source of truth, not sim path / failure flags.
		if _paint_valid_movement_endpoint_intent():
			return
		drag_preview_failed = true
		_hover_preview_cache_key = ""
		preview_state.clear_interaction()
		## Drop stale spent-AP boards so UI does not keep a previous skill's preview.
		preview_state.preview_board = null
		preview_state.preview_paths.clear()
		preview_state.preview_splits.clear()
		preview_state.preview_post_splits.clear()
		preview_state.preview_pushes.clear()
		if _planning != null:
			_planning.restore_committed_display()
		_sync_intent_live_board()
		return
	preview_state.apply_result(preview, _director)
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
	## Valid movement-skill selection must keep intent geometry even if sim path is short.
	_ensure_live_movement_intent_from_preview_actions(preview)
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
		if dragging and pv_actor != null:
			_planning.set_threat_origin(pv_actor.position)
			_planning._recompute_hover_ranges_from_inputs()
	_sync_intent_live_board()


## When live preview is invalid but awaiting TILE endpoint is legal, paint that intent route.
func _paint_valid_movement_endpoint_intent() -> bool:
	if _director == null or _director.board == null:
		return false
	var unit_id: int = _drag_unit_id if dragging else _director.selected_unit_id
	if unit_id < 0:
		return false
	var actor: UnitState = _proj_unit(unit_id)
	if actor == null:
		actor = _director.board.get_unit_by_id(unit_id)
	if actor == null:
		return false
	var ability: AbilityData = _selected_ability_data(actor)
	if not _is_awaiting_movement_endpoint(actor, ability):
		return false
	var cell: Vector2i = (
		_intent_state.hover_coord if _intent_state != null else Vector2i(-999999, -999999)
	)
	if not _director.board.is_in_bounds(cell):
		return false
	var origin: Vector2i = _proj_origin(actor)
	if not AbilitySystem.planning_is_valid_awaiting_endpoint(origin, cell, ability):
		return false
	var route_wps: Array[Vector2i] = _route_waypoints()
	var action: TimelineAction = TimelineAction.make_ability(
		unit_id, ability, cell, AbilitySystem.planning_commit_target_unit_id(ability, -1),
		GameEnums.MoveTiming.PRE_ACTION, route_wps,
	)
	var base: BoardState = (
		_director.base_board.clone() if _director.base_board != null else _director.board.clone()
	)
	preview_state.preview_board = base
	preview_state.preview_paths.clear()
	preview_state.preview_splits.clear()
	preview_state.preview_post_splits.clear()
	preview_state.action_splits.clear()
	preview_state.preview_pushes.clear()
	preview_state.ensure_movement_intent_from_actions([action], base)
	drag_preview_failed = false
	drag_sim_actor_pos = cell
	if _planning != null:
		_planning.apply_preview_state(preview_state, unit_id, -1)
	_sync_intent_live_board()
	return true


func _ensure_live_movement_intent_from_preview_actions(preview: Dictionary) -> void:
	var actions_v: Variant = preview.get("actions", [])
	if not actions_v is Array or (actions_v as Array).is_empty():
		return
	var start_board: BoardState = (
		_director.base_board if _director != null and _director.base_board != null else _director.board
	)
	preview_state.ensure_movement_intent_from_actions(actions_v as Array, start_board)


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
	_invalidate_planning_hover_cache()
	_clear_drag_preview_cache()
	_stash_committed_preview()
	_clear_hover_preview()
	_sync_intent_skill_mode()
	dragging = true
	_drag_unit_id = unit.id
	_drag_unit_was_selected = was_already_selected
	_clear_planning_cursor_for_drag()
	_drag_route = [_planning_drag_origin(unit.id)]
	_drag_last_free = _drag_route[0]
	_planning.set_fixed_range_origin(_drag_route[0])
	_planning.set_threat_origin(_drag_route[0])
	_planning._recompute_hover_ranges_from_inputs()
	_planning.begin_drag_sprite(unit.id)


func _end_drag_interaction(restore_committed: bool, snap_back: bool = false) -> void:
	_invalidate_planning_hover_cache()
	_clear_drag_preview_cache()
	_drag_route.clear()
	drag_preview_failed = false
	preview_state.clear_interaction()
	if _planning != null:
		_planning.clear_drag_route()
		_planning.clear_fixed_range_origin()
		_planning.clear_threat_origin()
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
	_sync_intent_live_board()
	_sync_intent_skill_mode()
	if _intent_state != null:
		_intent_state.recompute()
	_request_planning_selection_refresh()


func _on_board_changed(board: BoardState) -> void:
	if _director == null or board != _director.board:
		return
	var interacting: bool = aiming or dragging or _drag_armed
	if not interacting:
		# Stale stash after drag ended must not restore over a committed plan.
		if _drag_saved_preview != null:
			_drag_saved_preview = null
		# Snap undo/move refresh emits preview_updated in the same flush — skip duplicate danger pass.
		if _planning != null and not _director.plan_refresh_snap_units:
			_planning.mark_danger_dirty()
		if not _director.plan_refresh_snap_units:
			_schedule_plan_refresh_followup()
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
		_planning.clear_fixed_range_origin()
		_planning.clear_threat_origin()
		_planning.end_drag_sprite()
		_planning.mark_danger_dirty()
		_planning._invalidate_hover_cache()
	_schedule_plan_refresh_followup()


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
	_drag_route.clear()
	_drag_unit_id = unit_id
	_play_sfx("select")
	call_deferred("_finish_selection_changed")


func _request_planning_selection_refresh() -> void:
	if _selection_refresh_pending:
		return
	_selection_refresh_pending = true
	call_deferred("_run_planning_selection_refresh")


func _refresh_planning_hover_at_current_cell(refresh_cursor: bool) -> void:
	if _director == null or _planning == null or not _is_planning():
		return
	var cell: Vector2i = _intent_state.hover_coord if _intent_state != null else Vector2i(-999, -999)
	if _intent_state != null:
		_sync_threat_origin_from_cell(cell)
	if _director.selected_unit_id >= 0:
		_refresh_selected_interaction_preview()
	elif _director.board != null and _director.board.is_in_bounds(cell):
		_update_hover_attack_preview()
	_planning._recompute_hover_ranges_from_inputs()
	_sync_intent_skill_mode()
	if refresh_cursor and _intent_state != null:
		refresh_mouse_cursor(cell)


func _run_planning_selection_refresh() -> void:
	_selection_refresh_pending = false
	_refresh_planning_hover_at_current_cell(true)


func _finish_selection_changed() -> void:
	if _drag_saved_preview == null and _planning != null:
		_planning.stash_committed_preview()
	_request_planning_selection_refresh()


func _on_ability_selected(_index: int) -> void:
	if _director == null:
		return
	_invalidate_planning_hover_cache(false)
	_clear_intent_snapshot()
	_sync_intent_skill_mode()
	if dragging:
		_ability_hover_settle_pending = false
		clear_awaiting_targeting()
		_request_planning_selection_refresh()
		refresh_live_preview()
		return
	_ability_hover_settle_pending = true
	_schedule_ability_settled_refresh()


func _resync_hover_after_ability_change() -> void:
	if not _is_planning() or dragging or _intent_state == null or _director.board == null:
		return
	var hover: Vector2i = _intent_state.hover_coord
	if not _director.board.is_in_bounds(hover):
		return
	_last_planning_hover_cell = Vector2i(-9999, -9999)
	_last_heavy_hover_refresh_cell = Vector2i(-9999, -9999)
	_flush_hover_heavy_sync()


func _schedule_ability_settled_refresh() -> void:
	_ability_scroll_settle_generation += 1
	var gen: int = _ability_scroll_settle_generation
	var tree: SceneTree = _map_view.get_tree() if _map_view != null else null
	if tree == null or _map_view == null or not _map_view.is_inside_tree():
		_run_ability_settled_refresh()
		return
	tree.create_timer(_ABILITY_SCROLL_SETTLE_SEC).timeout.connect(
		func() -> void:
			if gen != _ability_scroll_settle_generation:
				return
			_run_ability_settled_refresh(),
		CONNECT_ONE_SHOT,
	)


func _run_ability_settled_refresh() -> void:
	if _director == null:
		return
	_ability_hover_settle_pending = false
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
	if _director != null and _director.plan_refresh_defer_overlay:
		return
	_schedule_plan_refresh_followup()
	if _suppress_post_commit_hover_refresh:
		_suppress_post_commit_hover_refresh = false
		return
	if _director != null and _director.plan_refresh_snap_units:
		return
	_schedule_hover_preview_refresh()


func _schedule_plan_refresh_followup() -> void:
	if _plan_refresh_followup_pending:
		return
	_plan_refresh_followup_pending = true
	call_deferred("_finish_plan_refresh_followup")


func _finish_plan_refresh_followup() -> void:
	_plan_refresh_followup_pending = false
	_sync_intent_live_board()
	_sync_intent_skill_mode()
	if _intent_state != null:
		_intent_state.recompute()
	refresh_mouse_cursor(
		_intent_state.hover_coord if _intent_state != null else Vector2i(-999, -999),
	)


func _schedule_hover_preview_refresh() -> void:
	if _hover_preview_refresh_pending:
		return
	_hover_preview_refresh_pending = true
	call_deferred("_flush_hover_preview_refresh")


func _flush_hover_preview_refresh() -> void:
	_hover_preview_refresh_pending = false
	_refresh_hover_if_planning()


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


## Public alias for input controller / UI when ability changes outside EventBus order.
func invalidate_hover_preview_cache() -> void:
	_invalidate_planning_hover_cache()


func on_hover_moved(cell: Vector2i) -> void:
	if _director == null or _director.board == null:
		return
	if not dragging:
		_sync_intent_skill_mode()
		if _intent_state != null:
			_intent_state.set_hover_coord(cell)
		if _planning != null:
			_planning.set_hover_coord(cell, false)
	if not _is_planning() or dragging:
		return
	var planning_cell_changed: bool = cell != _last_planning_hover_cell
	if planning_cell_changed:
		_last_planning_hover_cell = cell
	if _director.board.is_in_bounds(cell) and _director.selected_unit_id >= 0 and planning_cell_changed:
		if dragging:
			var p_unit := _proj_unit(_director.selected_unit_id)
			if p_unit != null:
				var ability := _selected_ability_data(p_unit)
				var is_awaiting_move = awaiting_targeting_active() and ability != null and AbilitySystem.ability_has_movement_effect(ability)
				if _basic_move_allowed() or is_awaiting_move:
					if _drag_route.is_empty():
						_drag_unit_id = _director.selected_unit_id
						_drag_route = [_proj_move_origin(p_unit)]
					_extend_drag_route(cell)
	if not _director.board.is_in_bounds(cell):
		_flush_hover_heavy_sync()
		return
	if _should_restore_stand_hover_preview(cell):
		_flush_hover_heavy_sync()
		return
	_schedule_hover_heavy_refresh()


func _schedule_hover_heavy_refresh() -> void:
	if _map_view == null or not _map_view.is_inside_tree():
		_flush_hover_heavy_sync()
		return
	if _hover_heavy_frame_pending:
		return
	_hover_heavy_frame_pending = true
	call_deferred("_deferred_begin_hover_heavy_flush")


func _deferred_begin_hover_heavy_flush() -> void:
	_hover_heavy_frame_pending = false
	_begin_hover_heavy_throttled_flush()


func _begin_hover_heavy_throttled_flush() -> void:
	if _director == null or not _is_planning() or dragging:
		return
	var now_usec: int = Time.get_ticks_usec()
	var elapsed_sec: float = (
		float(now_usec - _hover_heavy_last_flush_usec) / 1_000_000.0
		if _hover_heavy_last_flush_usec > 0
		else _HOVER_HEAVY_MIN_INTERVAL_SEC
	)
	if elapsed_sec < _HOVER_HEAVY_MIN_INTERVAL_SEC:
		_hover_heavy_throttle_gen += 1
		var gen: int = _hover_heavy_throttle_gen
		var wait_sec: float = maxf(_HOVER_HEAVY_MIN_INTERVAL_SEC - elapsed_sec, 0.001)
		_map_view.get_tree().create_timer(wait_sec).timeout.connect(
			func() -> void:
				if gen != _hover_heavy_throttle_gen:
					return
				_run_hover_heavy_refresh(),
			CONNECT_ONE_SHOT,
		)
		return
	_run_hover_heavy_refresh()


func _flush_hover_heavy_sync() -> void:
	_hover_heavy_throttle_gen += 1
	_hover_heavy_frame_pending = false
	_run_hover_heavy_refresh()


func _run_hover_heavy_refresh() -> void:
	if _director == null or _director.board == null or not _is_planning() or dragging:
		return
	var cell: Vector2i = _intent_state.hover_coord if _intent_state != null else Vector2i(-999, -999)
	_hover_heavy_last_flush_usec = Time.get_ticks_usec()
	if not _director.board.is_in_bounds(cell):
		if _director.selected_unit_id >= 0:
			_restore_hover_preview()
			if _planning != null:
				_planning._recompute_hover_ranges_from_inputs()
		else:
			_sync_intent_live_board()
			if _planning != null:
				_planning._invalidate_hover_cache()
				_planning._recompute_hover_ranges_from_inputs()
		_last_heavy_hover_refresh_cell = cell
		if _planning != null:
			_planning.queue_redraw()
		refresh_mouse_cursor(cell)
		return
	var planning_cell_changed: bool = cell != _last_heavy_hover_refresh_cell
	if _director.selected_unit_id >= 0:
		if planning_cell_changed:
			_sync_threat_origin_from_cell(cell)
		if _should_refresh_hover_preview(cell, planning_cell_changed):
			_refresh_selected_interaction_preview()
	elif planning_cell_changed:
		_update_hover_attack_preview()
	if _planning != null and planning_cell_changed:
		_planning._recompute_hover_ranges_from_inputs()
	if planning_cell_changed:
		refresh_mouse_cursor(cell)
	_last_heavy_hover_refresh_cell = cell
	if _planning != null:
		_planning.queue_redraw()


func get_hover_tile_for_ui() -> Vector2i:
	if dragging:
		return _drag_last_free
	if _intent_state != null:
		return _intent_state.hover_coord
	return Vector2i(-999, -999)


func is_live_preview_active() -> bool:
	if _director == null:
		return false
	if selected_phase_action_exhausted():
		return false
	return preview_state.preview_board != null


func _should_refresh_hover_preview(cell: Vector2i, planning_cell_changed: bool) -> bool:
	if planning_cell_changed:
		return true
	if _ability_hover_settle_pending:
		return false
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
	preview_state.clear_interaction()
	preview_state.preview_board = null
	preview_state.preview_paths.clear()
	preview_state.preview_splits.clear()
	preview_state.preview_post_splits.clear()
	preview_state.preview_pushes.clear()
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
	if selected_phase_action_exhausted():
		return true
	if _unit_move_slot_open(p_unit.id) and _is_hover_move_cell(p_unit, cell):
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
				_proj_origin(p_unit), cell, dash_ab,
			)
		):
			return false
	if not p_unit.active_abilities.is_empty() and _director.selected_ability_index >= 0:
		if _is_hover_move_cell(p_unit, cell) or _hover_attack_target_id() >= 0:
			return false
	return true


func _refresh_selected_interaction_preview() -> void:
	if dragging or _director == null or _director.board == null:
		return
	var cell: Vector2i = _intent_state.hover_coord if _intent_state != null else Vector2i(-999, -999)
	if _should_restore_stand_hover_preview(cell):
		_restore_hover_preview()
		return
	var p_unit := _proj_unit(_director.selected_unit_id)
	if p_unit == null:
		_restore_hover_preview()
		return
	if _unit_move_slot_open(p_unit.id) and _is_hover_move_cell(p_unit, cell):
		_refresh_live_interaction_preview(_director.selected_unit_id, cell, -1, [])
		_refresh_click_target_highlight()
		return
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
				_proj_origin(p_unit), cell, dash_ab,
			)
		):
			_refresh_live_interaction_preview(_director.selected_unit_id, cell, -1, [])
			_refresh_click_target_highlight()
			return
	var target_id := _hover_attack_target_id()
	_refresh_live_interaction_preview(_director.selected_unit_id, cell, target_id, [])
	_refresh_click_target_highlight()


func _is_hover_move_cell(p_unit: UnitState, cell: Vector2i) -> bool:
	if p_unit == null or cell == p_unit.position:
		return false
	if _director != null and _director.board != null:
		var occ: UnitState = _director.board.get_unit_at(cell)
		if occ != null and occ.is_enemy() and not _can_move_to(p_unit, cell):
			return false
	if _planning != null and _planning.is_hover_move_tile(cell):
		return true
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
	_clear_hover_drag_route()
	if _planning != null:
		_planning.set_drag_attack_target(-1)
	preview_state.clear_interaction()
	preview_state.preview_board = null
	preview_state.preview_paths.clear()
	preview_state.preview_splits.clear()
	preview_state.preview_post_splits.clear()
	preview_state.preview_pushes.clear()
	drag_preview_failed = false
	_clear_intent_snapshot()
	if _planning != null:
		_planning.clear_threat_origin()
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
	if _should_use_awaiting_endpoint_on_input(endpoint_ability) and AbilitySystem.planning_is_valid_awaiting_endpoint(
		_proj_origin(p_unit), cell, endpoint_ability,
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
		if target != null and GridSystem.manhattan(p_unit.position, target.position) > rng:
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
		if _paint_valid_movement_endpoint_intent():
			return
		return
	preview_state.apply_result(res, _director)
	_ensure_live_movement_intent_from_preview_actions(res)
	if _planning != null:
		_planning.apply_preview_state(preview_state, _director.selected_unit_id, _hover_attack_target_id())
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
	var cache_key: String = _hover_interaction_cache_key(unit_id, cell, attack_target_id)
	if cache_key == _hover_preview_cache_key and preview_state.preview_board != null:
		return
	var res: Dictionary = _preview_at_interaction_cell(
		unit_id, cell, move_coord, attack_target_id, waypoints, _snapshot_drag_legal_move_tiles(),
	)
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


func _resolve_hover_attack_target(p_unit: UnitState, hover_unit: UnitState) -> int:
	if _skill_interaction_active() or aiming:
		if hover_unit.id == p_unit.id:
			var ability := _selected_ability_data(p_unit)
			return p_unit.id if AbilitySystem.can_target_self(p_unit, ability) else -1
		if hover_unit.is_enemy():
			var ability := _selected_ability_data(p_unit)
			if ability == null or _awaiting_flow_selected(p_unit, ability):
				return -1
			if AbilitySystem.ability_uses_attack_animation(ability):
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
	if not force_basic_movement:
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
	return _commit_at_cell(
		unit_id, target_cell, local, waypoints, legal_move_tiles, preferred_tile,
	)


const _NO_PREFERRED_APPROACH: Vector2i = Vector2i(-999999, -999999)


## Single source for commit cell, waypoints, and approach hint — cursor, preview, and drop must match.
func _drag_route_commits_active() -> bool:
	return dragging or _drag_route.size() >= 2


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
				var route_waypoints: Array[Vector2i] = _route_waypoints()
				if _enemy_hover_respects_painted_route(actor, target, ability, route_waypoints):
					waypoints = route_waypoints
					legal_moves = _snapshot_drag_legal_move_tiles()
					if _drag_last_free != commit_cell:
						preferred = _drag_last_free
	elif _drag_route_commits_active():
		waypoints = _route_waypoints()
		legal_moves = _snapshot_drag_legal_move_tiles()
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
) -> Dictionary:
	var slots: Dictionary = _build_commit_slots_at_cell(
		unit_id, cell, waypoints, legal_move_tiles, preferred_approach, face_dir,
	)
	_strip_unaffordable_premove_pairs(slots, unit_id, cell, waypoints)
	var hover_enemy: UnitState = _resolve_hover_unit_at(cell)
	if (
		hover_enemy != null
		and hover_enemy.is_enemy()
		and not waypoints.is_empty()
		and (slots.get("action", []) as Array).is_empty()
		and not (slots.get("pre", []) as Array).is_empty()
	):
		var actor := _proj_unit(unit_id)
		var ability := _selected_ability_data(actor)
		if actor != null and not _enemy_hover_respects_painted_route(
			actor, hover_enemy, ability, waypoints,
		):
			slots = _build_commit_slots_at_cell(
				unit_id, cell, [], legal_move_tiles, hover_enemy.position, face_dir,
			)
			_strip_unaffordable_premove_pairs(slots, unit_id, cell, [])
	return _finalize_commit_slots(slots, unit_id)


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
	for raw: Variant in actions:
		if raw is TimelineAction:
			var action: TimelineAction = raw as TimelineAction
			if (
				action.type == GameEnums.ActionType.ABILITY
				and action.ability != null
				and not _can_pair_run_move_with_ability(actor, cell, waypoints, action.ability)
			):
				continue
		kept.append(raw)
	slots["action"] = kept


func _commit_at_interaction_cell(
	unit_id: int,
	cell: Vector2i,
	local: Vector2,
	attack_target_id: int = -1,
) -> bool:
	var params: Dictionary = _commit_interaction_params(cell, attack_target_id)
	return _commit_at_cell(
		unit_id,
		params.cell,
		local,
		params.waypoints,
		params.legal_move_tiles,
		params.preferred,
		int(params.get("face_dir", -1)),
	)


func _commit_at_cell(
	unit_id: int,
	cell: Vector2i,
	local: Vector2,
	waypoints: Array[Vector2i] = [],
	legal_move_tiles: Array[Vector2i] = [],
	preferred_approach: Vector2i = _NO_PREFERRED_APPROACH,
	face_dir: int = -1,
) -> bool:
	_flush_hover_heavy_sync()
	if selected_phase_action_exhausted(unit_id):
		_play_sfx("invalid")
		return false
	var effective_face: int = face_dir
	if effective_face < 0:
		effective_face = _facing_from_drop(local, cell)
	var snapshot_key: String = _intent_snapshot_key_for(
		unit_id, cell, waypoints, legal_move_tiles, preferred_approach, effective_face,
	)
	var slots: Dictionary
	if (
		_intent_snapshot_valid
		and _intent_snapshot_key == snapshot_key
		and not _intent_snapshot_slots.is_empty()
	):
		slots = _duplicate_commit_slots(_intent_snapshot_slots)
	else:
		slots = _final_commit_slots_for_interaction(
			unit_id, cell, waypoints, legal_move_tiles, preferred_approach, effective_face,
		)
		_apply_facing_to_slots(slots, local, cell, unit_id)
		if not _is_invalid_dict(slots) and slots.get("_noop", false) != true:
			## Intent truth: never commit slots the player has not painted.
			_paint_intent_slots_before_commit(unit_id, slots)
			_store_intent_snapshot(snapshot_key, slots)
	if slots.get("_noop", false) == true:
		_play_sfx("ability")
		return true
	if _is_invalid_dict(slots):
		_play_sfx("invalid")
		_clear_intent_snapshot()
		return false
	_notify_drag_plan_move_committed(unit_id)
	if _director == null or not _director.commit_from_slots(unit_id, slots):
		if _drag_move_commit_instant and _director != null:
			_director.clear_planning_move_instant(unit_id)
		_play_sfx("invalid")
		return false
	_play_commit_sfx(slots)
	_promote_intent_preview_after_commit()
	_on_commit_slots_applied(unit_id, slots)
	_clear_intent_snapshot()
	return true


func _paint_intent_slots_before_commit(unit_id: int, slots: Dictionary) -> void:
	if _director == null:
		return
	var actions: Array[TimelineAction] = _actions_from_slots(slots)
	if actions.is_empty():
		return
	var res: Dictionary = _director.preview_actions(unit_id, actions)
	if _is_invalid_dict(res):
		return
	preview_state.apply_result(res, _director)
	if _planning != null:
		_planning.apply_preview_state(
			preview_state,
			unit_id,
			_hover_attack_target_id(),
		)
	_sync_intent_live_board()


func _promote_intent_preview_after_commit() -> void:
	_suppress_post_commit_hover_refresh = true
	if _planning == null:
		return
	if is_live_preview_active():
		_planning.promote_live_preview_to_committed()
		return
	if preview_state.preview_board != null:
		_planning.apply_preview_state(
			preview_state,
			_director.selected_unit_id if _director != null else -1,
			_hover_attack_target_id(),
		)
		_planning.promote_live_preview_to_committed()


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
	var legal_parts: PackedStringArray = PackedStringArray()
	var legal_sorted: Array[Vector2i] = legal_move_tiles.duplicate()
	legal_sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x or (a.x == b.x and a.y < b.y)
	)
	for cell_l: Vector2i in legal_sorted:
		legal_parts.append("%d,%d" % [cell_l.x, cell_l.y])
	return "%d|%d|%s|%s|%d|%d|%d|%s|%s|%d" % [
		plan_rev,
		unit_id,
		str(cell),
		str(preferred_approach),
		ability_index,
		face_dir,
		1 if awaiting_targeting_active() else 0,
		",".join(wp_parts),
		",".join(legal_parts),
		1 if force_basic_movement else 0,
	]


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


func _store_intent_snapshot(key: String, slots: Dictionary) -> void:
	if _is_invalid_dict(slots) or slots.get("_noop", false) == true:
		_clear_intent_snapshot()
		return
	_intent_snapshot_key = key
	_intent_snapshot_slots = _duplicate_commit_slots(slots)
	_intent_snapshot_valid = true


func _clear_intent_snapshot() -> void:
	_intent_snapshot_valid = false
	_intent_snapshot_key = ""
	_intent_snapshot_slots = {}


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
		return _proj_move_origin(actor)
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
				## Path-based facing in MovementSystem — mouse quadrant must not override travel.
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
	for raw: Variant in slots.get("action", []):
		if raw is TimelineAction:
			var action: TimelineAction = raw as TimelineAction
			if action.type != GameEnums.ActionType.ABILITY or action.ability == null:
				continue
			if action.ability.is_universal_wait():
				if _planning != null:
					_planning.clear_threat_origin()
				_director.select_ability(-1)
				return
			if action.awaiting_target:
				_preserve_ability_selection_for_action(unit_id, action)
				if _planning != null:
					_planning.clear_threat_origin()
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
				var saved_paths: Dictionary = preview_state.preview_paths.duplicate()
				clear_awaiting_targeting()
				_preserve_ability_selection_for_action(unit_id, action)
				if not saved_paths.is_empty():
					preview_state.preview_paths = saved_paths
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
	var empty_board: BoardState = (
		_director.base_board.clone() if _director != null and _director.base_board != null else BoardState.new()
	)
	if _director == null or unit_id < 0:
		_clear_intent_snapshot()
		return {"intents": [], "events": [], "temp_board": empty_board, "invalid": true}
	var effective_face: int = face_dir
	if effective_face < 0 and _map_view != null:
		effective_face = _facing_from_drop(_mouse_local_for_facing(), cell)
	var slots: Dictionary = _final_commit_slots_for_interaction(
		unit_id, cell, waypoints, legal_move_tiles, preferred_approach, effective_face,
	)
	_apply_facing_to_slots(slots, _mouse_local_for_facing(), cell, unit_id)
	if _is_invalid_dict(slots):
		_clear_intent_snapshot()
		return {"intents": [], "events": [], "temp_board": empty_board, "invalid": true}
	var snapshot_key: String = _intent_snapshot_key_for(
		unit_id, cell, waypoints, legal_move_tiles, preferred_approach, effective_face,
	)
	_store_intent_snapshot(snapshot_key, slots)
	return _director.preview_actions(unit_id, _actions_from_slots(slots))


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
	var face_dir: int = -1
	if _map_view != null:
		face_dir = _facing_from_drop(_mouse_local_for_facing(), params.cell)
	var legal_tiles: Array[Vector2i] = params.legal_move_tiles as Array[Vector2i]
	if legal_tiles.is_empty():
		legal_tiles = _snapshot_drag_legal_move_tiles()
	return _intent_snapshot_key_for(
		unit_id,
		params.cell,
		params.waypoints as Array[Vector2i],
		legal_tiles,
		params.preferred,
		face_dir,
	)


func _preview_at_interaction_cell(
	unit_id: int,
	hover_cell: Vector2i,
	_move_coord: Vector2i,
	attack_target_id: int = -1,
	_waypoints: Array[Vector2i] = [],
	legal_move_tiles: Array[Vector2i] = [],
) -> Dictionary:
	var params: Dictionary = _commit_interaction_params(hover_cell, attack_target_id)
	var tiles: Array[Vector2i] = legal_move_tiles
	if tiles.is_empty():
		tiles = params.legal_move_tiles
	return _preview_from_commit_slots_at_cell(
		unit_id,
		params.cell,
		params.waypoints,
		tiles,
		params.preferred,
		int(params.get("face_dir", -1)),
	)


func _prefer_approach_over_trample_move(actor: UnitState, enemy: UnitState) -> bool:
	if force_basic_movement:
		return false
	if actor == null or enemy == null or not enemy.is_enemy():
		return false
	if _director.selected_ability_index < 0:
		return false
	return MovementSystem.has_trample(actor) and _can_move_to(actor, enemy.position)


func _notify_drag_plan_move_committed(unit_id: int) -> void:
	if _drag_move_commit_instant and _director != null:
		_director.mark_planning_move_instant(unit_id)


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


## Post-move hover/commit — action column already spent; never re-pair selected skill.
## Exception: committed action with an open pre-move slot still uses enemy/tile approach
## commit slots (pre + action), not post-move-only placement.
func _planning_post_move_only(actor: UnitState, unit_id: int, cell: Vector2i) -> bool:
	if _director == null or actor == null or unit_id < 0:
		return false
	if not (
		_director.get_planning_move_timing(unit_id) == GameEnums.MoveTiming.POST_ACTION
		and actor.has_used_turn_action()
	):
		return false
	if _should_replan_premove_approach(unit_id, cell):
		return false
	return true


func _should_replan_premove_approach(unit_id: int, cell: Vector2i) -> bool:
	if _director == null or _director.board == null or unit_id < 0:
		return false
	if _director.unit_has_move_planned_at_timing(unit_id, GameEnums.MoveTiming.PRE_ACTION):
		return false
	if not _director.unit_has_committed_class_action(unit_id):
		return false
	var hover_unit: UnitState = _resolve_hover_unit_at(cell)
	if hover_unit != null and hover_unit.is_enemy():
		return true
	return _is_committed_action_approach_cell(unit_id, cell)


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


func _basic_move_allowed() -> bool:
	if _director != null and _director.selected_unit_id >= 0:
		if selected_phase_action_exhausted(_director.selected_unit_id):
			return false
	if force_basic_movement:
		return true
	return not _movement_blocked_by_dash()


func _movement_blocked_by_dash() -> bool:
	if _director.selected_unit_id < 0:
		return false
	var unit := _proj_unit(_director.selected_unit_id)
	if unit == null:
		unit = _director.board.get_unit_by_id(_director.selected_unit_id) if _director.board != null else null
	return unit != null and AbilitySystem.ability_blocks_basic_movement(_selected_ability_data(unit))


func _drag_max_steps(unit: UnitState) -> int:
	var max_steps: int = _move_budget(unit)
	if not force_basic_movement and _director.selected_ability_index >= 0:
		var ability := _selected_ability_data(unit)
		if ability != null and AbilitySystem.ability_has_movement_effect(ability):
			if _awaiting_flow_selected(unit, ability) and not awaiting_targeting_active():
				pass
			else:
				max_steps = ability.range_tiles
	return max_steps


func _extend_drag_route(cell: Vector2i) -> void:
	if _drag_route.is_empty():
		return
	var idx := _drag_route.find(cell)
	if idx >= 0:
		if idx < _drag_route.size() - 1:
			_drag_route = _drag_route.slice(0, idx + 1)
			_sanitize_drag_route_context()
		return
	var last: Vector2i = _drag_route[_drag_route.size() - 1]
	var board: BoardState = _proj()
	var unit := _proj_unit(_drag_unit_id)
	if unit == null:
		return
	var move_origin: Vector2i = _proj_move_origin(unit)
	var ability: AbilityData = null
	if not force_basic_movement and _director.selected_ability_index >= 0:
		ability = _selected_ability_data(unit)
	var mt := unit.definition.movement_type if unit.definition != null else GameEnums.MovementType.WALK
	var budget: int = _drag_max_steps(unit)
	var move_cost: int = MovementSystem.move_cost_for(unit)
	if GridSystem.manhattan(last, cell) != 1:
		var corridor: Array[Vector2i] = MovementSystem.drag_corridor_path(
			board, last, cell, budget, mt, move_cost, unit, ability,
		)
		for c: Vector2i in corridor:
			_append_route_tile(c)
		if not _drag_route.is_empty() and _drag_route.back() != cell:
			_repath_drag_route_to(cell, unit, board, mt, budget, move_cost, ability)
		_sanitize_drag_route_context()
		return
	_append_route_tile(cell)
	if _drag_route.back() != cell:
		## Adjacent past budget: repath within budget instead of silently ignoring.
		_repath_drag_route_to(cell, unit, board, mt, budget, move_cost, ability)
	_sanitize_drag_route_context()


func _repath_drag_route_to(
	cell: Vector2i,
	unit: UnitState,
	board: BoardState,
	mt: GameEnums.MovementType,
	budget: int,
	move_cost: int,
	ability: AbilityData,
) -> void:
	var move_origin: Vector2i = _proj_move_origin(unit)
	var path: Array[Vector2i] = MovementSystem.drag_corridor_path(
		board, move_origin, cell, budget, mt, move_cost, unit, ability,
	)
	if path.is_empty() or path.back() != cell:
		return
	_drag_route = [move_origin]
	_drag_route.append_array(path)


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
	var ability: AbilityData = null
	if not force_basic_movement and _director.selected_ability_index >= 0:
		ability = _selected_ability_data(unit)
		
	if GridSystem.manhattan(last, coord) != 1 or not MovementSystem.is_walkable_for(board, coord, unit, ability):
		return
	_drag_route.append(coord)


func _sanitize_drag_route_context() -> void:
	if _drag_route.size() <= 1:
		return
	var board: BoardState = _proj()
	var unit := _proj_unit(_drag_unit_id)
	if unit == null:
		return
	var ability: AbilityData = null
	if not force_basic_movement and _director.selected_ability_index >= 0:
		ability = _selected_ability_data(unit)
		
	var final_cell: Vector2i = _drag_route.back()
	var basic_fallback: bool = false
	if ability != null:
		var origin := _proj_origin(unit)
		if not AbilitySystem.planning_is_valid_awaiting_endpoint(origin, final_cell, ability):
			basic_fallback = true
	else:
		basic_fallback = true

	if not basic_fallback:
		return

	var waypoints: Array[Vector2i] = _route_waypoints()
	var mt := unit.definition.movement_type if unit.definition != null else GameEnums.MovementType.WALK
	var budget: int = _drag_max_steps(unit)
	var move_cost: int = MovementSystem.move_cost_for(unit)
	if not MovementSystem._is_legal_walk(board, _drag_route[0], waypoints, budget, move_cost, unit, null):
		var safe_path: Array[Vector2i] = MovementSystem.find_path(
			board, _drag_route[0], final_cell, budget, mt, move_cost, null,
		)
		if not safe_path.is_empty() and safe_path.back() == final_cell:
			_drag_route = [_drag_route[0]]
			_drag_route.append_array(safe_path)
		else:
			_drag_route = [_drag_route[0]]


func _route_waypoints() -> Array[Vector2i]:
	var waypoints: Array[Vector2i] = []
	if _drag_route.size() >= 2:
		for i: int in range(1, _drag_route.size()):
			waypoints.append(_drag_route[i])
	return _normalize_adjacent_single_step_waypoints(waypoints, _drag_route[0] if not _drag_route.is_empty() else Vector2i.ZERO)


func _normalize_adjacent_single_step_waypoints(
	waypoints: Array[Vector2i],
	origin: Vector2i,
) -> Array[Vector2i]:
	if waypoints.size() == 1 and GridSystem.manhattan(origin, waypoints[0]) == 1:
		return []
	return waypoints


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
	_drag_route.clear()
	if _planning != null:
		_planning._invalidate_hover_cache()
	_invalidate_planning_hover_cache()
	_request_planning_selection_refresh()


func _awaiting_flow_selected(actor: UnitState, ability: AbilityData) -> bool:
	return (
		ability != null
		and actor != null
		and AbilitySystem.planning_commit_flow(actor, ability)
		== GameEnums.PlanningCommitFlow.AWAITING_TARGET
	)


## True while an armed awaiting skill is choosing a movement/dash tile endpoint.
func _is_awaiting_movement_endpoint(actor: UnitState, ability: AbilityData) -> bool:
	if not awaiting_targeting_active():
		return false
	if not _awaiting_flow_selected(actor, ability):
		return false
	return (
		AbilitySystem.planning_awaiting_phase(ability)
		== GameEnums.PlanningAwaitingPhase.MOVEMENT_ENDPOINT
	)


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
	key = key * 10 + (1 if force_basic_movement else 0)
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
	if force_basic_movement or _director == null or not _director.auto_run:
		return false
	var actor := unit if unit != null else _proj_unit(_director.selected_unit_id)
	if actor == null and _director.board != null:
		actor = _director.board.get_unit_by_id(_director.selected_unit_id)
	return actor != null and AbilitySystem.can_afford_run(actor)


## Where red action-range tiles anchor — projected stand plus live move-preview stand (intent truth).
func action_range_intent_stand_cell(unit_id: int = -1) -> Vector2i:
	if _director == null:
		return Vector2i(-999999, -999999)
	if unit_id < 0:
		unit_id = _director.selected_unit_id
	if unit_id < 0:
		return Vector2i(-999999, -999999)
	var actor: UnitState = _proj_unit(unit_id)
	if actor == null and _director.board != null:
		actor = _director.board.get_unit_by_id(unit_id)
	if actor == null:
		return Vector2i(-999999, -999999)
	var projected: Vector2i = _proj_move_origin(actor)
	var ability: AbilityData = null
	if unit_id == _director.selected_unit_id:
		ability = _selected_ability_data(actor)
	if ability != null and _awaiting_flow_selected(actor, ability) and AbilitySystem.is_movement_skill(ability):
		if awaiting_targeting_active():
			return projected
		var hover: Vector2i = _intent_state.hover_coord if _intent_state != null else Vector2i(-999999, -999999)
		if _director.board.is_in_bounds(hover):
			var hover_unit: UnitState = _director.board.get_unit_at(hover)
			if (
				hover_unit != null
				and hover_unit.is_enemy()
				and AbilitySystem.planning_is_valid_awaiting_endpoint(projected, hover, ability)
			):
				return projected
	var dest: Vector2i = move_intent_destination(unit_id)
	if _director.board.is_in_bounds(dest) and dest != projected and _is_hover_move_cell(actor, dest):
		return dest
	if is_live_preview_active() and preview_state.preview_board != null:
		var live_unit: UnitState = preview_state.preview_board.get_unit_by_id(unit_id)
		if live_unit != null:
			return live_unit.position
	return projected


## Locked move intent (timeline or painted drag) used for action-range economy — not hover stand.
func _timeline_move_action_for_action_range(unit_id: int) -> TimelineAction:
	if _director == null or unit_id < 0:
		return null
	var move_timing: int = _director.get_planning_move_timing(unit_id)
	if (
		move_timing >= 0
		and _director.unit_has_move_planned_at_timing(unit_id, move_timing)
	):
		var plan: Timeline = (
			_director.plan_post_move
			if move_timing == GameEnums.MoveTiming.POST_ACTION
			else _director.plan_pre_move
		)
		var current: TimelineAction = CombatPlanningPreview.committed_move_action(
			plan, unit_id, move_timing,
		)
		if current != null:
			return current
	for timing: int in [GameEnums.MoveTiming.PRE_ACTION, GameEnums.MoveTiming.POST_ACTION]:
		if timing == move_timing:
			continue
		var plan: Timeline = (
			_director.plan_pre_move
			if timing == GameEnums.MoveTiming.PRE_ACTION
			else _director.plan_post_move
		)
		var step: TimelineAction = CombatPlanningPreview.committed_move_action(
			plan, unit_id, timing,
		)
		if step != null:
			return step
	return null


func _binding_move_action_for_action_range(unit_id: int) -> TimelineAction:
	if _director == null or unit_id < 0:
		return null
	var timeline_move: TimelineAction = _timeline_move_action_for_action_range(unit_id)
	if timeline_move != null:
		return timeline_move
	if dragging and _drag_unit_id == unit_id and _drag_route_commits_active():
		var dest: Vector2i = _drag_route[_drag_route.size() - 1]
		var params: Dictionary = _commit_interaction_params(dest, -1)
		var slots: Dictionary = _final_commit_slots_for_interaction(
			unit_id,
			params.cell as Vector2i,
			params.waypoints as Array[Vector2i],
			params.legal_move_tiles as Array[Vector2i],
			params.preferred as Vector2i,
			params.face_dir as int,
		)
		var pre_moves: Array = slots.get("pre", []) as Array
		if not pre_moves.is_empty() and pre_moves[0] is TimelineAction:
			return pre_moves[0] as TimelineAction
	if unit_id == _director.selected_unit_id and not dragging:
		var live_path: Array = preview_state.preview_paths.get(unit_id, [])
		if live_path.size() >= 2:
			var dest: Vector2i = live_path[live_path.size() - 1] as Vector2i
			var actor: UnitState = _proj_unit(unit_id)
			if actor == null or not _is_hover_move_cell(actor, dest):
				return null
			var waypoints: Array[Vector2i] = []
			for i: int in range(1, live_path.size()):
				waypoints.append(live_path[i] as Vector2i)
			var params: Dictionary = _commit_interaction_params(dest, -1)
			var slots: Dictionary = _final_commit_slots_for_interaction(
				unit_id,
				dest,
				waypoints,
				params.legal_move_tiles as Array[Vector2i],
				params.preferred as Vector2i,
				params.face_dir as int,
			)
			var hover_pre_moves: Array = slots.get("pre", []) as Array
			if not hover_pre_moves.is_empty() and hover_pre_moves[0] is TimelineAction:
				return hover_pre_moves[0] as TimelineAction
	return null


func _actor_after_binding_move_intent(
	unit_id: int,
	move_action: TimelineAction,
) -> UnitState:
	if move_action == null or _director == null:
		return null
	var origin: UnitState = _proj_unit(unit_id)
	if origin == null and _director.board != null:
		origin = _director.board.get_unit_by_id(unit_id)
	if origin == null:
		return null
	var trial: BoardState = _proj().clone()
	var trial_actor: UnitState = trial.get_unit_by_id(unit_id)
	if trial_actor == null:
		return null
	var plan: Timeline = Timeline.new()
	plan.entries.append(move_action)
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(trial, plan, events)
	for event: SimEvent in events:
		if event.type != GameEnums.SimEventType.ACTION_FAILED:
			continue
		if int(event.data.get("actor", -1)) == unit_id:
			return null
	var projected: UnitState = trial.get_unit_by_id(unit_id)
	return projected.clone() if projected != null else null


## Red tiles show only when the selected skill is legal after binding move intent or hover stand.
## Economy owner: AbilitySystem.can_plan / can_show_planning_action_range_after_premove on projected actor.
func action_range_visible_for_hover() -> bool:
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
	var binding_move: TimelineAction = _binding_move_action_for_action_range(unit_id)
	if binding_move != null:
		var after_intent: UnitState = _actor_after_binding_move_intent(unit_id, binding_move)
		if after_intent == null:
			return false
		return AbilitySystem.can_plan(after_intent, ability, board)
	if awaiting_targeting_active():
		return AbilitySystem.can_plan(actor, ability, board)
	var stand: Vector2i = action_range_intent_stand_cell(unit_id)
	return AbilitySystem.can_show_planning_action_range_after_premove(
		board, actor, ability, stand, auto_run_move,
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
	if unit_id == _director.selected_unit_id:
		var live_path: Array = preview_state.preview_paths.get(unit_id, [])
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
	for step: TimelineAction in _director.get_unit_plan_steps(unit_id):
		if step != null and step.type == GameEnums.ActionType.MOVE and step.uses_run:
			return true
	return false


## End tile for the current move intent (live path, drag route, or hover).
func move_intent_destination(unit_id: int) -> Vector2i:
	if _director == null or unit_id < 0:
		return Vector2i(-999, -999)
	var live_path: Array = preview_state.preview_paths.get(unit_id, [])
	if live_path.size() >= 2:
		return live_path[live_path.size() - 1] as Vector2i
	if dragging and _drag_unit_id == unit_id and not _drag_route.is_empty():
		return _drag_route[_drag_route.size() - 1]
	if unit_id == _director.selected_unit_id:
		var hover: Vector2i = get_hover_tile_for_ui()
		if _director.board != null and _director.board.is_in_bounds(hover):
			var actor: UnitState = _proj_unit(unit_id)
			if actor != null and _is_hover_move_cell(actor, hover):
				return hover
	return Vector2i(-999, -999)


## Single AP read for planning UI — delegates to AbilitySystem.planning_display_ap_left.
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
		unit_move_requires_run(unit_id),
		auto_run_scroll,
		auto_run_move,
		move_intent_destination(unit_id),
	)


## Single MP read for planning UI — projected economy; reject overspend display from live sim.
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
	return AbilitySystem.planning_display_mp_left(committed, live_actor, live_valid)


## Cache key for timeline ghost refresh (intent snapshot identity).
func timeline_refresh_key(unit_id: int) -> String:
	if not _hover_intent_ghost_active(unit_id):
		return ""
	return _intent_snapshot_key


## Pending plan columns that differ from committed — for timeline ghost text.
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
	return is_live_preview_active() or dragging or skill_interaction_active() or aiming


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
		match action.type:
			GameEnums.ActionType.ABILITY:
				if action.ability != null and action.ability.is_movement_kind():
					pre_moves.append(action)
				elif action.ability == null or action.ability.kind != GameEnums.AbilityKind.UNIVERSAL_WAIT:
					abilities.append(action)
			GameEnums.ActionType.MOVE, GameEnums.ActionType.FACE:
				if action.move_timing == GameEnums.MoveTiming.POST_ACTION:
					post_moves.append(action)
				else:
					pre_moves.append(action)
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
	if a.uses_run != b.uses_run or a.awaiting_target != b.awaiting_target:
		return false
	if a.move_timing != b.move_timing:
		return false
	var a_ab: StringName = a.ability.id if a.ability != null else &""
	var b_ab: StringName = b.ability.id if b.ability != null else &""
	return a_ab == b_ab


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
	if extended_move_budget_active(unit):
		return AbilitySystem.planning_move_budget(unit, true)
	return unit.movement.points_left


func _ability_range(actor: UnitState) -> int:
	var abilities := actor.active_abilities
	var idx: int = _director.selected_ability_index
	if idx < 0 or idx >= abilities.size():
		return -1
	return abilities[idx].range_tiles


func _in_ability_range(actor: UnitState, target: UnitState) -> bool:
	var rng := _ability_range(actor)
	if rng < 0:
		return false
	var actor_pos: Vector2i = _proj_origin(actor) if aiming else actor.position
	var target_pos: Vector2i = target.position
	if aiming and target.is_enemy():
		target_pos = _aim_enemy_pos(target.id)
	return GridSystem.manhattan(actor_pos, target_pos) <= rng


func _in_ability_range_of_coord(actor: UnitState, coord: Vector2i) -> bool:
	var rng := _ability_range(actor)
	if rng < 0:
		return false
	var actor_pos: Vector2i = _proj_origin(actor) if aiming else actor.position
	return GridSystem.manhattan(actor_pos, coord) <= rng


func _can_target_unit_with_selected_ability(actor: UnitState, target: UnitState) -> bool:
	if actor == null or target == null or not target.is_alive():
		return false
	if force_basic_movement or _director == null or _director.selected_ability_index < 0:
		return false
	var ability := _selected_ability_data(actor)
	if ability == null or AbilitySystem.is_run_ability(ability):
		return false
	if target.id == actor.id:
		return AbilitySystem.can_target_self(actor, ability)
	if not AbilitySystem.target_passes_mode(actor, ability, target):
		return false
	return _in_ability_range(actor, target)


func _can_move_to(unit: UnitState, coord: Vector2i) -> bool:
	if unit == null:
		return false
	var move_origin: Vector2i = _proj_move_origin(unit)
	if coord == move_origin:
		return false
	if unit.movement.points_left <= 0 and not extended_move_budget_active(unit):
		return false
	var board := _proj()
	if not MovementSystem.can_end_movement_on(board, coord, unit):
		return false
	var ability: AbilityData = null
	if not force_basic_movement and _director.selected_ability_index >= 0:
		ability = _selected_ability_data(unit)
	var mt := unit.definition.movement_type if unit.definition != null else GameEnums.MovementType.WALK
	return not MovementSystem.find_path(
		board, move_origin, coord, _move_budget(unit), mt, 1, ability,
	).is_empty()


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
	var move_origin: Vector2i = _proj_move_origin(actor)
	if cell == move_origin:
		return false
	if not legal_move_tiles.is_empty():
		return legal_move_tiles.has(cell)
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
	if legal_move_tiles.is_empty():
		return true
	var ability := _selected_ability_data(actor)
	var rng: int = 1
	if ability != null:
		rng = actor.get_ability_range(ability)
	elif _director.selected_ability_index >= 0:
		return false
	var origin: Vector2i = _proj_origin(actor)
	if GridSystem.manhattan(origin, enemy.position) <= rng:
		return true
	for tile: Vector2i in legal_move_tiles:
		if GridSystem.manhattan(tile, enemy.position) <= rng:
			return true
	return false


func _unit_at_input_cell(cell: Vector2i) -> UnitState:
	if _director == null or _director.board == null:
		return null
	var occ := _proj().get_unit_at(cell)
	if occ == null:
		return null
	return _director.board.get_unit_by_id(occ.id)


func _proj() -> BoardState:
	if _director.projected_state != null:
		return _director.projected_state
	return _director.board


func _proj_unit(unit_id: int) -> UnitState:
	if unit_id < 0:
		return null
	return _proj().get_unit_by_id(unit_id)


func _proj_origin(unit: UnitState) -> Vector2i:
	var pv := _proj_unit(unit.id)
	if pv != null:
		return pv.position
	return unit.position


## Pathfinding / drop origin — projected stand, or action end during post-move.
func _proj_move_origin(unit: UnitState) -> Vector2i:
	if _director == null or unit == null:
		return _proj_origin(unit)
	return CombatPlanningPreview.planning_move_origin_cell(_director, _proj(), unit.id)


func _planning_drag_origin(unit_id: int) -> Vector2i:
	var unit: UnitState = _proj_unit(unit_id)
	if unit == null:
		return Vector2i(-999999, -999999)
	return _proj_move_origin(unit)


func _aim_enemy_pos(unit_id: int) -> Vector2i:
	var live := _director.board.get_unit_by_id(unit_id) if _director.board != null else null
	if live == null:
		return Vector2i.ZERO
	if not aiming or not live.is_enemy():
		return live.position
	var preview_unit := _aim_enemy_board().get_unit_by_id(unit_id)
	return preview_unit.position if preview_unit != null else live.position


## Live hover enemy/unit id for skill targeting overlays (presentation only).
func hover_attack_target_id() -> int:
	return _hover_attack_target_id()


func _hover_attack_target_id() -> int:
	if _director == null or _director.board == null:
		return -1
	var cell: Vector2i = _intent_state.hover_coord if _intent_state != null else Vector2i(-999, -999)
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
	if actor == null or enemy == null or route_waypoints.is_empty():
		return false
	return _can_pair_run_move_with_ability(actor, enemy.position, route_waypoints, ability)


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
	var move_origin: Vector2i = _proj_move_origin(actor)

	# Sanitize waypoints to strip leaked ability effects (like pass-through).
	# This ensures the UI animation exactly matches the Simulator's fallback logic.
	var is_valid_basic_path := true
	for step in waypoints:
		if not MovementSystem._is_walkable_for(_proj(), step, actor, null):
			is_valid_basic_path = false
			break
			
	var safe_waypoints: Array[Vector2i] = waypoints
	if not is_valid_basic_path:
		var mt: int = actor.definition.movement_type if actor.definition != null else GameEnums.MovementType.WALK
		var budget: int = _move_budget(actor)
		var move_cost: int = MovementSystem.move_cost_for(actor)
		safe_waypoints = MovementSystem.find_path(
			_proj(), move_origin, cell, budget, mt, move_cost, null,
		)
		
	# If the original waypoints were valid (likely due to an ability pass-through leak), 
	# but we couldn't find ANY valid path to the cell using basic movement rules 
	# (e.g., going around the enemy costs more movement points than the unit has),
	# we must reject the drop entirely rather than committing an empty move.
	if safe_waypoints.is_empty() and not waypoints.is_empty() and cell != move_origin:
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
	if actor.has_used_turn_action():
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
	if selected_phase_action_exhausted(unit_id):
		slots["invalid"] = "Action already exhausted this phase."
		return slots
	var move_timing: int = _move_slot_timing_for_commit(unit_id, actor, cell)
	var ability_index: int = _director.selected_ability_index
	var ability: AbilityData = _selected_ability_data(actor)
	var hover_unit: UnitState = _resolve_hover_unit_at(cell)

	if cell == actor.position:
		return _build_self_tile_commit_slots(
			slots, actor, unit_id, ability_index, ability, face_dir,
		)

	if _planning_post_move_only(actor, unit_id, cell):
		if (
			_basic_move_allowed()
			and _unit_move_slot_open(unit_id, cell)
			and _drop_allows_move_tile(cell, legal_move_tiles, actor)
		):
			if move_timing >= 0 and not _director.unit_has_move_planned_at_timing(unit_id, move_timing):
				_append_move_to_commit_slots(slots, unit_id, cell, waypoints, actor)
		elif _skill_interaction_active() and _invalid_hover_target(actor, cell, hover_unit):
			slots["invalid"] = "Invalid target."
		return slots

	## Awaiting movement-endpoint skills (DASH etc.) commit a TILE. Occupant is incidental —
	## do not divert into enemy/ally unit-target commit slots.
	var awaiting_tile_endpoint: bool = _is_awaiting_movement_endpoint(actor, ability)

	if hover_unit != null and hover_unit.is_enemy() and not awaiting_tile_endpoint:
		return _build_enemy_commit_slots(
			slots, actor, unit_id, cell, hover_unit, ability, ability_index,
			legal_move_tiles, waypoints, preferred_approach,
		)

	if hover_unit != null and hover_unit.is_alive() and not hover_unit.is_enemy() and not awaiting_tile_endpoint:
		if (
			ability_index >= 0
			and ability != null
			and not force_basic_movement
			and _can_target_unit_with_selected_ability(actor, hover_unit)
		):
			slots["action"].append(TimelineAction.make_ability(
				unit_id,
				ability,
				hover_unit.position,
				AbilitySystem.planning_commit_target_unit_id(ability, hover_unit.id),
				GameEnums.MoveTiming.PRE_ACTION,
				[],
			))
		if _skill_interaction_active() and hover_unit.id != actor.id:
			slots["invalid"] = "Cannot target this unit with selected skill."
			return slots

	if ability_index >= 0 and ability != null and not force_basic_movement:
		var effective_waypoints: Array[Vector2i] = waypoints
		if effective_waypoints.is_empty():
			var painted: Array[Vector2i] = _route_waypoints()
			if not painted.is_empty() and painted.back() == cell:
				effective_waypoints = painted
		if effective_waypoints.is_empty() and AbilitySystem.ability_has_movement_effect(ability):
			var live_path: Array = preview_state.preview_paths.get(unit_id, [])
			var start_pos: Vector2i = _proj_origin(actor)
			effective_waypoints = CombatPlanningPreview.destination_cells_from_route(
				live_path, start_pos, cell,
			)

		if _awaiting_flow_selected(actor, ability):
			if awaiting_targeting_active():
				if AbilitySystem.planning_is_valid_awaiting_endpoint(
					_proj_origin(actor), cell, ability,
				):
					slots["action"].append(TimelineAction.make_ability(
						unit_id,
						ability,
						cell,
						AbilitySystem.planning_commit_target_unit_id(ability, -1),
						GameEnums.MoveTiming.PRE_ACTION,
						effective_waypoints,
					))
					return slots
				slots["invalid"] = "Invalid target or distance for this ability."
				return slots
		else:
			if AbilitySystem.can_target_self(actor, ability):
				if AbilitySystem.is_run_ability(ability):
					if _drop_allows_move_tile(cell, legal_move_tiles, actor):
						if move_timing >= 0 and not _director.unit_has_move_planned_at_timing(unit_id, move_timing):
							_append_move_to_commit_slots(slots, unit_id, cell, effective_waypoints, actor)
					return slots
				if _drop_allows_move_tile(cell, legal_move_tiles, actor):
					if move_timing >= 0 and not _director.unit_has_move_planned_at_timing(unit_id, move_timing):
						_append_move_to_commit_slots(slots, unit_id, cell, effective_waypoints, actor)
					_maybe_append_premove_action_pair(
						slots, unit_id, actor, cell, ability, effective_waypoints,
					)
					return slots
			if hover_unit != null and _in_ability_range(actor, hover_unit):
				slots["action"].append(
					TimelineAction.make_ability(
						unit_id,
						ability,
						hover_unit.position,
						AbilitySystem.planning_commit_target_unit_id(ability, hover_unit.id),
						GameEnums.MoveTiming.PRE_ACTION,
						effective_waypoints,
					),
				)
				return slots
			if hover_unit == null and ability.has_targeting(GameEnums.TargetingFlags.TILE):
				if _in_ability_range_of_coord(actor, cell):
					var board: BoardState = _proj()
					if AbilitySystem.has_pass_through_effects(ability) and not AbilitySystem.ability_has_movement_effect(ability):
						var path: Array[Vector2i] = MovementSystem.find_path(board, actor.position, cell, ability.range_tiles)
						if path.is_empty():
							slots["invalid"] = "No valid path to target tile."
							return slots
					slots["action"].append(
						TimelineAction.make_ability(unit_id, ability, cell, -1, GameEnums.MoveTiming.PRE_ACTION, effective_waypoints),
					)
					return slots

	if (
		_basic_move_allowed()
		and _unit_move_slot_open(unit_id, cell)
		and _drop_allows_move_tile(cell, legal_move_tiles, actor)
	):
		if move_timing >= 0 and not _director.unit_has_move_planned_at_timing(unit_id, move_timing):
			_append_move_to_commit_slots(slots, unit_id, cell, waypoints, actor)
		if ability_index >= 0 and ability != null and not force_basic_movement:
			_maybe_append_premove_action_pair(
				slots, unit_id, actor, cell, ability, waypoints,
			)
		return slots
	if _skill_interaction_active() and _invalid_hover_target(actor, cell, hover_unit):
		slots["invalid"] = "Invalid target."
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
		not force_basic_movement
		and ability_index >= 0
		and ability != null
	)
	var effective_waypoints: Array[Vector2i] = waypoints.duplicate()
	if use_skill and not AbilitySystem.target_passes_mode(actor, ability, enemy):
		slots["invalid"] = "Invalid target for this skill."
		return slots
	## Safety: movement-endpoint awaiting should be handled as a TILE above; if we still
	## land here, commit via planning_commit_target_unit_id (TILE → -1).
	if use_skill and _is_awaiting_movement_endpoint(actor, ability):
		if AbilitySystem.planning_is_valid_awaiting_endpoint(
			_proj_origin(actor), enemy.position, ability,
		):
			slots["action"].append(
				TimelineAction.make_ability(
					unit_id,
					ability,
					enemy.position,
					AbilitySystem.planning_commit_target_unit_id(ability, enemy.id),
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
		slots["action"].append(
			TimelineAction.make_ability(
				unit_id,
				ability,
				enemy.position,
				AbilitySystem.planning_commit_target_unit_id(ability, enemy.id),
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
	elif _drop_allows_move_tile(enemy.position, legal_move_tiles, actor):
		_append_move_to_commit_slots(slots, unit_id, enemy.position, waypoints, actor)
		return slots
	elif not _enemy_attackable_from_legal_tiles(actor, enemy, legal_move_tiles):
		slots["invalid"] = "Enemy is not attackable from legal move tiles."
		return slots
	if use_skill:
		if AbilitySystem.is_movement_skill(ability):
			slots["invalid"] = "Cannot pair this action with a pre-move."
			return slots
		var approach_hint: Vector2i = cell
		if preferred_approach != _NO_PREFERRED_APPROACH:
			approach_hint = preferred_approach
		var approach: Vector2i = _director.preview_approach_tile(
			unit_id, enemy.id, ability_index, approach_hint,
		)
		if approach == actor.position and not _in_ability_range(actor, enemy):
			slots["invalid"] = "Target is out of range."
			return slots
		if approach != actor.position:
			var board: BoardState = _proj()
			var approach_path: Array[Vector2i] = []
			if _enemy_hover_respects_painted_route(actor, enemy, ability, waypoints):
				approach_path = waypoints.duplicate()
			slots["pre"].append(
				_director.make_planning_move_action(
					unit_id,
					approach,
					board,
					actor,
					approach_path,
					GameEnums.MoveTiming.PRE_ACTION,
				),
			)
			if (
				not AbilitySystem.movement_requires_run(board, actor, approach, approach_path)
				or AbilitySystem.can_afford_run_for_commit(actor, ability)
			):
				slots["action"].append(
					TimelineAction.make_ability(
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
			TimelineAction.make_ability(
				unit_id,
				ability,
				enemy.position,
				AbilitySystem.planning_commit_target_unit_id(ability, enemy.id),
				GameEnums.MoveTiming.PRE_ACTION,
				[],
			),
		)
		return slots
	if _can_move_to(actor, cell):
		_append_move_to_commit_slots(slots, unit_id, cell, waypoints, actor)
		return slots
	slots["invalid"] = "Tile is not reachable."
	return slots


func _step_cursor_glyph(action: TimelineAction, _unit: UnitState = null) -> String:
	return PlanningIcons.action_glyph(action)


func _actions_from_slots(slots: Dictionary) -> Array[TimelineAction]:
	var out: Array[TimelineAction] = []
	for col: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(col, []):
			if raw is TimelineAction:
				out.append(raw as TimelineAction)
	return out


func _finalize_commit_slots(slots: Dictionary, unit_id: int) -> Dictionary:
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
	var error_reason: String = _director.preview_commit_valid(unit_id, actions) if _director != null else ""
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
	return auto_use_skill_after_move and not force_basic_movement


func _slots_with_facing_for_commit(
	unit_id: int,
	cell: Vector2i,
	local: Vector2,
	waypoints: Array[Vector2i],
	legal_move_tiles: Array[Vector2i],
	preferred_approach: Vector2i,
	face_dir: int = -1,
) -> Dictionary:
	var effective_face: int = face_dir
	if effective_face < 0:
		effective_face = _facing_from_drop(local, cell)
	var slots: Dictionary = _final_commit_slots_for_interaction(
		unit_id, cell, waypoints, legal_move_tiles, preferred_approach, effective_face,
	)
	_apply_facing_to_slots(slots, local, cell, unit_id)
	return slots


## Tile cursor: same commit slots as on_left_press would commit.
func _final_commit_slots_for_click_at_cell(
	unit_id: int,
	cell: Vector2i,
	local: Vector2,
) -> Dictionary:
	if _director == null or _director.board == null or unit_id < 0:
		return _empty_commit_slots()
	if not _director.board.is_in_bounds(cell):
		return {"invalid": "Out of bounds."}
	if selected_phase_action_exhausted(unit_id):
		return _empty_commit_slots()
	var unit_at: UnitState = _unit_at_input_cell(cell)
	if unit_at != null and not unit_at.is_enemy() and unit_at.is_alive():
		if unit_at.id != unit_id:
			var caster: UnitState = _proj_unit(unit_id)
			if caster != null and _can_target_unit_with_selected_ability(caster, unit_at):
				var params: Dictionary = _commit_interaction_params(cell, unit_at.id)
				return _slots_with_facing_for_commit(
					unit_id,
					params.cell,
					local,
					params.waypoints,
					params.legal_move_tiles,
					params.preferred,
					int(params.get("face_dir", -1)),
				)
	if unit_at != null and unit_at.is_enemy():
		var params: Dictionary = _commit_interaction_params(cell, unit_at.id)
		return _slots_with_facing_for_commit(
			unit_id,
			params.cell,
			local,
			params.waypoints,
			params.legal_move_tiles,
			params.preferred,
			int(params.get("face_dir", -1)),
		)
	var params: Dictionary = _commit_interaction_params(cell, -1)
	return _slots_with_facing_for_commit(
		unit_id,
		params.cell,
		local,
		params.waypoints,
		params.legal_move_tiles,
		params.preferred,
		int(params.get("face_dir", -1)),
	)


## Tile cursor while dragging: same commit slots as drop would commit.
func _final_commit_slots_for_drop_at_cell(
	unit_id: int,
	cell: Vector2i,
	local: Vector2,
	legal_move_tiles: Array[Vector2i],
) -> Dictionary:
	if _director == null or _director.board == null or unit_id < 0:
		return _empty_commit_slots()
	if not _director.board.is_in_bounds(cell):
		return _empty_commit_slots()
	if selected_phase_action_exhausted(unit_id):
		return _empty_commit_slots()
	var dropped_on: UnitState = _unit_at_input_cell(cell)
	if dropped_on != null and dropped_on.id != unit_id:
		if _is_selectable_player_unit(dropped_on):
			var actor: UnitState = _proj_unit(unit_id)
			if actor != null and _can_target_unit_with_selected_ability(actor, dropped_on):
				var params: Dictionary = _commit_interaction_params(cell, dropped_on.id)
				return _slots_with_facing_for_commit(
					unit_id,
					params.cell,
					local,
					params.waypoints,
					params.legal_move_tiles,
					params.preferred,
					int(params.get("face_dir", -1)),
				)
			return _empty_commit_slots()
		return _slots_with_facing_for_commit(
			unit_id, dropped_on.position, local, [], legal_move_tiles, cell,
		)
	var params: Dictionary = _commit_interaction_params(cell, -1)
	return _slots_with_facing_for_commit(
		unit_id,
		params.cell,
		local,
		params.waypoints,
		params.legal_move_tiles,
		params.preferred,
		int(params.get("face_dir", -1)),
	)


func _cursor_icon_for_commit_at_cell(
	unit: UnitState,
	cell: Vector2i,
	waypoints: Array[Vector2i] = [],
	legal_move_tiles: Array[Vector2i] = [],
	preferred_approach: Vector2i = _NO_PREFERRED_APPROACH,
	face_dir: int = -1,
) -> String:
	if unit == null:
		return ""
	var slots: Dictionary = _final_commit_slots_for_interaction(
		unit.id, cell, waypoints, legal_move_tiles, preferred_approach, face_dir,
	)
	return _cursor_icon_from_commit_slots(slots, unit)


func _hover_icon_for_cell(
	unit: UnitState,
	cell: Vector2i,
	waypoints: Array[Vector2i] = [],
	legal_move_tiles: Array[Vector2i] = [],
	preferred_approach: Vector2i = _NO_PREFERRED_APPROACH,
	face_dir: int = -1,
) -> String:
	if unit == null:
		return ""
	return _cursor_icon_for_commit_at_cell(
		unit, cell, waypoints, legal_move_tiles, preferred_approach, face_dir,
	)


func _cursor_icon_from_commit_slots(slots: Dictionary, unit: UnitState = null) -> String:
	if _is_invalid_dict(slots):
		return PlanningIcons.GLYPH_NULL
	var glyphs: PackedStringArray = []
	for col: String in ["pre", "action", "post"]:
		var steps: Array = slots.get(col, [])
		if steps.is_empty():
			continue
		var step: TimelineAction = steps[0] as TimelineAction
		if step == null:
			continue
		var glyph: String = _step_cursor_glyph(step, unit)
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
		## F5: drag preview is the unit sprite only — hide planning emoji cursor.
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
	var slots: Dictionary
	if _intent_snapshot_valid and _intent_snapshot_key == cache_key:
		slots = _duplicate_commit_slots(_intent_snapshot_slots)
	else:
		slots = _final_commit_slots_for_click_at_cell(sel_id, cell, _mouse_local_for_facing())
	var icon: String = _cursor_icon_from_commit_slots(slots, p_unit)
	_hover_cursor_cache_key = cache_key
	_hover_cursor_cached_icon = icon
	return icon


func _resolve_hover_unit_at(cell: Vector2i) -> UnitState:
	if _director == null or _director.board == null or not _director.board.is_in_bounds(cell):
		return null
	var live: UnitState = _director.board.get_unit_at(cell)
	if live == null:
		return null
	var projected: UnitState = _proj().get_unit_by_id(live.id)
	return projected if projected != null else live


func _attack_range_for(actor: UnitState) -> int:
	var ability: AbilityData = _selected_ability_data(actor)
	if ability != null:
		return actor.get_ability_range(ability)
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
	return _cursor_icon_from_commit_slots(
		_final_commit_slots_for_drop_at_cell(
			actor.id, cell, _mouse_local_for_facing(), _snapshot_drag_legal_move_tiles(),
		),
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
				_proj_origin(p_unit), cell, ability,
			)
		):
			return true
	return false


func _skill_takes_priority_over_basic_move() -> bool:
	if _director == null:
		return false
	if _run_mode_selected():
		return false
	return not force_basic_movement and _director.selected_ability_index >= 0


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


func _sync_threat_origin_from_cell(_cell: Vector2i) -> void:
	if _planning == null or dragging:
		return
	# Hover: overlay _intent_stand_origin reads live preview stand. Clear stale drag override.
	_planning.clear_threat_origin()


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
			if ability != null and AbilitySystem.ability_has_movement_effect(ability) and not AbilitySystem.ability_is_offensive_dash(ability):
				emit_drag_sprite.call(TacticalUnitLayer.DragPreviewAnim.SPELL, atk_face, preview_cell, drag_preview_failed)
			else:
				emit_drag_sprite.call(TacticalUnitLayer.DragPreviewAnim.ATTACK, atk_face, preview_cell, drag_preview_failed)
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
				emit_drag_sprite.call(TacticalUnitLayer.DragPreviewAnim.SPELL, self_face, preview_cell, drag_preview_failed)
				_planning.set_drag_attack_target(-1)
				return
	if not force_basic_movement and _director.selected_ability_index >= 0:
		var endpoint_ability := _selected_ability_data(actor)
		if (
			endpoint_ability != null
			and _awaiting_flow_selected(actor, endpoint_ability)
			and awaiting_targeting_active()
			and AbilitySystem.planning_is_valid_awaiting_endpoint(
				_proj_origin(actor), cell, endpoint_ability,
			)
		):
			var dash_face: int = _facing_toward(_proj_origin(actor), cell)
			var mode: int = (
				TacticalUnitLayer.DragPreviewAnim.ATTACK
				if AbilitySystem.ability_is_offensive_dash(endpoint_ability)
				else TacticalUnitLayer.DragPreviewAnim.SPELL
			)
			var dash_target := _director.board.get_unit_at(cell)
			if dash_target != null and dash_target.is_enemy():
				drag_target_id = dash_target.id
			emit_drag_sprite.call(mode, dash_face, preview_cell, drag_preview_failed)
			_set_drag_attack_target(drag_target_id, preview)
			return
	if _drag_last_free != unit.position:
		if not force_basic_movement and _director.selected_ability_index >= 0:
			var move_self_ability := _selected_ability_data(actor)
			if (
				AbilitySystem.can_target_self(actor, move_self_ability)
				and not AbilitySystem.is_run_ability(move_self_ability)
			):
				var self_move_face: int = _facing_toward(unit.position, _drag_last_free)
				emit_drag_sprite.call(TacticalUnitLayer.DragPreviewAnim.SPELL, self_move_face, preview_cell, drag_preview_failed)
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
