extends RefCounted

## Bible: sympathetic_magic — Bloodweaver passive contract.
const _A := preload("res://tests/shaman_scenario_adapter.gd")

static func run_all(failures: Array[String]) -> void:
	_A.run_passive(&"sympathetic_magic", failures)
