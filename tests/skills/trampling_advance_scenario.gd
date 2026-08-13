class_name TramplingAdvanceScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Trampling Advance â€” MOVE + TRAMPLE + PUSH on tile target.
## Globals: EffectType.MOVE, TRAMPLE, PUSH via AbilitySystem.
## Tier 1: planning E2E harness (Knight QA â€” not planning gate).


static func run_all(failures: Array[String]) -> void:
	PlanningDragE2EHarness.cleanup_all()
	_sim_contract(failures)
	_phase1_select(failures)
	_phase2_hover_empty_unarmed(failures)
	_phase2_unarmed_mouse_waypoints(failures)
	_phase2_3_arm_and_paint(failures)
	_phase4_hover_end(failures)
	_phase5_commit(failures)
	_phase6_execute(failures)
	_phase7_premove_then_trample(failures)


static func _sim_contract(failures: Array[String]) -> void:
	var trample: AbilityData = _KnightQaHarness.factory_ability(&"knight_trampling_advance")
	_KnightQaHarness.assert_true(
		failures, "trample/contract/move",
		_KnightQaHarness.ability_has_effect(trample, GameEnums.EffectType.MOVE, false),
	)
	_KnightQaHarness.assert_true(
		failures, "trample/contract/trample",
		_KnightQaHarness.ability_has_effect(trample, GameEnums.EffectType.TRAMPLE, false),
	)
	_KnightQaHarness.assert_true(
		failures, "trample/contract/push",
		_KnightQaHarness.ability_has_effect(trample, GameEnums.EffectType.PUSH, false),
	)
	_KnightQaHarness.run_trample_base_sim(failures)
	_KnightQaHarness.run_trample_end_on_occupied_sim(failures)


static func _fixture_unit(fix: Dictionary) -> UnitState:
	if fix.has("unit") and fix.unit != null:
		return fix.unit as UnitState
	if fix.has("knight") and fix.knight != null:
		return fix.knight as UnitState
	return null


static func _trample_ability(fix: Dictionary) -> AbilityData:
	var unit: UnitState = _fixture_unit(fix)
	if unit == null:
		return null
	var idx: int = PlanningChecklistHarness.ability_index(
		unit, PlanningChecklistHarness.TRAMPLE_ID,
	)
	return unit.active_abilities[idx] if idx >= 0 else null


static func _arm_awaiting(fix: Dictionary) -> bool:
	if PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.TRAMPLE_ID) < 0:
		return false
	var stand: Vector2i = PlanningChecklistHarness.projected_unit(fix, 1).position
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	var arm_slots: Dictionary = input._final_commit_slots_for_interaction(1, stand)
	if TramplingAdvanceE2ETest._commit_slots_invalid(arm_slots):
		return false
	if not director.commit_from_slots(1, arm_slots):
		return false
	director.flush_plan_refresh_signals_if_pending()
	return input.awaiting_targeting_active()


static func _paint_trample_route(fix: Dictionary, route: Array[Vector2i]) -> void:
	var input: CombatPlanningInput = fix.input
	var unit: UnitState = _fixture_unit(fix)
	input._drag_unit_id = unit.id
	input._drag_unit_was_selected = true
	input._drag_route = route.duplicate()
	input._drag_last_free = PlanningChecklistHarness.TRAMPLE_END
	input.dragging = true
	PlanningChecklistHarness.hover(fix, PlanningChecklistHarness.TRAMPLE_END)


static func _full_route_from(start: Vector2i) -> Array[Vector2i]:
	return [start, PlanningChecklistHarness.TRAMPLE_ROUTE[0], PlanningChecklistHarness.TRAMPLE_ROUTE[1]]


static func _phase1_select(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_trample_board()
	fix.director.auto_run = true
	if PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.TRAMPLE_ID) < 0:
		PlanningChecklistHarness.assert_fail(failures, "trample/phase1", "Trampling Advance missing")
		return
	var ability: AbilityData = _trample_ability(fix)
	if ability == null:
		PlanningChecklistHarness.assert_fail(failures, "trample/phase1", "Trampling Advance missing after select")
		return
	PlanningChecklistHarness.assert_ability_kind_class(failures, "trample/phase1", ability)
	PlanningChecklistHarness.assert_eq_int(
		failures, "trample/phase1/ap_cost",
		ability.action_point_cost, 1,
	)
	PlanningChecklistHarness.assert_true(
		failures, "trample/phase1/not_mov_skill",
		not ability.is_movement_kind(),
		"Trample must not be MOVEMENT_SKILL (Bible: class active)",
	)
	PlanningChecklistHarness.assert_eq_int(failures, "trample/phase1/ap_pool", fix.unit.ability.points_left, 1)


