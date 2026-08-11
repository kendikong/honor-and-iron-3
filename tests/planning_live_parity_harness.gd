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


const _Probe := preload("res://tests/planning_bible_fixture_probe.gd")


## Full mirror of test_live_planning_bible_multi_knight_session (fixture board).
static func run_bible_multi_knight_session(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_bible_board()
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
			"icon_is": PlanningIcons.GLYPH_NULL,
			"slots_invalid": true,
			"tiles_only_in_bounds": true,
		}, "K1-03/off_blue",
	)
	var off_slots: Dictionary = PlanningChecklistHarness.slots_for_click(
		fix, PlanningChecklistHarness.OFF_BLUE_CELL,
	)
	if not PlanningChecklistHarness.slots_invalid(off_slots):
		PlanningChecklistHarness.assert_fail(failures, "K1-03/off_blue_click", "off-blue slots must be invalid")
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
	var tap_slots: Dictionary = PlanningChecklistHarness.commit_production(
		fix, PlanningChecklistHarness.E_HOOK_CELL,
	)
	if PlanningChecklistHarness.slots_invalid(tap_slots):
		PlanningChecklistHarness.assert_fail(failures, "K2-04/selection", "hook tap commit failed")
		return
	assert_k2_hook_committed(fix, failures, k2_id, e_hook_id, "K2-04/selection")
	var selection_surface: Dictionary = PlanningChecklistHarness.mode_commit_surface(fix, k2_id)
	undo_until_unit_clear(fix, failures, k2_id, PlanningChecklistHarness.K2_CELL, "K2-05")
	PlanningChecklistHarness.select_ability_for_unit(fix, k2_id, PlanningChecklistHarness.CHAIN_HOOK_ID)
	if not PlanningChecklistHarness.commit_painted_drop_on_cell(
		fix, [PlanningChecklistHarness.K2_CELL], PlanningChecklistHarness.E_HOOK_CELL,
	):
		PlanningChecklistHarness.assert_fail(failures, "K2-06/drag", "hook drag commit failed")
		return
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
	if not PlanningChecklistHarness.arm_trample_awaiting(fix, k3_id):
		PlanningChecklistHarness.assert_fail(failures, "K3-02", "trample arm failed")
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
	if not PlanningChecklistHarness.arm_trample_awaiting(fix, k3_id):
		PlanningChecklistHarness.assert_fail(failures, "K3-05", "rearm trample failed")
		return
	var tap_slots: Dictionary = PlanningChecklistHarness.commit_production(
		fix, PlanningChecklistHarness.TRAMPLE_END,
	)
	if PlanningChecklistHarness.slots_invalid(tap_slots):
		PlanningChecklistHarness.assert_fail(failures, "K3-05/selection", "trample tap failed")
		return
	assert_k3_trample_committed(fix, failures, k3_id, "K3-05/selection", false)
	var selection_surface: Dictionary = PlanningChecklistHarness.mode_commit_surface(fix, k3_id)
	undo_until_unit_clear(fix, failures, k3_id, PlanningChecklistHarness.K3_CELL, "K3-06")
	if not PlanningChecklistHarness.arm_trample_awaiting(fix, k3_id):
		PlanningChecklistHarness.assert_fail(failures, "K3-07", "rearm for drag failed")
		return
	var route: Array[Vector2i] = [
		PlanningChecklistHarness.K3_CELL,
		PlanningChecklistHarness.TRAMPLE_ROUTE[0],
		PlanningChecklistHarness.TRAMPLE_ROUTE[1],
	]
	if not PlanningChecklistHarness.commit_painted_drop_on_cell(
		fix, route, PlanningChecklistHarness.TRAMPLE_END,
	):
		PlanningChecklistHarness.assert_fail(failures, "K3-07/drag", "trample drag failed")
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
	var projected: UnitState = PlanningChecklistHarness.projected_unit(fix, k3_id)
	if projected == null or projected.position != PlanningChecklistHarness.TRAMPLE_POST_DEST:
		PlanningChecklistHarness.assert_fail(failures, label, "post projected position")


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
	if unit.movement.points_left != 3:
		PlanningChecklistHarness.assert_fail(
			failures,
			"K4-01",
			"k4 MP must be 3 for bible run route got %d" % unit.movement.points_left,
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


static func run_swap_adjacent_premove_mirror(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_swap_board(
		PlanningChecklistHarness.SWAP_ALLY_CELL,
	)
	var director: CombatDirector = fix.director
	var k1_id: int = fix.k1_id as int
	var ally_id: int = fix.ally_id as int
	var start_mp: int = fix.start_k1_mp as int
	director.auto_run = true
	if PlanningChecklistHarness.select_ability_for_unit(fix, k1_id, PlanningChecklistHarness.KNIGHT_SWAP_ID) < 0:
		PlanningChecklistHarness.assert_fail(failures, "SWAP-01", "swap ability missing")
		return
	_Probe.probe_cell(
		failures, fix, k1_id, PlanningChecklistHarness.SWAP_ALLY_CELL, {
			"blue_any": true,
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
	PlanningChecklistHarness.assert_swap_board_layers(
		failures, "SWAP-03", fix, k1_id, ally_id,
		PlanningChecklistHarness.SWAP_ALLY_CELL, PlanningChecklistHarness.KNIGHT_START, start_mp - 1, 1,
	)
	PlanningChecklistHarness.enter_basic_movement(fix)
	PlanningChecklistHarness.select_unit(fix, k1_id, PlanningChecklistHarness.SWAP_ALLY_CELL)
	var premove_route: Array[Vector2i] = [
		PlanningChecklistHarness.SWAP_ALLY_CELL,
		PlanningChecklistHarness.SWAP_PREMOVE_ROUTE[0],
		PlanningChecklistHarness.SWAP_PREMOVE_DEST,
	]
	if not PlanningChecklistHarness.commit_painted_drop_on_cell(
		fix, premove_route, PlanningChecklistHarness.SWAP_PREMOVE_DEST,
	):
		PlanningChecklistHarness.assert_fail(failures, "SWAP-04", "premove drag failed")
		return
	var pre_moves: Array[TimelineAction] = pre_moves_for_unit(director, k1_id)
	if pre_moves.size() < 2:
		PlanningChecklistHarness.assert_fail(
			failures, "SWAP-05", "expected swap+walk pre-moves got %d" % pre_moves.size(),
		)


static func run_swap_out_of_range_parity_mirror(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_swap_board(
		PlanningChecklistHarness.WALK_SWAP_ALLY_CELL,
	)
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
	if pre_moves.size() != 2:
		PlanningChecklistHarness.assert_fail(
			failures, "SWAP-09", "expected walk+swap pre-moves got %d" % pre_moves.size(),
		)
	elif pre_moves[0].type != GameEnums.ActionType.MOVE:
		PlanningChecklistHarness.assert_fail(failures, "SWAP-09", "first pre-move must be walk")
	elif pre_moves[1].type != GameEnums.ActionType.ABILITY:
		PlanningChecklistHarness.assert_fail(failures, "SWAP-09", "second pre-move must be swap")
	PlanningChecklistHarness.assert_swap_board_layers(
		failures, "SWAP-10", fix, k1_id, ally_id,
		PlanningChecklistHarness.WALK_SWAP_ALLY_CELL,
		PlanningChecklistHarness.WALK_SWAP_APPROACH,
		fix.start_k1_mp as int - 3,
		2,
	)


static func run_swap_walk_then_swap_mirror(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningChecklistHarness.wire_swap_board(
		PlanningChecklistHarness.WALK_SWAP_ALLY_CELL,
	)
	var director: CombatDirector = fix.director
	var k1_id: int = fix.k1_id as int
	var ally_id: int = fix.ally_id as int
	var start_mp: int = fix.start_k1_mp as int
	director.auto_run = true
	PlanningChecklistHarness.select_ability_for_unit(fix, k1_id, PlanningChecklistHarness.KNIGHT_SWAP_ID)
	PlanningChecklistHarness.enter_basic_movement(fix)
	if not PlanningChecklistHarness.commit_painted_drop_on_cell(
		fix,
		[
			PlanningChecklistHarness.KNIGHT_START,
			Vector2i(3, 5),
			PlanningChecklistHarness.WALK_SWAP_APPROACH,
		],
		PlanningChecklistHarness.WALK_SWAP_APPROACH,
	):
		PlanningChecklistHarness.assert_fail(failures, "SWAP-11", "walk drag failed")
		return
	PlanningChecklistHarness.select_ability_for_unit(fix, k1_id, PlanningChecklistHarness.KNIGHT_SWAP_ID)
	PlanningChecklistHarness.select_unit(fix, k1_id, PlanningChecklistHarness.WALK_SWAP_ALLY_CELL)
	if PlanningChecklistHarness.slots_invalid(
		PlanningChecklistHarness.commit_production(fix, PlanningChecklistHarness.WALK_SWAP_ALLY_CELL),
	):
		PlanningChecklistHarness.assert_fail(failures, "SWAP-12", "swap click failed")
		return
	var pre_moves: Array[TimelineAction] = pre_moves_for_unit(director, k1_id)
	if pre_moves.size() != 2:
		PlanningChecklistHarness.assert_fail(failures, "SWAP-13", "expected 2 pre-moves")
	PlanningChecklistHarness.assert_swap_board_layers(
		failures, "SWAP-14", fix, k1_id, ally_id,
		PlanningChecklistHarness.WALK_SWAP_ALLY_CELL,
		PlanningChecklistHarness.WALK_SWAP_APPROACH,
		start_mp - 3,
		2,
	)
