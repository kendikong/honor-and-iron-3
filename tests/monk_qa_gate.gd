extends Node

const _RUNNER := preload("res://tests/monk_qa_runner.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	print("[SUITE] monk_qa_tier1")
	_RUNNER.run_all(failures)
	if failures.is_empty():
		print("[PASS] Monk QA gate: factory matrix, all active skills, and passive triggers")
	else:
		for failure: String in failures:
			print("[FAIL] %s" % failure)
		print("[FAIL] Monk QA gate: %d failure(s)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
