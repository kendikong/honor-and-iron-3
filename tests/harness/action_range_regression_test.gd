class_name ActionRangeRegressionTest
extends RefCounted

## Regression matrix — red action-range tiles (owner bugs from manual QA).
## Permanent failure log: docs/design/ACTION_RANGE_LATEST_STAND.md
## Rule: .cursor/rules/action-range-latest-stand.mdc
##
## Contract (every case asserts as many layers as apply):
##   1. action_range_visible_for_hover() matches expect_show
##   2. action_range_intent_stand_cell() matches expect_stand when set
##   3. Overlay draws red tiles anchored on stand (not stale knight origin)
##   4. visibility gate parity: expect_show == overlay has any red tile
##
## Rule under test: red follows cursor stand; hide only when skill impossible after premove.

const KNIGHT_START := Vector2i(4, 5)
const ENEMY_POS := Vector2i(7, 5)
const BASH_APPROACH := Vector2i(6, 5)
const SHIELD_BASH_ID: StringName = &"knight_shield_bash"
const BOWLING_CHARGE_ID: StringName = &"knight_bowling_charge"
const TRAMPLE_ID: StringName = &"knight_trampling_advance"


## =============================================================================
## NOTE / MANDATE ON SWAP TESTS:
## Swap tests are isolated from the general regression run by default.
## Do NOT run swap tests in general regression suites unless specifically fixing
## swap mechanics. Use `run_swap_tests()` or `include_swap = true` when actively
## working on swap. Dedicated swap suite: `scripts/qa/run_swap_planning_acceptance.ps1`.
## =============================================================================

static func run_all(failures: Array[String], include_swap: bool = false) -> void:
	var tests: Array[Callable] = [
		_test_show_move_hover_without_action_slot,
		_test_show_enemy_bash_with_committed_premove,
		_test_show_red_anchor_follows_stand_not_knight_start,
		_test_bowling_enemy_hover_red_at_origin,
		_test_bowling_enemy_hover_not_bash_route,
		_test_bowling_empty_dash_line_remains_premove,
		_test_bowling_dash_only_click_no_premove,
		_test_bowling_awaiting_occupied_end,
		_test_hide_red_after_commit_run_icon_shield_bash,
		_test_hide_red_after_commit_run_icon_bowling,
		_test_hide_red_committed_run_timeline_bowling,
		_test_hide_red_committed_run_interior_hover_bowling,
		_test_hide_no_ability_selected,
		_test_show_awaiting_trample,
		_test_awaiting_module_range_after_committed_premove,
		_test_hover_step_updates_stand_and_red_tiles,
		_test_visibility_gate_parity_show,
		_test_visibility_gate_parity_hide,
		_test_shield_bash_off_map_hover,
		_test_premove_intent_legs_no_boomerang,
	]
	var names: PackedStringArray = [
		"show_move_hover_no_action_slot",
		"show_enemy_bash_committed_premove",
		"show_red_anchor_on_stand",
		"bowling_enemy_hover_red",
		"bowling_enemy_hover_not_bash",
		"bowling_empty_dash_line",
		"bowling_dash_only_no_premove_click",
		"bowling_awaiting_occupied_end",
		"hide_after_commit_run_icon_bash",
		"hide_after_commit_run_icon_bowling",
		"hide_committed_run_timeline_bowling",
		"hide_committed_run_interior_hover_bowling",
		"hide_no_ability",
		"show_awaiting_trample",
		"awaiting_module_range_after_premove",
		"hover_step_updates_stand",
		"parity_gate_show",
		"parity_gate_hide",
		"shield_bash_off_map_hover",
		"premove_no_boomerang",
	]
	if include_swap:
		tests.append(_test_post_swap_post_move_stand_locked_on_orbit)
		names.append("post_swap_post_move_stand_locked")
		tests.append(_test_premove_swap_committed_orbit_walk_intent)
		names.append("premove_swap_committed_orbit_walk")
	else:
		print("[SKIP] action_range/swap tests skipped by default (run only when specifically fixing swap: use run_swap_tests() or include_swap=true)")
	for i: int in range(tests.size()):
		print("[RUN] action_range/%s" % names[i])
		tests[i].call(failures)
		PlanningDragE2EHarness.cleanup_all()


## Dedicated runner for swap tests — run ONLY when specifically debugging or fixing swap.
static func run_swap_tests(failures: Array[String]) -> void:
	print("[RUN] action_range/post_swap_post_move_stand_locked")
	_test_post_swap_post_move_stand_locked_on_orbit(failures)
	PlanningDragE2EHarness.cleanup_all()
	print("[RUN] action_range/premove_swap_committed_orbit_walk")
	_test_premove_swap_committed_orbit_walk_intent(failures)
	PlanningDragE2EHarness.cleanup_all()


static func _fixture_unit(fix: Dictionary) -> UnitState:
	if fix.has("knight"):
		return fix.knight as UnitState
	return fix.get("unit", null) as UnitState


static func _hover_sync(
	input: CombatPlanningInput,
	overlay: TacticalPlanningOverlay,
	cell: Vector2i,
) -> void:
	input.set_qa_pointer_grid_cell(cell)
	input.on_hover_moved(cell)
	input._flush_hover_heavy_sync()
	overlay._recompute_hover_ranges_from_inputs()


## Enemy / skill hover parity with F5 + Tier 3 live probes (refresh interaction preview).
static func _attack_hover_sync(
	input: CombatPlanningInput,
	overlay: TacticalPlanningOverlay,
	cell: Vector2i,
) -> void:
	input.set_qa_pointer_grid_cell(cell)
	input.on_hover_moved(cell)
	input._flush_hover_heavy_sync()
	input.call("_refresh_selected_interaction_preview")
	overlay._recompute_hover_ranges_from_inputs()


static func _overlay_has_any_red(overlay: TacticalPlanningOverlay, board: BoardState) -> bool:
	if board == null:
		return false
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			if overlay.is_hover_action_range_tile(Vector2i(x, y)):
				return true
	return false


static func _collect_overlay_red_tiles(overlay: TacticalPlanningOverlay, board: BoardState) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if board == null:
		return out
	for y: int in range(board.grid_size.y):
		for x: int in range(board.grid_size.x):
			var coord := Vector2i(x, y)
			if overlay.is_hover_action_range_tile(coord):
				out.append(coord)
	return out


static func _refresh_planning_now(fix: Dictionary) -> void:
	var overlay: TacticalPlanningOverlay = fix.get("overlay", null) as TacticalPlanningOverlay
	var input: CombatPlanningInput = fix.input
	if input != null:
		input.refresh_planning_now()
	if overlay != null:
		overlay._recompute_hover_ranges_from_inputs()


