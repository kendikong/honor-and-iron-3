extends SceneTree

func _init() -> void:
	var failures: Array[String] = []
	ModuleAuthoringRulesTest.run_all(failures)
	if failures.is_empty():
		print("PASS module_authoring_rules_test")
		quit(0)
	for line: String in failures:
		push_error(line)
	quit(1)
