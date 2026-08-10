class_name ArcherToxicSporeArrowScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/archer_qa_harness_scenarios.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")
const _Upgrades := preload("res://tests/class_scenario_upgrade_registry.gd")

## Planning tier: B


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"archer_toxic_spore_arrow")


static func _sim_contract(failures: Array[String]) -> void:
		_Scenarios.run_toxic_spore_arrow(failures)
		_sim_upgrade(failures)

static func _sim_upgrade(failures: Array[String]) -> void:
	_Upgrades.run_for_factory(failures, &"archer_toxic_spore_arrow")
