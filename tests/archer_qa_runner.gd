class_name ArcherQaRunner
extends RefCounted

const _REGISTRY := preload("res://tests/archer_scenario_registry.gd")

static func run_all(failures: Array[String]) -> void:
	var ran_paths: Dictionary = {}
	for entry: Dictionary in _REGISTRY.all_entries():
		var name := String(entry.get("name", "?"))
		var script_path := String(entry.get("script_path", ""))
		print("[ARCHER_QA] %s" % name)
		if ran_paths.has(script_path):
			continue
		ran_paths[script_path] = true
		if not _REGISTRY.run_scenario(script_path, failures):
			failures.append("registry/%s: failed to load or run scenario" % name)
