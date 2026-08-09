class_name PlanningChecklistHarness
extends RefCounted

## Shared harness for 7-phase planning skill checklist scenarios.
## Asserts production layers: blue/red overlay, live preview, slots, cursor, economy, sim.
## Commit path: paint → commit_from_slots → promote → deferred flush (F5 parity).

const KNIGHT_START := Vector2i(4, 5)
const ENEMY_POS := Vector2i(7, 5)
const BASH_APPROACH := Vector2i(6, 5)
const BASH_HOVER_WALK := Vector2i(5, 5)
const K4_START := Vector2i(4, 1)
const K4_RUN_TRIGGER := Vector2i(3, 2)
const K4_DETOUR_PLUS_RUN_ROUTE: Array[Vector2i] = [
	K4_START, Vector2i(5, 1), Vector2i(5, 2), Vector2i(4, 2), K4_RUN_TRIGGER,
]
const HOOK_KNIGHT_START := Vector2i(1, 3)
const HOOK_ENEMY_POS := Vector2i(4, 3)
const TRAMPLE_START := Vector2i(5, 4)
const TRAMPLE_END := Vector2i(6, 3)
const TRAMPLE_ROUTE: Array[Vector2i] = [Vector2i(6, 4), Vector2i(6, 3)]

const SHIELD_BASH_ID: StringName = &"knight_shield_bash"
const CHAIN_HOOK_ID: StringName = &"knight_chain_hook"
const TRAMPLE_ID: StringName = &"knight_trampling_advance"
const BOWLING_CHARGE_ID: StringName = &"knight_bowling_charge"
const KNIGHT_SWAP_ID: StringName = &"knight_swap"
const K2_CELL := HOOK_KNIGHT_START
const K3_CELL := TRAMPLE_START
const K4_CELL := K4_START
const E_BASH_CELL := ENEMY_POS
const E_HOOK_CELL := HOOK_ENEMY_POS
const SWAP_ALLY_CELL := Vector2i(4, 4)
const SWAP_PREMOVE_ROUTE: Array[Vector2i] = [Vector2i(3, 4), Vector2i(3, 5)]
const SWAP_PREMOVE_DEST := Vector2i(3, 5)
const WALK_SWAP_ALLY_CELL := Vector2i(2, 4)
const WALK_SWAP_APPROACH := Vector2i(3, 4)
const OFF_BLUE_CELL := Vector2i(9, 9)
const OFF_MAP_HOVER := Vector2i(-999, -999)
const TRAMPLE_POST_DEST := Vector2i(8, 2)
const TRAMPLE_POST_ROUTE: Array[Vector2i] = [
	TRAMPLE_END, Vector2i(7, 3), Vector2i(8, 3), TRAMPLE_POST_DEST,
]
const TRAMPLE_FULL_PATH: Array[Vector2i] = [
	TRAMPLE_START, TRAMPLE_ROUTE[0], TRAMPLE_ROUTE[1],
]
const K1_BASH_ROUTE: Array[Vector2i] = [KNIGHT_START, BASH_HOVER_WALK, BASH_APPROACH]


static func wire_bash_board_minimal() -> Dictionary:
	PlanningDragE2EHarness.cleanup_all()
	var fix: Dictionary = PlanningDragE2EHarness.wire_minimal_fixture(
		KNIGHT_START, ENEMY_POS,
	)
	return fix


static func wire_bash_board() -> Dictionary:
	PlanningDragE2EHarness.cleanup_all()
	return PlanningDragE2EHarness.wire_fixture(
		PlanningDragE2EHarness._planning_fixture(KNIGHT_START, ENEMY_POS),
	)


static func wire_hook_board() -> Dictionary:
	PlanningDragE2EHarness.cleanup_all()
	var base: Dictionary = PlanningDragE2EHarness._planning_fixture(
		HOOK_KNIGHT_START, HOOK_ENEMY_POS,
	)
	return PlanningDragE2EHarness.wire_fixture(base)


static func wire_trample_board() -> Dictionary:
	PlanningDragE2EHarness.cleanup_all()
	var fix: Dictionary = PlanningDragE2EHarness._planning_fixture(TRAMPLE_START)
	fix.input.auto_use_skill_after_move = false
	var trample_idx: int = ability_index(fix.knight, TRAMPLE_ID)
	if trample_idx >= 0:
		fix.director.selected_ability_index = trample_idx
	fix["unit"] = fix.knight
	fix["trample_idx"] = trample_idx
	return PlanningDragE2EHarness.wire_fixture(fix)


static func wire_k4_board() -> Dictionary:
	PlanningDragE2EHarness.cleanup_all()
	var fix: Dictionary = PlanningDragE2EHarness.wire_fixture(
		PlanningDragE2EHarness._planning_fixture(K4_START, ENEMY_POS),
	)
	fix.director.auto_run = true
	fix.input.auto_use_skill_after_move = false
	fix.input.force_basic_movement = false
	return fix


static func ability_index(unit: UnitState, ability_id: StringName) -> int:
	for i: int in range(unit.active_abilities.size()):
		var ability: AbilityData = unit.active_abilities[i]
		if ability != null and ability.id == ability_id:
			return i
	return -1


