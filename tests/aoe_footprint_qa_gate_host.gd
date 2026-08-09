extends Node

## AOE footprint gate host for AoeFootprintQaGate.tscn (F5 / scene runner — not --script).

const _SUITE := preload("res://tests/aoe_footprint_contract_suite.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_SUITE.run(failures)
	if failures.is_empty():
		print("[PASS] AOE footprint contract")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	get_tree().quit(0 if failures.is_empty() else 1)
