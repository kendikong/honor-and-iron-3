class_name CombatPlanningInput
extends RefCounted

## H&I planning semantics ported from board_view — used by TacticalInputController.


var force_basic_movement: bool = false

var _map_view: TacticalMapView
var _director: CombatDirector
var _planning: TacticalPlanningOverlay
var _intent_state: CombatIntentState
var _sfx: SfxPlayer

var dragging: bool = false
var aiming: bool = false
var _drag_armed: bool = false
var _drag_press_local: Vector2 = Vector2.ZERO

const _DRAG_THRESHOLD_PX: float = 6.0
const ICON_MOVE: String = "👟"
const ICON_RUN: String = "🏃"
const ICON_ATTACK: String = "⚔️"
const ICON_SKILL: String = "🔮"
const ICON_MOVE_ATTACK: String = "👟⚔️"
const ICON_RUN_ATTACK: String = "🏃⚔️"
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
		if aiming and unit.id == _director.selected_unit_id:
			var actor := _proj_unit(_director.selected_unit_id)
			var self_ability := _selected_ability_data(actor)
			if actor != null and AbilitySystem.can_target_self(actor, self_ability):
				if not AbilitySystem.is_run_ability(self_ability):
					if not selected_phase_action_exhausted(_director.selected_unit_id):
						_director.rpc_plan_attack(_director.selected_unit_id, _director.selected_ability_index, unit.id)
						_play_sfx("ability")
					else:
						_play_sfx("invalid")
				cancel_aim()
				return
			_play_sfx("invalid")
			return
		if aiming:
			cancel_aim()
		var was_selected: bool = unit.id == _director.selected_unit_id
		if was_selected and _director.selected_ability_index >= 0:
			if _try_plan_self_target_attack(unit.id):
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
		if actor != null and _try_plan_basic_move(_director.selected_unit_id, cell, local):
			cancel_aim()
			return
		var target := _aim_enemy_board().get_unit_at(cell)
		if target != null and actor != null:
			if target.id == actor.id:
				var self_ability := _selected_ability_data(actor)
				if AbilitySystem.can_target_self(actor, self_ability):
					if not AbilitySystem.is_run_ability(self_ability):
						_director.rpc_plan_attack(_director.selected_unit_id, _director.selected_ability_index, target.id)
						_play_sfx("ability")
				else:
					_play_sfx("invalid")
			elif _in_ability_range(actor, target):
				_director.rpc_plan_attack(_director.selected_unit_id, _director.selected_ability_index, target.id)
				_play_sfx("ability")
			else:
				_play_sfx("invalid")
		elif actor != null and _ability_has_dash(_selected_ability_data(actor)):
			if _is_valid_dash_target(_proj_origin(actor), cell, _ability_range(actor)):
				_director.rpc_plan_ability_at_coord(_director.selected_unit_id, _director.selected_ability_index, cell)
				_play_sfx("ability")
			else:
				_play_sfx("invalid")
		else:
			_play_sfx("invalid")
		cancel_aim()
		return
	if unit != null and unit.is_enemy():
		var sel := board.get_unit_by_id(_director.selected_unit_id) if _director.selected_unit_id >= 0 else null
		if sel != null and not sel.is_enemy():
			if selected_phase_action_exhausted(sel.id):
				_director.select_unit(unit.id)
			else:
				_plan_approach_or_trample_on_enemy(_director.selected_unit_id, unit, local, Vector2i(-1, -1))
		else:
			_director.select_unit(unit.id)
	else:
		var sel_unit := board.get_unit_by_id(_director.selected_unit_id) if _director.selected_unit_id >= 0 else null
		if sel_unit != null and not sel_unit.is_enemy():
			if selected_phase_action_exhausted(sel_unit.id):
				return
			var proj_unit := _proj_unit(sel_unit.id)
			if (
				proj_unit != null
				and cell == proj_unit.position
				and _director.selected_ability_index >= 0
				and _try_plan_self_target_attack(sel_unit.id)
			):
				return
			if _try_commit_move_with_self_skill(_director.selected_unit_id, cell, local, []):
				pass
			elif not _try_plan_skill_at_coord(sel_unit, cell, local) and _basic_move_allowed():
				_director.rpc_plan_move(
					_director.selected_unit_id,
					cell,
					_facing_from_drop(local, cell),
					[],
				)
				_play_sfx("move")


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
				if CombatDirector.is_wait_ability_index(_director.selected_ability_index):
					_director.rpc_plan_wait(released_unit_id)
					_play_sfx("ability")
					_director.select_ability(-1)
					committed = true
				elif _try_plan_self_target_attack(released_unit_id):
					committed = true
				else:
					committed = _try_plan_wait(released_unit_id)
					if committed:
						_play_sfx("ability")
			elif CombatDirector.is_wait_ability_index(_director.selected_ability_index):
				_director.rpc_plan_wait(released_unit_id)
				_play_sfx("ability")
				_director.select_ability(-1)
				committed = true
			elif _try_plan_self_target_attack(released_unit_id):
				committed = true
			else:
					var face: int = _facing_from_drop(local, cell)
					if face >= 0:
						_director.rpc_plan_face(released_unit_id, face)
						_play_sfx("move")
						committed = true
		return committed
	if dropped_on == null:
		var move_drop_ok: bool = _drop_allows_move_tile(cell, legal_move_tiles, actor)
		if move_drop_ok:
			if _try_commit_move_with_self_skill(released_unit_id, cell, local, [], legal_move_tiles):
				committed = true
			elif _try_plan_basic_move(released_unit_id, cell, local, [], legal_move_tiles):
				committed = true
		if not committed and _try_plan_skill_at_coord(actor, cell, local):
			committed = true
	return committed


