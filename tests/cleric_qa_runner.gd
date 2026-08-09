class_name ClericQaRunner
extends RefCounted

const _HARNESS := preload("res://tests/cleric_qa_harness.gd")
const _MOVEMENT_SMOKE := preload("res://tests/movement_planning_smoke_registry.gd")


static func run_all(failures: Array[String]) -> void:
	_HARNESS.run_all(failures)
	_MOVEMENT_SMOKE.run_all_for_class(failures, &"cleric")
