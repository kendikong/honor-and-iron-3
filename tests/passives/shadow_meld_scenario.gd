extends RefCounted
## Bible: Shadow Meld - Rogue promotion passive, smoke spell conversion/free AP.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"shadow_meld", failures)
