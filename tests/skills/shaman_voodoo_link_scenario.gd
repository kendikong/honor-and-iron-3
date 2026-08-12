extends RefCounted

## Bible: shaman_voodoo_link — Bloodweaver link contract.
const _A := preload("res://tests/shaman_scenario_adapter.gd")

static func run_all(failures: Array[String]) -> void:
	_A.run_active(&"shaman_voodoo_link", failures)
