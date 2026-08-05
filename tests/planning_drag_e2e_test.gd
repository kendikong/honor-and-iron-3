class_name PlanningDragE2ETest
extends RefCounted

## Production drag-drop E2E — exercises on_left_release, stash lifecycle, board_changed, undo.


static func run_all(failures: Array[String]) -> void:
	var tests: Array[Callable] = [
		_test_release_walk_commit_undo,
		_test_release_matches_click_plan,
		_test_right_click_undo_after_release,
		_test_board_changed_clears_stale_stash_not_plan,
		_test_board_changed_during_active_drag_restores_preview,
		_test_oob_release_cancels_without_plan,
		_test_second_walk_after_undo,
		_test_release_bash_enemy_writes_plan,
		_test_stash_null_after_successful_release,
		_test_release_then_timeline_undo_via_director,
	]
	var names: PackedStringArray = [
		"release_walk_undo",
		"release_click_parity",
		"right_click_undo",
		"board_changed_stale_stash",
		"board_changed_active_drag",
		"oob_cancel",
		"second_walk_after_undo",
		"release_bash_enemy",
		"stash_cleared_on_release",
		"director_undo_after_release",
	]
	for i: int in range(tests.size()):
		print("[RUN drag-e2e] %s" % names[i])
		tests[i].call(failures)
		PlanningDragE2EHarness.cleanup_all()


