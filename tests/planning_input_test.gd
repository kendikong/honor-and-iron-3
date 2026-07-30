class_name PlanningInputTest
extends RefCounted

## Headless planning-input smoke tests (Phase 11).

static func run_all(failures: Array[String]) -> void:
	_test_force_basic_flag(failures)
	_test_undoable_action_director(failures)
	_test_planning_action_range_tiles(failures)
	_test_offensive_dash_heuristic(failures)
	_test_action_range_auto_run_ap_gate(failures)
	_test_composite_cursor_gate(failures)
	_test_cursor_matches_commit_slots(failures)
	_test_drag_cursor_matches_commit_slots(failures)
	_test_drag_cursor_ignores_preview_failed_flag(failures)
	_test_drop_commit_preserves_drag_route(failures)
	_test_cursor_omits_unaffordable_run_skill_pair(failures)
	_test_slots_only_cursor_matches_commit(failures)
	_test_preview_from_commit_slots(failures)
	_test_audit_regression_fixes(failures)
	_test_auto_skill_after_move_arms_dash(failures)
	_test_awaiting_plan_refresh(failures)
	_test_dash_arm_survives_plan_refresh(failures)
	_test_dash_self_click_blocks_false_wait(failures)
	_test_action_range_hidden_after_premove_mp(failures)
	_test_hover_cursor_matches_click_commit_slots(failures)
	_test_enemy_target_params_ignore_pseudo_drag(failures)
	_test_shield_bash_preview_pushes(failures)
	_test_planning_display_ap_run_intent(failures)
	_test_planning_display_mp_left(failures)
	_test_timeline_ghost_slots(failures)
	_test_committed_action_approach_uses_premove_slot(failures)
	_test_undo_movement_action_preserves_premove(failures)
	_test_ability_scroll_clears_hover_preview_cache(failures)


static func _bowling_charge_arm_fixture() -> Dictionary:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	var board := BoardState.new()
	board.grid_size = Vector2i(8, 8)
	var plain := TerrainData.new()
	plain.blocks_movement = false
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, plain)
	var dash := AbilityData.new()
	dash.kind = GameEnums.AbilityKind.CLASS_SKILL
	dash.display_name = "Bowling Charge"
	dash.targeting_mode = GameEnums.TargetingMode.ENEMY_UNIT
	dash.targeting_flags = AbilityData._targeting_mode_to_flags(dash.targeting_mode)
	var dash_eff := EffectData.new()
	dash_eff.type = GameEnums.EffectType.DASH
	dash_eff.amount = 3
	dash.effects = [dash_eff]
	var unit := UnitState.new()
	unit.id = 1
	unit.team = GameEnums.Team.PLAYER
	unit.position = Vector2i(2, 2)
	unit.movement.points_left = 4
	unit.ability.points_left = 3
	unit.active_abilities = [dash]
	board.units = [unit]
	GridSystem.set_occupant(board, unit.position, unit.id)
	director.board = board
	director.base_board = board
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = 1
	director.selected_ability_index = 0
	input._director = director
	return {"input": input, "director": director, "board": board, "unit": unit, "dash": dash}


static func _test_force_basic_flag(failures: Array[String]) -> void:
	var input := CombatPlanningInput.new()
	input.force_basic_movement = true
	if not input.force_basic_movement:
		failures.append("PlanningInputTest: force_basic_movement should persist when set")


static func _test_undoable_action_director(failures: Array[String]) -> void:
	var director := CombatDirector.new()
	var board := BoardState.new()
	board.grid_size = Vector2i(8, 6)
	var unit := UnitState.new()
	unit.id = 1
	unit.team = GameEnums.Team.PLAYER
	unit.position = Vector2i(2, 2)
	board.units = [unit]
	director.board = board
	director.phase = CombatDirector.Phase.PLANNING
	if director.unit_has_undoable_action(1):
		failures.append("PlanningInputTest: empty plan should not be undoable")
	var move := TimelineAction.new()
	move.type = GameEnums.ActionType.MOVE
	move.actor_id = 1
	move.target_coord = Vector2i(3, 2)
	director.plan_pre_move.entries.append(move)
	if not director.unit_has_undoable_action(1):
		failures.append("PlanningInputTest: queued move should be undoable")
	director.base_board = board
	director.plan_pre_move = Timeline.new()
	director.plan_action = Timeline.new()
	director.plan_post_move = Timeline.new()
	director.rpc_plan_wait(1)
	if not director.unit_has_wait_planned(1):
		failures.append("PlanningInputTest: wait should use hidden exhaustion slot")
	if director.plan_action.size() > 0:
		failures.append("PlanningInputTest: wait must not occupy plan_action")
	director.rpc_plan_wait(1)
	if director.unit_has_wait_planned(1):
		failures.append("PlanningInputTest: second wait call should cancel wait modifier")


static func _test_planning_action_range_tiles(failures: Array[String]) -> void:
	var board := BoardState.new()
	board.grid_size = Vector2i(8, 6)
	var unit := UnitState.new()
	unit.id = 1
	unit.position = Vector2i(3, 3)
	board.units = [unit]
	var dash := AbilityData.new()
	var dash_eff := EffectData.new()
	dash_eff.type = GameEnums.EffectType.DASH
	dash_eff.amount = 2
	dash.effects = [dash_eff]
	var tiles: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		board, unit, dash, unit.position, [],
	)
	if tiles.size() != 8:
		failures.append(
			"PlanningInputTest: dash range expected 8 cardinal tiles, got %d" % tiles.size(),
		)
	if not tiles.has(Vector2i(5, 3)):
		failures.append("PlanningInputTest: dash range missing east endpoint")
	var shifted: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		board, unit, dash, Vector2i(2, 3), [],
	)
	if not shifted.has(Vector2i(4, 3)):
		failures.append("PlanningInputTest: shifted dash origin should move east line")


static func _test_offensive_dash_heuristic(failures: Array[String]) -> void:
	var bulldoze_dash := AbilityData.new()
	var dash_eff := EffectData.new()
	dash_eff.type = GameEnums.EffectType.DASH
	dash_eff.amount = 3
	var bulldoze_eff := EffectData.new()
	bulldoze_eff.type = GameEnums.EffectType.BULLDOZE
	bulldoze_eff.amount = 1
	bulldoze_dash.effects = [dash_eff, bulldoze_eff]
	bulldoze_dash.targeting_mode = GameEnums.TargetingMode.ENEMY_UNIT
	if not AbilitySystem.ability_is_offensive_dash(bulldoze_dash):
		failures.append("PlanningInputTest: dash+bulldoze enemy skill should be offensive dash")
	var mobility_dash := AbilityData.new()
	mobility_dash.effects = [dash_eff]
	mobility_dash.targeting_mode = GameEnums.TargetingMode.SELF
	mobility_dash.can_target_self = true
	if AbilitySystem.ability_is_offensive_dash(mobility_dash):
		failures.append("PlanningInputTest: pure self dash should not be offensive dash")