static func _assert_contract(
	failures: Array[String],
	label: String,
	fix: Dictionary,
	overlay: TacticalPlanningOverlay,
	input: CombatPlanningInput,
	hover: Vector2i,
	ability: AbilityData,
	expect_show: bool,
	expect_stand: Vector2i = Vector2i(-999999, -999999),
	sync_hover: bool = true,
) -> void:
	if sync_hover:
		_hover_sync(input, overlay, hover)
	var visible: bool = input.action_range_visible_for_hover()
	var stand: Vector2i = input.action_range_intent_stand_cell(1)
	var overlay_stand: Vector2i = overlay._intent_stand_origin(_fixture_unit(fix))
	var has_red: bool = _overlay_has_any_red(overlay, fix.board)
	if visible != expect_show:
		failures.append(
			"ActionRangeRegression %s: visibility gate expected %s got %s (hover %s stand %s)"
			% [label, expect_show, visible, hover, stand],
		)
	if has_red != expect_show:
		failures.append(
			"ActionRangeRegression %s: overlay red tiles expected %s got %s (hover %s)"
			% [label, expect_show, has_red, hover],
		)
	if expect_stand.x > -900000 and stand != expect_stand:
		failures.append(
			"ActionRangeRegression %s: stand expected %s got %s"
			% [label, expect_stand, stand],
		)
	if stand != overlay_stand:
		failures.append(
			"ActionRangeRegression %s: input stand %s != overlay stand %s"
			% [label, stand, overlay_stand],
		)
	if expect_show and ability != null:
		var actor: UnitState = _fixture_unit(fix)
		var range_tiles: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
			fix.board, actor, ability, stand,
		)
		var anchored: bool = false
		for tile: Vector2i in range_tiles:
			if overlay.is_hover_action_range_tile(tile):
				anchored = true
				break
		if not anchored:
			failures.append(
				"ActionRangeRegression %s: no red tile from stand %s ability range"
				% [label, stand],
			)
		if stand != _fixture_unit(fix).position:
			var from_start: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
				fix.board, _fixture_unit(fix), ability, _fixture_unit(fix).position,
			)
			var only_start: bool = true
			for tile: Vector2i in _collect_overlay_red_tiles(overlay, fix.board):
				if not from_start.has(tile):
					only_start = false
					break
			if only_start and not from_start.is_empty():
				failures.append(
					"ActionRangeRegression %s: red tiles still anchored on knight start %s not stand %s"
					% [label, _fixture_unit(fix).position, stand],
				)


static func _test_show_move_hover_without_action_slot(failures: Array[String]) -> void:
	const HOVER_DEST := Vector2i(3, 4)
	var fix: Dictionary = PlanningQAGateTest._planning_fixture(KNIGHT_START, ENEMY_POS)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = PlanningQAGateTest._wire_overlay(fix)
	director.auto_run = true
	fix.knight.ability.points_left = 1
	director.plan_pre_move.entries.append(
		TimelineAction.make_move(
			1, HOVER_DEST, -1, [], GameEnums.MoveTiming.PRE_ACTION,
		),
	)
	var bowling_idx: int = PlanningQAGateTest._ability_index(fix.knight, BOWLING_CHARGE_ID)
	if bowling_idx < 0:
		failures.append("ActionRangeRegression show_move_hover_no_action_slot: Bowling Charge missing")
		return
	director.selected_ability_index = bowling_idx
	var slots: Dictionary = PlanningQAGateTest._commit_slots_at(input, 1, HOVER_DEST)
	var real_actions: Array = (slots.get("action", []) as Array).filter(func(a): return not (a is TimelineAction and (a as TimelineAction).awaiting_target))
	if not real_actions.is_empty():
		failures.append(
			"ActionRangeRegression show_move_hover_no_action_slot: fixture expects empty action slot",
		)
	var ability: AbilityData = PlanningQAGateTest._knight_ability(BOWLING_CHARGE_ID)
	_assert_contract(
		failures, "show_move_hover_no_action_slot", fix, overlay, input,
		HOVER_DEST, ability, true, HOVER_DEST,
	)


static func _test_show_enemy_bash_with_committed_premove(failures: Array[String]) -> void:
	const PREMOVE_DEST := Vector2i(5, 4)
	var fix: Dictionary = PlanningQAGateTest._planning_fixture(KNIGHT_START, ENEMY_POS)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = PlanningQAGateTest._wire_overlay(fix)
	director.plan_pre_move.entries.append(
		TimelineAction.make_move(
			1, PREMOVE_DEST, -1, [], GameEnums.MoveTiming.PRE_ACTION,
		),
	)
	var bash_idx: int = PlanningQAGateTest._ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("ActionRangeRegression show_enemy_bash_committed_premove: Shield Bash missing")
		return
	director.selected_ability_index = bash_idx
	var ability: AbilityData = PlanningQAGateTest._knight_ability(SHIELD_BASH_ID)
	# Timeline premove locks stand to committed dest (same as planning_qa_gate enemy_hover).
	_assert_contract(
		failures, "show_enemy_bash_committed_premove", fix, overlay, input,
		ENEMY_POS, ability, true, PREMOVE_DEST,
	)


static func _test_show_red_anchor_follows_stand_not_knight_start(failures: Array[String]) -> void:
	const HOVER_DEST := Vector2i(3, 4)
	var fix: Dictionary = PlanningQAGateTest._planning_fixture(KNIGHT_START, ENEMY_POS)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = PlanningQAGateTest._wire_overlay(fix)
	director.auto_run = true
	fix.knight.ability.points_left = 1
	director.plan_pre_move.entries.append(
		TimelineAction.make_move(
			1, HOVER_DEST, -1, [], GameEnums.MoveTiming.PRE_ACTION,
		),
	)
	var bowling_idx: int = PlanningQAGateTest._ability_index(fix.knight, BOWLING_CHARGE_ID)
	if bowling_idx < 0:
		failures.append("ActionRangeRegression show_red_anchor_on_stand: Bowling Charge missing")
		return
	director.selected_ability_index = bowling_idx
	var ability: AbilityData = PlanningQAGateTest._knight_ability(BOWLING_CHARGE_ID)
	_hover_sync(input, overlay, HOVER_DEST)
	var stand: Vector2i = input.action_range_intent_stand_cell(1)
	var at_stand: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		fix.board, fix.knight, ability, stand,
	)
	var at_start: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		fix.board, fix.knight, ability, KNIGHT_START,
	)
	var shifted_tile: Vector2i = Vector2i(-999999, -999999)
	for tile: Vector2i in at_stand:
		if not at_start.has(tile):
			shifted_tile = tile
			break
	if shifted_tile.x <= -900000:
		failures.append("ActionRangeRegression show_red_anchor_on_stand: need tile in stand range not start range")
		return
	if not overlay.is_hover_action_range_tile(shifted_tile):
		failures.append(
			"ActionRangeRegression show_red_anchor_on_stand: tile %s must be red at stand %s not start %s"
			% [shifted_tile, stand, KNIGHT_START],
		)


static func _test_bowling_enemy_hover_red_at_origin(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningQAGateTest._planning_fixture(KNIGHT_START, ENEMY_POS)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = PlanningQAGateTest._wire_overlay(fix)
	var bowling_idx: int = PlanningQAGateTest._ability_index(fix.knight, BOWLING_CHARGE_ID)
	if bowling_idx < 0:
		failures.append("ActionRangeRegression bowling_enemy_hover_red: Bowling Charge missing")
		return
	director.selected_ability_index = bowling_idx
	var ability: AbilityData = PlanningQAGateTest._knight_ability(BOWLING_CHARGE_ID)
	_attack_hover_sync(input, overlay, ENEMY_POS)
	var enemy_slots: Dictionary = PlanningQAGateTest._commit_slots_at(input, 1, ENEMY_POS)
	var enemy_actions: Array = enemy_slots.get("action", []) as Array
	if enemy_actions.is_empty():
		failures.append(
			"ActionRangeRegression bowling_enemy_hover_red: occupied enemy dash end must build an action, not ∅",
		)
	elif enemy_actions[0] is TimelineAction:
		var charge: TimelineAction = enemy_actions[0] as TimelineAction
		if charge.target_coord != ENEMY_POS or charge.target_unit_id != -1:
			failures.append(
				"ActionRangeRegression bowling_enemy_hover_red: occupied end must be a TILE dash (coord %s, unit -1), got %s / %s"
				% [ENEMY_POS, charge.target_coord, charge.target_unit_id],
			)
	if input.awaiting_targeting_active():
		failures.append(
			"ActionRangeRegression bowling_enemy_hover_red: enemy hover preview must not require self-arm",
		)
	if not input.action_range_visible_for_hover():
		failures.append(
			"ActionRangeRegression bowling_enemy_hover_red: enemy hover must keep action-range visible",
		)
	var stand: Vector2i = input.action_range_intent_stand_cell(1)
	if stand != KNIGHT_START:
		failures.append(
			"ActionRangeRegression bowling_enemy_hover_red: stand must stay at dash origin %s, got %s"
			% [KNIGHT_START, stand],
		)
	var expected: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		fix.board, fix.knight, ability, KNIGHT_START,
	)
	if not overlay.is_hover_action_range_tile(ENEMY_POS):
		failures.append(
			"ActionRangeRegression bowling_enemy_hover_red: enemy tile must be red on dash line from %s"
			% KNIGHT_START,
		)
	for tile: Vector2i in expected:
		if not overlay.is_hover_action_range_tile(tile):
			failures.append(
				"ActionRangeRegression bowling_enemy_hover_red: missing red tile %s from origin %s"
				% [tile, KNIGHT_START],
			)
			break


