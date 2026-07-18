class_name CombatPlanningInput
extends RefCounted

## H&I planning semantics ported from board_view — used by TacticalInputController.


var force_basic_movement: bool = false
var unit_selected_abilities: Dictionary = {}

var _map_view: TacticalMapView
var _director: CombatDirector
var _planning: TacticalPlanningOverlay
var _intent_state: CombatIntentState
var _sfx: SfxPlayer

var dragging: bool = false
var aiming: bool = false

var _drag_unit_id: int = -1
var _drag_route: Array[Vector2i] = []
var _drag_last_free: Vector2i = Vector2i(-1, -1)
var _drag_unit_was_selected: bool = false
var _drag_saved_preview: BoardState = null
var preview_state: CombatPlanningPreview = CombatPlanningPreview.new()
var drag_sim_actor_pos: Vector2i = Vector2i.ZERO
var drag_preview_failed: bool = false


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
	if not dragging:
		return
	dragging = false
	_drag_unit_id = -1
	_end_drag_interaction(true)
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
	var unit := board.get_unit_at(cell)
	if unit != null and not unit.is_enemy() and unit.is_alive():
		if NetworkManager != null and NetworkManager.is_multiplayer:
			if unit.controlling_player_id != NetworkManager.local_player_id:
				return
		if aiming and unit.id == _director.selected_unit_id:
			var actor := _proj_unit(_director.selected_unit_id)
			var self_ability := _selected_ability_data(actor)
			if actor != null and AbilitySystem.can_target_self(actor, self_ability):
				if not AbilitySystem.is_run_ability(self_ability):
					_director.rpc_plan_attack(_director.selected_unit_id, _director.selected_ability_index, unit.id)
					_play_sfx("ability")
				cancel_aim()
				return
			_play_sfx("invalid")
			return
		if aiming:
			cancel_aim()
		var was_selected: bool = unit.id == _director.selected_unit_id
		if not was_selected:
			_director.select_unit(unit.id)
		_begin_drag(unit, local, was_selected)
		return
	if aiming:
		var actor := _proj_unit(_director.selected_unit_id)
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
			_plan_approach_or_trample_on_enemy(_director.selected_unit_id, unit, local, Vector2i(-1, -1))
		else:
			_director.select_unit(unit.id)
	else:
		var sel_unit := board.get_unit_by_id(_director.selected_unit_id) if _director.selected_unit_id >= 0 else null
		if sel_unit != null and not sel_unit.is_enemy():
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
	if not dragging:
		return
	var released_unit_id: int = _drag_unit_id
	dragging = false
	var board: BoardState = _director.board
	var actor := board.get_unit_by_id(released_unit_id) if board != null else null
	var cell: Vector2i = _map_view.screen_to_grid(_map_view.get_viewport().get_mouse_position())
	if actor == null or board == null or not board.is_in_bounds(cell):
		_drag_unit_id = released_unit_id
		_end_drag_interaction(true)
		_drag_unit_id = -1
		return
	var dropped_on := board.get_unit_at(cell)
	if dropped_on != null and dropped_on.id != actor.id:
		var waypoints: Array[Vector2i] = _route_waypoints()
		_plan_approach_or_trample_on_enemy(released_unit_id, dropped_on, local, _drag_last_free, waypoints)
	elif cell == actor.position:
		if _drag_unit_was_selected:
			if not _drag_had_movement():
				if _try_plan_wait(released_unit_id):
					_play_sfx("ability")
			elif CombatDirector.is_wait_ability_index(_director.selected_ability_index):
				_director.rpc_plan_wait(released_unit_id)
				_play_sfx("ability")
				_director.select_ability(-1)
			else:
				var self_ability := _selected_ability_data(actor)
				if (
					_director.selected_ability_index >= 0
					and AbilitySystem.can_target_self(actor, self_ability)
					and not AbilitySystem.is_run_ability(self_ability)
				):
					_director.rpc_plan_attack(released_unit_id, _director.selected_ability_index, actor.id)
					_play_sfx("ability")
					_director.select_ability(-1)
				else:
					var face: int = _facing_from_drop(local, cell)
					if face >= 0:
						_director.rpc_plan_face(released_unit_id, face)
						_play_sfx("move")
		else:
			var face_idle: int = _facing_from_drop(local, cell)
			if face_idle >= 0:
				_director.rpc_plan_face(released_unit_id, face_idle)
				_play_sfx("move")
	elif dropped_on == null:
		var waypoints: Array[Vector2i] = _route_waypoints()
		if not _try_commit_move_with_self_skill(released_unit_id, cell, local, waypoints):
			if not _try_plan_skill_at_coord(actor, cell, local):
				_try_plan_basic_move(released_unit_id, cell, local, waypoints)
	_drag_unit_id = -1
	_end_drag_interaction(false)


