extends Node

## Gate: AOE footprint contract — geometry, scenario audit, live overlay audit, premove guard.

const _HARNESS := preload("res://tests/aoe_footprint_qa_harness.gd")
const _MOVEMENT := preload("res://tests/movement_timeline_qa_harness.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	print("[SUITE] aoe_footprint_contract")
	_HARNESS.run_geometry_contracts(failures)
	_HARNESS.audit_scenario_registries(failures)
	_HARNESS.audit_live_class_tests(failures)
	_HARNESS.audit_premove_arc_regression(failures)
	_MOVEMENT.audit_scenario_registries(failures)
	_MOVEMENT.audit_live_class_tests(failures)
	if failures.is_empty():
		print("[PASS] AOE footprint contract")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	get_tree().quit(0 if failures.is_empty() else 1)
