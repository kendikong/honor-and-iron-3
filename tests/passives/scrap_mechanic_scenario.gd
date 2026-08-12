extends RefCounted
## Bible §12 passive: Scrap Mechanic — enemy dying in RANGE 3 drops Scrap; [+] drops 2.
## Globals: EngineerSystems.on_kill + UnitState.scrap.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"scrap_mechanic", failures)
