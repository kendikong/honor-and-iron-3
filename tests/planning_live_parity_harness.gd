class_name PlanningLiveParityHarness
extends RefCounted

const _QaGate := preload("res://tests/planning_qa_gate_test.gd")

## Headless mirror of live_planning_scene_test preview/commit parity asserts.
## Same slots, overlay display paths, and k4 run-loop checks — fixture board only.

const _K1_BASH_ROUTE: Array[Vector2i] = [
	PlanningChecklistHarness.KNIGHT_START,
	PlanningChecklistHarness.BASH_HOVER_WALK,
	PlanningChecklistHarness.BASH_APPROACH,
]
const _K1_BASH_WAYPOINTS: Array[Vector2i] = [
	PlanningChecklistHarness.BASH_HOVER_WALK,
	PlanningChecklistHarness.BASH_APPROACH,
]


static func run_k1_bash_live_parity(
	fix: Dictionary,
	failures: Array[String],
	k1_id: int,
	e_bash_id: int,
	bash: AbilityData,
	label_prefix: String = "bible/k1",
) -> void:
	fix.director.auto_run = true
	fix.input.auto_use_skill_after_move = true
	PlanningChecklistHarness.select_ability_for_unit(fix, k1_id, PlanningChecklistHarness.SHIELD_BASH_ID)

	PlanningChecklistHarness.hover(fix, PlanningChecklistHarness.ENEMY_POS)
	var selection_pre: Dictionary = capture_preview_intent(
		fix, k1_id, PlanningChecklistHarness.ENEMY_POS, false,
	)
	if not commit_from_preview_intent(
		fix, k1_id, selection_pre, "%s/selection/release" % label_prefix, failures,
	):
		return
	assert_k1_bash_committed(fix, failures, k1_id, "%s/selection" % label_prefix, false)
	var selection_surface: Dictionary = PlanningChecklistHarness.mode_commit_surface(fix, k1_id)
	PlanningChecklistHarness.assert_red_contract(
		failures,
		"%s/selection/post_commit" % label_prefix,
		fix,
		bash,
		false,
		PlanningChecklistHarness.BASH_APPROACH,
		k1_id,
	)
	PlanningChecklistHarness.assert_enemy_live_unchanged(
		failures,
		"%s/selection/post_commit" % label_prefix,
		fix,
		e_bash_id,
		PlanningChecklistHarness.E_BASH_CELL,
	)
	var bashed_sel: UnitState = PlanningChecklistHarness.projected_unit(fix, e_bash_id)
	if bashed_sel != null and bashed_sel.position.x <= PlanningChecklistHarness.E_BASH_CELL.x:
		PlanningChecklistHarness.assert_fail(
			failures,
			"%s/selection/post_commit" % label_prefix,
			"projected enemy must show bash push (got %s)" % bashed_sel.position,
		)

	var failure_count_before_undo: int = failures.size()
	undo_until_unit_clear(fix, failures, k1_id, PlanningChecklistHarness.KNIGHT_START, label_prefix)
	if failures.size() > failure_count_before_undo:
		return

	PlanningChecklistHarness.select_ability_for_unit(fix, k1_id, PlanningChecklistHarness.SHIELD_BASH_ID)
	var waypoint_pre: Dictionary = paint_route_and_capture_pre_intent(
		fix,
		k1_id,
		_K1_BASH_ROUTE,
		PlanningChecklistHarness.ENEMY_POS,
		true,
		"%s/waypoint" % label_prefix,
		failures,
	)
	if waypoint_pre.is_empty():
		PlanningChecklistHarness.assert_fail(
			failures, "%s/waypoint" % label_prefix, "waypoint pre-intent capture failed",
		)
		return
	if not commit_from_preview_intent(fix, k1_id, waypoint_pre, "%s/waypoint/release" % label_prefix, failures):
		return
	assert_k1_bash_committed(fix, failures, k1_id, "%s/waypoint" % label_prefix, true)

	var drag_surface: Dictionary = PlanningChecklistHarness.mode_commit_surface(fix, k1_id)
	PlanningChecklistHarness.assert_mode_commit_parity(
		failures, "k1/selection", selection_surface, "k1/waypoint", drag_surface,
	)
	assert_committed_display_ratifies_pre_commit(
		fix, failures, k1_id, waypoint_pre, "%s/waypoint" % label_prefix,
	)

	PlanningChecklistHarness.assert_red_contract(
		failures,
		"%s/waypoint/post_commit" % label_prefix,
		fix,
		bash,
		false,
		PlanningChecklistHarness.BASH_APPROACH,
		k1_id,
	)
	PlanningChecklistHarness.assert_enemy_live_unchanged(
		failures,
		"%s/waypoint/post_commit" % label_prefix,
		fix,
		e_bash_id,
		PlanningChecklistHarness.E_BASH_CELL,
	)
	var bashed: UnitState = PlanningChecklistHarness.projected_unit(fix, e_bash_id)
	if bashed != null and bashed.position.x <= PlanningChecklistHarness.E_BASH_CELL.x:
		PlanningChecklistHarness.assert_fail(
			failures,
			"%s/waypoint/preview_push" % label_prefix,
			"projected enemy must show bash push (got %s)" % bashed.position,
		)


static func run_k4_run_live_parity(
	fix: Dictionary,
	failures: Array[String],
	k4_id: int,
	bowling: AbilityData,
	label_prefix: String = "bible/k4",
) -> void:
	fix.director.auto_run = true
	fix.input.auto_use_skill_after_move = false
	PlanningChecklistHarness.select_ability_for_unit(
		fix, k4_id, PlanningChecklistHarness.BOWLING_CHARGE_ID,
	)
	enter_k4_auto_run_paint_mode(fix, k4_id)
	run_k4_selection_route(fix, failures, k4_id, bowling, "%s/selection" % label_prefix)
	assert_k4_run_committed(fix, failures, k4_id, "%s/selection" % label_prefix)
	var selection_surface: Dictionary = PlanningChecklistHarness.mode_commit_surface(fix, k4_id)

	undo_until_unit_clear(fix, failures, k4_id, PlanningChecklistHarness.K4_START, label_prefix)
	enter_k4_auto_run_paint_mode(fix, k4_id)
	run_k4_drag_route(fix, failures, k4_id, bowling, "%s/drag" % label_prefix)
	assert_k4_run_committed(fix, failures, k4_id, "%s/drag" % label_prefix)
	var drag_surface: Dictionary = PlanningChecklistHarness.mode_commit_surface(fix, k4_id)
	PlanningChecklistHarness.assert_mode_commit_parity(
		failures, "k4/selection", selection_surface, "k4/drag", drag_surface,
	)

	PlanningChecklistHarness.hover(fix, PlanningChecklistHarness.K4_RUN_TRIGGER)
	PlanningChecklistHarness.assert_red_contract(
		failures,
		"%s/drag/post_commit" % label_prefix,
		fix,
		bowling,
		false,
		PlanningChecklistHarness.K4_RUN_TRIGGER,
		k4_id,
	)


static func enter_k4_auto_run_paint_mode(fix: Dictionary, unit_id: int) -> void:
	fix.director.select_unit(unit_id)
	fix.input.force_basic_movement = false
	PlanningChecklistHarness.wait_ability_settle_sync(fix)


static func run_k4_selection_route(
	fix: Dictionary,
	failures: Array[String],
	unit_id: int,
	bowling: AbilityData,
	label_prefix: String,
) -> void:
	var route: Array[Vector2i] = PlanningChecklistHarness.K4_DETOUR_PLUS_RUN_ROUTE
	PlanningChecklistHarness.select_unit(fix, unit_id, route[0])
	PlanningChecklistHarness.wait_ability_settle_sync(fix)
	for step_index: int in range(1, route.size()):
		var cell: Vector2i = route[step_index]
		var step_label: String = "%s/step_%d" % [label_prefix, step_index]
		var expected_path: Array[Vector2i] = route.slice(0, step_index + 1)
		var from_cell: Vector2i = route[step_index - 1]
		PlanningChecklistHarness.sweep_to_cell(fix, cell, from_cell)
		assert_not_dragging(fix, failures, step_label)
		assert_preview_path_equals(fix, failures, unit_id, expected_path, "%s/path" % step_label)
		if cell == Vector2i(4, 2):
			PlanningChecklistHarness.wait_ability_settle_sync(fix)
			assert_k4_walk_loop_preview(fix, failures, unit_id, bowling, cell, "%s/walk_loop" % step_label)
		elif cell == PlanningChecklistHarness.K4_RUN_TRIGGER:
			PlanningChecklistHarness.wait_ability_settle_sync(fix)
			assert_k4_run_loop_preview(fix, failures, unit_id, "%s/run_trigger" % step_label)

	var pre_intent: Dictionary = capture_preview_intent(
		fix, unit_id, PlanningChecklistHarness.K4_RUN_TRIGGER, false,
	)
	if not commit_from_preview_intent(
		fix, unit_id, pre_intent, "%s/release" % label_prefix, failures,
	):
		return
	assert_not_dragging(fix, failures, "%s/after_release" % label_prefix)
	var drag_route: Array[Vector2i] = fix.input.get_drag_route()
	if not drag_route.is_empty():
		PlanningChecklistHarness.assert_fail(
			failures,
			label_prefix,
			"selection mode must not leave drag route %s" % str(drag_route),
		)


