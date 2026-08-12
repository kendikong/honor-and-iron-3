extends RefCounted
## Bible: Board Scrambler - Rogue promotion passive, high-health damage swap.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"board_scrambler", failures)
