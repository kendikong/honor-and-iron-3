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

var _map_view: TacticalMapView
var _director: CombatDirector
var _planning: TacticalPlanningOverlay
var _intent_state: CombatIntentState
var _sfx: SfxPlayer

var dragging: bool = false
var aiming: bool = false
var dash_targeting: bool = false
var _drag_armed: bool = false
var _drag_press_local: Vector2 = Vector2.ZERO

const _DRAG_THRESHOLD_PX: float = 6.0
const ICON_MOVE: String = "👟"
const ICON_RUN: String = "🏃"
const ICON_ATTACK: String = "⚔️"
const ICON_SKILL: String = "🔮"
const ICON_COMPOSITE_SEP: String = "/"
const ICON_MOVE_ATTACK: String = "👟/⚔️"
const ICON_RUN_ATTACK: String = "🏃/⚔️"
const ICON_DASH: String = "💨"
const ICON_MOVE_DASH: String = "👟/💨"
const ICON_RUN_DASH: String = "🏃/💨"
const ICON_NULL: String = "∅"
const ICON_WAIT: String = "⏸"

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
var _selection_refresh_pending: bool = false
var _plan_refresh_followup_pending: bool = false
var _hover_preview_refresh_pending: bool = false
var _drag_move_commit_instant: bool = false
var _drag_preview_cache_key: int = 0
var _drag_preview_cache: Dictionary = {}
var _drag_last_cursor_cell: Vector2i = Vector2i(-999999, -999999)


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
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.ability_selected.connect(_on_ability_selected)
	EventBus.preview_updated.connect(_on_preview_updated)
	EventBus.board_changed.connect(_on_board_changed)


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
	aiming = false
	clear_dash_targeting()
	if _planning != null:
		_planning.set_aim_mode(false)
		_planning.clear_threat_origin()
		_planning._recompute_hover_ranges_from_inputs()
	_sync_intent_skill_mode()
	_restore_hover_preview()
	refresh_mouse_cursor(_intent_state.hover_coord if _intent_state != null else Vector2i(-999, -999))


func on_left_press(local: Vector2) -> void:
	var cell: Vector2i = _map_view.screen_to_grid(_map_view.get_viewport().get_mouse_position())
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
					_commit_at_cell(_director.selected_unit_id, cell, local)
				return
		if aiming and unit.id == _director.selected_unit_id:
			if not _commit_at_cell(_director.selected_unit_id, cell, local):
				_play_sfx("invalid")
			cancel_aim()
			return
		if aiming:
			cancel_aim()
		var was_selected: bool = unit.id == _director.selected_unit_id
		if was_selected and _director.selected_ability_index >= 0:
			if _commit_at_cell(unit.id, cell, local):
				return
		if not was_selected:
			_director.select_unit(unit.id)
		_arm_drag(unit, local, was_selected)
		return
	if aiming:
		var actor := _proj_unit(_director.selected_unit_id)
		if selected_phase_action_exhausted(_director.selected_unit_id):
			cancel_aim()
			return
		if actor != null and _commit_at_cell(_director.selected_unit_id, cell, local):
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
			_commit_at_cell(_director.selected_unit_id, cell, local)


func on_left_release(local: Vector2) -> void:
	if _drag_armed and not dragging:
		_process_unit_drop(local, false)
		_cancel_drag_armed()
		return
	if not dragging:
		return
	var had_movement: bool = _drag_had_movement()
	dragging = false
	var board: BoardState = _director.board
	var cell: Vector2i = _map_view.screen_to_grid(_map_view.get_viewport().get_mouse_position())
	var actor := board.get_unit_by_id(_drag_unit_id) if board != null else null
	if actor == null or board == null or not board.is_in_bounds(cell):
		_drag_unit_id = -1
		_end_drag_interaction(true, had_movement)
		return
	var committed: bool = _process_unit_drop(local, had_movement)
	var snap_back: bool = had_movement and not committed
	_drag_unit_id = -1
	_end_drag_interaction(false, snap_back)


func _process_unit_drop(local: Vector2, had_movement: bool) -> bool:
	_drag_move_commit_instant = had_movement
	var released_unit_id: int = _drag_unit_id
	var legal_move_tiles: Array[Vector2i] = _snapshot_drag_legal_move_tiles()
	var committed: bool = false
	var board: BoardState = _director.board
	var actor := board.get_unit_by_id(released_unit_id) if board != null else null
	var cell: Vector2i = _map_view.screen_to_grid(_map_view.get_viewport().get_mouse_position())
	if actor == null or board == null or not board.is_in_bounds(cell):
		return false
	var dropped_on := _unit_at_input_cell(cell)
	if dropped_on != null and dropped_on.id != actor.id:
		if _is_selectable_player_unit(dropped_on):
			if _can_target_unit_with_selected_ability(actor, dropped_on):
				if selected_phase_action_exhausted(released_unit_id):
					_play_sfx("invalid")
				else:
					return _commit_at_cell(released_unit_id, cell, local)
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
			if not had_movement:
				committed = _commit_at_cell(released_unit_id, cell, local)
			elif not _commit_at_cell(released_unit_id, cell, local):
				if _commit_face_only(released_unit_id, local, cell):
					committed = true
			else:
				committed = true
		return committed
	if dropped_on == null:
		committed = _commit_at_cell(
			released_unit_id,
			cell,
			local,
			_route_waypoints(),
			legal_move_tiles,
		)
	_drag_move_commit_instant = false
	return committed


func on_right_click() -> void:
	if aiming:
		cancel_aim()
		_play_sfx("cancel")
		return
	if dash_targeting:
		clear_dash_targeting()
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
	var board: BoardState = _director.board
	var cell: Vector2i = _map_view.screen_to_grid(_map_view.get_viewport().get_mouse_position())
	if _intent_state != null:
		_intent_state.set_hover_coord(cell)
	if board == null or not board.is_in_bounds(cell):
		_update_drag_sprite(local, cell, {})
		if cell != _drag_last_cursor_cell:
			_drag_last_cursor_cell = cell
			refresh_mouse_cursor(cell)
		return
	var occ := board.get_unit_at(cell)
	var drag_unit := board.get_unit_by_id(_drag_unit_id)
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
	if cache_key != _drag_preview_cache_key:
		_drag_preview_cache_key = cache_key
		_drag_preview_cache = _preview_at_interaction_cell(
			_drag_unit_id,
			cell,
			_drag_last_free,
			drag_target_id,
			waypoints,
			_snapshot_drag_legal_move_tiles(),
		)
		_apply_live_preview(_drag_preview_cache)
		if _planning != null:
			_planning.queue_redraw()
	_update_drag_sprite(local, cell, _drag_preview_cache)
	if cell != _drag_last_cursor_cell:
		_drag_last_cursor_cell = cell
		refresh_mouse_cursor(cell)


