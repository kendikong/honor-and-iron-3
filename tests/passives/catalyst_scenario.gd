extends RefCounted

## Bible: Catalyst — on elemental surface +1 MAG and +1 DEF; [+] +1 MOV.
## Globals: shared surface stat recalculation.
## Data/Sim delegate: tests/monk_qa_harness.gd::run_passive_factory
const _H := preload("res://tests/monk_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"catalyst", failures)