static func run_k4_drag_route(
	fix: Dictionary,
	failures: Array[String],
	unit_id: int,
	bowling: AbilityData,
	label_prefix: String,
) -> void:
	var route: Array[Vector2i] = PlanningChecklistHarness.K4_DETOUR_PLUS_RUN_ROUTE
	var unit: UnitState = fix.board.get_unit_by_id(unit_id)
	if unit == null:
		PlanningChecklistHarness.assert_fail(failures, label_prefix, "k4 unit missing")
		return
	PlanningChecklistHarness.select_unit(fix, unit_id, route[0])
	PlanningDragE2EHarness.begin_drag_route(fix, [route[0]])
	for step_index: int in range(1, route.size()):
		var cell: Vector2i = route[step_index]
		var step_label: String = "%s/step_%d" % [label_prefix, step_index]
		hop_drag_to_cell(fix, unit_id, cell)
		var expected_path: Array[Vector2i] = route.slice(0, step_index + 1)
		assert_drag_route_equals(fix, failures, expected_path, "%s/drag_route_%d" % [label_prefix, step_index])
		assert_preview_path_equals(fix, failures, unit_id, expected_path, "%s/preview_path_%d" % [label_prefix, step_index])
		if cell == Vector2i(4, 2):
			PlanningChecklistHarness.wait_ability_settle_sync(fix)
			assert_k4_walk_loop_preview(fix, failures, unit_id, bowling, cell, "%s/walk_loop_end" % step_label)
		elif cell == PlanningChecklistHarness.K4_RUN_TRIGGER:
			PlanningChecklistHarness.wait_ability_settle_sync(fix)
			assert_k4_run_loop_preview(fix, failures, unit_id, "%s/run_trigger" % label_prefix)

	assert_drag_route_equals(fix, failures, route, "%s/route" % label_prefix)
	assert_preview_path_equals(
		fix, failures, unit_id, fix.input.get_drag_route(), "%s/pre_release" % label_prefix,
	)
	var pre_intent: Dictionary = capture_preview_intent(
		fix, unit_id, PlanningChecklistHarness.K4_RUN_TRIGGER, true,
	)
	PlanningDragE2EHarness.release_at(fix, PlanningChecklistHarness.K4_RUN_TRIGGER)
	PlanningChecklistHarness.flush_planning(fix)
	assert_commit_ratifies_preview(
		fix, failures, unit_id, pre_intent, "%s/release" % label_prefix,
	)


static func paint_route_and_capture_pre_intent(
	fix: Dictionary,
	unit_id: int,
	route: Array[Vector2i],
	release_cell: Vector2i,
	use_drop: bool,
	label: String,
	failures: Array[String],
) -> Dictionary:
	var unit: UnitState = fix.board.get_unit_by_id(unit_id)
	if unit == null:
		PlanningChecklistHarness.assert_fail(failures, label, "unit %d missing" % unit_id)
		return {}
	PlanningChecklistHarness.select_unit(fix, unit_id, route[0])
	PlanningDragE2EHarness.begin_drag_route(fix, [route[0]])
	for step_index: int in range(1, route.size()):
		hop_drag_to_cell(fix, unit_id, route[step_index])
		var expected_path: Array[Vector2i] = route.slice(0, step_index + 1)
		assert_drag_route_equals(
			fix, failures, expected_path, "%s/drag_route_%d" % [label, step_index],
		)
		assert_preview_path_equals(
			fix, failures, unit_id, expected_path, "%s/path_%d" % [label, step_index],
		)
	PlanningChecklistHarness.hover(fix, release_cell)
	if use_drop:
		assert_preview_path_equals(fix, failures, unit_id, route, "%s/pre_release/path" % label)
	return capture_preview_intent(fix, unit_id, release_cell, use_drop)


static func hop_drag_to_cell(fix: Dictionary, unit_id: int, cell: Vector2i) -> void:
	var input: CombatPlanningInput = fix.input
	input.set_qa_pointer_grid_cell(cell)
	if input._intent_state != null:
		input._intent_state.set_hover_coord(cell)
	var local: Vector2 = input._mouse_local_for_facing()
	if input.dragging:
		input.update_drag(local)
	elif input.is_drag_armed():
		input.try_activate_drag(local)
		if input.dragging:
			input.update_drag(local)
	PlanningChecklistHarness.flush_planning(fix)


static func capture_preview_intent(
	fix: Dictionary,
	unit_id: int,
	cell: Vector2i,
	use_drop: bool,
) -> Dictionary:
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	PlanningChecklistHarness.flush_planning(fix)
	var slots: Dictionary = commit_slots_for_interaction(fix, unit_id, cell, use_drop)
	return {
		"cell": cell,
		"slots": slots,
		"slots_signature": _QaGate._intent_slot_signature(slots),
		"preview_path": PlanningChecklistHarness.preview_path(fix, unit_id).duplicate(),
		"drag_route": fix.input.get_drag_route().duplicate(),
		"display_ap": input.planning_display_ap_left(unit_id),
		"requires_run": input.unit_move_requires_run(unit_id),
		"invalid": PlanningChecklistHarness.slots_invalid(slots),
	}


static func commit_slots_for_interaction(
	fix: Dictionary,
	unit_id: int,
	cell: Vector2i,
	use_drop: bool,
) -> Dictionary:
	var input: CombatPlanningInput = fix.input
	if use_drop and input.dragging:
		return PlanningChecklistHarness.drop_slots_for_cell(fix, cell)
	return PlanningChecklistHarness.slots_for_click(fix, cell)


static func commit_from_preview_intent(
	fix: Dictionary,
	unit_id: int,
	pre_intent: Dictionary,
	label: String,
	failures: Array[String],
) -> bool:
	if bool(pre_intent.get("invalid", false)):
		PlanningChecklistHarness.assert_fail(
			failures, label, "commit blocked: preview slots invalid",
		)
		return false
	var slots: Dictionary = pre_intent.get("slots", {}) as Dictionary
	if not PlanningChecklistHarness.commit_slots_production(fix, slots):
		PlanningChecklistHarness.assert_fail(failures, label, "commit_from_slots failed")
		return false
	assert_commit_ratifies_preview(fix, failures, unit_id, pre_intent, label)
	return failures.is_empty()


static func assert_commit_ratifies_preview(
	fix: Dictionary,
	failures: Array[String],
	unit_id: int,
	pre: Dictionary,
	label: String,
) -> void:
	var director: CombatDirector = fix.director
	var slots: Dictionary = pre.get("slots", {}) as Dictionary
	if PlanningChecklistHarness.slots_invalid(slots):
		PlanningChecklistHarness.assert_fail(
			failures, label, "commit must not run when preview slots are invalid",
		)
		return
	var pre_move: TimelineAction = committed_pre_move_matching_slots(director, unit_id, slots)
	var pre_target: Vector2i = pre_target_from_slots(slots)
	if pre_target.x > -900000:
		if pre_move == null:
			PlanningChecklistHarness.assert_fail(
				failures,
				label,
				"committed pre-move missing for preview target %s" % pre_target,
			)
		else:
			if pre_move.target_coord != pre_target:
				PlanningChecklistHarness.assert_fail(
					failures,
					label,
					"committed pre-move target %s != preview %s"
					% [pre_move.target_coord, pre_target],
				)
			var slot_pre: Array = slots.get("pre", []) as Array
			if not slot_pre.is_empty() and slot_pre[0] is TimelineAction:
				var slot_action: TimelineAction = slot_pre[0] as TimelineAction
				if pre_move.uses_run != slot_action.uses_run:
					PlanningChecklistHarness.assert_fail(
						failures,
						label,
						"committed uses_run %s != preview %s"
						% [pre_move.uses_run, slot_action.uses_run],
					)
				if not (pre.get("drag_route", []) as Array).is_empty():
					if pre_move.waypoints != slot_action.waypoints:
						PlanningChecklistHarness.assert_fail(
							failures,
							label,
							"committed waypoints %s != preview %s"
							% [pre_move.waypoints, slot_action.waypoints],
						)
	var action_target_id: int = action_target_unit_from_slots(slots)
	var action: TimelineAction = committed_action_for_unit(director, unit_id)
	if action_target_id >= 0:
		if action == null:
			PlanningChecklistHarness.assert_fail(
				failures, label, "committed action missing for target unit %d" % action_target_id,
			)
		elif action.target_unit_id != action_target_id:
			PlanningChecklistHarness.assert_fail(
				failures,
				label,
				"committed action target %d != preview %d"
				% [action.target_unit_id, action_target_id],
			)


static func assert_committed_display_ratifies_pre_commit(
	fix: Dictionary,
	failures: Array[String],
	unit_id: int,
	pre_intent: Dictionary,
	label: String,
) -> void:
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	if overlay == null:
		PlanningChecklistHarness.assert_fail(failures, label, "overlay missing")
		return
	var pre_preview_path: Array = pre_intent.get("preview_path", [])
	var committed_path: Array = overlay.get_committed_preview().preview_paths.get(unit_id, [])
	if not pre_preview_path.is_empty() and committed_path != pre_preview_path:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"committed display path must ratify pre-commit move preview (%s vs %s)"
			% [str(committed_path), str(pre_preview_path)],
		)
	var pre_slots: Dictionary = pre_intent.get("slots", {}) as Dictionary
	var pre_target: Vector2i = pre_target_from_slots(pre_slots)
	var projected: UnitState = fix.director.projected_state.get_unit_by_id(unit_id)
	if projected != null and pre_target.x > -900000 and projected.position != pre_target:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"projected stand %s must ratify pre-commit pre-move target %s"
			% [projected.position, pre_target],
		)