func get_drag_unit_id() -> int:
	return _drag_unit_id


func refresh_live_preview() -> void:
	if not dragging or _drag_unit_id < 0:
		return
	var board: BoardState = _director.board
	var cell: Vector2i = _map_view.screen_to_grid(_map_view.get_viewport().get_mouse_position())
	if not board.is_in_bounds(cell):
		return
	var occ := board.get_unit_at(cell)
	var drag_unit := board.get_unit_by_id(_drag_unit_id)
	var drag_target_id: int = _drag_preview_target_id(drag_unit, occ)
	var preview: Dictionary = _preview_at_interaction_cell(
		_drag_unit_id,
		_map_view.screen_to_grid(_map_view.get_viewport().get_mouse_position()),
		_drag_last_free,
		drag_target_id,
		_route_waypoints(),
		_snapshot_drag_legal_move_tiles(),
	)
	_apply_live_preview(preview)


func _apply_live_preview(preview: Dictionary) -> void:
	if preview.is_empty():
		return
	if bool(preview.get("invalid", false)):
		drag_preview_failed = true
		preview_state.clear_interaction()
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
	var temp_board: BoardState = preview.get("temp_board")
	var pv_actor: UnitState = temp_board.get_unit_by_id(actor_id) if temp_board != null else null
	if pv_actor != null:
		drag_sim_actor_pos = pv_actor.position
	elif dragging:
		drag_sim_actor_pos = _drag_last_free
	if preview.has("temp_board") and _planning != null:
		_planning.apply_preview_state(preview_state, _director.selected_unit_id, _hover_attack_target_id())
		if dragging and pv_actor != null:
			_planning.set_threat_origin(pv_actor.position)
			_planning._recompute_hover_ranges_from_inputs()
	_sync_intent_live_board()


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
	_cancel_drag_armed()
	_drag_armed = true
	_drag_press_local = local
	_drag_unit_id = unit.id
	_drag_unit_was_selected = was_already_selected
	_drag_route = [unit.position]
	_drag_last_free = unit.position


func _cancel_drag_armed() -> void:
	_drag_armed = false
	_drag_press_local = Vector2.ZERO
	if dragging:
		return
	_drag_unit_id = -1
	_drag_route.clear()


func _begin_drag(unit: UnitState, local: Vector2, was_already_selected: bool) -> void:
	_invalidate_planning_hover_cache()
	_clear_drag_preview_cache()
	_stash_committed_preview()
	_clear_hover_preview()
	_sync_intent_skill_mode()
	dragging = true
	_drag_unit_id = unit.id
	_drag_unit_was_selected = was_already_selected
	_drag_route = [unit.position]
	_drag_last_free = unit.position
	_planning.set_fixed_range_origin(unit.position)
	_planning.set_threat_origin(unit.position)
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
		if _planning != null:
			_planning.restore_committed_display()
	_sync_intent_live_board()
	_sync_intent_skill_mode()
	if _intent_state != null:
		_intent_state.recompute()
	_request_planning_selection_refresh()


func _on_board_changed(_board: BoardState) -> void:
	var interacting: bool = (
		aiming
		or dragging
		or _drag_armed
		or _drag_saved_preview != null
	)
	if not interacting:
		if _planning != null:
			_planning.mark_danger_dirty()
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
		clear_dash_targeting()
		_invalidate_planning_hover_cache()
		_restore_hover_preview()
		_sync_intent_skill_mode()
		if _planning != null:
			_planning._recompute_hover_ranges_from_inputs()
		return
	_play_sfx("select")
	call_deferred("_finish_selection_changed")


func _request_planning_selection_refresh() -> void:
	if _selection_refresh_pending:
		return
	_selection_refresh_pending = true
	call_deferred("_run_planning_selection_refresh")


func _run_planning_selection_refresh() -> void:
	_selection_refresh_pending = false
	if _director == null or _planning == null:
		return
	if _intent_state != null:
		_sync_threat_origin_from_cell(_intent_state.hover_coord)
	_planning._recompute_hover_ranges_from_inputs()
	_sync_intent_skill_mode()
	call_deferred("_refresh_hover_if_planning")
	if _intent_state != null:
		refresh_mouse_cursor(_intent_state.hover_coord)


func _finish_selection_changed() -> void:
	if _drag_saved_preview == null and _planning != null:
		_planning.stash_committed_preview()
	_request_planning_selection_refresh()


func _on_ability_selected(index: int) -> void:
	if _director == null:
		return
	dash_targeting = false
	if _director.selected_unit_id >= 0:
		_director.remember_unit_ability(_director.selected_unit_id, index)
	_request_planning_selection_refresh()


func _on_preview_updated(_result: SimResult) -> void:
	_drag_saved_preview = null
	if dragging:
		return
	_schedule_plan_refresh_followup()
	if _director == null or not _director.peek_movement_only_refresh():
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


func _invalidate_planning_hover_cache() -> void:
	_last_planning_hover_cell = Vector2i(-9999, -9999)
	_hover_preview_cache_key = ""


