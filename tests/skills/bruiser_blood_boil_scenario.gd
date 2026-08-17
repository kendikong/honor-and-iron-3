class_name BruiserBloodBoilScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")
const _Upgrades := preload("res://tests/class_scenario_upgrade_registry.gd")

## Planning tier: B

## Bible: Blood Boil - SELF | spend 5 HP; next-turn attacks gain ATK +2 and BLEED WPN.
## [+] spend 10 HP; next-turn attacks gain ATK +4 and BLEED WPN.
## Globals: ADD_STATUS_SELF next-turn attack payload; shared attack/turn systems.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"bruiser_blood_boil")


static func _sim_contract(failures: Array[String]) -> void:
		_Scenarios.run_blood_boil(failures)
		_sim_upgrade(failures)


static func _sim_upgrade(failures: Array[String]) -> void:
	_Upgrades.run_for_factory(failures, &"bruiser_blood_boil")
