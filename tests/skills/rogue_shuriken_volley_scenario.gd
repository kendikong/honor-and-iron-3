extends RefCounted
## Bible: rogue_shuriken_volley - Rogue active, cone/bleed/pierce/blind proof through shared systems.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"rogue_shuriken_volley", failures)
	_H.run_upgrade_for(&"rogue_shuriken_volley", failures)
