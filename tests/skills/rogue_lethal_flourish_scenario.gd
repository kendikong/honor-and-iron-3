extends RefCounted
## Bible: rogue_lethal_flourish - Rogue active, damage/AP refund proof through shared systems.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"rogue_lethal_flourish", failures)
	_H.run_upgrade_for(&"rogue_lethal_flourish", failures)
