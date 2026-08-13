extends RefCounted

const _H := preload("res://tests/engineer_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

## Bible §12: Construct Turret — RANGE 2 summon turret ATK 1/turn; [+] on death ATK 2 adjacent.
## Globals: AbilitySystem + EngineerSystems + Simulator + GridSystem.
## Data/Sim delegate: tests/engineer_qa_harness.gd::run_ability_row

static func run_all(failures: Array[String]) -> void:
	_data_contract(failures)
	_sim_contract(failures)
	_sim_upgrade(failures)
	_Planning.run_for_factory(failures, &"engineer_construct_turret")

static func _data_contract(failures: Array[String]) -> void:
	_H.run_factory_matrix(failures)

static func _sim_contract(failures: Array[String]) -> void:
	_H.run_ability_row(&"engineer_construct_turret", failures)

static func _sim_upgrade(failures: Array[String]) -> void:
	_H.run_ability_upgrade_row(&"engineer_construct_turret", failures)
