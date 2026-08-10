extends RefCounted

## Bible: mage_time_warp — Mage active via AbilitySystem + Simulator.
const _H := preload("res://tests/mage_qa_harness.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"mage_time_warp", failures)