static func _phase2_hover_empty_unarmed(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_trample_board()
	fix.director.auto_run = true
	if PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.TRAMPLE_ID) < 0:
		PlanningChecklistHarness.assert_fail(failures, "trample/phase2_unarmed", "Trampling Advance missing")
		return
	if fix.input.awaiting_targeting_active():
		PlanningChecklistHarness.assert_fail(
			failures, "trample/phase2_unarmed",
			"selecting trample must not enter awaiting until self-tile arm",
		)
		return
	var hover_walk: Vector2i = PlanningChecklistHarness.TRAMPLE_ROUTE[0]
	var in_range_endpoint: Vector2i = Vector2i(4, 4)
	PlanningChecklistHarness.hover(fix, in_range_endpoint)
	var in_range_slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, in_range_endpoint)
	PlanningChecklistHarness.assert_true(
		failures, "trample/phase2_unarmed/in_range_pre",
		not (in_range_slots.get("pre", []) as Array).is_empty(),
		"in-range trample endpoint hover must still be pre-move before arm, got %s"
		% str(in_range_slots),
	)
	PlanningChecklistHarness.assert_true(
		failures, "trample/phase2_unarmed/in_range_no_committed_action",
		(in_range_slots.get("action", []) as Array).is_empty()
		or (
			(in_range_slots.get("action", []) as Array)[0] is TimelineAction
			and ((in_range_slots.get("action", []) as Array)[0] as TimelineAction).awaiting_target
		),
		"in-range hover must not commit trample action before arm, got %s" % str(in_range_slots),
	)
	PlanningChecklistHarness.hover(fix, hover_walk)
	PlanningChecklistHarness.assert_eq_cell(
		failures, "trample/phase2_unarmed/ghost_walk",
		PlanningChecklistHarness.preview_unit_pos(fix, 1), hover_walk,
	)
	var path: Array[Vector2i] = PlanningChecklistHarness.preview_path(fix, 1)
	PlanningChecklistHarness.assert_true(
		failures, "trample/phase2_unarmed/path_walk",
		path.size() >= 2
		and path[0] == PlanningChecklistHarness.TRAMPLE_START
		and path[-1] == hover_walk,
		"path must be %s -> %s, got %s"
		% [PlanningChecklistHarness.TRAMPLE_START, hover_walk, path],
	)
	var walk_slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, hover_walk)
	var pre_moves: Array = walk_slots.get("pre", []) as Array
	var actions: Array = walk_slots.get("action", []) as Array
	PlanningChecklistHarness.assert_true(
		failures, "trample/phase2_unarmed/pre_move",
		not pre_moves.is_empty(),
		"unarmed empty-tile hover must populate pre-move, got slots=%s" % str(walk_slots),
	)
	PlanningChecklistHarness.assert_true(
		failures, "trample/phase2_unarmed/no_action",
		actions.is_empty(),
		"unarmed empty-tile hover must not commit trample to action, got slots=%s" % str(walk_slots),
	)
	PlanningChecklistHarness.assert_cursor_contains(
		failures, "trample/phase2_unarmed/cursor_walk", fix, walk_slots, PlanningIcons.GLYPH_WALK,
	)


static func _phase2_unarmed_mouse_waypoints(failures: Array[String]) -> void:
	TramplingAdvanceE2ETest._test_unarmed_hover_follows_mouse_waypoints(failures)


