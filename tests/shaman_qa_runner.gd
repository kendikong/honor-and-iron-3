class_name ShamanQaRunner
extends RefCounted


const _HARNESS := preload("res://tests/shaman_qa_harness.gd")
const _REGISTRY := preload("res://tests/shaman_scenario_registry.gd")
const _MOVEMENT_SMOKE := preload("res://tests/movement_planning_smoke_registry.gd")


static func run_all(failures: Array[String]) -> void:
	_HARNESS.run_factory_matrix(failures)
	for entry: Dictionary in _REGISTRY.all_entries():
		var name := String(entry.get("name", "?"))
		var script_path := String(entry.get("script_path", ""))
		print("[SHAMAN_QA] %s" % name)
		if not _REGISTRY.run_scenario(script_path, failures):
			failures.append("registry/%s: failed to load or run scenario" % name)
	_MOVEMENT_SMOKE.run_all_for_class(failures, &"shaman")


static func run_live_skill_resolution(failures: Array[String]) -> void:
	for ability_id: StringName in _HARNESS.ABILITY_IDS:
		_HARNESS.run_single_ability(ability_id, failures)
