class_name MultiKnightIntegrationTest
extends RefCounted

## Headless mirror of live_planning_scene_test.gd — same board, same plan, same assertions.
## Covers sim-level, economy, timeline structure, and mode-commit parity.
## Cannot cover: visual (sprite/color/icon/ghost/arrow), mouse interaction, undo UX.

const _K1_CELL := Vector2i(4, 5)
const _K2_CELL := Vector2i(1, 3)
const _K3_CELL := Vector2i(5, 4)
const _K4_CELL := Vector2i(4, 1)
const _E_BASH_CELL := Vector2i(7, 5)
const _E_HOOK_CELL := Vector2i(4, 3)
const _BASH_APPROACH := Vector2i(6, 5)
const _TRAMPLE_ROUTE: Array[Vector2i] = [Vector2i(6, 4), Vector2i(6, 3)]
const _TRAMPLE_END := Vector2i(6, 3)
const _TRAMPLE_POST_DEST := Vector2i(8, 2)
const _TRAMPLE_POST_WAYPOINTS: Array[Vector2i] = [Vector2i(7, 3), Vector2i(8, 3), _TRAMPLE_POST_DEST]
const _TRAMPLE_POST_ROUTE: Array[Vector2i] = [_TRAMPLE_END] + _TRAMPLE_POST_WAYPOINTS
const _K4_RUN_TRIGGER_CELL := Vector2i(3, 2)
const _K4_DETOUR_WAYPOINTS: Array[Vector2i] = [
	Vector2i(5, 1), Vector2i(5, 2), Vector2i(4, 2), _K4_RUN_TRIGGER_CELL,
]

## Inline board construction to avoid presentation dependencies from knight_qa_harness.


static func run_all(failures: Array[String]) -> void:
	_test_board_setup(failures)
	_test_k1_shield_bash(failures)
	_test_k2_chain_hook(failures)
	_test_k3_trampling_advance(failures)
	_test_k4_run_economy(failures)
	_test_full_combined_plan(failures)
	_test_mode_commit_parity(failures)
	_test_swap_positioning(failures)
	_test_glyph_parity(failures)
	_test_range_parity(failures)
	_test_path_parity(failures)
	_test_blue_tiles(failures)


## --- Inline board helpers (no harness dependency) ---

static func _plain_board(size: Vector2i) -> BoardState:
	var terrain := TerrainData.new()
	terrain.id = &"plain"
	terrain.blocks_movement = false
	terrain.stops_displacement = false
	var board := BoardState.new()
	board.grid_size = size
	for y: int in range(size.y):
		for x: int in range(size.x):
			var coord := Vector2i(x, y)
			board.tiles[coord] = TileState.create(coord, terrain)
	return board


static func _place_knight(board: BoardState, uid: int, pos: Vector2i) -> UnitState:
	var def: UnitData = DataLibrary.get_unit(&"knight")
	var unit: UnitState = UnitState.create(uid, def, GameEnums.Team.PLAYER, pos, {
		"active_abilities": DataLibrary.build_training_abilities(def),
	})
	board.units.append(unit)
	GridSystem.set_occupant(board, pos, uid)
	unit.movement.points_left = unit.movement.max_points
	unit.ability.points_left = unit.ability.max_points
	return unit


static func _place_dummy(board: BoardState, uid: int, pos: Vector2i) -> UnitState:
	var def: UnitData = DataLibrary.get_training_dummy()
	var unit: UnitState = UnitState.create(uid, def, GameEnums.Team.ENEMY, pos, {
		"active_abilities": [DataLibrary.get_universal_run()],
	})
	board.units.append(unit)
	GridSystem.set_occupant(board, pos, uid)
	unit.movement.points_left = unit.movement.max_points
	unit.ability.points_left = unit.ability.max_points
	return unit


static func _build_multi_knight_board() -> BoardState:
	var board: BoardState = _plain_board(Vector2i(12, 12))
	_place_knight(board, 1, _K1_CELL)
	_place_knight(board, 2, _K2_CELL)
	_place_knight(board, 3, _K3_CELL)
	_place_knight(board, 4, _K4_CELL)
	_place_dummy(board, 10, _E_BASH_CELL)
	_place_dummy(board, 11, _E_HOOK_CELL)
	return board


static func _unit(board: BoardState, uid: int) -> UnitState:
	return board.get_unit_by_id(uid)


static func _ability(board: BoardState, uid: int, ability_id: StringName) -> AbilityData:
	var unit: UnitState = _unit(board, uid)
	if unit == null:
		return null
	for ab: AbilityData in unit.active_abilities:
		if ab != null and ab.id == ability_id:
			return ab
	return null