func on_hover_moved(cell: Vector2i) -> void:
	if _director == null or _director.board == null:
		return
	if not dragging:
		_sync_intent_skill_mode()
		if _intent_state != null:
			_intent_state.set_hover_coord(cell)
		if _planning != null:
			_planning.set_hover_coord(cell)
	if not _is_planning() or dragging:
		return
	var planning_cell_changed: bool = cell != _last_planning_hover_cell
	if planning_cell_changed:
		_last_planning_hover_cell = cell
	if not _director.board.is_in_bounds(cell):
		if _director.selected_unit_id >= 0:
			_restore_hover_preview()
		else:
			_sync_intent_live_board()
			if _planning != null:
				_planning._invalidate_hover_cache()
				_planning._recompute_hover_ranges_from_inputs()
		refresh_mouse_cursor(cell)
		return
	if _director.selected_unit_id >= 0:
		if planning_cell_changed:
			_refresh_selected_interaction_preview()
	elif planning_cell_changed:
		_update_hover_attack_preview()
	if _planning != null and planning_cell_changed:
		_planning._recompute_hover_ranges_from_inputs()
		_sync_threat_origin_from_cell(cell)
		_planning._recompute_hover_ranges_from_inputs()
	refresh_mouse_cursor(cell)


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
		var stand: Vector2i = _predicted_stand_tile_for_enemy_hover(cell, hover_unit)
		if stand != _proj_origin(p_unit) and _director.board.is_in_bounds(stand):
			return true
		if is_live_preview_active():
			var route: Array = preview_state.preview_paths.get(unit_id, [])
			if route.size() >= 2:
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
	if _planning != null:
		_planning.restore_committed_display()
	_sync_intent_live_board()


func clear_interaction_preview() -> void:
	_restore_hover_preview()


func _refresh_selected_interaction_preview() -> void:
	if dragging or _director == null or _director.board == null:
		return
	var cell: Vector2i = _intent_state.hover_coord if _intent_state != null else Vector2i(-999, -999)
	if _director.selected_unit_id < 0 or not _director.board.is_in_bounds(cell):
		_restore_hover_preview()
		return
	var p_unit := _proj_unit(_director.selected_unit_id)
	if p_unit == null or p_unit.is_enemy() or not p_unit.is_alive():
		_restore_hover_preview()
		return
	if selected_phase_action_exhausted():
		_restore_hover_preview()
		return
	if _unit_move_slot_open(p_unit.id) and _is_hover_move_cell(p_unit, cell):
		_refresh_live_interaction_preview(_director.selected_unit_id, cell, -1, [])
		_refresh_click_target_highlight()
		return
	if (
		_director.selected_ability_index >= 0
		and dash_targeting
		and _director.board.is_in_bounds(cell)
	):
		var dash_ab := _selected_ability_data(p_unit)
		if (
			dash_ab != null
			and _ability_has_dash(dash_ab)
			and _is_valid_dash_target(_proj_origin(p_unit), cell, _dash_steps(dash_ab))
		):
			_refresh_live_interaction_preview(_director.selected_unit_id, cell, -1, [])
			_refresh_click_target_highlight()
			return
	if not p_unit.active_abilities.is_empty() and _director.selected_ability_index >= 0:
		var target_id := _hover_attack_target_id()
		_refresh_live_interaction_preview(_director.selected_unit_id, cell, target_id, [])
		_refresh_click_target_highlight()
		return
	_restore_hover_preview()


func _is_hover_move_cell(p_unit: UnitState, cell: Vector2i) -> bool:
	if p_unit == null or cell == p_unit.position:
		return false
	if _planning != null and _planning.is_hover_move_tile(cell):
		return true
	return _can_move_to(p_unit, cell)


func _movement_icon_for(p_unit: UnitState, cell: Vector2i) -> String:
	if AbilitySystem.movement_requires_run(_proj(), p_unit, cell, []):
		return ICON_RUN
	return ICON_MOVE


