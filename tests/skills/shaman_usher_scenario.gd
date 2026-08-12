extends RefCounted

## Bible: shaman_usher — Shaman reposition skill.
const _A := preload("res://tests/shaman_scenario_adapter.gd")

static func run_all(failures: Array[String]) -> void:
	_A.run_active(&"shaman_usher", failures)
