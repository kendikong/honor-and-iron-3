extends Node

const _RUNNER := preload("res://tests/archer_qa_runner.gd")

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	print("[SUITE] archer_qa_tier1")
	_RUNNER.run_all(failures)
	if failures.is_empty():
		print("[PASS] Archer QA Tier 1 scenarios")
	else:
		for failure: String in failures:
			print("[FAIL] %s" % failure)
		print("[FAIL] Archer QA Tier 1 scenarios (%d failures)" % failures.size())
	get_tree().quit(1 if not failures.is_empty() else 0)
