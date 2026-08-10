class_name BruiserBreachingDashScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")
const _Upgrades := preload("res://tests/class_scenario_upgrade_registry.gd")

## Planning tier: B

## Bible: Breaching Dash - DASH 3 | destroy destructible cover on path.
## [+] next attack this turn gains PIERCE.
## Globals: EffectType.DASH + DESTROY_OBSTACLE; DASH_LINE targeting.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"bruiser_breaching_dash")


static func _sim_contract(failures: Array[String]) -> void:
		_Scenarios.run_breaching_dash(failures)
		_sim_upgrade(failures)


static func _sim_upgrade(failures: Array[String]) -> void:
	_Upgrades.run_for_factory(failures, &"bruiser_breaching_dash")
