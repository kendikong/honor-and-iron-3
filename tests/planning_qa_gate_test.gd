class_name PlanningQAGateTest
extends RefCounted

## Automated mirror of the owner's manual planning QA checklist (Skill Arena / TestBattle).
## Asserts production planning, preview, commit-slot, cursor, and sim APIs — not pixel draw.

const KNIGHT_START := Vector2i(4, 5)
const ENEMY_POS := Vector2i(7, 5)
const BASH_APPROACH := Vector2i(6, 5)
const SHIELD_BASH_ID: StringName = &"knight_shield_bash"
const CHAIN_HOOK_ID: StringName = &"knight_chain_hook"
const TRAMPLE_ID: StringName = &"knight_trampling_advance"
const BOWLING_CHARGE_ID: StringName = &"knight_bowling_charge"


static func run_all(failures: Array[String]) -> void:
	var tests: Array[Callable] = [
		_test_waypoint_paint_order_preserved_on_tile_drag,
		_test_jump_drag_autocorrect_preserves_painted_corridor,
		_test_stale_hover_updates_commit_waypoints,
		_test_cursor_walk_run_and_composite,
		_test_blue_move_tiles_on_walk_select,
		_test_planning_display_mp_left_contract,
		_test_committed_walk_preview_matches_sim_path,
		_test_shield_bash_enemy_hover_commit_slots,
		_test_shield_bash_push_away_from_player,
		_test_shield_bash_enemy_lands_at_push_destination,
		_test_shield_bash_enemy_hover_composite_cursor,
		_test_shield_bash_hover_change_clears_stale_approach,
		_test_chain_hook_awaiting_targeting_segment,
		_test_chain_hook_pull_toward_player,
		_test_trampling_premove_then_arm_commit_flow,
		_test_trampling_unarmed_empty_hover_is_premove,
		# Integrity extensions (headless-only; beyond manual checklist)
		_test_hover_slots_are_deterministic,
		_test_commit_plan_matches_hover_slots,
		_test_undo_action_keeps_premove,
		_test_shield_bash_full_approach_push_preview,
		_test_committed_hook_approach_uses_premove,
		_test_out_of_range_hover_is_invalid,
		_test_trample_paint_preview_matches_route,
		_test_trample_commit_preserves_east_then_north,
		_test_trample_sim_follows_painted_order,
		# Intent-truth pipeline (preview = slots = commit = sim)
		_test_bash_slots_preview_board_parity,
		_test_hover_click_drop_slot_parity,
		_test_click_drop_parity_bash_enemy,
		_test_click_drop_parity_walk_adjacent,
		_test_click_drop_parity_bash_approach,
		_test_click_drop_parity_hook_enemy,
		_test_click_drop_parity_oob_invalid,
		_test_click_drop_cursor_parity_bash,
		_test_click_drop_cursor_parity_walk,
		_test_click_drop_commit_sim_bash,
		_test_click_drop_commit_sim_walk,
		_test_click_drop_drag_walk_sim_parity,
		_test_click_drop_drag_bash_enemy_parity,
		_test_drag_drop_commit_undo_clears_plan,
		_test_cursor_equals_slots_on_hover,
		_test_bash_commit_sim_push,
		_test_hook_commit_sim_pull,
		_test_invalid_slots_block_commit,
		_test_full_slot_signature_on_commit,
		_test_ability_switch_clears_preview_cache,
		_test_ability_select_refreshes_enemy_hover_path,
		_test_trample_paint_commit_sim_chain,
		_test_bash_sim_determinism,
		_test_hover_order_invariant,
		_test_drag_cleared_restores_canonical_bash_intent,
		_test_approach_bash_slots_preview_keeps_push,
		_test_timeline_ghost_clears_when_committed,
		_test_action_range_centered_on_live_stand,
		_test_action_range_hides_when_auto_run_blocks_skill_ap,
		_test_action_range_hides_after_commit_run_icon,
		_test_action_range_shows_while_awaiting_trample,
		_test_action_range_shows_on_enemy_hover,
		_test_action_range_follows_cursor_on_move_hover,
		_test_enemy_skill_hover_not_movement_route,
		_test_enemy_bash_approach_move_leg,
		_test_bash_targeting_uses_pre_push_enemy_cell,
		_test_hook_pull_preview_keeps_attack_target,
		_test_class_skill_execute_spends_ap,
		_test_class_skill_player_turn_spends_ap,
		_test_bash_promote_locks_committed_ghost,
		_test_hook_in_range_approach_tile_is_actor_position,
	]
	var names: PackedStringArray = [
		"waypoint_paint",
		"jump_autocorrect",
		"stale_hover",
		"cursor-glyphs",
		"blue_move_tiles",
		"mp_display_contract",
		"walk_sim",
		"bash_slots",
		"bash_push",
		"bash_threat",
		"bash_cursor",
		"bash_stale",
		"hook_segment",
		"hook_pull",
		"trample_flow",
		"trample_unarmed_hover",
		"hover_deterministic",
		"commit_matches_hover",
		"undo_keeps_premove",
		"bash_full_approach_push",
		"hook_committed_premove",
		"out_of_range_invalid",
		"trample_paint_preview",
		"trample_commit_wps",
		"trample_sim_order",
		"bash_preview_board_parity",
		"hover_click_drop_parity",
		"click_drop_bash",
		"click_drop_walk",
		"click_drop_approach",
		"click_drop_hook",
		"click_drop_oob",
		"click_drop_cursor_bash",
		"click_drop_cursor_walk",
		"click_drop_sim_bash",
		"click_drop_sim_walk",
		"click_drop_drag_walk_sim",
		"click_drop_drag_bash",
		"drag_drop_undo",
		"cursor_equals_slots",
		"bash_commit_sim",
		"hook_commit_sim",
		"invalid_blocks_commit",
		"full_slot_signature",
		"ability_cache_clear",
		"ability_scroll_hover_path",
		"trample_full_chain",
		"bash_sim_determinism",
		"hover_order_invariant",
		"drag_cleared_intent",
		"approach_bash_push_preview",
		"timeline_ghost_commit",
		"action_range_live_stand",
		"action_range_auto_run_ap_gate",
		"action_range_commit_run_icon_hide",
		"action_range_awaiting_trample",
		"action_range_enemy_hover",
		"action_range_move_hover_follows_cursor",
		"enemy_hover_not_move_route",
		"bash_enemy_approach_leg",
		"bash_target_pre_push_cell",
		"hook_pull_attack_target",
		"class_skill_execute_ap",
		"class_skill_player_turn_ap",
		"bash_promote_ghost",
		"hook_in_range_approach",
	]
	for i: int in range(tests.size()):
		print("[RUN] %s" % names[i])
		tests[i].call(failures)
		PlanningDragE2EHarness.cleanup_all()


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
		assert(dummy_def != null, "PlanningQAGate: training dummy definition missing")
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
	var fix: Dictionary = {
		"input": input,
		"director": director,
		"board": board,
		"knight": knight,
		"enemy": units[1] if units.size() > 1 else null,
	}
	PlanningDragE2EHarness.track_raw_fixture(fix)
	return fix


static func _commit_slots_at(
	input: CombatPlanningInput,
	unit_id: int,
	cell: Vector2i,
	waypoints: Array[Vector2i] = [],
) -> Dictionary:
	var empty_legal: Array[Vector2i] = []
	return input._final_commit_slots_for_interaction(
		unit_id, cell, waypoints, empty_legal, Vector2i(-999999, -999999),
	)


static func _clear_drag_state(input: CombatPlanningInput) -> void:
	input.dragging = false
	input._drag_route.clear()
	input._drag_unit_id = -1
	input._drag_last_free = Vector2i(-999999, -999999)
	input._drag_unit_was_selected = false


static func _click_slots_at(
	input: CombatPlanningInput,
	unit_id: int,
	cell: Vector2i,
) -> Dictionary:
	return input._final_commit_slots_for_click_at_cell(unit_id, cell, Vector2.ZERO)


static func _drop_slots_at(
	input: CombatPlanningInput,
	unit_id: int,
	cell: Vector2i,
) -> Dictionary:
	var legal_moves: Array[Vector2i] = []
	if input._drag_route_commits_active():
		legal_moves = input._snapshot_drag_legal_move_tiles()
	return input._final_commit_slots_for_drop_at_cell(
		unit_id, cell, Vector2.ZERO, legal_moves,
	)


static func _assert_click_drop_signature_parity(
	failures: Array[String],
	label: String,
	input: CombatPlanningInput,
	unit_id: int,
	cell: Vector2i,
) -> void:
	var click_slots: Dictionary = _click_slots_at(input, unit_id, cell)
	var drop_slots: Dictionary = _drop_slots_at(input, unit_id, cell)
	if _intent_slot_signature(click_slots) != _intent_slot_signature(drop_slots):
		failures.append(
			"PlanningQAGate click/drop parity %s: selection vs drop slots differ %s vs %s"
			% [label, _intent_slot_signature(click_slots), _intent_slot_signature(drop_slots)],
		)


static func _sim_unit_position_after_slots_commit(
	director: CombatDirector,
	unit_id: int,
	slots: Dictionary,
) -> Vector2i:
	if _slots_invalid(slots):
		return Vector2i(-999999, -999999)
	if not director.commit_from_slots(unit_id, slots):
		return Vector2i(-999998, -999998)
	director.flush_plan_refresh_signals_if_pending()
	var result: SimResult = _simulate_committed_plan(director)
	var unit: UnitState = result.final_state.get_unit_by_id(unit_id)
	if unit == null:
		return Vector2i(-999997, -999997)
	return unit.position


static func _sim_enemy_position_after_slots_commit(
	director: CombatDirector,
	actor_id: int,
	enemy_id: int,
	slots: Dictionary,
) -> Vector2i:
	if _slots_invalid(slots):
		return Vector2i(-999999, -999999)
	if not director.commit_from_slots(actor_id, slots):
		return Vector2i(-999998, -999998)
	director.flush_plan_refresh_signals_if_pending()
	var result: SimResult = _simulate_committed_plan(director)
	var enemy: UnitState = result.final_state.get_unit_by_id(enemy_id)
	if enemy == null:
		return Vector2i(-999997, -999997)
	return enemy.position


static func _actions_from_slots(slots: Dictionary) -> Array[TimelineAction]:
	var actions: Array[TimelineAction] = []
	for col: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(col, []):
			if raw is TimelineAction:
				actions.append(raw as TimelineAction)
	return actions


static func _arm_awaiting_at(
	input: CombatPlanningInput,
	director: CombatDirector,
	stand_cell: Vector2i,
) -> bool:
	var arm_slots: Dictionary = _commit_slots_at(input, 1, stand_cell)
	if bool(arm_slots.get("invalid", true)):
		return false
	if not director.commit_from_slots(1, arm_slots):
		return false
	director.flush_plan_refresh_signals_if_pending()
	return input.awaiting_targeting_active()


static func _slots_invalid(slots: Dictionary) -> bool:
	var flag: Variant = slots.get("invalid", false)
	if flag is bool:
		return flag
	if flag is String:
		return not (flag as String).is_empty()
	return bool(flag)


static func _hook_committed_approach_fixture() -> Dictionary:
	## Mirrors planning_input_test committed-action approach fixture (hook-only knight).
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	director.plan_pre_move = Timeline.new()
	director.plan_action = Timeline.new()
	director.plan_post_move = Timeline.new()
	var hook: AbilityData = _knight_ability(CHAIN_HOOK_ID)
	if hook == null:
		return {"input": null, "director": null, "knight": null, "enemy": null, "hook": null}
	var knight_def: UnitData = DataLibrary.get_unit(&"knight")
	var knight: UnitState = UnitState.create(1, knight_def, GameEnums.Team.PLAYER, Vector2i(0, 3))
	knight.active_abilities = [hook]
	knight.movement.points_left = 4
	knight.movement.max_points = 4
	knight.ability.points_left = 1
	knight.ability.max_points = 1
	var dummy_def: UnitData = DataLibrary.get_training_dummy()
	var enemy: UnitState = UnitState.create(2, dummy_def, GameEnums.Team.ENEMY, Vector2i(4, 3))
	var units: Array[UnitState] = [knight, enemy]
	var board := _plain_board(Vector2i(10, 6), units)
	director.board = board
	director.base_board = board.clone()
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = 1
	director.selected_ability_index = 0
	director.plan_action.entries.append(
		TimelineAction.make_ability(
			1, hook, enemy.position, enemy.id, GameEnums.MoveTiming.PRE_ACTION, [],
		),
	)
	director.plan_affected_unit_ids = [1]
	director._refresh_plan()
	input._director = director
	input.auto_use_skill_after_move = true
	return {"input": input, "director": director, "knight": knight, "enemy": enemy, "hook": hook}


