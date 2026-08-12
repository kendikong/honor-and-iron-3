extends RefCounted
## Bible §12 passive: Reinforced Constructs — +25% Max HP and inherit 50% DEF; [+] +50% and 100%.
## Globals: EngineerSystems.on_spawned construct scaling.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"reinforced_constructs", failures)