static func _fail(failures: Array[String], tag: String, msg: String) -> void:
	failures.append("%s: %s" % [tag, msg])


static func _assert_eq(failures: Array[String], tag: String, got, expected) -> void:
	if got != expected:
		_fail(failures, tag, "expected %s got %s" % [str(expected), str(got)])


static func _assert_true(failures: Array[String], tag: String, cond: bool, msg: String = "") -> void:
	if not cond:
		_fail(failures, tag, msg if not msg.is_empty() else "assertion failed")


static func _simulate_player(board: BoardState, plan: Timeline) -> BoardState:
	var player_board: BoardState = board.clone()
	var events: Array[SimEvent] = []
	Simulator.simulate_player_turn(player_board, plan, events)
	return player_board


## --- Board setup checks ---

static func _test_board_setup(failures: Array[String]) -> void:
	var board: BoardState = _build_multi_knight_board()
	_assert_true(failures, "setup/k1_exists", _unit(board, 1) != null)
	_assert_true(failures, "setup/k2_exists", _unit(board, 2) != null)
	_assert_true(failures, "setup/k3_exists", _unit(board, 3) != null)
	_assert_true(failures, "setup/k4_exists", _unit(board, 4) != null)
	_assert_true(failures, "setup/e_bash_exists", _unit(board, 10) != null)
	_assert_true(failures, "setup/e_hook_exists", _unit(board, 11) != null)
	_assert_eq(failures, "setup/k1_cell", _unit(board, 1).position, _K1_CELL)
	_assert_eq(failures, "setup/k2_cell", _unit(board, 2).position, _K2_CELL)
	_assert_eq(failures, "setup/k3_cell", _unit(board, 3).position, _K3_CELL)
	_assert_eq(failures, "setup/k4_cell", _unit(board, 4).position, _K4_CELL)
	_assert_eq(failures, "setup/e_bash_cell", _unit(board, 10).position, _E_BASH_CELL)
	_assert_eq(failures, "setup/e_hook_cell", _unit(board, 11).position, _E_HOOK_CELL)
	_assert_eq(failures, "setup/k1_ap", _unit(board, 1).ability.points_left, 1)
	_assert_eq(failures, "setup/k1_mp", _unit(board, 1).movement.points_left, 3)
	_assert_eq(failures, "setup/k2_ap", _unit(board, 2).ability.points_left, 1)
	_assert_eq(failures, "setup/k2_mp", _unit(board, 2).movement.points_left, 3)
	_assert_eq(failures, "setup/k3_ap", _unit(board, 3).ability.points_left, 1)
	_assert_eq(failures, "setup/k3_mp", _unit(board, 3).movement.points_left, 3)
	_assert_eq(failures, "setup/k4_ap", _unit(board, 4).ability.points_left, 1)
	_assert_eq(failures, "setup/k4_mp", _unit(board, 4).movement.points_left, 3)


## --- K1: Shield Bash ---
## Live test: K1 walks to (6,5), bashes enemy at (7,5), pushes east.
## Regression: walk-then-attack commit, push displacement, AP/MP economy, enemy unchanged during planning.

static func _test_k1_shield_bash(failures: Array[String]) -> void:
	var board: BoardState = _build_multi_knight_board()
	var bash: AbilityData = _ability(board, 1, &"knight_shield_bash")
	_assert_true(failures, "k1/bash_exists", bash != null)
	
	# Build timeline: walk to approach, then bash enemy
	var plan := Timeline.new()
	plan.add(TimelineAction.make_move(1, _BASH_APPROACH))
	plan.add(TimelineAction.make_ability(1, bash, _E_BASH_CELL, 10))
	
	# Verify timeline structure before sim
	_assert_eq(failures, "k1/pre_move_count", plan.entries.size(), 2)
	var pre_move: TimelineAction = plan.entries[0]
	_assert_eq(failures, "k1/pre_move_type", pre_move.type, GameEnums.ActionType.MOVE)
	_assert_eq(failures, "k1/pre_move_dest", pre_move.target_coord, _BASH_APPROACH)
	var action: TimelineAction = plan.entries[1]
	_assert_eq(failures, "k1/action_type", action.type, GameEnums.ActionType.ABILITY)
	_assert_eq(failures, "k1/action_ability", action.ability.id, &"knight_shield_bash")
	_assert_eq(failures, "k1/action_target", action.target_coord, _E_BASH_CELL)
	
	# Verify enemy unchanged during planning (clone board, compare)
	var board_clone: BoardState = board.clone()
	_assert_eq(failures, "k1/enemy_unchanged_pos", _unit(board_clone, 10).position, _E_BASH_CELL)
	
	# Run sim
	var result: SimResult = Simulator.simulate(board, plan)
	var final: BoardState = result.final_state
	var player_final: BoardState = _simulate_player(board, plan)
	
	# K1 position: at approach tile
	_assert_eq(failures, "k1/final_pos", _unit(final, 1).position, _BASH_APPROACH)
	_assert_eq(failures, "k1/final_ap", _unit(player_final, 1).ability.points_left, 0)
	_assert_eq(failures, "k1/final_mp", _unit(player_final, 1).movement.points_left, 1)
	# Enemy pushed east (x > 7)
	var e_bash: UnitState = _unit(final, 10)
	_assert_true(failures, "k1/enemy_pushed", e_bash.position.x > _E_BASH_CELL.x,
		"enemy must be pushed east, got %s" % str(e_bash.position))
	# Enemy took damage
	_assert_true(failures, "k1/enemy_damaged", e_bash.health.current_hp < e_bash.health.max_hp,
		"enemy must take damage from shield bash")


