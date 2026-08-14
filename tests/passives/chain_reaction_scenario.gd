extends RefCounted

## Bible: Linked Ripple — applying PUSH to a linked enemy applies PUSH 1 to all other linked enemies.
## Globals: ShamanSystems shared hooks + Simulator.
## Data/Sim delegate: tests/shaman_qa_harness.gd::run_passive_factory
const _H := preload("res://tests/shaman_qa_harness.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"chain_reaction", failures)
