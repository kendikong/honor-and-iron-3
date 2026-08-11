extends RefCounted

## Bible: Evasive Acrobat — gain GHOST; moving through enemies applies CONFUSION; [+] BLIND.
## Globals: shared movement pass-through and status trigger.
## Data/Sim delegate: tests/monk_qa_harness.gd::run_passive_factory
const _H := preload("res://tests/monk_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"evasive_acrobat", failures)
