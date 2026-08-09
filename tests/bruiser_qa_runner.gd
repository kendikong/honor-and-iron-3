extends SceneTree

## Bruiser QA Tier 1 headless CLI / Run Script entry.
## Run: godot --headless --path <repo> --script res://tests/bruiser_qa_runner.gd
## Scene gate (F5): res://tests/BruiserQaGate.tscn → bruiser_qa_gate_host.gd
## Scenario library: res://tests/bruiser_qa_runner_lib.gd


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
