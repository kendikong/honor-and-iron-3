extends RefCounted
## Bible: rogue_blindside - Rogue active, damage/stagger proof through shared systems.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"rogue_blindside", failures)
	_H.run_upgrade_for(&"rogue_blindside", failures)