static func _test_release_walk_commit_undo(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningDragE2EHarness.wire_walk_fixture()
	PlanningDragE2EHarness.prepare_basic_walk(fix)
	var dest := Vector2i(5, 5)
	var route: Array[Vector2i] = [PlanningDragE2EHarness.KNIGHT_START, dest]
	PlanningDragE2EHarness.paint_and_release(fix, route, dest)
	if fix.input._drag_saved_preview != null:
		failures.append("DragE2E release_walk_undo: stash must be null after successful release")
	if fix.director.plan_pre_move.size() == 0:
		failures.append("DragE2E release_walk_undo: release must write pre-move plan")
		return
	if not fix.director.unit_has_undoable_action(1):
		failures.append("DragE2E release_walk_undo: walk must be undoable after release")
		return
	var before: int = fix.director.plan_pre_move.size()
	PlanningDragE2EHarness.undo_selected(fix)
	if fix.director.plan_pre_move.size() >= before:
		failures.append("DragE2E release_walk_undo: right-click undo must clear drag-committed move")
	if fix.input._drag_saved_preview != null:
		failures.append("DragE2E release_walk_undo: undo must not resurrect drag stash")


static func _test_release_matches_click_plan(failures: Array[String]) -> void:
	var dest := Vector2i(5, 5)
	var click_fix: Dictionary = PlanningDragE2EHarness.wire_minimal_fixture()
	PlanningDragE2EHarness.prepare_basic_walk(click_fix)
	var click_slots: Dictionary = click_fix.input._final_commit_slots_for_click_at_cell(
		1, dest, Vector2.ZERO,
	)
	if PlanningDragE2EHarness._slots_invalid(click_slots):
		failures.append(
			"DragE2E release_click_parity: click slots invalid %s"
			% str(click_slots.get("invalid", "")),
		)
		return
	var drop_fix: Dictionary = PlanningDragE2EHarness.wire_walk_fixture()
	PlanningDragE2EHarness.prepare_basic_walk(drop_fix)
	var route: Array[Vector2i] = [PlanningDragE2EHarness.KNIGHT_START, dest]
	PlanningDragE2EHarness.begin_drag_route(drop_fix, route)
	var legal_moves: Array[Vector2i] = drop_fix.input._snapshot_drag_legal_move_tiles()
	var drop_slots: Dictionary = drop_fix.input._final_commit_slots_for_drop_at_cell(
		1, dest, Vector2.ZERO, legal_moves,
	)
	if PlanningDragE2EHarness._slots_invalid(drop_slots):
		failures.append(
			"DragE2E release_click_parity: painted drop slots invalid %s"
			% str(drop_slots.get("invalid", "")),
		)
		return
	if _slot_signature(click_slots) != _slot_signature(drop_slots):
		failures.append(
			"DragE2E release_click_parity: click vs painted-drop slots differ",
		)
		return
	if not click_fix.director.commit_from_slots(1, click_slots):
		failures.append("DragE2E release_click_parity: click commit_from_slots failed")
		return
	click_fix.director.flush_plan_refresh_signals_if_pending()
	var click_sig: String = _plan_signature(click_fix.director)
	click_fix.director.rpc_remove_last_for_unit(1)
	click_fix.director.flush_plan_refresh_signals_if_pending()
	PlanningDragE2EHarness.release_at(drop_fix, dest)
	var drop_sig: String = _plan_signature(drop_fix.director)
	if click_sig != drop_sig:
		failures.append(
			"DragE2E release_click_parity: release plan %s differs from click %s"
			% [drop_sig, click_sig],
		)


static func _test_right_click_undo_after_release(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningDragE2EHarness.wire_walk_fixture()
	PlanningDragE2EHarness.prepare_basic_walk(fix)
	var dest := Vector2i(5, 4)
	PlanningDragE2EHarness.paint_and_release(
		fix, [PlanningDragE2EHarness.KNIGHT_START, dest], dest,
	)
	if not fix.director.unit_has_undoable_action(1):
		failures.append("DragE2E right_click_undo: expected undoable action before undo")
		return
	PlanningDragE2EHarness.undo_selected(fix)
	if fix.director.unit_has_undoable_action(1):
		failures.append("DragE2E right_click_undo: undo must remove undoable action")
	if fix.director.plan_pre_move.size() > 0:
		failures.append("DragE2E right_click_undo: pre-move timeline must be empty after undo")


static func _test_board_changed_clears_stale_stash_not_plan(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningDragE2EHarness.wire_walk_fixture()
	PlanningDragE2EHarness.prepare_basic_walk(fix)
	var dest := Vector2i(5, 5)
	PlanningDragE2EHarness.paint_and_release(
		fix, [PlanningDragE2EHarness.KNIGHT_START, dest], dest,
	)
	if fix.director.plan_pre_move.size() == 0:
		failures.append("DragE2E board_changed_stale_stash: need committed plan")
		return
	# Simulate bug: stale stash left behind after drag ended.
	fix.input._drag_saved_preview = fix.director.board.clone()
	var plan_before: String = _plan_signature(fix.director)
	PlanningDragE2EHarness.emit_board_changed(fix)
	fix.director.flush_plan_refresh_signals_if_pending()
	if fix.input._drag_saved_preview != null:
		failures.append(
			"DragE2E board_changed_stale_stash: idle board_changed must clear stale stash",
		)
	if _plan_signature(fix.director) != plan_before:
		failures.append(
			"DragE2E board_changed_stale_stash: stale stash must not wipe committed plan",
		)


static func _test_board_changed_during_active_drag_restores_preview(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningDragE2EHarness.wire_walk_fixture()
	PlanningDragE2EHarness.prepare_basic_walk(fix)
	var dest := Vector2i(5, 5)
	PlanningDragE2EHarness.begin_drag_route(
		fix, [PlanningDragE2EHarness.KNIGHT_START, dest],
	)
	if not fix.input.dragging:
		failures.append("DragE2E board_changed_active_drag: drag must be active")
		return
	if fix.input._drag_saved_preview == null:
		failures.append("DragE2E board_changed_active_drag: begin_drag must stash preview")
		return
	PlanningDragE2EHarness.emit_board_changed(fix)
	fix.director.flush_plan_refresh_signals_if_pending()
	if fix.input.dragging:
		failures.append("DragE2E board_changed_active_drag: board_changed must end drag")
	if fix.input._drag_saved_preview != null:
		failures.append(
			"DragE2E board_changed_active_drag: restored preview must clear stash after restore",
		)


static func _test_oob_release_cancels_without_plan(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningDragE2EHarness.wire_walk_fixture()
	PlanningDragE2EHarness.prepare_basic_walk(fix)
	var dest := Vector2i(5, 5)
	PlanningDragE2EHarness.begin_drag_route(
		fix, [PlanningDragE2EHarness.KNIGHT_START, dest],
	)
	var oob := Vector2i(-1, -1)
	fix.input.set_qa_pointer_grid_cell(oob)
	fix.input.on_left_release(Vector2.ZERO)
	fix.director.flush_plan_refresh_signals_if_pending()
	if fix.director.plan_pre_move.size() > 0:
		failures.append("DragE2E oob_cancel: OOB release must not commit a move")
	if fix.input.dragging:
		failures.append("DragE2E oob_cancel: drag must end after OOB release")


static func _test_second_walk_after_undo(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningDragE2EHarness.wire_walk_fixture()
	PlanningDragE2EHarness.prepare_basic_walk(fix)
	var first := Vector2i(5, 5)
	var second := Vector2i(4, 6)
	PlanningDragE2EHarness.paint_and_release(
		fix, [PlanningDragE2EHarness.KNIGHT_START, first], first,
	)
	PlanningDragE2EHarness.undo_selected(fix)
	PlanningDragE2EHarness.paint_and_release(
		fix, [PlanningDragE2EHarness.KNIGHT_START, second], second,
	)
	if fix.director.plan_pre_move.size() == 0:
		failures.append("DragE2E second_walk_after_undo: second drag release must commit")
		return
	var move: TimelineAction = fix.director.plan_pre_move.entries[0]
	if move.target_coord != second:
		failures.append(
			"DragE2E second_walk_after_undo: expected dest %s got %s"
			% [second, move.target_coord],
		)


static func _test_release_bash_enemy_writes_plan(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningDragE2EHarness.wire_bash_fixture()
	fix.input.auto_use_skill_after_move = true
	var bash_idx: int = _bash_index(fix.knight)
	if bash_idx < 0:
		failures.append("DragE2E release_bash_enemy: knight missing Shield Bash")
		return
	fix.director.selected_ability_index = bash_idx
	var route: Array[Vector2i] = [
		PlanningDragE2EHarness.KNIGHT_START,
		PlanningDragE2EHarness.BASH_APPROACH,
	]
	PlanningDragE2EHarness.paint_and_release(fix, route, PlanningDragE2EHarness.ENEMY_POS)
	if fix.director.plan_pre_move.size() == 0:
		failures.append("DragE2E release_bash_enemy: bash release must write pre-move")
		return
	if fix.director.plan_action.size() == 0:
		failures.append("DragE2E release_bash_enemy: bash release must write action plan")


static func _test_stash_null_after_successful_release(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningDragE2EHarness.wire_walk_fixture()
	PlanningDragE2EHarness.prepare_basic_walk(fix)
	var dest := Vector2i(5, 5)
	PlanningDragE2EHarness.begin_drag_route(
		fix, [PlanningDragE2EHarness.KNIGHT_START, dest],
	)
	if fix.input._drag_saved_preview == null:
		failures.append("DragE2E stash_cleared_on_release: begin_drag must stash preview")
	PlanningDragE2EHarness.release_at(fix, dest)
	if fix.input._drag_saved_preview != null:
		failures.append("DragE2E stash_cleared_on_release: successful release must null stash")
	if fix.input.dragging:
		failures.append("DragE2E stash_cleared_on_release: dragging must be false after release")


static func _test_release_then_timeline_undo_via_director(failures: Array[String]) -> void:
	var fix: Dictionary = PlanningDragE2EHarness.wire_walk_fixture()
	PlanningDragE2EHarness.prepare_basic_walk(fix)
	var dest := Vector2i(5, 5)
	PlanningDragE2EHarness.paint_and_release(
		fix, [PlanningDragE2EHarness.KNIGHT_START, dest], dest,
	)
	if not fix.director.unit_has_undoable_action(1):
		failures.append("DragE2E director_undo_after_release: move must be undoable")
		return
	fix.director.rpc_remove_last_for_unit(1)
	fix.director.flush_plan_refresh_signals_if_pending()
	PlanningDragE2EHarness.emit_board_changed(fix)
	fix.director.flush_plan_refresh_signals_if_pending()
	if fix.director.plan_pre_move.size() > 0:
		failures.append("DragE2E director_undo_after_release: undo must clear plan after board_changed")
	if fix.input._drag_saved_preview != null:
		failures.append("DragE2E director_undo_after_release: undo must not leave drag stash")


static func _bash_index(knight: UnitState) -> int:
	for i: int in range(knight.active_abilities.size()):
		var ability: AbilityData = knight.active_abilities[i]
		if ability != null and ability.id == &"knight_shield_bash":
			return i
	return -1


static func _slot_signature(slots: Dictionary) -> String:
	var parts: PackedStringArray = []
	for col: String in ["pre", "action", "post"]:
		for raw: Variant in slots.get(col, []):
			if raw is TimelineAction:
				var action: TimelineAction = raw as TimelineAction
				parts.append(
					"%s:%s:%s" % [str(action.type), str(action.target_coord), str(action.waypoints)],
				)
	return "|".join(parts)


static func _plan_signature(director: CombatDirector) -> String:
	var parts: PackedStringArray = []
	for timeline: Timeline in [director.plan_pre_move, director.plan_action, director.plan_post_move]:
		for entry: TimelineAction in timeline.entries:
			parts.append(
				"%s:%s:%s" % [str(entry.primary_type), str(entry.target_coord), str(entry.waypoints)],
			)
	return "|".join(parts)
