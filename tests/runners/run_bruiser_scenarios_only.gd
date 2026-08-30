extends SceneTree

## Alias CLI entry for Bruiser Tier 1 (same as bruiser_qa_runner.gd).
## Prefer: --script res://tests/bruiser_qa_runner.gd or F5 BruiserQaGate.tscn


func _initialize() -> void:
	var failures: Array[String] = []
	var drag: GDScript = load("res://tests/planning_drag_e2e_harness.gd") as GDScript
	var runner: GDScript = load("res://tests/bruiser_qa_runner_lib.gd") as GDScript
	var host := Node.new()
	host.name = "BruiserQaGateHost"
	root.add_child(host)
	drag.set_host(host)
	print("[SUITE] bruiser_qa_tier1")
	runner.run_all(failures)
	drag.cleanup_all()
	drag.set_host(null)
	host.queue_free()
	if failures.is_empty():
		print("[PASS] Bruiser QA Tier 1 scenarios")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	quit(0 if failures.is_empty() else 1)
