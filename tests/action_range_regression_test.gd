class_name ActionRangeRegressionTest
extends RefCounted

## Regression matrix — red action-range tiles (owner bugs from manual QA).
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


static func run_all(failures: Array[String]) -> void:
	var tests: Array[Callable] = [
		_test_show_move_hover_without_action_slot,
		_test_show_enemy_bash_with_committed_premove,
		_test_show_red_anchor_follows_stand_not_knight_start,
		_test_bowling_enemy_hover_red_at_origin,
		_test_bowling_enemy_hover_not_bash_route,
		_test_bowling_dash_only_tiles_not_blue,
		_test_bowling_dash_only_click_no_premove,
		_test_hide_red_after_commit_run_icon_shield_bash,
		_test_hide_red_after_commit_run_icon_bowling,
		_test_hide_red_committed_run_timeline_bowling,
		_test_hide_red_committed_run_interior_hover_bowling,
		_test_hide_no_ability_selected,
		_test_show_awaiting_trample,
		_test_hover_step_updates_stand_and_red_tiles,
		_test_visibility_gate_parity_show,
		_test_visibility_gate_parity_hide,
	]
	var names: PackedStringArray = [
		"show_move_hover_no_action_slot",
		"show_enemy_bash_committed_premove",
		"show_red_anchor_on_stand",
		"bowling_enemy_hover_red",
		"bowling_enemy_hover_not_bash",
		"bowling_dash_only_not_blue",
		"bowling_dash_only_no_premove_click",
		"hide_after_commit_run_icon_bash",
		"hide_after_commit_run_icon_bowling",
		"hide_committed_run_timeline_bowling",
		"hide_committed_run_interior_hover_bowling",
		"hide_no_ability",
		"show_awaiting_trample",
		"hover_step_updates_stand",
		"parity_gate_show",
		"parity_gate_hide",
	]
	for i: int in range(tests.size()):
		print("[RUN] action_range/%s" % names[i])
		tests[i].call(failures)
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
	input.on_hover_moved(cell)
	input._flush_hover_heavy_sync()
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


