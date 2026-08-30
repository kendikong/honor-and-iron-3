class_name RogueQaRunner
extends RefCounted

const _REGISTRY := preload("res://tests/rogue_scenario_registry.gd")
const _HARNESS := preload("res://tests/rogue_qa_harness.gd")
const _MOVEMENT_SMOKE := preload("res://tests/movement_planning_smoke_registry.gd")
const _PLANNING := preload("res://tests/class_scenario_planning_contract.gd")


static func run_all(failures: Array[String]) -> void:
	_HARNESS.run_factory_matrix(failures)
	for entry: Dictionary in _REGISTRY.all_entries():
		var factory_id: StringName = entry.factory_id
		var script_path: String = String(entry.script_path)
		print("[ROGUE_QA] %s (%s)" % [entry.name, factory_id])
		if not _REGISTRY.run_scenario(script_path, failures):
			failures.append("registry/%s: failed to load or run scenario" % entry.name)
		if _is_ability(factory_id):
			_PLANNING.run_for_factory(failures, factory_id)
	_MOVEMENT_SMOKE.run_all_for_class(failures, &"rogue")
	_HARNESS.run_core_passive_triggers(failures)


static func _is_ability(factory_id: StringName) -> bool:
	return factory_id in _HARNESS.ABILITY_IDS