static func select_ability(fix: Dictionary, ability_id: StringName) -> int:
	var idx: int = ability_index(fix.knight, ability_id)
	if idx < 0:
		return -1
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var prev: int = director.selected_ability_index
	director.selected_ability_index = idx
	var stand: Vector2i = projected_unit(fix, director.selected_unit_id).position
	var intent: CombatIntentState = fix.get("intent", null) as CombatIntentState
	if intent != null:
		intent.set_hover_coord(stand)
	if input != null and prev != idx:
		input._on_ability_selected(idx)
		input.call("_run_ability_settled_refresh")
	flush_planning(fix)
	return idx


static func flush_planning(fix: Dictionary) -> void:
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = fix.get("overlay", null) as TacticalPlanningOverlay
	director.flush_plan_refresh_signals_if_pending()
	if overlay != null:
		overlay._flush_hover_recompute()
	if input != null:
		input._flush_hover_preview_refresh()


static func hover(fix: Dictionary, cell: Vector2i) -> void:
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	input.set_qa_pointer_grid_cell(cell)
	input.on_hover_moved(cell)
	input._flush_hover_heavy_sync()
	if overlay != null:
		overlay._recompute_hover_ranges_from_inputs()


static func hover_off_map(fix: Dictionary) -> void:
	var input: CombatPlanningInput = fix.input
	input.clear_qa_pointer_override()
	input.on_hover_moved(OFF_MAP_HOVER)
	if input._intent_state != null:
		input._intent_state.set_hover_coord(OFF_MAP_HOVER)
	flush_planning(fix)


static func refresh_attack_hover(fix: Dictionary, cell: Vector2i) -> void:
	hover(fix, cell)
	var input: CombatPlanningInput = fix.input
	if input != null:
		input.call("_refresh_selected_interaction_preview")
	flush_planning(fix)


static func slots_for_click(fix: Dictionary, cell: Vector2i) -> Dictionary:
	return fix.input._final_commit_slots_for_click_at_cell(
		fix.director.selected_unit_id, cell, Vector2.ZERO,
	)


static func slots_for_hover(fix: Dictionary, cell: Vector2i) -> Dictionary:
	var empty_wps: Array[Vector2i] = []
	var empty_legal: Array[Vector2i] = []
	return fix.input._final_commit_slots_for_interaction(
		fix.director.selected_unit_id,
		cell,
		empty_wps,
		empty_legal,
		Vector2i(-999999, -999999),
	)


static func assert_execute_spends_ap(
	failures: Array[String],
	label: String,
	board: BoardState,
	action: TimelineAction,
	expected_ap_left: int,
) -> void:
	var trial: BoardState = board.clone()
	var actor: UnitState = trial.get_unit_by_id(action.actor_id)
	if actor == null:
		assert_fail(failures, label, "actor missing for execute AP check")
		return
	var events: Array[SimEvent] = []
	AbilitySystem.execute(trial, action, events)
	assert_eq_int(failures, label, actor.ability.points_left, expected_ap_left)


static func assert_committed_ghost_pos(
	failures: Array[String],
	label: String,
	fix: Dictionary,
	unit_id: int,
	expected: Vector2i,
) -> void:
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	if overlay == null:
		assert_fail(failures, label, "overlay missing")
		return
	var board: BoardState = overlay.get_committed_preview().preview_board
	if board == null:
		assert_fail(failures, label, "committed preview board missing")
		return
	var unit: UnitState = board.get_unit_by_id(unit_id)
	assert_eq_cell(
		failures, label,
		unit.position if unit != null else Vector2i(-999999, -999999),
		expected,
	)


static func commit_paint_promote_only(fix: Dictionary, cell: Vector2i) -> bool:
	var slots: Dictionary = slots_for_click(fix, cell)
	if _slots_invalid(slots):
		return false
	var unit_id: int = fix.director.selected_unit_id
	fix.input.call("_paint_intent_slots_before_commit", unit_id, slots)
	if not fix.director.commit_from_slots(unit_id, slots):
		return false
	fix.input.call("_promote_intent_preview_after_commit")
	return true


static func assert_committed_preview_push(
	failures: Array[String], label: String, fix: Dictionary, enemy_id: int,
) -> void:
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	if overlay == null:
		assert_fail(failures, label, "overlay missing")
		return
	var live_pushes: Array = fix.input.preview_state.preview_pushes.get(enemy_id, [])
	var committed_pushes: Array = overlay.get_committed_preview().preview_pushes.get(enemy_id, [])
	assert_true(
		failures, label, not live_pushes.is_empty(),
		"live preview must show push before promote",
	)
	assert_true(
		failures, label, committed_pushes == live_pushes,
		"committed overlay pushes %s must match live %s after promote"
		% [committed_pushes, live_pushes],
	)


static func assert_preview_approach_tile(
	failures: Array[String],
	label: String,
	fix: Dictionary,
	target_unit_id: int,
	ability_index: int,
	preferred_tile: Vector2i,
	expected: Vector2i,
) -> void:
	var stand: Vector2i = fix.director.preview_approach_tile(
		1, target_unit_id, ability_index, preferred_tile,
	)
	assert_eq_cell(failures, label, stand, expected)


