extends SceneTree

## Single headless entry point for deterministic bug-regression verification.
## Run:
##   "<godot.exe>" --headless --path . --script res://tests/regression_test.gd

func _initialize() -> void:
	## Autoloads are initialized before this entry point dynamically loads planning code.
	print("[START] Deterministic regression suite")
	var report := FileAccess.open("user://regression_test_result.txt", FileAccess.WRITE)
	report.store_line("STARTED")
	report.close()
	report = FileAccess.open("user://regression_test_result.txt", FileAccess.READ_WRITE)
	report.seek_end()
	report.store_line("BRIDGE_START")
	report.close()
	var bridge_runner: Script = load("res://tests/bridge_test_runner.gd")
	var bridge_result: Dictionary = bridge_runner.run_all()
	report = FileAccess.open("user://regression_test_result.txt", FileAccess.READ_WRITE)
	report.seek_end()
	report.store_line("BRIDGE_FINISHED")
	report.close()
	var sim_runner: Script = load("res://tests/sim_test_runner.gd")
	var sim_failures: int = sim_runner.new().run_all()
	var bridge_failures: Array = bridge_result.get("failures", [])
	if bridge_failures.is_empty() and sim_failures == 0:
		report = FileAccess.open("user://regression_test_result.txt", FileAccess.READ_WRITE)
		report.seek_end()
		report.store_line("PASS")
		report.close()
		print("[PASS] Deterministic regression suite passed.")
		quit(0)
	for failure: Variant in bridge_failures:
		report = FileAccess.open("user://regression_test_result.txt", FileAccess.READ_WRITE)
		report.seek_end()
		report.store_line("[BRIDGE] %s" % str(failure))
		report.close()
		printerr("[BRIDGE] %s" % str(failure))
	if sim_failures > 0:
		report = FileAccess.open("user://regression_test_result.txt", FileAccess.READ_WRITE)
		report.seek_end()
		report.store_line("[SIM] %d simulation regression test(s) failed." % sim_failures)
		report.close()
		printerr("[SIM] %d simulation regression test(s) failed." % sim_failures)
	quit(1)
