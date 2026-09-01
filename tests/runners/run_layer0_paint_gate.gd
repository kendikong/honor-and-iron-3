extends Node

## Layer 0 paint split gate host (locked vs bundle).


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	PlanningDragE2EHarness.set_host(self)
	PlanningQAGateTest._test_locked_blue_stable_across_hovers(failures)
	PlanningQAGateTest._test_locked_blue_visible_without_bundle(failures)
	PlanningQAGateTest._test_bundle_mismatch_does_not_clear_locked_blue(failures)
	PlanningQAGateTest._test_locked_red_stable_across_hovers(failures)
	PlanningQAGateTest._test_locked_red_visible_without_bundle(failures)
	PlanningQAGateTest._test_bundle_mismatch_does_not_clear_locked_red(failures)
	PlanningQAGateTest._test_blue_move_tiles_on_walk_select(failures)
	PlanningDragE2EHarness.cleanup_all()
	if failures.is_empty():
		print("--- Layer 0 paint gate: PASS ---")
		get_tree().quit(0)
	else:
		for line: String in failures:
			push_error("[FAIL] %s" % line)
		print("--- Layer 0 paint gate: FAIL (%d) ---" % failures.size())
		get_tree().quit(1)