func on_right_click() -> void:
	if aiming:
		cancel_aim()
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
		if _planning != null:
			_planning.queue_redraw()
		return
	var occ := board.get_unit_at(cell)
	var drag_unit := board.get_unit_by_id(_drag_unit_id)
	var legal_move_tiles: Array[Vector2i] = (
		_planning.get_hover_move_tiles() if _planning != null else []
	)
	if drag_unit != null and (occ == null or occ.id == _drag_unit_id):
		if cell == drag_unit.position or legal_move_tiles.has(cell):
			_drag_last_free = cell
	elif (
		drag_unit != null
		and not drag_unit.is_enemy()
		and occ != null
		and occ.is_enemy()
		and MovementSystem.has_trample(drag_unit)
		and force_basic_movement
		and legal_move_tiles.has(occ.position)
	):
		_drag_last_free = occ.position
	var drag_target_id: int = _drag_preview_target_id(drag_unit, occ)
	var preview: Dictionary = _director.preview_drag(
		_drag_unit_id,
		_drag_last_free,
		drag_target_id,
		[],
	)
	_apply_live_preview(preview)
	if _planning != null:
		_planning.set_threat_origin(_drag_last_free)
		_planning._recompute_hover_ranges_from_inputs()
	_update_drag_sprite(local, cell, preview)
	_sync_intent_live_board()
	if _intent_state != null:
		_intent_state.recompute()
	refresh_mouse_cursor(cell)
	if _planning != null:
		_planning.queue_redraw()


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
	var preview: Dictionary = _director.preview_drag(
		_drag_unit_id,
		_drag_last_free,
		drag_target_id,
		[],
	)
	_apply_live_preview(preview)


