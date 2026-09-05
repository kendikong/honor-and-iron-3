extends Node

## Headless planning fixture gate — full Knight checklist + drag/input/trample suites.
## CLI: godot --headless --path . res://tests/gates/PlanningQaGate.tscn
## PowerShell: .\scripts\run_planning_headless_contracts.ps1

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _run_gate()


func _run_gate() -> void:
	var failures: Array[String] = []
	PlanningDragE2EHarness.set_host(self)
	var suites: Array[Dictionary] = [
		{"name": "planning_forecast", "path": "res://tests/harness/planning_forecast_test.gd"},
		{"name": "drag_e2e", "path": "res://tests/harness/planning_drag_e2e_test.gd"},
		{"name": "planning_input", "path": "res://tests/harness/planning_input_test.gd"},
		{"name": "qa_checklist", "path": "res://tests/harness/planning_qa_gate_test.gd"},
	]
	for suite: Dictionary in suites:
		print("[SUITE] %s" % suite.name)
		var path: String = suite.path as String
		var script: GDScript = load(path) as GDScript
		if script == null:
			failures.append("suite_load_failed:%s" % path)
			continue
		var run_callable := Callable(script, "run_all")
		if not run_callable.is_valid():
			failures.append("suite_run_all_invalid:%s" % path)
			continue
		run_callable.call(failures)
		PlanningDragE2EHarness.cleanup_all()
		await get_tree().process_frame
	PlanningDragE2EHarness.set_host(null)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
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
		print("[PASS] Planning headless fixtures: forecast, skill scenarios, drag E2E, planning input, trample, action-range, checklist, intent contracts.")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	get_tree().quit(0 if failures.is_empty() else 1)
