class_name BeastSavageBiteScenarioTest
extends RefCounted

const _H := preload("res://tests/beast_rider_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

## Bible: Savage Bite — RANGE 1 | ATK 4 | target BLEED/POISON; [+] on kill SHIELD 2.
## Globals: AbilitySystem damage legality and CombatSystem kill lifecycle.
## Data/Sim delegate: tests/beast_rider_qa_harness.gd::run_ability_row

static func run_all(failures: Array[String]) -> void:
	_data_contract(failures)
	_sim_contract(failures)
	_sim_upgrade(failures)
	_Planning.run_for_factory(failures, &"beast_savage_bite")

static func _data_contract(failures: Array[String]) -> void:
	_H.run_factory_matrix(failures)

static func _sim_contract(failures: Array[String]) -> void:
	_H.run_ability_row(&"beast_savage_bite", failures)

static func _sim_upgrade(failures: Array[String]) -> void:
	_H.run_ability_upgrade_row(&"beast_savage_bite", failures)