func _apply_live_preview(preview: Dictionary) -> void:
	if preview.is_empty():
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
			_sync_threat_origin_from_cell(cell)
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
	if _planning != null and planning_cell_changed:
		_planning._recompute_hover_ranges_from_inputs()
	if _director.selected_unit_id >= 0:
		if planning_cell_changed:
			_refresh_selected_interaction_preview()
	else:
		if planning_cell_changed:
			_update_hover_attack_preview()
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
	var can_act: bool = p_unit.can_use_action_slot()
	var can_move: bool = (
		p_unit.movement.points_left > 0
		and _director.get_planning_move_timing(id) >= 0
	)
	return not can_act and not can_move


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
		if _run_mode_selected(p_unit) or _basic_move_allowed() or force_basic_movement:
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
	if _run_mode_selected(p_unit):
		return ICON_RUN
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
	if _unit_movement_blocked_by_dash(p_unit) and not force_basic_movement:
		var dash_ability := _selected_ability_data(p_unit)
		if dash_ability != null and _is_valid_dash_target(p_unit.position, cell, dash_ability.range_tiles):
			var dash_res: Dictionary = _director.preview_dash(
				_director.selected_unit_id, cell, _director.selected_ability_index,
			)
			_apply_hover_preview_dict(dash_res)
		return
	if _skill_takes_priority_over_basic_move():
		var skill_ability := _selected_ability_data(p_unit)
		if (
			skill_ability != null
			and _ability_has_dash(skill_ability)
			and _is_valid_dash_target(_proj_origin(p_unit), cell, skill_ability.range_tiles)
		):
			var dash_res: Dictionary = _director.preview_dash(
				_director.selected_unit_id, cell, _director.selected_ability_index,
			)
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
	var res: Dictionary = _director.preview_drag(_director.selected_unit_id, p_unit.position, target_id)
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
	var dash_preview := false
	var dash_ab := _selected_ability_data(unit)
	if _director.board.is_in_bounds(cell) and _should_use_dash_on_input(dash_ab):
		dash_preview = _is_valid_dash_target(_proj_origin(unit), cell, dash_ab.range_tiles)
	var cache_key: String = "%d|%d|%s|%d|%d|%s" % [
		_director.plan_revision if _director != null else 0,
		unit_id,
		str(move_coord),
		attack_target_id,
		cur_ability,
		"1" if dash_preview else "0",
	]
	if cache_key == _hover_preview_cache_key:
		return
	_hover_preview_cache_key = cache_key
	var res: Dictionary
	if dash_preview:
		res = _director.preview_dash(unit_id, cell, cur_ability)
		drag_sim_actor_pos = _proj_origin(unit)
	else:
		res = _director.preview_drag(unit_id, move_coord, attack_target_id, waypoints)
		var temp_board: BoardState = res.get("temp_board")
		var pv_actor: UnitState = temp_board.get_unit_by_id(unit_id) if temp_board != null else null
		drag_sim_actor_pos = pv_actor.position if pv_actor != null else move_coord
	drag_preview_failed = false
	for event: Variant in res.get("events", []):
		if event is SimEvent:
			var sim: SimEvent = event as SimEvent
			if (
				sim.type == GameEnums.SimEventType.ACTION_FAILED
				and int(sim.data.get("actor", -1)) == unit_id
			):
				drag_preview_failed = true
				break
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
			if _in_ability_range(p_unit, hover_unit):
				return hover_unit.id
			return -1
		if _in_ability_range(p_unit, hover_unit):
			return hover_unit.id
		return -1
	if hover_unit.is_enemy():
		return hover_unit.id
	return -1


func _should_use_dash_on_input(ability: AbilityData) -> bool:
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
	if selected_phase_action_exhausted(unit_id):
		_play_sfx("invalid")
		return false
	var actor := _proj_unit(unit_id)
	if actor == null:
		actor = _director.board.get_unit_by_id(unit_id) if _director.board != null else null
	if actor == null:
		return false
	if _in_ability_range(actor, enemy):
		_director.rpc_plan_attack(unit_id, _director.selected_ability_index, enemy.id)
		_play_sfx("ability")
		return true
	var ability := _selected_ability_data(actor)
	if (
		ability != null
		and AbilitySystem.can_target_self(actor, ability)
		and _director.selected_ability_index >= 0
	):
		if _try_commit_move_with_self_skill(
			unit_id, preferred_tile, local, waypoints, legal_move_tiles,
		):
			return true
		if (
			preferred_tile != actor.position
			and _drop_allows_move_tile(preferred_tile, legal_move_tiles, actor)
		):
			_director.rpc_plan_move(
				unit_id,
				preferred_tile,
				_facing_from_drop(local, preferred_tile),
				waypoints,
			)
			_play_sfx("move")
			return true
		_director.rpc_plan_attack(unit_id, _director.selected_ability_index, actor.id)
		_play_sfx("ability")
		return true
	if _prefer_approach_over_trample_move(actor, enemy):
		if not _enemy_attackable_from_legal_tiles(actor, enemy, legal_move_tiles):
			return false
		_director.rpc_plan_attack_with_approach(
			unit_id,
			_director.selected_ability_index,
			enemy.id,
			preferred_tile,
		)
		_play_sfx("ability")
		return true
	if _drop_allows_move_tile(enemy.position, legal_move_tiles, actor):
		_director.rpc_plan_move(
			unit_id,
			enemy.position,
			_facing_from_drop(local, enemy.position),
			waypoints,
		)
		_play_sfx("move")
		return true
	if not _enemy_attackable_from_legal_tiles(actor, enemy, legal_move_tiles):
		return false
	_director.rpc_plan_attack_with_approach(
		unit_id,
		_director.selected_ability_index,
		enemy.id,
		preferred_tile,
	)
	_play_sfx("ability")
	return true