static func assert_k4_run_committed(
	fix: Dictionary,
	failures: Array[String],
	k4_id: int,
	label: String,
) -> void:
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var projected: UnitState = director.projected_state.get_unit_by_id(k4_id)
	if projected == null:
		PlanningChecklistHarness.assert_fail(failures, label, "k4 projected missing")
		return
	if projected.position != PlanningChecklistHarness.K4_RUN_TRIGGER:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"k4 destination expected %s got %s"
			% [PlanningChecklistHarness.K4_RUN_TRIGGER, projected.position],
		)
	var pre: TimelineAction = PlanningChecklistHarness.committed_pre_move(director, k4_id)
	if pre == null:
		PlanningChecklistHarness.assert_fail(failures, label, "k4 must commit pre-move")
		return
	if pre.target_coord != PlanningChecklistHarness.K4_RUN_TRIGGER:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"k4 pre-move dest %s != %s" % [pre.target_coord, PlanningChecklistHarness.K4_RUN_TRIGGER],
		)
	if not pre.uses_run:
		PlanningChecklistHarness.assert_fail(failures, label, "k4 pre-move must use Run")
	var expected_wps: Array[Vector2i] = PlanningChecklistHarness.K4_DETOUR_PLUS_RUN_ROUTE.slice(1)
	if pre.waypoints != expected_wps:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"k4 waypoints expected %s got %s" % [expected_wps, pre.waypoints],
		)
	if not plan_uses_run_for_unit(director, k4_id):
		PlanningChecklistHarness.assert_fail(failures, label, "k4 plan must use Run")
	if input.planning_display_ap_left(k4_id) != 0:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"k4 display AP after commit expected 0 got %d" % input.planning_display_ap_left(k4_id),
		)


static func assert_k4_walk_loop_preview(
	fix: Dictionary,
	failures: Array[String],
	unit_id: int,
	bowling: AbilityData,
	stand: Vector2i,
	label: String,
) -> void:
	var input: CombatPlanningInput = fix.input
	PlanningChecklistHarness.settle_ability_hover(fix)
	if input.unit_move_requires_run(unit_id):
		PlanningChecklistHarness.assert_fail(failures, label, "walk detour must not require Run at %s" % stand)
	if input.planning_display_ap_left(unit_id) != 1:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"walk detour display AP expected 1 got %d" % input.planning_display_ap_left(unit_id),
		)
	if bowling == null:
		PlanningChecklistHarness.assert_fail(failures, label, "bowling missing at walk loop")
	if not input.action_range_visible_for_hover():
		PlanningChecklistHarness.assert_fail(failures, label, "action-range gate must stay on at walk detour")
	PlanningChecklistHarness.assert_red_contract(
		failures, "%s/red" % label, fix, bowling, true, stand, unit_id,
	)


static func assert_k4_run_loop_preview(
	fix: Dictionary,
	failures: Array[String],
	unit_id: int,
	label: String,
) -> void:
	var input: CombatPlanningInput = fix.input
	PlanningChecklistHarness.settle_ability_hover(fix)
	if not input.unit_move_requires_run(unit_id):
		PlanningChecklistHarness.assert_fail(failures, label, "extension past detour must require Run")
	if input.planning_display_ap_left(unit_id) != 0:
		PlanningChecklistHarness.assert_fail(failures, label, "Run intent must show 0 display AP")
	if input.action_range_visible_for_hover():
		PlanningChecklistHarness.assert_fail(failures, label, "Run trigger must hide action-range gate")
	if not PlanningChecklistHarness.collect_red_tiles(fix).is_empty():
		PlanningChecklistHarness.assert_fail(failures, label, "Run trigger must hide action-range red")


static func assert_preview_path_equals(
	fix: Dictionary,
	failures: Array[String],
	unit_id: int,
	expected: Array,
	label: String,
) -> void:
	var actual: Array[Vector2i] = PlanningChecklistHarness.preview_path(fix, unit_id)
	if actual != expected:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"preview path expected %s got %s" % [str(expected), str(actual)],
		)


static func assert_drag_route_equals(
	fix: Dictionary,
	failures: Array[String],
	expected: Array,
	label: String,
) -> void:
	var actual: Array[Vector2i] = fix.input.get_drag_route()
	if actual != expected:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"drag route expected %s got %s" % [str(expected), str(actual)],
		)


static func assert_not_dragging(fix: Dictionary, failures: Array[String], label: String) -> void:
	if fix.input.dragging:
		PlanningChecklistHarness.assert_fail(
			failures, label, "selection mode must not activate drag",
		)


static func undo_until_unit_clear(
	fix: Dictionary,
	failures: Array[String],
	unit_id: int,
	home_cell: Vector2i,
	label_prefix: String,
) -> void:
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	director.select_unit(unit_id)
	PlanningChecklistHarness.flush_planning(fix)
	for _attempt: int in range(8):
		if director.unit_has_undoable_action(unit_id):
			PlanningDragE2EHarness.undo_selected(fix)
			PlanningChecklistHarness.flush_planning(fix)
			continue
		if input.awaiting_targeting_active():
			PlanningDragE2EHarness.undo_selected(fix)
			PlanningChecklistHarness.flush_planning(fix)
			continue
		break
	var unit: UnitState = director.board.get_unit_by_id(unit_id)
	if unit == null:
		PlanningChecklistHarness.assert_fail(
			failures, "%s/undo" % label_prefix, "unit %d missing" % unit_id,
		)
		return
	if unit.position != home_cell:
		PlanningChecklistHarness.assert_fail(
			failures,
			"%s/undo" % label_prefix,
			"board cell expected %s got %s" % [home_cell, unit.position],
		)
	if director.unit_has_undoable_action(unit_id):
		PlanningChecklistHarness.assert_fail(
			failures,
			"%s/undo" % label_prefix,
			"unit %d still has undoable plan" % unit_id,
		)


static func committed_pre_move_matching_slots(
	director: CombatDirector,
	unit_id: int,
	slots: Dictionary,
) -> TimelineAction:
	var slot_pre: Array = slots.get("pre", []) as Array
	if not slot_pre.is_empty() and slot_pre[0] is TimelineAction:
		var slot_action: TimelineAction = slot_pre[0] as TimelineAction
		for action: TimelineAction in pre_moves_for_unit(director, unit_id):
			if action.type != slot_action.type:
				continue
			if action.type == GameEnums.ActionType.MOVE:
				if action.target_coord == slot_action.target_coord:
					return action
			elif (
				action.type == GameEnums.ActionType.ABILITY
				and slot_action.ability != null
				and action.ability != null
				and action.ability.id == slot_action.ability.id
			):
				return action
	return PlanningChecklistHarness.committed_pre_move(director, unit_id)


static func committed_action_for_unit(director: CombatDirector, unit_id: int) -> TimelineAction:
	for action: TimelineAction in director.plan_action.entries:
		if action != null and action.actor_id == unit_id:
			return action
	return null


static func pre_moves_for_unit(director: CombatDirector, unit_id: int) -> Array[TimelineAction]:
	var out: Array[TimelineAction] = []
	for action: TimelineAction in director.plan_pre_move.entries:
		if action != null and action.actor_id == unit_id:
			out.append(action)
	return out


static func plan_uses_run_for_unit(director: CombatDirector, unit_id: int) -> bool:
	for action: TimelineAction in director.plan_pre_move.entries:
		if action != null and action.actor_id == unit_id and action.uses_run:
			return true
	return false


static func pre_target_from_slots(slots: Dictionary) -> Vector2i:
	var pre: Array = slots.get("pre", []) as Array
	for raw: Variant in pre:
		if raw is TimelineAction:
			var step: TimelineAction = raw as TimelineAction
			if step.type == GameEnums.ActionType.MOVE:
				return step.target_coord
	return Vector2i(-999999, -999999)


static func action_target_unit_from_slots(slots: Dictionary) -> int:
	var action_steps: Array = slots.get("action", []) as Array
	if action_steps.is_empty():
		return -1
	var step: TimelineAction = action_steps[0] as TimelineAction
	return step.target_unit_id if step != null else -1


const _Probe := preload("res://tests/planning_bible_fixture_probe.gd")


