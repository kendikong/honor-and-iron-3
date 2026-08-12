extends RefCounted
## Bible: Blink Strike - Rogue promotion passive, basic attack range.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"blink_strike", failures)
