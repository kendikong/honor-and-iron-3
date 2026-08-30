class_name EngineerQaRunner
extends RefCounted

const _REGISTRY := preload("res://tests/engineer_scenario_registry.gd")
const _HARNESS := preload("res://tests/engineer_qa_harness.gd")
const _PLANNING := preload("res://tests/class_scenario_planning_contract.gd")


static func run_all(failures: Array[String]) -> void:
	_HARNESS.run_factory_matrix(failures)
	for entry: Dictionary in _REGISTRY.all_entries():
		var factory_id: StringName = entry.factory_id
		print("[ENGINEER_QA] %s (%s)" % [entry.name, factory_id])
		if not _REGISTRY.run_scenario(String(entry.script_path), failures):
			failures.append("registry/%s: failed to load or run scenario" % entry.name)
		if _is_ability(factory_id):
			_PLANNING.run_for_factory(failures, factory_id)


static func _is_ability(factory_id: StringName) -> bool:
	return factory_id in _HARNESS.ABILITY_IDS
