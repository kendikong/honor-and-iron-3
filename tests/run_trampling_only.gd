extends SceneTree

const TRAMPLING_E2E := preload("res://tests/trampling_advance_e2e_test.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	TRAMPLING_E2E.run_all(failures)
	if failures.is_empty():
		print("[PASS] Trampling Advance E2E tests passed.")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	quit(0 if failures.is_empty() else 1)
