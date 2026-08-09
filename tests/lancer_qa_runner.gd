class_name LancerQaRunner
extends RefCounted

const _REGISTRY := preload("res://tests/lancer_scenario_registry.gd")
const _MOVEMENT_SMOKE := preload("res://tests/movement_planning_smoke_registry.gd")

static func run_all(failures: Array[String]) -> void:
	var ran_paths: Dictionary = {}
	for entry: Dictionary in _REGISTRY.all_entries():
		var name := String(entry.get("name", "?"))
		var factory_id: StringName = entry.get("factory_id", &"") as StringName
		var script_path := String(entry.get("script_path", ""))
		print("[LANCER_QA] %s (%s)" % [name, factory_id])
		if ran_paths.has(script_path):
			continue
		ran_paths[script_path] = true
		if not _REGISTRY.run_scenario(script_path, failures):
			failures.append("registry/%s: failed to load or run scenario" % name)
	_MOVEMENT_SMOKE.run_all_for_class(failures, &"lancer")

