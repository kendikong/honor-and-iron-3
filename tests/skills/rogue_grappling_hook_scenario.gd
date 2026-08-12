extends RefCounted
## Bible: rogue_grappling_hook - Rogue active, pull/trap damage proof through shared systems.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"rogue_grappling_hook", failures)
	_H.run_upgrade_for(&"rogue_grappling_hook", failures)