func on_right_click() -> void:
	if aiming:
		cancel_aim()
		_play_sfx("cancel")
		return
	if _is_planning() and _director.selected_unit_id >= 0:
		if _director.unit_has_undoable_action(_director.selected_unit_id):
			_director.rpc_remove_last_for_unit(_director.selected_unit_id)
			_play_sfx("cancel")
		else:
			_director.select_unit(-1)
			_play_sfx("cancel")


func update_drag(local: Vector2) -> void:
	var board: BoardState = _director.board
	var cell: Vector2i = _map_view.screen_to_grid(_map_view.get_viewport().get_mouse_position())
	if not board.is_in_bounds(cell):
		return
	if _intent_state != null:
		_intent_state.set_hover_coord(cell)
	if _basic_move_allowed():
		_extend_drag_route(cell)
	var occ := board.get_unit_at(cell)
	var drag_unit := board.get_unit_by_id(_drag_unit_id)
	if occ == null or occ.id == _drag_unit_id:
		_drag_last_free = cell
	elif (
		drag_unit != null
		and not drag_unit.is_enemy()
		and occ.is_enemy()
		and MovementSystem.has_trample(drag_unit)
		and force_basic_movement
	):
		_drag_last_free = cell
	var drag_target_id: int = _drag_preview_target_id(drag_unit, occ)
	var preview: Dictionary = _director.preview_drag(
		_drag_unit_id,
		_drag_last_free,
		drag_target_id,
		_route_waypoints(),
	)
	_apply_live_preview(preview)
	if _planning != null:
		_planning.set_threat_origin(_drag_last_free)
		_planning._recompute_hover_ranges_from_inputs()
	_planning.set_drag_route(_drag_route)
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
		_route_waypoints(),
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


func _begin_drag(unit: UnitState, local: Vector2, was_already_selected: bool) -> void:
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
	_planning.set_drag_route(_drag_route)
	_planning._recompute_hover_ranges_from_inputs()
	_planning.begin_drag_sprite(unit.id)


func _end_drag_interaction(restore_committed: bool) -> void:
	_drag_route.clear()
	drag_preview_failed = false
	preview_state.clear_interaction()
	if _planning != null:
		_planning.clear_drag_route()
		_planning.clear_fixed_range_origin()
		_planning.clear_threat_origin()
		_planning.end_drag_sprite()
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
	_refresh_hover_if_planning()


func _on_board_changed(_board: BoardState) -> void:
	if aiming:
		cancel_aim()
	aiming = false
	dragging = false
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
		_planning._recompute_hover_ranges_from_inputs()
	_sync_intent_live_board()
	_sync_intent_skill_mode()
	if _intent_state != null:
		_intent_state.recompute()
	refresh_mouse_cursor(
		_intent_state.hover_coord if _intent_state != null else Vector2i(-999, -999),
	)


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
	if unit_id >= 0:
		_play_sfx("select")
	if _drag_saved_preview == null and _planning != null:
		_planning.stash_committed_preview()
	if unit_selected_abilities.has(unit_id):
		_director.select_ability(int(unit_selected_abilities[unit_id]))
	elif unit_id < 0:
		pass
	if _planning != null and _director != null:
		if _intent_state != null:
			_sync_threat_origin_from_cell(_intent_state.hover_coord)
		_planning._recompute_hover_ranges_from_inputs()
	_sync_intent_skill_mode()
	_refresh_hover_if_planning()