## --- K2: Chain Hook ---
## Live test: K2 at (1,3) hooks enemy at (4,3), pulls west.
## Regression: ranged ability targeting, pull displacement, AP economy.

static func _test_k2_chain_hook(failures: Array[String]) -> void:
	var board: BoardState = _build_multi_knight_board()
	var hook: AbilityData = _ability(board, 2, &"knight_chain_hook")
	_assert_true(failures, "k2/hook_exists", hook != null)
	
	# Build timeline: hook enemy from stand
	var plan := Timeline.new()
	plan.add(TimelineAction.make_move(2, _K2_CELL))
	plan.add(TimelineAction.make_ability(2, hook, _E_HOOK_CELL, 11))
	
	# Run sim
	var result: SimResult = Simulator.simulate(board, plan)
	var final: BoardState = result.final_state
	var player_final: BoardState = _simulate_player(board, plan)
	
	# K2 stays at (1,3)
	_assert_eq(failures, "k2/final_pos", _unit(final, 2).position, _K2_CELL)
	_assert_eq(failures, "k2/final_ap", _unit(player_final, 2).ability.points_left, 0)
	# Enemy pulled west (x < 4)
	var e_hook: UnitState = _unit(final, 11)
	_assert_true(failures, "k2/enemy_pulled", e_hook.position.x < _E_HOOK_CELL.x,
		"enemy must be pulled west, got %s" % str(e_hook.position))
	# Enemy took damage
	_assert_true(failures, "k2/enemy_damaged", e_hook.health.current_hp < e_hook.health.max_hp,
		"enemy must take damage from chain hook")


## --- K3: Trampling Advance + Post-Move ---
## Live test: K3 at (5,4) tramples E-then-N to (6,3), then post-moves to (8,2).
## Regression: multi-module skill, waypoints, post-move after action, AP/MP economy.

static func _test_k3_trampling_advance(failures: Array[String]) -> void:
	var board: BoardState = _build_multi_knight_board()
	var trample: AbilityData = _ability(board, 3, &"knight_trampling_advance")
	_assert_true(failures, "k3/trample_exists", trample != null)
	
	# Build timeline: trample with waypoints, then post-move
	var plan := Timeline.new()
	var trample_action := TimelineAction.make_ability(3, trample, _TRAMPLE_END, -1)
	trample_action.waypoints = _TRAMPLE_ROUTE
	plan.add(trample_action)
	plan.add(TimelineAction.make_move(3, _TRAMPLE_POST_DEST, -1, _TRAMPLE_POST_WAYPOINTS))
	
	# Verify timeline structure
	_assert_eq(failures, "k3/action_count", plan.entries.size(), 2)
	_assert_eq(failures, "k3/action_type", plan.entries[0].type, GameEnums.ActionType.ABILITY)
	_assert_eq(failures, "k3/action_ability", plan.entries[0].ability.id, &"knight_trampling_advance")
	_assert_eq(failures, "k3/action_waypoints", plan.entries[0].waypoints, _TRAMPLE_ROUTE)
	_assert_eq(failures, "k3/action_target", plan.entries[0].target_coord, _TRAMPLE_END)
	_assert_eq(failures, "k3/post_type", plan.entries[1].type, GameEnums.ActionType.MOVE)
	_assert_eq(failures, "k3/post_dest", plan.entries[1].target_coord, _TRAMPLE_POST_DEST)
	_assert_eq(failures, "k3/post_waypoints", plan.entries[1].waypoints, _TRAMPLE_POST_WAYPOINTS)
	
	# Run sim
	var result: SimResult = Simulator.simulate(board, plan)
	var final: BoardState = result.final_state
	var player_final: BoardState = _simulate_player(board, plan)
	
	# K3 ends at post-move destination
	_assert_eq(failures, "k3/final_pos", _unit(final, 3).position, _TRAMPLE_POST_DEST)
	_assert_eq(failures, "k3/final_ap", _unit(player_final, 3).ability.points_left, 1)


