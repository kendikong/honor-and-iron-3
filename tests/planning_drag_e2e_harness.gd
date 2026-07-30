class_name PlanningDragE2EHarness
extends RefCounted

## Production-path drag E2E helpers: _begin_drag → update_drag → on_left_release → flush.

const KNIGHT_START := Vector2i(4, 5)
const ENEMY_POS := Vector2i(7, 5)
const BASH_APPROACH := Vector2i(6, 5)


static func wire_minimal_fixture(
	knight_pos: Vector2i = KNIGHT_START,
	enemy_pos: Vector2i = Vector2i(-1, -1),
) -> Dictionary:
	var fix: Dictionary = _planning_fixture(knight_pos, enemy_pos)
	var intent := CombatIntentState.new()
	intent.bind(fix.director)
	var overlay := TacticalPlanningOverlay.new()
	overlay.setup(null, fix.director, intent)
	overlay.set_board(fix.board)
	fix.input._planning = overlay
	fix.input._intent_state = intent
	overlay.bind_planning_input(fix.input)
	fix["overlay"] = overlay
	fix["intent"] = intent
	return fix


static func wire_walk_fixture() -> Dictionary:
	return wire_drag_fixture(KNIGHT_START, Vector2i(-1, -1))


static func wire_bash_fixture() -> Dictionary:
	return wire_drag_fixture(KNIGHT_START, ENEMY_POS)


static func wire_drag_fixture(
	knight_pos: Vector2i = KNIGHT_START,
	enemy_pos: Vector2i = Vector2i(-1, -1),
) -> Dictionary:
	return wire_fixture(_planning_fixture(knight_pos, enemy_pos))


static func _plain_board(size: Vector2i, units: Array[UnitState]) -> BoardState:
	var terrain := TerrainData.new()
	terrain.id = &"plain"
	terrain.blocks_movement = false
	var board := BoardState.new()
	board.grid_size = size
	for y: int in range(size.y):
		for x: int in range(size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, terrain)
	board.units = units
	for unit: UnitState in units:
		GridSystem.set_occupant(board, unit.position, unit.id)
	return board


static func _planning_fixture(
	knight_pos: Vector2i,
	enemy_pos: Vector2i = Vector2i(-1, -1),
) -> Dictionary:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	director.plan_pre_move = Timeline.new()
	director.plan_action = Timeline.new()
	director.plan_post_move = Timeline.new()
	var knight_def: UnitData = DataLibrary.get_unit(&"knight")
	var knight: UnitState = UnitState.create(1, knight_def, GameEnums.Team.PLAYER, knight_pos)
	knight.active_abilities = DataLibrary.build_training_abilities(knight_def)
	knight.movement.points_left = knight.movement.max_points
	knight.ability.points_left = 3
	knight.ability.max_points = 3
	var units: Array[UnitState] = [knight]
	if enemy_pos.x >= 0:
		var dummy_def: UnitData = DataLibrary.get_training_dummy()
		assert(dummy_def != null, "PlanningDragE2E: training dummy definition missing")
		var enemy: UnitState = UnitState.create(
			2, dummy_def, GameEnums.Team.ENEMY, enemy_pos,
		)
		units.append(enemy)
	var board := _plain_board(Vector2i(12, 12), units)
	director.board = board
	director.base_board = board.clone()
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = 1
	input._director = director
	input.auto_use_skill_after_move = true
	return {
		"input": input,
		"director": director,
		"board": board,
		"knight": knight,
		"enemy": units[1] if units.size() > 1 else null,
	}


static func wire_fixture(fix: Dictionary) -> Dictionary:
	var map_stub := QaPlanningMapStub.new()
	var intent := CombatIntentState.new()
	intent.bind(fix.director)
	var overlay := TacticalPlanningOverlay.new()
	overlay.setup(null, fix.director, intent)
	overlay.set_board(fix.board)
	fix.input.set("_map_view", map_stub)
	fix.input._planning = overlay
	fix.input._intent_state = intent
	fix.input._bind_event_bus()
	overlay.bind_planning_input(fix.input)
	fix["map_stub"] = map_stub
	fix["overlay"] = overlay
	fix["intent"] = intent
	return fix


static func prepare_basic_walk(fix: Dictionary) -> void:
	fix.director.selected_ability_index = -1
	fix.input.force_basic_movement = true
	fix.input.auto_use_skill_after_move = false


static func begin_drag_route(fix: Dictionary, route: Array[Vector2i]) -> void:
	var input: CombatPlanningInput = fix.input
	var unit: UnitState = fix.knight if fix.has("knight") else fix.unit
	var origin: Vector2i = route[0] if not route.is_empty() else unit.position
	var local: Vector2 = fix.map_stub.grid_to_local(origin)
	input._begin_drag(unit, local, true)
	for i: int in range(1, route.size()):
		var cell: Vector2i = route[i]
		fix.map_stub.set_mock_mouse_for_cell(cell)
		input.update_drag(fix.map_stub.grid_to_local(cell))


static func release_at(fix: Dictionary, cell: Vector2i) -> void:
	fix.map_stub.set_mock_mouse_for_cell(cell)
	var local: Vector2 = fix.map_stub.grid_to_local(cell)
	fix.input.on_left_release(local)
	fix.director.flush_plan_refresh_signals_if_pending()


static func paint_and_release(
	fix: Dictionary,
	route: Array[Vector2i],
	release_cell: Vector2i,
) -> void:
	begin_drag_route(fix, route)
	release_at(fix, release_cell)


static func click_commit_at(
	fix: Dictionary,
	cell: Vector2i,
) -> bool:
	var slots: Dictionary = fix.input._final_commit_slots_for_click_at_cell(
		fix.director.selected_unit_id, cell, Vector2.ZERO,
	)
	if _slots_invalid(slots):
		return false
	if not fix.director.commit_from_slots(fix.director.selected_unit_id, slots):
		return false
	fix.director.flush_plan_refresh_signals_if_pending()
	return true


static func undo_selected(fix: Dictionary) -> void:
	fix.input.on_right_click()
	fix.director.flush_plan_refresh_signals_if_pending()


static func emit_board_changed(fix: Dictionary) -> void:
	EventBus.board_changed.emit(fix.director.board)


static func _slots_invalid(slots: Dictionary) -> bool:
	var flag: Variant = slots.get("invalid", false)
	if flag is bool:
		return flag
	if flag is String:
		return not (flag as String).is_empty()
	return bool(flag)
