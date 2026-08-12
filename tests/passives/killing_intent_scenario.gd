extends RefCounted
## Bible: Killing Intent - Rogue promotion passive, adjacent low-health AP.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"killing_intent", failures)
