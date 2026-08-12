extends RefCounted
## Bible: Shadow Strike - Rogue promotion passive, teleport adjacency mark/root.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"shadow_strike", failures)