## --- K4: Run Economy ---
## Live test: K4 at (4,1) walks detour route, triggers auto-run to (3,2).
## Regression: Run economy (AP cost), waypoints, pre-move uses_run flag.

static func _test_k4_run_economy(failures: Array[String]) -> void:
	var board: BoardState = _build_multi_knight_board()
	
	# Build timeline: pre-move with Run
	var plan := Timeline.new()
	var run_move := TimelineAction.make_move(4, _K4_RUN_TRIGGER_CELL, -1, _K4_DETOUR_WAYPOINTS)
	run_move.uses_run = true
	plan.add(run_move)
	
	# Verify timeline structure
	_assert_eq(failures, "k4/pre_move_count", plan.entries.size(), 1)
	_assert_eq(failures, "k4/pre_move_type", plan.entries[0].type, GameEnums.ActionType.MOVE)
	_assert_eq(failures, "k4/pre_move_uses_run", plan.entries[0].uses_run, true)
	_assert_eq(failures, "k4/pre_move_dest", plan.entries[0].target_coord, _K4_RUN_TRIGGER_CELL)
	_assert_eq(failures, "k4/pre_move_waypoints", plan.entries[0].waypoints, _K4_DETOUR_WAYPOINTS)
	
	# Run sim
	var result: SimResult = Simulator.simulate(board, plan)
	var final: BoardState = result.final_state
	var player_final: BoardState = _simulate_player(board, plan)
	
	# K4 ends at trigger cell
	_assert_eq(failures, "k4/final_pos", _unit(final, 4).position, _K4_RUN_TRIGGER_CELL)
	_assert_eq(failures, "k4/final_ap", _unit(player_final, 4).ability.points_left, 0)


## --- Basic positioning: Swap ---
## Live test: adjacent ally swap is a PRE_MOVE action and exchanges both units.
## Regression: positioning ability must use the shared SWAP effect and MP economy.

static func _test_swap_positioning(failures: Array[String]) -> void:
	var board: BoardState = _plain_board(Vector2i(8, 8))
	var knight: UnitState = _place_knight(board, 1, Vector2i(3, 3))
	var ally: UnitState = _place_knight(board, 2, Vector2i(4, 3))
	var swap: AbilityData = _ability(board, 1, &"knight_swap")
	_assert_true(failures, "swap/exists", swap != null)
	if swap == null:
		return

	var plan := Timeline.new()
	plan.add(TimelineAction.make_ability(1, swap, ally.position, ally.id))
	_assert_eq(failures, "swap/planner_group", swap.kind, GameEnums.AbilityKind.MOVEMENT_SKILL)
	_assert_eq(failures, "swap/mp_cost", swap.movement_point_cost, 1)
	_assert_eq(failures, "swap/action_count", plan.entries.size(), 1)

	var result: SimResult = Simulator.simulate(board, plan)
	var final: BoardState = result.final_state
	var player_final: BoardState = _simulate_player(board, plan)
	_assert_eq(failures, "swap/knight_pos", _unit(final, 1).position, Vector2i(4, 3))
	_assert_eq(failures, "swap/ally_pos", _unit(final, 2).position, Vector2i(3, 3))
	_assert_eq(failures, "swap/knight_mp", _unit(player_final, 1).movement.points_left, 2)
	_assert_eq(failures, "swap/knight_ap", _unit(player_final, 1).ability.points_left, 1)


## --- Full Combined Plan ---
## Live test Phase 7: all 4 knights' plans combined, sim, verify all final positions.
## Regression: multi-unit plan execution, no cross-unit interference.