static func _test_action_range_auto_run_ap_gate(failures: Array[String]) -> void:
	var setup: Dictionary = _plain_board_with_unit(Vector2i(0, 2), 2, 3)
	var board: BoardState = setup["board"] as BoardState
	var unit: UnitState = setup["unit"] as UnitState
	var skill := AbilityData.new()
	skill.kind = GameEnums.AbilityKind.CLASS_SKILL
	skill.action_point_cost = 3
	var dmg := EffectData.new()
	dmg.type = GameEnums.EffectType.DAMAGE
	dmg.amount = 2
	skill.effects = [dmg]
	var run_tile := Vector2i(5, 2)
	if not AbilitySystem.movement_requires_run(board, unit, run_tile, []):
		failures.append("PlanningInputTest: auto-run AP gate setup tile should require run")
	if AbilitySystem.can_show_planning_action_range_after_premove(
		board, unit, skill, run_tile, true,
	):
		failures.append(
			"PlanningInputTest: action range should hide when auto-run consumes last affordable AP",
		)
	unit.ability.points_left = 4
	if not AbilitySystem.can_show_planning_action_range_after_premove(
		board, unit, skill, run_tile, true,
	):
		failures.append(
			"PlanningInputTest: action range should show when run plus skill fit AP budget",
		)
	var walk_tile := Vector2i(1, 2)
	if not AbilitySystem.can_show_planning_action_range_after_premove(
		board, unit, skill, walk_tile, true,
	):
		failures.append("PlanningInputTest: walk premove should not consume run AP")


static func _test_composite_cursor_gate(failures: Array[String]) -> void:
	var input := CombatPlanningInput.new()
	input.auto_use_skill_after_move = false
	var slots: Dictionary = {
		"pre": [TimelineAction.make_move(1, Vector2i(2, 2))],
		"action": [TimelineAction.make_ability(1, AbilityData.new(), Vector2i(2, 2), 1)],
		"post": [],
		"invalid": false,
	}
	var icon: String = input._cursor_icon_from_commit_slots(slots, null)
	if icon.find("/") >= 0:
		failures.append("PlanningInputTest: composite cursor should be disabled when auto_use_skill_after_move is off")
	input.auto_use_skill_after_move = true
	icon = input._cursor_icon_from_commit_slots(slots, null)
	if icon.find("/") < 0:
		failures.append("PlanningInputTest: composite cursor should join move and action when enabled")


static func _test_cursor_matches_commit_slots(failures: Array[String]) -> void:
	var input := CombatPlanningInput.new()
	input.auto_use_skill_after_move = true
	var dash := AbilityData.new()
	dash.kind = GameEnums.AbilityKind.MOVEMENT_SKILL
	var dash_eff := EffectData.new()
	dash_eff.type = GameEnums.EffectType.DASH
	dash.effects = [dash_eff]
	var unit := UnitState.new()
	unit.id = 1
	var run_only_slots: Dictionary = {
		"pre": [
			TimelineAction.make_run_move(
				1, Vector2i(2, 4), -1, [], GameEnums.MoveTiming.PRE_ACTION,
			),
		],
		"action": [],
		"post": [],
		"invalid": false,
	}
	var icon: String = input._cursor_icon_from_commit_slots(run_only_slots, unit)
	if icon != PlanningIcons.GLYPH_RUN:
		failures.append(
			"PlanningInputTest: run-only premove cursor must be run icon, got %s" % icon,
		)
	var paired_slots: Dictionary = {
		"pre": [
			TimelineAction.make_run_move(
				1, Vector2i(2, 4), -1, [], GameEnums.MoveTiming.PRE_ACTION,
			),
		],
		"action": [TimelineAction.make_ability(1, dash, Vector2i(2, 4), 1)],
		"post": [],
		"invalid": false,
	}
	icon = input._cursor_icon_from_commit_slots(paired_slots, unit)
	var expected_paired: String = PlanningIcons.join_glyphs([
		PlanningIcons.GLYPH_RUN,
		PlanningIcons.GLYPH_DASH,
	])
	if icon != expected_paired:
		failures.append(
			"PlanningInputTest: paired run+dash cursor should composite, got %s" % icon,
		)
	var move_glyph: String = input._step_cursor_glyph(
		TimelineAction.make_run_move(
			1, Vector2i(2, 4), -1, [], GameEnums.MoveTiming.PRE_ACTION,
		),
		unit,
	)
	if move_glyph.find(PlanningIcons.GLYPH_DASH) >= 0:
		failures.append("PlanningInputTest: move glyph must not infer dash from armed skill")


static func _test_drag_cursor_matches_commit_slots(failures: Array[String]) -> void:
	var fix: Dictionary = _bowling_charge_arm_fixture()
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	input.auto_use_skill_after_move = true
	input.dragging = true
	input._drag_unit_id = 1
	input._drag_unit_was_selected = true
	var dest := Vector2i(1, 4)
	input._drag_route = [unit.position, Vector2i(2, 3), Vector2i(1, 3), dest]
	input._drag_last_free = Vector2i(1, 3)
	director.projected_state = director.board.clone()
	var params: Dictionary = input._commit_interaction_params(dest, -1)
	var slots: Dictionary = input._final_commit_slots_for_interaction(
		1,
		params.cell,
		params.waypoints,
		params.legal_move_tiles,
		params.preferred,
	)
	var expected_icon: String = input._cursor_icon_from_commit_slots(slots, unit)
	var drag_icon: String = input._drag_hover_icon(unit, dest)
	if drag_icon != expected_icon:
		failures.append(
			(
				"PlanningInputTest: drag cursor '%s' must match commit slots '%s'"
				% [drag_icon, expected_icon]
			),
		)
	if (slots.get("action", []) as Array).is_empty():
		failures.append(
			"PlanningInputTest: drag commit slots should include awaiting action for Bowling Charge",
		)
	if not director.commit_from_slots(1, slots):
		failures.append("PlanningInputTest: drag commit slots should commit")
	if director.find_awaiting_action(1) == null:
		failures.append(
			"PlanningInputTest: drag drop commit must leave awaiting action in plan_action",
		)


