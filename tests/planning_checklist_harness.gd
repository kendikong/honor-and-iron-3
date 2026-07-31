class_name PlanningChecklistHarness
extends RefCounted

## Shared harness for 7-phase planning skill checklist scenarios.
## Asserts production layers: blue/red overlay, live preview, slots, cursor, economy, sim.
## Commit path: paint → commit_from_slots → promote → deferred flush (F5 parity).

const KNIGHT_START := Vector2i(4, 5)
const ENEMY_POS := Vector2i(7, 5)
const BASH_APPROACH := Vector2i(6, 5)
const HOOK_KNIGHT_START := Vector2i(1, 3)
const HOOK_ENEMY_POS := Vector2i(4, 3)
const TRAMPLE_START := Vector2i(5, 4)
const TRAMPLE_END := Vector2i(6, 3)
const TRAMPLE_ROUTE: Array[Vector2i] = [Vector2i(6, 4), Vector2i(6, 3)]

const SHIELD_BASH_ID: StringName = &"knight_shield_bash"
const CHAIN_HOOK_ID: StringName = &"knight_chain_hook"
const TRAMPLE_ID: StringName = &"knight_trampling_advance"
const BOWLING_CHARGE_ID: StringName = &"knight_bowling_charge"


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
	var fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(TRAMPLE_START)
	fix["knight"] = fix.unit
	return PlanningDragE2EHarness.wire_fixture(fix)


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
		1, cell, empty_wps, empty_legal, Vector2i(-999999, -999999),
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
	fix.input.call("_paint_intent_slots_before_commit", 1, slots)
	if not fix.director.commit_from_slots(1, slots):
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
	input.call("_paint_intent_slots_before_commit", 1, slots)
	if not director.commit_from_slots(1, slots):
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
	input.call("_paint_intent_slots_before_commit", 1, slots)
	if not director.commit_from_slots(1, slots):
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
			var slots: Dictionary = slots_for_hover(fix, dest)
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
	fix.knight.ability.points_left = ap_left
	fix.knight.ability.max_points = maxi(ap_left, fix.knight.ability.max_points)
	fix.knight.movement.points_left = mp_left
	var proj: UnitState = projected_unit(fix, 1)
	if proj != null and proj.id == fix.knight.id:
		proj.ability.points_left = ap_left
		proj.movement.points_left = mp_left


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
) -> void:
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	var visible: bool = input.action_range_visible_for_hover()
	var stand: Vector2i = input.action_range_intent_stand_cell(1)
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
	if expect_show and ability != null:
		var range_tiles: Array[Vector2i] = expected_red_tiles(
			fix.board, fix.knight, ability, stand,
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


static func _slots_invalid(slots: Dictionary) -> bool:
	var flag: Variant = slots.get("invalid", false)
	if flag is bool:
		return flag
	if flag is String:
		return not (flag as String).is_empty()
	return bool(flag)
