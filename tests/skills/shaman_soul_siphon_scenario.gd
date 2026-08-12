extends RefCounted

## Bible: shaman_soul_siphon — debuff-scaled damage contract.
const _A := preload("res://tests/shaman_scenario_adapter.gd")

static func run_all(failures: Array[String]) -> void:
	_A.run_active(&"shaman_soul_siphon", failures)
