extends RefCounted
## Bible: rogue_slip_past - Rogue active, movement/push proof through shared systems.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"rogue_slip_past", failures)
	_H.run_upgrade_for(&"rogue_slip_past", failures)