static func _ability_index(unit: UnitState, ability_id: StringName) -> int:
	for i: int in range(unit.active_abilities.size()):
		var ability: AbilityData = unit.active_abilities[i]
		if ability != null and ability.id == ability_id:
			return i
	return -1


static func _knight_ability(ability_id: StringName) -> AbilityData:
	var def: UnitData = DataLibrary.get_unit(&"knight")
	if def == null:
		return null
	for ability: AbilityData in def.abilities:
		if ability != null and ability.id == ability_id:
			return ability
	return null


static func _preview_for_actions(
	director: CombatDirector,
	actions: Array[TimelineAction],
) -> CombatPlanningPreview:
	var preview := CombatPlanningPreview.new()
	var res: Dictionary = director.preview_actions(1, actions)
	preview.apply_result(res, director)
	return preview


static func _push_segment(pushes: Array) -> Array:
	if pushes.is_empty():
		return []
	var seg: Variant = pushes[pushes.size() - 1]
	return seg as Array if seg is Array else []


static func _pre_target(slots: Dictionary) -> Vector2i:
	var pre: Array = slots.get("pre", []) as Array
	if pre.is_empty():
		return Vector2i(-999, -999)
	var step: TimelineAction = pre[0] as TimelineAction
	return step.target_coord if step != null else Vector2i(-999, -999)


static func _action_target_unit(slots: Dictionary) -> int:
	var action_steps: Array = slots.get("action", []) as Array
	if action_steps.is_empty():
		return -1
	var step: TimelineAction = action_steps[0] as TimelineAction
	return step.target_unit_id if step != null else -1


static func _slot_signature(slots: Dictionary) -> String:
	return "%s|%s|%s" % [
		str(_pre_target(slots)),
		str(_action_target_unit(slots)),
		str(bool(slots.get("invalid", true))),
	]


static func _intent_slot_signature(slots: Dictionary) -> String:
	var pre_wps: String = "[]"
	var pre: Array = slots.get("pre", []) as Array
	if not pre.is_empty() and pre[0] is TimelineAction:
		pre_wps = str((pre[0] as TimelineAction).waypoints)
	var action_ability: String = ""
	var action_steps: Array = slots.get("action", []) as Array
	if not action_steps.is_empty() and action_steps[0] is TimelineAction:
		var act: TimelineAction = action_steps[0] as TimelineAction
		action_ability = str(act.ability.id) if act.ability != null else ""
	var post_count: int = (slots.get("post", []) as Array).size()
	return "%s|%s|%s|%s|%d|%s" % [
		str(_pre_target(slots)),
		pre_wps,
		str(_action_target_unit(slots)),
		action_ability,
		post_count,
		str(_slots_invalid(slots)),
	]


static func _preview_dict_from_cell(
	input: CombatPlanningInput,
	unit_id: int,
	cell: Vector2i,
) -> Dictionary:
	return input._preview_from_commit_slots_at_cell(
		unit_id, cell, [] as Array[Vector2i], [] as Array[Vector2i], Vector2i(-999999, -999999),
	)


static func _preview_from_dict(
	director: CombatDirector,
	preview_dict: Dictionary,
) -> CombatPlanningPreview:
	var preview := CombatPlanningPreview.new()
	preview.apply_result(preview_dict, director)
	return preview


static func _enemy_push_destination(preview: CombatPlanningPreview, enemy_id: int) -> Vector2i:
	var pushes: Array = preview.preview_pushes.get(enemy_id, [])
	var seg: Array = _push_segment(pushes)
	if seg.size() < 2:
		return Vector2i(-999999, -999999)
	return seg[1] as Vector2i


static func _simulate_committed_plan(director: CombatDirector) -> SimResult:
	var start_board: BoardState = director.base_board.clone()
	start_board.intents = []
	return Simulator.simulate(start_board, director.get_player_plan())


static func _bash_img1_ready(fix: Dictionary) -> int:
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		return -1
	fix.director.selected_ability_index = bash_idx
	return bash_idx


static func _wire_overlay(fix: Dictionary) -> TacticalPlanningOverlay:
	var intent := CombatIntentState.new()
	var overlay := TacticalPlanningOverlay.new()
	overlay.setup(null, fix.director, intent)
	overlay.set_board(fix.board)
	fix.input._planning = overlay
	fix.input._intent_state = intent
	overlay.bind_planning_input(fix.input)
	PlanningDragE2EHarness.track_overlay_fixture(fix, overlay)
	return overlay


static func _wire_click_drop_context(fix: Dictionary) -> void:
	_wire_overlay(fix)


static func _test_waypoint_paint_order_preserved_on_tile_drag(failures: Array[String]) -> void:
	var fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(TramplingAdvanceE2ETest.START_CELL)
	var input: CombatPlanningInput = fix.input
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("PlanningQAGate movement 1A: knight missing Trampling Advance")
		return
	TramplingAdvanceE2ETest._arm_trample_awaiting(input, fix.director, unit)
	input._drag_unit_id = unit.id
	input._drag_route = [TramplingAdvanceE2ETest.START_CELL]
	input._extend_drag_route(TramplingAdvanceE2ETest.EAST_THEN_NORTH[0])
	input._extend_drag_route(TramplingAdvanceE2ETest.EAST_THEN_NORTH[1])
	var painted: Array[Vector2i] = [
		TramplingAdvanceE2ETest.START_CELL,
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[0],
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[1],
	]
	if input._drag_route != painted:
		failures.append(
			"PlanningQAGate movement 1A: tile drag must preserve paint order %s, got %s"
			% [str(painted), str(input._drag_route)],
		)


static func _test_jump_drag_autocorrect_preserves_painted_corridor(failures: Array[String]) -> void:
	var fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(TramplingAdvanceE2ETest.START_CELL)
	var input: CombatPlanningInput = fix.input
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("PlanningQAGate movement 1A autocorrect: missing Trampling Advance")
		return
	TramplingAdvanceE2ETest._arm_trample_awaiting(input, fix.director, unit)
	input._drag_unit_id = unit.id
	input._drag_route = [TramplingAdvanceE2ETest.START_CELL]
	input._extend_drag_route(TramplingAdvanceE2ETest.EAST_THEN_NORTH[0])
	input._extend_drag_route(TramplingAdvanceE2ETest.END_CELL)
	var painted: Array[Vector2i] = [
		TramplingAdvanceE2ETest.START_CELL,
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[0],
		TramplingAdvanceE2ETest.END_CELL,
	]
	if input._drag_route != painted:
		failures.append(
			"PlanningQAGate movement 1A autocorrect: jump drag must keep E-then-N corridor %s, got %s"
			% [str(painted), str(input._drag_route)],
		)


static func _test_stale_hover_updates_commit_waypoints(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate movement stale: knight missing Shield Bash")
		return
	director.selected_ability_index = bash_idx
	var enemy_slots: Dictionary = input._final_commit_slots_for_interaction(
		1, ENEMY_POS, [], [], Vector2i(-999999, -999999),
	)
	var approach_slots: Dictionary = input._final_commit_slots_for_interaction(
		1, BASH_APPROACH, [], [], Vector2i(-999999, -999999),
	)
	var enemy_pre: Array = enemy_slots.get("pre", []) as Array
	var approach_pre: Array = approach_slots.get("pre", []) as Array
	if enemy_pre.is_empty():
		failures.append("PlanningQAGate movement stale: enemy hover must build pre-move")
		return
	var enemy_move: TimelineAction = enemy_pre[0] as TimelineAction
	var approach_move: TimelineAction = approach_pre[0] as TimelineAction
	if approach_move == null or approach_move.target_coord != BASH_APPROACH:
		failures.append(
			"PlanningQAGate movement stale: approach hover must target %s, got %s"
			% [str(BASH_APPROACH), str(approach_move.target_coord if approach_move != null else null)],
		)
	if enemy_move == null or enemy_move.target_coord != BASH_APPROACH:
		failures.append(
			"PlanningQAGate movement stale: enemy hover pre-move must target %s, got %s"
			% [str(BASH_APPROACH), str(enemy_move.target_coord if enemy_move != null else null)],
		)


static func _test_planning_display_mp_left_contract(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, Vector2i(-1, -1))
	fix.knight.movement.points_left = 2
	fix.knight.movement.max_points = 3
	var proj: UnitState = fix.director.projected_state.get_unit_by_id(1)
	if proj != null:
		proj.movement.points_left = 2
		proj.movement.max_points = 3
	var display_mp: int = fix.input.planning_display_mp_left(1)
	if display_mp != 2:
		failures.append(
			"PlanningQAGate MP display: committed budget must match points_left (got %d)" % display_mp,
		)


static func _test_blue_move_tiles_on_walk_select(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, Vector2i(-1, -1))
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	fix["overlay"] = overlay
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	director.selected_ability_index = -1
	input.force_basic_movement = true
	PlanningChecklistHarness.hover(fix, KNIGHT_START)
	var blue: Array[Vector2i] = PlanningChecklistHarness.collect_blue_tiles(fix)
	if blue.is_empty():
		failures.append("PlanningQAGate blue tiles: walk select must show reachable move tiles")
		return
	var dest := Vector2i(5, 5)
	if not blue.has(dest):
		failures.append(
			"PlanningQAGate blue tiles: walk dest (5,5) must be reachable, got %s" % str(blue),
		)


static func _test_cursor_walk_run_and_composite(failures: Array[String]) -> void:
	var input := CombatPlanningInput.new()
	input.auto_use_skill_after_move = true
	var unit := UnitState.new()
	unit.id = 1
	var walk_slots: Dictionary = {
		"pre": [TimelineAction.make_move(1, Vector2i(2, 2))],
		"action": [],
		"post": [],
		"invalid": false,
	}
	var walk_icon: String = input._cursor_icon_from_commit_slots(walk_slots, unit)
	if walk_icon != PlanningIcons.GLYPH_WALK:
		failures.append(
			"PlanningQAGate cursor 1B: walk tile must show walk glyph, got %s" % walk_icon,
		)
	var run_slots: Dictionary = {
		"pre": [
			TimelineAction.make_run_move(
				1, Vector2i(5, 2), -1, [], GameEnums.MoveTiming.PRE_ACTION,
			),
		],
		"action": [],
		"post": [],
		"invalid": false,
	}
	var run_icon: String = input._cursor_icon_from_commit_slots(run_slots, unit)
	if run_icon != PlanningIcons.GLYPH_RUN:
		failures.append(
			"PlanningQAGate cursor 1B: run tile must show run glyph, got %s" % run_icon,
		)
	var bash: AbilityData = _knight_ability(SHIELD_BASH_ID)
	if bash == null:
		failures.append("PlanningQAGate cursor 1B: Shield Bash ability missing")
		return
	var paired_slots: Dictionary = {
		"pre": [TimelineAction.make_move(1, BASH_APPROACH)],
		"action": [TimelineAction.make_ability(1, bash, ENEMY_POS, 2)],
		"post": [],
		"invalid": false,
	}
	var paired_icon: String = input._cursor_icon_from_commit_slots(paired_slots, unit)
	var expected_paired: String = PlanningIcons.join_glyphs([
		PlanningIcons.GLYPH_WALK,
		PlanningIcons.GLYPH_ATTACK,
	])
	if paired_icon != expected_paired:
		failures.append(
			"PlanningQAGate cursor 1B: walk+skill must composite %s, got %s"
			% [expected_paired, paired_icon],
		)


static func _test_committed_walk_preview_matches_sim_path(failures: Array[String]) -> void:
	var plain := TerrainData.new()
	plain.blocks_movement = false
	var board := BoardState.new()
	board.grid_size = Vector2i(10, 6)
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, plain)
	var knight_def: UnitData = DataLibrary.get_unit(&"knight")
	var knight: UnitState = UnitState.create(1, knight_def, GameEnums.Team.PLAYER, Vector2i(0, 2))
	knight.movement.points_left = 4
	knight.movement.max_points = 4
	board.units = [knight]
	GridSystem.set_occupant(board, knight.position, knight.id)
	var director := CombatDirector.new()
	director.plan_pre_move = Timeline.new()
	director.plan_action = Timeline.new()
	director.plan_post_move = Timeline.new()
	director.board = board
	director.base_board = board.clone()
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = 1
	director.selected_ability_index = -1
	var input := CombatPlanningInput.new()
	input._director = director
	input.force_basic_movement = true
	var dest := Vector2i(2, 2)
	var slots: Dictionary = _commit_slots_at(input, 1, dest)
	if bool(slots.get("invalid", true)):
		failures.append("PlanningQAGate movement exec: basic walk commit slots invalid")
		return
	if not director.commit_from_slots(1, slots):
		failures.append("PlanningQAGate movement exec: basic walk commit failed")
		return
	director.flush_plan_refresh_signals_if_pending()
	var start_board: BoardState = director.base_board.clone()
	start_board.intents = []
	var result: SimResult = Simulator.simulate(start_board, director.get_player_plan())
	var visited: Array[Vector2i] = [Vector2i(0, 2)]
	for event: SimEvent in result.events:
		if event.type != GameEnums.SimEventType.UNIT_MOVED:
			continue
		if int(event.data.get("actor", -1)) != 1:
			continue
		var path_v: Variant = event.data.get("path", [])
		if path_v is Array:
			for step: Variant in path_v:
				if step is Vector2i:
					visited.append(step)
	var pre: TimelineAction = director.plan_pre_move.entries[0]
	if pre.waypoints.size() > 0:
		for wp: Vector2i in pre.waypoints:
			if not visited.has(wp):
				failures.append(
					"PlanningQAGate movement exec: sim path missing committed waypoint %s (visited %s)"
					% [str(wp), str(visited)],
				)
	if visited.back() != dest:
		failures.append(
			"PlanningQAGate movement exec: sim must end at %s, visited %s"
			% [str(dest), str(visited)],
		)