## Full mirror of test_live_planning_bible_multi_knight_session (fixture board).
static func run_bible_multi_knight_session(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bible_board()
	assert_training_board_pools(fix, failures, "TRAIN-01/bible")
	var director: CombatDirector = fix.director
	var expect: Dictionary = {}
	var k1_id: int = fix.k1_id as int
	var k2_id: int = fix.k2_id as int
	var k3_id: int = fix.k3_id as int
	var k4_id: int = fix.k4_id as int
	var e_bash_id: int = fix.e_bash_id as int
	var e_hook_id: int = fix.e_hook_id as int
	director.auto_run = true
	fix.input.auto_use_skill_after_move = true
	run_undo_sprite_smoke(fix, failures, k1_id)
	run_k1_journey_mirror(fix, failures, k1_id, e_bash_id, expect)
	run_k2_journey_mirror(fix, failures, k2_id, e_hook_id, expect)
	run_k3_journey_mirror(fix, failures, k3_id, expect)
	run_k4_journey_mirror(fix, failures, k4_id, expect)
	run_execute_all_plans(fix, failures, expect, k1_id, k2_id, k3_id, k4_id, e_bash_id, e_hook_id)


## Mirror test_live_swap_session (fixture board).
static func run_swap_session_mirror(failures: Array[String]) -> void:
	run_swap_adjacent_premove_mirror(failures)
	run_swap_out_of_range_parity_mirror(failures)
	run_swap_walk_then_swap_mirror(failures)


static func run_swap_adjacent_premove_mirror(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_swap_board(
		PlanningChecklistHarness.SWAP_ALLY_CELL,
	)
	assert_training_board_pools(fix, failures, "TRAIN-01/swap_adjacent")
	var director: CombatDirector = fix.director
	var k1_id: int = fix.k1_id as int
	var ally_id: int = fix.ally_id as int
	var start_mp: int = fix.start_k1_mp as int
	director.auto_run = true
	var swap_idx: int = PlanningChecklistHarness.select_ability_for_unit(
		fix, k1_id, PlanningChecklistHarness.KNIGHT_SWAP_ID,
	)
	var swap: AbilityData = null
	if swap_idx >= 0:
		swap = fix.board.get_unit_by_id(k1_id).active_abilities[swap_idx]
	if swap == null:
		PlanningChecklistHarness.assert_fail(failures, "SWAP-01", "swap ability missing")
		return
	_Probe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.SWAP_ALLY_CELL, {
			"blue_any": true,
			"ability": swap,
			"manhattan": true,
			"preview_nonempty": true,
		}, "SWAP-01/hover",
	)
	PlanningChecklistHarness.select_unit(fix, k1_id, PlanningChecklistHarness.SWAP_ALLY_CELL)
	if PlanningChecklistHarness.slots_invalid(
		PlanningChecklistHarness.commit_production(fix, PlanningChecklistHarness.SWAP_ALLY_CELL),
	):
		PlanningChecklistHarness.assert_fail(failures, "SWAP-02", "swap commit failed")
		return
	if director.selected_unit_id != k1_id:
		PlanningChecklistHarness.assert_fail(failures, "SWAP-02", "must keep k1 selected after swap commit")
	assert_swap_premove_state_layers(
		fix, failures, "SWAP-03", {
			"k1_id": k1_id,
			"ally_id": ally_id,
			"k1_pos": PlanningChecklistHarness.SWAP_ALLY_CELL,
			"ally_pos": PlanningChecklistHarness.KNIGHT_START,
			"k1_mp": start_mp - 1,
			"pre_move_count": 1,
			"require_swap_first": true,
		},
	)
	PlanningChecklistHarness.enter_basic_movement(fix)
	PlanningChecklistHarness.select_unit(fix, k1_id, PlanningChecklistHarness.SWAP_ALLY_CELL)
	_Probe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.SWAP_PREMOVE_ROUTE[0], {
			"blue_has": [PlanningChecklistHarness.SWAP_PREMOVE_ROUTE[0]],
			"ghost_pos": PlanningChecklistHarness.SWAP_PREMOVE_ROUTE[0],
			"path": [
				PlanningChecklistHarness.SWAP_ALLY_CELL,
				PlanningChecklistHarness.SWAP_PREMOVE_ROUTE[0],
			],
			"manhattan": true,
			"preview_nonempty": true,
			"icon_has": [PlanningIcons.GLYPH_WALK],
		}, "SWAP-04/hover_west",
	)
	_Probe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.SWAP_PREMOVE_DEST, {
			"blue_has": [PlanningChecklistHarness.SWAP_PREMOVE_DEST],
			"ghost_pos": PlanningChecklistHarness.SWAP_PREMOVE_DEST,
			"path": [
				PlanningChecklistHarness.SWAP_ALLY_CELL,
				PlanningChecklistHarness.SWAP_PREMOVE_ROUTE[0],
				PlanningChecklistHarness.SWAP_PREMOVE_DEST,
			],
			"manhattan": true,
			"preview_nonempty": true,
			"icon_has": [PlanningIcons.GLYPH_WALK],
		}, "SWAP-04/hover_dest",
	)
	var premove_route: Array[Vector2i] = [
		PlanningChecklistHarness.SWAP_ALLY_CELL,
		PlanningChecklistHarness.SWAP_PREMOVE_ROUTE[0],
		PlanningChecklistHarness.SWAP_PREMOVE_DEST,
	]
	var premove_pre: Dictionary = paint_route_and_capture_pre_intent(
		fix,
		k1_id,
		premove_route,
		PlanningChecklistHarness.SWAP_PREMOVE_DEST,
		true,
		"SWAP-04/premove",
		failures,
	)
	if premove_pre.is_empty():
		PlanningChecklistHarness.assert_fail(failures, "SWAP-04", "premove pre-intent capture failed")
		return
	if not commit_from_preview_intent(fix, k1_id, premove_pre, "SWAP-04/release", failures):
		return
	assert_swap_premove_state_layers(
		fix, failures, "SWAP-05", {
			"k1_id": k1_id,
			"ally_id": ally_id,
			"k1_pos": PlanningChecklistHarness.SWAP_PREMOVE_DEST,
			"ally_pos": PlanningChecklistHarness.KNIGHT_START,
			"k1_mp": start_mp - 3,
			"pre_move_count": 2,
			"require_swap_first": true,
			"last_pre_dest": PlanningChecklistHarness.SWAP_PREMOVE_DEST,
			"last_pre_waypoints": PlanningChecklistHarness.SWAP_PREMOVE_ROUTE,
		},
	)


static func run_swap_out_of_range_parity_mirror(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_swap_board(
		PlanningChecklistHarness.WALK_SWAP_ALLY_CELL,
	)
	assert_training_board_pools(fix, failures, "TRAIN-01/swap_out_of_range")
	var director: CombatDirector = fix.director
	var k1_id: int = fix.k1_id as int
	var ally_id: int = fix.ally_id as int
	director.auto_run = true
	if PlanningChecklistHarness.select_ability_for_unit(fix, k1_id, PlanningChecklistHarness.KNIGHT_SWAP_ID) < 0:
		PlanningChecklistHarness.assert_fail(failures, "SWAP-06", "swap ability missing")
		return
	_Probe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.WALK_SWAP_ALLY_CELL, {
			"preview_nonempty": true,
			"path_end": PlanningChecklistHarness.WALK_SWAP_APPROACH,
			"path_start": PlanningChecklistHarness.KNIGHT_START,
			"path_min_size": 2,
			"ghost_pos": PlanningChecklistHarness.WALK_SWAP_APPROACH,
			"manhattan": true,
			"icon_has": [PlanningIcons.GLYPH_WALK, PlanningIcons.GLYPH_SWAP],
		}, "SWAP-06/hover",
	)
	var pre_click: Dictionary = commit_slots_for_interaction(
		fix, k1_id, PlanningChecklistHarness.WALK_SWAP_ALLY_CELL, false,
	)
	if PlanningChecklistHarness.slots_invalid(pre_click):
		PlanningChecklistHarness.assert_fail(failures, "SWAP-07", "out-of-range click slots invalid")
		return
	if not PlanningChecklistHarness.commit_slots_production(fix, pre_click):
		PlanningChecklistHarness.assert_fail(failures, "SWAP-07", "out-of-range click commit failed")
		return
	if director.selected_unit_id != k1_id:
		PlanningChecklistHarness.assert_fail(failures, "SWAP-08", "k1 must stay selected after ally click")
	var pre_moves: Array[TimelineAction] = pre_moves_for_unit(director, k1_id)
	assert_pre_move_walk_swap_shape(
		failures,
		"SWAP-09",
		pre_moves,
		ally_id,
		PlanningChecklistHarness.WALK_SWAP_APPROACH,
	)
	assert_swap_premove_state_layers(
		fix, failures, "SWAP-10", {
			"k1_id": k1_id,
			"ally_id": ally_id,
			"k1_pos": PlanningChecklistHarness.WALK_SWAP_ALLY_CELL,
			"ally_pos": PlanningChecklistHarness.WALK_SWAP_APPROACH,
			"k1_mp": fix.start_k1_mp as int - 3,
			"pre_move_count": 2,
		},
	)