static func _phase2_3_arm_and_paint(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_trample_board()
	fix.director.auto_run = true
	if not _arm_awaiting(fix):
		PlanningChecklistHarness.assert_fail(failures, "trample/phase2", "arm awaiting failed")
		return
	var route: Array[Vector2i] = _full_route_from(PlanningChecklistHarness.TRAMPLE_START)
	_paint_trample_route(fix, route)
	PlanningChecklistHarness.assert_true(
		failures, "trample/phase3/paint_order",
		fix.input._drag_route == route,
		"painted route must be %s got %s" % [route, fix.input._drag_route],
	)
	var ability: AbilityData = _trample_ability(fix)
	PlanningChecklistHarness.assert_red_contract(
		failures, "trample/phase3/red_while_awaiting", fix, ability, true,
	)


static func _phase4_hover_end(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_trample_board()
	fix.director.auto_run = true
	if not _arm_awaiting(fix):
		PlanningChecklistHarness.assert_fail(failures, "trample/phase4", "arm awaiting failed")
		return
	var route: Array[Vector2i] = _full_route_from(PlanningChecklistHarness.TRAMPLE_START)
	_paint_trample_route(fix, route)
	PlanningChecklistHarness.assert_eq_cell(
		failures, "trample/phase4/route_end",
		fix.input._drag_route[fix.input._drag_route.size() - 1], PlanningChecklistHarness.TRAMPLE_END,
	)
	PlanningChecklistHarness.assert_eq_cell(
		failures, "trample/phase4/hover_dest",
		fix.input._drag_last_free, PlanningChecklistHarness.TRAMPLE_END,
	)


static func _phase5_commit(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_trample_board()
	fix.director.auto_run = true
	if not _arm_awaiting(fix):
		PlanningChecklistHarness.assert_fail(failures, "trample/phase5", "arm awaiting failed")
		return
	var route: Array[Vector2i] = _full_route_from(PlanningChecklistHarness.TRAMPLE_START)
	TramplingAdvanceE2ETest._paint_drag_route(fix.input, fix.unit, route, PlanningChecklistHarness.TRAMPLE_END)
	var slots: Dictionary = TramplingAdvanceE2ETest._commit_drag_route(
		fix.input, fix.director, PlanningChecklistHarness.TRAMPLE_END,
	)
	PlanningChecklistHarness.assert_true(
		failures, "trample/phase5/commit",
		not slots.is_empty() and not PlanningChecklistHarness._slots_invalid(slots),
		"trample drag commit must succeed",
	)
	var action: TimelineAction = TramplingAdvanceE2ETest._committed_trample_action(fix.director)
	PlanningChecklistHarness.assert_true(
		failures, "trample/phase5/action", action != null,
		"trample action must be committed",
	)
	if action != null:
		PlanningChecklistHarness.assert_true(
			failures, "trample/phase5/waypoints",
			action.waypoints == PlanningChecklistHarness.TRAMPLE_ROUTE,
			"waypoints %s expected %s" % [action.waypoints, PlanningChecklistHarness.TRAMPLE_ROUTE],
		)
	PlanningChecklistHarness.assert_eq_int(
		failures, "trample/phase5/ap_after",
		PlanningChecklistHarness.projected_unit(fix, 1).ability.points_left, 0,
	)


static func _phase6_execute(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_trample_board()
	fix.director.auto_run = true
	if not _arm_awaiting(fix):
		PlanningChecklistHarness.assert_fail(failures, "trample/phase6", "arm awaiting failed")
		return
	var route: Array[Vector2i] = _full_route_from(PlanningChecklistHarness.TRAMPLE_START)
	TramplingAdvanceE2ETest._paint_drag_route(fix.input, fix.unit, route, PlanningChecklistHarness.TRAMPLE_END)
	if TramplingAdvanceE2ETest._commit_drag_route(
		fix.input, fix.director, PlanningChecklistHarness.TRAMPLE_END,
	).is_empty():
		PlanningChecklistHarness.assert_fail(failures, "trample/phase6", "trample commit failed")
		return
	var result: SimResult = PlanningChecklistHarness.simulate_committed(fix.director)
	var visited: Array[Vector2i] = [PlanningChecklistHarness.TRAMPLE_START]
	for ev: SimEvent in result.events:
		if ev.type != GameEnums.SimEventType.UNIT_MOVED:
			continue
		if int(ev.data.get("actor", -1)) != 1:
			continue
		PlanningChecklistHarness.assert_eq_int(
			failures,
			"trample/phase6/presentation_anim",
			int(ev.data.get("presentation_anim", GameEnums.PresentationAnim.AUTO)),
			GameEnums.PresentationAnim.RUN,
		)
		var path_v: Variant = ev.data.get("path", [])
		if path_v is Array and not (path_v as Array).is_empty():
			for step: Variant in path_v:
				if step is Vector2i:
					visited.append(step)
			continue
		var to_cell: Variant = ev.data.get("to")
		if to_cell is Vector2i:
			visited.append(to_cell)
	var expected: Array[Vector2i] = [
		PlanningChecklistHarness.TRAMPLE_START,
		PlanningChecklistHarness.TRAMPLE_ROUTE[0],
		PlanningChecklistHarness.TRAMPLE_ROUTE[1],
	]
	PlanningChecklistHarness.assert_true(
		failures, "trample/phase6/order",
		visited == expected,
		"sim must visit %s in order, got %s" % [expected, visited],
	)
	PlanningChecklistHarness.assert_player_turn_ap_spent(
		failures, "trample/phase6/ap_spent", fix.director, 1, 0,
	)


static func _phase7_premove_then_trample(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_trample_board()
	fix.input.force_basic_movement = true
	fix.director.selected_ability_index = -1
	var pre_dest: Vector2i = PlanningChecklistHarness.TRAMPLE_ROUTE[0]
	PlanningChecklistHarness.commit_production(fix, pre_dest)
	PlanningChecklistHarness.select_ability(fix, PlanningChecklistHarness.TRAMPLE_ID)
	if not _arm_awaiting(fix):
		PlanningChecklistHarness.assert_fail(failures, "trample/phase7", "arm after pre-move failed")
		return
	PlanningChecklistHarness.assert_eq_cell(
		failures, "trample/phase7/stand",
		PlanningChecklistHarness.projected_unit(fix, 1).position, pre_dest,
	)
	var route: Array[Vector2i] = [pre_dest, PlanningChecklistHarness.TRAMPLE_ROUTE[1]]
	TramplingAdvanceE2ETest._paint_drag_route(fix.input, fix.unit, route, PlanningChecklistHarness.TRAMPLE_END)
	TramplingAdvanceE2ETest._commit_drag_route(fix.input, fix.director, PlanningChecklistHarness.TRAMPLE_END)
	var action: TimelineAction = TramplingAdvanceE2ETest._committed_trample_action(fix.director)
	PlanningChecklistHarness.assert_true(
		failures, "trample/phase7/committed", action != null,
		"trample must remain committed after second drag",
	)
