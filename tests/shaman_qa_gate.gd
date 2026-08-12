extends Node


const _RUNNER := preload("res://tests/shaman_qa_runner.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	print("[SUITE] shaman_qa_tier1")
	_RUNNER.run_all(failures)
	if failures.is_empty():
		print("[PASS] Shaman QA gate: factory matrix, per-row scenarios, and movement smoke")
	else:
		for failure: String in failures:
			print("[FAIL] %s" % failure)
		print("[FAIL] Shaman QA gate: %d failure(s)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
