class_name BeastBestialRoarScenarioTest
extends RefCounted

const _H := preload("res://tests/beast_rider_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

## Bible: Bestial Roar — CONE 3 | PUSH 2 | FEAR only debuffed targets; [+] DEF -1 in cone.
## Globals: GridSystem cone footprint, PhysicsSystem push, and status layers.
## Data/Sim delegate: tests/beast_rider_qa_harness.gd::run_ability_row

static func run_all(failures: Array[String]) -> void:
	_data_contract(failures)
	_sim_contract(failures)
	_sim_upgrade(failures)
	_Planning.run_for_factory(failures, &"beast_bestial_roar")

static func _data_contract(failures: Array[String]) -> void:
	_H.run_factory_matrix(failures)

static func _sim_contract(failures: Array[String]) -> void:
	_H.run_ability_row(&"beast_bestial_roar", failures)

static func _sim_upgrade(failures: Array[String]) -> void:
	_H.run_ability_upgrade_row(&"beast_bestial_roar", failures)
