extends RefCounted

## Bible: Perfect Form — taking 0 damage last turn grants STR and MOV; [+] doubled.
## Globals: shared turn-boundary damage tracking and stat recalculation.
## Data/Sim delegate: tests/monk_qa_harness.gd::run_passive_factory
const _H := preload("res://tests/monk_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"perfect_form", failures)
