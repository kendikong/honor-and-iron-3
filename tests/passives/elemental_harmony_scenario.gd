extends RefCounted

## Bible: Elemental Harmony — ATK bonus per adjacent elemental tile; [+] doubled.
## Globals: shared adjacent-tile stat recalculation.
## Data/Sim delegate: tests/monk_qa_harness.gd::run_passive_factory
const _H := preload("res://tests/monk_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"elemental_harmony", failures)