static func _test_bowling_enemy_hover_not_bash_route(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningQAGateTest._planning_fixture(KNIGHT_START, ENEMY_POS)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = PlanningQAGateTest._wire_overlay(fix)
	var bash_idx: int = PlanningQAGateTest._ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("ActionRangeRegression bowling_enemy_hover_not_bash: Shield Bash missing")
		return
	director.selected_ability_index = bash_idx
	_hover_sync(input, overlay, ENEMY_POS)
	if not overlay._movement_hover_route_cells().is_empty():
		failures.append(
			"ActionRangeRegression bowling_enemy_hover_not_bash: bash enemy hover must not use awaiting dash route",
		)


static func _test_bowling_empty_dash_line_remains_premove(failures: Array[String]) -> void:
	const KNIGHT := Vector2i(5, 5)
	const ENEMY := Vector2i(7, 5)
	const EMPTY_WALK_TILE := Vector2i(6, 5)
	const EMPTY_DASH_ONLY := Vector2i(8, 5)
	var fix: Dictionary = PlanningQAGateTest._planning_fixture(KNIGHT, ENEMY)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = PlanningQAGateTest._wire_overlay(fix)
	# An empty dash-line tile is still a walk when it fits the normal MP budget.
	_sync_knight_ap(fix, 1, 1)
	var bowling_idx: int = PlanningQAGateTest._ability_index(fix.knight, BOWLING_CHARGE_ID)
	if bowling_idx < 0:
		failures.append("ActionRangeRegression bowling_empty_dash_line: Bowling Charge missing")
		return
	director.selected_ability_index = bowling_idx
	_hover_sync(input, overlay, KNIGHT)
	if not overlay.is_hover_move_tile(EMPTY_WALK_TILE):
		failures.append(
			"ActionRangeRegression bowling_empty_dash_line: empty dash-line tile must remain a blue move",
		)
	_hover_sync(input, overlay, EMPTY_WALK_TILE)
	var walk_slots: Dictionary = PlanningQAGateTest._commit_slots_at(input, 1, EMPTY_WALK_TILE)
	var pre_moves: Array = walk_slots.get("pre", []) as Array
	if pre_moves.is_empty() or not pre_moves[0] is TimelineAction:
		failures.append(
			"ActionRangeRegression bowling_empty_dash_line: empty hover must build a MOVE premove",
		)
	elif (pre_moves[0] as TimelineAction).type != GameEnums.ActionType.MOVE:
		failures.append(
			"ActionRangeRegression bowling_empty_dash_line: premove slot must be MOVE",
		)
	if overlay.is_hover_move_tile(EMPTY_DASH_ONLY):
		failures.append(
			"ActionRangeRegression bowling_empty_dash_line: over-budget empty dash tile must not be blue",
		)


static func _test_bowling_dash_only_click_no_premove(failures: Array[String]) -> void:
	const KNIGHT := Vector2i(5, 5)
	const ENEMY := Vector2i(6, 5)
	const DASH_ONLY := Vector2i(8, 5)
	var fix: Dictionary = PlanningQAGateTest._planning_fixture(KNIGHT, ENEMY)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = PlanningQAGateTest._wire_overlay(fix)
	_sync_knight_ap(fix, 1, 1)
	var bowling_idx: int = PlanningQAGateTest._ability_index(fix.knight, BOWLING_CHARGE_ID)
	if bowling_idx < 0:
		failures.append("ActionRangeRegression bowling_dash_only_no_premove_click: Bowling Charge missing")
		return
	director.selected_ability_index = bowling_idx
	# Arm awaiting on self first (F5 / K4 live: dash endpoint intent only after self-arm).
	var arm_slots: Dictionary = input._final_commit_slots_for_click_at_cell(1, KNIGHT, Vector2.ZERO)
	if not director.commit_from_slots(1, arm_slots):
		failures.append(
			"ActionRangeRegression bowling_dash_only_no_premove_click: arm commit failed",
		)
	if director.find_awaiting_action(1) == null:
		failures.append(
			"ActionRangeRegression bowling_dash_only_no_premove_click: self click must arm awaiting dash",
		)
	_attack_hover_sync(input, overlay, DASH_ONLY)
	var armed_slots: Dictionary = input._final_commit_slots_for_click_at_cell(1, DASH_ONLY, Vector2.ZERO)
	var hover_icon: String = input.compute_hover_action_icon(DASH_ONLY)
	var expected_icon: String = input._cursor_icon_from_commit_slots(armed_slots, fix.knight)
	if hover_icon != expected_icon:
		failures.append(
			"ActionRangeRegression bowling_dash_only_no_premove_click: armed dash-only cursor must match slots (got %s expected %s)"
			% [hover_icon, expected_icon],
		)
	if not (armed_slots.get("pre", []) as Array).is_empty():
		failures.append(
			"ActionRangeRegression bowling_dash_only_no_premove_click: armed dash-only click must not commit premove",
		)
	if (armed_slots.get("action", []) as Array).is_empty():
		failures.append(
			"ActionRangeRegression bowling_dash_only_no_premove_click: armed dash-only click must build action",
		)


## Occupied dash end after self-arm: BULLDOZE dest-commit, not unit-target ∅.
static func _test_bowling_awaiting_occupied_end(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningQAGateTest._planning_fixture(KNIGHT_START, ENEMY_POS)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = PlanningQAGateTest._wire_overlay(fix)
	var bowling_idx: int = PlanningQAGateTest._ability_index(fix.knight, BOWLING_CHARGE_ID)
	if bowling_idx < 0:
		failures.append("ActionRangeRegression bowling_awaiting_occupied_end: Bowling Charge missing")
		return
	director.selected_ability_index = bowling_idx
	var arm_slots: Dictionary = input._final_commit_slots_for_click_at_cell(1, KNIGHT_START, Vector2.ZERO)
	if not director.commit_from_slots(1, arm_slots):
		failures.append("ActionRangeRegression bowling_awaiting_occupied_end: self-arm commit failed")
		return
	if director.find_awaiting_action(1) == null:
		failures.append("ActionRangeRegression bowling_awaiting_occupied_end: self click must arm awaiting dash")
		return
	_attack_hover_sync(input, overlay, ENEMY_POS)
	var dest_slots: Dictionary = input._final_commit_slots_for_click_at_cell(1, ENEMY_POS, Vector2.ZERO)
	if input._is_invalid_dict(dest_slots):
		failures.append(
			"ActionRangeRegression bowling_awaiting_occupied_end: occupied dash end must not be invalid (%s)"
			% str(dest_slots.get("invalid", "")),
		)
	var dest_actions: Array = dest_slots.get("action", []) as Array
	if dest_actions.is_empty():
		failures.append(
			"ActionRangeRegression bowling_awaiting_occupied_end: occupied enemy dash end must build an action, not ∅",
		)
	elif dest_actions[0] is TimelineAction:
		var charge: TimelineAction = dest_actions[0] as TimelineAction
		if charge.target_coord != ENEMY_POS or charge.target_unit_id != -1:
			failures.append(
				"ActionRangeRegression bowling_awaiting_occupied_end: occupied end must be a TILE dash (coord %s, unit -1), got %s / %s"
				% [ENEMY_POS, charge.target_coord, charge.target_unit_id],
			)
	var hover_icon: String = input.compute_hover_action_icon(ENEMY_POS)
	if hover_icon == PlanningIcons.GLYPH_NULL or hover_icon == "":
		failures.append(
			"ActionRangeRegression bowling_awaiting_occupied_end: occupied dash hover must not show ∅",
		)
	if not overlay.is_hover_action_range_tile(ENEMY_POS):
		failures.append(
			"ActionRangeRegression bowling_awaiting_occupied_end: enemy tile must stay red while awaiting dest",
		)
	if director.preview_commit_valid(1, input._actions_from_slots(dest_slots)) != "":
		failures.append(
			"ActionRangeRegression bowling_awaiting_occupied_end: preview must accept occupied BULLDOZE landing",
		)


static func _sync_knight_ap(fix: Dictionary, ap: int, mp: int = -1) -> void:
	fix.knight.ability.points_left = ap
	if mp >= 0:
		fix.knight.movement.points_left = mp
	if fix.director.base_board != null:
		var base_knight: UnitState = fix.director.base_board.get_unit_by_id(1)
		if base_knight != null:
			base_knight.ability.points_left = ap
			if mp >= 0:
				base_knight.movement.points_left = mp
	if fix.director.projected_state != null:
		var projected_knight: UnitState = fix.director.projected_state.get_unit_by_id(1)
		if projected_knight != null:
			projected_knight.ability.points_left = ap
			if mp >= 0:
				projected_knight.movement.points_left = mp


static func _test_hide_auto_run_consumes_skill_ap(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningQAGateTest._planning_fixture(KNIGHT_START, ENEMY_POS)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = PlanningQAGateTest._wire_overlay(fix)
	director.auto_run = true
	_sync_knight_ap(fix, 1, 0)
	var bash_idx: int = PlanningQAGateTest._ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("ActionRangeRegression hide_auto_run_ap_gate: Shield Bash missing")
		return
	director.selected_ability_index = bash_idx
	var run_tile: Vector2i = _find_run_hover_tile(fix.board, fix.knight)
	if run_tile.x <= -900000:
		failures.append("ActionRangeRegression hide_auto_run_ap_gate: no run tile")
		return
	var ability: AbilityData = PlanningQAGateTest._knight_ability(SHIELD_BASH_ID)
	_assert_contract(
		failures, "hide_auto_run_ap_gate", fix, overlay, input,
		run_tile, ability, false,
	)


## Owner-report regression: F5 click commit path (not bare commit_from_slots).
## Shield Bash + auto-run, run icon on timeline, 0 AP, mouse still on destination — no red.
static func assert_hide_red_after_commit_run_icon_shield_bash(failures: Array[String]) -> void:
	var base_fix: Dictionary = PlanningDragE2EHarness._planning_fixture(KNIGHT_START, ENEMY_POS)
	var fix: Dictionary = PlanningDragE2EHarness.wire_fixture(base_fix)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	director.auto_run = true
	_sync_knight_ap(fix, 1, 0)
	var bash_idx: int = PlanningQAGateTest._ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("ActionRangeRegression hide_after_commit_run_icon_bash: Shield Bash missing")
		return
	director.selected_ability_index = -1
	_sync_knight_ap(fix, 1, 1)
	var run_dest: Vector2i = _find_run_hover_tile(fix.board, fix.knight)
	if run_dest.x <= -900000:
		failures.append("ActionRangeRegression hide_after_commit_run_icon_bash: no run destination tile")
		return
	input.set_qa_pointer_grid_cell(run_dest)
	input.on_hover_moved(run_dest)
	input._flush_hover_heavy_sync()
	overlay._recompute_hover_ranges_from_inputs()
	var slots: Dictionary = PlanningQAGateTest._click_slots_at(input, 1, run_dest)
	if PlanningQAGateTest._slots_invalid(slots):
		failures.append(
			"ActionRangeRegression hide_after_commit_run_icon_bash: hover slots invalid at %s"
			% run_dest,
		)
		return
	var pre_moves: Array = slots.get("pre", []) as Array
	if pre_moves.is_empty():
		failures.append(
			"ActionRangeRegression hide_after_commit_run_icon_bash: hover must build pre-move before commit",
		)
		return
	var pre_move: TimelineAction = pre_moves[0] as TimelineAction
	if pre_move == null or not pre_move.uses_run:
		failures.append(
			"ActionRangeRegression hide_after_commit_run_icon_bash: pre-move must be run before commit",
		)
		return
	var run_glyph: String = input._cursor_icon_from_commit_slots(slots, fix.knight)
	if run_glyph != PlanningIcons.GLYPH_RUN:
		failures.append(
			"ActionRangeRegression hide_after_commit_run_icon_bash: cursor must show run icon, got %s"
			% run_glyph,
		)
		return
	## F5 path: paint live preview → commit → promote (not bare commit_from_slots).
	input.call("_paint_intent_slots_before_commit", 1, slots)
	if not director.commit_from_slots(1, slots):
		failures.append(
			"ActionRangeRegression hide_after_commit_run_icon_bash: commit_from_slots failed",
		)
		return
	input.call("_promote_intent_preview_after_commit")
	_refresh_planning_now(fix)
	if director.plan_pre_move.entries.is_empty():
		failures.append(
			"ActionRangeRegression hide_after_commit_run_icon_bash: run must appear on timeline after commit",
		)
		return
	var timeline_run: TimelineAction = director.plan_pre_move.entries[0] as TimelineAction
	if timeline_run == null or not timeline_run.uses_run:
		failures.append(
			"ActionRangeRegression hide_after_commit_run_icon_bash: timeline pre-move must be run (run icon)",
		)
		return
	if timeline_run.target_coord != run_dest:
		failures.append(
			"ActionRangeRegression hide_after_commit_run_icon_bash: timeline run dest expected %s got %s"
			% [run_dest, timeline_run.target_coord],
		)
		return
	var projected: UnitState = (
		director.projected_state.get_unit_by_id(1) if director.projected_state != null else null
	)
	if projected == null:
		failures.append(
			"ActionRangeRegression hide_after_commit_run_icon_bash: projected knight missing after commit",
		)
		return
	if projected.position != run_dest:
		failures.append(
			"ActionRangeRegression hide_after_commit_run_icon_bash: projected stand expected %s got %s"
			% [run_dest, projected.position],
		)
		return
	if projected.ability.points_left > 0:
		failures.append(
			"ActionRangeRegression hide_after_commit_run_icon_bash: run commit must leave 0 AP (got %d)"
			% projected.ability.points_left,
		)
		return
	director.select_ability(bash_idx)
	input.call("_run_ability_settled_refresh")
	_refresh_planning_now(fix)
	var ability: AbilityData = PlanningQAGateTest._knight_ability(SHIELD_BASH_ID)
	_assert_contract(
		failures,
		"hide_after_commit_run_icon_bash",
		fix,
		overlay,
		input,
		run_dest,
		ability,
		false,
		run_dest,
	)


static func _test_hide_red_after_commit_run_icon_shield_bash(failures: Array[String]) -> void:
	assert_hide_red_after_commit_run_icon_shield_bash(failures)


static func _test_hide_red_after_commit_run_icon_bowling(failures: Array[String]) -> void:
	var base_fix: Dictionary = PlanningDragE2EHarness._planning_fixture(KNIGHT_START, ENEMY_POS)
	var fix: Dictionary = PlanningDragE2EHarness.wire_fixture(base_fix)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	director.auto_run = true
	_sync_knight_ap(fix, 1, 0)
	var bowling_idx: int = PlanningQAGateTest._ability_index(fix.knight, BOWLING_CHARGE_ID)
	if bowling_idx < 0:
		failures.append("ActionRangeRegression hide_after_commit_run_icon_bowling: Bowling Charge missing")
		return
	director.selected_ability_index = bowling_idx
	var run_dest: Vector2i = _find_run_hover_tile(fix.board, fix.knight)
	if run_dest.x <= -900000:
		failures.append("ActionRangeRegression hide_after_commit_run_icon_bowling: no run destination tile")
		return
	input.set_qa_pointer_grid_cell(run_dest)
	input.on_hover_moved(run_dest)
	input._flush_hover_heavy_sync()
	overlay._recompute_hover_ranges_from_inputs()
	var slots: Dictionary = PlanningQAGateTest._click_slots_at(input, 1, run_dest)
	if PlanningQAGateTest._slots_invalid(slots):
		failures.append(
			"ActionRangeRegression hide_after_commit_run_icon_bowling: hover slots invalid at %s"
			% run_dest,
		)
		return
	var pre_moves: Array = slots.get("pre", []) as Array
	if pre_moves.is_empty():
		failures.append(
			"ActionRangeRegression hide_after_commit_run_icon_bowling: hover must build pre-move before commit",
		)
		return
	var pre_move: TimelineAction = pre_moves[0] as TimelineAction
	if pre_move == null or not pre_move.uses_run:
		failures.append(
			"ActionRangeRegression hide_after_commit_run_icon_bowling: pre-move must be run before commit",
		)
		return
	input.call("_paint_intent_slots_before_commit", 1, slots)
	if not director.commit_from_slots(1, slots):
		failures.append(
			"ActionRangeRegression hide_after_commit_run_icon_bowling: commit_from_slots failed",
		)
		return
	input.call("_promote_intent_preview_after_commit")
	_refresh_planning_now(fix)
	director.select_ability(bowling_idx)
	input.call("_run_ability_settled_refresh")
	_refresh_planning_now(fix)
	var ability: AbilityData = PlanningQAGateTest._knight_ability(BOWLING_CHARGE_ID)
	_assert_contract(
		failures,
		"hide_after_commit_run_icon_bowling",
		fix,
		overlay,
		input,
		run_dest,
		ability,
		false,
		run_dest,
	)


static func _test_hide_red_committed_run_timeline_bowling(failures: Array[String]) -> void:
	const RUN_DEST := Vector2i(3, 6)
	var fix: Dictionary = PlanningQAGateTest._planning_fixture(KNIGHT_START, ENEMY_POS)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = PlanningQAGateTest._wire_overlay(fix)
	director.auto_run = true
	fix.knight.ability.points_left = 1
	director.plan_pre_move.entries.append(
		TimelineAction.make_run_move(
			1, RUN_DEST, -1, [], GameEnums.MoveTiming.PRE_ACTION,
		),
	)
	var bowling_idx: int = PlanningQAGateTest._ability_index(fix.knight, BOWLING_CHARGE_ID)
	if bowling_idx < 0:
		failures.append("ActionRangeRegression hide_committed_run_timeline_bowling: Bowling Charge missing")
		return
	director.selected_ability_index = bowling_idx
	var ability: AbilityData = PlanningQAGateTest._knight_ability(BOWLING_CHARGE_ID)
	_assert_contract(
		failures,
		"hide_committed_run_timeline_bowling",
		fix,
		overlay,
		input,
		RUN_DEST,
		ability,
		false,
	)


static func _test_hide_red_committed_run_interior_hover_bowling(failures: Array[String]) -> void:
	const RUN_DEST := Vector2i(3, 4)
	const INTERIOR_HOVER := Vector2i(4, 4)
	var fix: Dictionary = PlanningQAGateTest._planning_fixture(KNIGHT_START, ENEMY_POS)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = PlanningQAGateTest._wire_overlay(fix)
	director.auto_run = true
	fix.knight.ability.points_left = 1
	fix.knight.movement.points_left = 0
	director.plan_pre_move.entries.append(
		TimelineAction.make_run_move(
			1, RUN_DEST, -1, [INTERIOR_HOVER], GameEnums.MoveTiming.PRE_ACTION,
		),
	)
	var bowling_idx: int = PlanningQAGateTest._ability_index(fix.knight, BOWLING_CHARGE_ID)
	if bowling_idx < 0:
		failures.append(
			"ActionRangeRegression hide_committed_run_interior_hover_bowling: Bowling Charge missing",
		)
		return
	director.selected_ability_index = bowling_idx
	var ability: AbilityData = PlanningQAGateTest._knight_ability(BOWLING_CHARGE_ID)
	_assert_contract(
		failures,
		"hide_committed_run_interior_hover_bowling",
		fix,
		overlay,
		input,
		INTERIOR_HOVER,
		ability,
		false,
	)


static func _test_hide_no_ability_selected(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningQAGateTest._planning_fixture(KNIGHT_START, ENEMY_POS)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = PlanningQAGateTest._wire_overlay(fix)
	director.selected_ability_index = -1
	_assert_contract(
		failures, "hide_no_ability", fix, overlay, input,
		Vector2i(3, 4), null, false,
	)


static func _test_show_awaiting_trample(failures: Array[String]) -> void:
	var fix: Dictionary = TramplingAdvanceE2ETest._knight_fixture(TramplingAdvanceE2ETest.START_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var unit: UnitState = fix.unit
	var overlay: TacticalPlanningOverlay = PlanningQAGateTest._wire_overlay(fix)
	if fix.trample_idx < 0:
		failures.append("ActionRangeRegression show_awaiting_trample: Trampling Advance missing")
		return
	if not TramplingAdvanceE2ETest._arm_trample_awaiting(input, director, unit):
		failures.append("ActionRangeRegression show_awaiting_trample: arm awaiting failed")
		return
	var trample: AbilityData = null
	for ab: AbilityData in unit.active_abilities:
		if ab != null and ab.id == TRAMPLE_ID:
			trample = ab
			break
	_assert_contract(
		failures, "show_awaiting_trample", fix, overlay, input,
		TramplingAdvanceE2ETest.END_CELL, trample, true,
	)


static func _test_hover_step_updates_stand_and_red_tiles(failures: Array[String]) -> void:
	const DEST_A := Vector2i(3, 4)
	const DEST_B := Vector2i(4, 4)
	var fix: Dictionary = PlanningQAGateTest._planning_fixture(KNIGHT_START, ENEMY_POS)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = PlanningQAGateTest._wire_overlay(fix)
	director.auto_run = true
	fix.knight.ability.points_left = 1
	var bowling_idx: int = PlanningQAGateTest._ability_index(fix.knight, BOWLING_CHARGE_ID)
	if bowling_idx < 0:
		failures.append("ActionRangeRegression hover_step_updates_stand: Bowling Charge missing")
		return
	director.selected_ability_index = bowling_idx
	var ability: AbilityData = PlanningQAGateTest._knight_ability(BOWLING_CHARGE_ID)
	_hover_sync(input, overlay, DEST_A)
	var stand_a: Vector2i = input.action_range_intent_stand_cell(1)
	var reds_a: Array[Vector2i] = _collect_overlay_red_tiles(overlay, fix.board)
	_hover_sync(input, overlay, DEST_B)
	var stand_b: Vector2i = input.action_range_intent_stand_cell(1)
	var reds_b: Array[Vector2i] = _collect_overlay_red_tiles(overlay, fix.board)
	if stand_a == stand_b:
		failures.append(
			"ActionRangeRegression hover_step_updates_stand: stand must change %s -> %s on hover step"
			% [stand_a, stand_b],
		)
	if reds_a == reds_b:
		failures.append(
			"ActionRangeRegression hover_step_updates_stand: red tile set must update on hover step",
		)
	var range_b: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		fix.board, fix.knight, ability, stand_b,
	)
	var anchored_b: bool = false
	for tile: Vector2i in range_b:
		if overlay.is_hover_action_range_tile(tile):
			anchored_b = true
			break
	if not anchored_b:
		failures.append(
			"ActionRangeRegression hover_step_updates_stand: red tiles must anchor on new stand %s"
			% stand_b,
		)


## Would have failed 37b3879 — awaiting module range used base_board (turn start).
## BUG-20260815T183841-612: pre-move (5,3)→(7,3), arm Charge Strike, red still on (5,3).
static func _test_awaiting_module_range_after_committed_premove(failures: Array[String]) -> void:
	const START := Vector2i(5, 3)
	const LANDING := Vector2i(7, 3)
	const ONLY_FROM_LANDING := Vector2i(7, 5)
	const ONLY_FROM_START := Vector2i(3, 3)
	const Checklist := preload("res://tests/harness/planning_checklist_harness.gd")
	var fix: Dictionary = PlanningDragE2EHarness.wire_bruiser_solo_fixture(
		START, &"bruiser_charge_strike",
	)
	if fix.has("error"):
		failures.append(
			"ActionRangeRegression awaiting_module_range_after_premove: bruiser fixture %s"
			% str(fix.error),
		)
		return
	if fix.is_empty() or not fix.has("input"):
		return
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	director.auto_run = false
	director.selected_ability_index = -1
	var bruiser: UnitState = fix.bruiser as UnitState
	bruiser.ability.points_left = maxi(bruiser.ability.points_left, 1)
	bruiser.movement.points_left = maxi(bruiser.movement.points_left, 4)
	var walk_slots: Dictionary = PlanningQAGateTest._commit_slots_at(input, 1, LANDING)
	var walk_pre: Array = walk_slots.get("pre", []) as Array
	if walk_pre.is_empty():
		failures.append(
			"ActionRangeRegression awaiting_module_range_after_premove: unarmed walk to %s must build pre-move"
			% LANDING,
		)
		return
	if not director.commit_from_slots(1, walk_slots):
		failures.append("ActionRangeRegression awaiting_module_range_after_premove: pre-move commit failed")
		return
	Checklist.flush_planning(fix)
	var idx: int = Checklist.select_ability(fix, &"bruiser_charge_strike")
	if idx < 0:
		failures.append("ActionRangeRegression awaiting_module_range_after_premove: Charge Strike missing")
		return
	var arm_slots: Dictionary = PlanningQAGateTest._commit_slots_at(input, 1, LANDING)
	if not director.commit_from_slots(1, arm_slots):
		failures.append("ActionRangeRegression awaiting_module_range_after_premove: self-arm Charge Strike failed")
		return
	Checklist.flush_planning(fix)
	var awaiting: TimelineAction = director.find_awaiting_action(1)
	if awaiting == null or awaiting.awaiting_module_index != 0:
		failures.append(
			"ActionRangeRegression awaiting_module_range_after_premove: must await MOVE module 0, got %s"
			% str(awaiting.awaiting_module_index if awaiting != null else -999),
		)
		return
	_hover_sync(input, overlay, LANDING)
	var stand: Vector2i = input.action_range_intent_stand_cell(1)
	var overlay_stand: Vector2i = overlay._intent_stand_origin(bruiser)
	if stand != LANDING:
		failures.append(
			"ActionRangeRegression awaiting_module_range_after_premove: stand expected %s got %s"
			% [LANDING, stand],
		)
	if overlay_stand != LANDING:
		failures.append(
			"ActionRangeRegression awaiting_module_range_after_premove: overlay stand expected %s got %s"
			% [LANDING, overlay_stand],
		)
	if not overlay.is_hover_action_range_tile(ONLY_FROM_LANDING):
		failures.append(
			"ActionRangeRegression awaiting_module_range_after_premove: red missing %s (in MOVE 2 from landing %s, out from start %s)"
			% [ONLY_FROM_LANDING, LANDING, START],
		)
	if overlay.is_hover_action_range_tile(ONLY_FROM_START):
		failures.append(
			"ActionRangeRegression awaiting_module_range_after_premove: red still on start-only tile %s (turn-start diamond around %s)"
			% [ONLY_FROM_START, START],
		)


static func _test_visibility_gate_parity_show(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningQAGateTest._planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var overlay: TacticalPlanningOverlay = PlanningQAGateTest._wire_overlay(fix)
	var bash_idx: int = PlanningQAGateTest._ability_index(fix.knight, SHIELD_BASH_ID)
	director.selected_ability_index = bash_idx
	_hover_sync(input, overlay, ENEMY_POS)
	if input.action_range_visible_for_hover() != _overlay_has_any_red(overlay, fix.board):
		failures.append(
			"ActionRangeRegression parity_gate_show: visibility gate must match overlay red presence on enemy hover",
		)


static func _test_visibility_gate_parity_hide(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningQAGateTest._planning_fixture(KNIGHT_START, ENEMY_POS)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var overlay: TacticalPlanningOverlay = PlanningQAGateTest._wire_overlay(fix)
	director.auto_run = true
	fix.knight.ability.points_left = 1
	fix.knight.movement.points_left = 2
	director.selected_ability_index = PlanningQAGateTest._ability_index(fix.knight, BOWLING_CHARGE_ID)
	var run_tile: Vector2i = _find_run_hover_tile(fix.board, fix.knight)
	if run_tile.x <= -900000:
		failures.append("ActionRangeRegression parity_gate_hide: no run tile")
		return
	_hover_sync(input, overlay, run_tile)
	if input.action_range_visible_for_hover() != _overlay_has_any_red(overlay, fix.board):
		failures.append(
			"ActionRangeRegression parity_gate_hide: visibility gate must match overlay red absence on unaffordable run hover",
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


## NOTE / MANDATE:
## Do NOT run swap tests unless specifically fixing swap mechanics!
## Swap mechanics have a dedicated acceptance runner (scripts/qa/run_swap_planning_acceptance.ps1)
## and dedicated harness entry `ActionRangeRegressionTest.run_swap_tests(failures)`.
static func _test_post_swap_post_move_stand_locked_on_orbit(failures: Array[String]) -> void:
	var Checklist := PlanningChecklistHarness
	var fix: Dictionary = Checklist.wire_swap_board(Checklist.SWAP_ALLY_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	var k1_id: int = int(fix.k1_id)
	if Checklist.select_ability_for_unit(fix, k1_id, Checklist.KNIGHT_SWAP_ID) < 0:
		failures.append("ActionRangeRegression post_swap_post_move_stand_locked: knight_swap missing")
		return
	Checklist.select_unit(fix, k1_id, Checklist.SWAP_ALLY_CELL)
	var swap_slots: Dictionary = Checklist.commit_production(fix, Checklist.SWAP_ALLY_CELL)
	if swap_slots.get("invalid", false):
		failures.append("ActionRangeRegression post_swap_post_move_stand_locked: swap commit invalid")
		return
	Checklist.flush_planning(fix)
	var stand_after_swap: Vector2i = Checklist.SWAP_ALLY_CELL
	var orbit: Vector2i = Vector2i(stand_after_swap.x + 1, stand_after_swap.y)
	if not fix.board.is_in_bounds(orbit):
		orbit = Vector2i(stand_after_swap.x, stand_after_swap.y + 1)
	Checklist.hover(fix, orbit)
	var stand: Vector2i = input.action_range_intent_stand_cell(fix.k1_id)
	if stand != stand_after_swap:
		failures.append(
			"ActionRangeRegression post_swap_post_move_stand_locked: stand expected %s got %s on orbit %s"
			% [stand_after_swap, stand, orbit],
		)
	var overlay_stand: Vector2i = overlay._intent_stand_origin(fix.knight)
	if overlay_stand != stand_after_swap:
		failures.append(
			"ActionRangeRegression post_swap_post_move_stand_locked: overlay stand expected %s got %s"
			% [stand_after_swap, overlay_stand],
		)
	var preview: Dictionary = input._preview_from_commit_slots_at_cell(fix.k1_id, orbit)
	if preview.get("temp_board", null) == null:
		failures.append(
			"ActionRangeRegression post_swap_post_move_stand_locked: orbit hover must return a simulator preview",
		)
	var orbit_slots: Dictionary = input._final_commit_slots_for_click_at_cell(fix.k1_id, orbit, Vector2.ZERO)
	var orbit_actions: Array[TimelineAction] = input._actions_from_slots(orbit_slots)
	var director_preview: Dictionary = director.preview_actions(fix.k1_id, orbit_actions)
	if director_preview.get("temp_board", null) == null:
		failures.append(
			"ActionRangeRegression post_swap_post_move_stand_locked: director must return a simulator preview",
		)
	if not overlay._blast_tiles_on_hover_layer:
		failures.append(
			"ActionRangeRegression post_swap_post_move_stand_locked: blast must follow cursor on hover layer",
		)


## NOTE / MANDATE:
## Do NOT run swap tests unless specifically fixing swap mechanics!
## Swap mechanics have a dedicated acceptance runner (scripts/qa/run_swap_planning_acceptance.ps1)
## and dedicated harness entry `ActionRangeRegressionTest.run_swap_tests(failures)`.
static func _test_premove_swap_committed_orbit_walk_intent(failures: Array[String]) -> void:
	var Checklist := PlanningChecklistHarness
	var fix: Dictionary = Checklist.wire_swap_board(Checklist.WALK_SWAP_ALLY_CELL)
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var k1_id: int = int(fix.k1_id)
	if Checklist.select_ability_for_unit(fix, k1_id, Checklist.KNIGHT_SWAP_ID) < 0:
		failures.append("ActionRangeRegression premove_swap_committed_orbit_walk: knight_swap missing")
		return
	Checklist.select_unit(fix, k1_id, Checklist.WALK_SWAP_ALLY_CELL)
	var swap_slots: Dictionary = Checklist.commit_production(fix, Checklist.WALK_SWAP_ALLY_CELL)
	if swap_slots.get("invalid", false):
		failures.append("ActionRangeRegression premove_swap_committed_orbit_walk: swap commit invalid")
		return
	var pre_moves: Array[TimelineAction] = Checklist.pre_moves_for_unit(director, fix.k1_id)
	if pre_moves.size() < 2 or pre_moves[1].type != GameEnums.ActionType.ABILITY:
		failures.append(
			"ActionRangeRegression premove_swap_committed_orbit_walk: expected walk+swap pre-move pair",
		)
		return
	Checklist.flush_planning(fix)
	if not input._ally_skill_preview_slots(fix.knight, Checklist.WALK_SWAP_APPROACH).is_empty():
		failures.append(
			"ActionRangeRegression premove_swap_committed_orbit_walk: ally hover must not rebuild swap slots",
		)
	var ally_slots: Dictionary = input._build_commit_slots_at_cell(fix.k1_id, Checklist.WALK_SWAP_APPROACH)
	var ally_actions: Array[TimelineAction] = input._actions_from_slots(ally_slots)
	for action: TimelineAction in ally_actions:
		if action.type == GameEnums.ActionType.ABILITY:
			failures.append(
				"ActionRangeRegression premove_swap_committed_orbit_walk: ally cell must not re-pair swap",
			)
			break


static func _test_shield_bash_off_map_hover(failures: Array[String]) -> void:
	const OFF_MAP_CELL := Vector2i(-1, -1)
	var fix: Dictionary = PlanningQAGateTest._planning_fixture(KNIGHT_START, ENEMY_POS)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = PlanningQAGateTest._wire_overlay(fix)
	var bash_idx: int = PlanningQAGateTest._ability_index(fix.knight, SHIELD_BASH_ID)
	if bash_idx < 0:
		failures.append("ActionRangeRegression shield_bash_off_map_hover: Shield Bash missing")
		return
	director.selected_ability_index = bash_idx
	var ability: AbilityData = PlanningQAGateTest._knight_ability(SHIELD_BASH_ID)
	_attack_hover_sync(input, overlay, OFF_MAP_CELL)
	_assert_contract(
		failures, "shield_bash_off_map_hover", fix, overlay, input,
		OFF_MAP_CELL, ability, true, KNIGHT_START, false,
	)


static func _test_premove_intent_legs_no_boomerang(failures: Array[String]) -> void:
	const PREMOVE_DEST := Vector2i(5, 4)
	var fix: Dictionary = PlanningQAGateTest._planning_fixture(KNIGHT_START, ENEMY_POS)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = PlanningQAGateTest._wire_overlay(fix)
	director.select_ability(-1)

	var unit_id: int = fix.knight.id
	_hover_sync(input, overlay, PREMOVE_DEST)

	# Verify hover route before commit: clean route from start to destination without boomerang.
	var hover_paths: Dictionary = input._authoritative_preview_paths()
	var hover_route: Array = hover_paths.get(unit_id, [])
	if hover_route.is_empty():
		failures.append("ActionRangeRegression premove_no_boomerang: hover route missing before commit")
		return
	if hover_route[0] != KNIGHT_START:
		failures.append(
			"ActionRangeRegression premove_no_boomerang: hover start %s expected %s" % [hover_route[0], KNIGHT_START],
		)
	if hover_route.back() != PREMOVE_DEST:
		failures.append(
			"ActionRangeRegression premove_no_boomerang: hover back %s expected %s" % [hover_route.back(), PREMOVE_DEST],
		)
	if hover_route.size() != 3:
		failures.append(
			"ActionRangeRegression premove_no_boomerang: extra legs detected in hover: route %s" % [hover_route],
		)
	var seen: Dictionary = {}
	for c: Variant in hover_route:
		if seen.has(c):
			failures.append(
				"ActionRangeRegression premove_no_boomerang: boomerang loop detected at %s in %s" % [c, hover_route],
			)
			break
		seen[c] = true

	# Commit pre-move: executes immediately on live board and clears move preview immediately.
	var walk_slots: Dictionary = PlanningQAGateTest._commit_slots_at(input, unit_id, PREMOVE_DEST)
	input.call("_paint_intent_slots_before_commit", unit_id, walk_slots)
	if not director.commit_from_slots(unit_id, walk_slots):
		failures.append("ActionRangeRegression premove_no_boomerang: pre-move commit failed")
		return
	input.call("_promote_intent_preview_after_commit")

	# Move preview must clear immediately upon execution.
	if overlay._should_draw_player_move_preview():
		failures.append(
			"ActionRangeRegression premove_no_boomerang: overlay still exposes move preview after execution",
		)
	var committed: CombatPlanningPreview = overlay.get_committed_preview()
	var committed_route: Array = committed.preview_paths.get(unit_id, [])
	if not committed_route.is_empty():
		failures.append(
			"ActionRangeRegression premove_no_boomerang: committed route not cleared after execution: %s" % [committed_route],
		)
	if committed.preview_board != null:
		failures.append(
			"ActionRangeRegression premove_no_boomerang: preview_board not cleared after execution",
		)

	# Latest stand must reflect the destination reached.
	var stand: Vector2i = CombatPlanningPreview.planning_latest_stand_cell(
		director, director.base_board, unit_id, committed,
	)
	if stand != PREMOVE_DEST:
		failures.append(
			"ActionRangeRegression premove_no_boomerang: stand %s expected %s" % [stand, PREMOVE_DEST],
		)

	# Verify move_leg_origin_cell reflects the true starting cell (KNIGHT_START), not PREMOVE_DEST.
	var move_act: TimelineAction = CombatPlanningPreview.committed_move_action(
		director.get_player_plan(), unit_id, GameEnums.MoveTiming.PRE_ACTION,
	)
	if move_act == null:
		failures.append("ActionRangeRegression premove_no_boomerang: committed move action missing")
		return
	var origin_cell: Vector2i = CombatPlanningPreview.move_leg_origin_cell(
		director, director.board, unit_id, GameEnums.MoveTiming.PRE_ACTION, move_act,
	)
	if origin_cell != KNIGHT_START:
		failures.append(
			"ActionRangeRegression premove_no_boomerang: move origin %s expected %s" % [origin_cell, KNIGHT_START],
		)

	# Verify committed_move_already_realized returns true when unit has arrived at destination
	if not CombatPlanningPreview.committed_move_already_realized(
		director, director.board, unit_id, GameEnums.MoveTiming.PRE_ACTION, move_act, [KNIGHT_START, PREMOVE_DEST], PREMOVE_DEST,
	):
		failures.append("ActionRangeRegression premove_no_boomerang: committed move not marked realized after arrival")

	# Verify display_committed_move_route_leg returns empty array (cleared) once executed
	var committed_leg: Array = input.display_committed_move_route_leg(
		unit_id, GameEnums.MoveTiming.PRE_ACTION, PREMOVE_DEST,
	)
	if not committed_leg.is_empty():
		failures.append(
			"ActionRangeRegression premove_no_boomerang: committed leg not cleared after execution: %s" % [committed_leg],
		)

	# Post-commit hover on another tile (BUG-20260904T000206-156: hover tile (6, 5)) must NOT resurrect pre-move route or arrows
	_hover_sync(input, overlay, Vector2i(6, 5))
	var post_hover_leg: Array = input.display_committed_move_route_leg(
		unit_id, GameEnums.MoveTiming.PRE_ACTION, PREMOVE_DEST,
	)
	if not post_hover_leg.is_empty():
		failures.append(
			"ActionRangeRegression premove_no_boomerang: hover on other cell resurrected committed leg: %s" % [post_hover_leg],
		)

	# Multi-tile autorun pre-move test (BUG-20260904T000305-623):
	const AUTORUN_DEST := Vector2i(6, 3)
	var fix2: Dictionary = PlanningQAGateTest._planning_fixture(KNIGHT_START, ENEMY_POS)
	var dir2: CombatDirector = fix2.director
	var inp2: CombatPlanningInput = fix2.input
	var over2: TacticalPlanningOverlay = PlanningQAGateTest._wire_overlay(fix2)
	dir2.auto_run = true
	dir2.select_ability(-1)
	var u2_id: int = fix2.knight.id
	_hover_sync(inp2, over2, AUTORUN_DEST)
	var autorun_slots: Dictionary = PlanningQAGateTest._commit_slots_at(inp2, u2_id, AUTORUN_DEST)
	inp2.call("_paint_intent_slots_before_commit", u2_id, autorun_slots)
	if not dir2.commit_from_slots(u2_id, autorun_slots):
		failures.append("ActionRangeRegression premove_no_boomerang: autorun commit failed")
		return
	inp2.call("_promote_intent_preview_after_commit")

	var autorun_act: TimelineAction = CombatPlanningPreview.committed_move_action(
		dir2.get_player_plan(), u2_id, GameEnums.MoveTiming.PRE_ACTION,
	)
	if autorun_act == null:
		failures.append("ActionRangeRegression premove_no_boomerang: autorun move action missing")
		return
	var autorun_origin: Vector2i = CombatPlanningPreview.move_leg_origin_cell(
		dir2, dir2.board, u2_id, GameEnums.MoveTiming.PRE_ACTION, autorun_act,
	)
	if autorun_origin != KNIGHT_START:
		failures.append(
			"ActionRangeRegression premove_no_boomerang: autorun origin %s expected %s" % [autorun_origin, KNIGHT_START],
		)

	# Verify slots route does not start with destination (no boomerang loop)
	var slots_route: Array[Vector2i] = CombatPlanningPreview._committed_move_route_from_slots(
		dir2, dir2.board, u2_id, GameEnums.MoveTiming.PRE_ACTION, autorun_act,
	)
	if not slots_route.is_empty() and slots_route[0] == AUTORUN_DEST:
		failures.append(
			"ActionRangeRegression premove_no_boomerang: autorun slots route starts at destination %s: %s"
			% [AUTORUN_DEST, slots_route],
		)

	# Verify realized and cleared once executed
	if not CombatPlanningPreview.committed_move_already_realized(
		dir2, dir2.board, u2_id, GameEnums.MoveTiming.PRE_ACTION, autorun_act, slots_route, AUTORUN_DEST,
	):
		failures.append("ActionRangeRegression premove_no_boomerang: autorun move not marked realized after arrival")
	# Verify move preview clears before unit starts walking (visual cell still at start or mid-walk)
	var mid_walk_leg: Array = inp2.display_committed_move_route_leg(
		u2_id, GameEnums.MoveTiming.PRE_ACTION, KNIGHT_START,
	)
	if not mid_walk_leg.is_empty():
		failures.append(
			"ActionRangeRegression premove_no_boomerang: move preview leg not cleared before unit starts walking (mid-walk visual cell %s): %s"
			% [KNIGHT_START, mid_walk_leg],
		)

	# Verify autorun move does NOT animate a second time during execution phase
	var unit_layer := TacticalUnitLayer.new()
	unit_layer._board = dir2.board
	unit_layer._phase = CombatDirector.Phase.EXECUTING
	var exec_move_event := SimEvent.make(
		GameEnums.SimEventType.UNIT_MOVED,
		{
			"actor": u2_id,
			"from": KNIGHT_START,
			"to": AUTORUN_DEST,
			"move_timing": GameEnums.MoveTiming.PRE_ACTION,
			"presentation_anim": GameEnums.PresentationAnim.RUN,
		},
	)
	if unit_layer._should_animate_move(exec_move_event):
		failures.append(
			"ActionRangeRegression premove_no_boomerang: auto run pre-move must NOT animate during execution phase (plays twice)",
		)
	unit_layer.free()