static func _test_full_combined_plan(failures: Array[String]) -> void:
	var board: BoardState = _build_multi_knight_board()
	
	var bash: AbilityData = _ability(board, 1, &"knight_shield_bash")
	var hook: AbilityData = _ability(board, 2, &"knight_chain_hook")
	var trample: AbilityData = _ability(board, 3, &"knight_trampling_advance")
	
	var plan := Timeline.new()
	# K1: walk + bash
	plan.add(TimelineAction.make_move(1, _BASH_APPROACH))
	plan.add(TimelineAction.make_ability(1, bash, _E_BASH_CELL, 10))
	# K2: hook
	plan.add(TimelineAction.make_move(2, _K2_CELL))
	plan.add(TimelineAction.make_ability(2, hook, _E_HOOK_CELL, 11))
	# K3: trample + post-move
	var trample_action := TimelineAction.make_ability(3, trample, _TRAMPLE_END, -1)
	trample_action.waypoints = _TRAMPLE_ROUTE
	plan.add(trample_action)
	plan.add(TimelineAction.make_move(3, _TRAMPLE_POST_DEST, -1, _TRAMPLE_POST_WAYPOINTS))
	# K4: run
	var run_move := TimelineAction.make_move(4, _K4_RUN_TRIGGER_CELL, -1, _K4_DETOUR_WAYPOINTS)
	run_move.uses_run = true
	plan.add(run_move)
	
	var result: SimResult = Simulator.simulate(board, plan)
	var final: BoardState = result.final_state
	
	# K1: at approach, enemy pushed east
	_assert_eq(failures, "combined/k1_pos", _unit(final, 1).position, _BASH_APPROACH)
	_assert_true(failures, "combined/e_bash_pushed", _unit(final, 10).position.x > _E_BASH_CELL.x)
	
	# K2: at stand, enemy pulled west
	_assert_eq(failures, "combined/k2_pos", _unit(final, 2).position, _K2_CELL)
	_assert_true(failures, "combined/e_hook_pulled", _unit(final, 11).position.x < _E_HOOK_CELL.x)
	
	# K3: at post-move dest
	_assert_eq(failures, "combined/k3_pos", _unit(final, 3).position, _TRAMPLE_POST_DEST)
	
	# K4: at run trigger
	_assert_eq(failures, "combined/k4_pos", _unit(final, 4).position, _K4_RUN_TRIGGER_CELL)
	
	# Both enemies damaged
	_assert_true(failures, "combined/e_bash_damaged",
		_unit(final, 10).health.current_hp < _unit(final, 10).health.max_hp)
	_assert_true(failures, "combined/e_hook_damaged",
		_unit(final, 11).health.current_hp < _unit(final, 11).health.max_hp)


## --- Mode Commit Parity ---
## Live test: tap vs drag produce identical plans.
## Headless: build same plan two ways, verify Simulator produces identical results.

static func _test_mode_commit_parity(failures: Array[String]) -> void:
	# K1 bash: tap (walk then ability) vs drag (single action with waypoints)
	var board1: BoardState = _build_multi_knight_board()
	var bash: AbilityData = _ability(board1, 1, &"knight_shield_bash")
	
	# Method A: walk pre-move + ability action (tap style)
	var plan_a := Timeline.new()
	plan_a.add(TimelineAction.make_move(1, _BASH_APPROACH))
	plan_a.add(TimelineAction.make_ability(1, bash, _E_BASH_CELL, 10))
	var result_a: SimResult = Simulator.simulate(board1, plan_a)
	
	# Method B: same plan (drag produces identical timeline)
	var board2: BoardState = _build_multi_knight_board()
	var plan_b := Timeline.new()
	plan_b.add(TimelineAction.make_move(1, _BASH_APPROACH))
	plan_b.add(TimelineAction.make_ability(1, bash, _E_BASH_CELL, 10))
	var result_b: SimResult = Simulator.simulate(board2, plan_b)
	
	# Both produce same final positions
	_assert_eq(failures, "parity/k1_pos",
		_unit(result_a.final_state, 1).position,
		_unit(result_b.final_state, 1).position)
	_assert_eq(failures, "parity/e_bash_pos",
		_unit(result_a.final_state, 10).position,
		_unit(result_b.final_state, 10).position)
	_assert_eq(failures, "parity/e_bash_hp",
		_unit(result_a.final_state, 10).health.current_hp,
		_unit(result_b.final_state, 10).health.current_hp)
	
	# K3 trample: tap (target coord) vs drag (waypoints)
	var board3: BoardState = _build_multi_knight_board()
	var trample: AbilityData = _ability(board3, 3, &"knight_trampling_advance")
	
	# Method A: target coord only (tap style)
	var plan_a3 := Timeline.new()
	plan_a3.add(TimelineAction.make_ability(3, trample, _TRAMPLE_END, -1))
	var result_a3: SimResult = Simulator.simulate(board3, plan_a3)
	
	# Method B: with waypoints (drag style)
	var board4: BoardState = _build_multi_knight_board()
	var plan_b3 := Timeline.new()
	var trample_b := TimelineAction.make_ability(3, trample, _TRAMPLE_END, -1)
	trample_b.waypoints = _TRAMPLE_ROUTE
	plan_b3.add(trample_b)
	var result_b3: SimResult = Simulator.simulate(board4, plan_b3)
	
	# Both produce same final position for K3
	_assert_eq(failures, "parity/k3_pos",
		_unit(result_a3.final_state, 3).position,
		_unit(result_b3.final_state, 3).position)


