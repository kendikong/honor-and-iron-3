extends SceneTree

const _KNIGHT_QA_RUNNER := preload("res://tests/knight_qa_runner.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	print("[SUITE] knight_qa_tier1")
	_KNIGHT_QA_RUNNER.run_all(failures)
	if failures.is_empty():
		print("[PASS] Knight QA Tier 1 scenarios")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	quit(0 if failures.is_empty() else 1)