static func _test_drag_cursor_ignores_preview_failed_flag(failures: Array[String]) -> void:
	var fix: Dictionary = _bowling_charge_arm_fixture()
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	input.auto_use_skill_after_move = true
	input.dragging = true
	input._drag_unit_id = 1
	input._drag_unit_was_selected = true
	var dest := Vector2i(1, 4)
	input._drag_route = [unit.position, Vector2i(2, 3), Vector2i(1, 3), dest]
	input._drag_last_free = Vector2i(1, 3)
	input.drag_preview_failed = true
	director.projected_state = director.board.clone()
	var params: Dictionary = input._commit_interaction_params(dest, -1)
	var slots: Dictionary = input._final_commit_slots_for_interaction(
		1,
		params.cell,
		params.waypoints,
		params.legal_move_tiles,
		params.preferred,
	)
	if bool(slots.get("invalid", false)):
		failures.append(
			"PlanningInputTest: drag_preview_failed regression needs valid commit slots",
		)
		return
	var expected_icon: String = input._cursor_icon_from_commit_slots(slots, unit)
	var drag_icon: String = input._drag_hover_icon(unit, dest)
	if drag_icon != expected_icon:
		failures.append(
			(
				"PlanningInputTest: drag cursor must ignore drag_preview_failed (got '%s', expected '%s')"
				% [drag_icon, expected_icon]
			),
		)


static func _test_drop_commit_preserves_drag_route(failures: Array[String]) -> void:
	var fix: Dictionary = _bowling_charge_arm_fixture()
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	input.auto_use_skill_after_move = true
	input._drag_unit_id = 1
	input._drag_unit_was_selected = true
	var dest := Vector2i(1, 4)
	input._drag_route = [unit.position, Vector2i(2, 3), Vector2i(1, 3), dest]
	input._drag_last_free = Vector2i(1, 3)
	director.projected_state = director.board.clone()
	input.dragging = true
	var drag_params: Dictionary = input._commit_interaction_params(dest, -1)
	input.dragging = false
	var drop_params: Dictionary = input._commit_interaction_params(dest, -1)
	if drop_params.waypoints != drag_params.waypoints:
		failures.append(
			"PlanningInputTest: drop commit must keep drag route waypoints (got %s vs %s)"
			% [str(drop_params.waypoints), str(drag_params.waypoints)],
		)
	var drop_slots: Dictionary = input._final_commit_slots_for_interaction(
		1,
		drop_params.cell,
		drop_params.waypoints,
		drop_params.legal_move_tiles,
		drop_params.preferred,
	)
	if (drop_slots.get("action", []) as Array).is_empty():
		failures.append(
			"PlanningInputTest: drop commit slots must pair awaiting action with premove",
		)
	if not director.commit_from_slots(1, drop_slots):
		failures.append("PlanningInputTest: drop route commit should succeed")
	if director.find_awaiting_action(1) == null:
		failures.append(
			"PlanningInputTest: drop route commit must leave awaiting in plan_action",
		)
	if director.selected_ability_index < 0:
		failures.append(
			"PlanningInputTest: awaiting commit should keep bowling charge selected",
		)


static func _test_cursor_omits_unaffordable_run_skill_pair(failures: Array[String]) -> void:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	director.auto_run = true
	var board := BoardState.new()
	board.grid_size = Vector2i(8, 8)
	var plain := TerrainData.new()
	plain.blocks_movement = false
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, plain)
	var dash := AbilityData.new()
	dash.kind = GameEnums.AbilityKind.CLASS_SKILL
	dash.display_name = "Bowling Charge"
	dash.action_point_cost = 3
	var dash_eff := EffectData.new()
	dash_eff.type = GameEnums.EffectType.DASH
	dash_eff.amount = 3
	dash.effects = [dash_eff]
	var unit := UnitState.new()
	unit.id = 1
	unit.team = GameEnums.Team.PLAYER
	unit.position = Vector2i(2, 2)
	unit.movement.points_left = 2
	unit.movement.max_points = 4
	unit.ability.points_left = 1
	unit.ability.max_points = 3
	unit.active_abilities = [dash]
	board.units = [unit]
	GridSystem.set_occupant(board, unit.position, unit.id)
	director.board = board
	director.base_board = board
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = 1
	director.selected_ability_index = 0
	input._director = director
	input.auto_use_skill_after_move = true
	var dest := Vector2i(2, 5)
	var slots: Dictionary = input._final_commit_slots_for_interaction(1, dest)
	var icon: String = input._cursor_icon_from_commit_slots(slots, unit)
	if icon.find(PlanningIcons.GLYPH_DASH) >= 0:
		failures.append(
			"PlanningInputTest: cursor must not show dash when run+skill AP pair is unaffordable (got %s)"
			% icon,
		)
	if (slots.get("action", []) as Array).size() > 0:
		failures.append(
			"PlanningInputTest: unaffordable run+skill pair must not include action in commit slots",
		)
	var pre_moves: Array = slots.get("pre", [])
	if pre_moves.is_empty():
		failures.append(
			"PlanningInputTest: unaffordable pair should still allow run-only premove cursor",
		)
	elif not (pre_moves[0] as TimelineAction).uses_run:
		failures.append(
			"PlanningInputTest: distant tile with auto-run should still preview as run move",
		)
	if not director.commit_from_slots(1, slots):
		failures.append("PlanningInputTest: run-only fallback commit should succeed")
	if director.find_awaiting_action(1) != null:
		failures.append(
			"PlanningInputTest: unaffordable pair commit must not add awaiting action",
		)


static func _test_slots_only_cursor_matches_commit(failures: Array[String]) -> void:
	var fixture: Dictionary = _bowling_charge_arm_fixture()
	var input: CombatPlanningInput = fixture.input
	var director: CombatDirector = fixture.director
	var unit: UnitState = fixture.unit
	input.auto_use_skill_after_move = true
	director.projected_state = director.board.clone()
	var dest := Vector2i(1, 4)
	input.dragging = true
	input._drag_unit_id = 1
	input._drag_route = [unit.position, Vector2i(2, 3), dest]
	input._drag_last_free = Vector2i(2, 3)
	_assert_cursor_matches_slots(input, unit, dest, failures, "drag move+dash")
	input.dragging = false
	input._drag_unit_id = -1
	input._drag_route.clear()
	_assert_cursor_matches_slots(input, unit, unit.position, failures, "self arm")
	if not director.commit_from_slots(
		1, input._final_commit_slots_for_interaction(1, unit.position),
	):
		failures.append("PlanningInputTest: slots-only self arm commit should succeed")
	if director.find_awaiting_action(1) == null:
		failures.append("PlanningInputTest: slots-only self arm must write awaiting to plan")
	director.clear_awaiting_action(1)
	director.selected_ability_index = -1
	_assert_cursor_matches_slots(input, unit, unit.position, failures, "self wait")
	var wait_slots: Dictionary = input._final_commit_slots_for_interaction(1, unit.position)
	if not director.commit_from_slots(1, wait_slots):
		failures.append("PlanningInputTest: slots-only wait commit should succeed")
	if not director.unit_has_wait_planned(1):
		failures.append("PlanningInputTest: slots-only wait commit must toggle wait")


