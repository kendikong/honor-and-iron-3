class_name PlanningLiveParityHarness
extends RefCounted

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
	var bash_hover: Array[Vector2i] = selection_pre.get("preview_path", []) as Array
	PlanningChecklistHarness.assert_ghost_at_dest_until_walk_starts(
		failures,
		fix,
		k1_id,
		PlanningChecklistHarness.BASH_APPROACH,
		PlanningChecklistHarness.KNIGHT_START,
		"%s/selection/ghost" % label_prefix,
	)
	PlanningChecklistHarness.assert_non_move_step_move_preview(
		failures,
		fix,
		k1_id,
		bash_hover,
		PlanningChecklistHarness.KNIGHT_START,
		"%s/selection" % label_prefix,
	)
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
	assert_execution_preview_cleared_after_commit(
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
	reset_planning_interaction_layers(fix)


static func reset_planning_interaction_layers(fix: Dictionary) -> void:
	var input: CombatPlanningInput = fix.input
	var director: CombatDirector = fix.director
	if input != null:
		input.cancel_drag()
		input.preview_state.clear_interaction()
		input.preview_state.preview_board = null
		input.call("_restore_hover_preview")
	if director != null:
		PlanningChecklistHarness.flush_planning(fix)


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
	PlanningChecklistHarness.assert_ghost_at_dest_until_walk_starts(
		failures,
		fix,
		k4_id,
		PlanningChecklistHarness.K4_RUN_TRIGGER,
		PlanningChecklistHarness.K4_START,
		"%s/selection/ghost" % label_prefix,
	)
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
		"slots_signature": PlanningQAGateTest._intent_slot_signature(slots),
		"preview_path": PlanningChecklistHarness.display_move_route(fix, unit_id).duplicate(),
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
	PlanningChecklistHarness.assert_display_move_preview_after_commit(
		failures,
		fix,
		unit_id,
		pre_intent.get("preview_path", []) as Array,
		"%s/display" % label,
	)
	return true


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


static func assert_execution_preview_cleared_after_commit(
	fix: Dictionary,
	failures: Array[String],
	unit_id: int,
	pre_intent: Dictionary,
	label: String,
) -> void:
	PlanningChecklistHarness.assert_display_move_preview_after_commit(
		failures,
		fix,
		unit_id,
		pre_intent.get("preview_path", []) as Array,
		"%s/display" % label,
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
	var actual: Array[Vector2i] = PlanningChecklistHarness.display_move_route(fix, unit_id)
	var want: Array[Vector2i] = PlanningChecklistHarness.typed_cells(expected)
	if not PlanningChecklistHarness.routes_equal(actual, want):
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"display_move_route_cells expected %s got %s" % [str(want), str(actual)],
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
	reset_planning_interaction_layers(fix)
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
	PlanningBibleFixtureProbe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.SWAP_ALLY_CELL, {
			"blue_any": true,
			"ability": swap,
		}, "SWAP-01/hover",
	)
	PlanningChecklistHarness.assert_not_stepped_walk_corridor(
		failures, fix, k1_id, "SWAP-01/not_walk",
	)
	PlanningChecklistHarness.select_unit(fix, k1_id, PlanningChecklistHarness.SWAP_ALLY_CELL)
	var swap_pre: Dictionary = capture_preview_intent(
		fix, k1_id, PlanningChecklistHarness.SWAP_ALLY_CELL, false,
	)
	if PlanningChecklistHarness.slots_invalid(
		PlanningChecklistHarness.commit_production(fix, PlanningChecklistHarness.SWAP_ALLY_CELL),
	):
		PlanningChecklistHarness.assert_fail(failures, "SWAP-02", "swap commit failed")
		return
	PlanningChecklistHarness.assert_display_move_preview_after_commit(
		failures,
		fix,
		k1_id,
		swap_pre.get("preview_path", []) as Array,
		"SWAP-02/display",
	)
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
	PlanningBibleFixtureProbe.probe_cell(
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
	PlanningBibleFixtureProbe.probe_cell(
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
	PlanningBibleFixtureProbe.probe_cell(
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
	reset_planning_interaction_layers(fix)
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
	PlanningChecklistHarness.assert_display_move_route_empty(
		failures, fix, k1_id, "UNDO-03/cleared",
	)
	PlanningChecklistHarness.hover(fix, dest)
	PlanningChecklistHarness.flush_planning(fix)
	var live_after_undo: Array[Vector2i] = PlanningChecklistHarness.display_move_route(fix, k1_id)
	if live_after_undo.size() < 2:
		PlanningChecklistHarness.assert_fail(
			failures,
			"UNDO-03/live",
			"undo must restore live walk preview, got %s" % str(live_after_undo),
		)


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
	PlanningBibleFixtureProbe.probe_cell(
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
	PlanningBibleFixtureProbe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.BASH_HOVER_WALK, {
			"ghost_pos": PlanningChecklistHarness.BASH_HOVER_WALK,
			"path_end": PlanningChecklistHarness.BASH_HOVER_WALK,
			"path_start": PlanningChecklistHarness.KNIGHT_START,
			"path_min_size": 2,
			"manhattan": true,
			"preview_nonempty": true,
			"red_on": true,
			"red_stand": PlanningChecklistHarness.BASH_HOVER_WALK,
			"ability": bash,
			"icon_has": [PlanningIcons.GLYPH_WALK],
			"blue_any": true,
		}, "K1-04/walk",
	)
	PlanningChecklistHarness.assert_hover_field_outline(
		failures, fix, PlanningChecklistHarness.BASH_HOVER_WALK, true, "K1-04/outline",
	)
	if bash != null:
		PlanningChecklistHarness.assert_next_phase_red_from_hover_stand(
			failures,
			fix,
			bash,
			PlanningChecklistHarness.BASH_HOVER_WALK,
			PlanningChecklistHarness.KNIGHT_START,
			"K1-04/next_phase",
		)
	PlanningChecklistHarness.assert_illegal_hover_has_no_walk(
		failures,
		fix,
		k1_id,
		PlanningChecklistHarness.OFF_BLUE_CELL,
		"K1-04/illegal_restore",
	)
	PlanningChecklistHarness.select_unit(fix, k1_id, PlanningChecklistHarness.ENEMY_POS)
	PlanningChecklistHarness.refresh_attack_hover(fix, PlanningChecklistHarness.ENEMY_POS)
	var push_to: Vector2i = PlanningChecklistHarness.push_destination(fix, e_bash_id)
	if push_to.x <= PlanningChecklistHarness.E_BASH_CELL.x:
		PlanningChecklistHarness.assert_fail(failures, "K1-06", "push preview must be east of enemy")
	PlanningBibleFixtureProbe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.ENEMY_POS, {
			"path_end": PlanningChecklistHarness.BASH_APPROACH,
			"path_start": PlanningChecklistHarness.KNIGHT_START,
			"path_min_size": 3,
			"manhattan": true,
			"preview_nonempty": true,
			"blue_any": true,
			"red_on": true,
			"red_stand": PlanningChecklistHarness.BASH_APPROACH,
			"ability": bash,
			"icon_has": [PlanningIcons.GLYPH_WALK, PlanningIcons.GLYPH_ATTACK],
			"push_dest": push_to,
			"push_enemy_id": e_bash_id,
		}, "K1-05/approach",
	)
	if bash_idx >= 0:
		PlanningChecklistHarness.assert_preview_approach_tile(
			failures,
			"K1-05/facing",
			fix,
			e_bash_id,
			bash_idx,
			PlanningChecklistHarness.ENEMY_POS,
			PlanningChecklistHarness.BASH_APPROACH,
		)
	PlanningChecklistHarness.assert_forced_displace_not_walk_path(
		failures, fix, k1_id, push_to, "K1-05/push_not_walk",
	)
	PlanningChecklistHarness.assert_targeting_arrow_not_walk(
		failures, fix, k1_id, "K1-05/arrow_not_walk",
	)
	PlanningChecklistHarness.assert_walk_facing(
		failures, fix, k1_id, GameEnums.Facing.EAST, "K1-05/route_facing",
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
	PlanningBibleFixtureProbe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.ENEMY_POS, {
			"ability": bash,
		}, "K1-03/from_enemy",
	)
	PlanningBibleFixtureProbe.probe_cell(
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
			"display_empty": true,
		}, "K1-03/off_blue",
	)
	PlanningChecklistHarness.assert_hover_field_outline(
		failures, fix, PlanningChecklistHarness.OFF_BLUE_CELL, false, "K1-03/outline",
	)
	assert_off_blue_click_must_not_commit(
		fix, failures, k1_id, PlanningChecklistHarness.OFF_BLUE_CELL, "K1-03/off_blue_click",
	)
	PlanningChecklistHarness.hover_off_map(fix)
	PlanningBibleFixtureProbe.probe_cell(
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
	PlanningChecklistHarness.refresh_attack_hover(fix, PlanningChecklistHarness.K2_CELL)
	var hook: AbilityData = null
	if hook_idx >= 0:
		hook = fix.board.get_unit_by_id(k2_id).active_abilities[hook_idx]
	PlanningBibleFixtureProbe.probe_cell(
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
	PlanningBibleFixtureProbe.probe_cell(
		failures, fix, k2_id, Vector2i(2, 3), {
			"ghost_pos": Vector2i(2, 3),
			"path_end": Vector2i(2, 3),
			"path_start": PlanningChecklistHarness.K2_CELL,
			"path_min_size": 2,
			"manhattan": true,
			"preview_nonempty": true,
			"blue_any": true,
		}, "K2-02/walk",
	)
	var pull_preview: Vector2i = PlanningChecklistHarness.push_destination(fix, e_hook_id)
	if pull_preview.x > -900000 and pull_preview.x >= PlanningChecklistHarness.E_HOOK_CELL.x:
		PlanningChecklistHarness.assert_fail(failures, "K2-03", "pull preview must be west of enemy")
	PlanningBibleFixtureProbe.probe_cell(
		failures, fix, k2_id, PlanningChecklistHarness.E_HOOK_CELL, {
			"icon_has": [PlanningIcons.GLYPH_ATTACK],
			"blue_any": true,
			"red_on": true,
			"red_stand": PlanningChecklistHarness.K2_CELL,
			"ability": hook,
			"pull_dest": pull_preview,
			"pull_enemy_id": e_hook_id,
		}, "K2-03/enemy",
	)
	PlanningChecklistHarness.assert_forced_displace_not_walk_path(
		failures, fix, k2_id, pull_preview, "K2-03/pull_not_walk",
	)
	PlanningChecklistHarness.assert_targeting_arrow_not_walk(
		failures, fix, k2_id, "K2-03/arrow_not_walk",
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
	PlanningBibleFixtureProbe.probe_cell(
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
	PlanningBibleFixtureProbe.probe_cell(
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
	PlanningBibleFixtureProbe.probe_cell(
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
	PlanningBibleFixtureProbe.probe_cell(
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
	var trample_hover: Array[Vector2i] = sel_pre.get("preview_path", []) as Array
	PlanningChecklistHarness.assert_ghost_at_dest_until_walk_starts(
		failures,
		fix,
		k3_id,
		PlanningChecklistHarness.TRAMPLE_END,
		PlanningChecklistHarness.K3_CELL,
		"K3-05/ghost",
	)
	PlanningChecklistHarness.assert_non_move_step_move_preview(
		failures,
		fix,
		k3_id,
		trample_hover,
		Vector2i(5, 3),
		"K3-05",
	)
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
	PlanningBibleFixtureProbe.probe_cell(
		failures, fix, k3_id, PlanningChecklistHarness.TRAMPLE_END, {
			"blue_any": true,
			"manhattan": true,
		}, "K3-09/post_stand",
	)
	PlanningBibleFixtureProbe.probe_cell(
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
	PlanningBibleFixtureProbe.probe_cell(
		failures, fix, k3_id, PlanningChecklistHarness.TRAMPLE_POST_DEST, {
			"path": PlanningChecklistHarness.TRAMPLE_POST_ROUTE,
			"ghost_pos": PlanningChecklistHarness.TRAMPLE_POST_DEST,
			"manhattan": true,
			"preview_nonempty": true,
			"blue_any": true,
		}, "K3-11/post_hover_dest",
	)
	var post_hover: Array[Vector2i] = PlanningChecklistHarness.display_move_route(fix, k3_id)
	if not PlanningChecklistHarness.commit_painted_drop_on_cell(
		fix,
		PlanningChecklistHarness.TRAMPLE_POST_ROUTE,
		PlanningChecklistHarness.TRAMPLE_POST_DEST,
	):
		PlanningChecklistHarness.assert_fail(failures, "K3-12/post_drag", "post-trample drag failed")
		return
	PlanningChecklistHarness.assert_display_move_preview_after_commit(
		failures, fix, k3_id, post_hover, "K3-12/display",
	)
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
	PlanningBibleFixtureProbe.probe_cell(
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
	var k3_steps: Array[Vector2i] = []
	for ev: SimEvent in result.events:
		if ev.type == GameEnums.SimEventType.UNIT_MOVED and ev.moved_unit_id() == k3_id:
			var path_arr: Array = ev.data.get("path", [])
			for step: Variant in path_arr:
				k3_steps.append(step as Vector2i)
	if k3_steps.size() >= 2:
		PlanningChecklistHarness.assert_eq_cell(
			failures, "EXEC-01/k3_corridor_step0", k3_steps[0], PlanningChecklistHarness.TRAMPLE_ROUTE[0],
		)
		PlanningChecklistHarness.assert_eq_cell(
			failures, "EXEC-01/k3_corridor_step1", k3_steps[1], PlanningChecklistHarness.TRAMPLE_ROUTE[1],
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
	PlanningChecklistHarness.assert_execution_planning_ui_off(
		failures, fix, k1_id, "EXEC-01/ui_off",
	)


## Mirror shaped-skill AOE footprint & premove overlay parity (Cleave ARC).
static func run_aoe_cleave_session_mirror(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_aoe_cleave_board()
	var actor_id: int = fix["actor_id"] as int
	var actor: UnitState = fix.board.get_unit_by_id(actor_id)
	if actor == null:
		PlanningChecklistHarness.assert_fail(failures, "CLEAVE-01", "actor missing")
		return

	# Step 1: Pre-move from (4, 5) to (6, 5)
	PlanningChecklistHarness.enter_basic_movement(fix)
	PlanningChecklistHarness.select_unit(fix, actor_id, PlanningChecklistHarness.KNIGHT_START)
	var pre_route: Array[Vector2i] = [
		PlanningChecklistHarness.KNIGHT_START,
		PlanningChecklistHarness.BASH_HOVER_WALK,
		PlanningChecklistHarness.BASH_APPROACH,
	]
	var pre_intent: Dictionary = paint_route_and_capture_pre_intent(
		fix, actor_id, pre_route, PlanningChecklistHarness.BASH_APPROACH, true, "CLEAVE-01/premove", failures,
	)
	if pre_intent.is_empty():
		return
	if not commit_from_preview_intent(fix, actor_id, pre_intent, "CLEAVE-01/premove_release", failures):
		return
	var stand: Vector2i = PlanningChecklistHarness.projected_unit(fix, actor_id).position
	PlanningChecklistHarness.assert_eq_cell(failures, "CLEAVE-01/stand", stand, PlanningChecklistHarness.BASH_APPROACH)
	# Step 2: Select Cleave (ARC shaped skill)
	var cleave_idx: int = PlanningChecklistHarness.select_ability_for_unit(fix, actor_id, &"bruiser_cleave")
	if cleave_idx < 0:
		PlanningChecklistHarness.assert_fail(failures, "CLEAVE-02", "bruiser_cleave missing")
		return
	var cleave: AbilityData = actor.active_abilities[cleave_idx]

	# Step 3: Verify red action range tiles paint from latest stand (6, 5), not (4, 5)
	PlanningChecklistHarness.assert_red_contract(
		failures, "CLEAVE-03/red_range", fix, cleave, true, PlanningChecklistHarness.BASH_APPROACH, actor_id,
	)

	# Step 4: Arm Cleave on self (stand cell) for awaiting-target aiming
	var arm_pre: Dictionary = capture_preview_intent(fix, actor_id, PlanningChecklistHarness.BASH_APPROACH, false)
	if not commit_from_preview_intent(fix, actor_id, arm_pre, "CLEAVE-04/arm", failures):
		return
	var frozen_premove: Array[Vector2i] = pre_intent.get("preview_path", []) as Array
	if not fix.input.awaiting_targeting_active():
		PlanningChecklistHarness.assert_fail(
			failures, "CLEAVE-04/aim", "cleave arm must open target pick (non-move step)",
		)
	else:
		PlanningChecklistHarness.assert_blue_walk_tiles_off(failures, "CLEAVE-04/blue_off", fix)
		PlanningChecklistHarness.assert_frozen_walk_not_redrawn_by_mouse(
			failures,
			fix,
			actor_id,
			frozen_premove,
			PlanningChecklistHarness.KNIGHT_START,
			"CLEAVE-04/frozen",
		)
		PlanningChecklistHarness.assert_hover_field_outline(
			failures, fix, PlanningChecklistHarness.ENEMY_POS, true, "CLEAVE-04/outline",
		)

	# Step 5: Hover target at (7, 5) -> verify yellow blast footprint (ARC of 3 tiles)
	PlanningChecklistHarness.hover(fix, PlanningChecklistHarness.ENEMY_POS)
	PlanningChecklistHarness.flush_planning(fix)
	var aoe_harness_script: GDScript = load("res://tests/harness/aoe_footprint_qa_harness.gd") as GDScript
	if aoe_harness_script != null:
		aoe_harness_script.call(
			"assert_planning_overlay_footprint",
			failures, "CLEAVE-05/footprint", fix, cleave, PlanningChecklistHarness.BASH_APPROACH, PlanningChecklistHarness.ENEMY_POS,
		)

	# Step 6: Verify red action range and yellow blast coexist
	var overlay: TacticalPlanningOverlay = fix.overlay as TacticalPlanningOverlay
	if overlay != null:
		var red_tiles: Array[Vector2i] = overlay.get_hover_action_range_tiles()
		var yellow_tiles: Array[Vector2i] = overlay.get_hover_blast_tiles()
		if red_tiles.is_empty():
			PlanningChecklistHarness.assert_fail(failures, "CLEAVE-06/coexist", "red action range must not be erased by yellow blast")
		if yellow_tiles.size() != 3:
			PlanningChecklistHarness.assert_fail(failures, "CLEAVE-06/coexist", "cleave blast must have 3 arc tiles, got %d" % yellow_tiles.size())

	# Step 7: Verify live forecast predicts damage to dummy targets
	var live_prev: CombatPlanningPreview = overlay.get_live_preview() if overlay != null else null
	if live_prev != null and live_prev.forecast != null:
		var dmg: int = live_prev.forecast.damage_hp(fix.e1_id)
		if dmg <= 0:
			var any_dmg: bool = false
			for id_key: Variant in live_prev.forecast._damage_hp:
				if int(live_prev.forecast._damage_hp[id_key]) > 0:
					any_dmg = true
					break
			if not any_dmg:
				PlanningChecklistHarness.assert_fail(failures, "CLEAVE-07/forecast", "cleave hover forecast missing damage")

	# Step 8: Commit Cleave from preview
	var cleave_pre: Dictionary = capture_preview_intent(fix, actor_id, PlanningChecklistHarness.ENEMY_POS, false)
	if not commit_from_preview_intent(fix, actor_id, cleave_pre, "CLEAVE-08/commit", failures):
		return
	PlanningChecklistHarness.hover(fix, PlanningChecklistHarness.ENEMY_POS)
	PlanningChecklistHarness.flush_planning(fix)
	PlanningChecklistHarness.assert_yellow_blast_empty(failures, "CLEAVE-08/yellow_cleared", fix)

	# Step 9: Execution via simulate_committed -> verify all 3 dummies damaged
	var sim_result: SimResult = PlanningChecklistHarness.simulate_committed(fix.director)
	var final_board: BoardState = sim_result.final_state
	for e_id: int in [fix.e1_id, fix.e2_id, fix.e3_id]:
		var dummy: UnitState = final_board.get_unit_by_id(e_id)
		if dummy != null and dummy.health.current_hp >= dummy.health.max_hp:
			PlanningChecklistHarness.assert_fail(failures, "CLEAVE-09/sim", "dummy %d took no sim damage from cleave" % e_id)

	undo_until_unit_clear(fix, failures, actor_id, PlanningChecklistHarness.KNIGHT_START, "CLEAVE-10/undo")


static func run_wait_all_tiles_off(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bash_board()
	var knight: UnitState = fix.knight as UnitState
	if knight == null:
		PlanningChecklistHarness.assert_fail(failures, "WAIT-01", "knight missing")
		return
	var k1_id: int = knight.id
	PlanningChecklistHarness.select_unit(fix, k1_id, PlanningChecklistHarness.KNIGHT_START)
	PlanningChecklistHarness.select_wait(fix)
	PlanningChecklistHarness.hover(fix, PlanningChecklistHarness.KNIGHT_START)
	PlanningChecklistHarness.flush_planning(fix)
	PlanningChecklistHarness.assert_wait_all_tiles_off(failures, fix, k1_id, "WAIT-01/stand")
	PlanningChecklistHarness.assert_hover_field_outline(
		failures, fix, PlanningChecklistHarness.KNIGHT_START, false, "WAIT-01/outline_stand",
	)
	PlanningChecklistHarness.hover(fix, PlanningChecklistHarness.BASH_HOVER_WALK)
	PlanningChecklistHarness.flush_planning(fix)
	PlanningChecklistHarness.assert_wait_all_tiles_off(failures, fix, k1_id, "WAIT-01/walk_cell")
	PlanningChecklistHarness.assert_hover_field_outline(
		failures, fix, PlanningChecklistHarness.BASH_HOVER_WALK, false, "WAIT-01/outline_walk",
	)


static func run_charge_strike_stand_handoff(failures: Array[String]) -> void:
	const BruiserFixture := preload("res://tests/harness/bruiser_planning_checklist_harness.gd")
	var start := Vector2i(5, 4)
	var enemy_cell := Vector2i(8, 2)
	var pre_dest := Vector2i(6, 3)
	var charge_dest := Vector2i(7, 2)
	var pre_route: Array[Vector2i] = [start, Vector2i(6, 4), pre_dest]
	var fix: Dictionary = BruiserFixture.wire_board(
		start, enemy_cell, Vector2i(-1, -1), &"bruiser_charge_strike",
	)
	if fix.is_empty():
		PlanningChecklistHarness.assert_fail(failures, "CS-01", "bruiser Charge Strike fixture missing")
		return
	var actor: UnitState = fix.actor as UnitState
	if actor == null:
		PlanningChecklistHarness.assert_fail(failures, "CS-01", "bruiser missing")
		return
	var actor_id: int = actor.id
	PlanningChecklistHarness.set_unit_pools(fix, actor_id, 1, 8)
	fix.director.auto_run = false
	fix.input.auto_use_skill_after_move = false
	PlanningChecklistHarness.enter_basic_movement(fix)
	var pre_intent: Dictionary = paint_route_and_capture_pre_intent(
		fix, actor_id, pre_route, pre_dest, true, "CS-01/premove", failures,
	)
	if pre_intent.is_empty():
		return
	if not commit_from_preview_intent(fix, actor_id, pre_intent, "CS-01/premove_release", failures):
		return
	var idx: int = PlanningChecklistHarness.select_ability(fix, &"bruiser_charge_strike")
	if idx < 0:
		PlanningChecklistHarness.assert_fail(failures, "CS-02", "bruiser_charge_strike missing")
		return
	var charge: AbilityData = actor.active_abilities[idx]
	var arm_pre: Dictionary = capture_preview_intent(fix, actor_id, pre_dest, false)
	if not commit_from_preview_intent(fix, actor_id, arm_pre, "CS-02/arm", failures):
		return
	PlanningChecklistHarness.refresh_attack_hover(fix, charge_dest)
	var charge_hover: Array[Vector2i] = PlanningChecklistHarness.display_move_route(fix, actor_id)
	var charge_pre: Dictionary = capture_preview_intent(fix, actor_id, charge_dest, false)
	if not commit_from_preview_intent(fix, actor_id, charge_pre, "CS-03/charge", failures):
		return
	PlanningChecklistHarness.hover(fix, enemy_cell)
	PlanningChecklistHarness.flush_planning(fix)
	PlanningChecklistHarness.assert_red_contract(
		failures, "CS-04/red_stand", fix, charge, true, charge_dest, actor_id,
	)
	PlanningChecklistHarness.assert_blue_walk_tiles_off(failures, "CS-04/blue_off", fix)
	PlanningChecklistHarness.assert_frozen_walk_not_redrawn_by_mouse(
		failures, fix, actor_id, charge_hover, enemy_cell, "CS-04/frozen",
	)
	PlanningChecklistHarness.assert_ghost_at_dest_until_walk_starts(
		failures, fix, actor_id, charge_dest, pre_dest, "CS-04/ghost",
	)


## Mirror Bowling Charge advance: L-shape walk/arm, hover every red dash tile plus off-red, commit DASH 3 past enemy.
static func run_bowling_advance_session_mirror(failures: Array[String]) -> void:
	print("[SUITE] bowling_advance_mimic")
	var fix: Dictionary = PlanningChecklistHarness.wire_bowling_advance_board()
	var knight_id: int = fix.k1_id as int
	var enemy_id: int = fix.e_bowl_id as int
	fix.director.auto_run = false
	fix.input.auto_use_skill_after_move = false
	var bowling: AbilityData = _select_bowling(fix, failures, knight_id, "BA-01")
	if bowling == null:
		return
	_probe_unarmed_stand(fix, failures, knight_id, bowling)
	_probe_unarmed_l_walk(fix, failures, knight_id, bowling)
	if not _commit_l_walk_and_arm(fix, failures, knight_id, bowling, "BA-04"):
		return
	_probe_all_red_dash_tiles(fix, failures, knight_id, bowling, enemy_id, "BA-06")
	_probe_off_red_tiles(fix, failures, knight_id, bowling, "BA-07")
	var hover_route: Array[Vector2i] = _commit_dash_past_enemy(
		fix, failures, knight_id, bowling, enemy_id, "BA-08",
	)
	if hover_route.is_empty():
		return
	_assert_bowling_dash_committed(fix, failures, knight_id, enemy_id, "BA-09", hover_route)
	var selection_surface: Dictionary = PlanningChecklistHarness.mode_commit_surface(fix, knight_id)
	undo_until_unit_clear(
		fix, failures, knight_id, PlanningChecklistHarness.BOWLING_ADVANCE_START, "BA-10",
	)
	PlanningChecklistHarness.assert_display_move_route_empty(
		failures, fix, knight_id, "BA-10/cleared",
	)
	PlanningChecklistHarness.enter_basic_movement(fix)
	PlanningChecklistHarness.hover(fix, PlanningChecklistHarness.BOWLING_ADVANCE_L_MID)
	PlanningChecklistHarness.flush_planning(fix)
	var live_after_undo: Array[Vector2i] = PlanningChecklistHarness.display_move_route(fix, knight_id)
	if live_after_undo.size() < 2:
		PlanningChecklistHarness.assert_fail(
			failures,
			"BA-10/live",
			"undo must restore live walk preview, got %s" % str(live_after_undo),
		)
	bowling = _select_bowling(fix, failures, knight_id, "BA-11")
	if bowling == null:
		return
	if not _commit_l_walk_and_arm(fix, failures, knight_id, bowling, "BA-11"):
		return
	var hover_route_2: Array[Vector2i] = _commit_dash_past_enemy(
		fix, failures, knight_id, bowling, enemy_id, "BA-12",
	)
	if hover_route_2.is_empty():
		return
	_assert_bowling_dash_committed(fix, failures, knight_id, enemy_id, "BA-12", hover_route_2)
	var drag_surface: Dictionary = PlanningChecklistHarness.mode_commit_surface(fix, knight_id)
	PlanningChecklistHarness.assert_mode_commit_parity(
		failures, "ba/first", selection_surface, "ba/second", drag_surface,
	)
	_probe_postmove_from_landing(fix, failures, knight_id, bowling)
	_assert_execute_matches_projected(fix, failures, knight_id, enemy_id)


static func _select_bowling(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	label: String,
) -> AbilityData:
	var idx: int = PlanningChecklistHarness.select_ability_for_unit(
		fix, knight_id, PlanningChecklistHarness.BOWLING_CHARGE_ID,
	)
	if idx < 0:
		PlanningChecklistHarness.assert_fail(failures, label, "Bowling Charge missing")
		return null
	var unit: UnitState = fix.board.get_unit_by_id(knight_id)
	if unit == null:
		PlanningChecklistHarness.assert_fail(failures, label, "knight missing")
		return null
	return unit.active_abilities[idx]


static func _probe_unarmed_stand(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	bowling: AbilityData,
) -> void:
	PlanningBibleFixtureProbe.probe_cell(
		failures, fix, knight_id, PlanningChecklistHarness.BOWLING_ADVANCE_START, {
			"blue_any": true,
			"red_on": true,
			"red_stand": PlanningChecklistHarness.BOWLING_ADVANCE_START,
			"ability": bowling,
			"manhattan": true,
		}, "BA-01/stand",
	)


static func _probe_unarmed_l_walk(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	bowling: AbilityData,
) -> void:
	var mid: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_L_MID
	var stand: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_STAND
	var start: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_START
	PlanningBibleFixtureProbe.probe_cell(
		failures, fix, knight_id, mid, {
			"path": [start, mid],
			"ghost_pos": mid,
			"manhattan": true,
			"preview_nonempty": true,
			"icon_has": [PlanningIcons.GLYPH_WALK],
			"icon_not": [PlanningIcons.GLYPH_NULL],
			"red_on": true,
			"red_stand": mid,
			"ability": bowling,
		}, "BA-02/l_mid",
	)
	_assert_cursor_matches_slots(fix, failures, knight_id, mid, "BA-02/l_mid/cursor")
	_require_display_move_route(
		fix, failures, knight_id, start, mid, "BA-02/l_mid/display",
	)
	PlanningBibleFixtureProbe.probe_cell(
		failures, fix, knight_id, stand, {
			"path_start": start,
			"path_end": stand,
			"path_min_size": 3,
			"ghost_pos": stand,
			"manhattan": true,
			"preview_nonempty": true,
			"icon_has": [PlanningIcons.GLYPH_WALK],
			"icon_not": [PlanningIcons.GLYPH_NULL],
			"red_on": true,
			"red_stand": stand,
			"ability": bowling,
		}, "BA-03/l_dest",
	)
	_assert_cursor_matches_slots(fix, failures, knight_id, stand, "BA-03/l_dest/cursor")
	_require_display_move_route(
		fix, failures, knight_id, start, stand, "BA-03/l_dest/display",
	)


static func _commit_l_walk_and_arm(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	bowling: AbilityData,
	label: String,
) -> bool:
	var route: Array[Vector2i] = PlanningChecklistHarness.BOWLING_ADVANCE_L_ROUTE
	var dest: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_STAND
	PlanningChecklistHarness.select_unit(fix, knight_id, route[0])
	PlanningChecklistHarness.wait_ability_settle_sync(fix)
	PlanningChecklistHarness.clear_drag_state(fix)
	var unit: UnitState = fix.board.get_unit_by_id(knight_id)
	_paint_bowling_drag_route(fix.input, unit, route, dest)
	PlanningChecklistHarness.hover(fix, dest)
	PlanningChecklistHarness.flush_planning(fix)
	var painted_l: Array[Vector2i] = _require_display_move_route(
		fix, failures, knight_id, route[0], dest, "%s/l_walk/painted_display" % label,
	)
	if painted_l.size() < 2:
		return false
	var slots: Dictionary = PlanningChecklistHarness.drop_slots_for_cell(fix, dest)
	if PlanningChecklistHarness.slots_invalid(slots):
		PlanningChecklistHarness.assert_fail(failures, "%s/l_walk" % label, "L-walk premove commit failed")
		return false
	if not PlanningChecklistHarness.commit_slots_production(fix, slots):
		PlanningChecklistHarness.assert_fail(failures, "%s/l_walk" % label, "L-walk premove commit failed")
		return false
	PlanningChecklistHarness.clear_drag_state(fix)
	_assert_premove_executed_and_preview_cleared(fix, failures, knight_id, dest, "%s/premove_clear" % label)
	var after_l: Array[Vector2i] = fix.input.display_move_route_cells(knight_id)
	if _routes_equal(after_l, painted_l):
		PlanningChecklistHarness.assert_fail(
			failures,
			"%s/premove_clear" % label,
			"executed L-walk must clear THAT display_move_route_cells path %s" % str(painted_l),
		)
	var pre: TimelineAction = PlanningChecklistHarness.committed_pre_move(fix.director, knight_id)
	if pre == null:
		PlanningChecklistHarness.assert_fail(failures, "%s/premove" % label, "L-walk must write a pre-move")
		return false
	if pre.target_coord != dest:
		PlanningChecklistHarness.assert_fail(
			failures, "%s/premove" % label, "L-walk dest %s got %s" % [dest, pre.target_coord],
		)
		return false
	if pre.waypoints != PlanningChecklistHarness.BOWLING_ADVANCE_L_WAYPOINTS:
		PlanningChecklistHarness.assert_fail(
			failures,
			"%s/premove" % label,
			"L-walk waypoints %s expected %s" % [pre.waypoints, PlanningChecklistHarness.BOWLING_ADVANCE_L_WAYPOINTS],
		)
	PlanningChecklistHarness.select_ability_for_unit(
		fix, knight_id, PlanningChecklistHarness.BOWLING_CHARGE_ID,
	)
	PlanningChecklistHarness.select_unit(fix, knight_id, dest)
	if not fix.input.awaiting_targeting_active():
		var arm_slots: Dictionary = PlanningChecklistHarness.commit_production(fix, dest)
		if PlanningChecklistHarness.slots_invalid(arm_slots):
			PlanningChecklistHarness.assert_fail(failures, "%s/arm" % label, "walk/arm self-tap failed")
			return false
	if not fix.input.awaiting_targeting_active():
		PlanningChecklistHarness.assert_fail(failures, "%s/arm" % label, "bowling must arm awaiting dash after L-walk")
		return false
	if fix.director.find_awaiting_action(knight_id) == null:
		PlanningChecklistHarness.assert_fail(failures, "%s/arm" % label, "awaiting bowling action missing")
		return false
	PlanningBibleFixtureProbe.probe_cell(
		failures, fix, knight_id, dest, {
			"red_on": true,
			"red_stand": dest,
			"ability": bowling,
			"manhattan": true,
		}, "%s/armed_stand" % label,
	)
	var armed_display: Array[Vector2i] = fix.input.display_move_route_cells(knight_id)
	if armed_display.size() >= 2:
		PlanningChecklistHarness.assert_fail(
			failures,
			"%s/armed_stand/display" % label,
			"armed stand with no dash hover must not keep a move preview, got %s" % str(armed_display),
		)
	return true


static func _paint_bowling_drag_route(
	input: CombatPlanningInput,
	unit: UnitState,
	route: Array[Vector2i],
	dest: Vector2i,
) -> void:
	input._drag_unit_id = unit.id
	input._drag_unit_was_selected = true
	input._drag_route = route.duplicate()
	input._drag_last_free = dest
	input.dragging = true
	var intent := CombatIntentState.new()
	intent.bind(input._director)
	intent.set_hover_coord(dest)
	input._intent_state = intent


static func _assert_premove_executed_and_preview_cleared(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	dest: Vector2i,
	label: String,
) -> void:
	var live: UnitState = fix.director.board.get_unit_by_id(knight_id)
	if live == null or live.position != dest:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"premove executes immediately; live stand expected %s got %s"
			% [dest, live.position if live != null else Vector2i(-1, -1)],
		)
	var projected: UnitState = PlanningChecklistHarness.projected_unit(fix, knight_id)
	if projected == null or projected.position != dest:
		PlanningChecklistHarness.assert_fail(
			failures, label, "projected stand after premove expected %s" % dest,
		)
	var pre_leg: Array = fix.input.display_committed_move_route_leg(
		knight_id, GameEnums.MoveTiming.PRE_ACTION, dest,
	)
	if not pre_leg.is_empty():
		PlanningChecklistHarness.assert_fail(
			failures, label, "executed L-walk committed leg must clear, got %s" % str(pre_leg),
		)
	var display_route: Array[Vector2i] = fix.input.display_move_route_cells(knight_id)
	if display_route.size() >= 2:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"executed L-walk must not keep a live move preview, got %s" % str(display_route),
		)
	var live_path: Array[Vector2i] = PlanningChecklistHarness.preview_path(fix, knight_id)
	if live_path.size() >= 2 and live_path[0] == PlanningChecklistHarness.BOWLING_ADVANCE_START:
		PlanningChecklistHarness.assert_fail(
			failures, label, "live preview path must not keep the executed L-walk, got %s" % str(live_path),
		)


static func _probe_all_red_dash_tiles(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	bowling: AbilityData,
	enemy_id: int,
	label: String,
) -> void:
	var stand: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_STAND
	PlanningChecklistHarness.select_unit(fix, knight_id, stand)
	PlanningChecklistHarness.flush_planning(fix)
	var overlay_red: Array[Vector2i] = PlanningChecklistHarness.collect_red_tiles(fix)
	var unit: UnitState = PlanningChecklistHarness.projected_unit(fix, knight_id)
	var expected_red: Array[Vector2i] = AbilitySystem.planning_action_range_tiles(
		fix.director.projected_state if fix.director.projected_state != null else fix.board,
		unit,
		bowling,
		stand,
	)
	if overlay_red.is_empty():
		PlanningChecklistHarness.assert_fail(failures, label, "armed bowling must paint red dash tiles")
		return
	for tile: Vector2i in expected_red:
		if not overlay_red.has(tile):
			PlanningChecklistHarness.assert_fail(
				failures, label, "missing red dash tile %s from stand %s" % [tile, stand],
			)
	for tile: Vector2i in overlay_red:
		_assert_red_dash_hover(
			fix, failures, knight_id, bowling, enemy_id, stand, tile, "%s/%s" % [label, tile],
		)
	PlanningChecklistHarness.assert_eq_int(
		failures, "%s/count" % label, overlay_red.size(), expected_red.size(),
	)


static func _assert_red_dash_hover(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	bowling: AbilityData,
	enemy_id: int,
	stand: Vector2i,
	tile: Vector2i,
	label: String,
) -> void:
	PlanningChecklistHarness.refresh_attack_hover(fix, tile)
	var path: Array[Vector2i] = fix.input.display_move_route_cells(knight_id)
	if path.size() < 2:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"red dash tile %s must show display_move_route_cells (got %s); dash is a movement module"
			% [tile, str(path)],
		)
		return
	_assert_dash_path_is_straight_walk(failures, stand, tile, path, label)
	var ghost: Vector2i = PlanningChecklistHarness.preview_unit_pos(fix, knight_id)
	PlanningChecklistHarness.assert_eq_cell(failures, "%s/ghost" % label, ghost, tile)
	var slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, tile)
	if PlanningChecklistHarness.slots_invalid(slots):
		PlanningChecklistHarness.assert_fail(
			failures, label, "red dash tile %s must be selectable (got invalid slots)" % tile,
		)
		return
	var actions: Array = slots.get("action", []) as Array
	if actions.is_empty():
		PlanningChecklistHarness.assert_fail(failures, label, "red dash tile %s must build an action, not ∅" % tile)
		return
	if actions[0] is TimelineAction:
		var dash: TimelineAction = actions[0] as TimelineAction
		if dash.target_coord != tile:
			PlanningChecklistHarness.assert_fail(
				failures, label, "dash target_coord %s expected %s" % [dash.target_coord, tile],
			)
		if dash.target_unit_id != -1:
			PlanningChecklistHarness.assert_fail(
				failures, label, "bowling dash is TILE targeting, got unit %d" % dash.target_unit_id,
			)
	_assert_cursor_matches_slots(fix, failures, knight_id, tile, "%s/cursor" % label)
	var icon: String = fix.input.compute_hover_action_icon(tile)
	if icon == PlanningIcons.GLYPH_NULL or icon == "":
		PlanningChecklistHarness.assert_fail(failures, label, "red dash hover must not show ∅ at %s" % tile)
	PlanningChecklistHarness.assert_red_contract(
		failures, "%s/red" % label, fix, bowling, true, stand, knight_id,
	)
	PlanningChecklistHarness.assert_enemy_live_unchanged(
		failures, "%s/live_enemy" % label, fix, enemy_id, PlanningChecklistHarness.BOWLING_ADVANCE_ENEMY,
	)
	if tile == PlanningChecklistHarness.BOWLING_ADVANCE_DEST:
		var projected_enemy: UnitState = PlanningChecklistHarness.projected_unit(fix, enemy_id)
		if projected_enemy != null and projected_enemy.position == PlanningChecklistHarness.BOWLING_ADVANCE_ENEMY:
			var hover_enemy: UnitState = null
			if fix.input.preview_state != null and fix.input.preview_state.preview_board != null:
				hover_enemy = fix.input.preview_state.preview_board.get_unit_by_id(enemy_id)
			if hover_enemy == null or hover_enemy.position == PlanningChecklistHarness.BOWLING_ADVANCE_ENEMY:
				PlanningChecklistHarness.assert_fail(
					failures, label, "dash past enemy must predict bulldoze displacement",
				)


static func _assert_dash_path_is_straight_walk(
	failures: Array[String],
	stand: Vector2i,
	dest: Vector2i,
	path: Array[Vector2i],
	label: String,
) -> void:
	if path.is_empty():
		PlanningChecklistHarness.assert_fail(
			failures, label, "dash movement module must show a move preview to %s" % dest,
		)
		return
	var line: Array[Vector2i] = PhysicsSystem.cardinal_straight_line_path(stand, dest)
	if line.is_empty():
		PlanningChecklistHarness.assert_fail(
			failures, label, "dash dest %s is not on a cardinal line from %s" % [dest, stand],
		)
		return
	if path[path.size() - 1] != dest:
		PlanningChecklistHarness.assert_fail(
			failures, label, "dash path must end at hover %s got %s" % [dest, path[path.size() - 1]],
		)
	if path[0] != stand and path[0] != line[0]:
		PlanningChecklistHarness.assert_fail(
			failures, label, "dash path must start at stand %s or first step %s, got %s" % [stand, line[0], path[0]],
		)
	for i: int in range(1, path.size()):
		if GridSystem.manhattan(path[i - 1], path[i]) != 1:
			PlanningChecklistHarness.assert_fail(
				failures,
				label,
				"dash path skipped a tile at step %d (%s -> %s); dash is not teleport"
				% [i, path[i - 1], path[i]],
			)
			return
	for cell: Vector2i in line:
		if not path.has(cell):
			PlanningChecklistHarness.assert_fail(
				failures,
				label,
				"dash path %s skipped straight-line cell %s (not a teleport hop)" % [str(path), cell],
			)
			return
	if GridSystem.manhattan(stand, dest) > 1 and path.size() < 2:
		PlanningChecklistHarness.assert_fail(
			failures, label, "dash past one tile must visit every cell, got hop %s" % str(path),
		)


static func _probe_off_red_tiles(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	bowling: AbilityData,
	label: String,
) -> void:
	var stand: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_STAND
	var off_cells: Array[Vector2i] = [
		PlanningChecklistHarness.BOWLING_ADVANCE_OFF_RED_A,
		PlanningChecklistHarness.BOWLING_ADVANCE_OFF_RED_B,
	]
	for cell: Vector2i in off_cells:
		PlanningChecklistHarness.refresh_attack_hover(fix, cell)
		var red: Array[Vector2i] = PlanningChecklistHarness.collect_red_tiles(fix)
		if red.has(cell):
			PlanningChecklistHarness.assert_fail(
				failures, "%s/%s" % [label, cell], "off-red cell %s must not be painted red" % cell,
			)
		var slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, cell)
		var icon: String = fix.input.compute_hover_action_icon(cell)
		var path: Array[Vector2i] = fix.input.display_move_route_cells(knight_id)
		if not PlanningChecklistHarness.slots_invalid(slots) and not (slots.get("action", []) as Array).is_empty():
			PlanningChecklistHarness.assert_fail(
				failures, "%s/%s" % [label, cell], "off-red hover must not build a dash action",
			)
		if icon != PlanningIcons.GLYPH_NULL and icon != "":
			if icon.contains(PlanningIcons.GLYPH_DASH):
				PlanningChecklistHarness.assert_fail(
					failures, "%s/%s" % [label, cell], "off-red must not show dash cursor, got %s" % icon,
				)
		if not path.is_empty() and path.size() >= 2:
			PlanningChecklistHarness.assert_fail(
				failures,
				"%s/%s" % [label, cell],
				"invalid hover must show no walk path, got %s" % str(path),
			)
		PlanningChecklistHarness.assert_red_contract(
			failures, "%s/%s/red_from_stand" % [label, cell], fix, bowling, true, stand, knight_id,
		)
	assert_off_blue_click_must_not_commit(
		fix, failures, knight_id, PlanningChecklistHarness.BOWLING_ADVANCE_OFF_RED_A, "%s/click_a" % label,
	)
	assert_off_blue_click_must_not_commit(
		fix, failures, knight_id, PlanningChecklistHarness.BOWLING_ADVANCE_OFF_RED_B, "%s/click_b" % label,
	)


static func _commit_dash_past_enemy(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	bowling: AbilityData,
	enemy_id: int,
	label: String,
) -> Array[Vector2i]:
	var dest: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_DEST
	var stand: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_STAND
	PlanningChecklistHarness.refresh_attack_hover(fix, dest)
	_assert_red_dash_hover(
		fix, failures, knight_id, bowling, enemy_id, stand, dest, "%s/pre_commit" % label,
	)
	var hover_route: Array[Vector2i] = fix.input.display_move_route_cells(knight_id)
	if hover_route.size() < 2:
		PlanningChecklistHarness.assert_fail(
			failures,
			"%s/hover_display" % label,
			"dash hover display_move_route_cells empty or < 2 before commit: %s" % str(hover_route),
		)
		return []
	if hover_route[0] != stand or hover_route[hover_route.size() - 1] != dest:
		PlanningChecklistHarness.assert_fail(
			failures,
			"%s/hover_display" % label,
			"dash hover route %s must start at %s and end at %s" % [str(hover_route), stand, dest],
		)
		return []
	var pre_intent: Dictionary = capture_preview_intent(
		fix, knight_id, dest, false,
	)
	if not commit_from_preview_intent(
		fix, knight_id, pre_intent, "%s/release" % label, failures,
	):
		return []
	var post_commit: Array[Vector2i] = fix.input.display_move_route_cells(knight_id)
	if post_commit.size() < 2:
		PlanningChecklistHarness.assert_fail(
			failures,
			"%s/persist_display" % label,
			"display_move_route_cells was wiped after dash commit: %s" % str(post_commit),
		)
	elif not _routes_equal(post_commit, hover_route):
		PlanningChecklistHarness.assert_fail(
			failures,
			"%s/persist_display" % label,
			"committed display_move_route_cells %s differs from hover %s" % [str(post_commit), str(hover_route)],
		)
	return hover_route


static func _assert_bowling_dash_committed(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	enemy_id: int,
	label: String,
	hover_route: Array[Vector2i],
) -> void:
	var dest: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_DEST
	var stand: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_STAND
	var action: TimelineAction = PlanningChecklistHarness.committed_action(fix.director, knight_id)
	if action == null:
		PlanningChecklistHarness.assert_fail(failures, label, "bowling dash action missing")
		return
	if action.target_coord != dest:
		PlanningChecklistHarness.assert_fail(
			failures, label, "bowling dest %s got %s" % [dest, action.target_coord],
		)
	var projected: UnitState = PlanningChecklistHarness.projected_unit(fix, knight_id)
	if projected == null or projected.position != dest:
		PlanningChecklistHarness.assert_fail(failures, label, "projected knight must land at %s" % dest)
	if projected != null and projected.ability.points_left != 0:
		PlanningChecklistHarness.assert_fail(failures, label, "bowling must spend AP")
	PlanningChecklistHarness.assert_enemy_live_unchanged(
		failures, "%s/live_enemy" % label, fix, enemy_id, PlanningChecklistHarness.BOWLING_ADVANCE_ENEMY,
	)
	var live_knight: UnitState = fix.director.board.get_unit_by_id(knight_id)
	if live_knight == null or live_knight.position != stand:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"dash has not executed yet; live knight must remain at armed stand %s" % stand,
		)
	var persist_path: Array[Vector2i] = fix.input.display_move_route_cells(knight_id)
	if persist_path.size() < 2:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"display_move_route_cells was wiped after dash commit (walk has not started): %s"
			% str(persist_path),
		)
	elif not _routes_equal(persist_path, hover_route):
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"committed display_move_route_cells %s differs from hover %s"
			% [str(persist_path), str(hover_route)],
		)
	else:
		_assert_dash_path_is_straight_walk(failures, stand, dest, persist_path, "%s/committed_path" % label)
	var action_route: Array = fix.input.display_committed_action_route_cells(knight_id, action, stand)
	var typed_action: Array[Vector2i] = _typed_cells(action_route)
	if typed_action.size() < 2:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"display_committed_action_route_cells empty or < 2: %s" % str(typed_action),
		)
	elif not _routes_equal(typed_action, hover_route):
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"committed action route %s differs from hover %s" % [str(typed_action), str(hover_route)],
		)
	var ghost: Vector2i = PlanningChecklistHarness.preview_unit_pos(fix, knight_id)
	PlanningChecklistHarness.assert_eq_cell(failures, "%s/ghost" % label, ghost, dest)
	var bowling: AbilityData = action.ability
	PlanningChecklistHarness.assert_red_contract(
		failures, "%s/post_commit_red" % label, fix, bowling, false, dest, knight_id,
	)
	PlanningChecklistHarness.assert_non_move_step_move_preview(
		failures,
		fix,
		knight_id,
		hover_route,
		PlanningChecklistHarness.BOWLING_ADVANCE_OFF_RED_A,
		label,
	)


static func _probe_postmove_from_landing(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	bowling: AbilityData,
) -> void:
	var land: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_DEST
	var post: Vector2i = PlanningChecklistHarness.BOWLING_ADVANCE_POST_DEST
	PlanningChecklistHarness.select_unit(fix, knight_id, land)
	PlanningChecklistHarness.enter_basic_movement(fix)
	PlanningBibleFixtureProbe.probe_cell(
		failures, fix, knight_id, land, {
			"blue_any": true,
			"manhattan": true,
		}, "BA-13/post_stand",
	)
	PlanningBibleFixtureProbe.probe_cell(
		failures, fix, knight_id, post, {
			"path": [land, post],
			"ghost_pos": post,
			"manhattan": true,
			"preview_nonempty": true,
			"icon_has": [PlanningIcons.GLYPH_WALK],
			"icon_not": [PlanningIcons.GLYPH_NULL],
			"blue_has": [post],
		}, "BA-14/post_hover",
	)
	_assert_cursor_matches_slots(fix, failures, knight_id, post, "BA-14/post_cursor")
	var post_hover: Array[Vector2i] = _require_display_move_route(
		fix, failures, knight_id, land, post, "BA-14/post_display",
	)
	var post_route: Array[Vector2i] = [land, post]
	if not PlanningChecklistHarness.commit_painted_drop_on_cell(fix, post_route, post):
		PlanningChecklistHarness.assert_fail(failures, "BA-15/post_commit", "postmove after bowling failed")
		return
	var post_action: TimelineAction = PlanningChecklistHarness.committed_post_move(fix.director, knight_id)
	if post_action == null:
		PlanningChecklistHarness.assert_fail(failures, "BA-15/post_commit", "post-move missing")
		return
	if post_action.target_coord != post:
		PlanningChecklistHarness.assert_fail(failures, "BA-15/post_commit", "post-move dest")
	var live_after_post: UnitState = fix.director.board.get_unit_by_id(knight_id)
	var post_display: Array[Vector2i] = fix.input.display_move_route_cells(knight_id)
	if live_after_post != null and live_after_post.position == post:
		if post_display.size() >= 2 and post_display[post_display.size() - 1] == post:
			PlanningChecklistHarness.assert_fail(
				failures,
				"BA-15/post_display",
				"executed postmove must clear THAT display_move_route_cells, got %s" % str(post_display),
			)
	elif post_hover.size() >= 2 and not _routes_equal(post_display, post_hover):
		PlanningChecklistHarness.assert_fail(
			failures,
			"BA-15/post_display",
			"postmove has not started walking; display_move_route_cells %s must equal hover %s"
			% [str(post_display), str(post_hover)],
		)
	PlanningChecklistHarness.assert_red_contract(
		failures, "BA-16/post_after_commit", fix, bowling, false, post, knight_id,
	)


static func _assert_execute_matches_projected(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	enemy_id: int,
) -> void:
	var result: SimResult = PlanningChecklistHarness.simulate_committed(fix.director)
	var sim_board: BoardState = result.final_state
	var proj_k: UnitState = PlanningChecklistHarness.projected_unit(fix, knight_id)
	var proj_e: UnitState = PlanningChecklistHarness.projected_unit(fix, enemy_id)
	var sim_k: UnitState = sim_board.get_unit_by_id(knight_id)
	var sim_e: UnitState = sim_board.get_unit_by_id(enemy_id)
	if sim_k == null or proj_k == null:
		PlanningChecklistHarness.assert_fail(failures, "BA-17/exec", "knight missing at execute")
		return
	PlanningChecklistHarness.assert_eq_cell(failures, "BA-17/k", sim_k.position, proj_k.position)
	if sim_e == null or proj_e == null:
		PlanningChecklistHarness.assert_fail(failures, "BA-17/exec", "enemy missing at execute")
		return
	PlanningChecklistHarness.assert_eq_cell(failures, "BA-17/e", sim_e.position, proj_e.position)
	if sim_e.position == PlanningChecklistHarness.BOWLING_ADVANCE_ENEMY:
		PlanningChecklistHarness.assert_fail(
			failures, "BA-17/exec", "execute must displace the enemy bowling charged through",
		)


static func _assert_cursor_matches_slots(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	cell: Vector2i,
	label: String,
) -> void:
	var unit: UnitState = fix.board.get_unit_by_id(knight_id)
	var slots: Dictionary = PlanningChecklistHarness.slots_for_hover(fix, cell)
	var hover_icon: String = fix.input.compute_hover_action_icon(cell)
	var expected_icon: String = fix.input._cursor_icon_from_commit_slots(slots, unit)
	if hover_icon != expected_icon:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"cursor %s must match slots cursor %s at %s" % [hover_icon, expected_icon, cell],
		)


static func _require_display_move_route(
	fix: Dictionary,
	failures: Array[String],
	knight_id: int,
	expected_start: Vector2i,
	expected_end: Vector2i,
	label: String,
) -> Array[Vector2i]:
	var route: Array[Vector2i] = fix.input.display_move_route_cells(knight_id)
	if route.size() < 2:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"display_move_route_cells empty or < 2 (got %s); move preview must be on screen"
			% str(route),
		)
		return []
	if route[0] != expected_start or route[route.size() - 1] != expected_end:
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"display_move_route_cells %s must start at %s and end at %s"
			% [str(route), expected_start, expected_end],
		)
		return []
	for i: int in range(1, route.size()):
		if GridSystem.manhattan(route[i - 1], route[i]) != 1:
			PlanningChecklistHarness.assert_fail(
				failures,
				label,
				"display_move_route_cells skipped a tile at %s -> %s"
				% [route[i - 1], route[i]],
			)
			return []
	return route


static func _routes_equal(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
	if a.size() != b.size():
		return false
	for i: int in range(a.size()):
		if a[i] != b[i]:
			return false
	return true


static func _typed_cells(raw: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for v: Variant in raw:
		out.append(v as Vector2i)
	return out