static func _flush_deferred_planning_refresh(fix: Dictionary) -> void:
	var director: CombatDirector = fix.director
	var overlay: TacticalPlanningOverlay = fix.get("overlay", null) as TacticalPlanningOverlay
	var input: CombatPlanningInput = fix.input
	director.flush_plan_refresh_signals_if_pending()
	if overlay != null:
		overlay._flush_hover_recompute()
	if input != null:
		input._flush_hover_preview_refresh()


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
	if not (slots.get("action", []) as Array).is_empty():
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
	_assert_contract(
		failures, "show_enemy_bash_committed_premove", fix, overlay, input,
		ENEMY_POS, ability, true, BASH_APPROACH,
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
	_hover_sync(input, overlay, ENEMY_POS)
	if input.awaiting_targeting_active():
		failures.append(
			"ActionRangeRegression bowling_enemy_hover_red: enemy hover preview must not require self-arm",
		)
	if not input.is_live_preview_active():
		failures.append(
			"ActionRangeRegression bowling_enemy_hover_red: live preview required on enemy hover",
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
	var route: Array[Vector2i] = overlay.awaiting_movement_hover_route_cells()
	if route.size() < 2:
		failures.append(
			"ActionRangeRegression bowling_enemy_hover_red: blue dash route must be drawable, got %s"
			% str(route),
		)
	elif route[0] != KNIGHT_START or route[route.size() - 1] != ENEMY_POS:
		failures.append(
			"ActionRangeRegression bowling_enemy_hover_red: blue dash route must span origin to enemy, got %s"
			% str(route),
		)
	var pushes: Array = input.preview_state.preview_pushes.get(fix.enemy.id, [])
	if pushes.is_empty():
		failures.append(
			"ActionRangeRegression bowling_enemy_hover_red: orange push preview must show on enemy hover",
		)


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
	if not overlay.awaiting_movement_hover_route_cells().is_empty():
		failures.append(
			"ActionRangeRegression bowling_enemy_hover_not_bash: bash enemy hover must not use awaiting dash route",
		)


static func _test_bowling_dash_only_tiles_not_blue(failures: Array[String]) -> void:
	const KNIGHT := Vector2i(5, 5)
	const ENEMY := Vector2i(6, 5)
	const DASH_ONLY_A := Vector2i(7, 5)
	const DASH_ONLY_B := Vector2i(8, 5)
	var fix: Dictionary = PlanningQAGateTest._planning_fixture(KNIGHT, ENEMY)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = PlanningQAGateTest._wire_overlay(fix)
	var bowling_idx: int = PlanningQAGateTest._ability_index(fix.knight, BOWLING_CHARGE_ID)
	if bowling_idx < 0:
		failures.append("ActionRangeRegression bowling_dash_only_not_blue: Bowling Charge missing")
		return
	director.selected_ability_index = bowling_idx
	_hover_sync(input, overlay, KNIGHT)
	for dash_tile: Vector2i in [DASH_ONLY_A, DASH_ONLY_B]:
		if overlay.is_hover_move_tile(dash_tile):
			failures.append(
				"ActionRangeRegression bowling_dash_only_not_blue: dash-only tile %s must not be blue move"
				% dash_tile,
			)
	_hover_sync(input, overlay, DASH_ONLY_A)
	var icon: String = input.compute_hover_action_icon(DASH_ONLY_A)
	if icon != PlanningIcons.GLYPH_NULL:
		failures.append(
			"ActionRangeRegression bowling_dash_only_not_blue: dash-only hover cursor must be null, got %s"
			% icon,
		)
	var ability: AbilityData = PlanningQAGateTest._knight_ability(BOWLING_CHARGE_ID)
	if not AbilitySystem.planning_is_valid_awaiting_endpoint(KNIGHT, DASH_ONLY_A, ability):
		failures.append(
			"ActionRangeRegression bowling_dash_only_not_blue: fixture tile %s must be valid dash endpoint"
			% DASH_ONLY_A,
		)


static func _test_bowling_dash_only_click_no_premove(failures: Array[String]) -> void:
	const KNIGHT := Vector2i(5, 5)
	const ENEMY := Vector2i(6, 5)
	const DASH_ONLY := Vector2i(8, 5)
	var fix: Dictionary = PlanningQAGateTest._planning_fixture(KNIGHT, ENEMY)
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var overlay: TacticalPlanningOverlay = PlanningQAGateTest._wire_overlay(fix)
	var bowling_idx: int = PlanningQAGateTest._ability_index(fix.knight, BOWLING_CHARGE_ID)
	if bowling_idx < 0:
		failures.append("ActionRangeRegression bowling_dash_only_no_premove_click: Bowling Charge missing")
		return
	director.selected_ability_index = bowling_idx
	_hover_sync(input, overlay, DASH_ONLY)
	var hover_slots: Dictionary = input._final_commit_slots_for_click_at_cell(1, DASH_ONLY, Vector2.ZERO)
	if not (hover_slots.get("pre", []) as Array).is_empty():
		failures.append(
			"ActionRangeRegression bowling_dash_only_no_premove_click: dash-only hover must not build premove",
		)
	if (hover_slots.get("action", []) as Array).is_empty():
		failures.append(
			"ActionRangeRegression bowling_dash_only_no_premove_click: dash-only hover must build action preview",
		)
	var arm_slots: Dictionary = input._final_commit_slots_for_click_at_cell(1, KNIGHT, Vector2.ZERO)
	if not director.commit_from_slots(1, arm_slots):
		failures.append(
			"ActionRangeRegression bowling_dash_only_no_premove_click: arm commit failed",
		)
	_hover_sync(input, overlay, DASH_ONLY)
	if input.compute_hover_action_icon(DASH_ONLY) != PlanningIcons.GLYPH_NULL:
		failures.append(
			"ActionRangeRegression bowling_dash_only_no_premove_click: armed dash-only cursor must be null",
		)
	var armed_slots: Dictionary = input._final_commit_slots_for_click_at_cell(1, DASH_ONLY, Vector2.ZERO)
	if not (armed_slots.get("pre", []) as Array).is_empty():
		failures.append(
			"ActionRangeRegression bowling_dash_only_no_premove_click: armed dash-only click must not commit premove",
		)
	if (armed_slots.get("action", []) as Array).is_empty():
		failures.append(
			"ActionRangeRegression bowling_dash_only_no_premove_click: armed dash-only click must build action",
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
	_flush_deferred_planning_refresh(fix)
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
	_flush_deferred_planning_refresh(fix)
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
	_flush_deferred_planning_refresh(fix)
	director.select_ability(bowling_idx)
	input.call("_run_ability_settled_refresh")
	_flush_deferred_planning_refresh(fix)
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
