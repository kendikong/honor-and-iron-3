extends SceneTree

## Headless entry point for bridge-layer checks.
## Run from the project root with:
##   "<godot.exe>" --headless --path . --script res://tests/bridge_test.gd

func _initialize() -> void:
	var result: Dictionary = BridgeTestRunner.run_all()
	if result.passed:
		print("[PASS] All bridge tests passed.")
		quit(0)
	for failure: String in result.failures:
		printerr("  [X] %s" % failure)
	printerr("[FAIL] %d bridge test(s) failed." % result.failures.size())
	quit(1)