static func run_swap_walk_then_swap_mirror(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_swap_board(
		PlanningChecklistHarness.WALK_SWAP_ALLY_CELL,
	)
	assert_training_board_pools(fix, failures, "TRAIN-01/swap_walk_then")
	var director: CombatDirector = fix.director
	var k1_id: int = fix.k1_id as int
	var ally_id: int = fix.ally_id as int
	var start_mp: int = fix.start_k1_mp as int
	director.auto_run = true
	PlanningChecklistHarness.select_ability_for_unit(fix, k1_id, PlanningChecklistHarness.KNIGHT_SWAP_ID)
	PlanningChecklistHarness.enter_basic_movement(fix)
	var walk_pre: Dictionary = paint_route_and_capture_pre_intent(
		fix,
		k1_id,
		[
			PlanningChecklistHarness.KNIGHT_START,
			Vector2i(3, 5),
			PlanningChecklistHarness.WALK_SWAP_APPROACH,
		],
		PlanningChecklistHarness.WALK_SWAP_APPROACH,
		true,
		"SWAP-11/walk",
		failures,
	)
	if walk_pre.is_empty():
		PlanningChecklistHarness.assert_fail(failures, "SWAP-11", "walk drag pre-intent failed")
		return
	if not commit_from_preview_intent(fix, k1_id, walk_pre, "SWAP-11/release", failures):
		return
	PlanningChecklistHarness.select_ability_for_unit(fix, k1_id, PlanningChecklistHarness.KNIGHT_SWAP_ID)
	PlanningChecklistHarness.select_unit(fix, k1_id, PlanningChecklistHarness.WALK_SWAP_ALLY_CELL)
	var swap_pre: Dictionary = capture_preview_intent(
		fix, k1_id, PlanningChecklistHarness.WALK_SWAP_ALLY_CELL, false,
	)
	if not commit_from_preview_intent(fix, k1_id, swap_pre, "SWAP-12/release", failures):
		return
	var pre_moves: Array[TimelineAction] = pre_moves_for_unit(director, k1_id)
	assert_pre_move_walk_swap_shape(
		failures,
		"SWAP-13",
		pre_moves,
		ally_id,
		PlanningChecklistHarness.WALK_SWAP_APPROACH,
	)
	assert_swap_premove_state_layers(
		fix, failures, "SWAP-14", {
			"k1_id": k1_id,
			"ally_id": ally_id,
			"k1_pos": PlanningChecklistHarness.WALK_SWAP_ALLY_CELL,
			"ally_pos": PlanningChecklistHarness.WALK_SWAP_APPROACH,
			"k1_mp": start_mp - 3,
			"pre_move_count": 2,
		},
	)


static func run_undo_sprite_smoke(fix: Dictionary, failures: Array[String], k1_id: int) -> void:
	var director: CombatDirector = fix.director
	director.selected_ability_index = -1
	fix.input.force_basic_movement = true
	var home: Vector2i = PlanningChecklistHarness.KNIGHT_START
	var dest: Vector2i = PlanningChecklistHarness.BASH_HOVER_WALK
	PlanningDragE2EHarness.paint_and_release(fix, [home, dest], dest)
	if director.plan_pre_move.entries.is_empty():
		PlanningChecklistHarness.assert_fail(failures, "UNDO-01", "drag commit must write pre-move")
		return
	if not director.unit_has_undoable_action(k1_id):
		PlanningChecklistHarness.assert_fail(failures, "UNDO-02", "unit must be undoable after drag walk")
		return
	undo_until_unit_clear(fix, failures, k1_id, home, "UNDO-03")


static func run_k1_journey_mirror(
	fix: Dictionary,
	failures: Array[String],
	k1_id: int,
	e_bash_id: int,
	expect: Dictionary,
) -> void:
	var knight: UnitState = fix.board.get_unit_by_id(k1_id)
	if knight == null:
		PlanningChecklistHarness.assert_fail(failures, "K1-01", "k1 unit missing")
		return
	if knight.ability.points_left != 1 or knight.movement.points_left != 3:
		PlanningChecklistHarness.assert_fail(
			failures,
			"K1-01",
			"k1 pools expected 1 AP / 3 MP got AP=%d MP=%d"
			% [knight.ability.points_left, knight.movement.points_left],
		)
	PlanningChecklistHarness.select_unit(fix, k1_id, PlanningChecklistHarness.KNIGHT_START)
	var bash_idx: int = PlanningChecklistHarness.select_ability_for_unit(
		fix, k1_id, PlanningChecklistHarness.SHIELD_BASH_ID,
	)
	var bash: AbilityData = null
	if bash_idx >= 0:
		bash = fix.board.get_unit_by_id(k1_id).active_abilities[bash_idx]
	_Probe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.KNIGHT_START, {
			"red_on": true,
			"red_stand": PlanningChecklistHarness.KNIGHT_START,
			"ability": bash,
			"blue_any": true,
			"red_cell": {
				"cell": PlanningChecklistHarness.ENEMY_POS,
				"stand": PlanningChecklistHarness.KNIGHT_START,
				"in_range": false,
			},
		}, "K1-02/stand",
	)
	probe_k1_hover_edges(fix, failures, k1_id, bash)
	_Probe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.BASH_HOVER_WALK, {
			"ghost_pos": PlanningChecklistHarness.BASH_HOVER_WALK,
			"path_end": PlanningChecklistHarness.BASH_HOVER_WALK,
			"path_start": PlanningChecklistHarness.KNIGHT_START,
			"path_min_size": 2,
			"manhattan": true,
			"red_on": true,
			"red_stand": PlanningChecklistHarness.BASH_HOVER_WALK,
			"ability": bash,
			"icon_has": [PlanningIcons.GLYPH_WALK],
			"blue_any": true,
		}, "K1-04/walk",
	)
	PlanningChecklistHarness.select_unit(fix, k1_id, PlanningChecklistHarness.ENEMY_POS)
	PlanningChecklistHarness.refresh_attack_hover(fix, PlanningChecklistHarness.ENEMY_POS)
	var push_to: Vector2i = PlanningChecklistHarness.push_destination(fix, e_bash_id)
	if push_to.x <= PlanningChecklistHarness.E_BASH_CELL.x:
		PlanningChecklistHarness.assert_fail(failures, "K1-06", "push preview must be east of enemy")
	_Probe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.ENEMY_POS, {
			"path_end": PlanningChecklistHarness.BASH_APPROACH,
			"path_start": PlanningChecklistHarness.KNIGHT_START,
			"path_min_size": 3,
			"manhattan": true,
			"blue_any": true,
			"red_on": true,
			"red_stand": PlanningChecklistHarness.BASH_APPROACH,
			"ability": bash,
			"icon_has": [PlanningIcons.GLYPH_WALK, PlanningIcons.GLYPH_ATTACK],
			"push_dest": push_to,
			"push_enemy_id": e_bash_id,
		}, "K1-05/approach",
	)
	run_k1_bash_live_parity(fix, failures, k1_id, e_bash_id, bash, "K1")
	var bashed: UnitState = PlanningChecklistHarness.projected_unit(fix, e_bash_id)
	expect["k1_pos"] = PlanningChecklistHarness.BASH_APPROACH
	expect["e_bash_pos"] = bashed.position if bashed != null else PlanningChecklistHarness.E_BASH_CELL


static func probe_k1_hover_edges(
	fix: Dictionary,
	failures: Array[String],
	k1_id: int,
	bash: AbilityData,
) -> void:
	_Probe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.ENEMY_POS, {
			"ability": bash,
		}, "K1-03/from_enemy",
	)
	_Probe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.OFF_BLUE_CELL, {
			"blue_any": true,
			"blue_not": [PlanningChecklistHarness.OFF_BLUE_CELL],
			"red_on": true,
			"red_stand": PlanningChecklistHarness.KNIGHT_START,
			"ability": bash,
			"red_tiles_exact": true,
			"attack_target_clear": true,
			"icon_is": PlanningIcons.GLYPH_NULL,
			"slots_invalid": true,
			"tiles_only_in_bounds": true,
		}, "K1-03/off_blue",
	)
	assert_off_blue_click_must_not_commit(
		fix, failures, k1_id, PlanningChecklistHarness.OFF_BLUE_CELL, "K1-03/off_blue_click",
	)
	PlanningChecklistHarness.hover_off_map(fix)
	_Probe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.OFF_MAP_HOVER, {
			"hover_oob": true,
			"blue_any": true,
			"red_on": true,
			"red_stand": PlanningChecklistHarness.KNIGHT_START,
			"ability": bash,
			"tiles_only_in_bounds": true,
		}, "K1-03/off_map",
	)


static func run_k2_journey_mirror(
	fix: Dictionary,
	failures: Array[String],
	k2_id: int,
	e_hook_id: int,
	expect: Dictionary,
) -> void:
	expect["k2_pos"] = PlanningChecklistHarness.K2_CELL
	expect["e_hook_pos"] = PlanningChecklistHarness.E_HOOK_CELL
	var hook_idx: int = PlanningChecklistHarness.select_ability_for_unit(
		fix, k2_id, PlanningChecklistHarness.CHAIN_HOOK_ID,
	)
	var hook: AbilityData = null
	if hook_idx >= 0:
		hook = fix.board.get_unit_by_id(k2_id).active_abilities[hook_idx]
	_Probe.probe_cell(
		failures, fix, k2_id, PlanningChecklistHarness.K2_CELL, {
			"red_on": true,
			"red_stand": PlanningChecklistHarness.K2_CELL,
			"ability": hook,
			"red_cell": {
				"cell": PlanningChecklistHarness.E_HOOK_CELL,
				"stand": PlanningChecklistHarness.K2_CELL,
				"in_range": true,
			},
			"blue_any": true,
		}, "K2-01/stand",
	)
	_Probe.probe_cell(
		failures, fix, k2_id, Vector2i(2, 3), {
			"ghost_pos": Vector2i(2, 3),
			"path_end": Vector2i(2, 3),
			"path_start": PlanningChecklistHarness.K2_CELL,
			"path_min_size": 2,
			"manhattan": true,
			"blue_any": true,
		}, "K2-02/walk",
	)
	var pull_preview: Vector2i = PlanningChecklistHarness.push_destination(fix, e_hook_id)
	if pull_preview.x > -900000 and pull_preview.x >= PlanningChecklistHarness.E_HOOK_CELL.x:
		PlanningChecklistHarness.assert_fail(failures, "K2-03", "pull preview must be west of enemy")
	_Probe.probe_cell(
		failures, fix, k2_id, PlanningChecklistHarness.E_HOOK_CELL, {
			"path_end": PlanningChecklistHarness.K2_CELL,
			"path_start": PlanningChecklistHarness.K2_CELL,
			"path_min_size": 1,
			"icon_has": [PlanningIcons.GLYPH_ATTACK],
			"manhattan": true,
			"blue_any": true,
			"red_on": true,
			"red_stand": PlanningChecklistHarness.K2_CELL,
			"ability": hook,
			"pull_dest": pull_preview,
			"pull_enemy_id": e_hook_id,
		}, "K2-03/enemy",
	)
	PlanningChecklistHarness.select_unit(fix, k2_id, PlanningChecklistHarness.K2_CELL)
	var hook_pre: Dictionary = capture_preview_intent(
		fix, k2_id, PlanningChecklistHarness.E_HOOK_CELL, false,
	)
	if not commit_from_preview_intent(fix, k2_id, hook_pre, "K2-04/selection/release", failures):
		return
	assert_k2_hook_committed(fix, failures, k2_id, e_hook_id, "K2-04/selection")
	var selection_surface: Dictionary = PlanningChecklistHarness.mode_commit_surface(fix, k2_id)
	undo_until_unit_clear(fix, failures, k2_id, PlanningChecklistHarness.K2_CELL, "K2-05")
	PlanningChecklistHarness.select_ability_for_unit(fix, k2_id, PlanningChecklistHarness.CHAIN_HOOK_ID)
	PlanningChecklistHarness.select_unit(fix, k2_id, PlanningChecklistHarness.K2_CELL)
	PlanningDragE2EHarness.begin_drag_route(fix, [PlanningChecklistHarness.K2_CELL])
	hop_drag_to_cell(fix, k2_id, PlanningChecklistHarness.E_HOOK_CELL)
	var hook_drag_pre: Dictionary = capture_preview_intent(
		fix, k2_id, PlanningChecklistHarness.E_HOOK_CELL, true,
	)
	PlanningDragE2EHarness.release_at(fix, PlanningChecklistHarness.E_HOOK_CELL)
	PlanningChecklistHarness.flush_planning(fix)
	assert_commit_ratifies_preview(fix, failures, k2_id, hook_drag_pre, "K2-06/drag/release")
	assert_k2_hook_committed(fix, failures, k2_id, e_hook_id, "K2-06/drag")
	var drag_surface: Dictionary = PlanningChecklistHarness.mode_commit_surface(fix, k2_id)
	PlanningChecklistHarness.assert_mode_commit_parity(
		failures, "k2/selection", selection_surface, "k2/drag", drag_surface,
	)
	var projected: UnitState = PlanningChecklistHarness.projected_unit(fix, k2_id)
	if projected != null and projected.ability.points_left != 0:
		PlanningChecklistHarness.assert_fail(failures, "K2-07", "hook spends AP")
	var hooked: UnitState = PlanningChecklistHarness.projected_unit(fix, e_hook_id)
	if hooked != null and hooked.position.x >= PlanningChecklistHarness.E_HOOK_CELL.x:
		PlanningChecklistHarness.assert_fail(failures, "K2-08", "hook must pull west")
	expect["k2_pos"] = PlanningChecklistHarness.K2_CELL
	expect["e_hook_pos"] = hooked.position if hooked != null else PlanningChecklistHarness.E_HOOK_CELL


