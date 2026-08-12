extends RefCounted
## Bible: Pass - Rogue innate passive, ghost movement and enemy pass-through.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"pass", failures)
