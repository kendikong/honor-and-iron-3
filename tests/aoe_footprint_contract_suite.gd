extends RefCounted

## Shared AOE + movement-timeline contract checks (not a Godot main script).

const _HARNESS := preload("res://tests/aoe_footprint_qa_harness.gd")
const _MOVEMENT := preload("res://tests/movement_timeline_qa_harness.gd")


static func run(failures: Array[String]) -> void:
	print("[SUITE] aoe_footprint_contract")
	_HARNESS.run_geometry_contracts(failures)
	_HARNESS.audit_scenario_registries(failures)
	_HARNESS.audit_live_class_tests(failures)
	_HARNESS.audit_premove_arc_regression(failures)
	_MOVEMENT.audit_scenario_registries(failures)
	_MOVEMENT.audit_live_class_tests(failures)
