extends RefCounted
## Bible: Debuff Overload - Rogue promotion passive, turn-start damage per debuff.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"debuff_overload", failures)
