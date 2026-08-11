extends Node

## Scene-tree host for T3 mimic headless suite (PlanningQaGate-style .tscn entry).


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var runner: GDScript = load("res://tests/planning_t3_mimic_runner.gd") as GDScript
	PlanningDragE2EHarness.set_host(self)
	runner.run_all(failures)
	PlanningDragE2EHarness.cleanup_all()
	PlanningDragE2EHarness.set_host(null)
	if failures.is_empty():
		print("[PASS] Fixture Parity Suite (action_range + intent + journeys + bible)")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	get_tree().quit(0 if failures.is_empty() else 1)