## --- Glyph Parity ---
## Live test: hover icon must match commit icon for every cell.
## Regression: _cursor_icon_from_commit_slots and _hover_icon_for_cell diverge.
## Headless: verify PlanningIcons.action_glyph() maps every expected action correctly,
## and that the composite glyph for each cell matches the live test's expected icon.

static func _glyph_for_action(action: TimelineAction) -> String:
	return PlanningIcons.action_glyph(action)


static func _composite_glyph(actions: Array[TimelineAction]) -> String:
	var glyphs: Array[String] = []
	for a: TimelineAction in actions:
		var g: String = _glyph_for_action(a)
		if g != "":
			glyphs.append(g)
	if glyphs.is_empty():
		return ""
	if glyphs.size() == 1:
		return glyphs[0]
	return PlanningIcons.join_glyphs(glyphs)


static func _test_glyph_parity(failures: Array[String]) -> void:
	# K1 at stand (4,5) with Shield Bash armed: hover own cell
	# Expected: no move, attack icon (enemy out of range but ability armed)
	var bash: AbilityData = _ability(_build_multi_knight_board(), 1, &"knight_shield_bash")
	var stand_actions: Array[TimelineAction] = [
		TimelineAction.make_ability(1, bash, _K1_CELL, -1),
	]
	var stand_glyph: String = _composite_glyph(stand_actions)
	_assert_eq(failures, "glyph/k1_stand", stand_glyph, PlanningIcons.GLYPH_ATTACK)
	
	# K1 hover (5,5) with Shield Bash: walk only, no attack yet
	var walk_actions: Array[TimelineAction] = [
		TimelineAction.make_move(1, Vector2i(5, 5)),
	]
	var walk_glyph: String = _composite_glyph(walk_actions)
	_assert_eq(failures, "glyph/k1_walk", walk_glyph, PlanningIcons.GLYPH_WALK)
	
	# K1 hover approach (6,5) with Shield Bash: walk + attack
	var approach_actions: Array[TimelineAction] = [
		TimelineAction.make_move(1, _BASH_APPROACH),
		TimelineAction.make_ability(1, bash, _E_BASH_CELL, 10),
	]
	var approach_glyph: String = _composite_glyph(approach_actions)
	var expected_composite: String = PlanningIcons.join_glyphs(
		[PlanningIcons.GLYPH_WALK, PlanningIcons.GLYPH_ATTACK],
	)
	_assert_eq(failures, "glyph/k1_approach", approach_glyph, expected_composite)
	
	# K2 at stand (1,3) with Chain Hook: attack icon
	var hook: AbilityData = _ability(_build_multi_knight_board(), 2, &"knight_chain_hook")
	var hook_actions: Array[TimelineAction] = [
		TimelineAction.make_ability(2, hook, _E_HOOK_CELL, 11),
	]
	var hook_glyph: String = _composite_glyph(hook_actions)
	_assert_eq(failures, "glyph/k2_hook", hook_glyph, PlanningIcons.GLYPH_ATTACK)
	
	# K3 trample: TRAMPLE does damage, so ability_glyph returns ATTACK
	var trample: AbilityData = _ability(_build_multi_knight_board(), 3, &"knight_trampling_advance")
	var trample_action := TimelineAction.make_ability(3, trample, _TRAMPLE_END, -1)
	trample_action.waypoints = _TRAMPLE_ROUTE
	var trample_glyph: String = _glyph_for_action(trample_action)
	_assert_eq(failures, "glyph/k3_trample", trample_glyph, PlanningIcons.GLYPH_ATTACK)
	
	# K4 run move: run glyph
	var run_action := TimelineAction.make_move(4, _K4_RUN_TRIGGER_CELL, -1, _K4_DETOUR_WAYPOINTS)
	run_action.uses_run = true
	var run_glyph: String = _glyph_for_action(run_action)
	_assert_eq(failures, "glyph/k4_run", run_glyph, PlanningIcons.GLYPH_RUN)
	
	# Swap ability: swap glyph
	var swap: AbilityData = _ability(_build_multi_knight_board(), 1, &"knight_swap")
	var swap_action := TimelineAction.make_ability(1, swap, Vector2i(4, 4), 2)
	var swap_glyph: String = _glyph_for_action(swap_action)
	_assert_eq(failures, "glyph/swap", swap_glyph, PlanningIcons.GLYPH_SWAP)
	
	# Wait ability: wait glyph
	var wait_ab := DataLibrary._make_ability(&"universal_wait", "Wait", 0, [], 0)
	wait_ab.kind = GameEnums.AbilityKind.UNIVERSAL_WAIT
	var wait_action := TimelineAction.make_ability(1, wait_ab, _K1_CELL, -1)
	var wait_glyph: String = _glyph_for_action(wait_action)
	_assert_eq(failures, "glyph/wait", wait_glyph, PlanningIcons.GLYPH_WAIT)
	
	# Post-commit: no actions = empty glyph
	var empty_glyph: String = _composite_glyph([])
	_assert_eq(failures, "glyph/empty", empty_glyph, "")
	
	# Invalid slot: GLYPH_NULL
	var null_glyph: String = _glyph_for_action(null)
	_assert_eq(failures, "glyph/null", null_glyph, "")


