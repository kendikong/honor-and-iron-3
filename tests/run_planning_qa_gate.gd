extends Node

## LEGACY Tier 1/2 — headless fixture contracts (DISABLED from QA gate).
##
## Not part of run_planning_qa_gate.ps1 unless -IncludeLegacyTier12. Use Tier 3:
##   .\scripts\run_planning_scene_acceptance.ps1
## Optional local archaeology:
##   "<godot.exe>" --headless --path . --script res://tests/run_planning_qa_gate.gd

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _run_gate()


func _run_gate() -> void:
	var failures: Array[String] = []
	PlanningDragE2EHarness.set_host(self)
	var suites: Array[Dictionary] = [
		{"name": "skill_scenarios", "path": "res://tests/planning_skill_scenarios_test.gd"},
		{"name": "drag_e2e", "path": "res://tests/planning_drag_e2e_test.gd"},
		{"name": "planning_input", "path": "res://tests/planning_input_test.gd"},
		{"name": "trample_e2e", "path": "res://tests/trampling_advance_e2e_test.gd"},
		{"name": "action_range_regression", "path": "res://tests/action_range_regression_test.gd"},
		{"name": "qa_checklist", "path": "res://tests/planning_qa_gate_test.gd"},
		{"name": "intent_contract_e2e", "path": "res://tests/planning_intent_contract_e2e_test.gd"},
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
		print("[PASS] Tier 1/2 planning contracts: skill scenarios, drag E2E, planning input, trample, action-range regression, checklist, and intent contracts.")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	get_tree().quit(0 if failures.is_empty() else 1)
