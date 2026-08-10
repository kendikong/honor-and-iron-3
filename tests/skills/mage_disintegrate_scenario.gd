extends RefCounted

## Bible: mage_disintegrate — Mage active via AbilitySystem + Simulator.
const _H := preload("res://tests/mage_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

## Planning tier: B

static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"mage_disintegrate")


static func _sim_contract(failures: Array[String]) -> void:
		_H.run_single_ability(&"mage_disintegrate", failures)
