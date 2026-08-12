extends RefCounted
## Bible: Backstab - Rogue promotion passive, ignore DEF after pass-through.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"backstab", failures)