static func _assert_cursor_matches_slots(
	input: CombatPlanningInput,
	unit: UnitState,
	cell: Vector2i,
	failures: Array[String],
	label: String,
) -> void:
	var params: Dictionary = input._commit_interaction_params(cell, -1)
	var face_dir: int = int(params.get("face_dir", -1))
	var slots: Dictionary = input._final_commit_slots_for_interaction(
		unit.id,
		params.cell,
		params.waypoints,
		params.legal_move_tiles,
		params.preferred,
		face_dir,
	)
	var from_slots: String = input._cursor_icon_from_commit_slots(slots, unit)
	var from_hover: String = input._hover_icon_for_cell(
		unit,
		params.cell,
		params.waypoints,
		params.legal_move_tiles,
		params.preferred,
		face_dir,
	)
	if from_slots != from_hover:
		failures.append(
			"PlanningInputTest: %s cursor must equal commit slots (hover=%s slots=%s)"
			% [label, from_hover, from_slots],
		)


static func _test_preview_from_commit_slots(failures: Array[String]) -> void:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	var board := BoardState.new()
	board.grid_size = Vector2i(6, 6)
	var plain := TerrainData.new()
	plain.blocks_movement = false
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, plain)
	var unit := UnitState.new()
	unit.id = 1
	unit.team = GameEnums.Team.PLAYER
	unit.position = Vector2i(1, 1)
	unit.movement.points_left = 4
	unit.movement.max_points = 4
	unit.ability.points_left = 2
	board.units = [unit]
	GridSystem.set_occupant(board, unit.position, unit.id)
	director.board = board
	director.base_board = board
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = 1
	director.selected_ability_index = -1
	input._director = director
	var invalid: Dictionary = input._preview_from_commit_slots_at_cell(1, Vector2i(20, 20))
	if not bool(invalid.get("invalid", false)):
		failures.append("PlanningInputTest: out-of-range commit preview should be invalid")
	var move_preview: Dictionary = input._preview_from_commit_slots_at_cell(1, Vector2i(2, 1))
	if bool(move_preview.get("invalid", false)):
		failures.append("PlanningInputTest: adjacent move preview should be valid")
	var temp_board: BoardState = move_preview.get("temp_board") as BoardState
	if temp_board == null:
		failures.append("PlanningInputTest: move preview missing temp_board")
	else:
		var pv := temp_board.get_unit_by_id(1)
		if pv == null or pv.position != Vector2i(2, 1):
			failures.append("PlanningInputTest: move preview should place unit on target tile")


static func _test_audit_regression_fixes(failures: Array[String]) -> void:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	var board := BoardState.new()
	board.grid_size = Vector2i(6, 6)
	var plain := TerrainData.new()
	plain.blocks_movement = false
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, plain)
	var unit := UnitState.new()
	unit.id = 1
	unit.team = GameEnums.Team.PLAYER
	unit.position = Vector2i(2, 2)
	unit.movement.points_left = 4
	unit.ability.points_left = 2
	var heal := AbilityData.new()
	heal.targeting_mode = GameEnums.TargetingMode.SELF
	heal.targeting_flags = AbilityData._targeting_mode_to_flags(heal.targeting_mode)
	var dash := AbilityData.new()
	dash.kind = GameEnums.AbilityKind.MOVEMENT_SKILL
	var dash_eff := EffectData.new()
	dash_eff.type = GameEnums.EffectType.DASH
	dash.effects = [dash_eff]
	unit.active_abilities = [heal, dash]
	board.units = [unit]
	GridSystem.set_occupant(board, unit.position, unit.id)
	director.board = board
	director.base_board = board
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = 1
	input._director = director
	director.selected_ability_index = 0
	var self_slots: Dictionary = input._build_commit_slots_at_cell(1, unit.position)
	var action_steps: Array = self_slots.get("action", [])
	if action_steps.is_empty():
		failures.append("PlanningInputTest: self-target skill should populate action slot on own tile")
	director.selected_ability_index = 1
	var arm_slots: Dictionary = input._final_commit_slots_for_interaction(1, unit.position)
	if (arm_slots.get("action", []) as Array).is_empty():
		failures.append("PlanningInputTest: dash skill self click should build awaiting action slot")
	if not director.commit_from_slots(1, arm_slots):
		failures.append("PlanningInputTest: dash skill self click should arm dash targeting")
	if not input.awaiting_targeting_active():
		failures.append("PlanningInputTest: try_arm should queue awaiting action in plan")
	director.selected_ability_index = -1
	var wait_slots: Dictionary = input._final_commit_slots_for_interaction(1, unit.position)
	if input._cursor_icon_from_commit_slots(wait_slots, unit) != PlanningIcons.GLYPH_WAIT:
		failures.append("PlanningInputTest: empty skill bar should show wait cursor from commit slots")
	director.selected_ability_index = 0
	var heal_slots: Dictionary = input._final_commit_slots_for_interaction(1, unit.position)
	if input._cursor_icon_from_commit_slots(heal_slots, unit) == PlanningIcons.GLYPH_WAIT:
		failures.append("PlanningInputTest: wait cursor hidden when self-target skill selected")


