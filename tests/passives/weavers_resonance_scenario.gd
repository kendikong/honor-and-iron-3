extends RefCounted

## Bible: Weaver's Resonance — consuming a weave triggers 1-tile elemental shockwave and SHIELD 1; [+] WEAKEN.
## Globals: shared weave-consumption trigger, GridSystem footprint, and status effects.
## Data/Sim delegate: tests/monk_qa_harness.gd::run_passive_factory
const _H := preload("res://tests/monk_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"weavers_resonance", failures)