func _prefer_approach_over_trample_move(actor: UnitState, enemy: UnitState) -> bool:
	if force_basic_movement:
		return false
	if actor == null or enemy == null or not enemy.is_enemy():
		return false
	if _director.selected_ability_index < 0:
		return false
	return MovementSystem.has_trample(actor) and _can_move_to(actor, enemy.position)


func _try_commit_move_with_self_skill(
	unit_id: int,
	coord: Vector2i,
	local: Vector2,
	waypoints: Array[Vector2i] = [],
	legal_move_tiles: Array[Vector2i] = [],
) -> bool:
	if force_basic_movement or _director.selected_ability_index < 0:
		return false
	var actor := _proj_unit(unit_id)
	if actor == null:
		actor = _director.board.get_unit_by_id(unit_id) if _director.board != null else null
	if actor == null:
		return false
	var ability := _selected_ability_data(actor)
	if ability == null or not AbilitySystem.can_target_self(actor, ability):
		return false
	if AbilitySystem.is_run_ability(ability):
		if coord == actor.position:
			return false
		if not _drop_allows_move_tile(coord, legal_move_tiles, actor):
			return false
		var face_dir: int = _facing_from_drop(local, coord)
		if AbilitySystem.movement_requires_run(_proj(), actor, coord, waypoints):
			_director.rpc_plan_run_and_move(
				unit_id, coord, face_dir, waypoints, _director.selected_ability_index,
			)
			_play_sfx("ability")
		else:
			_director.rpc_plan_move(unit_id, coord, face_dir, waypoints)
			_play_sfx("move")
		return true
	if coord == actor.position:
		_director.rpc_plan_attack(unit_id, _director.selected_ability_index, unit_id)
		_play_sfx("ability")
		return true
	if not _drop_allows_move_tile(coord, legal_move_tiles, actor):
		return false
	_director.rpc_plan_move_with_self_ability(
		unit_id,
		coord,
		_facing_from_drop(local, coord),
		waypoints,
		_director.selected_ability_index,
	)
	_play_sfx("ability")
	return true


func _try_plan_skill_at_coord(unit: UnitState, coord: Vector2i, local: Vector2) -> bool:
	if selected_phase_action_exhausted(unit.id):
		return false
	if force_basic_movement or _director.selected_ability_index < 0:
		return false
	var ability := _selected_ability_data(unit)
	if ability == null:
		return false
	var actor := _proj_unit(unit.id)
	if actor == null:
		actor = unit
	if _ability_has_dash(ability):
		if not _is_valid_dash_target(_proj_origin(actor), coord, ability.range_tiles):
			return false
		_director.rpc_plan_ability_at_coord(unit.id, _director.selected_ability_index, coord)
		_play_sfx("ability")
		return true
	var target := _proj().get_unit_at(coord)
	if target != null:
		if target.id == actor.id:
			if AbilitySystem.can_target_self(actor, ability) and not AbilitySystem.is_run_ability(ability):
				_director.rpc_plan_attack(unit.id, _director.selected_ability_index, target.id)
				_play_sfx("ability")
				return true
		elif _in_ability_range(actor, target):
			_director.rpc_plan_attack(unit.id, _director.selected_ability_index, target.id)
			_play_sfx("ability")
			return true
	return false