static func _test_auto_skill_after_move_arms_dash(failures: Array[String]) -> void:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	var board := BoardState.new()
	board.grid_size = Vector2i(8, 8)
	var plain := TerrainData.new()
	plain.blocks_movement = false
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, plain)
	var unit := UnitState.new()
	unit.id = 1
	unit.team = GameEnums.Team.PLAYER
	unit.position = Vector2i(2, 2)
	unit.movement.points_left = 4
	unit.ability.points_left = 2
	var dash := AbilityData.new()
	dash.kind = GameEnums.AbilityKind.CLASS_SKILL
	var dash_eff := EffectData.new()
	dash_eff.type = GameEnums.EffectType.DASH
	dash_eff.amount = 3
	dash.effects = [dash_eff]
	dash.display_name = "Bowling Charge"
	dash.targeting_mode = GameEnums.TargetingMode.ENEMY_UNIT
	dash.targeting_flags = AbilityData._targeting_mode_to_flags(dash.targeting_mode)
	unit.active_abilities = [dash]
	board.units = [unit]
	GridSystem.set_occupant(board, unit.position, unit.id)
	director.board = board
	director.base_board = board
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = 1
	director.selected_ability_index = 0
	input._director = director
	input.auto_use_skill_after_move = true
	var paired_slots: Dictionary = input._finalize_commit_slots(
		input._build_commit_slots_at_cell(1, Vector2i(3, 2)),
		1,
	)
	if (paired_slots.get("action", []) as Array).is_empty():
		failures.append(
			"PlanningInputTest: awaiting-target skill should pair awaiting action on move hover",
		)
	if not director.commit_from_slots(1, paired_slots):
		failures.append(
			"PlanningInputTest: move+awaiting commit slots should commit to plan",
		)
	if not input.awaiting_targeting_active():
		failures.append(
			"PlanningInputTest: move+awaiting commit should leave awaiting action in plan",
		)
	var awaiting: TimelineAction = director.find_awaiting_action(1)
	if awaiting == null or not awaiting.awaiting_target:
		failures.append(
			"PlanningInputTest: committed awaiting action should be in plan_action",
		)
	var awaiting_label: String = CombatUiFormatters.action_symbol_text(board, awaiting, unit)
	if awaiting_label.find("Awaiting Input") < 0:
		failures.append(
			"PlanningInputTest: awaiting label should include Awaiting Input, got %s"
			% awaiting_label,
		)
	if not awaiting_label.begins_with(PlanningIcons.GLYPH_DASH):
		failures.append(
			"PlanningInputTest: awaiting phase label should start with movement glyph, got %s"
			% awaiting_label,
		)
	var paired_icon: String = input._cursor_icon_from_commit_slots(paired_slots, unit)
	var expected_paired: String = PlanningIcons.join_glyphs([
		PlanningIcons.GLYPH_WALK,
		PlanningIcons.GLYPH_DASH,
	])
	if paired_icon != expected_paired:
		failures.append(
			"PlanningInputTest: move+awaiting hover cursor should composite, got %s expected %s"
			% [paired_icon, expected_paired],
		)
	input.auto_use_skill_after_move = false
	var move_slots_off: Dictionary = input._finalize_commit_slots(
		{
			"pre": [
				TimelineAction.make_move(
					1, Vector2i(3, 2), -1, [], GameEnums.MoveTiming.PRE_ACTION,
				),
			],
			"action": [],
			"post": [],
			"invalid": false,
		},
		1,
	)
	input._on_commit_slots_applied(1, move_slots_off)
	if input.awaiting_targeting_active():
		failures.append(
			"PlanningInputTest: awaiting must not auto-arm when auto skill after move is off",
		)
	director.selected_ability_index = 0
	input.auto_use_skill_after_move = false
	var move_only_slots_off: Dictionary = input._finalize_commit_slots(
		input._build_commit_slots_at_cell(1, Vector2i(3, 2)),
		1,
	)
	if not (move_only_slots_off.get("action", []) as Array).is_empty():
		failures.append(
			"PlanningInputTest: awaiting skill should not pair when auto skill after move is off",
		)
	var heal := AbilityData.new()
	heal.targeting_mode = GameEnums.TargetingMode.SELF
	heal.targeting_flags = AbilityData._targeting_mode_to_flags(heal.targeting_mode)
	unit.active_abilities = [heal]
	director.selected_ability_index = 0
	input.auto_use_skill_after_move = false
	var move_only_slots: Dictionary = input._build_commit_slots_at_cell(1, Vector2i(3, 2))
	if not (move_only_slots.get("action", []) as Array).is_empty():
		failures.append(
			"PlanningInputTest: self skill should not pair on move tile when auto skill after move is off",
		)
	input.auto_use_skill_after_move = true
	var self_paired_slots: Dictionary = input._build_commit_slots_at_cell(1, Vector2i(3, 2))
	if (self_paired_slots.get("action", []) as Array).is_empty():
		failures.append(
			"PlanningInputTest: self skill should pair on move tile when auto skill after move is on",
		)


static func _test_awaiting_plan_refresh(failures: Array[String]) -> void:
	var director := CombatDirector.new()
	var board := BoardState.new()
	board.grid_size = Vector2i(8, 8)
	var plain := TerrainData.new()
	plain.blocks_movement = false
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, plain)
	var unit := UnitState.new()
	unit.id = 1
	unit.team = GameEnums.Team.PLAYER
	unit.position = Vector2i(2, 2)
	unit.movement.points_left = 4
	unit.ability.points_left = 2
	var dash := AbilityData.new()
	dash.kind = GameEnums.AbilityKind.CLASS_SKILL
	dash.display_name = "Bowling Charge"
	var dash_eff := EffectData.new()
	dash_eff.type = GameEnums.EffectType.DASH
	dash_eff.amount = 3
	dash.effects = [dash_eff]
	unit.active_abilities = [dash]
	board.units = [unit]
	GridSystem.set_occupant(board, unit.position, unit.id)
	director.board = board
	director.base_board = board
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.plan_pre_move.entries.append(
		TimelineAction.make_run_move(1, Vector2i(3, 2), -1, [], GameEnums.MoveTiming.PRE_ACTION),
	)
	var combined: Timeline = director.get_player_plan()
	if not director._plan_is_movement_only(combined):
		failures.append(
			"PlanningInputTest: premove-only plan should use movement-only refresh",
		)
	var awaiting_plan := Timeline.new()
	awaiting_plan.add(director.plan_pre_move.entries[0])
	awaiting_plan.add(TimelineAction.make_ability_awaiting(1, dash, Vector2i(2, 2)))
	if not director._plan_is_movement_only(awaiting_plan):
		failures.append(
			"PlanningInputTest: premove + awaiting dash should still use movement-only refresh",
		)


static func _test_dash_arm_survives_plan_refresh(failures: Array[String]) -> void:
	var fixture: Dictionary = _bowling_charge_arm_fixture()
	var input: CombatPlanningInput = fixture["input"] as CombatPlanningInput
	var director: CombatDirector = fixture["director"] as CombatDirector
	var unit: UnitState = fixture["unit"] as UnitState
	var arm_slots: Dictionary = input._final_commit_slots_for_interaction(1, unit.position)
	if not director.commit_from_slots(1, arm_slots):
		failures.append("PlanningInputTest: dash self click should arm through plan refresh")
	if director.find_awaiting_action(1) == null:
		failures.append(
			"PlanningInputTest: awaiting dash must survive sync during _refresh_plan",
		)
	if not input.awaiting_targeting_active():
		failures.append(
			"PlanningInputTest: awaiting_targeting_active should read awaiting plan entry",
		)
	director.flush_plan_refresh_signals_if_pending()
	input.cancel_aim()
	if director.find_awaiting_action(1) == null:
		failures.append(
			"PlanningInputTest: awaiting dash must survive board_changed + cancel_aim",
		)
	if not input.awaiting_targeting_active():
		failures.append(
			"PlanningInputTest: awaiting_targeting_active must survive board_changed refresh",
		)


