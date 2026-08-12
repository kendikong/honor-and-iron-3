class_name BeastAirliftScenarioTest
extends RefCounted

const _H := preload("res://tests/beast_rider_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

## Bible: Airlift — RANGE 1 | pick up adjacent ally Step 1, drop empty Step 3 post-action; [+] ally ATK +1.
## Globals: AbilitySystem ordered planning phases and shared teleport presentation.
## Data/Sim delegate: tests/beast_rider_qa_harness.gd::run_ability_row

static func run_all(failures: Array[String]) -> void:
	_data_contract(failures)
	_sim_contract(failures)
	_sim_upgrade(failures)
	_Planning.run_for_factory(failures, &"beast_airlift")

static func _data_contract(failures: Array[String]) -> void:
	_H.run_factory_matrix(failures)

static func _sim_contract(failures: Array[String]) -> void:
	_H.run_ability_row(&"beast_airlift", failures)

static func _sim_upgrade(failures: Array[String]) -> void:
	_H.run_ability_upgrade_row(&"beast_airlift", failures)
