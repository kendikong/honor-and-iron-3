extends RefCounted

## Bible: Ki Momentum — +1 STR per 2 tiles moved before attack; [+] per 1 tile.
## Globals: shared movement-distance attack scaling.
## Data/Sim delegate: tests/monk_qa_harness.gd::run_passive_factory
const _H := preload("res://tests/monk_qa_harness.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"momentum_transfer", failures)