func _on_ability_selected(index: int) -> void:
	if _director == null:
		return
	if _drag_saved_preview == null and _planning != null:
		_planning.stash_committed_preview()
	if _director.selected_unit_id >= 0:
		unit_selected_abilities[_director.selected_unit_id] = index
	if _planning != null and _director != null:
		if _intent_state != null:
			_sync_threat_origin_from_cell(_intent_state.hover_coord)
		_planning._recompute_hover_ranges_from_inputs()
	_sync_intent_skill_mode()
	_refresh_hover_if_planning()


func _on_preview_updated(_result: SimResult) -> void:
	_drag_saved_preview = null
	_sync_intent_live_board()
	if dragging:
		return
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
	if not _director.board.is_in_bounds(cell):
		if _director.selected_unit_id >= 0:
			_restore_hover_preview()
		else:
			_sync_intent_live_board()
			if _planning != null:
				_planning._invalidate_hover_cache()
				_planning._recompute_hover_ranges_from_inputs()
		return
	if _planning != null:
		_planning._recompute_hover_ranges_from_inputs()
	if _director.selected_unit_id >= 0:
		_refresh_selected_interaction_preview()
	else:
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
	var can_act: bool = p_unit.ability.points_left > 0 and not p_unit.turn_action_used
	var can_move: bool = (
		p_unit.movement.points_left > 0
		and _director.get_planning_move_timing(id) >= 0
	)
	return not can_act and not can_move


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
	if _run_mode_selected(p_unit) and _can_move_to(p_unit, cell):
		_refresh_live_interaction_preview(_director.selected_unit_id, cell, -1, [])
		_refresh_click_target_highlight()
		return
	if _basic_move_allowed() and _can_move_to(p_unit, cell):
		_refresh_live_interaction_preview(_director.selected_unit_id, cell, -1, [])
		_refresh_click_target_highlight()
		return
	if not p_unit.active_abilities.is_empty() and _director.selected_ability_index >= 0:
		var target_id := _hover_attack_target_id()
		_refresh_live_interaction_preview(_director.selected_unit_id, cell, target_id, [])
		_refresh_click_target_highlight()
		return
	if force_basic_movement and _can_move_to(p_unit, cell):
		_refresh_live_interaction_preview(_director.selected_unit_id, cell, -1, [])
		_refresh_click_target_highlight()
		return
	_restore_hover_preview()


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
) -> void:
	var actor := _proj_unit(unit_id)
	if actor == null:
		actor = _director.board.get_unit_by_id(unit_id) if _director.board != null else null
	if actor == null:
		return
	var ability := _selected_ability_data(actor)
	if (
		ability != null
		and AbilitySystem.can_target_self(actor, ability)
		and _director.selected_ability_index >= 0
	):
		if _try_commit_move_with_self_skill(unit_id, preferred_tile, local, waypoints):
			return
		if preferred_tile != actor.position and _can_move_to(actor, preferred_tile):
			_director.rpc_plan_move(
				unit_id,
				preferred_tile,
				_facing_from_drop(local, preferred_tile),
				waypoints,
			)
			_play_sfx("move")
			return
		_director.rpc_plan_attack(unit_id, _director.selected_ability_index, actor.id)
		_play_sfx("ability")
		return
	if _prefer_approach_over_trample_move(actor, enemy):
		_director.rpc_plan_attack_with_approach(
			unit_id,
			_director.selected_ability_index,
			enemy.id,
			preferred_tile,
		)
		_play_sfx("ability")
	elif _can_move_to(actor, enemy.position):
		_director.rpc_plan_move(
			unit_id,
			enemy.position,
			_facing_from_drop(local, enemy.position),
			waypoints,
		)
		_play_sfx("move")
	else:
		_director.rpc_plan_attack_with_approach(
			unit_id,
			_director.selected_ability_index,
			enemy.id,
			preferred_tile,
		)
		_play_sfx("ability")


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
		if not _can_move_to(actor, coord):
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
	if not _can_move_to(actor, coord):
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
) -> bool:
	if not _basic_move_allowed():
		return false
	var actor := _proj_unit(unit_id)
	if actor == null:
		actor = _director.board.get_unit_by_id(unit_id) if _director.board != null else null
	if actor == null or not _can_move_to(actor, coord):
		return false
	_director.rpc_plan_move(unit_id, coord, _facing_from_drop(local, coord), waypoints)
	_play_sfx("move")
	return true


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
	if _drag_route.size() > 1:
		return true
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
			if drag_unit != null and not drag_unit.is_enemy() and cell == drag_unit.position:
				var ability := _selected_ability_data(drag_unit)
				if ability != null and ability.range_tiles == 0:
					return _ability_action_icon(ability)
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
	if _run_mode_selected(p_unit):
		if cell != p_unit.position and _can_move_to(p_unit, cell):
			return "🏃"
	var hover_unit: UnitState = (
		_aim_enemy_board().get_unit_at(cell)
		if _skill_interaction_active()
		else _proj().get_unit_at(cell)
	)
	if _skill_interaction_active():
		if force_basic_movement and hover_unit == null and cell != p_unit.position and _can_move_to(p_unit, cell):
			return "🏃"
		var valid_aim := false
		if hover_unit != null:
			if hover_unit.id == p_unit.id:
				var self_ability := _selected_ability_data(p_unit)
				valid_aim = AbilitySystem.can_target_self(p_unit, self_ability)
			else:
				valid_aim = _in_ability_range(p_unit, hover_unit)
		elif CombatDirector.is_wait_ability_index(_director.selected_ability_index):
			valid_aim = cell == p_unit.position
		elif _director.selected_ability_index >= 0 and _director.selected_ability_index < p_unit.active_abilities.size():
			var aim_ability: AbilityData = p_unit.active_abilities[_director.selected_ability_index]
			if _ability_has_dash(aim_ability):
				valid_aim = _is_valid_dash_target(p_unit.position, cell, aim_ability.range_tiles)
		if valid_aim:
			var aim_ability := CombatDirector.resolve_selected_ability(p_unit, _director.selected_ability_index)
			if aim_ability != null:
				if AbilitySystem.is_wait_ability(aim_ability):
					return "⏸"
				return _ability_action_icon(aim_ability)
	else:
		if hover_unit != null and hover_unit.is_enemy():
			if _prefer_approach_over_trample_move(p_unit, hover_unit):
				return "⚔️"
			if _can_move_to(p_unit, cell):
				return "🏃"
			return "⚔️"
		if hover_unit == null and cell != p_unit.position:
			var hover_ability := _selected_ability_data(p_unit)
			if (
				_skill_takes_priority_over_basic_move()
				and hover_ability != null
				and _ability_has_dash(hover_ability)
				and _is_valid_dash_target(_proj_origin(p_unit), cell, hover_ability.range_tiles)
			):
				if AbilitySystem.ability_is_offensive_dash(hover_ability):
					return "⚔️"
				return "✨"
			if (
				_basic_move_allowed()
				and not MovementSystem.find_path(
					_proj(), p_unit.position, cell, _move_budget(p_unit),
				).is_empty()
			):
				return "🏃"
	return ""


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


