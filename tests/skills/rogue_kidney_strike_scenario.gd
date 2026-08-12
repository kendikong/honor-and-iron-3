extends RefCounted
## Bible: rogue_kidney_strike - Rogue active, damage/slow/root proof through shared systems.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"rogue_kidney_strike", failures)
	_H.run_upgrade_for(&"rogue_kidney_strike", failures)
