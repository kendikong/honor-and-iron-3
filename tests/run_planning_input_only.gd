extends SceneTree

const PlanningModuleParityTest = preload("res://tests/planning_module_parity_test.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	PlanningInputTest.run_all(failures)
	PlanningModuleParityTest.run_all(failures)
	if failures.is_empty():
		print("[PASS] PlanningInputTest")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	quit(0 if failures.is_empty() else 1)