func _move_attack_icon_for(p_unit: UnitState, cell: Vector2i) -> String:
	var move_icon: String = _movement_icon_for(p_unit, cell)
	if move_icon == ICON_RUN:
		return ICON_RUN_ATTACK
	return ICON_MOVE_ATTACK


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
	if _planning != null:
		_planning.set_drag_attack_target(-1)
	preview_state.clear_interaction()
	preview_state.preview_board = null
	preview_state.preview_paths.clear()
	preview_state.preview_splits.clear()
	preview_state.preview_post_splits.clear()
	preview_state.preview_pushes.clear()
	drag_preview_failed = false
	if _planning != null:
		_planning.restore_committed_display()
	_sync_intent_live_board()


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
	var dash_ab := _selected_ability_data(p_unit)
	if _should_use_dash_on_input(dash_ab) and _is_valid_dash_target(
		_proj_origin(p_unit), cell, _dash_steps(dash_ab),
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
	preview_state.apply_result(res, _director)
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
	var cur_ability: int = _director.selected_ability_index
	var cache_key: String = "%d|%d|%s|%s|%d|%d|%d" % [
		_director.plan_revision if _director != null else 0,
		unit_id,
		str(move_coord),
		str(cell),
		attack_target_id,
		cur_ability,
		1 if dash_targeting else 0,
	]
	if cache_key == _hover_preview_cache_key:
		return
	_hover_preview_cache_key = cache_key
	var res: Dictionary = _preview_at_interaction_cell(
		unit_id, cell, move_coord, attack_target_id, waypoints, _snapshot_drag_legal_move_tiles(),
	)
	drag_preview_failed = bool(res.get("invalid", false))
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


func _resolve_hover_attack_target(p_unit: UnitState, hover_unit: UnitState) -> int:
	if _skill_interaction_active() or aiming:
		if hover_unit.id == p_unit.id:
			var ability := _selected_ability_data(p_unit)
			return p_unit.id if AbilitySystem.can_target_self(p_unit, ability) else -1
		if hover_unit.is_enemy():
			var ability := _selected_ability_data(p_unit)
			if ability == null or _ability_has_dash(ability):
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


func _should_use_dash_on_input(ability: AbilityData) -> bool:
	if not dash_targeting:
		return false
	if ability == null or not _ability_has_dash(ability) or _director.selected_ability_index < 0:
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


func _commit_at_cell(
	unit_id: int,
	cell: Vector2i,
	local: Vector2,
	waypoints: Array[Vector2i] = [],
	legal_move_tiles: Array[Vector2i] = [],
	preferred_approach: Vector2i = _NO_PREFERRED_APPROACH,
) -> bool:
	if selected_phase_action_exhausted(unit_id):
		_play_sfx("invalid")
		return false
	var actor := _proj_unit(unit_id)
	if actor == null and _director != null and _director.board != null:
		actor = _director.board.get_unit_by_id(unit_id)
	if actor != null and cell == actor.position and _try_arm_dash_or_self_skill(unit_id):
		return true
	var slots: Dictionary = _finalize_commit_slots(
		_build_commit_slots_at_cell(
			unit_id, cell, waypoints, legal_move_tiles, preferred_approach,
		),
		unit_id,
	)
	if bool(slots.get("invalid", false)):
		if actor != null and cell == actor.position and _try_plan_wait(unit_id):
			_play_sfx("ability")
			return true
		_play_sfx("invalid")
		return false
	_apply_facing_to_slots(slots, local, cell)
	if _director == null or not _director.commit_from_slots(unit_id, slots):
		_play_sfx("invalid")
		return false
	_play_commit_sfx(slots)
	_on_commit_slots_applied(unit_id, slots)
	_notify_drag_plan_move_committed(unit_id)
	return true


func _try_arm_dash_or_self_skill(unit_id: int) -> bool:
	if _director == null or not _is_planning():
		return false
	if selected_phase_action_exhausted(unit_id):
		return false
	if _director.selected_ability_index < 0:
		return false
	if CombatDirector.is_wait_ability_index(_director.selected_ability_index):
		return false
	var actor := _proj_unit(unit_id)
	if actor == null and _director.board != null:
		actor = _director.board.get_unit_by_id(unit_id)
	if actor == null:
		return false
	var self_ability := _selected_ability_data(actor)
	if self_ability != null and _ability_has_dash(self_ability) and not dash_targeting:
		arm_dash_targeting()
		_play_sfx("ability")
		return true
	return false


func _apply_facing_to_slots(slots: Dictionary, local: Vector2, cell: Vector2i) -> void:
	var face_dir: int = _facing_from_drop(local, cell)
	if face_dir < 0:
		return
	for col: String in ["pre", "post"]:
		for raw: Variant in slots.get(col, []):
			if raw is TimelineAction:
				var move_action: TimelineAction = raw as TimelineAction
				if move_action.type == GameEnums.ActionType.MOVE:
					move_action.face_dir = face_dir


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
			if _ability_has_dash(action.ability):
				clear_dash_targeting()
				_director.select_ability(-1)
			elif (
				not AbilitySystem.is_run_ability(action.ability)
				and not AbilitySystem.is_wait_ability(action.ability)
			):
				_director.select_ability(-1)
			return
	_apply_auto_skill_after_move(unit_id, slots)


func _preview_from_commit_slots_at_cell(
	unit_id: int,
	cell: Vector2i,
	waypoints: Array[Vector2i] = [],
	legal_move_tiles: Array[Vector2i] = [],
	preferred_approach: Vector2i = _NO_PREFERRED_APPROACH,
) -> Dictionary:
	var empty_board: BoardState = (
		_director.base_board.clone() if _director != null and _director.base_board != null else BoardState.new()
	)
	if _director == null or unit_id < 0:
		return {"intents": [], "events": [], "temp_board": empty_board, "invalid": true}
	var slots: Dictionary = _finalize_commit_slots(
		_build_commit_slots_at_cell(
			unit_id, cell, waypoints, legal_move_tiles, preferred_approach,
		),
		unit_id,
	)
	if bool(slots.get("invalid", false)):
		return {"intents": [], "events": [], "temp_board": empty_board, "invalid": true}
	return _director.preview_actions(unit_id, _actions_from_slots(slots))


func _preview_at_interaction_cell(
	unit_id: int,
	hover_cell: Vector2i,
	move_coord: Vector2i,
	attack_target_id: int = -1,
	waypoints: Array[Vector2i] = [],
	legal_move_tiles: Array[Vector2i] = [],
) -> Dictionary:
	var preview_cell: Vector2i = hover_cell
	var preferred: Vector2i = _NO_PREFERRED_APPROACH
	if attack_target_id >= 0 and _director != null and _director.board != null:
		var target: UnitState = _director.board.get_unit_by_id(attack_target_id)
		if target != null:
			preview_cell = target.position
			if move_coord != preview_cell:
				preferred = move_coord
	elif move_coord != hover_cell:
		preview_cell = move_coord
	return _preview_from_commit_slots_at_cell(
		unit_id, preview_cell, waypoints, legal_move_tiles, preferred,
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


func _unit_move_slot_open(unit_id: int) -> bool:
	if _director == null or unit_id < 0:
		return false
	var move_timing: int = _director.get_planning_move_timing(unit_id)
	if move_timing == -1:
		return false
	return not _director.unit_has_move_planned_at_timing(unit_id, move_timing)


func _basic_move_allowed() -> bool:
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


func _extend_drag_route(cell: Vector2i) -> void:
	if _drag_route.is_empty():
		return
	var last: Vector2i = _drag_route[_drag_route.size() - 1]
	if cell == last:
		return
	if _drag_route.size() >= 2 and cell == _drag_route[_drag_route.size() - 2]:
		_drag_route.remove_at(_drag_route.size() - 1)
		return
	var board: BoardState = _director.board
	var unit := board.get_unit_by_id(_drag_unit_id)
	if unit == null:
		return
	if GridSystem.manhattan(last, cell) != 1:
		for c: Vector2i in MovementSystem.find_path(board, last, cell, 999):
			_append_route_tile(c)
		return
	_append_route_tile(cell)


func _append_route_tile(coord: Vector2i) -> void:
	var board: BoardState = _director.board
	var unit := board.get_unit_by_id(_drag_unit_id)
	if unit == null or _drag_route.is_empty():
		return
	var last: Vector2i = _drag_route[_drag_route.size() - 1]
	if coord == last:
		return
	if _drag_route.size() >= 2 and coord == _drag_route[_drag_route.size() - 2]:
		_drag_route.remove_at(_drag_route.size() - 1)
		return
	if GridSystem.manhattan(last, coord) != 1 or not MovementSystem.is_walkable_for(board, coord, unit):
		return
	if not force_basic_movement and _director.selected_ability_index >= 0:
		var occ := board.get_unit_at(coord)
		if occ != null and occ.is_enemy() and MovementSystem.has_trample(unit):
			return
	if _drag_route.size() - 1 >= _move_budget(unit):
		return
	_drag_route.append(coord)


func _route_waypoints() -> Array[Vector2i]:
	var waypoints: Array[Vector2i] = []
	if _drag_route.size() >= 2:
		for i: int in range(1, _drag_route.size()):
			waypoints.append(_drag_route[i])
	return waypoints


func dash_targeting_active() -> bool:
	return dash_targeting


func arm_dash_targeting() -> void:
	if _director == null or _director.selected_ability_index < 0:
		return
	var actor := _proj_unit(_director.selected_unit_id)
	if actor == null and _director.board != null:
		actor = _director.board.get_unit_by_id(_director.selected_unit_id)
	if actor == null or not _ability_has_dash(_selected_ability_data(actor)):
		return
	if selected_phase_action_exhausted(actor.id):
		return
	dash_targeting = true
	if _planning != null:
		_planning.clear_threat_origin()
	_invalidate_planning_hover_cache()
	_request_planning_selection_refresh()


func clear_dash_targeting() -> void:
	if not dash_targeting:
		return
	dash_targeting = false
	_invalidate_planning_hover_cache()
	_request_planning_selection_refresh()


func _dash_steps(ability: AbilityData) -> int:
	return AbilitySystem.dash_steps(ability)


func _slots_include_move(slots: Dictionary) -> bool:
	for col: String in ["pre", "post"]:
		for raw: Variant in slots.get(col, []):
			if raw is TimelineAction and (raw as TimelineAction).type == GameEnums.ActionType.MOVE:
				return true
	return false


## Auto Skill After Move: one post-commit hook (move-only slots + dash still selected → arm dash).
func _apply_auto_skill_after_move(unit_id: int, slots: Dictionary) -> void:
	if not _composite_cursors_enabled() or _director == null:
		return
	if unit_id != _director.selected_unit_id or not _slots_include_move(slots):
		return
	if selected_phase_action_exhausted(unit_id):
		return
	if _director.selected_ability_index < 0 or dash_targeting:
		return
	var actor := _proj_unit(unit_id)
	if actor == null and _director.board != null:
		actor = _director.board.get_unit_by_id(unit_id)
	if actor == null:
		return
	var ability := _selected_ability_data(actor)
	if ability != null and _ability_has_dash(ability):
		arm_dash_targeting()


func _ability_has_dash(ability: AbilityData) -> bool:
	return AbilitySystem.ability_has_dash(ability)


func _drag_had_movement() -> bool:
	if _drag_route.is_empty():
		return false
	return _drag_last_free != _drag_route[0]


func _clear_drag_preview_cache() -> void:
	_drag_preview_cache_key = 0
	_drag_preview_cache = {}
	_drag_last_cursor_cell = Vector2i(-999999, -999999)


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


func _commit_face_only(unit_id: int, local: Vector2, cell: Vector2i) -> bool:
	var face_dir: int = _facing_from_drop(local, cell)
	if face_dir < 0 or _director == null:
		return false
	var slots: Dictionary = _empty_commit_slots()
	slots["action"].append(TimelineAction.make_face(unit_id, face_dir))
	slots = _finalize_commit_slots(slots, unit_id)
	if bool(slots.get("invalid", false)):
		return false
	if not _director.commit_from_slots(unit_id, slots):
		return false
	_play_sfx("move")
	return true


func _try_plan_wait(unit_id: int) -> bool:
	if _director == null or not _is_planning():
		return false
	if selected_phase_action_exhausted(unit_id):
		_play_sfx("invalid")
		return false
	_director.rpc_plan_wait(unit_id)
	if _planning != null:
		_planning.clear_threat_origin()
	_director.select_ability(-1)
	return true


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


func _is_valid_dash_target(actor_pos: Vector2i, coord: Vector2i, max_range: int) -> bool:
	if coord == actor_pos or max_range <= 0:
		return false
	var delta := coord - actor_pos
	if delta.x != 0 and delta.y != 0:
		return false
	var dist := GridSystem.manhattan(actor_pos, coord)
	return dist >= 1 and dist <= max_range


func _in_ability_range(actor: UnitState, target: UnitState) -> bool:
	var rng := _ability_range(actor)
	if rng < 0:
		return false
	var actor_pos: Vector2i = _proj_origin(actor) if aiming else actor.position
	var target_pos: Vector2i = target.position
	if aiming and target.is_enemy():
		target_pos = _aim_enemy_pos(target.id)
	return GridSystem.manhattan(actor_pos, target_pos) <= rng


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
	if unit == null or coord == unit.position:
		return false
	if unit.movement.points_left <= 0 and not extended_move_budget_active(unit):
		return false
	var board := _proj()
	if not MovementSystem.can_end_movement_on(board, coord, unit):
		return false
	return not MovementSystem.find_path(board, unit.position, coord, _move_budget(unit)).is_empty()


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


func _aim_enemy_pos(unit_id: int) -> Vector2i:
	var live := _director.board.get_unit_by_id(unit_id) if _director.board != null else null
	if live == null:
		return Vector2i.ZERO
	if not aiming or not live.is_enemy():
		return live.position
	var preview_unit := _aim_enemy_board().get_unit_by_id(unit_id)
	return preview_unit.position if preview_unit != null else live.position


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
	if _sfx != null:
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


func _append_move_to_commit_slots(
	slots: Dictionary,
	unit_id: int,
	cell: Vector2i,
	waypoints: Array[Vector2i],
	actor: UnitState,
) -> void:
	if _director == null or actor == null:
		return
	var timing: int = _director.get_planning_move_timing(unit_id)
	if timing < 0:
		return
	var move: TimelineAction = TimelineAction.make_move(unit_id, cell, -1, waypoints, timing)
	if AbilitySystem.movement_requires_run(_proj(), actor, cell, waypoints):
		if _run_mode_selected(actor) or auto_run_movement_active(actor):
			move = TimelineAction.make_run_move(unit_id, cell, -1, waypoints, timing)
		else:
			slots["invalid"] = true
			return
	var col: String = "post" if timing == GameEnums.MoveTiming.POST_ACTION else "pre"
	slots[col].append(move)


func _build_commit_slots_at_cell(
	unit_id: int,
	cell: Vector2i,
	waypoints: Array[Vector2i] = [],
	legal_move_tiles: Array[Vector2i] = [],
	preferred_approach: Vector2i = _NO_PREFERRED_APPROACH,
) -> Dictionary:
	var slots: Dictionary = _empty_commit_slots()
	if _director == null or unit_id < 0 or _director.board == null:
		return slots
	if not _director.board.is_in_bounds(cell):
		slots["invalid"] = true
		return slots
	var actor: UnitState = _proj_unit(unit_id)
	if actor == null:
		actor = _director.board.get_unit_by_id(unit_id)
	if actor == null or actor.is_enemy() or not actor.is_alive():
		return slots
	if selected_phase_action_exhausted(unit_id):
		slots["invalid"] = true
		return slots
	var timing: int = _director.get_planning_move_timing(unit_id)
	var ability_index: int = _director.selected_ability_index
	var ability: AbilityData = _selected_ability_data(actor)
	var hover_unit: UnitState = _resolve_hover_unit_at(cell)

	if cell == actor.position:
		if CombatDirector.is_wait_ability_index(ability_index):
			if ability != null:
				slots["action"].append(
					TimelineAction.make_ability(unit_id, ability, cell, unit_id),
				)
		elif (
			ability != null
			and AbilitySystem.can_target_self(actor, ability)
			and not AbilitySystem.is_run_ability(ability)
		):
			slots["action"].append(
				TimelineAction.make_ability(unit_id, ability, cell, unit_id),
			)
		return slots

	if hover_unit != null and hover_unit.is_enemy():
		return _build_enemy_commit_slots(
			slots, actor, unit_id, cell, hover_unit, ability, ability_index,
			legal_move_tiles, waypoints, preferred_approach,
		)

	if hover_unit != null and hover_unit.is_alive() and not hover_unit.is_enemy():
		if (
			ability_index >= 0
			and ability != null
			and not force_basic_movement
			and _can_target_unit_with_selected_ability(actor, hover_unit)
		):
			slots["action"].append(
				TimelineAction.make_ability(unit_id, ability, hover_unit.position, hover_unit.id),
			)
			return slots
		if _skill_interaction_active() and hover_unit.id != actor.id:
			slots["invalid"] = true
		return slots

	if ability_index >= 0 and ability != null and not force_basic_movement:
		if _ability_has_dash(ability):
			if dash_targeting and _is_valid_dash_target(_proj_origin(actor), cell, _dash_steps(ability)):
				slots["action"].append(TimelineAction.make_ability(unit_id, ability, cell, -1))
				return slots
			if dash_targeting:
				slots["invalid"] = true
				return slots
		if AbilitySystem.can_target_self(actor, ability):
			if AbilitySystem.is_run_ability(ability):
				if _drop_allows_move_tile(cell, legal_move_tiles, actor):
					if timing >= 0 and not _director.unit_has_move_planned_at_timing(unit_id, timing):
						_append_move_to_commit_slots(slots, unit_id, cell, waypoints, actor)
				return slots
			if _drop_allows_move_tile(cell, legal_move_tiles, actor):
				if timing >= 0 and not _director.unit_has_move_planned_at_timing(unit_id, timing):
					_append_move_to_commit_slots(slots, unit_id, cell, waypoints, actor)
				if (
					_composite_cursors_enabled()
					and _can_pair_run_move_with_ability(actor, cell, waypoints, ability)
				):
					slots["action"].append(
						TimelineAction.make_ability(unit_id, ability, cell, unit_id),
					)
				return slots
		if hover_unit != null and _in_ability_range(actor, hover_unit):
			slots["action"].append(
				TimelineAction.make_ability(unit_id, ability, hover_unit.position, hover_unit.id),
			)
			return slots

	if (
		_basic_move_allowed()
		and _unit_move_slot_open(unit_id)
		and _drop_allows_move_tile(cell, legal_move_tiles, actor)
	):
		if timing >= 0 and not _director.unit_has_move_planned_at_timing(unit_id, timing):
			_append_move_to_commit_slots(slots, unit_id, cell, waypoints, actor)
		return slots

	if _skill_interaction_active() and _invalid_hover_target(actor, cell, hover_unit):
		slots["invalid"] = true
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
	if use_skill and not AbilitySystem.target_passes_mode(actor, ability, enemy):
		slots["invalid"] = true
		return slots
	if use_skill and _ability_has_dash(ability):
		if dash_targeting and _is_valid_dash_target(_proj_origin(actor), enemy.position, _dash_steps(ability)):
			slots["action"].append(
				TimelineAction.make_ability(unit_id, ability, enemy.position, enemy.id),
			)
			return slots
		if dash_targeting:
			slots["invalid"] = true
			return slots
	if use_skill and _in_ability_range(actor, enemy):
		slots["action"].append(
			TimelineAction.make_ability(unit_id, ability, enemy.position, enemy.id),
		)
		return slots
	if not use_skill and _in_attack_range_from(_proj_origin(actor), enemy, actor):
		var basic: AbilityData = actor.active_abilities[0] if not actor.active_abilities.is_empty() else null
		if basic != null:
			slots["action"].append(
				TimelineAction.make_ability(unit_id, basic, enemy.position, enemy.id),
			)
		return slots
	if use_skill and _prefer_approach_over_trample_move(actor, enemy):
		if not _enemy_attackable_from_legal_tiles(actor, enemy, legal_move_tiles):
			slots["invalid"] = true
			return slots
	elif _drop_allows_move_tile(enemy.position, legal_move_tiles, actor):
		_append_move_to_commit_slots(slots, unit_id, enemy.position, waypoints, actor)
		return slots
	elif not _enemy_attackable_from_legal_tiles(actor, enemy, legal_move_tiles):
		slots["invalid"] = true
		return slots
	if use_skill:
		var approach_hint: Vector2i = cell
		if preferred_approach != _NO_PREFERRED_APPROACH:
			approach_hint = preferred_approach
		var approach: Vector2i = _director.preview_approach_tile(
			unit_id, enemy.id, ability_index, approach_hint,
		)
		if approach == actor.position and not _in_ability_range(actor, enemy):
			slots["invalid"] = true
			return slots
		if approach != actor.position:
			var board: BoardState = _proj()
			var budget: int = _director.planning_move_budget(actor, board)
			var path: Array[Vector2i] = MovementSystem.find_path(
				board, actor.position, approach, budget,
			)
			if path.is_empty():
				slots["invalid"] = true
				return slots
			slots["pre"].append(
				_director.make_planning_move_action(
					unit_id,
					approach,
					board,
					actor,
					path,
					GameEnums.MoveTiming.PRE_ACTION,
				),
			)
			if AbilitySystem.movement_requires_run(board, actor, approach, path):
				if AbilitySystem.can_afford_run_for_commit(actor, ability):
					slots["action"].append(
						TimelineAction.make_ability(unit_id, ability, enemy.position, enemy.id),
					)
				return slots
		slots["action"].append(
			TimelineAction.make_ability(unit_id, ability, enemy.position, enemy.id),
		)
		return slots
	if _can_move_to(actor, cell) or _is_hover_move_cell(actor, cell):
		_append_move_to_commit_slots(slots, unit_id, cell, waypoints, actor)
		return slots
	slots["invalid"] = true
	return slots


func _step_cursor_glyph(action: TimelineAction, _unit: UnitState = null) -> String:
	if action == null:
		return ""
	match action.type:
		GameEnums.ActionType.MOVE:
			return ICON_RUN if action.uses_run else ICON_MOVE
		GameEnums.ActionType.ABILITY:
			if action.ability == null:
				return ICON_SKILL
			if DataLibrary.is_universal_wait(action.ability.id):
				return ICON_WAIT
			return _ability_action_icon(action.ability)
		GameEnums.ActionType.FACE:
			return "👀"
	return ""


func _actions_from_slots(slots: Dictionary) -> Array[TimelineAction]:
	var out: Array[TimelineAction] = []
	for col: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(col, []):
			if raw is TimelineAction:
				out.append(raw as TimelineAction)
	return out


func _finalize_commit_slots(slots: Dictionary, unit_id: int) -> Dictionary:
	if bool(slots.get("invalid", false)):
		return slots
	var actions: Array[TimelineAction] = _actions_from_slots(slots)
	if actions.is_empty():
		slots["invalid"] = true
		return slots
	if _director != null and not _director.preview_commit_valid(unit_id, actions):
		slots["invalid"] = true
		return slots
	slots["_preview_validated"] = true
	return slots


func _composite_cursors_enabled() -> bool:
	return auto_use_skill_after_move and not force_basic_movement


func _cursor_icon_for_commit_at_cell(
	unit: UnitState,
	cell: Vector2i,
	waypoints: Array[Vector2i] = [],
	legal_move_tiles: Array[Vector2i] = [],
	preferred_approach: Vector2i = _NO_PREFERRED_APPROACH,
) -> String:
	if unit == null:
		return ""
	var slots: Dictionary = _finalize_commit_slots(
		_build_commit_slots_at_cell(
			unit.id, cell, waypoints, legal_move_tiles, preferred_approach,
		),
		unit.id,
	)
	return _cursor_icon_from_commit_slots(slots, unit)


func _would_arm_dash_on_self_click(unit: UnitState) -> bool:
	if _director == null or selected_phase_action_exhausted(unit.id):
		return false
	if _director.selected_ability_index < 0:
		return false
	if CombatDirector.is_wait_ability_index(_director.selected_ability_index):
		return false
	var ability := _selected_ability_data(unit)
	return ability != null and _ability_has_dash(ability) and not dash_targeting


func _would_show_wait_on_self_click(unit: UnitState) -> bool:
	if _director == null or not _is_planning():
		return false
	if selected_phase_action_exhausted(unit.id):
		return false
	if _director.selected_ability_index >= 0:
		if CombatDirector.is_wait_ability_index(_director.selected_ability_index):
			return true
		return false
	return true


func _would_commit_face_on_self(unit: UnitState, cell: Vector2i) -> bool:
	if unit == null or cell != unit.position or not dragging or _map_view == null:
		return false
	if _drag_unit_id >= 0 and unit.id != _drag_unit_id:
		return false
	var local: Vector2 = _map_view.get_local_mouse_position()
	return _facing_from_drop(local, cell) >= 0


func _hover_icon_for_cell(
	unit: UnitState,
	cell: Vector2i,
	waypoints: Array[Vector2i] = [],
	legal_move_tiles: Array[Vector2i] = [],
	preferred_approach: Vector2i = _NO_PREFERRED_APPROACH,
) -> String:
	if unit == null:
		return ""
	if cell == unit.position and _would_arm_dash_on_self_click(unit):
		return ICON_DASH
	var icon: String = _cursor_icon_for_commit_at_cell(
		unit, cell, waypoints, legal_move_tiles, preferred_approach,
	)
	if icon != "" and icon != ICON_NULL:
		return icon
	if cell == unit.position and _would_show_wait_on_self_click(unit):
		return ICON_WAIT
	if _would_commit_face_on_self(unit, cell):
		return "👀"
	return ICON_NULL if cell != unit.position else ""


func _cursor_icon_from_commit_slots(slots: Dictionary, unit: UnitState = null) -> String:
	if bool(slots.get("invalid", false)):
		return ICON_NULL
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
	return ICON_COMPOSITE_SEP.join(glyphs)


func refresh_mouse_cursor(cell: Vector2i) -> void:
	var icon: String = compute_hover_action_icon(cell)
	if _planning != null:
		_planning.set_hover_action_icon(icon)
	if icon != "":
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func compute_hover_action_icon(cell: Vector2i) -> String:
	return _compute_hover_action_icon(cell)


func _compute_hover_action_icon(cell: Vector2i) -> String:
	if _director == null or _director.board == null or not _director.board.is_in_bounds(cell):
		return ""
	if dragging:
		if _drag_unit_was_selected and _drag_unit_id >= 0:
			var drag_unit := _director.board.get_unit_by_id(_drag_unit_id)
			if drag_unit != null and not drag_unit.is_enemy():
				var actor := _proj_unit(drag_unit.id)
				if actor == null:
					actor = drag_unit
				return _drag_hover_icon(actor, cell)
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
	var legal_moves: Array[Vector2i] = _snapshot_drag_legal_move_tiles()
	return _hover_icon_for_cell(p_unit, cell, [], legal_moves)


func _resolve_hover_unit_at(cell: Vector2i) -> UnitState:
	if _director == null or _director.board == null or not _director.board.is_in_bounds(cell):
		return null
	var live: UnitState = _director.board.get_unit_at(cell)
	if live == null:
		return null
	var projected: UnitState = _proj().get_unit_by_id(live.id)
	return projected if projected != null else live


func _move_hover_icon(p_unit: UnitState, cell: Vector2i) -> String:
	if cell == p_unit.position:
		return ""
	if not _basic_move_allowed() or not _unit_move_slot_open(p_unit.id):
		return ""
	var legal_moves: Array[Vector2i] = _snapshot_drag_legal_move_tiles()
	return _hover_icon_for_cell(p_unit, cell, [], legal_moves)


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


func _move_attack_hover_icon(
	p_unit: UnitState,
	cell: Vector2i,
	_origin: Vector2i = Vector2i(-9999, -9999),
) -> String:
	if not _composite_cursors_enabled():
		return ""
	if p_unit == null or cell == p_unit.position:
		return ""
	if _move_hover_icon(p_unit, cell) == "" and not (dragging and cell == _drag_last_free):
		return ""
	# Clicking a move tile only queues movement. Move+attack comes from enemy click or drag preview.
	if not dragging or not _drag_preview_includes_attack(p_unit.id):
		return ""
	return ICON_MOVE_ATTACK


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
	if drag_preview_failed:
		return ICON_NULL
	var legal_moves: Array[Vector2i] = _snapshot_drag_legal_move_tiles()
	var drag_target_id: int = -1
	if _director != null and _director.board != null:
		var occ := _director.board.get_unit_at(cell)
		drag_target_id = _drag_preview_target_id(actor, occ)
	var preferred: Vector2i = _NO_PREFERRED_APPROACH
	var preview_cell: Vector2i = cell
	if drag_target_id >= 0 and _director.board != null:
		var target := _director.board.get_unit_by_id(drag_target_id)
		if target != null:
			preview_cell = target.position
			if _drag_last_free != preview_cell:
				preferred = _drag_last_free
	elif _drag_last_free != cell:
		preview_cell = _drag_last_free
	return _hover_icon_for_cell(actor, preview_cell, _drag_route, legal_moves, preferred)


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
	if _ability_has_dash(ability) and _planning != null:
		if dash_targeting and (
			_planning.is_hover_action_range_tile(cell)
			and not _is_valid_dash_target(_proj_origin(p_unit), cell, _dash_steps(ability))
		):
			return true
	return false


func _ability_action_icon(ability: AbilityData) -> String:
	if ability == null:
		return ""
	if AbilitySystem.is_wait_ability(ability):
		return ICON_WAIT
	if AbilitySystem.ability_is_offensive_dash(ability):
		return ICON_ATTACK
	if AbilitySystem.ability_has_dash(ability):
		return ICON_DASH
	for eff: EffectData in ability.effects:
		match eff.type:
			GameEnums.EffectType.DAMAGE:
				return ICON_ATTACK
			GameEnums.EffectType.HEAL:
				return "💚"
			GameEnums.EffectType.ARMOR_UP:
				return "🛡️"
			GameEnums.EffectType.SWAP:
				return "🔄"
	return ICON_SKILL


func _skill_takes_priority_over_basic_move() -> bool:
	if _director == null:
		return false
	if _run_mode_selected():
		return false
	return not force_basic_movement and _director.selected_ability_index >= 0


func _skill_interaction_active() -> bool:
	return _skill_takes_priority_over_basic_move() and _director.selected_unit_id >= 0 and not dragging


func _threat_follows_cursor() -> bool:
	if aiming:
		return true
	if dash_targeting:
		return false
	if not _skill_interaction_active():
		return false
	if _director == null or _director.selected_unit_id < 0:
		return false
	if _intent_state != null and _director.board != null:
		var cell: Vector2i = _intent_state.hover_coord
		if _director.board.is_in_bounds(cell):
			var hover_unit: UnitState = _director.board.get_unit_at(cell)
			if hover_unit != null and hover_unit.is_enemy():
				return false
	# After pre-move, action range is from the unit — not hypothetical move destinations.
	if not _unit_move_slot_open(_director.selected_unit_id):
		return false
	return true


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
	if is_live_preview_active() and preview_state.preview_board != null:
		var pv: UnitState = preview_state.preview_board.get_unit_by_id(unit_id)
		if pv != null:
			return pv.position
	var ability_index: int = _director.selected_ability_index
	if ability_index >= 0:
		if _in_ability_range(actor, enemy):
			return origin
		return _director.preview_approach_tile(unit_id, enemy.id, ability_index, cell)
	if _in_attack_range_from(origin, enemy, actor):
		return origin
	if actor.active_abilities.is_empty():
		return origin
	return _director.preview_approach_tile(unit_id, enemy.id, 0, cell)


func _sync_threat_origin_from_cell(cell: Vector2i) -> void:
	if _planning == null or _director == null or _director.board == null or dragging:
		return
	if _director.board.is_in_bounds(cell):
		var hover_unit: UnitState = _director.board.get_unit_at(cell)
		if hover_unit != null and hover_unit.is_enemy():
			var stand: Vector2i = _predicted_stand_tile_for_enemy_hover(cell, hover_unit)
			if stand.x > -900:
				_planning.set_threat_origin(stand)
			else:
				_planning.clear_threat_origin()
			return
	if not _threat_follows_cursor():
		_planning.clear_threat_origin()
		return
	if _planning.is_hover_move_tile(cell):
		_planning.set_threat_origin(cell)
	else:
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
			if ability != null and AbilitySystem.ability_has_dash(ability) and not AbilitySystem.ability_is_offensive_dash(ability):
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
		var dash_ability := _selected_ability_data(actor)
		if (
			dash_ability != null
			and _ability_has_dash(dash_ability)
			and dash_targeting
			and _is_valid_dash_target(_proj_origin(actor), cell, _dash_steps(dash_ability))
		):
			var dash_face: int = _facing_toward(_proj_origin(actor), cell)
			var mode: int = (
				TacticalUnitLayer.DragPreviewAnim.ATTACK
				if AbilitySystem.ability_is_offensive_dash(dash_ability)
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
