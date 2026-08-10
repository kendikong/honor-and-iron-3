class_name BruiserBloodBoilScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

## Planning tier: B

## Bible: Blood Boil — SELF | spend 5 HP for STR +3 (1 turn).
## [+] spend 10 HP for STR +5 instead.
## Globals: EffectType.DAMAGE_SELF + ADD_STATUS_SELF STAT_BUFF_STR.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"bruiser_blood_boil")


static func _sim_contract(failures: Array[String]) -> void:
		_Scenarios.run_blood_boil(failures)

