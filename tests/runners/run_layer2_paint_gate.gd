extends Node

## Layer 2 locked red + next-phase red gate.


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	PlanningDragE2EHarness.set_host(self)
	PlanningQAGateTest._test_locked_red_stable_across_hovers(failures)
	PlanningQAGateTest._test_locked_red_visible_without_bundle(failures)
	PlanningQAGateTest._test_bundle_mismatch_does_not_clear_locked_red(failures)
	PlanningQAGateTest._test_action_range_centered_on_live_stand(failures)
	PlanningQAGateTest._test_action_range_hides_when_auto_run_blocks_skill_ap(failures)
	PlanningQAGateTest._test_action_range_hides_after_commit_run_icon(failures)
	PlanningQAGateTest._test_action_range_shows_while_awaiting_trample(failures)
	PlanningQAGateTest._test_action_range_shows_on_enemy_hover(failures)
	PlanningQAGateTest._test_action_range_follows_cursor_on_move_hover(failures)
	PlanningDragE2EHarness.cleanup_all()
	if failures.is_empty():
		print("--- Layer 2 paint gate: PASS ---")
		get_tree().quit(0)
	else:
		for line: String in failures:
			push_error("[FAIL] %s" % line)
		print("--- Layer 2 paint gate: FAIL (%d) ---" % failures.size())
		get_tree().quit(1)