static func _test_dash_self_click_blocks_false_wait(failures: Array[String]) -> void:
	var fixture: Dictionary = _bowling_charge_arm_fixture()
	var input: CombatPlanningInput = fixture["input"] as CombatPlanningInput
	var director: CombatDirector = fixture["director"] as CombatDirector
	var unit: UnitState = fixture["unit"] as UnitState
	var dash: AbilityData = fixture["dash"] as AbilityData
	if not AbilitySystem.planning_arms_on_self_tile(unit, dash):
		failures.append("PlanningInputTest: bowling charge should arm awaiting flow on self click")
	var dash_slots: Dictionary = input._final_commit_slots_for_interaction(1, unit.position)
	var dash_action: TimelineAction = (dash_slots.get("action", []) as Array)[0] as TimelineAction
	if dash_action == null or not dash_action.awaiting_target:
		failures.append("PlanningInputTest: dash self click must build awaiting slot, not wait")
	if not director.commit_from_slots(1, dash_slots):
		failures.append("PlanningInputTest: dash self click must arm awaiting action")
	if director.unit_has_wait_planned(1):
		failures.append("PlanningInputTest: dash self click must not plan wait")


static func _plain_board_with_unit(
	unit_pos: Vector2i,
	movement_points: int,
	ability_points: int = 3,
) -> Dictionary:
	var plain := TerrainData.new()
	plain.blocks_movement = false
	var board := BoardState.new()
	board.grid_size = Vector2i(10, 6)
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, plain)
	var unit := UnitState.new()
	unit.id = 1
	unit.team = GameEnums.Team.PLAYER
	unit.position = unit_pos
	unit.movement.points_left = movement_points
	unit.movement.max_points = maxi(movement_points, 4)
	unit.ability.points_left = ability_points
	board.units = [unit]
	GridSystem.set_occupant(board, unit_pos, unit.id)
	return {"board": board, "unit": unit}


static func _test_action_range_hidden_after_premove_mp(failures: Array[String]) -> void:
	var setup: Dictionary = _plain_board_with_unit(Vector2i(0, 2), 3)
	var board: BoardState = setup["board"] as BoardState
	var unit: UnitState = setup["unit"] as UnitState
	var swap := AbilityData.new()
	swap.kind = GameEnums.AbilityKind.MOVEMENT_SKILL
	swap.movement_point_cost = 1
	swap.action_point_cost = 0
	swap.targeting_mode = GameEnums.TargetingMode.ALLY_UNIT
	swap.targeting_flags = AbilityData._targeting_mode_to_flags(swap.targeting_mode)
	var swap_eff := EffectData.new()
	swap_eff.type = GameEnums.EffectType.SWAP
	swap.effects = [swap_eff]
	if not AbilitySystem.can_show_planning_action_range_after_premove(
		board, unit, swap, Vector2i(1, 2), false,
	):
		failures.append("PlanningInputTest: near premove should leave enough MP for Swap")
	if AbilitySystem.can_show_planning_action_range_after_premove(
		board, unit, swap, Vector2i(3, 2), false,
	):
		failures.append("PlanningInputTest: far premove should hide Swap when MP exhausted")


static func _test_hover_cursor_matches_click_commit_slots(failures: Array[String]) -> void:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	var board := BoardState.new()
	board.grid_size = Vector2i(8, 8)
	var plain := TerrainData.new()
	plain.blocks_movement = false
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			board.set_tile_terrain(Vector2i(x, y), plain)
	var bash := AbilityData.new()
	bash.kind = GameEnums.AbilityKind.CLASS_SKILL
	bash.action_point_cost = 1
	bash.range_tiles = 1
	bash.effects = [DataLibrary._effect(GameEnums.EffectType.DAMAGE, 1)]
	var knight := UnitState.new()
	knight.id = 1
	knight.team = GameEnums.Team.PLAYER
	knight.position = Vector2i(0, 2)
	knight.movement.points_left = 4
	knight.movement.max_points = 4
	knight.ability.points_left = 1
	knight.ability.max_points = 1
	knight.active_abilities = [bash]
	var enemy := UnitState.new()
	enemy.id = 2
	enemy.team = GameEnums.Team.ENEMY
	enemy.position = Vector2i(4, 2)
	board.units = [knight, enemy]
	GridSystem.set_occupant(board, knight.position, knight.id)
	GridSystem.set_occupant(board, enemy.position, enemy.id)
	director.board = board
	director.base_board = board
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = 1
	director.selected_ability_index = 0
	director.auto_run = true
	input._director = director
	input.auto_use_skill_after_move = true
	input._drag_unit_id = 1
	input._drag_route = [knight.position, Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]
	var enemy_cell := enemy.position
	var click_slots: Dictionary = input._final_commit_slots_for_click_at_cell(1, enemy_cell, Vector2.ZERO)
	var expected_icon: String = input._cursor_icon_from_commit_slots(click_slots, knight)
	var hover_icon: String = input.compute_hover_action_icon(enemy_cell)
	if hover_icon != expected_icon:
		failures.append(
			"PlanningInputTest: hover cursor must match click commit slots (hover=%s click=%s)"
			% [hover_icon, expected_icon],
		)
	if expected_icon.find(PlanningIcons.GLYPH_ATTACK) < 0:
		failures.append(
			"PlanningInputTest: enemy click slots should include attack glyph (got %s)"
			% expected_icon,
		)
	if (
		expected_icon.find(PlanningIcons.GLYPH_RUN) >= 0
		and expected_icon.find(PlanningIcons.GLYPH_ATTACK) < 0
	):
		failures.append(
			"PlanningInputTest: enemy approach must be walk+skill, not run-only (got %s)"
			% expected_icon,
		)


static func _test_enemy_target_params_ignore_pseudo_drag(failures: Array[String]) -> void:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	var board := BoardState.new()
	board.grid_size = Vector2i(8, 8)
	var plain := TerrainData.new()
	plain.blocks_movement = false
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			board.set_tile_terrain(Vector2i(x, y), plain)
	var bash := AbilityData.new()
	bash.kind = GameEnums.AbilityKind.CLASS_SKILL
	bash.action_point_cost = 1
	bash.range_tiles = 1
	bash.effects = [DataLibrary._effect(GameEnums.EffectType.DAMAGE, 1)]
	var knight := UnitState.new()
	knight.id = 1
	knight.team = GameEnums.Team.PLAYER
	knight.position = Vector2i(0, 2)
	knight.movement.points_left = 4
	knight.movement.max_points = 4
	knight.ability.points_left = 1
	knight.ability.max_points = 1
	knight.active_abilities = [bash]
	var enemy := UnitState.new()
	enemy.id = 2
	enemy.team = GameEnums.Team.ENEMY
	enemy.position = Vector2i(4, 2)
	board.units = [knight, enemy]
	GridSystem.set_occupant(board, knight.position, knight.id)
	GridSystem.set_occupant(board, enemy.position, enemy.id)
	director.board = board
	director.base_board = board
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = 1
	director.selected_ability_index = 0
	director.auto_run = true
	input._director = director
	input._drag_unit_id = 1
	input._drag_route = [knight.position, Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]
	input._drag_last_free = Vector2i(3, 2)
	var params: Dictionary = input._commit_interaction_params(enemy.position, enemy.id)
	if not (params.waypoints as Array).is_empty():
		failures.append(
			"PlanningInputTest: unaffordable run+skill must correct enemy params (drop painted route)",
		)
	if params.preferred != enemy.position:
		failures.append(
			"PlanningInputTest: corrected enemy target preferred must be enemy tile (got %s)"
			% str(params.preferred),
		)
	knight.ability.points_left = 2
	knight.ability.max_points = 2
	params = input._commit_interaction_params(enemy.position, enemy.id)
	if (params.waypoints as Array).is_empty():
		failures.append(
			"PlanningInputTest: affordable run+skill should keep painted route on enemy hover",
		)


