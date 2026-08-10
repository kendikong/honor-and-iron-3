class_name BruiserViolentCollisionScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")
const _Upgrades := preload("res://tests/class_scenario_upgrade_registry.gd")

## Planning tier: B

## Bible: Violent Collision - DASH 3 | bulldoze + recast MOVE 2 on enemy hit.
## [+] collisions apply STAGGER (1 turn).
## Globals: EffectType.DASH + bulldoze/violent_collision_recast modifiers.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"bruiser_violent_collision")


static func _sim_contract(failures: Array[String]) -> void:
		_Scenarios.run_violent_collision(failures)
		_sim_upgrade(failures)


static func _sim_upgrade(failures: Array[String]) -> void:
	_Upgrades.run_for_factory(failures, &"bruiser_violent_collision")
