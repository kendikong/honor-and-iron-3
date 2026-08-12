extends RefCounted
## Bible §12 passive: Recycling Protocol — friendly Construct destroyed grants 2 Scrap and 1 AP once/turn; [+] 3 Scrap.
## Globals: EngineerSystems.on_construct_destroyed + UnitState economy.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"recycling_protocol", failures)
