extends RefCounted
## Bible: Mind Static - Rogue promotion passive, range and defense suppression.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"mind_static", failures)
