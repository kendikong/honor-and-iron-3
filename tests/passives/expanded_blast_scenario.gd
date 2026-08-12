extends RefCounted
## Bible §12 passive: Expanded Blast — explosion AOE +1 tile; [+] destroy traps and cover.
## Globals: GridSystem + AbilitySystem terrain destruction.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"expanded_blast", failures)
