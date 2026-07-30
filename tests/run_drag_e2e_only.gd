extends SceneTree

## Fast runner for production drag-drop E2E only.

func _initialize() -> void:
	var failures: Array[String] = []
	var drag: GDScript = load("res://tests/planning_drag_e2e_test.gd") as GDScript
	drag.run_all(failures)
	for failure: String in failures:
		printerr("[FAIL] %s" % failure)
	if failures.is_empty():
		print("[PASS] drag E2E (%d tests)" % 10)
	quit(0 if failures.is_empty() else 1)
