extends SceneTree

## Planning input smoke tests. SceneTree + deferred load so EventBus exists before CombatDirector compiles.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test_script: GDScript = load("res://tests/planning_input_test.gd") as GDScript
	if test_script == null:
		printerr("[FAIL] PlanningInputTest script failed to load")
		quit(1)
		return
	var host := Node.new()
	root.add_child(host)
	var drag: GDScript = load("res://tests/planning_drag_e2e_harness.gd") as GDScript
	if drag != null:
		drag.call("set_host", host)
	var failures: Array[String] = []
	test_script.call("run_all", failures)
	if drag != null:
		drag.call("cleanup_all")
		drag.call("set_host", null)
	host.queue_free()
	if failures.is_empty():
		print("[PASS] PlanningInputTest")
		quit(0)
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
		quit(1)
