extends RefCounted

## Bible: shaman_hex — missing-health debuff contract.
const _A := preload("res://tests/shaman_scenario_adapter.gd")

static func run_all(failures: Array[String]) -> void:
	_A.run_active(&"shaman_hex", failures)