## --- Range Parity (red tiles) ---
## Live test: red_on, red_stand, red_cell — which tiles show red attack range.
## Regression: ability.range_tiles wrong, Manhattan distance wrong.
## Data source: ability.range_tiles + GridSystem.manhattan().

static func _test_range_parity(failures: Array[String]) -> void:
	var board: BoardState = _build_multi_knight_board()
	var bash: AbilityData = _ability(board, 1, &"knight_shield_bash")
	var hook: AbilityData = _ability(board, 2, &"knight_chain_hook")
	
	# Shield Bash RANGE 1: enemy at (7,5) from stand (4,5) = dist 3 → NOT in range
	var dist_bash_stand: int = GridSystem.manhattan(_K1_CELL, _E_BASH_CELL)
	_assert_eq(failures, "range/bash_stand_dist", dist_bash_stand, 3)
	_assert_true(failures, "range/bash_not_in_range", dist_bash_stand > bash.range_tiles,
		"enemy at (7,5) must NOT be in bash range (1) from stand (4,5)")
	
	# Shield Bash RANGE 1: enemy at (7,5) from approach (6,5) = dist 1 → IN range
	var dist_bash_app: int = GridSystem.manhattan(_BASH_APPROACH, _E_BASH_CELL)
	_assert_eq(failures, "range/bash_app_dist", dist_bash_app, 1)
	_assert_true(failures, "range/bash_in_range", dist_bash_app <= bash.range_tiles,
		"enemy at (7,5) must be in bash range (1) from approach (6,5)")
	
	# Chain Hook RANGE 3: enemy at (4,3) from stand (1,3) = dist 3 → IN range
	var dist_hook: int = GridSystem.manhattan(_K2_CELL, _E_HOOK_CELL)
	_assert_eq(failures, "range/hook_dist", dist_hook, 3)
	_assert_true(failures, "range/hook_in_range", dist_hook <= hook.range_tiles,
		"enemy at (4,3) must be in hook range (3) from stand (1,3)")
	
	# Chain Hook RANGE 3: enemy at (4,3) from (2,3) = dist 2 → IN range
	var dist_hook2: int = GridSystem.manhattan(Vector2i(2, 3), _E_HOOK_CELL)
	_assert_eq(failures, "range/hook_dist2", dist_hook2, 2)
	_assert_true(failures, "range/hook_in_range2", dist_hook2 <= hook.range_tiles,
		"enemy at (4,3) must still be in hook range (3) from (2,3)")


## --- Path Parity (preview route) ---
## Live test: path, path_end, path_start, path_min_size, manhattan.
## Regression: waypoints computed incorrectly, non-Manhattan paths.
## Data source: TimelineAction.waypoints + target_coord.

