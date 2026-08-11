extends RefCounted

## Bible: Elemental Attunement — attack on elemental surface grants PIERCE; [+] BURN/BLEED MAG.
## Globals: surface attack passive trigger and shared status application.
## Data/Sim delegate: tests/monk_qa_harness.gd::run_passive_factory
const _H := preload("res://tests/monk_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"elemental_attunement", failures)
