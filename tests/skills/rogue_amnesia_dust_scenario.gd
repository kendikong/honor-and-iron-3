extends RefCounted
## Bible: rogue_amnesia_dust - Rogue active, damage/blind/confusion/poison proof through shared systems.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"rogue_amnesia_dust", failures)
	_H.run_upgrade_for(&"rogue_amnesia_dust", failures)