func _try_plan_basic_move(
	unit_id: int,
	coord: Vector2i,
	local: Vector2,
	waypoints: Array[Vector2i] = [],
	legal_move_tiles: Array[Vector2i] = [],
) -> bool:
	if not _basic_move_allowed():
		return false
	var move_timing: int = _director.get_planning_move_timing(unit_id)
	if (
		move_timing != -1
		and _director.unit_has_move_planned_at_timing(unit_id, move_timing)
	):
		return false
	var actor := _proj_unit(unit_id)
	if actor == null:
		actor = _director.board.get_unit_by_id(unit_id) if _director.board != null else null
	if actor == null or not _drop_allows_move_tile(coord, legal_move_tiles, actor):
		return false
	_director.rpc_plan_move(unit_id, coord, _facing_from_drop(local, coord), waypoints)
	_play_sfx("move")
	return true


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


func _ability_has_dash(ability: AbilityData) -> bool:
	return AbilitySystem.ability_has_dash(ability)


func _drag_had_movement() -> bool:
	if _drag_route.is_empty():
		return false
	return _drag_last_free != _drag_route[0]


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


func _try_plan_self_target_attack(unit_id: int) -> bool:
	if _director == null or not _is_planning():
		return false
	if selected_phase_action_exhausted(unit_id):
		return false
	if _director.selected_ability_index < 0:
		return false
	if CombatDirector.is_wait_ability_index(_director.selected_ability_index):
		return false
	var board: BoardState = _director.board
	var actor := _proj_unit(unit_id)
	if actor == null:
		actor = board.get_unit_by_id(unit_id) if board != null else null
	if actor == null:
		return false
	var self_ability := _selected_ability_data(actor)
	if (
		self_ability == null
		or not AbilitySystem.can_target_self(actor, self_ability)
		or AbilitySystem.is_run_ability(self_ability)
	):
		return false
	_director.rpc_plan_attack(unit_id, _director.selected_ability_index, actor.id)
	_play_sfx("ability")
	_director.select_ability(-1)
	return true


func _selected_ability_data(unit: UnitState) -> AbilityData:
	if _director == null or unit == null:
		return null
	return CombatDirector.resolve_selected_ability(unit, _director.selected_ability_index)


func run_mode_selected(unit: UnitState = null) -> bool:
	return _run_mode_selected(unit)


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
	return actor.ability.points_left >= ability.action_point_cost


func _move_budget(unit: UnitState) -> int:
	if unit == null:
		return 0
	if _run_mode_selected(unit):
		return AbilitySystem.preview_move_budget_with_run(unit)
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


func _can_move_to(unit: UnitState, coord: Vector2i) -> bool:
	if unit == null or coord == unit.position:
		return false
	if unit.movement.points_left <= 0 and not _run_mode_selected(unit):
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
	var self_tile_icon: String = _self_tile_hover_icon(p_unit, cell)
	if self_tile_icon != "":
		return self_tile_icon
	if _run_mode_selected(p_unit):
		if cell != p_unit.position and _is_hover_move_cell(p_unit, cell):
			return _movement_icon_for(p_unit, cell)
		return ""
	var hover_unit: UnitState = _resolve_hover_unit_at(cell)
	if _skill_interaction_active():
		if (
			force_basic_movement
			and hover_unit == null
			and cell != p_unit.position
			and _unit_move_slot_open(p_unit.id)
			and _is_hover_move_cell(p_unit, cell)
		):
			return _movement_icon_for(p_unit, cell)
		var valid_aim := false
		if hover_unit != null:
			if hover_unit.id == p_unit.id:
				var self_ability := _selected_ability_data(p_unit)
				valid_aim = AbilitySystem.can_target_self(p_unit, self_ability)
			else:
				valid_aim = _in_ability_range(p_unit, hover_unit) \
					and AbilitySystem.target_passes_mode(p_unit, _selected_ability_data(p_unit), hover_unit)
		elif CombatDirector.is_wait_ability_index(_director.selected_ability_index):
			valid_aim = cell == p_unit.position
		elif _director.selected_ability_index >= 0 and _director.selected_ability_index < p_unit.active_abilities.size():
			var aim_ability: AbilityData = p_unit.active_abilities[_director.selected_ability_index]
			if _ability_has_dash(aim_ability):
				valid_aim = _is_valid_dash_target(_proj_origin(p_unit), cell, aim_ability.range_tiles)
		if valid_aim:
			var aim_ability := CombatDirector.resolve_selected_ability(p_unit, _director.selected_ability_index)
			if aim_ability != null:
				if AbilitySystem.is_wait_ability(aim_ability):
					return ICON_WAIT
				return _ability_action_icon(aim_ability)
		if hover_unit != null and hover_unit.is_enemy():
			var enemy_icon: String = _enemy_hover_icon(p_unit, cell, hover_unit)
			if enemy_icon != "":
				return enemy_icon
		var move_attack: String = _move_attack_hover_icon(p_unit, cell)
		if move_attack != "":
			return move_attack
		var move_icon: String = _move_hover_icon(p_unit, cell)
		if move_icon != "":
			return move_icon
		if _invalid_hover_target(p_unit, cell, hover_unit):
			return ICON_NULL
		return ""
	return _cursor_selection_hints(p_unit, cell, hover_unit)


