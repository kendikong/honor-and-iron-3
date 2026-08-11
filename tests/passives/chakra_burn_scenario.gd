extends RefCounted

## Bible: Chakra Burn — hitting a hazard applies BURN MAG; [+] also BLIND.
## Globals: hazard-hit passive trigger and shared status system.
## Data/Sim delegate: tests/monk_qa_harness.gd::run_passive_factory
const _H := preload("res://tests/monk_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"chakra_burn", failures)