static func assert_k2_hook_committed(
	fix: Dictionary,
	failures: Array[String],
	k2_id: int,
	e_hook_id: int,
	label: String,
) -> void:
	var director: CombatDirector = fix.director
	if director.plan_action.entries.is_empty():
		PlanningChecklistHarness.assert_fail(failures, label, "hook must write action")
		return
	var projected: UnitState = PlanningChecklistHarness.projected_unit(fix, k2_id)
	if projected == null or projected.ability.points_left != 0:
		PlanningChecklistHarness.assert_fail(failures, label, "hook spends AP")
	var hooked: UnitState = PlanningChecklistHarness.projected_unit(fix, e_hook_id)
	if hooked == null or hooked.position.x >= PlanningChecklistHarness.E_HOOK_CELL.x:
		PlanningChecklistHarness.assert_fail(failures, label, "hook must pull west")


static func run_k3_journey_mirror(
	fix: Dictionary,
	failures: Array[String],
	k3_id: int,
	expect: Dictionary,
) -> void:
	expect["k3_pos"] = PlanningChecklistHarness.K3_CELL
	var trample_idx: int = PlanningChecklistHarness.select_ability_for_unit(
		fix, k3_id, PlanningChecklistHarness.TRAMPLE_ID,
	)
	var trample: AbilityData = null
	if trample_idx >= 0:
		trample = fix.board.get_unit_by_id(k3_id).active_abilities[trample_idx]
	_Probe.probe_cell(
		failures, fix, k3_id, PlanningChecklistHarness.K3_CELL, {
			"blue_any": true,
			"red_on": true,
			"red_stand": PlanningChecklistHarness.K3_CELL,
			"ability": trample,
			"manhattan": true,
		}, "K3-01/stand",
	)
	if not rearm_trample_awaiting(fix, failures, k3_id, "K3-02"):
		return
	if not fix.input.awaiting_targeting_active():
		PlanningChecklistHarness.assert_fail(failures, "K3-02", "awaiting_targeting must be active")
	_Probe.probe_cell(
		failures, fix, k3_id, PlanningChecklistHarness.TRAMPLE_ROUTE[0], {
			"path": [PlanningChecklistHarness.K3_CELL, PlanningChecklistHarness.TRAMPLE_ROUTE[0]],
			"ghost_pos": PlanningChecklistHarness.TRAMPLE_ROUTE[0],
			"manhattan": true,
			"preview_nonempty": true,
			"red_on": true,
			"red_stand": PlanningChecklistHarness.K3_CELL,
			"ability": trample,
		}, "K3-03/hover_east",
	)
	_Probe.probe_cell(
		failures, fix, k3_id, PlanningChecklistHarness.TRAMPLE_END, {
			"path_end": PlanningChecklistHarness.TRAMPLE_END,
			"path_start": PlanningChecklistHarness.K3_CELL,
			"path_min_size": 3,
			"ghost_pos": PlanningChecklistHarness.TRAMPLE_END,
			"manhattan": true,
			"preview_nonempty": true,
			"red_on": true,
			"red_stand": PlanningChecklistHarness.K3_CELL,
			"ability": trample,
		}, "K3-04/hover_end",
	)
	if not fix.input.awaiting_targeting_active():
		if not rearm_trample_awaiting(fix, failures, k3_id, "K3-05"):
			PlanningChecklistHarness.assert_fail(failures, "K3-05", "trample re-arm failed")
			return
	_Probe.probe_cell(
		failures, fix, k3_id, PlanningChecklistHarness.TRAMPLE_END, {
			"path": PlanningChecklistHarness.TRAMPLE_FULL_PATH,
			"ghost_pos": PlanningChecklistHarness.TRAMPLE_END,
			"manhattan": true,
			"preview_nonempty": true,
		}, "K3-05/selection/pre_tap",
	)
	var sel_pre: Dictionary = capture_preview_intent(
		fix, k3_id, PlanningChecklistHarness.TRAMPLE_END, false,
	)
	if not commit_from_preview_intent(fix, k3_id, sel_pre, "K3-05/selection/release", failures):
		return
	assert_k3_trample_committed(fix, failures, k3_id, "K3-05/selection", false)
	var selection_surface: Dictionary = PlanningChecklistHarness.mode_commit_surface(fix, k3_id)
	undo_until_unit_clear(fix, failures, k3_id, PlanningChecklistHarness.K3_CELL, "K3-06")
	if not rearm_trample_awaiting(fix, failures, k3_id, "K3-07"):
		return
	if not commit_trample_drag_with_probes(fix, failures, k3_id):
		return
	assert_k3_trample_committed(fix, failures, k3_id, "K3-07/drag", true)
	var drag_surface: Dictionary = PlanningChecklistHarness.mode_commit_surface(fix, k3_id)
	PlanningChecklistHarness.assert_mode_commit_parity(
		failures, "k3/selection", selection_surface, "k3/drag", drag_surface,
	)
	PlanningChecklistHarness.assert_red_contract(
		failures, "K3-08/post_commit", fix, trample, false, PlanningChecklistHarness.TRAMPLE_END, k3_id,
	)
	PlanningChecklistHarness.select_unit(fix, k3_id, PlanningChecklistHarness.TRAMPLE_END)
	PlanningChecklistHarness.enter_basic_movement(fix)
	_Probe.probe_cell(
		failures, fix, k3_id, PlanningChecklistHarness.TRAMPLE_END, {
			"blue_any": true,
			"manhattan": true,
		}, "K3-09/post_stand",
	)
	_Probe.probe_cell(
		failures, fix, k3_id, Vector2i(7, 3), {
			"blue_has": [Vector2i(7, 3)],
			"ghost_pos": Vector2i(7, 3),
			"path": [PlanningChecklistHarness.TRAMPLE_END, Vector2i(7, 3)],
			"manhattan": true,
			"preview_nonempty": true,
			"icon_has": [PlanningIcons.GLYPH_WALK],
			"icon_not": [PlanningIcons.GLYPH_ATTACK],
		}, "K3-10/post_hover_east",
	)
	_Probe.probe_cell(
		failures, fix, k3_id, PlanningChecklistHarness.TRAMPLE_POST_DEST, {
			"path": PlanningChecklistHarness.TRAMPLE_POST_ROUTE,
			"ghost_pos": PlanningChecklistHarness.TRAMPLE_POST_DEST,
			"manhattan": true,
			"preview_nonempty": true,
			"blue_any": true,
		}, "K3-11/post_hover_dest",
	)
	if not PlanningChecklistHarness.commit_painted_drop_on_cell(
		fix,
		PlanningChecklistHarness.TRAMPLE_POST_ROUTE,
		PlanningChecklistHarness.TRAMPLE_POST_DEST,
	):
		PlanningChecklistHarness.assert_fail(failures, "K3-12/post_drag", "post-trample drag failed")
		return
	assert_k3_post_move_committed(fix, failures, k3_id, "K3-12")
	PlanningChecklistHarness.assert_red_contract(
		failures, "K3-13/post_after_commit", fix, trample, false,
		PlanningChecklistHarness.TRAMPLE_POST_DEST, k3_id,
	)
	expect["k3_pos"] = PlanningChecklistHarness.TRAMPLE_POST_DEST


