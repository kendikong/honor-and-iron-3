extends RefCounted

## Bible: voodoo_doll — class_abilities.txt section 10 Shaman passive.
## Globals: ShamanSystems shared hooks + Simulator.
## Data/Sim delegate: tests/shaman_qa_harness.gd::run_passive_factory
const _H := preload("res://tests/shaman_qa_harness.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"voodoo_doll", failures)
