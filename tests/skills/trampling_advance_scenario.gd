class_name TramplingAdvanceScenarioTest
extends RefCounted

## Trampling Advance checklist — metadata here; production drag/commit/sim owned by TramplingAdvanceE2ETest.


static func run_all(failures: Array[String]) -> void:
	_phase1_select(failures)
	_phase2_3_arm_and_paint(failures)
	_phase4_hover_end(failures)
	_phase5_commit(failures)
	_phase6_execute(failures)
	_phase7_premove_then_trample(failures)


static func _trample_ability(fix: Dictionary) -> AbilityData:
	var idx: int = PlanningChecklistHarness.ability_index(
		fix.knight, PlanningChecklistHarness.TRAMPLE_ID,
	)
	return fix.knight.active_abilities[idx] if idx >= 0 else null


static func _arm_awaiting(fix: Dictionary) -> bool:
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
	input._drag_unit_id = fix.unit.id
	input._drag_unit_was_selected = true
	input._drag_route = route.duplicate()
	input._drag_last_free = PlanningChecklistHarness.TRAMPLE_END
	input.dragging = true
	PlanningChecklistHarness.hover(fix, PlanningChecklistHarness.TRAMPLE_END)


static func _full_route_from(start: Vector2i) -> Array[Vector2i]:
	return [start, PlanningChecklistHarness.TRAMPLE_ROUTE[0], PlanningChecklistHarness.TRAMPLE_ROUTE[1]]


static func _phase1_select(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_trample_board()
	var ability: AbilityData = _trample_ability(fix)
	if ability == null:
		PlanningChecklistHarness.assert_fail(failures, "trample/phase1", "Trampling Advance missing")
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


static func _phase2_3_arm_and_paint(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_trample_board()
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
