extends SceneTree

## Headless entry point for the multi-knight integration test.
## Run: godot --headless --path . --script res://tests/run_multi_knight_integration.gd

const _Test := preload("res://tests/multi_knight_integration_test.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	_Test.run_all(failures)
	
	if failures.is_empty():
		print("[PASS] MultiKnightIntegration: all checks passed")
		quit(0)
	else:
		for f: String in failures:
			printerr("[FAIL] %s" % f)
		printerr("[SUMMARY] MultiKnightIntegration: %d failures" % failures.size())
		quit(1)