static func _test_shield_bash_preview_pushes(failures: Array[String]) -> void:
	var director := CombatDirector.new()
	var board := BoardState.new()
	board.grid_size = Vector2i(8, 8)
	var plain := TerrainData.new()
	plain.blocks_movement = false
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			board.set_tile_terrain(Vector2i(x, y), plain)
	var bash := AbilityData.new()
	bash.kind = GameEnums.AbilityKind.CLASS_SKILL
	bash.action_point_cost = 1
	bash.range_tiles = 1
	bash.effects = [
		DataLibrary._effect(GameEnums.EffectType.DAMAGE, 1),
		DataLibrary._effect(GameEnums.EffectType.PUSH, 2),
	]
	var knight := UnitState.new()
	knight.id = 1
	knight.team = GameEnums.Team.PLAYER
	knight.position = Vector2i(1, 2)
	knight.movement.points_left = 4
	knight.movement.max_points = 4
	knight.ability.points_left = 1
	knight.ability.max_points = 1
	knight.active_abilities = [bash]
	var enemy := UnitState.new()
	enemy.id = 2
	enemy.team = GameEnums.Team.ENEMY
	enemy.position = Vector2i(3, 2)
	board.units = [knight, enemy]
	GridSystem.set_occupant(board, knight.position, knight.id)
	GridSystem.set_occupant(board, enemy.position, enemy.id)
	director.board = board
	director.base_board = board
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = 1
	director.selected_ability_index = 0
	var actions: Array[TimelineAction] = [
		TimelineAction.make_ability(
			1, bash, enemy.position, enemy.id, GameEnums.MoveTiming.PRE_ACTION,
		),
	]
	var res: Dictionary = director.preview_actions(1, actions)
	var preview := CombatPlanningPreview.new()
	preview.apply_result(res, director)
	var pushes: Array = preview.preview_pushes.get(enemy.id, [])
	if pushes.is_empty():
		failures.append("PlanningInputTest: Shield Bash preview must populate preview_pushes for target")
	# Approach move + bash: displacement strip must not erase the bash (and its push).
	knight.position = Vector2i(0, 2)
	GridSystem.set_occupant(board, Vector2i(0, 2), knight.id)
	GridSystem.set_occupant(board, Vector2i(3, 2), enemy.id)
	var approach_actions: Array[TimelineAction] = [
		TimelineAction.make_move(
			1,
			Vector2i(2, 2),
			-1,
			[Vector2i(1, 2)],
			GameEnums.MoveTiming.PRE_ACTION,
		),
		TimelineAction.make_ability(
			1, bash, enemy.position, enemy.id, GameEnums.MoveTiming.PRE_ACTION,
		),
	]
	var approach_res: Dictionary = director.preview_actions(1, approach_actions)
	var approach_preview := CombatPlanningPreview.new()
	approach_preview.apply_result(approach_res, director)
	var approach_pushes: Array = approach_preview.preview_pushes.get(enemy.id, [])
	if approach_pushes.is_empty():
		failures.append(
			"PlanningInputTest: approach + Shield Bash preview must keep push arrows (displacement strip)",
		)


static func _test_planning_display_ap_run_intent(failures: Array[String]) -> void:
	var setup: Dictionary = _plain_board_with_unit(Vector2i(0, 2), 0, 2)
	var board: BoardState = setup["board"] as BoardState
	var unit: UnitState = setup["unit"] as UnitState
	var run_tile := Vector2i(5, 2)
	if not AbilitySystem.movement_requires_run(board, unit, run_tile, []):
		failures.append("PlanningInputTest: run-intent AP setup should require run")
	var implicit_ap: int = AbilitySystem.planning_display_ap_left(
		board,
		unit,
		null,
		null,
		false,
		true,
		false,
		true,
		run_tile,
	)
	if implicit_ap != 1:
		failures.append(
			"PlanningInputTest: run intent should show 1 AP left (2 - run), got %d" % implicit_ap,
		)
	var skill := AbilityData.new()
	skill.kind = GameEnums.AbilityKind.CLASS_SKILL
	skill.action_point_cost = 1
	var paired_ap: int = AbilitySystem.planning_display_ap_left(
		board,
		unit,
		skill,
		null,
		false,
		true,
		false,
		true,
		run_tile,
	)
	if paired_ap != 0:
		failures.append(
			"PlanningInputTest: run + skill scroll should show 0 AP left, got %d" % paired_ap,
		)
	var live_unit: UnitState = unit.clone()
	live_unit.ability.points_left = 1
	var live_ap: int = AbilitySystem.planning_display_ap_left(
		board, unit, null, live_unit, true, false, false, false, run_tile,
	)
	if live_ap != 1:
		failures.append(
			"PlanningInputTest: live preview AP should mirror sim board, got %d" % live_ap,
		)


static func _test_planning_display_mp_left(failures: Array[String]) -> void:
	var unit: UnitState = UnitState.new()
	unit.movement.points_left = 1
	unit.movement.max_points = 3
	var live_unit: UnitState = unit.clone()
	live_unit.movement.points_left = -1
	var display_mp: int = AbilitySystem.planning_display_mp_left(unit, live_unit, true)
	if display_mp != 1:
		failures.append(
			"PlanningInputTest: live MP overspend should show committed budget, got %d" % display_mp,
		)
	var committed_only: int = AbilitySystem.planning_display_mp_left(unit, null, false)
	if committed_only != 1:
		failures.append(
			"PlanningInputTest: committed MP display mismatch, got %d" % committed_only,
		)


