extends SceneTree

## Headless entry for TestBattle / debug-report bridge tests only.
## Do NOT use --script res://tests/bridge_test_runner.gd (RefCounted, not SceneTree).
## Run:
##   "<godot.exe>" --headless --path . --script res://tests/run_test_battle_bridge.gd


func _initialize() -> void:
	var result: Dictionary = TestBattleTestRunner.run_all()
	if result.passed:
		print("[PASS] TestBattle bridge tests passed.")
		quit(0)
	for failure: String in result.get("failures", []):
		printerr("  [X] %s" % failure)
	printerr("[FAIL] %d TestBattle bridge test(s) failed." % result.failures.size())
	quit(1)