func _cursor_selection_hints(p_unit: UnitState, cell: Vector2i, hover_unit: UnitState) -> String:
	if hover_unit != null and hover_unit.is_enemy():
		return _enemy_hover_icon(p_unit, cell, hover_unit)
	if hover_unit != null and hover_unit.is_alive():
		return ""
	var move_icon: String = _move_hover_icon(p_unit, cell)
	if move_icon != "":
		return move_icon
	if hover_unit == null and cell != p_unit.position:
		var move_attack: String = _move_attack_hover_icon(p_unit, cell)
		if move_attack != "":
			return move_attack
		var hover_ability := _selected_ability_data(p_unit)
		if (
			_skill_takes_priority_over_basic_move()
			and hover_ability != null
			and _ability_has_dash(hover_ability)
			and _is_valid_dash_target(_proj_origin(p_unit), cell, hover_ability.range_tiles)
		):
			if AbilitySystem.ability_is_offensive_dash(hover_ability):
				return ICON_ATTACK
			return ICON_SKILL
	if _invalid_hover_target(p_unit, cell, hover_unit):
		return ICON_NULL
	return ""


func _resolve_hover_unit_at(cell: Vector2i) -> UnitState:
	if _director == null or _director.board == null or not _director.board.is_in_bounds(cell):
		return null
	var live: UnitState = _director.board.get_unit_at(cell)
	if live == null:
		return null
	var projected: UnitState = _proj().get_unit_by_id(live.id)
	return projected if projected != null else live


func _enemy_hover_icon(p_unit: UnitState, cell: Vector2i, hover_unit: UnitState) -> String:
	if hover_unit == null or not hover_unit.is_enemy():
		return ""
	if selected_phase_action_exhausted(p_unit.id):
		return ICON_NULL
	var ability: AbilityData = _selected_ability_data(p_unit)
	var use_skill: bool = (
		not force_basic_movement
		and _director != null
		and _director.selected_ability_index >= 0
		and ability != null
	)
	if use_skill:
		if not AbilitySystem.target_passes_mode(p_unit, ability, hover_unit):
			return ICON_NULL
		if _ability_has_dash(ability) and not AbilitySystem.ability_is_offensive_dash(ability):
			return ICON_NULL
	var legal_moves: Array[Vector2i] = _snapshot_drag_legal_move_tiles()
	var in_range: bool = _in_ability_range(p_unit, hover_unit)
	if in_range:
		if use_skill:
			return _ability_action_icon(ability)
		return ICON_ATTACK
	if _can_move_to(p_unit, cell) or _is_hover_move_cell(p_unit, cell):
		return _movement_icon_for(p_unit, cell)
	if _enemy_attackable_from_legal_tiles(p_unit, hover_unit, legal_moves):
		return _move_attack_icon_for(p_unit, cell)
	return ICON_NULL