static func _test_timeline_ghost_slots(failures: Array[String]) -> void:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	var setup: Dictionary = _plain_board_with_unit(Vector2i(2, 2), 4, 2)
	var board: BoardState = setup["board"] as BoardState
	var unit: UnitState = setup["unit"] as UnitState
	director.board = board
	director.base_board = board
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = 1
	input._director = director
	var move := TimelineAction.make_move(
		1, Vector2i(4, 2), -1, [], GameEnums.MoveTiming.PRE_ACTION,
	)
	input._intent_snapshot_valid = true
	input._intent_snapshot_key = "test"
	input._intent_snapshot_slots = {
		"pre": [move],
		"action": [],
		"post": [],
		"invalid": false,
	}
	input.preview_state.preview_board = board.clone()
	var ghost: Dictionary = input.timeline_ghost_slots(1)
	var pre: Array = ghost.get("pre", []) as Array
	if pre.is_empty():
		failures.append("PlanningInputTest: empty plan should show ghost premove")
	if pre.size() != 1 or (pre[0] as TimelineAction).target_coord != Vector2i(4, 2):
		failures.append("PlanningInputTest: ghost premove target mismatch")
	director.get_player_plan().entries.append(move)
	input._intent_snapshot_valid = true
	ghost = input.timeline_ghost_slots(1)
	if not (ghost.get("pre", []) as Array).is_empty():
		failures.append("PlanningInputTest: ghost should clear when intent matches committed plan")


static func _test_committed_action_approach_uses_premove_slot(failures: Array[String]) -> void:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	var board := BoardState.new()
	board.grid_size = Vector2i(10, 6)
	var plain := TerrainData.new()
	plain.blocks_movement = false
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			board.set_tile_terrain(Vector2i(x, y), plain)
	var hook := AbilityData.new()
	hook.kind = GameEnums.AbilityKind.CLASS_SKILL
	hook.action_point_cost = 1
	hook.range_tiles = 3
	hook.targeting_mode = GameEnums.TargetingMode.ENEMY_UNIT
	hook.targeting_flags = AbilityData._targeting_mode_to_flags(hook.targeting_mode)
	hook.effects = [
		DataLibrary._effect(GameEnums.EffectType.DAMAGE, 1),
		DataLibrary._effect(GameEnums.EffectType.PULL, 2),
	]
	var knight := UnitState.new()
	knight.id = 1
	knight.team = GameEnums.Team.PLAYER
	knight.position = Vector2i(1, 3)
	knight.movement.points_left = 4
	knight.movement.max_points = 4
	knight.ability.points_left = 1
	knight.ability.max_points = 1
	knight.active_abilities = [hook]
	var enemy := UnitState.new()
	enemy.id = 2
	enemy.team = GameEnums.Team.ENEMY
	enemy.position = Vector2i(4, 3)
	board.units = [knight, enemy]
	GridSystem.set_occupant(board, knight.position, knight.id)
	GridSystem.set_occupant(board, enemy.position, enemy.id)
	director.board = board
	director.base_board = board
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
	var slots: Dictionary = input._final_commit_slots_for_interaction(
		1, enemy.position, [], [], Vector2i(-999999, -999999),
	)
	var pre: Array = slots.get("pre", []) as Array
	var post: Array = slots.get("post", []) as Array
	if pre.is_empty():
		failures.append(
			"PlanningInputTest: committed action + enemy hover must build pre-move approach",
		)
	if not post.is_empty():
		failures.append(
			"PlanningInputTest: committed action approach must not land in post-move slot",
		)
	var approach_cell: Vector2i = director.preview_approach_tile(
		1, enemy.id, 0, Vector2i(3, 3),
	)
	if approach_cell == knight.position:
		failures.append("PlanningInputTest: chain hook fixture should need an approach tile")
	var approach_slots: Dictionary = input._final_commit_slots_for_interaction(
		1, approach_cell, [], [], Vector2i(-999999, -999999),
	)
	var approach_pre: Array = approach_slots.get("pre", []) as Array
	var approach_post: Array = approach_slots.get("post", []) as Array
	if approach_pre.is_empty():
		failures.append(
			"PlanningInputTest: committed action + approach stand hover must build pre-move",
		)
	if not approach_post.is_empty():
		failures.append(
			"PlanningInputTest: approach stand hover must not use post-move slot",
		)
	# Uncommitted: approach stand must still bucket into pre, never post.
	director.plan_action = Timeline.new()
	director.plan_affected_unit_ids = [1]
	director._refresh_plan()
	var fresh_slots: Dictionary = input._final_commit_slots_for_interaction(
		1, approach_cell, [], [], Vector2i(-999999, -999999),
	)
	if (fresh_slots.get("post", []) as Array).size() > 0:
		failures.append(
			"PlanningInputTest: uncommitted approach hover must not populate post-move",
		)
	if (fresh_slots.get("pre", []) as Array).is_empty():
		failures.append(
			"PlanningInputTest: uncommitted approach hover must populate pre-move",
		)


static func _test_undo_movement_action_preserves_premove(failures: Array[String]) -> void:
	var director := CombatDirector.new()
	var board := BoardState.new()
	board.grid_size = Vector2i(10, 6)
	var plain := TerrainData.new()
	plain.blocks_movement = false
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			board.set_tile_terrain(Vector2i(x, y), plain)
	var trample := AbilityData.new()
	trample.kind = GameEnums.AbilityKind.MOVEMENT_SKILL
	trample.id = &"knight_trampling_advance"
	trample.action_point_cost = 1
	trample.movement_point_cost = 2
	trample.targeting_flags = GameEnums.TargetingFlags.TILE
	var move_eff := EffectData.new()
	move_eff.type = GameEnums.EffectType.MOVE
	move_eff.amount = 2
	trample.effects = [move_eff]
	var knight := UnitState.new()
	knight.id = 1
	knight.team = GameEnums.Team.PLAYER
	knight.position = Vector2i(3, 3)
	knight.movement.points_left = 4
	knight.movement.max_points = 4
	knight.ability.points_left = 1
	knight.ability.max_points = 1
	knight.active_abilities = [trample]
	board.units = [knight]
	GridSystem.set_occupant(board, knight.position, knight.id)
	director.board = board
	director.base_board = board
	director.projected_state = board.clone()
	director.phase = CombatDirector.Phase.PLANNING
	director.selected_unit_id = 1
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
		failures.append("PlanningInputTest: undo should remove movement skill action")
	if director.plan_pre_move.entries.is_empty():
		failures.append(
			"PlanningInputTest: undo movement skill must keep pre-move walk on timeline",
		)


static func _test_ability_scroll_clears_hover_preview_cache(failures: Array[String]) -> void:
	var input := CombatPlanningInput.new()
	var director := CombatDirector.new()
	director.phase = CombatDirector.Phase.PLANNING
	input._director = director
	input._hover_preview_cache_key = "stale|1|ability|0"
	input._on_ability_selected(0)
	if input._hover_preview_cache_key != "":
		failures.append(
			"PlanningInputTest: ability change must invalidate hover preview cache",
		)
