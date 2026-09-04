extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var suite: GDScript = load("res://tests/harness/action_range_regression_test.gd") as GDScript
	suite.run_all(failures)
	if failures.is_empty():
		print("[PASS] ActionRangeRegression tests passed.")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	quit(0 if failures.is_empty() else 1)