static func assert_player_turn_ap_spent(
	failures: Array[String], label: String, director: CombatDirector, unit_id: int, expected_ap: int,
) -> void:
	var board: BoardState = simulate_player_committed(director)
	var unit: UnitState = board.get_unit_by_id(unit_id)
	assert_eq_int(
		failures, label,
		unit.ability.points_left if unit != null else -1,
		expected_ap,
	)


static func assert_action_range_hidden(
	failures: Array[String], label: String, fix: Dictionary,
) -> void:
	assert_true(
		failures, label,
		not fix.input.action_range_visible_for_hover(),
		"action_range_visible_for_hover must be false",
	)


static func commit_production(fix: Dictionary, cell: Vector2i) -> Dictionary:
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var slots: Dictionary = slots_for_click(fix, cell)
	if _slots_invalid(slots):
		return slots
	var unit_id: int = director.selected_unit_id
	input.call("_paint_intent_slots_before_commit", unit_id, slots)
	if not director.commit_from_slots(unit_id, slots):
		slots["invalid"] = "commit_from_slots_failed"
		return slots
	input.call("_promote_intent_preview_after_commit")
	flush_planning(fix)
	return slots


static func commit_slots_production(fix: Dictionary, slots: Dictionary) -> bool:
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	if _slots_invalid(slots):
		return false
	var unit_id: int = director.selected_unit_id
	input.call("_paint_intent_slots_before_commit", unit_id, slots)
	if not director.commit_from_slots(unit_id, slots):
		return false
	input.call("_promote_intent_preview_after_commit")
	flush_planning(fix)
	return true


static func simulate_player_committed(director: CombatDirector) -> BoardState:
	var board: BoardState = director.base_board.clone()
	board.intents = []
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(board, director.get_player_plan(), events)
	return board


static func simulate_committed(director: CombatDirector) -> SimResult:
	var start_board: BoardState = director.base_board.clone()
	start_board.intents = []
	return Simulator.simulate(start_board, director.get_player_plan())


static func projected_unit(fix: Dictionary, unit_id: int = 1) -> UnitState:
	var director: CombatDirector = fix.director
	if director.projected_state != null:
		var u: UnitState = director.projected_state.get_unit_by_id(unit_id)
		if u != null:
			return u
	return fix.board.get_unit_by_id(unit_id)


static func preview_unit_pos(fix: Dictionary, unit_id: int = 1) -> Vector2i:
	var input: CombatPlanningInput = fix.input
	if input.is_live_preview_active() and input.preview_state.preview_board != null:
		var u: UnitState = input.preview_state.preview_board.get_unit_by_id(unit_id)
		if u != null:
			return u.position
	return projected_unit(fix, unit_id).position


static func preview_path(fix: Dictionary, unit_id: int = 1) -> Array[Vector2i]:
	var raw: Array = fix.input.preview_state.preview_paths.get(unit_id, [])
	var out: Array[Vector2i] = []
	for v: Variant in raw:
		out.append(v as Vector2i)
	return out


static func push_destination(fix: Dictionary, enemy_id: int = 2) -> Vector2i:
	var pushes: Array = fix.input.preview_state.preview_pushes.get(enemy_id, [])
	for seg: Variant in pushes:
		if seg is Array and (seg as Array).size() >= 2:
			return (seg as Array)[1] as Vector2i
	return Vector2i(-999999, -999999)


