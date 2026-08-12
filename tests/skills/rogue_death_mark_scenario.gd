extends RefCounted
## Bible: rogue_death_mark - Rogue active, mark/refresh proof through shared systems.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"rogue_death_mark", failures)
	_H.run_upgrade_for(&"rogue_death_mark", failures)
