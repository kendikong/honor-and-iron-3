class_name PlanningDragE2EHarness
extends RefCounted

## Production-path drag E2E helpers: _begin_drag → update_drag → on_left_release → flush.

const KNIGHT_START := Vector2i(4, 5)
const ENEMY_POS := Vector2i(7, 5)
const BASH_APPROACH := Vector2i(6, 5)
static var _live_fixtures: Array[Dictionary] = []
static var _host: Node = null


static func set_host(host: Node) -> void:
	_host = host


static func wire_minimal_fixture(
	knight_pos: Vector2i = KNIGHT_START,
	enemy_pos: Vector2i = Vector2i(-1, -1),
) -> Dictionary:
	var fix: Dictionary = _planning_fixture(knight_pos, enemy_pos)
	var intent := CombatIntentState.new()
	intent.bind(fix.director)
	var overlay := TacticalPlanningOverlay.new()
	_attach_to_host(overlay)
	overlay.setup(null, fix.director, intent)
	overlay.set_board(fix.board)
	fix.input._planning = overlay
	fix.input._intent_state = intent
	overlay.bind_planning_input(fix.input)
	fix["overlay"] = overlay
	fix["intent"] = intent
	_track_fixture(fix)
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
	knight.ability.points_left = 1
	knight.ability.max_points = 1
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
	_attach_to_host(map_stub)
	_attach_to_host(overlay)
	overlay.setup(null, fix.director, intent)
	overlay.set_board(fix.board)
	fix.input._map_view = map_stub
	fix.input._planning = overlay
	fix.input._intent_state = intent
	fix.input._bind_event_bus()
	fix.input.set_qa_pointer_grid_cell(fix.knight.position)
	overlay.bind_planning_input(fix.input)
	fix["map_stub"] = map_stub
	fix["overlay"] = overlay
	fix["intent"] = intent
	_track_fixture(fix)
	return fix


static func track_raw_fixture(fix: Dictionary) -> void:
	_track_fixture(fix)


static func track_overlay_fixture(fix: Dictionary, overlay: TacticalPlanningOverlay) -> void:
	_attach_to_host(overlay)
	fix["overlay"] = overlay
	_track_fixture(fix)


static func cleanup_all() -> void:
	var freed_directors: Dictionary = {}
	for fix: Dictionary in _live_fixtures:
		var director: CombatDirector = null
		var director_ref: Variant = fix.get("director", null)
		if director_ref is Object and is_instance_valid(director_ref):
			director = director_ref as CombatDirector
			director.flush_plan_refresh_signals_if_pending()
		var input_ref: Variant = fix.get("input", null)
		if input_ref is CombatPlanningInput:
			var input := input_ref as CombatPlanningInput
			input.flush_deferred_planning()
			input.teardown()
		var overlay_ref: Variant = fix.get("overlay", null)
		if overlay_ref is Object and is_instance_valid(overlay_ref):
			var overlay := overlay_ref as TacticalPlanningOverlay
			overlay.teardown()
			overlay.free()
		var map_stub_ref: Variant = fix.get("map_stub", null)
		if map_stub_ref is Object and is_instance_valid(map_stub_ref):
			(map_stub_ref as QaPlanningMapStub).free()
		if director != null and is_instance_valid(director):
			var director_id: int = director.get_instance_id()
			if not freed_directors.has(director_id):
				if director.get_parent() != null:
					director.get_parent().remove_child(director)
				director.queue_free()
				freed_directors[director_id] = true
	_live_fixtures.clear()


static func _track_fixture(fix: Dictionary) -> void:
	if _live_fixtures.find(fix) >= 0:
		return
	_live_fixtures.append(fix)


static func _attach_to_host(node: Node) -> void:
	if _host != null and is_instance_valid(_host) and node.get_parent() == null:
		_host.add_child(node)


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
		fix.input.set_qa_pointer_grid_cell(cell)
		input.update_drag(fix.map_stub.grid_to_local(cell))


static func release_at(fix: Dictionary, cell: Vector2i) -> void:
	fix.input.set_qa_pointer_grid_cell(cell)
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
	fix.input._on_board_changed(fix.director.board)


static func _slots_invalid(slots: Dictionary) -> bool:
	var flag: Variant = slots.get("invalid", false)
	if flag is bool:
		return flag
	if flag is String:
		return not (flag as String).is_empty()
	return bool(flag)
