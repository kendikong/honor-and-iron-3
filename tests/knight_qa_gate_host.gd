extends Node

## Knight QA Tier 1 host for KnightQaGate.tscn (scene entry — not --script).
## Autoloads are ready before _ready; drag harness attaches UI stubs to this node.

const _KNIGHT_QA_RUNNER := preload("res://tests/knight_qa_runner.gd")
const _DRAG := preload("res://tests/planning_drag_e2e_harness.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_DRAG.set_host(self)
	print("[SUITE] knight_qa_tier1")
	_KNIGHT_QA_RUNNER.run_all(failures)
	_DRAG.cleanup_all()
	_DRAG.set_host(null)
	if failures.is_empty():
		print("[PASS] Knight QA Tier 1 scenarios")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	get_tree().quit(0 if failures.is_empty() else 1)