func _skill_takes_priority_over_basic_move() -> bool:
	if _director == null:
		return false
	if _run_mode_selected():
		return false
	return not force_basic_movement and _director.selected_ability_index >= 0


func _skill_interaction_active() -> bool:
	return _skill_takes_priority_over_basic_move() and _director.selected_unit_id >= 0 and not dragging


func _threat_follows_cursor() -> bool:
	return aiming or _skill_interaction_active()


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
	if (
		drag_unit != null
		and not drag_unit.is_enemy()
		and _director.selected_ability_index >= 0
		and not force_basic_movement
		and not _run_mode_selected(drag_unit)
		and _drag_last_free != drag_unit.position
	):
		var self_ability := _selected_ability_data(drag_unit)
		if AbilitySystem.can_target_self(drag_unit, self_ability):
			return drag_unit.id
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
				_planning.update_drag_sprite(
					local,
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
				_planning.update_drag_sprite(local, TacticalUnitLayer.DragPreviewAnim.SPELL, atk_face, preview_cell, drag_preview_failed)
			else:
				_planning.update_drag_sprite(local, TacticalUnitLayer.DragPreviewAnim.ATTACK, atk_face, preview_cell, drag_preview_failed)
			_set_drag_attack_target(drag_target_id, preview)
			return
		if _can_move_to(actor, occ.position):
			var walk_face: int = _facing_toward(actor.position, occ.position)
			_planning.update_drag_sprite(
				local, _drag_move_preview_mode(actor), walk_face, preview_cell, drag_preview_failed,
			)
			_planning.set_drag_attack_target(-1)
			return
	if cell == actor.position and _drag_unit_was_selected:
		if CombatDirector.is_wait_ability_index(_director.selected_ability_index):
			var wait_face: int = _facing_from_drop(local, cell)
			if wait_face < 0:
				wait_face = actor.facing
			_planning.update_drag_sprite(local, TacticalUnitLayer.DragPreviewAnim.SPELL, wait_face, preview_cell, drag_preview_failed)
			_planning.set_drag_attack_target(-1)
			return
		if _director.selected_ability_index >= 0:
			var self_ability := _selected_ability_data(actor)
			if AbilitySystem.can_target_self(actor, self_ability):
				var self_face: int = _facing_from_drop(local, cell)
				if self_face < 0:
					self_face = actor.facing
				_planning.update_drag_sprite(local, TacticalUnitLayer.DragPreviewAnim.SPELL, self_face, preview_cell, drag_preview_failed)
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
			_planning.update_drag_sprite(local, mode, dash_face, preview_cell, drag_preview_failed)
			_set_drag_attack_target(drag_target_id, preview)
			return
	if _drag_route.size() > 1 or _drag_last_free != unit.position:
		if not force_basic_movement and _director.selected_ability_index >= 0:
			var move_self_ability := _selected_ability_data(actor)
			if (
				AbilitySystem.can_target_self(actor, move_self_ability)
				and not AbilitySystem.is_run_ability(move_self_ability)
			):
				var self_move_face: int = _facing_from_drop(local, _drag_last_free)
				if _drag_route.size() >= 2:
					self_move_face = _facing_toward(
						_drag_route[_drag_route.size() - 2], _drag_route[_drag_route.size() - 1],
					)
				elif _drag_last_free != unit.position:
					self_move_face = _facing_toward(unit.position, _drag_last_free)
				_planning.update_drag_sprite(
					local, TacticalUnitLayer.DragPreviewAnim.SPELL, self_move_face, preview_cell, drag_preview_failed,
				)
				_set_drag_attack_target(-1, preview)
				return
		var move_face: int = _facing_from_drop(local, _drag_last_free)
		if _drag_route.size() >= 2:
			move_face = _facing_toward(_drag_route[_drag_route.size() - 2], _drag_route[_drag_route.size() - 1])
		elif _drag_last_free != unit.position:
			move_face = _facing_toward(unit.position, _drag_last_free)
		_planning.update_drag_sprite(
			local, _drag_move_preview_mode(actor), move_face, preview_cell, drag_preview_failed,
		)
		_set_drag_attack_target(-1, preview)
		return
	var idle_face: int = _facing_from_drop(local, cell)
	if idle_face < 0:
		idle_face = actor.facing
	_planning.update_drag_sprite(local, TacticalUnitLayer.DragPreviewAnim.IDLE, idle_face, preview_cell, drag_preview_failed)
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
