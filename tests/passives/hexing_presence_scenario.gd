extends RefCounted

## Bible: hexing_presence — Shaman innate aura contract.
const _A := preload("res://tests/shaman_scenario_adapter.gd")

static func run_all(failures: Array[String]) -> void:
	_A.run_passive(&"hexing_presence", failures)
