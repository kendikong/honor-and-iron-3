extends Node

const _RUNNER := preload("res://tests/cleric_qa_runner.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	print("[SUITE] cleric_qa_tier1")
	_RUNNER.run_all(failures)
	if failures.is_empty():
		print("[PASS] Cleric QA Tier 1 scenarios")
	else:
		for failure: String in failures:
			print("[FAIL] %s" % failure)
		print("[FAIL] Cleric QA Tier 1 scenarios (%d failures)" % failures.size())
	get_tree().quit(1 if not failures.is_empty() else 0)
