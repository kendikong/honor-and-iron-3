class_name ArcherHuntersMarkScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/archer_qa_harness_scenarios.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

## Planning tier: B


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"archer_hunters_mark")


static func _sim_contract(failures: Array[String]) -> void:
		_Scenarios.run_hunters_mark(failures)
