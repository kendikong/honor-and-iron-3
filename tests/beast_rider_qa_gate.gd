extends Node

const _RUNNER := preload("res://tests/beast_rider_qa_runner.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	print("[SUITE] beast_rider_qa_tier1")
	_RUNNER.run_all(failures)
	if failures.is_empty():
		print("[PASS] Beast Rider QA gate: factory matrix, 17 active rows, 16 passive rows")
	else:
		for failure: String in failures:
			print("[FAIL] %s" % failure)
		print("[FAIL] Beast Rider QA gate: %d failure(s)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
