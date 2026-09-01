extends Node

## Layer 3 yellow blast gate.


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	PlanningDragE2EHarness.set_host(self)
	PlanningQAGateTest._test_shaped_skill_red_range_yellow_blast(failures)
	PlanningQAGateTest._test_zero_range_self_aoe_red_yellow_contract(failures)
	PlanningQAGateTest._test_single_target_yellow_impact_tile(failures)
	PlanningQAGateTest._test_selected_tile_aoe_allows_premove(failures)
	PlanningQAGateTest._test_volley_awaiting_hover_damage_and_targeting_arrow(failures)
	PlanningQAGateTest._test_yellow_clears_after_skill_commit(failures)
	PlanningDragE2EHarness.cleanup_all()
	if failures.is_empty():
		print("--- Layer 3 paint gate: PASS ---")
		get_tree().quit(0)
	else:
		for line: String in failures:
			push_error("[FAIL] %s" % line)
		print("--- Layer 3 paint gate: FAIL (%d) ---" % failures.size())
		get_tree().quit(1)
