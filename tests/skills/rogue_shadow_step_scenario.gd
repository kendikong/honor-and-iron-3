extends RefCounted
## Bible: rogue_shadow_step - Rogue active, teleport/strength proof through shared systems.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"rogue_shadow_step", failures)
	_H.run_upgrade_for(&"rogue_shadow_step", failures)
