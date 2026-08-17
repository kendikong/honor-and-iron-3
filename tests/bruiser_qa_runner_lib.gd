extends RefCounted

const _REGISTRY := preload("res://tests/bruiser_scenario_registry.gd")
const _HARNESS := preload("res://tests/bruiser_qa_harness.gd")
const _UPGRADES := preload("res://tests/bruiser_qa_harness_upgrades.gd")
const _DRAG := preload("res://tests/planning_drag_e2e_harness.gd")
const _PLANNING := preload("res://tests/bruiser_planning_smoke_registry.gd")

## Tier 1 Bruiser scenario library (not a Godot main script).
## Run gate: F5 `BruiserQaGate.tscn`, or `--script res://tests/bruiser_qa_runner.gd`


static func run_all(failures: Array[String]) -> void:
	_HARNESS.run_shape_geometry(failures)
	for entry: Dictionary in _REGISTRY.all_entries():
		var name: String = String(entry.get("name", "?"))
		var factory_id: StringName = entry.get("factory_id", &"") as StringName
		var script_path: String = String(entry.get("script_path", ""))
		if factory_id == &"bruiser_meat_shield":
			print("[BRUISER_QA] %s (%s) N/A — Action ally relocation deferred" % [name, factory_id])
			continue
		print("[BRUISER_QA] %s (%s)" % [name, factory_id])
		if not _REGISTRY.run_scenario(script_path, failures):
			_HARNESS.assert_fail(failures, "registry/%s" % name, "failed to load or run scenario script")
			continue
		_UPGRADES.run_upgrade_for(name, failures)
		_PLANNING.run_for_factory_id(failures, factory_id)
		_DRAG.cleanup_all()
