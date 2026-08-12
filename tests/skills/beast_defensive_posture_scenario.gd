class_name BeastDefensivePostureScenarioTest
extends RefCounted

const _H := preload("res://tests/beast_rider_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

## Bible: Defensive Posture — SELF | INTERCEPT 50% and DEF +2 for 1 turn; [+] PUSH 2 attacker if hit.
## Globals: AbilitySystem self-status layer and CombatSystem interception.
## Data/Sim delegate: tests/beast_rider_qa_harness.gd::run_ability_row

static func run_all(failures: Array[String]) -> void:
	_data_contract(failures)
	_sim_contract(failures)
	_sim_upgrade(failures)
	_Planning.run_for_factory(failures, &"beast_defensive_posture")

static func _data_contract(failures: Array[String]) -> void:
	_H.run_factory_matrix(failures)

static func _sim_contract(failures: Array[String]) -> void:
	_H.run_ability_row(&"beast_defensive_posture", failures)

static func _sim_upgrade(failures: Array[String]) -> void:
	_H.run_ability_upgrade_row(&"beast_defensive_posture", failures)
