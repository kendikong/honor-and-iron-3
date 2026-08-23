class_name BruiserViolentCollisionScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")
const _Upgrades := preload("res://tests/class_scenario_upgrade_registry.gd")

## Planning tier: B

## Bible: Violent Collision — DASH 3 | BULLDOZE; on enemy hit DASH 5 | BULLDOZE same line.
## [+] collisions apply STAGGER (1 turn).
## Globals: DASH + BULLDOZE; IF_LINE_COLLISION_MODIFY_PRIMARY_RANGE layer (3→5 on line hit).


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"bruiser_violent_collision")


static func _sim_contract(failures: Array[String]) -> void:
		_Scenarios.run_violent_collision(failures)
		_sim_upgrade(failures)


static func _sim_upgrade(failures: Array[String]) -> void:
	_Upgrades.run_for_factory(failures, &"bruiser_violent_collision")
