extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var planning_input_test: Script = load("res://tests/planning_input_test.gd")
	var planning_module_parity_test: Script = load("res://tests/planning_module_parity_test.gd")
	planning_input_test.run_all(failures)
	planning_module_parity_test.run_all(failures)
	if failures.is_empty():
		print("[PASS] PlanningInputTest")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	quit(0 if failures.is_empty() else 1)
