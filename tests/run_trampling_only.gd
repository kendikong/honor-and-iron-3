extends SceneTree

## Fast Trampling Advance E2E runner. Uses load() so autoloads (EventBus) are ready first.

func _initialize() -> void:
	var failures: Array[String] = []
	var trampling_e2e: GDScript = load("res://tests/trampling_advance_e2e_test.gd") as GDScript
	trampling_e2e.run_all(failures)
	if failures.is_empty():
		print("[PASS] Trampling Advance E2E tests passed.")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	quit(0 if failures.is_empty() else 1)
