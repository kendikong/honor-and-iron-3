class_name ArcherQaRunner
extends RefCounted

const _REGISTRY := preload("res://tests/archer_scenario_registry.gd")
const _HARNESS := preload("res://tests/archer_qa_harness.gd")
const _UPGRADES := preload("res://tests/archer_qa_harness_upgrades.gd")
const _PLANNING := preload("res://tests/movement_planning_smoke_registry.gd")
const _DRAG := preload("res://tests/planning_drag_e2e_harness.gd")


static func run_all(failures: Array[String]) -> void:
	_HARNESS.run_data_contract(failures)
	_HARNESS.run_shape_contract_smoke(failures)
	for entry: Dictionary in _REGISTRY.all_entries():
		var name: String = String(entry.get("name", "?"))
		var factory_id: StringName = entry.get("factory_id", &"") as StringName
		var script_path: String = String(entry.get("script_path", ""))
		print("[ARCHER_QA] %s (%s)" % [name, factory_id])
		if not _REGISTRY.run_scenario(script_path, failures):
			failures.append("registry/%s: failed to load or run scenario" % name)
			continue
		_UPGRADES.run_upgrade_for(name, failures)
		_PLANNING.run_for_factory_id(failures, factory_id)
		_DRAG.cleanup_all()
