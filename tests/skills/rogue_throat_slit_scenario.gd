extends RefCounted
## Bible: rogue_throat_slit - Rogue active, damage/silence proof through shared systems.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"rogue_throat_slit", failures)
	_H.run_upgrade_for(&"rogue_throat_slit", failures)
