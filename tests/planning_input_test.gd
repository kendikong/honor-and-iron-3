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
	_test_preview_from_commit_slots(failures)
	_test_audit_regression_fixes(failures)
	_test_auto_skill_after_move_arms_dash(failures)
	_test_awaiting_dash_plan_refresh(failures)
	_test_dash_arm_survives_plan_refresh(failures)
	_test_dash_self_click_blocks_false_wait(failures)
	_test_action_range_hidden_after_premove_mp(failures)


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
	if icon != CombatPlanningInput.ICON_RUN:
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
	var expected_paired: String = (
		"%s%s%s"
		% [CombatPlanningInput.ICON_RUN, CombatPlanningInput.ICON_COMPOSITE_SEP, CombatPlanningInput.ICON_DASH]
	)
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
	if move_glyph.find(CombatPlanningInput.ICON_DASH) >= 0:
		failures.append("PlanningInputTest: move glyph must not infer dash from armed skill")


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
	if not input._try_arm_dash_or_self_skill(1):
		failures.append("PlanningInputTest: dash skill self click should arm dash targeting")
	if not input.dash_targeting_active():
		failures.append("PlanningInputTest: try_arm_dash should queue awaiting dash in plan")
	director.selected_ability_index = -1
	if not input._would_show_wait_on_self_click(unit):
		failures.append("PlanningInputTest: empty skill bar should allow wait cursor on self tile")
	director.selected_ability_index = 0
	if input._would_show_wait_on_self_click(unit):
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
	var move_slots: Dictionary = input._finalize_commit_slots(
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
	input._on_commit_slots_applied(1, move_slots)
	if not input.dash_targeting_active():
		failures.append(
			"PlanningInputTest: auto skill after move should arm dash after move-only commit",
		)
	var awaiting: TimelineAction = director.find_awaiting_dash_action(1)
	if awaiting == null or not awaiting.awaiting_target:
		failures.append(
			"PlanningInputTest: armed dash should queue awaiting action in plan_action",
		)
	var awaiting_label: String = CombatUiFormatters.action_symbol_text(board, awaiting, unit)
	if awaiting_label.find("Awaiting Input") < 0:
		failures.append(
			"PlanningInputTest: awaiting dash label should include Awaiting Input, got %s"
			% awaiting_label,
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
	if input.dash_targeting_active():
		failures.append(
			"PlanningInputTest: dash must not auto-arm when auto skill after move is off",
		)
	director.selected_ability_index = 0
	input.auto_use_skill_after_move = true
	var move_only_slots: Dictionary = input._finalize_commit_slots(
		input._build_commit_slots_at_cell(1, Vector2i(3, 2)),
		1,
	)
	var move_only_icon: String = input._cursor_icon_from_commit_slots(move_only_slots, unit)
	if move_only_icon.find(CombatPlanningInput.ICON_DASH) >= 0:
		failures.append(
			"PlanningInputTest: move-only dash hover cursor must not show dash — only what commits",
		)
	var pre_steps: Array = move_only_slots.get("pre", [])
	if pre_steps.is_empty():
		failures.append("PlanningInputTest: dash move hover should build premove slots")
	else:
		var expected_move_icon: String = input._step_cursor_glyph(pre_steps[0] as TimelineAction, unit)
		if move_only_icon != expected_move_icon:
			failures.append(
				"PlanningInputTest: move-only dash cursor should match premove glyph only, got %s expected %s"
				% [move_only_icon, expected_move_icon],
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
	var paired_slots: Dictionary = input._build_commit_slots_at_cell(1, Vector2i(3, 2))
	if (paired_slots.get("action", []) as Array).is_empty():
		failures.append(
			"PlanningInputTest: self skill should pair on move tile when auto skill after move is on",
		)


static func _test_awaiting_dash_plan_refresh(failures: Array[String]) -> void:
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
	if not input._try_arm_dash_or_self_skill(1):
		failures.append("PlanningInputTest: dash self click should arm through plan refresh")
	if director.find_awaiting_dash_action(1) == null:
		failures.append(
			"PlanningInputTest: awaiting dash must survive sync during _refresh_plan",
		)
	if not input.dash_targeting_active():
		failures.append(
			"PlanningInputTest: dash_targeting_active should read awaiting plan entry",
		)
	director.flush_plan_refresh_signals_if_pending()
	input.cancel_aim()
	if director.find_awaiting_dash_action(1) == null:
		failures.append(
			"PlanningInputTest: awaiting dash must survive board_changed + cancel_aim",
		)
	if not input.dash_targeting_active():
		failures.append(
			"PlanningInputTest: dash_targeting_active must survive board_changed refresh",
		)


static func _test_dash_self_click_blocks_false_wait(failures: Array[String]) -> void:
	var fixture: Dictionary = _bowling_charge_arm_fixture()
	var input: CombatPlanningInput = fixture["input"] as CombatPlanningInput
	var director: CombatDirector = fixture["director"] as CombatDirector
	var unit: UnitState = fixture["unit"] as UnitState
	var dash: AbilityData = fixture["dash"] as AbilityData
	if not AbilitySystem.ability_arms_dash_on_self_click(unit, dash):
		failures.append("PlanningInputTest: bowling charge should arm dash on self click")
	if input._try_plan_wait(1):
		failures.append(
			"PlanningInputTest: wait must not trigger when a dash skill is selected",
		)
	if not input._try_arm_dash_or_self_skill(1):
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
