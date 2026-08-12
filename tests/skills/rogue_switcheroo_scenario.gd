extends RefCounted
## Bible: rogue_switcheroo - Rogue active, swap/incoming inheritance proof through shared systems.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"rogue_switcheroo", failures)
	_H.run_upgrade_for(&"rogue_switcheroo", failures)
