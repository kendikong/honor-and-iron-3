class_name BeastRepositionScenarioTest
extends RefCounted

const _H := preload("res://tests/beast_rider_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

## Bible: Reposition — COST 2 MOV; move adjacent ally to the empty tile directly opposite you; [+] RANGE 2.
## Globals: MovementSystem + AbilitySystem TELEPORT_CASTER motion data.
## Data/Sim delegate: tests/beast_rider_qa_harness.gd::run_ability_row

static func run_all(failures: Array[String]) -> void:
	_data_contract(failures)
	_sim_contract(failures)
	_sim_upgrade(failures)
	_Planning.run_for_factory(failures, &"beast_reposition")

static func _data_contract(failures: Array[String]) -> void:
	_H.run_factory_matrix(failures)

static func _sim_contract(failures: Array[String]) -> void:
	_H.run_ability_row(&"beast_reposition", failures)

static func _sim_upgrade(failures: Array[String]) -> void:
	_H.run_ability_upgrade_row(&"beast_reposition", failures)
