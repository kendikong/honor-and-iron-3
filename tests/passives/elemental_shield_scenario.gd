extends RefCounted

## Bible: Elemental Shield — creating terrain grants +1 DEF for the turn; [+] +2 DEF.
## Globals: shared terrain-created trigger and turn defense state.
## Data/Sim delegate: tests/monk_qa_harness.gd::run_passive_factory
const _H := preload("res://tests/monk_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"elemental_shield", failures)
