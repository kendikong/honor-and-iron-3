extends Node

## Layer 4 path / route gate.


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	PlanningDragE2EHarness.set_host(self)
	PlanningQAGateTest._test_waypoint_paint_order_preserved_on_tile_drag(failures)
	PlanningQAGateTest._test_trample_paint_preview_matches_route(failures)
	PlanningQAGateTest._test_trample_commit_preserves_east_then_north(failures)
	PlanningQAGateTest._test_trample_sim_follows_painted_order(failures)
	PlanningQAGateTest._test_trample_repath_does_not_replace_painted_order(failures)
	PlanningQAGateTest._test_painted_route_premove_vs_move_equivalence(failures)
	PlanningQAGateTest._test_teleport_full_preview_truth_click(failures)
	PlanningQAGateTest._test_drag_drop_commit_undo_clears_plan(failures)
	PlanningQAGateTest._test_waypoint_premove_enemy_hover_full_truth(failures)
	PlanningQAGateTest._test_painted_route_then_enemy_hover_click_preserves_intent(failures)
	PlanningQAGateTest._test_movement_module_hover_uses_route_not_target_arrow(failures)
	PlanningQAGateTest._test_tile_targeting_forbids_premove(failures)
	PlanningDragE2EHarness.cleanup_all()
	if failures.is_empty():
		print("--- Layer 4 paint gate: PASS ---")
		get_tree().quit(0)
	else:
		for line: String in failures:
			push_error("[FAIL] %s" % line)
		print("--- Layer 4 paint gate: FAIL (%d) ---" % failures.size())
		get_tree().quit(1)