static func assert_k3_trample_committed(
	fix: Dictionary,
	failures: Array[String],
	k3_id: int,
	label: String,
	is_drag: bool,
) -> void:
	var director: CombatDirector = fix.director
	var action: TimelineAction = PlanningChecklistHarness.committed_action(director, k3_id)
	if action == null:
		PlanningChecklistHarness.assert_fail(failures, label, "trample action missing")
		return
	var projected: UnitState = PlanningChecklistHarness.projected_unit(fix, k3_id)
	if projected == null:
		PlanningChecklistHarness.assert_fail(failures, label, "trample projected missing")
		return
	if is_drag:
		if action.waypoints != PlanningChecklistHarness.TRAMPLE_ROUTE:
			PlanningChecklistHarness.assert_fail(failures, label, "trample drag waypoints")
		if projected.position != PlanningChecklistHarness.TRAMPLE_END:
			PlanningChecklistHarness.assert_fail(failures, label, "trample end position")
	else:
		if action.target_coord != PlanningChecklistHarness.TRAMPLE_END:
			PlanningChecklistHarness.assert_fail(failures, label, "trample target")
	if projected.ability.points_left != 0:
		PlanningChecklistHarness.assert_fail(failures, label, "trample spends AP")


static func assert_k3_post_move_committed(
	fix: Dictionary,
	failures: Array[String],
	k3_id: int,
	label: String,
) -> void:
	var director: CombatDirector = fix.director
	var post: TimelineAction = PlanningChecklistHarness.committed_post_move(director, k3_id)
	if post == null:
		PlanningChecklistHarness.assert_fail(failures, label, "post-move missing")
		return
	if post.target_coord != PlanningChecklistHarness.TRAMPLE_POST_DEST:
		PlanningChecklistHarness.assert_fail(failures, label, "post-move dest")
	if post.waypoints != PlanningChecklistHarness.TRAMPLE_POST_WAYPOINTS:
		PlanningChecklistHarness.assert_fail(failures, label, "post-move waypoints")
	var projected: UnitState = PlanningChecklistHarness.projected_unit(fix, k3_id)
	if projected == null or projected.position != PlanningChecklistHarness.TRAMPLE_POST_DEST:
		PlanningChecklistHarness.assert_fail(failures, label, "post projected position")


static func plan_entry_count(director: CombatDirector) -> int:
	return (
		director.plan_pre_move.entries.size()
		+ director.plan_action.entries.size()
		+ director.plan_post_move.entries.size()
	)


static func assert_off_blue_click_must_not_commit(
	fix: Dictionary,
	failures: Array[String],
	unit_id: int,
	cell: Vector2i,
	label: String,
) -> void:
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var before: int = plan_entry_count(director)
	var pre_action: TimelineAction = PlanningChecklistHarness.committed_action(director, unit_id)
	var pre_move: TimelineAction = PlanningChecklistHarness.committed_pre_move(director, unit_id)
	PlanningChecklistHarness.commit_production(fix, cell)
	PlanningChecklistHarness.flush_planning(fix)
	if plan_entry_count(director) != before:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"off-blue click must not add timeline entries (before=%d)" % before,
		)
	var post_action: TimelineAction = PlanningChecklistHarness.committed_action(director, unit_id)
	var post_move: TimelineAction = PlanningChecklistHarness.committed_pre_move(director, unit_id)
	if post_action != pre_action:
		PlanningChecklistHarness.assert_fail(failures, label, "off-blue click must not commit action")
	if post_move != pre_move:
		PlanningChecklistHarness.assert_fail(failures, label, "off-blue click must not commit move")
	if input.preview_state != null and input.preview_state.preview_board != null:
		PlanningChecklistHarness.assert_fail(
			failures, label, "off-blue click must not leave painted attack preview",
		)


static func assert_k1_bash_committed(
	fix: Dictionary,
	failures: Array[String],
	k1_id: int,
	label: String,
	require_waypoints: bool,
) -> void:
	var director: CombatDirector = fix.director
	if director.plan_pre_move.entries.is_empty():
		PlanningChecklistHarness.assert_fail(failures, label, "bash must write pre-move")
		return
	if director.plan_action.entries.is_empty():
		PlanningChecklistHarness.assert_fail(failures, label, "bash must write action")
		return
	var bash_pre: TimelineAction = PlanningChecklistHarness.committed_pre_move(director, k1_id)
	if bash_pre == null:
		PlanningChecklistHarness.assert_fail(failures, label, "missing bash pre-move")
		return
	if bash_pre.target_coord != PlanningChecklistHarness.BASH_APPROACH:
		PlanningChecklistHarness.assert_fail(
			failures, label, "bash pre-move dest expected %s got %s"
			% [PlanningChecklistHarness.BASH_APPROACH, bash_pre.target_coord],
		)
	if require_waypoints and bash_pre.waypoints != _K1_BASH_WAYPOINTS:
		PlanningChecklistHarness.assert_fail(
			failures, label, "bash pre-move waypoints expected %s got %s"
			% [_K1_BASH_WAYPOINTS, bash_pre.waypoints],
		)


static func rearm_trample_awaiting(
	fix: Dictionary,
	failures: Array[String],
	k3_id: int,
	label: String,
) -> bool:
	PlanningChecklistHarness.select_ability_for_unit(fix, k3_id, PlanningChecklistHarness.TRAMPLE_ID)
	PlanningChecklistHarness.select_unit(fix, k3_id, PlanningChecklistHarness.K3_CELL)
	var slots: Dictionary = PlanningChecklistHarness.commit_production(
		fix, PlanningChecklistHarness.K3_CELL,
	)
	if PlanningChecklistHarness.slots_invalid(slots):
		PlanningChecklistHarness.assert_fail(failures, label, "trample re-arm tap failed")
		return false
	if not fix.input.awaiting_targeting_active():
		PlanningChecklistHarness.assert_fail(failures, label, "awaiting_targeting must be active after re-arm")
		return false
	if fix.director.find_awaiting_action(k3_id) == null:
		PlanningChecklistHarness.assert_fail(failures, label, "awaiting action missing after re-arm")
		return false
	return true


static func commit_trample_drag_with_probes(
	fix: Dictionary,
	failures: Array[String],
	k3_id: int,
) -> bool:
	var route: Array[Vector2i] = [
		PlanningChecklistHarness.K3_CELL,
		PlanningChecklistHarness.TRAMPLE_ROUTE[0],
		PlanningChecklistHarness.TRAMPLE_ROUTE[1],
	]
	PlanningChecklistHarness.select_unit(fix, k3_id, route[0])
	PlanningDragE2EHarness.begin_drag_route(fix, [route[0]])
	for step_index: int in range(1, route.size()):
		hop_drag_to_cell(fix, k3_id, route[step_index])
		var expected_path: Array[Vector2i] = route.slice(0, step_index + 1)
		assert_drag_route_equals(
			fix, failures, expected_path, "K3-07/drag_route_%d" % step_index,
		)
		assert_preview_path_equals(
			fix, failures, k3_id, expected_path, "K3-07/preview_path_%d" % step_index,
		)
	hop_drag_to_cell(fix, k3_id, PlanningChecklistHarness.TRAMPLE_END)
	var full_route: Array[Vector2i] = [
		PlanningChecklistHarness.K3_CELL,
		PlanningChecklistHarness.TRAMPLE_ROUTE[0],
		PlanningChecklistHarness.TRAMPLE_ROUTE[1],
	]
	if PlanningChecklistHarness.TRAMPLE_END != full_route[full_route.size() - 1]:
		full_route.append(PlanningChecklistHarness.TRAMPLE_END)
	assert_preview_path_equals(fix, failures, k3_id, full_route, "K3-07/pre_release/path")
	var pre_intent: Dictionary = capture_preview_intent(
		fix, k3_id, PlanningChecklistHarness.TRAMPLE_END, true,
	)
	PlanningDragE2EHarness.release_at(fix, PlanningChecklistHarness.TRAMPLE_END)
	PlanningChecklistHarness.flush_planning(fix)
	assert_commit_ratifies_preview(fix, failures, k3_id, pre_intent, "K3-07/release")
	return true


static func assert_training_board_pools(
	fix: Dictionary,
	failures: Array[String],
	label: String,
) -> void:
	for unit: UnitState in fix.board.units:
		if unit.team != GameEnums.Team.PLAYER or not unit.is_alive():
			continue
		if unit.ability.points_left != 1 or unit.movement.points_left != unit.movement.max_points:
			PlanningChecklistHarness.assert_fail(
				failures,
				label,
				"unit %d expected 1 AP / %d MP got AP=%d MP=%d"
				% [unit.id, unit.movement.max_points, unit.ability.points_left, unit.movement.points_left],
			)


