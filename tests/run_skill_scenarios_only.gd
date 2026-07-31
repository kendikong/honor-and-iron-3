extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	print("[SUITE] skill_scenarios_only")
	PlanningSkillScenariosTest.run_all(failures)
	if failures.is_empty():
		print("[PASS] Skill scenario checklist")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	quit(0 if failures.is_empty() else 1)
