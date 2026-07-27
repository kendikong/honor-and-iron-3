extends Node

## Single headless entry point for deterministic bug-regression verification.
## Run:
##   "<godot.exe>" --headless --path . res://tests/regression_test.tscn

func _ready() -> void:
	## Load after autoloads enter the tree; production planning code references EventBus.
	var report := FileAccess.open("user://regression_test_result.txt", FileAccess.WRITE)
	report.store_line("STARTED")
	var bridge_runner: Script = load("res://tests/bridge_test_runner.gd")
	var sim_runner: Script = load("res://tests/sim_test_runner.gd")
	var bridge_result: Dictionary = bridge_runner.run_all()
	var sim_failures: int = sim_runner.new().run_all()
	var bridge_failures: Array = bridge_result.get("failures", [])
	if bridge_failures.is_empty() and sim_failures == 0:
		report.store_line("PASS")
		report.close()
		print("[PASS] Deterministic regression suite passed.")
		get_tree().quit(0)
	for failure: Variant in bridge_failures:
		report.store_line("[BRIDGE] %s" % str(failure))
		printerr("[BRIDGE] %s" % str(failure))
	if sim_failures > 0:
		report.store_line("[SIM] %d simulation regression test(s) failed." % sim_failures)
		printerr("[SIM] %d simulation regression test(s) failed." % sim_failures)
	report.close()
	get_tree().quit(1)