static func _test_shield_bash_enemy_hover_commit_slots(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate Shield Bash 2A: ability missing on knight")
		return
	director.selected_ability_index = bash_idx
	var slots: Dictionary = input._final_commit_slots_for_interaction(
		1, ENEMY_POS, [], [], Vector2i(-999999, -999999),
	)
	if bool(slots.get("invalid", true)):
		failures.append("PlanningQAGate Shield Bash 2A: enemy hover slots invalid")
		return
	var pre: Array = slots.get("pre", []) as Array
	var action: Array = slots.get("action", []) as Array
	if pre.is_empty() or action.is_empty():
		failures.append("PlanningQAGate Shield Bash 2A: enemy hover must fill pre + action")
		return
	var move_step: TimelineAction = pre[0] as TimelineAction
	var bash_step: TimelineAction = action[0] as TimelineAction
	if move_step.target_coord != BASH_APPROACH:
		failures.append(
			"PlanningQAGate Shield Bash 2A: pre-move must approach %s, got %s"
			% [str(BASH_APPROACH), str(move_step.target_coord)],
		)
	if bash_step.target_unit_id != 2:
		failures.append("PlanningQAGate Shield Bash 2A: action must target enemy id 2")


static func _test_shield_bash_push_away_from_player(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(BASH_APPROACH, ENEMY_POS)
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate Shield Bash 2A push: ability missing")
		return
	var bash: AbilityData = fix.knight.active_abilities[bash_idx]
	var actions: Array[TimelineAction] = [
		TimelineAction.make_ability(
			1, bash, ENEMY_POS, 2, GameEnums.MoveTiming.PRE_ACTION,
		),
	]
	var preview := _preview_for_actions(director, actions)
	var pushes: Array = preview.preview_pushes.get(2, [])
	var seg: Array = _push_segment(pushes)
	if seg.size() < 2:
		failures.append("PlanningQAGate Shield Bash 2A push: preview_pushes missing segment")
		return
	var from_cell: Vector2i = seg[0] as Vector2i
	var to_cell: Vector2i = seg[1] as Vector2i
	if to_cell.x <= from_cell.x:
		failures.append(
			"PlanningQAGate Shield Bash 2A push: must push east away from player %s -> %s"
			% [str(from_cell), str(to_cell)],
		)


static func _test_shield_bash_enemy_lands_at_push_destination(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(BASH_APPROACH, ENEMY_POS)
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate Shield Bash 2A threat: ability missing")
		return
	var bash: AbilityData = fix.knight.active_abilities[bash_idx]
	var actions: Array[TimelineAction] = [
		TimelineAction.make_ability(
			1, bash, ENEMY_POS, 2, GameEnums.MoveTiming.PRE_ACTION,
		),
	]
	var preview := _preview_for_actions(director, actions)
	var pushes: Array = preview.preview_pushes.get(2, [])
	var seg: Array = _push_segment(pushes)
	if seg.size() < 2:
		failures.append("PlanningQAGate Shield Bash 2A threat: missing push preview")
		return
	var pushed_to: Vector2i = seg[1] as Vector2i
	if preview.preview_board == null:
		failures.append("PlanningQAGate Shield Bash 2A threat: preview board missing")
		return
	var pv_enemy: UnitState = preview.preview_board.get_unit_by_id(2)
	if pv_enemy == null:
		failures.append("PlanningQAGate Shield Bash 2A threat: enemy missing on preview board")
		return
	if pv_enemy.position != pushed_to:
		failures.append(
			"PlanningQAGate Shield Bash 2A threat: enemy must land at push dest %s, at %s"
			% [str(pushed_to), str(pv_enemy.position)],
		)


static func _test_shield_bash_enemy_hover_composite_cursor(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	director.selected_ability_index = bash_idx
	var slots: Dictionary = input._final_commit_slots_for_interaction(
		1, ENEMY_POS, [], [], Vector2i(-999999, -999999),
	)
	var icon: String = input._cursor_icon_from_commit_slots(slots, fix.knight)
	if icon.find(PlanningIcons.GLYPH_WALK) < 0 or icon.find(PlanningIcons.GLYPH_ATTACK) < 0:
		failures.append(
			"PlanningQAGate Shield Bash 2A cursor: enemy hover must composite walk+attack, got %s"
			% icon,
		)


static func _test_shield_bash_hover_change_clears_stale_approach(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	director.selected_ability_index = bash_idx
	input._drag_route = [KNIGHT_START, Vector2i(5, 5)]
	input.dragging = true
	input._drag_unit_id = 1
	var stale_slots: Dictionary = input._final_commit_slots_for_interaction(
		1, ENEMY_POS, input._drag_route, [], Vector2i(-999999, -999999),
	)
	input.dragging = false
	input._drag_route.clear()
	var fresh_slots: Dictionary = input._final_commit_slots_for_interaction(
		1, ENEMY_POS, [], [], Vector2i(-999999, -999999),
	)
	var stale_pre: Array = stale_slots.get("pre", []) as Array
	var fresh_pre: Array = fresh_slots.get("pre", []) as Array
	if stale_pre.is_empty() or fresh_pre.is_empty():
		failures.append("PlanningQAGate Shield Bash 2A stale: pre-move missing on hover compare")
		return
	var stale_move: TimelineAction = stale_pre[0] as TimelineAction
	var fresh_move: TimelineAction = fresh_pre[0] as TimelineAction
	if fresh_move.target_coord != BASH_APPROACH:
		failures.append(
			"PlanningQAGate Shield Bash 2A stale: fresh hover must use canonical approach %s"
			% str(BASH_APPROACH),
		)
	if stale_move.target_coord == Vector2i(5, 5):
		failures.append(
			"PlanningQAGate Shield Bash 2A stale: enemy hover must not keep invalid drag waypoint (5,5)",
		)


static func _test_chain_hook_awaiting_targeting_segment(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(Vector2i(1, 3), Vector2i(4, 3))
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var hook_idx: int = _ability_index(fix.knight, CHAIN_HOOK_ID)
	if hook_idx < 0:
		failures.append("PlanningQAGate Chain Hook 2B: ability missing")
		return
	director.selected_ability_index = hook_idx
	var hook: AbilityData = fix.knight.active_abilities[hook_idx]
	if AbilitySystem.ability_has_movement_effect(hook):
		failures.append("PlanningQAGate Chain Hook 2B: hook must not be movement-effect skill")
	if not hook.has_targeting(GameEnums.TargetingFlags.ENEMY):
		failures.append("PlanningQAGate Chain Hook 2B: hook must target enemies")
	var enemy_pos: Vector2i = fix.enemy.position
	var slots: Dictionary = input._final_commit_slots_for_interaction(
		1, enemy_pos, [] as Array[Vector2i], [] as Array[Vector2i], Vector2i(-999999, -999999),
	)
	if bool(slots.get("invalid", true)):
		failures.append("PlanningQAGate Chain Hook 2B: enemy hover slots invalid")
		return
	var action_steps: Array = slots.get("action", []) as Array
	if action_steps.is_empty():
		failures.append("PlanningQAGate Chain Hook 2B: enemy hover must commit hook action")
		return
	var hook_action: TimelineAction = action_steps[0] as TimelineAction
	if hook_action.target_unit_id != 2:
		failures.append("PlanningQAGate Chain Hook 2B: hook action must target enemy id 2")
	var segment: Array[Vector2i] = [fix.knight.position, enemy_pos]
	if segment[0] == segment[1]:
		failures.append("PlanningQAGate Chain Hook 2B: targeting segment must be player -> enemy")


static func _test_chain_hook_pull_toward_player(failures: Array[String]) -> void:
	var knight_pos := Vector2i(1, 3)
	var enemy_pos := Vector2i(4, 3)
	var fix: Dictionary = _planning_fixture(knight_pos, enemy_pos)
	var director: CombatDirector = fix.director
	var hook_idx: int = _ability_index(fix.knight, CHAIN_HOOK_ID)
	if hook_idx < 0:
		failures.append("PlanningQAGate Chain Hook 2B pull: ability missing")
		return
	var hook: AbilityData = fix.knight.active_abilities[hook_idx]
	var actions: Array[TimelineAction] = [
		TimelineAction.make_ability(
			1, hook, enemy_pos, 2, GameEnums.MoveTiming.PRE_ACTION,
		),
	]
	var preview := _preview_for_actions(director, actions)
	var pushes: Array = preview.preview_pushes.get(2, [])
	var seg: Array = _push_segment(pushes)
	if seg.size() < 2:
		failures.append("PlanningQAGate Chain Hook 2B pull: preview displacement missing")
		return
	var from_cell: Vector2i = seg[0] as Vector2i
	var to_cell: Vector2i = seg[1] as Vector2i
	if to_cell.x >= from_cell.x:
		failures.append(
			"PlanningQAGate Chain Hook 2B pull: must pull west toward player %s -> %s"
			% [str(from_cell), str(to_cell)],
		)


static func _test_trampling_premove_then_arm_commit_flow(failures: Array[String]) -> void:
	var start := Vector2i(5, 4)
	var fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(start)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("PlanningQAGate Trampling 2C: missing Trampling Advance")
		return
	input.force_basic_movement = true
	director.selected_ability_index = -1
	var pre_dest := Vector2i(6, 4)
	var trample_end := Vector2i(6, 3)
	var pre_slots: Dictionary = _commit_slots_at(input, 1, pre_dest)
	if bool(pre_slots.get("invalid", true)):
		failures.append("PlanningQAGate Trampling 2C: pre-move slots invalid")
		return
	if not director.commit_from_slots(1, pre_slots):
		failures.append("PlanningQAGate Trampling 2C: pre-move commit failed")
		return
	director.flush_plan_refresh_signals_if_pending()
	if director.plan_pre_move.entries.is_empty():
		failures.append("PlanningQAGate Trampling 2C: pre-move must stay on timeline")
	input.force_basic_movement = false
	director.selected_ability_index = fix.trample_idx
	var stand: Vector2i = director.projected_state.get_unit_by_id(1).position
	if not _arm_awaiting_at(input, director, stand):
		failures.append("PlanningQAGate Trampling 2C: arm awaiting failed at %s" % str(stand))
		return
	var route: Array[Vector2i] = [pre_dest, trample_end]
	TramplingAdvanceE2ETest._paint_drag_route(input, unit, route, trample_end)
	var slots: Dictionary = TramplingAdvanceE2ETest._commit_drag_route(
		input, director, trample_end,
	)
	if slots.is_empty():
		failures.append("PlanningQAGate Trampling 2C: trample commit failed after pre-move")
		return
	var trample: TimelineAction = TramplingAdvanceE2ETest._committed_trample_action(director)
	if trample == null:
		failures.append("PlanningQAGate Trampling 2C: missing committed trample action")
		return
	if trample.target_coord != trample_end:
		failures.append(
			"PlanningQAGate Trampling 2C: trample target %s expected %s"
			% [str(trample.target_coord), str(trample_end)],
		)
	var preview: CombatPlanningPreview = TramplingAdvanceE2ETest._rebuild_committed_preview(director)
	var path: Array = preview.preview_paths.get(1, [])
	var expected_path: Array[Vector2i] = [start, pre_dest, trample_end]
	if path != expected_path:
		failures.append(
			"PlanningQAGate Trampling 2C: preview path %s expected %s"
			% [str(path), str(expected_path)],
		)


static func _test_trampling_unarmed_empty_hover_is_premove(failures: Array[String]) -> void:
	var fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(PlanningChecklistHarness.TRAMPLE_START)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	if fix.trample_idx < 0:
		failures.append("PlanningQAGate Trampling unarmed hover: missing Trampling Advance")
		return
	director.auto_run = true
	director.selected_ability_index = fix.trample_idx
	if input.awaiting_targeting_active():
		failures.append(
			"PlanningQAGate Trampling unarmed hover: select must not arm awaiting yet",
		)
		return
	var hover_walk: Vector2i = PlanningChecklistHarness.TRAMPLE_ROUTE[0]
	var in_range_endpoint: Vector2i = Vector2i(4, 4)
	var in_range_slots: Dictionary = PlanningQAGateTest._commit_slots_at(input, 1, in_range_endpoint)
	if bool(in_range_slots.get("invalid", false)):
		failures.append(
			"PlanningQAGate Trampling unarmed hover: in-range endpoint slots invalid %s"
			% str(in_range_slots),
		)
		return
	var in_range_pre: Array = in_range_slots.get("pre", []) as Array
	var in_range_actions: Array = in_range_slots.get("action", []) as Array
	if in_range_pre.is_empty():
		failures.append(
			"PlanningQAGate Trampling unarmed hover: in-range endpoint must populate pre-move",
		)
	for raw_action: Variant in in_range_actions:
		if raw_action is TimelineAction:
			var committed: TimelineAction = raw_action as TimelineAction
			if committed.awaiting_target:
				continue
			if committed.ability != null and committed.ability.id == TRAMPLE_ID:
				failures.append(
					"PlanningQAGate Trampling unarmed hover: in-range tile must not commit trample action",
				)
	var slots: Dictionary = PlanningQAGateTest._commit_slots_at(input, 1, hover_walk)
	if bool(slots.get("invalid", false)):
		failures.append(
			"PlanningQAGate Trampling unarmed hover: slots invalid %s" % str(slots),
		)
		return
	var pre_moves: Array = slots.get("pre", []) as Array
	var actions: Array = slots.get("action", []) as Array
	if pre_moves.is_empty():
		failures.append(
			"PlanningQAGate Trampling unarmed hover: expected pre-move on empty tile",
		)
	if not actions.is_empty():
		failures.append(
			"PlanningQAGate Trampling unarmed hover: action must stay empty before arm",
		)
	var pre: TimelineAction = pre_moves[0] as TimelineAction if not pre_moves.is_empty() else null
	if pre != null and pre.target_coord != hover_walk:
		failures.append(
			"PlanningQAGate Trampling unarmed hover: pre-move dest %s expected %s"
			% [str(pre.target_coord), str(hover_walk)],
		)


static func _test_hover_slots_are_deterministic(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate integrity: Shield Bash missing for deterministic hover")
		return
	director.selected_ability_index = bash_idx
	var empty_wps: Array[Vector2i] = []
	var empty_legal: Array[Vector2i] = []
	var first: Dictionary = input._final_commit_slots_for_interaction(
		1, ENEMY_POS, empty_wps, empty_legal, Vector2i(-999999, -999999),
	)
	var second: Dictionary = input._final_commit_slots_for_interaction(
		1, ENEMY_POS, empty_wps, empty_legal, Vector2i(-999999, -999999),
	)
	if _slot_signature(first) != _slot_signature(second):
		failures.append(
			"PlanningQAGate integrity: repeat enemy hover must return identical slots %s vs %s"
			% [_slot_signature(first), _slot_signature(second)],
		)


static func _test_commit_plan_matches_hover_slots(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate integrity: Shield Bash missing for commit parity")
		return
	director.selected_ability_index = bash_idx
	var slots: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	if bool(slots.get("invalid", true)):
		failures.append("PlanningQAGate integrity: enemy hover must be committable")
		return
	if not director.commit_from_slots(1, slots):
		failures.append("PlanningQAGate integrity: commit_from_slots failed on hover slots")
		return
	director.flush_plan_refresh_signals_if_pending()
	var pre_target: Vector2i = _pre_target(slots)
	if not director.plan_pre_move.entries.is_empty():
		var committed_pre: TimelineAction = director.plan_pre_move.entries[0]
		if committed_pre.target_coord != pre_target:
			failures.append(
				"PlanningQAGate integrity: committed pre-move %s != hover preview %s"
				% [str(committed_pre.target_coord), str(pre_target)],
			)
	if not director.plan_action.entries.is_empty():
		var committed_action: TimelineAction = director.plan_action.entries[0]
		if committed_action.target_unit_id != _action_target_unit(slots):
			failures.append(
				"PlanningQAGate integrity: committed action target %d != hover preview %d"
				% [committed_action.target_unit_id, _action_target_unit(slots)],
			)


static func _test_undo_action_keeps_premove(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(Vector2i(3, 3))
	var director: CombatDirector = fix.director
	var trample_idx: int = _ability_index(fix.knight, TRAMPLE_ID)
	if trample_idx < 0:
		failures.append("PlanningQAGate integrity: Trampling Advance missing for undo test")
		return
	var trample: AbilityData = fix.knight.active_abilities[trample_idx]
	director.plan_pre_move.entries.append(
		TimelineAction.make_move(
			1, Vector2i(4, 2), -1, [], GameEnums.MoveTiming.PRE_ACTION,
		),
	)
	director.plan_action.entries.append(
		TimelineAction.make_ability(
			1,
			trample,
			Vector2i(5, 1),
			-1,
			GameEnums.MoveTiming.PRE_ACTION,
			[Vector2i(4, 2), Vector2i(5, 1)],
		),
	)
	director.rpc_remove_last_for_unit(1)
	if not director.plan_action.entries.is_empty():
		failures.append("PlanningQAGate integrity: undo must remove action column entry")
	if director.plan_pre_move.entries.is_empty():
		failures.append("PlanningQAGate integrity: undo must not remove paired pre-move walk")


static func _test_shield_bash_full_approach_push_preview(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate integrity: Shield Bash missing for full approach push")
		return
	director.selected_ability_index = bash_idx
	var slots: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	var actions: Array[TimelineAction] = _actions_from_slots(slots)
	if actions.size() < 2:
		failures.append("PlanningQAGate integrity: enemy hover must plan walk + bash together")
		return
	var preview := _preview_for_actions(director, actions)
	var pushes: Array = preview.preview_pushes.get(2, [])
	var seg: Array = _push_segment(pushes)
	if seg.size() < 2:
		failures.append("PlanningQAGate integrity: full approach + bash must preview push")
		return
	var from_cell: Vector2i = seg[0] as Vector2i
	var to_cell: Vector2i = seg[1] as Vector2i
	if to_cell.x <= from_cell.x:
		failures.append(
			"PlanningQAGate integrity: full approach bash must push east %s -> %s"
			% [str(from_cell), str(to_cell)],
		)


static func _test_committed_hook_approach_uses_premove(failures: Array[String]) -> void:
	var fix: Dictionary = _hook_committed_approach_fixture()
	if fix.input == null:
		failures.append("PlanningQAGate integrity: Chain Hook missing for committed approach")
		return
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var knight: UnitState = fix.knight
	var enemy: UnitState = fix.enemy
	var enemy_slots: Dictionary = input._final_commit_slots_for_interaction(
		1, enemy.position, [] as Array[Vector2i], [] as Array[Vector2i], Vector2i(-999999, -999999),
	)
	if (enemy_slots.get("pre", []) as Array).is_empty():
		failures.append(
			"PlanningQAGate integrity: committed hook + enemy hover must build pre-move approach",
		)
	if not (enemy_slots.get("post", []) as Array).is_empty():
		failures.append(
			"PlanningQAGate integrity: committed hook approach must not use post-move column",
		)
	var approach_cell: Vector2i = director.preview_approach_tile(
		1, enemy.id, 0, Vector2i(3, 3),
	)
	if approach_cell == knight.position:
		failures.append("PlanningQAGate integrity: hook fixture should need approach tile")
		return
	var stand_slots: Dictionary = input._final_commit_slots_for_interaction(
		1, approach_cell, [] as Array[Vector2i], [] as Array[Vector2i], Vector2i(-999999, -999999),
	)
	if (stand_slots.get("pre", []) as Array).is_empty():
		failures.append(
			"PlanningQAGate integrity: committed hook + approach stand hover must build pre-move",
		)
	if not (stand_slots.get("post", []) as Array).is_empty():
		failures.append(
			"PlanningQAGate integrity: approach stand hover must not use post-move column",
		)


static func _test_out_of_range_hover_is_invalid(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate integrity: Shield Bash missing for range gate")
		return
	director.selected_ability_index = bash_idx
	var oob_slots: Dictionary = _commit_slots_at(input, 1, Vector2i(-1, 0))
	if not _slots_invalid(oob_slots):
		failures.append(
			"PlanningQAGate integrity: out-of-bounds hover must be rejected",
		)


static func _test_trample_paint_preview_matches_route(failures: Array[String]) -> void:
	var fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(TramplingAdvanceE2ETest.START_CELL)
	var input: CombatPlanningInput = fix.input
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("PlanningQAGate integrity: Trampling missing for paint preview")
		return
	TramplingAdvanceE2ETest._arm_trample_awaiting(input, fix.director, unit)
	var route: Array[Vector2i] = [
		TramplingAdvanceE2ETest.START_CELL,
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[0],
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[1],
	]
	TramplingAdvanceE2ETest._paint_drag_route(input, unit, route, TramplingAdvanceE2ETest.END_CELL)
	if not input._paint_valid_movement_endpoint_intent():
		failures.append("PlanningQAGate integrity: trample endpoint paint must be valid")
		return
	var preview_path: Array = input.preview_state.preview_paths.get(1, [])
	var expected: Array[Vector2i] = [
		TramplingAdvanceE2ETest.START_CELL,
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[0],
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[1],
	]
	if preview_path != expected:
		failures.append(
			"PlanningQAGate integrity: trample live preview path %s expected %s"
			% [str(preview_path), str(expected)],
		)


static func _test_trample_commit_preserves_east_then_north(failures: Array[String]) -> void:
	var fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(TramplingAdvanceE2ETest.START_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("PlanningQAGate integrity: Trampling missing for commit waypoints")
		return
	TramplingAdvanceE2ETest._arm_trample_awaiting(input, director, unit)
	var route: Array[Vector2i] = [
		TramplingAdvanceE2ETest.START_CELL,
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[0],
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[1],
	]
	TramplingAdvanceE2ETest._paint_drag_route(input, unit, route, TramplingAdvanceE2ETest.END_CELL)
	TramplingAdvanceE2ETest._commit_drag_route(input, director, TramplingAdvanceE2ETest.END_CELL)
	var action: TimelineAction = TramplingAdvanceE2ETest._committed_trample_action(director)
	if action == null:
		failures.append("PlanningQAGate integrity: missing committed trample after paint")
		return
	if action.waypoints != TramplingAdvanceE2ETest.EAST_THEN_NORTH:
		failures.append(
			"PlanningQAGate integrity: trample waypoints %s expected E-then-N %s"
			% [str(action.waypoints), str(TramplingAdvanceE2ETest.EAST_THEN_NORTH)],
		)


static func _test_trample_sim_follows_painted_order(failures: Array[String]) -> void:
	var fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(TramplingAdvanceE2ETest.START_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("PlanningQAGate integrity: Trampling missing for sim order")
		return
	TramplingAdvanceE2ETest._arm_trample_awaiting(input, director, unit)
	var route: Array[Vector2i] = [
		TramplingAdvanceE2ETest.START_CELL,
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[0],
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[1],
	]
	TramplingAdvanceE2ETest._paint_drag_route(input, unit, route, TramplingAdvanceE2ETest.END_CELL)
	if TramplingAdvanceE2ETest._commit_drag_route(input, director, TramplingAdvanceE2ETest.END_CELL).is_empty():
		failures.append("PlanningQAGate integrity: trample commit failed for sim order")
		return
	var start_board: BoardState = director.base_board.clone()
	start_board.intents = []
	var result: SimResult = Simulator.simulate(start_board, director.get_player_plan())
	var visited: Array[Vector2i] = [TramplingAdvanceE2ETest.START_CELL]
	for event: SimEvent in result.events:
		if event.type != GameEnums.SimEventType.UNIT_MOVED:
			continue
		if int(event.data.get("actor", -1)) != 1:
			continue
		var path_v: Variant = event.data.get("path", [])
		if path_v is Array:
			for step: Variant in path_v:
				if step is Vector2i:
					visited.append(step)
	var expected: Array[Vector2i] = [
		TramplingAdvanceE2ETest.START_CELL,
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[0],
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[1],
	]
	if visited != expected:
		failures.append(
			"PlanningQAGate integrity: trample sim walk %s expected painted E-then-N %s"
			% [str(visited), str(expected)],
		)


static func _test_bash_slots_preview_board_parity(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate preview parity: Shield Bash missing")
		return
	var slots: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	if _slots_invalid(slots):
		failures.append("PlanningQAGate preview parity: bash enemy hover must be valid")
		return
	var preview_dict: Dictionary = _preview_dict_from_cell(input, 1, ENEMY_POS)
	if bool(preview_dict.get("invalid", false)):
		failures.append("PlanningQAGate preview parity: slots preview dict must not be invalid")
		return
	var preview: CombatPlanningPreview = _preview_from_dict(director, preview_dict)
	var pushed_to: Vector2i = _enemy_push_destination(preview, 2)
	if pushed_to.x < -900000:
		failures.append("PlanningQAGate preview parity: slots preview must include push segment")
		return
	if preview.preview_board == null:
		failures.append("PlanningQAGate preview parity: slots preview missing preview_board")
		return
	var pv_enemy: UnitState = preview.preview_board.get_unit_by_id(2)
	if pv_enemy == null:
		failures.append("PlanningQAGate preview parity: enemy missing on slots preview board")
		return
	if pv_enemy.position != pushed_to:
		failures.append(
			"PlanningQAGate preview parity: preview_board enemy %s must match push dest %s"
			% [str(pv_enemy.position), str(pushed_to)],
		)


static func _test_hover_click_drop_slot_parity(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(fix)
	var input: CombatPlanningInput = fix.input
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate hover/click/drop parity: Shield Bash missing")
		return
	_clear_drag_state(input)
	var hover_slots: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	var click_slots: Dictionary = _click_slots_at(input, 1, ENEMY_POS)
	var drop_slots: Dictionary = _drop_slots_at(input, 1, ENEMY_POS)
	if _slots_invalid(hover_slots) or _slots_invalid(click_slots) or _slots_invalid(drop_slots):
		failures.append("PlanningQAGate hover/click/drop parity: bash enemy must be valid in all modes")
		return
	var hover_sig: String = _intent_slot_signature(hover_slots)
	var click_sig: String = _intent_slot_signature(click_slots)
	var drop_sig: String = _intent_slot_signature(drop_slots)
	if hover_sig != click_sig:
		failures.append(
			"PlanningQAGate hover/click/drop parity: interaction vs click differ %s vs %s"
			% [hover_sig, click_sig],
		)
	if click_sig != drop_sig:
		failures.append(
			"PlanningQAGate hover/click/drop parity: selection vs drop differ %s vs %s"
			% [click_sig, drop_sig],
		)


static func _test_click_drop_parity_bash_enemy(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(fix)
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate click/drop bash: Shield Bash missing")
		return
	_clear_drag_state(fix.input)
	_assert_click_drop_signature_parity(failures, "bash enemy", fix.input, 1, ENEMY_POS)


static func _test_click_drop_parity_walk_adjacent(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(fix)
	var director: CombatDirector = fix.director
	director.selected_ability_index = -1
	fix.input.force_basic_movement = true
	_clear_drag_state(fix.input)
	_assert_click_drop_signature_parity(failures, "walk adjacent", fix.input, 1, Vector2i(5, 5))


static func _test_click_drop_parity_bash_approach(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(fix)
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate click/drop approach: Shield Bash missing")
		return
	_clear_drag_state(fix.input)
	_assert_click_drop_signature_parity(failures, "bash approach", fix.input, 1, BASH_APPROACH)


static func _test_click_drop_parity_hook_enemy(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(Vector2i(1, 3), Vector2i(4, 3))
	_wire_click_drop_context(fix)
	var hook_idx: int = _ability_index(fix.knight, CHAIN_HOOK_ID)
	if hook_idx < 0:
		failures.append("PlanningQAGate click/drop hook: Chain Hook missing")
		return
	fix.director.selected_ability_index = hook_idx
	_clear_drag_state(fix.input)
	_assert_click_drop_signature_parity(
		failures, "hook enemy", fix.input, 1, fix.enemy.position,
	)


static func _test_click_drop_parity_oob_invalid(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(fix)
	var director: CombatDirector = fix.director
	_clear_drag_state(fix.input)
	var oob := Vector2i(-1, 0)
	var click_slots: Dictionary = _click_slots_at(fix.input, 1, oob)
	var drop_slots: Dictionary = _drop_slots_at(fix.input, 1, oob)
	if not _slots_invalid(click_slots):
		failures.append("PlanningQAGate click/drop oob: selection must reject out-of-bounds")
	if _actions_from_slots(drop_slots).size() > 0:
		failures.append("PlanningQAGate click/drop oob: drop must not offer OOB actions")
	if director.commit_from_slots(1, click_slots):
		failures.append("PlanningQAGate click/drop oob: selection commit must fail")
	if director.commit_from_slots(1, drop_slots):
		failures.append("PlanningQAGate click/drop oob: drop commit must fail")


static func _test_click_drop_cursor_parity_bash(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(fix)
	var input: CombatPlanningInput = fix.input
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate click/drop cursor bash: Shield Bash missing")
		return
	_clear_drag_state(input)
	var click_slots: Dictionary = _click_slots_at(input, 1, ENEMY_POS)
	var drop_slots: Dictionary = _drop_slots_at(input, 1, ENEMY_POS)
	var click_icon: String = input._cursor_icon_from_commit_slots(click_slots, fix.knight)
	var drop_icon: String = input._cursor_icon_from_commit_slots(drop_slots, fix.knight)
	if click_icon != drop_icon:
		failures.append(
			"PlanningQAGate click/drop cursor bash: selection %s != drop %s"
			% [click_icon, drop_icon],
		)


static func _test_click_drop_cursor_parity_walk(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	director.selected_ability_index = -1
	input.force_basic_movement = true
	_clear_drag_state(input)
	var dest := Vector2i(5, 5)
	var click_slots: Dictionary = _click_slots_at(input, 1, dest)
	var drop_slots: Dictionary = _drop_slots_at(input, 1, dest)
	if _slots_invalid(click_slots) or _slots_invalid(drop_slots):
		failures.append("PlanningQAGate click/drop cursor walk: adjacent walk must be valid")
		return
	var click_icon: String = input._cursor_icon_from_commit_slots(click_slots, fix.knight)
	var drop_icon: String = input._cursor_icon_from_commit_slots(drop_slots, fix.knight)
	if click_icon != drop_icon:
		failures.append(
			"PlanningQAGate click/drop cursor walk: selection %s != drop %s"
			% [click_icon, drop_icon],
		)


static func _test_click_drop_commit_sim_bash(failures: Array[String]) -> void:
	var click_fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(click_fix)
	if _bash_img1_ready(click_fix) < 0:
		failures.append("PlanningQAGate click/drop sim bash: Shield Bash missing")
		return
	_clear_drag_state(click_fix.input)
	var click_slots: Dictionary = _click_slots_at(click_fix.input, 1, ENEMY_POS)
	if _slots_invalid(click_slots):
		failures.append("PlanningQAGate click/drop sim bash: selection slots invalid")
		return
	var click_enemy_pos: Vector2i = _sim_enemy_position_after_slots_commit(
		click_fix.director, 1, 2, click_slots,
	)
	if click_enemy_pos.x < -900000:
		failures.append("PlanningQAGate click/drop sim bash: selection commit/sim failed")
		return
	var drop_fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(drop_fix)
	if _bash_img1_ready(drop_fix) < 0:
		failures.append("PlanningQAGate click/drop sim bash: Shield Bash missing on drop fixture")
		return
	_clear_drag_state(drop_fix.input)
	var drop_slots: Dictionary = _drop_slots_at(drop_fix.input, 1, ENEMY_POS)
	if _slots_invalid(drop_slots):
		failures.append("PlanningQAGate click/drop sim bash: drop slots invalid")
		return
	var drop_enemy_pos: Vector2i = _sim_enemy_position_after_slots_commit(
		drop_fix.director, 1, 2, drop_slots,
	)
	if drop_enemy_pos != click_enemy_pos:
		failures.append(
			"PlanningQAGate click/drop sim bash: enemy at %s (selection) vs %s (drop)"
			% [str(click_enemy_pos), str(drop_enemy_pos)],
		)


static func _test_click_drop_commit_sim_walk(failures: Array[String]) -> void:
	var dest := Vector2i(5, 5)
	var click_fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(click_fix)
	click_fix.director.selected_ability_index = -1
	click_fix.input.force_basic_movement = true
	_clear_drag_state(click_fix.input)
	var click_slots: Dictionary = _click_slots_at(click_fix.input, 1, dest)
	if _slots_invalid(click_slots):
		failures.append("PlanningQAGate click/drop sim walk: selection slots invalid")
		return
	var click_knight_pos: Vector2i = _sim_unit_position_after_slots_commit(
		click_fix.director, 1, click_slots,
	)
	if click_knight_pos != dest:
		failures.append(
			"PlanningQAGate click/drop sim walk: selection ended at %s expected %s"
			% [str(click_knight_pos), str(dest)],
		)
		return
	var drop_fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(drop_fix)
	drop_fix.director.selected_ability_index = -1
	drop_fix.input.force_basic_movement = true
	_clear_drag_state(drop_fix.input)
	var drop_slots: Dictionary = _drop_slots_at(drop_fix.input, 1, dest)
	if _slots_invalid(drop_slots):
		failures.append("PlanningQAGate click/drop sim walk: drop slots invalid")
		return
	var drop_knight_pos: Vector2i = _sim_unit_position_after_slots_commit(
		drop_fix.director, 1, drop_slots,
	)
	if drop_knight_pos != click_knight_pos:
		failures.append(
			"PlanningQAGate click/drop sim walk: knight at %s (selection) vs %s (drop)"
			% [str(click_knight_pos), str(drop_knight_pos)],
		)


static func _test_click_drop_drag_walk_sim_parity(failures: Array[String]) -> void:
	var dest := Vector2i(5, 5)
	var click_fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(click_fix)
	click_fix.director.selected_ability_index = -1
	click_fix.input.force_basic_movement = true
	_clear_drag_state(click_fix.input)
	var click_slots: Dictionary = _click_slots_at(click_fix.input, 1, dest)
	var click_pos: Vector2i = _sim_unit_position_after_slots_commit(click_fix.director, 1, click_slots)
	if click_pos != dest:
		failures.append(
			"PlanningQAGate click/drop drag walk: selection baseline failed at %s"
			% str(click_pos),
		)
		return
	var drop_fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(drop_fix)
	drop_fix.director.selected_ability_index = -1
	drop_fix.input.force_basic_movement = true
	var route: Array[Vector2i] = [KNIGHT_START, dest]
	TramplingAdvanceE2ETest._paint_drag_route(drop_fix.input, drop_fix.knight, route, dest)
	var drop_slots: Dictionary = _drop_slots_at(drop_fix.input, 1, dest)
	if _slots_invalid(drop_slots):
		failures.append("PlanningQAGate click/drop drag walk: painted drop slots invalid")
		return
	var drop_pos: Vector2i = _sim_unit_position_after_slots_commit(drop_fix.director, 1, drop_slots)
	if drop_pos != click_pos:
		failures.append(
			"PlanningQAGate click/drop drag walk: painted drop ended at %s, selection at %s"
			% [str(drop_pos), str(click_pos)],
		)


static func _test_click_drop_drag_bash_enemy_parity(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_click_drop_context(fix)
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate click/drop drag bash: Shield Bash missing")
		return
	_clear_drag_state(fix.input)
	var click_slots: Dictionary = _click_slots_at(fix.input, 1, ENEMY_POS)
	if _slots_invalid(click_slots):
		failures.append("PlanningQAGate click/drop drag bash: selection slots invalid")
		return
	var route: Array[Vector2i] = [KNIGHT_START, Vector2i(5, 5), BASH_APPROACH]
	TramplingAdvanceE2ETest._paint_drag_route(fix.input, fix.knight, route, BASH_APPROACH)
	var drop_slots: Dictionary = _drop_slots_at(fix.input, 1, ENEMY_POS)
	if _slots_invalid(drop_slots):
		failures.append("PlanningQAGate click/drop drag bash: painted drop on enemy invalid")
		return
	if _intent_slot_signature(click_slots) != _intent_slot_signature(drop_slots):
		failures.append(
			"PlanningQAGate click/drop drag bash: selection vs painted-drop differ %s vs %s"
			% [_intent_slot_signature(click_slots), _intent_slot_signature(drop_slots)],
		)


static func _test_drag_drop_commit_undo_clears_plan(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, Vector2i(-1, -1))
	_wire_click_drop_context(fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	director.selected_ability_index = -1
	input.force_basic_movement = true
	var dest := Vector2i(5, 5)
	input._begin_drag(fix.knight, Vector2.ZERO, true)
	var route: Array[Vector2i] = [KNIGHT_START, dest]
	input._drag_route = route.duplicate()
	input._drag_last_free = dest
	var params: Dictionary = input._commit_interaction_params(dest, -1)
	var slots: Dictionary = input._final_commit_slots_for_interaction(
		1, params.cell, params.waypoints, params.legal_move_tiles, params.preferred,
		int(params.get("face_dir", -1)),
	)
	if _slots_invalid(slots):
		failures.append("PlanningQAGate drag_drop_undo: painted drag commit slots invalid")
		return
	if not director.commit_from_slots(1, slots):
		failures.append("PlanningQAGate drag_drop_undo: commit_from_slots failed")
		return
	input._end_drag_interaction(false, false)
	director.flush_plan_refresh_signals_if_pending()
	if input._drag_saved_preview != null:
		failures.append(
			"PlanningQAGate drag_drop_undo: successful drop must clear _drag_saved_preview",
		)
	if director.plan_pre_move.size() == 0:
		failures.append("PlanningQAGate drag_drop_undo: drag commit must write pre-move")
		return
	var move_action: TimelineAction = director.plan_pre_move.entries[0]
	if move_action.irreversible:
		failures.append("PlanningQAGate drag_drop_undo: basic drag walk must stay undoable")
		return
	if not director.unit_has_undoable_action(1):
		failures.append("PlanningQAGate drag_drop_undo: unit must be undoable after drag commit")
		return
	var before: int = director.plan_pre_move.size()
	director.rpc_remove_last_for_unit(1)
	director.flush_plan_refresh_signals_if_pending()
	if director.plan_pre_move.size() >= before:
		failures.append(
			"PlanningQAGate drag_drop_undo: undo must remove drag-committed pre-move",
		)
	if input._drag_saved_preview != null:
		failures.append(
			"PlanningQAGate drag_drop_undo: undo must not leave stale drag preview stash",
		)


static func _test_cursor_equals_slots_on_hover(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate cursor parity: Shield Bash missing")
		return
	var bash_slots: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	var bash_icon_slots: String = input._cursor_icon_from_commit_slots(bash_slots, fix.knight)
	var bash_icon_hover: String = input.compute_hover_action_icon(ENEMY_POS)
	if bash_icon_slots != bash_icon_hover:
		failures.append(
			"PlanningQAGate cursor parity: bash enemy hover icon %s != slots icon %s"
			% [bash_icon_hover, bash_icon_slots],
		)
	director.selected_ability_index = -1
	input.force_basic_movement = true
	var walk_dest := Vector2i(5, 5)
	var walk_slots: Dictionary = _commit_slots_at(input, 1, walk_dest)
	if _slots_invalid(walk_slots):
		failures.append("PlanningQAGate cursor parity: adjacent walk hover must be valid")
		return
	var walk_icon_slots: String = input._cursor_icon_from_commit_slots(walk_slots, fix.knight)
	var walk_icon_hover: String = input.compute_hover_action_icon(walk_dest)
	if walk_icon_slots != walk_icon_hover:
		failures.append(
			"PlanningQAGate cursor parity: walk hover icon %s != slots icon %s"
			% [walk_icon_hover, walk_icon_slots],
		)


static func _test_bash_commit_sim_push(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate bash sim: Shield Bash missing")
		return
	var slots: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	if _slots_invalid(slots):
		failures.append("PlanningQAGate bash sim: enemy hover must be committable")
		return
	var preview_dict: Dictionary = _preview_dict_from_cell(input, 1, ENEMY_POS)
	var preview: CombatPlanningPreview = _preview_from_dict(director, preview_dict)
	var expected_push: Vector2i = _enemy_push_destination(preview, 2)
	if expected_push.x < -900000:
		failures.append("PlanningQAGate bash sim: preview must define push destination before commit")
		return
	if not director.commit_from_slots(1, slots):
		failures.append("PlanningQAGate bash sim: commit_from_slots failed on hover slots")
		return
	director.flush_plan_refresh_signals_if_pending()
	var result: SimResult = _simulate_committed_plan(director)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	if enemy == null:
		failures.append("PlanningQAGate bash sim: enemy missing after simulate")
		return
	if enemy.position != expected_push:
		failures.append(
			"PlanningQAGate bash sim: enemy at %s expected push destination %s from preview"
			% [str(enemy.position), str(expected_push)],
		)


static func _test_hook_commit_sim_pull(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(Vector2i(1, 3), Vector2i(4, 3))
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var hook_idx: int = _ability_index(fix.knight, CHAIN_HOOK_ID)
	if hook_idx < 0:
		failures.append("PlanningQAGate hook sim: Chain Hook missing")
		return
	director.selected_ability_index = hook_idx
	var start_enemy_x: int = fix.enemy.position.x
	var slots: Dictionary = _commit_slots_at(input, 1, fix.enemy.position)
	if _slots_invalid(slots):
		failures.append("PlanningQAGate hook sim: enemy hover must be committable")
		return
	var preview_dict: Dictionary = _preview_dict_from_cell(input, 1, fix.enemy.position)
	var preview: CombatPlanningPreview = _preview_from_dict(director, preview_dict)
	var expected_pos: Vector2i = fix.enemy.position
	if preview.preview_board != null:
		var pv_enemy: UnitState = preview.preview_board.get_unit_by_id(2)
		if pv_enemy != null:
			expected_pos = pv_enemy.position
	if expected_pos.x >= start_enemy_x:
		failures.append(
			"PlanningQAGate hook sim: preview must place enemy west of %d, got %s"
			% [start_enemy_x, str(expected_pos)],
		)
		return
	if not director.commit_from_slots(1, slots):
		failures.append("PlanningQAGate hook sim: commit_from_slots failed")
		return
	director.flush_plan_refresh_signals_if_pending()
	var result: SimResult = _simulate_committed_plan(director)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	if enemy == null:
		failures.append("PlanningQAGate hook sim: enemy missing after simulate")
		return
	if enemy.position != expected_pos:
		failures.append(
			"PlanningQAGate hook sim: enemy at %s expected preview/sim position %s"
			% [str(enemy.position), str(expected_pos)],
		)


static func _test_invalid_slots_block_commit(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate invalid commit: Shield Bash missing")
		return
	var oob_slots: Dictionary = _commit_slots_at(input, 1, Vector2i(-1, 0))
	if not _slots_invalid(oob_slots):
		failures.append("PlanningQAGate invalid commit: OOB slots must be invalid")
		return
	var actions: Array[TimelineAction] = _actions_from_slots(oob_slots)
	if director.preview_commit_valid(1, actions) == "":
		failures.append("PlanningQAGate invalid commit: preview_commit_valid must reject OOB/empty plan")
	if director.commit_from_slots(1, oob_slots):
		failures.append("PlanningQAGate invalid commit: commit_from_slots must reject invalid OOB slots")


static func _test_full_slot_signature_on_commit(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate full signature: Shield Bash missing")
		return
	var slots: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	if _slots_invalid(slots):
		failures.append("PlanningQAGate full signature: bash enemy hover must be valid")
		return
	var pre_steps: Array = slots.get("pre", []) as Array
	var action_steps: Array = slots.get("action", []) as Array
	if pre_steps.is_empty() or action_steps.is_empty():
		failures.append("PlanningQAGate full signature: bash enemy hover must fill pre + action")
		return
	var slot_pre: TimelineAction = pre_steps[0] as TimelineAction
	var slot_action: TimelineAction = action_steps[0] as TimelineAction
	if slot_pre.move_timing != GameEnums.MoveTiming.PRE_ACTION:
		failures.append("PlanningQAGate full signature: pre-move must use PRE_ACTION timing")
	if slot_action.ability == null or slot_action.ability.id != SHIELD_BASH_ID:
		failures.append("PlanningQAGate full signature: action must be Shield Bash")
	if not (slots.get("post", []) as Array).is_empty():
		failures.append("PlanningQAGate full signature: bash approach must not use post column")
	if not director.commit_from_slots(1, slots):
		failures.append("PlanningQAGate full signature: commit failed")
		return
	director.flush_plan_refresh_signals_if_pending()
	if director.plan_pre_move.entries.is_empty() or director.plan_action.entries.is_empty():
		failures.append("PlanningQAGate full signature: commit must write pre + action columns")
		return
	var committed_pre: TimelineAction = director.plan_pre_move.entries[0]
	var committed_action: TimelineAction = director.plan_action.entries[0]
	if committed_pre.target_coord != slot_pre.target_coord:
		failures.append("PlanningQAGate full signature: committed pre target mismatch")
	if committed_pre.waypoints != slot_pre.waypoints:
		failures.append(
			"PlanningQAGate full signature: committed pre waypoints %s != slots %s"
			% [str(committed_pre.waypoints), str(slot_pre.waypoints)],
		)
	if committed_action.target_unit_id != slot_action.target_unit_id:
		failures.append("PlanningQAGate full signature: committed action target mismatch")
	if committed_action.ability == null or committed_action.ability.id != SHIELD_BASH_ID:
		failures.append("PlanningQAGate full signature: committed action ability mismatch")


static func _test_ability_switch_clears_preview_cache(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	input._hover_preview_cache_key = "stale|1|ability|0"
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate cache clear: Shield Bash missing")
		return
	input._on_ability_selected(bash_idx)
	if input._hover_preview_cache_key != "":
		failures.append(
			"PlanningQAGate cache clear: ability select must invalidate hover preview cache",
		)


static func _test_ability_select_refreshes_enemy_hover_path(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_overlay(fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate ability scroll hover: Shield Bash missing")
		return
	var other_idx: int = -1
	for i: int in range(fix.knight.active_abilities.size()):
		if i == bash_idx:
			continue
		var ability: AbilityData = fix.knight.active_abilities[i] as AbilityData
		if ability != null and not ability.is_universal_run():
			other_idx = i
			break
	if other_idx < 0:
		failures.append("PlanningQAGate ability scroll hover: no alternate ability for scroll test")
		return
	input.on_hover_moved(ENEMY_POS)
	director.selected_ability_index = other_idx
	input._on_ability_selected(other_idx)
	director.selected_ability_index = bash_idx
	input._on_ability_selected(bash_idx)
	if not input.is_live_preview_active():
		failures.append(
			"PlanningQAGate ability scroll hover: Shield Bash on enemy must activate live preview",
		)
		return
	var path: Array = input.preview_state.preview_paths.get(1, [])
	if path.size() < 2:
		failures.append(
			"PlanningQAGate ability scroll hover: expected approach path, got %s" % str(path),
		)


static func _test_trample_paint_commit_sim_chain(failures: Array[String]) -> void:
	var fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(TramplingAdvanceE2ETest.START_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	if fix.trample_idx < 0:
		failures.append("PlanningQAGate trample chain: Trampling Advance missing")
		return
	TramplingAdvanceE2ETest._arm_trample_awaiting(input, director, unit)
	var route: Array[Vector2i] = [
		TramplingAdvanceE2ETest.START_CELL,
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[0],
		TramplingAdvanceE2ETest.EAST_THEN_NORTH[1],
	]
	var expected: Array[Vector2i] = route.duplicate()
	TramplingAdvanceE2ETest._paint_drag_route(input, unit, route, TramplingAdvanceE2ETest.END_CELL)
	if not input._paint_valid_movement_endpoint_intent():
		failures.append("PlanningQAGate trample chain: painted endpoint must be valid")
		return
	var live_path: Array = input.preview_state.preview_paths.get(1, [])
	if live_path != expected:
		failures.append(
			"PlanningQAGate trample chain: live preview %s != painted %s"
			% [str(live_path), str(expected)],
		)
	if TramplingAdvanceE2ETest._commit_drag_route(
		input, director, TramplingAdvanceE2ETest.END_CELL,
	).is_empty():
		failures.append("PlanningQAGate trample chain: commit failed")
		return
	var trample: TimelineAction = TramplingAdvanceE2ETest._committed_trample_action(director)
	if trample == null or trample.waypoints != TramplingAdvanceE2ETest.EAST_THEN_NORTH:
		failures.append("PlanningQAGate trample chain: committed waypoints must match paint")
		return
	var result: SimResult = _simulate_committed_plan(director)
	var visited: Array[Vector2i] = [TramplingAdvanceE2ETest.START_CELL]
	for event: SimEvent in result.events:
		if event.type != GameEnums.SimEventType.UNIT_MOVED:
			continue
		if int(event.data.get("actor", -1)) != 1:
			continue
		var path_v: Variant = event.data.get("path", [])
		if path_v is Array:
			for step: Variant in path_v:
				if step is Vector2i:
					visited.append(step)
	if visited != expected:
		failures.append(
			"PlanningQAGate trample chain: sim path %s != painted %s"
			% [str(visited), str(expected)],
		)


static func _test_bash_sim_determinism(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate sim determinism: Shield Bash missing")
		return
	var slots: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	if not director.commit_from_slots(1, slots):
		failures.append("PlanningQAGate sim determinism: bash commit failed")
		return
	director.flush_plan_refresh_signals_if_pending()
	var plan: Timeline = director.get_player_plan()
	var board_a: BoardState = director.base_board.clone()
	board_a.intents = []
	var board_b: BoardState = director.base_board.clone()
	board_b.intents = []
	var result_a: SimResult = Simulator.simulate(board_a, plan)
	var result_b: SimResult = Simulator.simulate(board_b, plan)
	var enemy_a: UnitState = result_a.final_state.get_unit_by_id(2)
	var enemy_b: UnitState = result_b.final_state.get_unit_by_id(2)
	if enemy_a == null or enemy_b == null:
		failures.append("PlanningQAGate sim determinism: enemy missing after simulate")
		return
	if enemy_a.position != enemy_b.position:
		failures.append(
			"PlanningQAGate sim determinism: repeat sim enemy positions differ %s vs %s"
			% [str(enemy_a.position), str(enemy_b.position)],
		)


static func _test_hover_order_invariant(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate hover order: Shield Bash missing")
		return
	var first_approach: Dictionary = _commit_slots_at(input, 1, BASH_APPROACH)
	var enemy_hover: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	var second_approach: Dictionary = _commit_slots_at(input, 1, BASH_APPROACH)
	if _slots_invalid(first_approach) or _slots_invalid(enemy_hover):
		failures.append("PlanningQAGate hover order: approach and enemy hovers must be valid")
		return
	if _intent_slot_signature(first_approach) != _intent_slot_signature(second_approach):
		failures.append(
			"PlanningQAGate hover order: approach hover unstable %s vs %s"
			% [_intent_slot_signature(first_approach), _intent_slot_signature(second_approach)],
		)
	if _pre_target(enemy_hover) != BASH_APPROACH:
		failures.append(
			"PlanningQAGate hover order: enemy hover pre-move must target canonical approach %s"
			% str(BASH_APPROACH),
		)


static func _test_drag_cleared_restores_canonical_bash_intent(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate drag cleared: Shield Bash missing")
		return
	var baseline: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	input._drag_unit_id = 1
	input._drag_route = [KNIGHT_START, Vector2i(5, 5)]
	input._drag_last_free = Vector2i(5, 5)
	input.dragging = true
	var polluted: Dictionary = input._final_commit_slots_for_interaction(
		1, ENEMY_POS, input._drag_route, [], Vector2i(-999999, -999999),
	)
	input.dragging = false
	input._drag_route.clear()
	input._drag_unit_id = -1
	input._drag_last_free = Vector2i(-999999, -999999)
	var restored: Dictionary = _commit_slots_at(input, 1, ENEMY_POS)
	if _slots_invalid(baseline) or _slots_invalid(restored):
		failures.append("PlanningQAGate drag cleared: bash enemy hover must stay valid")
		return
	if _intent_slot_signature(restored) != _intent_slot_signature(baseline):
		failures.append(
			"PlanningQAGate drag cleared: after drag cancel enemy intent must restore %s vs %s"
			% [_intent_slot_signature(baseline), _intent_slot_signature(restored)],
		)
	var polluted_pre: Array = polluted.get("pre", []) as Array
	if not polluted_pre.is_empty():
		var polluted_move: TimelineAction = polluted_pre[0] as TimelineAction
		if polluted_move != null and polluted_move.target_coord == Vector2i(5, 5):
			failures.append(
				"PlanningQAGate drag cleared: stale drag waypoint (5,5) must not persist on enemy hover",
			)


static func _test_approach_bash_slots_preview_keeps_push(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	if _bash_img1_ready(fix) < 0:
		failures.append("PlanningQAGate approach bash push: Shield Bash missing")
		return
	var preview_dict: Dictionary = _preview_dict_from_cell(input, 1, ENEMY_POS)
	if bool(preview_dict.get("invalid", false)):
		failures.append("PlanningQAGate approach bash push: slots preview must be valid")
		return
	var preview: CombatPlanningPreview = _preview_from_dict(director, preview_dict)
	if _enemy_push_destination(preview, 2).x < -900000:
		failures.append(
			"PlanningQAGate approach bash push: slots→preview must keep push arrows after approach move",
		)


static func _test_timeline_ghost_clears_when_committed(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, Vector2i(-1, -1))
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	director.selected_ability_index = -1
	input.force_basic_movement = true
	var dest := Vector2i(5, 5)
	var move: TimelineAction = TimelineAction.make_move(
		1, dest, -1, [], GameEnums.MoveTiming.PRE_ACTION,
	)
	input.preview_state.preview_board = director.board.clone()
	input._intent_snapshot_valid = true
	input._intent_snapshot_slots = {
		"pre": [move],
		"action": [],
		"post": [],
		"invalid": false,
	}
	var ghost_before: Dictionary = input.timeline_ghost_slots(1)
	if (ghost_before.get("pre", []) as Array).is_empty():
		failures.append("PlanningQAGate ghost: uncommitted hover intent must show ghost pre-move")
		return
	var ghost_move: TimelineAction = (ghost_before.get("pre", []) as Array)[0] as TimelineAction
	if ghost_move == null or ghost_move.target_coord != dest:
		failures.append("PlanningQAGate ghost: ghost pre-move must match hover intent target")
	director.plan_pre_move.entries.append(move)
	input._intent_snapshot_valid = true
	var ghost_after: Dictionary = input.timeline_ghost_slots(1)
	if not (ghost_after.get("pre", []) as Array).is_empty():
		failures.append(
			"PlanningQAGate ghost: ghost must clear when hover intent matches committed pre-move",
		)


static func _test_action_range_centered_on_live_stand(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate action_range_live_stand: Shield Bash missing")
		return
	director.selected_ability_index = bash_idx
	input.on_hover_moved(ENEMY_POS)
	input._flush_hover_heavy_sync()
	if not input.is_live_preview_active():
		failures.append(
			"PlanningQAGate action_range_live_stand: enemy hover must activate live preview",
		)
		return
	if not input.action_range_visible_for_hover():
		failures.append(
			"PlanningQAGate action_range_live_stand: enemy hover must keep action-range visible at live stand",
		)
		return
	var live_board: BoardState = overlay.get_live_preview().preview_board
	if live_board == null:
		failures.append("PlanningQAGate action_range_live_stand: live preview board missing")
		return
	var live_knight: UnitState = live_board.get_unit_by_id(1)
	if live_knight == null:
		failures.append("PlanningQAGate action_range_live_stand: live knight missing on preview board")
		return
	if live_knight.position != BASH_APPROACH:
		failures.append(
			"PlanningQAGate action_range_live_stand: expected live stand %s got %s"
			% [BASH_APPROACH, live_knight.position],
		)
		return
	var ability: AbilityData = _knight_ability(SHIELD_BASH_ID)
	if ability == null:
		failures.append("PlanningQAGate action_range_live_stand: Shield Bash ability missing")
		return
	var expected: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		fix.board, fix.knight, ability, live_knight.position,
	)
	for tile: Vector2i in expected:
		if not overlay.is_hover_action_range_tile(tile):
			failures.append(
				"PlanningQAGate action_range_live_stand: red tile %s missing (stand %s)"
				% [tile, live_knight.position],
			)


static func _find_run_hover_tile(board: BoardState, unit: UnitState) -> Vector2i:
	if board == null or unit == null:
		return Vector2i(-999999, -999999)
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			var coord := Vector2i(x, y)
			if coord == unit.position:
				continue
			if AbilitySystem.movement_requires_run(board, unit, coord, []):
				return coord
	return Vector2i(-999999, -999999)


static func _test_action_range_hides_when_auto_run_blocks_skill_ap(failures: Array[String]) -> void:
	const COMMITTED_RUN_DEST := Vector2i(3, 6)
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	director.auto_run = true
	fix.knight.ability.points_left = 1
	fix.knight.movement.points_left = 2
	var projected_knight: UnitState = director.projected_state.get_unit_by_id(1) if director.projected_state != null else null
	if projected_knight != null:
		projected_knight.ability.points_left = 1
		projected_knight.movement.points_left = 2
	var bowling_idx: int = _ability_index(fix.knight, BOWLING_CHARGE_ID)
	if bowling_idx < 0:
		failures.append("PlanningQAGate action_range_auto_run_ap_gate: Bowling Charge missing")
		return
	director.selected_ability_index = bowling_idx
	var run_tile: Vector2i = _find_run_hover_tile(fix.board, fix.knight)
	if run_tile.x <= -900000:
		failures.append("PlanningQAGate action_range_auto_run_ap_gate: no run-requiring hover tile found")
		return
	input.on_hover_moved(run_tile)
	input._flush_hover_heavy_sync()
	overlay._recompute_hover_ranges_from_inputs()
	if input.action_range_visible_for_hover():
		failures.append(
			"PlanningQAGate action_range_auto_run_ap_gate: action_range_visible_for_hover must be false after run hover %s"
			% run_tile,
		)
	if overlay.is_hover_action_range_tile(ENEMY_POS):
		failures.append(
			"PlanningQAGate action_range_auto_run_ap_gate: red tiles must hide when auto-run premove consumes skill AP (hover %s)"
			% run_tile,
		)
	var ability: AbilityData = _knight_ability(BOWLING_CHARGE_ID)
	if ability == null:
		failures.append("PlanningQAGate action_range_auto_run_ap_gate: Bowling Charge ability missing")
		return
	var expected: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		fix.board, fix.knight, ability, fix.knight.position,
	)
	for tile: Vector2i in expected:
		if overlay.is_hover_action_range_tile(tile):
			failures.append(
				"PlanningQAGate action_range_auto_run_ap_gate: red tile %s must be hidden after run hover %s"
				% [tile, run_tile],
			)
			return


static func _test_action_range_hides_after_commit_run_icon(failures: Array[String]) -> void:
	ActionRangeRegressionTest.assert_hide_red_after_commit_run_icon_shield_bash(failures)


static func _test_action_range_shows_while_awaiting_trample(failures: Array[String]) -> void:
	var fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(TramplingAdvanceE2ETest.START_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	if fix.trample_idx < 0:
		failures.append("PlanningQAGate action_range_awaiting_trample: Trampling Advance missing")
		return
	if not TramplingAdvanceE2ETest._arm_trample_awaiting(input, director, unit):
		failures.append("PlanningQAGate action_range_awaiting_trample: arm awaiting failed")
		return
	input.on_hover_moved(TramplingAdvanceE2ETest.END_CELL)
	overlay._recompute_hover_ranges_from_inputs()
	if not input.action_range_visible_for_hover():
		failures.append(
			"PlanningQAGate action_range_awaiting_trample: awaiting trample must keep action-range visible",
		)
		return
	var trample: AbilityData = unit.active_abilities[fix.trample_idx]
	var origin: Vector2i = CombatPlanningPreview.planning_move_origin_cell(director, fix.board, unit.id)
	var expected: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		fix.board, unit, trample, origin,
	)
	if expected.is_empty():
		failures.append("PlanningQAGate action_range_awaiting_trample: expected trample range tiles")
		return
	var found: bool = false
	for tile: Vector2i in expected:
		if overlay.is_hover_action_range_tile(tile):
			found = true
			break
	if not found:
		failures.append(
			"PlanningQAGate action_range_awaiting_trample: red tiles missing while awaiting (origin %s)"
			% origin,
		)


static func _test_action_range_shows_on_enemy_hover(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate action_range_enemy_hover: Shield Bash missing")
		return
	director.selected_ability_index = bash_idx
	director.plan_pre_move.entries.append(
		TimelineAction.make_move(
			1, BASH_APPROACH, -1, [], GameEnums.MoveTiming.PRE_ACTION,
		),
	)
	input.on_hover_moved(ENEMY_POS)
	input._flush_hover_heavy_sync()
	overlay._recompute_hover_ranges_from_inputs()
	if not input.action_range_visible_for_hover():
		failures.append(
			"PlanningQAGate action_range_enemy_hover: enemy hover must keep action-range visible",
		)
		return
	var ability: AbilityData = _knight_ability(SHIELD_BASH_ID)
	if ability == null:
		failures.append("PlanningQAGate action_range_enemy_hover: Shield Bash ability missing")
		return
	var stand: Vector2i = BASH_APPROACH
	var expected: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		fix.board, fix.knight, ability, stand,
	)
	var found: bool = false
	for tile: Vector2i in expected:
		if overlay.is_hover_action_range_tile(tile):
			found = true
			break
	if not found:
		failures.append(
			"PlanningQAGate action_range_enemy_hover: red tiles must show on enemy hover (stand %s)"
			% stand,
		)


static func _test_action_range_follows_cursor_on_move_hover(failures: Array[String]) -> void:
	const HOVER_DEST := Vector2i(3, 4)
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = _wire_overlay(fix)
	director.auto_run = true
	fix.knight.ability.points_left = 1
	var projected_knight: UnitState = (
		director.projected_state.get_unit_by_id(1) if director.projected_state != null else null
	)
	if projected_knight != null:
		projected_knight.ability.points_left = 1
	director.plan_pre_move.entries.append(
		TimelineAction.make_move(
			1, HOVER_DEST, -1, [], GameEnums.MoveTiming.PRE_ACTION,
		),
	)
	var bowling_idx: int = _ability_index(fix.knight, BOWLING_CHARGE_ID)
	if bowling_idx < 0:
		failures.append("PlanningQAGate action_range_move_hover_follows_cursor: Bowling Charge missing")
		return
	director.selected_ability_index = bowling_idx
	input.on_hover_moved(HOVER_DEST)
	input._flush_hover_heavy_sync()
	overlay._recompute_hover_ranges_from_inputs()
	if not input.action_range_visible_for_hover():
		failures.append(
			"PlanningQAGate action_range_move_hover_follows_cursor: red tiles must show on move hover when skill stays affordable after premove (hover %s)"
			% HOVER_DEST,
		)
		return
	var stand: Vector2i = input.action_range_intent_stand_cell(1)
	if stand != HOVER_DEST:
		failures.append(
			"PlanningQAGate action_range_move_hover_follows_cursor: expected stand %s got %s"
			% [HOVER_DEST, stand],
		)
		return
	var ability: AbilityData = _knight_ability(BOWLING_CHARGE_ID)
	if ability == null:
		failures.append("PlanningQAGate action_range_move_hover_follows_cursor: Bowling Charge ability missing")
		return
	var expected: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		fix.board, fix.knight, ability, stand,
	)
	var found: bool = false
	for tile: Vector2i in expected:
		if overlay.is_hover_action_range_tile(tile):
			found = true
			break
	if not found:
		failures.append(
			"PlanningQAGate action_range_move_hover_follows_cursor: red tiles must anchor on cursor stand %s"
			% stand,
		)


static func _test_enemy_skill_hover_not_movement_route(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_overlay(fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var hook_idx: int = _ability_index(fix.knight, CHAIN_HOOK_ID)
	if hook_idx < 0:
		failures.append("PlanningQAGate enemy_hover_not_move_route: Chain Hook missing")
		return
	director.selected_ability_index = hook_idx
	director.plan_pre_move.entries.append(
		TimelineAction.make_move(
			1, Vector2i(5, 4), -1, [], GameEnums.MoveTiming.PRE_ACTION,
		),
	)
	input.on_hover_moved(ENEMY_POS)
	if input.interaction_move_hover_active(1, ENEMY_POS):
		failures.append(
			"PlanningQAGate enemy_hover_not_move_route: enemy skill targeting must not use movement hover route",
		)
	if input.hover_attack_target_id() != fix.enemy.id:
		failures.append(
			"PlanningQAGate enemy_hover_not_move_route: enemy hover must resolve attack target id",
		)


static func _test_enemy_bash_approach_move_leg(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_overlay(fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate bash_enemy_approach_leg: Shield Bash missing")
		return
	director.selected_ability_index = bash_idx
	input.on_hover_moved(ENEMY_POS)
	if not input.is_live_preview_active():
		failures.append(
			"PlanningQAGate bash_enemy_approach_leg: live preview required on enemy hover",
		)
		return
	if input.interaction_move_hover_active(1, ENEMY_POS):
		failures.append(
			"PlanningQAGate bash_enemy_approach_leg: enemy hover must not be move-tile hover",
		)
		return
	var leg: Array = CombatPlanningPreview.pending_move_route_leg(
		1, input.preview_state, director, fix.board,
	)
	if leg.size() < 2:
		failures.append(
			"PlanningQAGate bash_enemy_approach_leg: expected pre-move leg, got %s" % str(leg),
		)


static func _test_bash_targeting_uses_pre_push_enemy_cell(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_overlay(fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate bash_target_pre_push_cell: Shield Bash missing")
		return
	director.selected_ability_index = bash_idx
	input.on_hover_moved(ENEMY_POS)
	if not input.is_live_preview_active():
		failures.append(
			"PlanningQAGate bash_target_pre_push_cell: live preview required on enemy hover",
		)
		return
	var pushes: Array = input.preview_state.preview_pushes.get(fix.enemy.id, [])
	if pushes.is_empty():
		failures.append(
			"PlanningQAGate bash_target_pre_push_cell: Shield Bash must preview push displacement",
		)
		return
	var preview_enemy: UnitState = input.preview_state.preview_board.get_unit_by_id(fix.enemy.id)
	if preview_enemy == null:
		failures.append("PlanningQAGate bash_target_pre_push_cell: preview enemy missing")
		return
	if preview_enemy.position == fix.enemy.position:
		failures.append(
			"PlanningQAGate bash_target_pre_push_cell: preview enemy must move on push preview",
		)


static func _test_hook_pull_preview_keeps_attack_target(failures: Array[String]) -> void:
	var fix: Dictionary = _planning_fixture(KNIGHT_START, ENEMY_POS)
	_wire_overlay(fix)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var hook_idx: int = _ability_index(fix.knight, CHAIN_HOOK_ID)
	if hook_idx < 0:
		failures.append("PlanningQAGate hook_pull_attack_target: Chain Hook missing")
		return
	director.selected_ability_index = hook_idx
	input.on_hover_moved(ENEMY_POS)
	if input.hover_attack_target_id() != fix.enemy.id:
		failures.append(
			"PlanningQAGate hook_pull_attack_target: enemy hover must resolve attack target",
		)
		return
	var pushes: Array = input.preview_state.preview_pushes.get(fix.enemy.id, [])
	if pushes.is_empty():
		failures.append(
			"PlanningQAGate hook_pull_attack_target: hook hover must preview pull displacement",
		)


static func _test_class_skill_execute_spends_ap(failures: Array[String]) -> void:
	const HOOK_KNIGHT := Vector2i(1, 3)
	const HOOK_ENEMY := Vector2i(4, 3)
	var fix: Dictionary = _planning_fixture(HOOK_KNIGHT, HOOK_ENEMY)
	var ability: AbilityData = _knight_ability(CHAIN_HOOK_ID)
	if ability == null:
		failures.append("PlanningQAGate class_skill_execute_ap: Chain Hook missing")
		return
	var action := TimelineAction.new()
	action.type = GameEnums.ActionType.ABILITY
	action.actor_id = 1
	action.target_unit_id = 2
	action.target_coord = HOOK_ENEMY
	action.ability = ability
	PlanningChecklistHarness.assert_execute_spends_ap(
		failures, "PlanningQAGate class_skill_execute_ap", fix.board, action, 0,
	)


static func _test_class_skill_player_turn_spends_ap(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningDragE2EHarness.wire_fixture(
		PlanningDragE2EHarness._planning_fixture(KNIGHT_START, ENEMY_POS),
	)
	fix.director.auto_run = true
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate class_skill_player_turn_ap: Shield Bash missing")
		return
	fix.director.selected_ability_index = bash_idx
	fix.input.on_hover_moved(ENEMY_POS)
	fix.input._flush_hover_heavy_sync()
	if not PlanningChecklistHarness.commit_paint_promote_only(fix, ENEMY_POS):
		failures.append("PlanningQAGate class_skill_player_turn_ap: bash commit failed")
		return
	PlanningChecklistHarness.assert_player_turn_ap_spent(
		failures, "PlanningQAGate class_skill_player_turn_ap", fix.director, 1, 0,
	)


static func _test_bash_promote_locks_committed_ghost(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningDragE2EHarness.wire_minimal_fixture(KNIGHT_START, ENEMY_POS)
	fix.director.auto_run = true
	var bash_idx: int = _ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("PlanningQAGate bash_promote_ghost: Shield Bash missing")
		return
	fix.director.selected_ability_index = bash_idx
	fix.input.on_hover_moved(ENEMY_POS)
	fix.input._flush_hover_heavy_sync()
	if not PlanningChecklistHarness.commit_paint_promote_only(fix, ENEMY_POS):
		failures.append("PlanningQAGate bash_promote_ghost: paint/commit failed")
		return
	PlanningChecklistHarness.assert_committed_ghost_pos(
		failures, "PlanningQAGate bash_promote_ghost", fix, 1, BASH_APPROACH,
	)


static func _test_hook_in_range_approach_tile_is_actor_position(failures: Array[String]) -> void:
	const HOOK_KNIGHT := Vector2i(1, 3)
	const HOOK_ENEMY := Vector2i(4, 3)
	var fix: Dictionary = _planning_fixture(HOOK_KNIGHT, HOOK_ENEMY)
	var hook_idx: int = _ability_index(fix.knight, CHAIN_HOOK_ID)
	if hook_idx < 0:
		failures.append("PlanningQAGate hook_in_range_approach: Chain Hook missing")
		return
	PlanningChecklistHarness.assert_preview_approach_tile(
		failures, "PlanningQAGate hook_in_range_approach", fix, 2, hook_idx,
		HOOK_ENEMY, HOOK_KNIGHT,
	)