func _self_tile_hover_icon(p_unit: UnitState, cell: Vector2i) -> String:
	if cell != p_unit.position:
		return ""
	if selected_phase_action_exhausted(p_unit.id):
		return ""
	if CombatDirector.is_wait_ability_index(_director.selected_ability_index):
		return ICON_WAIT
	var self_ability := _selected_ability_data(p_unit)
	if (
		_director.selected_ability_index >= 0
		and self_ability != null
		and AbilitySystem.can_target_self(p_unit, self_ability)
		and not AbilitySystem.is_run_ability(self_ability)
	):
		return _ability_action_icon(self_ability)
	if _hover_would_commit_wait(p_unit):
		return ICON_WAIT
	return ""


func _hover_would_commit_wait(p_unit: UnitState) -> bool:
	if selected_phase_action_exhausted(p_unit.id):
		return false
	return true


func _move_hover_icon(p_unit: UnitState, cell: Vector2i) -> String:
	if cell == p_unit.position:
		return ""
	if not _basic_move_allowed() or not _unit_move_slot_open(p_unit.id):
		return ""
	if _planning != null and _planning.is_hover_move_tile(cell):
		return _movement_icon_for(p_unit, cell)
	if _can_move_to(p_unit, cell):
		return _movement_icon_for(p_unit, cell)
	return ""


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
	if cell == _proj_origin(actor):
		return _self_tile_hover_icon(actor, cell)
	if drag_preview_failed:
		return ICON_NULL
	var legal_moves: Array[Vector2i] = _snapshot_drag_legal_move_tiles()
	var occ: UnitState = _director.board.get_unit_at(cell) if _director.board != null else null
	if occ != null and occ.is_enemy() and occ.id != actor.id:
		var proj_occ: UnitState = _proj().get_unit_by_id(occ.id)
		if proj_occ != null:
			occ = proj_occ
		return _enemy_hover_icon(actor, cell, occ)
	var move_attack: String = _move_attack_hover_icon(actor, cell, actor.position)
	if move_attack != "":
		return move_attack
	if _drop_allows_move_tile(cell, legal_moves, actor) or (
		cell == _drag_last_free and legal_moves.has(cell)
	):
		return ICON_MOVE
	return ""


func _invalid_hover_target(p_unit: UnitState, cell: Vector2i, hover_unit: UnitState) -> bool:
	if not _skill_interaction_active():
		return false
	var ability: AbilityData = _selected_ability_data(p_unit)
	if ability == null:
		return false
	if hover_unit != null and hover_unit.id == p_unit.id:
		return not AbilitySystem.can_target_self(p_unit, ability) and not AbilitySystem.is_run_ability(ability)
	if _ability_has_dash(ability) and _planning != null:
		if (
			_planning.is_hover_threat_tile(cell)
			and not _is_valid_dash_target(_proj_origin(p_unit), cell, ability.range_tiles)
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
		return ICON_SKILL
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
	if not _skill_interaction_active():
		return false
	if _director == null or _director.selected_unit_id < 0:
		return false
	# After pre-move, threat range is from the unit — not hypothetical move destinations.
	if not _unit_move_slot_open(_director.selected_unit_id):
		return false
	return true


func _sync_threat_origin_from_cell(cell: Vector2i) -> void:
	if _planning == null or _director == null or _director.board == null or dragging:
		return
	if _threat_follows_cursor() and _director.board.is_in_bounds(cell):
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


func _drag_move_preview_mode(unit: UnitState) -> int:
	if _run_mode_selected(unit):
		return TacticalUnitLayer.DragPreviewAnim.RUN
	if preview_state.preview_board != null and unit != null:
		var pv := preview_state.preview_board.get_unit_by_id(unit.id)
		if pv != null and pv.has_status(GameEnums.StatusType.RUNNING):
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
			emit_drag_sprite.call(_drag_move_preview_mode(actor), walk_face, preview_cell, drag_preview_failed)
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
			and _is_valid_dash_target(_proj_origin(actor), cell, dash_ability.range_tiles)
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
		emit_drag_sprite.call(_drag_move_preview_mode(actor), move_face, preview_cell, drag_preview_failed)
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
