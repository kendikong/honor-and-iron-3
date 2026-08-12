extends RefCounted

## Bible: spiritual_guardian — Spirit Caller passive contract.
const _A := preload("res://tests/shaman_scenario_adapter.gd")

static func run_all(failures: Array[String]) -> void:
	_A.run_passive(&"spiritual_guardian", failures)
