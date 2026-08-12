class_name BeastRiderQaRunner
extends RefCounted

const _REGISTRY := preload("res://tests/beast_rider_scenario_registry.gd")
const _HARNESS := preload("res://tests/beast_rider_qa_harness.gd")


static func run_all(failures: Array[String]) -> void:
	_HARNESS.run_factory_matrix(failures)
	for entry: Dictionary in _REGISTRY.all_entries():
		var factory_id: StringName = entry.factory_id
		print("[BEAST_RIDER_QA] %s (%s)" % [entry.name, factory_id])
		if not _REGISTRY.run_scenario(String(entry.script_path), failures):
			failures.append("registry/%s: failed to load or run scenario" % entry.name)
		if factory_id in _HARNESS.ABILITY_IDS:
			_HARNESS.run_ability_row(factory_id, failures)
			_HARNESS.run_planning_row(factory_id, failures)
		else:
			_HARNESS.run_passive_row(factory_id, failures)