static func assert_swap_premove_state_layers(
	fix: Dictionary,
	failures: Array[String],
	label: String,
	expect: Dictionary,
) -> void:
	var director: CombatDirector = fix.director
	var input: CombatPlanningInput = fix.input
	var k1_id: int = int(expect.get("k1_id", fix.get("k1_id", -1)))
	var ally_id: int = int(expect.get("ally_id", fix.get("ally_id", -1)))
	var k1_pos: Vector2i = expect["k1_pos"] as Vector2i
	var ally_pos: Vector2i = expect["ally_pos"] as Vector2i

	var board_k1: UnitState = director.board.get_unit_by_id(k1_id)
	var board_ally: UnitState = director.board.get_unit_by_id(ally_id)
	if board_k1 == null or board_ally == null:
		PlanningChecklistHarness.assert_fail(failures, label, "live board units missing")
		return
	PlanningChecklistHarness.assert_eq_cell(failures, "%s/k1_board" % label, board_k1.position, k1_pos)
	PlanningChecklistHarness.assert_eq_cell(failures, "%s/ally_board" % label, board_ally.position, ally_pos)

	var proj_k1: UnitState = PlanningChecklistHarness.projected_unit(fix, k1_id)
	var proj_ally: UnitState = PlanningChecklistHarness.projected_unit(fix, ally_id)
	if proj_k1 == null or proj_ally == null:
		PlanningChecklistHarness.assert_fail(failures, label, "projected units missing")
		return
	PlanningChecklistHarness.assert_eq_cell(failures, "%s/k1_proj" % label, proj_k1.position, k1_pos)
	PlanningChecklistHarness.assert_eq_cell(failures, "%s/ally_proj" % label, proj_ally.position, ally_pos)

	if input.preview_state != null and input.preview_state.preview_board != null:
		var preview: BoardState = input.preview_state.preview_board
		var preview_k1: UnitState = preview.get_unit_by_id(k1_id)
		var preview_ally: UnitState = preview.get_unit_by_id(ally_id)
		if preview_k1 == null or preview_ally == null:
			PlanningChecklistHarness.assert_fail(failures, label, "preview_board units missing")
		else:
			PlanningChecklistHarness.assert_eq_cell(
				failures, "%s/k1_preview" % label, preview_k1.position, proj_k1.position,
			)
			PlanningChecklistHarness.assert_eq_cell(
				failures, "%s/ally_preview" % label, preview_ally.position, proj_ally.position,
			)

	if expect.has("k1_mp"):
		PlanningChecklistHarness.assert_eq_int(
			failures, "%s/k1_mp" % label, proj_k1.movement.points_left, int(expect["k1_mp"]),
		)

	var pre_moves: Array[TimelineAction] = pre_moves_for_unit(director, k1_id)
	if expect.has("pre_move_count"):
		PlanningChecklistHarness.assert_eq_int(
			failures, "%s/pre_count" % label, pre_moves.size(), int(expect["pre_move_count"]),
		)
	if bool(expect.get("require_swap_first", false)):
		if pre_moves.is_empty():
			PlanningChecklistHarness.assert_fail(failures, label, "swap must write a pre-move entry")
			return
		var swap_action: TimelineAction = pre_moves[0]
		if swap_action.type != GameEnums.ActionType.ABILITY:
			PlanningChecklistHarness.assert_fail(failures, label, "first pre-move must be ability")
		elif swap_action.ability == null:
			PlanningChecklistHarness.assert_fail(failures, label, "swap ability missing on timeline")
		else:
			if swap_action.ability.id != PlanningChecklistHarness.KNIGHT_SWAP_ID:
				PlanningChecklistHarness.assert_fail(failures, label, "first pre-move must be knight_swap")
			if swap_action.target_unit_id != ally_id:
				PlanningChecklistHarness.assert_fail(failures, label, "swap must target ally")
	if expect.has("last_pre_dest"):
		if pre_moves.size() < 2:
			PlanningChecklistHarness.assert_fail(failures, label, "expected follow-up pre-move")
			return
		var walk_action: TimelineAction = pre_moves[pre_moves.size() - 1]
		if walk_action.type != GameEnums.ActionType.MOVE:
			PlanningChecklistHarness.assert_fail(failures, label, "follow-up pre-move must be MOVE")
		elif walk_action.target_coord != expect["last_pre_dest"]:
			PlanningChecklistHarness.assert_fail(
				failures, label, "follow-up pre-move destination %s" % walk_action.target_coord,
			)
		if expect.has("last_pre_waypoints"):
			if walk_action.waypoints != expect["last_pre_waypoints"]:
				PlanningChecklistHarness.assert_fail(
					failures, label, "follow-up pre-move waypoints %s" % walk_action.waypoints,
				)

	var sim_result: SimResult = PlanningChecklistHarness.simulate_committed(director)
	var sim_board: BoardState = sim_result.final_state
	for unit_id: int in [k1_id, ally_id]:
		var sim_unit: UnitState = sim_board.get_unit_by_id(unit_id)
		var proj_unit: UnitState = director.projected_state.get_unit_by_id(unit_id)
		var live_unit: UnitState = director.board.get_unit_by_id(unit_id)
		if sim_unit == null or proj_unit == null or live_unit == null:
			PlanningChecklistHarness.assert_fail(failures, label, "sim/projected/live unit %d missing" % unit_id)
			continue
		PlanningChecklistHarness.assert_eq_cell(
			failures, "%s/sim_%d" % [label, unit_id], sim_unit.position, proj_unit.position,
		)
		PlanningChecklistHarness.assert_eq_cell(
			failures, "%s/live_%d" % [label, unit_id], live_unit.position, sim_unit.position,
		)


static func assert_pre_move_walk_swap_shape(
	failures: Array[String],
	label: String,
	pre_moves: Array[TimelineAction],
	ally_id: int,
	walk_dest: Vector2i,
) -> void:
	if pre_moves.size() < 2:
		PlanningChecklistHarness.assert_fail(
			failures, label, "expected walk+swap pre-moves got %d" % pre_moves.size(),
		)
		return
	if pre_moves[0].type != GameEnums.ActionType.MOVE:
		PlanningChecklistHarness.assert_fail(failures, label, "first pre-move must be walk")
	elif pre_moves[0].target_coord != walk_dest:
		PlanningChecklistHarness.assert_fail(
			failures, label, "walk destination %s" % pre_moves[0].target_coord,
		)
	if pre_moves[1].type != GameEnums.ActionType.ABILITY:
		PlanningChecklistHarness.assert_fail(failures, label, "second pre-move must be swap ability")
	elif pre_moves[1].ability == null:
		PlanningChecklistHarness.assert_fail(failures, label, "swap ability missing")
	else:
		if pre_moves[1].ability.id != PlanningChecklistHarness.KNIGHT_SWAP_ID:
			PlanningChecklistHarness.assert_fail(failures, label, "second pre-move must be knight_swap")
		if pre_moves[1].target_unit_id != ally_id:
			PlanningChecklistHarness.assert_fail(failures, label, "swap must target ally")


static func run_k4_journey_mirror(
	fix: Dictionary,
	failures: Array[String],
	k4_id: int,
	expect: Dictionary,
) -> void:
	var unit: UnitState = fix.board.get_unit_by_id(k4_id)
	if unit == null:
		PlanningChecklistHarness.assert_fail(failures, "K4-01", "k4 unit missing")
		return
	if unit.movement.points_left != unit.movement.max_points:
		PlanningChecklistHarness.assert_fail(
			failures,
			"K4-01",
			"k4 MP must match factory max (%d) for bible run route got %d"
			% [unit.movement.max_points, unit.movement.points_left],
		)
	var bowling_idx: int = PlanningChecklistHarness.select_ability_for_unit(
		fix, k4_id, PlanningChecklistHarness.BOWLING_CHARGE_ID,
	)
	var bowling: AbilityData = null
	if bowling_idx >= 0:
		bowling = unit.active_abilities[bowling_idx]
	_Probe.probe_cell(
		failures, fix, k4_id, PlanningChecklistHarness.K4_START, {
			"blue_any": true,
			"red_on": true,
			"red_stand": PlanningChecklistHarness.K4_START,
			"ability": bowling,
			"manhattan": true,
		}, "K4-02/stand",
	)
	fix.input.auto_use_skill_after_move = false
	run_k4_run_live_parity(fix, failures, k4_id, bowling, "K4")
	var k4_projected: UnitState = PlanningChecklistHarness.projected_unit(fix, k4_id)
	expect["k4_pos"] = k4_projected.position if k4_projected != null else PlanningChecklistHarness.K4_START


static func run_execute_all_plans(
	fix: Dictionary,
	failures: Array[String],
	expect: Dictionary,
	k1_id: int,
	k2_id: int,
	k3_id: int,
	k4_id: int,
	e_bash_id: int,
	e_hook_id: int,
) -> void:
	var director: CombatDirector = fix.director
	var result: SimResult = PlanningChecklistHarness.simulate_committed(director)
	var board: BoardState = result.final_state
	PlanningChecklistHarness.assert_eq_cell(
		failures, "EXEC-01/k1", board.get_unit_by_id(k1_id).position, expect["k1_pos"] as Vector2i,
	)
	PlanningChecklistHarness.assert_eq_cell(
		failures, "EXEC-01/k2", board.get_unit_by_id(k2_id).position, expect["k2_pos"] as Vector2i,
	)
	PlanningChecklistHarness.assert_eq_cell(
		failures, "EXEC-01/k3", board.get_unit_by_id(k3_id).position, expect["k3_pos"] as Vector2i,
	)
	PlanningChecklistHarness.assert_eq_cell(
		failures, "EXEC-01/k4", board.get_unit_by_id(k4_id).position, expect["k4_pos"] as Vector2i,
	)
	PlanningChecklistHarness.assert_eq_cell(
		failures, "EXEC-01/e_bash", board.get_unit_by_id(e_bash_id).position, expect["e_bash_pos"] as Vector2i,
	)
	PlanningChecklistHarness.assert_eq_cell(
		failures, "EXEC-01/e_hook", board.get_unit_by_id(e_hook_id).position, expect["e_hook_pos"] as Vector2i,
	)
