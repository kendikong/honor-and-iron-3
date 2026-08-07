extends SceneTree

## Bruiser QA Tier 1. SceneTree + deferred load so EventBus exists before planning scripts compile.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var failures: Array[String] = []
	var drag: GDScript = load("res://tests/planning_drag_e2e_harness.gd") as GDScript
	var runner: GDScript = load("res://tests/bruiser_qa_runner.gd") as GDScript
	drag.call("set_host", host)
	print("[SUITE] bruiser_qa_tier1")
	runner.call("run_all", failures)
	drag.call("cleanup_all")
	drag.call("set_host", null)
	if failures.is_empty():
		print("[PASS] Bruiser QA Tier 1 scenarios")
		quit(0)
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
		quit(1)
