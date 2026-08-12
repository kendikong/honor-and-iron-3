extends RefCounted

## Bible: shaman_earthbind_totem — ROOT pulse contract.
const _A := preload("res://tests/shaman_scenario_adapter.gd")

static func run_all(failures: Array[String]) -> void:
	_A.run_active(&"shaman_earthbind_totem", failures)
