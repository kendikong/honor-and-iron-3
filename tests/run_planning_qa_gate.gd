extends SceneTree

## Fast Planning QA Gate runner — mirrors the owner's manual Skill Arena checklist.
## Run:
##   "<godot.exe>" --headless --path . --script res://tests/run_planning_qa_gate.gd

func _initialize() -> void:
	var failures: Array[String] = []
	var gate: GDScript = load("res://tests/planning_qa_gate_test.gd") as GDScript
	gate.run_all(failures)
	if failures.is_empty():
		print("[PASS] Planning QA gate — all checklist items covered by headless tests.")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	quit(0 if failures.is_empty() else 1)
