extends RefCounted
## Bible: rogue_poison_flask - Rogue active, damage/poison hazard/blind proof through shared systems.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"rogue_poison_flask", failures)
	_H.run_upgrade_for(&"rogue_poison_flask", failures)