static func collect_red_tiles(fix: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	var board: BoardState = fix.board
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			var coord := Vector2i(x, y)
			if overlay.is_hover_action_range_tile(coord):
				out.append(coord)
	return out


static func collect_blue_tiles(fix: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	var board: BoardState = fix.board
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			var coord := Vector2i(x, y)
			if overlay.is_hover_move_tile(coord):
				out.append(coord)
	return out


static func walk_diamond_from(
	board: BoardState,
	origin: Vector2i,
	mp_budget: int,
) -> Array[Vector2i]:
	var mt: int = GameEnums.MovementType.WALK
	return MovementSystem.get_reachable_tiles(board, origin, mp_budget, mt)


static func collect_drag_hover_tiles(fix: Dictionary) -> Array[Vector2i]:
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	if overlay != null:
		overlay._recompute_hover_ranges_from_inputs()
	return input._snapshot_drag_legal_move_tiles()


static func collect_red_visible_hovers(
	fix: Dictionary,
	cells: Array[Vector2i],
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var input: CombatPlanningInput = fix.input
	for cell: Vector2i in cells:
		hover(fix, cell)
		input.call("_run_ability_settled_refresh")
		flush_planning(fix)
		if input.action_range_visible_for_hover():
			out.append(cell)
	return out


## Overlay truth: cells where red tiles are actually drawn (not gate-only).
static func collect_overlay_red_hovers(
	fix: Dictionary,
	cells: Array[Vector2i],
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in cells:
		hover(fix, cell)
		fix.input.call("_run_ability_settled_refresh")
		flush_planning(fix)
		if not collect_red_tiles(fix).is_empty():
			out.append(cell)
	return out


## F5 contract: when planning UI shows 0 AP, red must be off (gate + overlay).
static func assert_no_red_when_display_ap_zero(
	failures: Array[String],
	label: String,
	fix: Dictionary,
	unit_id: int = 1,
) -> void:
	var input: CombatPlanningInput = fix.input
	var display_ap: int = input.planning_display_ap_left(unit_id)
	assert_eq_int(failures, "%s/display_ap_pre" % label, display_ap, 0)
	if display_ap != 0:
		return
	var gate_on: bool = input.action_range_visible_for_hover()
	var overlay_red: Array[Vector2i] = collect_red_tiles(fix)
	assert_true(
		failures,
		label,
		not gate_on,
		"visibility gate must be off when display AP is 0 (gate=%s)" % gate_on,
	)
	assert_true(
		failures,
		label,
		overlay_red.is_empty(),
		"overlay red must be empty when display AP is 0 (tiles=%s)" % [overlay_red],
	)


static func collect_cells_where_hover_stand_matches(
	fix: Dictionary,
	cells: Array[Vector2i],
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var input: CombatPlanningInput = fix.input
	for cell: Vector2i in cells:
		hover(fix, cell)
		input.call("_run_ability_settled_refresh")
		flush_planning(fix)
		if input.action_range_intent_stand_cell(1) == cell:
			out.append(cell)
	return out


static func blue_tile_near_stand(
	blue_tiles: Array[Vector2i],
	stand: Vector2i,
	prefer_far: bool = false,
) -> Vector2i:
	var best: Vector2i = Vector2i(-999999, -999999)
	var best_dist: int = -1 if prefer_far else 999999
	for tile: Vector2i in blue_tiles:
		if tile == stand:
			continue
		var dist: int = GridSystem.manhattan(stand, tile)
		if prefer_far:
			if dist > best_dist:
				best_dist = dist
				best = tile
		elif dist < best_dist:
			best_dist = dist
			best = tile
	return best


static func slots_for_painted_hover(fix: Dictionary, dest: Vector2i) -> Dictionary:
	var input: CombatPlanningInput = fix.input
	var params: Dictionary = input._commit_interaction_params(dest, -1)
	return input._final_commit_slots_for_interaction(
		fix.director.selected_unit_id,
		params.cell as Vector2i,
		params.waypoints as Array[Vector2i],
		params.legal_move_tiles as Array[Vector2i],
		params.preferred as Vector2i,
		params.face_dir as int,
	)


static func commit_painted_run_route(
	fix: Dictionary,
	route: Array[Vector2i],
	dest: Vector2i,
	ap_left: int = 1,
	mp_left: int = 0,
) -> bool:
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	director.auto_run = true
	input.auto_use_skill_after_move = false
	director.selected_ability_index = -1
	set_knight_pools(fix, ap_left, mp_left)
	TramplingAdvanceE2ETest._paint_drag_route(input, fix.knight, route, dest)
	hover(fix, dest)
	var slots: Dictionary = slots_for_painted_hover(fix, dest)
	if _slots_invalid(slots):
		return false
	if not commit_slots_production(fix, slots):
		return false
	input.call("_promote_intent_preview_after_commit")
	flush_planning(fix)
	return true


static func assert_red_off_at_hover(
	failures: Array[String],
	label: String,
	fix: Dictionary,
	ability: AbilityData,
	cell: Vector2i,
) -> void:
	hover(fix, cell)
	fix.input.call("_run_ability_settled_refresh")
	flush_planning(fix)
	assert_red_contract(failures, label, fix, ability, false)


static func expected_red_tiles(
	board: BoardState,
	unit: UnitState,
	ability: AbilityData,
	stand: Vector2i,
) -> Array[Vector2i]:
	return AbilitySystem.planning_action_range_tiles(board, unit, ability, stand)


static func find_run_hover_tile(board: BoardState, unit: UnitState) -> Vector2i:
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			var coord := Vector2i(x, y)
			if coord == unit.position:
				continue
			if AbilitySystem.movement_requires_run(board, unit, coord, []):
				return coord
	return Vector2i(-999999, -999999)


static func find_painted_center_run_dest(
	fix: Dictionary,
	ap_left: int = 1,
	mp_left: int = 1,
	min_route_len: int = 3,
) -> Dictionary:
	var board: BoardState = fix.board
	var unit: UnitState = fix.knight
	var input: CombatPlanningInput = fix.input
	const CENTER_MIN := 4
	const CENTER_MAX := 7
	var edge_run: Vector2i = find_run_hover_tile(board, unit)
	for y: int in range(CENTER_MIN, CENTER_MAX + 1):
		for x: int in range(CENTER_MIN, CENTER_MAX + 1):
			var dest := Vector2i(x, y)
			if dest == unit.position or dest == edge_run:
				continue
			var route: Array[Vector2i] = build_orthogonal_route(unit.position, dest)
			if route.size() < min_route_len:
				continue
			set_knight_pools(fix, ap_left, mp_left)
			flush_planning(fix)
			fix.director.selected_ability_index = -1
			TramplingAdvanceE2ETest._paint_drag_route(input, unit, route, dest)
			hover(fix, dest)
			var slots: Dictionary = slots_for_painted_hover(fix, dest)
			if _slots_invalid(slots):
				continue
			var pre: Array = slots.get("pre", []) as Array
			if pre.is_empty() or not (pre[0] is TimelineAction):
				continue
			var step: TimelineAction = pre[0] as TimelineAction
			if not step.uses_run or step.target_coord != dest:
				continue
			return {"dest": dest, "route": route, "slots": slots}
	return {}


static func build_orthogonal_route_y_first(origin: Vector2i, dest: Vector2i) -> Array[Vector2i]:
	var route: Array[Vector2i] = [origin]
	var cursor: Vector2i = origin
	while cursor.y != dest.y:
		cursor.y += 1 if dest.y > cursor.y else -1
		route.append(cursor)
	while cursor.x != dest.x:
		cursor.x += 1 if dest.x > cursor.x else -1
		route.append(cursor)
	return route


static func try_painted_run_to_dest(
	fix: Dictionary,
	dest: Vector2i,
	ap_left: int,
	mp_left: int,
) -> Dictionary:
	var unit: UnitState = fix.knight
	var input: CombatPlanningInput = fix.input
	var route: Array[Vector2i] = build_orthogonal_route_y_first(unit.position, dest)
	fix.director.auto_run = true
	fix.director.selected_ability_index = -1
	set_knight_pools(fix, ap_left, mp_left)
	flush_planning(fix)
	TramplingAdvanceE2ETest._paint_drag_route(input, unit, route, dest)
	hover(fix, dest)
	var slots: Dictionary = slots_for_painted_hover(fix, dest)
	if _slots_invalid(slots):
		return {}
	var pre: Array = slots.get("pre", []) as Array
	if pre.is_empty() or not (pre[0] is TimelineAction):
		return {}
	var step: TimelineAction = pre[0] as TimelineAction
	if not step.uses_run or step.target_coord != dest:
		return {}
	return {"dest": dest, "route": route, "slots": slots}


static func build_orthogonal_route(origin: Vector2i, dest: Vector2i) -> Array[Vector2i]:
	var route: Array[Vector2i] = [origin]
	var cursor: Vector2i = origin
	while cursor.x != dest.x:
		cursor.x += 1 if dest.x > cursor.x else -1
		route.append(cursor)
	while cursor.y != dest.y:
		cursor.y += 1 if dest.y > cursor.y else -1
		route.append(cursor)
	return route


static func set_knight_pools(fix: Dictionary, ap_left: int, mp_left: int) -> void:
	var director: CombatDirector = fix.director
	var boards: Array[BoardState] = [
		director.base_board,
		director.board,
		director.projected_state,
	]
	for board: BoardState in boards:
		if board == null:
			continue
		var knight: UnitState = board.get_unit_by_id(fix.knight.id)
		if knight == null:
			continue
		knight.ability.points_left = ap_left
		knight.ability.max_points = maxi(ap_left, knight.ability.max_points)
		knight.movement.points_left = mp_left
		knight.movement.max_points = maxi(mp_left, knight.movement.max_points)


static func assert_fail(failures: Array[String], label: String, detail: String) -> void:
	failures.append("%s: %s" % [label, detail])


static func assert_true(
	failures: Array[String], label: String, cond: bool, detail: String,
) -> void:
	if not cond:
		assert_fail(failures, label, detail)


static func assert_eq_cell(
	failures: Array[String], label: String, got: Vector2i, expected: Vector2i,
) -> void:
	if got != expected:
		assert_fail(failures, label, "expected %s got %s" % [expected, got])


static func assert_eq_int(
	failures: Array[String], label: String, got: int, expected: int,
) -> void:
	if got != expected:
		assert_fail(failures, label, "expected %d got %d" % [expected, got])


static func assert_red_contract(
	failures: Array[String],
	label: String,
	fix: Dictionary,
	ability: AbilityData,
	expect_show: bool,
	expect_stand: Vector2i = Vector2i(-999999, -999999),
	unit_id: int = -1,
) -> void:
	var uid: int = unit_id if unit_id > 0 else fix.director.selected_unit_id
	var unit: UnitState = fix.board.get_unit_by_id(uid)
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	var visible: bool = input.action_range_visible_for_hover()
	var stand: Vector2i = input.action_range_intent_stand_cell(uid)
	var has_red: bool = not collect_red_tiles(fix).is_empty()
	assert_true(
		failures, label,
		visible == expect_show,
		"visibility gate expected %s got %s" % [expect_show, visible],
	)
	assert_true(
		failures, label,
		has_red == expect_show,
		"overlay red expected %s got %s" % [expect_show, has_red],
	)
	if expect_stand.x > -900000:
		assert_eq_cell(failures, label, stand, expect_stand)
	if expect_show and ability != null and unit != null:
		var range_tiles: Array[Vector2i] = expected_red_tiles(
			fix.board, unit, ability, stand,
		)
		var anchored: bool = false
		for tile: Vector2i in range_tiles:
			if overlay.is_hover_action_range_tile(tile):
				anchored = true
				break
		assert_true(
			failures, label, anchored,
			"no overlay red tile from AbilitySystem range at stand %s" % stand,
		)


static func assert_red_excludes_cell(
	failures: Array[String],
	label: String,
	fix: Dictionary,
	ability: AbilityData,
	stand: Vector2i,
	cell: Vector2i,
) -> void:
	var range_tiles: Array[Vector2i] = expected_red_tiles(
		fix.board, fix.knight, ability, stand,
	)
	assert_true(
		failures, label,
		not range_tiles.has(cell),
		"cell %s must not be in red range from stand %s" % [cell, stand],
	)


static func assert_red_includes_cell(
	failures: Array[String],
	label: String,
	fix: Dictionary,
	ability: AbilityData,
	stand: Vector2i,
	cell: Vector2i,
) -> void:
	var range_tiles: Array[Vector2i] = expected_red_tiles(
		fix.board, fix.knight, ability, stand,
	)
	assert_true(
		failures, label,
		range_tiles.has(cell),
		"cell %s must be in red range from stand %s" % [cell, stand],
	)


static func assert_cursor_contains(
	failures: Array[String], label: String, fix: Dictionary, slots: Dictionary, glyph: String,
) -> void:
	var icon: String = fix.input._cursor_icon_from_commit_slots(slots, fix.knight)
	assert_true(
		failures, label,
		icon.find(glyph) >= 0,
		"cursor must contain %s, got %s" % [glyph, icon],
	)


static func assert_cursor_is(
	failures: Array[String], label: String, fix: Dictionary, slots: Dictionary, glyph: String,
) -> void:
	var icon: String = fix.input._cursor_icon_from_commit_slots(slots, fix.knight)
	if icon != glyph:
		assert_fail(failures, label, "cursor expected %s got %s" % [glyph, icon])


static func assert_slots_match_preview_commit(
	failures: Array[String], label: String, fix: Dictionary, cell: Vector2i,
) -> void:
	var hover_slots: Dictionary = slots_for_hover(fix, cell)
	var click_slots: Dictionary = slots_for_click(fix, cell)
	assert_true(
		failures, label,
		PlanningQAGateTest._intent_slot_signature(hover_slots)
		== PlanningQAGateTest._intent_slot_signature(click_slots),
		"hover slots must match click slots at %s" % cell,
	)


static func assert_commit_no_jump(
	failures: Array[String], label: String, fix: Dictionary, cell: Vector2i,
) -> void:
	var before_sig: String = PlanningQAGateTest._intent_slot_signature(slots_for_hover(fix, cell))
	var before_push: Vector2i = push_destination(fix, 2)
	var before_ghost: Vector2i = preview_unit_pos(fix, 1)
	var slots: Dictionary = commit_production(fix, cell)
	assert_true(failures, label, not _slots_invalid(slots), "commit must succeed")
	assert_true(
		failures, label,
		PlanningQAGateTest._intent_slot_signature(slots) == before_sig,
		"committed slots must match pre-commit preview signature",
	)
	hover(fix, cell)
	assert_eq_cell(failures, label, preview_unit_pos(fix, 1), before_ghost)


static func assert_sim_matches_preview(
	failures: Array[String], label: String, fix: Dictionary,
) -> void:
	var preview_board: BoardState = fix.input.preview_state.preview_board
	if preview_board == null:
		assert_fail(failures, label, "preview board missing before sim")
		return
	var result: SimResult = simulate_committed(fix.director)
	for unit: UnitState in preview_board.units:
		var final_u: UnitState = result.final_state.get_unit_by_id(unit.id)
		if final_u == null:
			assert_fail(failures, label, "unit %d missing after sim" % unit.id)
			continue
		if final_u.position != unit.position:
			assert_fail(
				failures, label,
				"unit %d sim pos %s != preview %s"
				% [unit.id, final_u.position, unit.position],
			)


static func assert_ability_kind_class(
	failures: Array[String], label: String, ability: AbilityData,
) -> void:
	assert_true(
		failures, label,
		ability != null and ability.kind == GameEnums.AbilityKind.CLASS_SKILL,
		"ability must be CLASS_SKILL (got kind %d)" % (ability.kind if ability else -1),
	)


static func clear_drag_state(fix: Dictionary) -> void:
	var input: CombatPlanningInput = fix.input
	input.dragging = false
	input._drag_route.clear()
	input._drag_unit_id = -1
	input._drag_last_free = Vector2i(-999999, -999999)
	input._drag_unit_was_selected = false


static func drop_slots_for_cell(fix: Dictionary, cell: Vector2i) -> Dictionary:
	var input: CombatPlanningInput = fix.input
	var legal_moves: Array[Vector2i] = []
	if input._drag_route_commits_active():
		legal_moves = input._snapshot_drag_legal_move_tiles()
	return input._final_commit_slots_for_drop_at_cell(
		fix.director.selected_unit_id, cell, Vector2.ZERO, legal_moves,
	)


static func hover_route(fix: Dictionary, route: Array[Vector2i]) -> void:
	for cell: Vector2i in route:
		hover(fix, cell)


static func commit_painted_drop_on_cell(
	fix: Dictionary,
	route: Array[Vector2i],
	drop_cell: Vector2i,
) -> bool:
	clear_drag_state(fix)
	var input: CombatPlanningInput = fix.input
	var dest: Vector2i = route[route.size() - 1]
	var unit: UnitState = fix.board.get_unit_by_id(fix.director.selected_unit_id)
	TramplingAdvanceE2ETest._paint_drag_route(input, unit, route, dest)
	hover(fix, drop_cell)
	var slots: Dictionary = drop_slots_for_cell(fix, drop_cell)
	if _slots_invalid(slots):
		clear_drag_state(fix)
		return false
	var ok: bool = commit_slots_production(fix, slots)
	clear_drag_state(fix)
	return ok


static func committed_pre_move(director: CombatDirector, unit_id: int) -> TimelineAction:
	return _timeline_action_for_unit(director, unit_id, director.plan_pre_move.entries)


static func committed_action(director: CombatDirector, unit_id: int) -> TimelineAction:
	return _timeline_action_for_unit(director, unit_id, director.plan_action.entries)


static func committed_post_move(director: CombatDirector, unit_id: int) -> TimelineAction:
	return _timeline_action_for_unit(director, unit_id, director.plan_post_move.entries)


static func _timeline_action_for_unit(
	director: CombatDirector,
	unit_id: int,
	entries: Array,
) -> TimelineAction:
	for raw: Variant in entries:
		var action: TimelineAction = raw as TimelineAction
		if action != null and action.actor_id == unit_id:
			return action
	return null


static func action_surface(action: TimelineAction) -> Dictionary:
	if action == null:
		return {}
	return {
		"type": action.type,
		"target": action.target_coord,
		"waypoints": action.waypoints.duplicate(),
		"uses_run": action.uses_run,
		"ability": action.ability.id if action.ability != null else &"",
	}


static func mode_commit_surface(fix: Dictionary, unit_id: int = 1) -> Dictionary:
	var projected: UnitState = projected_unit(fix, unit_id)
	var director: CombatDirector = fix.director
	return {
		"projected_unit": {
			"position": projected.position,
			"ap": projected.ability.points_left,
			"mp": projected.movement.points_left,
		},
		"pre_move": action_surface(committed_pre_move(director, unit_id)),
		"action": action_surface(committed_action(director, unit_id)),
		"post_move": action_surface(committed_post_move(director, unit_id)),
	}


static func assert_mode_commit_parity(
	failures: Array[String],
	selection_key: String,
	selection_surface: Dictionary,
	drag_key: String,
	drag_surface: Dictionary,
) -> void:
	if selection_surface != drag_surface:
		assert_fail(
			failures,
			"t3_mimic/%s_vs_%s" % [selection_key, drag_key],
			"preview/commit parity diverged: %s != %s (sel=%s drag=%s)"
			% [selection_key, drag_key, str(selection_surface), str(drag_surface)],
		)


static func slots_invalid(slots: Dictionary) -> bool:
	return _slots_invalid(slots)


static func _slots_invalid(slots: Dictionary) -> bool:
	var flag: Variant = slots.get("invalid", false)
	if flag is bool:
		return flag
	if flag is String:
		return not (flag as String).is_empty()
	return bool(flag)


static func _commit_unit_id(fix: Dictionary) -> int:
	return fix.director.selected_unit_id


static func _training_knight(id: int, pos: Vector2i) -> UnitState:
	var knight_def: UnitData = DataLibrary.get_unit(&"knight")
	var knight: UnitState = UnitState.create(id, knight_def, GameEnums.Team.PLAYER, pos)
	knight.active_abilities = DataLibrary.build_training_abilities(knight_def)
	knight.movement.points_left = knight.movement.max_points
	knight.ability.points_left = 1
	knight.ability.max_points = 1
	return knight


static func wire_bible_board() -> Dictionary:
	PlanningDragE2EHarness.cleanup_all()
	var dummy_def: UnitData = DataLibrary.get_training_dummy()
	assert(dummy_def != null, "wire_bible_board: training dummy missing")
	var units: Array[UnitState] = [
		_training_knight(1, KNIGHT_START),
		_training_knight(2, K2_CELL),
		_training_knight(3, K3_CELL),
		_training_knight(4, K4_CELL),
		UnitState.create(5, dummy_def, GameEnums.Team.ENEMY, E_BASH_CELL),
		UnitState.create(6, dummy_def, GameEnums.Team.ENEMY, E_HOOK_CELL),
	]
	var fix: Dictionary = _wire_multi_fixture(units, 1)
	fix["k1_id"] = 1
	fix["k2_id"] = 2
	fix["k3_id"] = 3
	fix["k4_id"] = 4
	fix["e_bash_id"] = 5
	fix["e_hook_id"] = 6
	return fix


static func wire_swap_board(ally_cell: Vector2i) -> Dictionary:
	PlanningDragE2EHarness.cleanup_all()
	var units: Array[UnitState] = [
		_training_knight(1, KNIGHT_START),
		_training_knight(2, ally_cell),
	]
	var fix: Dictionary = _wire_multi_fixture(units, 1)
	fix["k1_id"] = 1
	fix["ally_id"] = 2
	fix["ally_cell"] = ally_cell
	var k1: UnitState = fix.board.get_unit_by_id(1)
	fix["start_k1_mp"] = k1.movement.points_left if k1 != null else 0
	return fix


static func _wire_multi_fixture(units: Array[UnitState], selected_id: int) -> Dictionary:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	director.plan_pre_move = Timeline.new()
	director.plan_action = Timeline.new()
	director.plan_post_move = Timeline.new()
	var board: BoardState = PlanningDragE2EHarness._plain_board(Vector2i(12, 12), units)
	director.board = board
	director.base_board = board.clone()
	director.projected_state = board.clone()
	director.turn_start_board = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = selected_id
	input._director = director
	input.auto_use_skill_after_move = true
	var core: Dictionary = {
		"input": input,
		"director": director,
		"board": board,
		"knight": board.get_unit_by_id(selected_id),
	}
	return PlanningDragE2EHarness.wire_fixture(core)


static func select_unit(fix: Dictionary, unit_id: int, stand_cell: Vector2i = Vector2i(-999999, -999999)) -> void:
	var director: CombatDirector = fix.director
	director.select_unit(unit_id)
	fix["knight"] = fix.board.get_unit_by_id(unit_id)
	if stand_cell.x > -900000:
		hover(fix, stand_cell)
	flush_planning(fix)


static func select_ability_for_unit(
	fix: Dictionary, unit_id: int, ability_id: StringName,
) -> int:
	select_unit(fix, unit_id)
	return select_ability(fix, ability_id)


static func set_unit_pools(fix: Dictionary, unit_id: int, ap_left: int, mp_left: int) -> void:
	var director: CombatDirector = fix.director
	var boards: Array[BoardState] = [
		director.base_board,
		director.board,
		director.projected_state,
	]
	for board: BoardState in boards:
		if board == null:
			continue
		var unit: UnitState = board.get_unit_by_id(unit_id)
		if unit == null:
			continue
		unit.ability.points_left = ap_left
		unit.ability.max_points = maxi(ap_left, unit.ability.max_points)
		unit.movement.points_left = mp_left
		unit.movement.max_points = maxi(mp_left, unit.movement.max_points)


static func enter_basic_movement(fix: Dictionary) -> void:
	fix.director.selected_ability_index = -1
	fix.input.force_basic_movement = true
	fix.input.auto_use_skill_after_move = false
	flush_planning(fix)


static func arm_trample_awaiting(fix: Dictionary, unit_id: int) -> bool:
	var unit: UnitState = fix.board.get_unit_by_id(unit_id)
	if unit == null:
		return false
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var empty_wps: Array[Vector2i] = []
	var empty_legal: Array[Vector2i] = []
	var arm_slots: Dictionary = input._final_commit_slots_for_interaction(
		unit_id,
		unit.position,
		empty_wps,
		empty_legal,
		Vector2i(-999999, -999999),
	)
	if _slots_invalid(arm_slots):
		return false
	input.call("_paint_intent_slots_before_commit", unit_id, arm_slots)
	if not director.commit_from_slots(unit_id, arm_slots):
		return false
	input.call("_promote_intent_preview_after_commit")
	flush_planning(fix)
	return input.awaiting_targeting_active()


static func pre_moves_for_unit(director: CombatDirector, unit_id: int) -> Array[TimelineAction]:
	var out: Array[TimelineAction] = []
	for raw: Variant in director.plan_pre_move.entries:
		var action: TimelineAction = raw as TimelineAction
		if action != null and action.actor_id == unit_id:
			out.append(action)
	return out


static func assert_enemy_live_unchanged(
	failures: Array[String],
	label: String,
	fix: Dictionary,
	enemy_id: int,
	turn_start_cell: Vector2i,
) -> void:
	var live: UnitState = fix.director.board.get_unit_by_id(enemy_id)
	if live == null:
		assert_fail(failures, label, "live enemy %d missing" % enemy_id)
		return
	assert_eq_cell(failures, label, live.position, turn_start_cell)


static func assert_swap_board_layers(
	failures: Array[String],
	label: String,
	fix: Dictionary,
	k1_id: int,
	ally_id: int,
	k1_pos: Vector2i,
	ally_pos: Vector2i,
	expected_mp: int = -1,
	expected_pre_count: int = -1,
) -> void:
	var director: CombatDirector = fix.director
	var board_k1: UnitState = director.board.get_unit_by_id(k1_id)
	var board_ally: UnitState = director.board.get_unit_by_id(ally_id)
	if board_k1 == null or board_ally == null:
		assert_fail(failures, label, "live board units missing")
		return
	assert_eq_cell(failures, "%s/k1_board" % label, board_k1.position, k1_pos)
	assert_eq_cell(failures, "%s/ally_board" % label, board_ally.position, ally_pos)
	var proj_k1: UnitState = projected_unit(fix, k1_id)
	var proj_ally: UnitState = projected_unit(fix, ally_id)
	assert_eq_cell(failures, "%s/k1_proj" % label, proj_k1.position, k1_pos)
	assert_eq_cell(failures, "%s/ally_proj" % label, proj_ally.position, ally_pos)
	if expected_mp >= 0:
		assert_eq_int(failures, "%s/k1_mp" % label, proj_k1.movement.points_left, expected_mp)
	if expected_pre_count >= 0:
		assert_eq_int(
			failures,
			"%s/pre_count" % label,
			pre_moves_for_unit(director, k1_id).size(),
			expected_pre_count,
		)
