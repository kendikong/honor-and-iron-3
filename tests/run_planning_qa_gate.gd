extends SceneTree

## Planning QA Gate — production drag E2E + planning input + trample + checklist mirror.
## Run:
##   "<godot.exe>" --headless --path . --script res://tests/run_planning_qa_gate.gd

func _initialize() -> void:
	var failures: Array[String] = []
	var suites: Array[Dictionary] = [
		{"name": "drag_e2e", "path": "res://tests/planning_drag_e2e_test.gd"},
		{"name": "planning_input", "path": "res://tests/planning_input_test.gd"},
		{"name": "trample_e2e", "path": "res://tests/trampling_advance_e2e_test.gd"},
		{"name": "qa_checklist", "path": "res://tests/planning_qa_gate_test.gd"},
	]
	for suite: Dictionary in suites:
		print("[SUITE] %s" % suite.name)
		var runner: GDScript = load(suite.path as String) as GDScript
		runner.run_all(failures)
	var report_path := "user://planning_qa_gate_result.txt"
	var report := FileAccess.open(report_path, FileAccess.WRITE)
	if report != null:
		if failures.is_empty():
			report.store_line("PASS")
		else:
			for failure: String in failures:
				report.store_line("[FAIL] %s" % failure)
		report.close()
	if failures.is_empty():
		print("[PASS] Planning QA gate — drag E2E, planning input, trample, and checklist.")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	quit(0 if failures.is_empty() else 1)
