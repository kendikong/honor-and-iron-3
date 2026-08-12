extends RefCounted

## Bible: hexing_touch — Soulwalker passive contract.
const _A := preload("res://tests/shaman_scenario_adapter.gd")

static func run_all(failures: Array[String]) -> void:
	_A.run_passive(&"hexing_touch", failures)
