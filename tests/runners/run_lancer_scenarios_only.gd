extends Node

const _RUNNER := preload("res://tests/lancer_qa_runner.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	print("[SUITE] lancer_qa_tier1")
	_RUNNER.run_all(failures)
	if failures.is_empty():
		print("[PASS] Lancer QA Tier 1 scenarios")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	get_tree().quit(0 if failures.is_empty() else 1)

