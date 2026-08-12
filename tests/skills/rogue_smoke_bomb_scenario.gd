extends RefCounted
## Bible: rogue_smoke_bomb - Rogue active, hazard/stealth proof through shared systems.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"rogue_smoke_bomb", failures)
	_H.run_upgrade_for(&"rogue_smoke_bomb", failures)