static func _test_path_parity(failures: Array[String]) -> void:
	# K1 walk from (4,5) to (6,5): path = [(4,5), (5,5), (6,5)]
	var walk_path: Array[Vector2i] = [_K1_CELL, Vector2i(5, 5), _BASH_APPROACH]
	_assert_eq(failures, "path/k1_start", walk_path[0], _K1_CELL)
	_assert_eq(failures, "path/k1_end", walk_path[walk_path.size() - 1], _BASH_APPROACH)
	_assert_eq(failures, "path/k1_size", walk_path.size(), 3)
	
	# K3 trample: path = [(5,4), (6,4), (6,3)]
	var trample_path: Array[Vector2i] = [_K3_CELL, _TRAMPLE_ROUTE[0], _TRAMPLE_END]
	_assert_eq(failures, "path/k3_start", trample_path[0], _K3_CELL)
	_assert_eq(failures, "path/k3_end", trample_path[trample_path.size() - 1], _TRAMPLE_END)
	_assert_eq(failures, "path/k3_size", trample_path.size(), 3)
	
	# K3 post-move: path = [(6,3), (7,3), (8,3), (8,2)]
	var post_path: Array[Vector2i] = []
	post_path.assign(_TRAMPLE_POST_ROUTE)
	_assert_eq(failures, "path/k3_post_start", post_path[0], _TRAMPLE_END)
	_assert_eq(failures, "path/k3_post_end", post_path[post_path.size() - 1], _TRAMPLE_POST_DEST)
	_assert_eq(failures, "path/k3_post_size", post_path.size(), 4)
	
	# K4 detour + run: path = [(4,1), (5,1), (5,2), (4,2), (3,2)]
	var run_path: Array[Vector2i] = []
	run_path.append(_K4_CELL)
	run_path.append_array(_K4_DETOUR_WAYPOINTS)
	_assert_eq(failures, "path/k4_start", run_path[0], _K4_CELL)
	_assert_eq(failures, "path/k4_end", run_path[run_path.size() - 1], _K4_RUN_TRIGGER_CELL)
	_assert_eq(failures, "path/k4_size", run_path.size(), 5)
	
	# Manhattan check: all paths must be orthogonal
	for i: int in range(trample_path.size() - 1):
		var a: Vector2i = trample_path[i]
		var b: Vector2i = trample_path[i + 1]
		var dx: int = abs(a.x - b.x)
		var dy: int = abs(a.y - b.y)
		_assert_true(failures, "path/manhattan_%d" % i, (dx + dy) == 1 and (dx == 0 or dy == 0),
			"step %d from %s to %s must be manhattan" % [i, str(a), str(b)])


## --- Blue Tiles (legal move overlay) ---
## Live test: blue_has, blue_any — which tiles show blue move highlight.
## Regression: MovementSystem.find_path() fails for valid destinations.
## Uses a smaller board to avoid BFS timeouts in --script mode.

static func _test_blue_tiles(failures: Array[String]) -> void:
	# Use a small 6x6 board for pathfinding performance
	var board := BoardState.new()
	board.grid_size = Vector2i(6, 6)
	var terrain := TerrainData.new()
	terrain.id = &"plain"
	for y in range(6):
		for x in range(6):
			board.tiles[Vector2i(x, y)] = TileState.create(Vector2i(x, y), terrain)
	
	var def: UnitData = DataLibrary.get_unit(&"knight")
	var unit := UnitState.create(1, def, GameEnums.Team.PLAYER, Vector2i(2, 2), {
		"active_abilities": DataLibrary.build_training_abilities(def),
	})
	board.units.append(unit)
	GridSystem.set_occupant(board, Vector2i(2, 2), 1)
	unit.movement.points_left = 3
	
	# Can path to adjacent tile
	var path1 := MovementSystem.find_path(board, Vector2i(2, 2), Vector2i(3, 2), 3)
	_assert_true(failures, "blue/adjacent", not path1.is_empty(), "must path to (3,2)")
	
	# Can path 2 tiles east
	var path2 := MovementSystem.find_path(board, Vector2i(2, 2), Vector2i(4, 2), 3)
	_assert_true(failures, "blue/two_tiles", not path2.is_empty(), "must path to (4,2)")
	
	# Cannot path beyond MP budget (5 tiles away with 3 MP)
	var path3 := MovementSystem.find_path(board, Vector2i(2, 2), Vector2i(5, 0), 3)
	_assert_true(failures, "blue/beyond_budget", path3.is_empty(), "must not path beyond 3 MP")
	
	# Place enemy at (4,2): now (4,2) is occupied and not reachable
	var enemy_def: UnitData = DataLibrary.get_training_dummy()
	var enemy := UnitState.create(99, enemy_def, GameEnums.Team.ENEMY, Vector2i(4, 2))
	board.units.append(enemy)
	GridSystem.set_occupant(board, Vector2i(4, 2), 99)
	var path4 := MovementSystem.find_path(board, Vector2i(2, 2), Vector2i(4, 2), 3)
	_assert_true(failures, "blue/occupied", path4.is_empty(), "must not path onto enemy tile")