extends SceneTree

## Knight QA Tier 1 headless CLI runner.
## Run: godot --headless --path <repo> --script res://tests/run_skill_scenarios_only.gd
## Scene gate (F5 / .tscn): use res://tests/KnightQaGate.tscn → knight_qa_gate_host.gd
## Uses load() so EventBus autoloads exist before planning E2E scripts compile.


func _initialize() -> void:
	var failures: Array[String] = []
	var drag: GDScript = load("res://tests/planning_drag_e2e_harness.gd") as GDScript
	var runner: GDScript = load("res://tests/knight_qa_runner.gd") as GDScript
	var host := Node.new()
	host.name = "KnightQaGateHost"
	root.add_child(host)
	drag.set_host(host)
	print("[SUITE] knight_qa_tier1")
	runner.run_all(failures)
	drag.cleanup_all()
	drag.set_host(null)
	host.queue_free()
	if failures.is_empty():
		print("[PASS] Knight QA Tier 1 scenarios")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	quit(0 if failures.is_empty() else 1)
