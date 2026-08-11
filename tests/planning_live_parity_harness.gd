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
	PlanningChecklistHarness.set_unit_pools(fix, k1_id, 1, 3)
	PlanningChecklistHarness.select_ability_for_unit(fix, k1_id, PlanningChecklistHarness.SHIELD_BASH_ID)

	PlanningChecklistHarness.hover(fix, PlanningChecklistHarness.ENEMY_POS)
	var tap_slots: Dictionary = PlanningChecklistHarness.commit_production(
		fix, PlanningChecklistHarness.ENEMY_POS,
	)
	if PlanningChecklistHarness.slots_invalid(tap_slots):
		PlanningChecklistHarness.assert_fail(
			failures, "%s/selection" % label_prefix, "enemy tap commit failed",
		)
		return
	var selection_surface: Dictionary = PlanningChecklistHarness.mode_commit_surface(fix, k1_id)

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
	PlanningChecklistHarness.set_unit_pools(fix, k4_id, 1, 3)
	PlanningChecklistHarness.select_ability_for_unit(
		fix, k4_id, PlanningChecklistHarness.BOWLING_CHARGE_ID,
	)
	enter_k4_auto_run_paint_mode(fix, k4_id)
	run_k4_selection_route(fix, failures, k4_id, bowling, "%s/selection" % label_prefix)
	assert_k4_run_committed(fix, failures, k4_id, "%s/selection" % label_prefix)
	var selection_surface: Dictionary = PlanningChecklistHarness.mode_commit_surface(fix, k4_id)

	var failure_count_before_undo: int = failures.size()
	undo_until_unit_clear(fix, failures, k4_id, PlanningChecklistHarness.K4_START, label_prefix)
	if failures.size() > failure_count_before_undo:
		return

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
	PlanningChecklistHarness.flush_planning(fix)


static func run_k4_selection_route(
	fix: Dictionary,
	failures: Array[String],
	unit_id: int,
	bowling: AbilityData,
	label_prefix: String,
) -> void:
	var route: Array[Vector2i] = PlanningChecklistHarness.K4_DETOUR_PLUS_RUN_ROUTE
	PlanningChecklistHarness.select_unit(fix, unit_id, route[0])
	for step_index: int in range(1, route.size()):
		var cell: Vector2i = route[step_index]
		var step_label: String = "%s/step_%d" % [label_prefix, step_index]
		var expected_path: Array[Vector2i] = route.slice(0, step_index + 1)
		PlanningChecklistHarness.hover(fix, cell)
		assert_not_dragging(fix, failures, step_label)
		assert_preview_path_equals(fix, failures, unit_id, expected_path, "%s/path" % step_label)
		if cell == Vector2i(4, 2) or cell == PlanningChecklistHarness.K4_RUN_TRIGGER:
			PlanningChecklistHarness.settle_ability_hover(fix)
		if cell == Vector2i(4, 2):
			assert_k4_walk_loop_preview(fix, failures, unit_id, bowling, cell, "%s/walk_loop" % step_label)
		elif cell == PlanningChecklistHarness.K4_RUN_TRIGGER:
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
			assert_k4_walk_loop_preview(fix, failures, unit_id, bowling, cell, "%s/walk_loop_end" % step_label)
		elif cell == PlanningChecklistHarness.K4_RUN_TRIGGER:
			assert_k4_run_loop_preview(fix, failures, unit_id, "%s/run_trigger" % step_label)

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
		assert_preview_path_equals(
			fix, failures, unit_id, expected_path, "%s/path_%d" % [label, step_index],
		)
	PlanningChecklistHarness.hover(fix, release_cell)
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
		PlanningChecklistHarness.assert_fail(
			failures,
			label,
			"Run intent display AP expected 0 got %d" % input.planning_display_ap_left(unit_id),
		)
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
