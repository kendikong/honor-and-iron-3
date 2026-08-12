extends RefCounted

## Bible: shaman_bone_spear — SKEWER 4 and barricade footprint contract.
const _A := preload("res://tests/shaman_scenario_adapter.gd")

static func run_all(failures: Array[String]) -> void:
	_A.run_active(&"shaman_bone_spear", failures)
