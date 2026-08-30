class_name MercenaryQaRunner
extends RefCounted


const _REGISTRY := preload("res://tests/mercenary_scenario_registry.gd")
const _HARNESS := preload("res://tests/mercenary_qa_harness.gd")
const _MOVEMENT_SMOKE := preload("res://tests/movement_planning_smoke_registry.gd")


static func run_all(failures: Array[String]) -> void:
	_HARNESS.run_factory_matrix(failures)
	for entry: Dictionary in _REGISTRY.all_entries():
		var factory_id: StringName = entry.get("factory_id", &"") as StringName
		var script_path := String(entry.get("script_path", ""))
		print("[MERCENARY_QA] %s" % factory_id)
		if not _REGISTRY.run_scenario(factory_id, script_path, failures):
			failures.append("registry/%s: failed to load or run scenario" % factory_id)
	_HARNESS.run_core_passive_triggers(failures)
	_MOVEMENT_SMOKE.run_all_for_class(failures, &"mercenary")
