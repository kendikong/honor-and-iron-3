class_name CombatPlanningInput
extends RefCounted

## H&I planning semantics ported from board_view — used by TacticalInputController.

const DRAG_CLICK_MOVE_THRESHOLD: float = 8.0
const DRAG_SELF_SKILL_DELAY_MS: int = 150

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
var _drag_press_local: Vector2 = Vector2.ZERO
var _drag_press_time_ms: int = 0
var _drag_unit_was_selected: bool = false
var _drag_saved_preview: BoardState = null


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


func cancel_drag() -> void:
	dragging = false
	_drag_unit_id = -1
	_drag_route.clear()
	if _planning != null:
		_planning.clear_drag_route()
	_restore_committed_preview()


func cancel_aim() -> void:
	aiming = false
	if _intent_state != null:
		_intent_state.set_skill_interaction_active(false)
	if _planning != null:
		_planning.set_aim_mode(false)


func on_left_press(local: Vector2) -> void:
	var cell: Vector2i = _map_view.screen_to_grid(_map_view.get_viewport().get_mouse_position())
	var board: BoardState = _director.board
	if board == null or not board.is_in_bounds(cell):
		cancel_aim()
		return
	var unit := board.get_unit_at(cell)
	if unit != null and not unit.is_enemy() and unit.is_alive():
		if aiming and unit.id == _director.selected_unit_id:
			var actor := _proj_unit(_director.selected_unit_id)
			if actor != null and _ability_range(actor) == 0:
				_director.rpc_plan_attack(_director.selected_unit_id, _director.selected_ability_index, unit.id)
				_play_sfx("ability")
				cancel_aim()
				return
			_play_sfx("invalid")
			return
		if aiming:
			cancel_aim()
		var was_selected: bool = unit.id == _director.selected_unit_id
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
				if _ability_range(actor) == 0:
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
			if not _try_plan_skill_at_coord(sel_unit, cell, local) and _basic_move_allowed():
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
	dragging = false
	_planning.clear_drag_route()
	var board: BoardState = _director.board
	var actor := board.get_unit_by_id(_drag_unit_id)
	var cell: Vector2i = _map_view.screen_to_grid(_map_view.get_viewport().get_mouse_position())
	if actor == null or not board.is_in_bounds(cell):
		_restore_committed_preview()
		return
	var dropped_on := board.get_unit_at(cell)
	if dropped_on != null and dropped_on.id != actor.id:
		var waypoints: Array[Vector2i] = _route_waypoints()
		_plan_approach_or_trample_on_enemy(_drag_unit_id, dropped_on, local, _drag_last_free, waypoints)
	elif cell == actor.position:
		if (
			_director.selected_ability_index >= 0
			and _ability_range(actor) == 0
			and _drag_unit_was_selected
			and _drag_self_skill_intent(local)
		):
			_director.rpc_plan_attack(_drag_unit_id, _director.selected_ability_index, actor.id)
			_play_sfx("ability")
			_director.select_ability(-1)
		else:
			var face: int = _facing_from_drop(local, cell)
			if face >= 0:
				_director.rpc_plan_face(_drag_unit_id, face)
				_play_sfx("move")
	elif dropped_on == null:
		var waypoints: Array[Vector2i] = _route_waypoints()
		if not _try_plan_skill_at_coord(actor, cell, local):
			_try_plan_basic_move(_drag_unit_id, cell, local, waypoints)
	_drag_route.clear()


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
	var drag_target_id: int = -1
	if occ != null and occ.id != _drag_unit_id:
		drag_target_id = occ.id
	var preview: Dictionary = _director.preview_drag(
		_drag_unit_id,
		_drag_last_free,
		drag_target_id,
		_route_waypoints(),
	)
	if preview.has("temp_board"):
		_planning.set_preview_board(preview["temp_board"])
	_planning.set_drag_route(_drag_route)
	_planning.recompute_hover_ranges(
		force_basic_movement,
		_director.selected_ability_index,
		dragging,
		_drag_unit_id,
	)


func _begin_drag(unit: UnitState, local: Vector2, was_already_selected: bool) -> void:
	_stash_committed_preview()
	dragging = true
	_drag_unit_id = unit.id
	_drag_unit_was_selected = was_already_selected
	_drag_press_local = local
	_drag_press_time_ms = Time.get_ticks_msec()
	_drag_route = [unit.position]
	_drag_last_free = unit.position
	_planning.set_drag_route(_drag_route)
	_play_sfx("select")


func _stash_committed_preview() -> void:
	if _planning != null:
		_drag_saved_preview = _planning.get_preview_board()


func _restore_committed_preview() -> void:
	if _drag_saved_preview != null and _planning != null:
		_planning.set_preview_board(_drag_saved_preview)
	_drag_saved_preview = null


func _on_selection_changed(unit_id: int) -> void:
	if unit_selected_abilities.has(unit_id):
		_director.select_ability(int(unit_selected_abilities[unit_id]))
	elif unit_id < 0:
		pass


func _on_ability_selected(index: int) -> void:
	if _director.selected_unit_id >= 0:
		unit_selected_abilities[_director.selected_unit_id] = index


func _on_preview_updated(_result: SimResult) -> void:
	_drag_saved_preview = null


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
			if _ability_range(actor) == 0:
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
	if GridSystem.manhattan(last, cell) != 1:
		return
	var board: BoardState = _director.board
	var unit := board.get_unit_by_id(_drag_unit_id)
	if unit == null:
		return
	if not MovementSystem.is_walkable_for(board, cell, unit):
		return
	if not force_basic_movement and _director.selected_ability_index >= 0:
		var occ := board.get_unit_at(cell)
		if occ != null and occ.is_enemy() and MovementSystem.has_trample(unit):
			return
	if _drag_route.size() - 1 >= unit.movement.points_left:
		return
	_drag_route.append(cell)


func _route_waypoints() -> Array[Vector2i]:
	var waypoints: Array[Vector2i] = []
	if _drag_route.size() >= 2:
		for i: int in range(1, _drag_route.size()):
			waypoints.append(_drag_route[i])
	return waypoints


func _drag_self_skill_intent(release_local: Vector2) -> bool:
	if _drag_route.size() > 1:
		return true
	if release_local.distance_to(_drag_press_local) >= DRAG_CLICK_MOVE_THRESHOLD:
		return true
	return Time.get_ticks_msec() - _drag_press_time_ms >= DRAG_SELF_SKILL_DELAY_MS


func _ability_has_dash(ability: AbilityData) -> bool:
	return AbilitySystem.ability_has_dash(ability)


func _selected_ability_data(unit: UnitState) -> AbilityData:
	if unit == null:
		return null
	var idx: int = _director.selected_ability_index
	if idx < 0 or idx >= unit.active_abilities.size():
		return null
	return unit.active_abilities[idx]


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
	return GridSystem.manhattan(actor_pos, target.position) <= rng


func _can_move_to(unit: UnitState, coord: Vector2i) -> bool:
	if unit == null or coord == unit.position:
		return false
	if unit.movement.points_left <= 0:
		return false
	var board := _proj()
	if not MovementSystem.can_end_movement_on(board, coord, unit):
		return false
	return not MovementSystem.find_path(board, unit.position, coord, unit.movement.points_left).is_empty()


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
	return _director.phase in [
		CombatDirector.Phase.PLANNING_PHASE_1,
		CombatDirector.Phase.PLANNING_PHASE_2,
	]


func _play_sfx(key: String) -> void:
	if _sfx != null:
		_sfx.play(key)
