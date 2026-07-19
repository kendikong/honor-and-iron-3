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
	_test_action_range_hidden_after_premove_mp(failures)


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
