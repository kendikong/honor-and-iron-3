class_name BruiserAdrenalineSurgeScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")
const _Upgrades := preload("res://tests/class_scenario_upgrade_registry.gd")

## Planning tier: B

## Bible: Adrenaline Surge - SELF | spend 5 HP | +1 MOV +1 STR next turn; 0 AP if 2+ adjacent enemies.
## [+] Pre-Move action: skip Action slot, execute immediately (1/turn).
## Globals: ADD_STATUS_SELF STR/MOV; ZERO_IF_ADJACENT_ENEMIES_GTE_N; upgraded_planner_group PRE_MOVE.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"bruiser_adrenaline_surge")


static func _sim_contract(failures: Array[String]) -> void:
		_Scenarios.run_adrenaline_surge(failures)
		_sim_upgrade(failures)

static func _sim_upgrade(failures: Array[String]) -> void:
	_Upgrades.run_for_factory(failures, &"bruiser_adrenaline_surge")
