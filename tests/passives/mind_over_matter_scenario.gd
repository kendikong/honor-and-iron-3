extends RefCounted

## Bible: Mind over Matter — physical attacks scale from higher STR or MAG; [+] equal stats grant DEF.
## Globals: shared damage scaling and stat recalculation.
## Data/Sim delegate: tests/monk_qa_harness.gd::run_passive_factory
const _H := preload("res://tests/monk_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"mind_over_matter", failures)
