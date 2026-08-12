extends RefCounted
## Bible: rogue_evasive_strike - Rogue active, move/damage/defense proof through shared systems.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"rogue_evasive_strike", failures)
	_H.run_upgrade_for(&"rogue_evasive_strike", failures)
