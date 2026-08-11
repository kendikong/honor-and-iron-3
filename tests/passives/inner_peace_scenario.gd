extends RefCounted

## Bible: Inner Peace — spending 0 MOV grants PIERCE; [+] attack gains ATK +2.
## Globals: shared turn economy boundary and next-attack modifiers.
## Data/Sim delegate: tests/monk_qa_harness.gd::run_passive_factory
const _H := preload("res://tests/monk_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"inner_peace", failures)
