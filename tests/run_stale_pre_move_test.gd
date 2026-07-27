extends SceneTree

## Focused verification: pre-move arrow hidden after commit when action is planned.

func _initialize() -> void:
	var failures: Array[String] = []
	var test_script: GDScript = load("res://tests/stale_pre_move_test.gd") as GDScript
	test_script.run_all(failures)
	if failures.is_empty():
		print("[PASS] stale pre-move preview tests")
	else:
		for f: String in failures:
			printerr("[FAIL] %s" % f)
	quit(0 if failures.is_empty() else 1)
