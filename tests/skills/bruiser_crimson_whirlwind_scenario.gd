class_name BruiserCrimsonWhirlwindScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")
const _Upgrades := preload("res://tests/class_scenario_upgrade_registry.gd")

## Planning tier: B

## Bible: Crimson Whirlwind - RANGE 0 | AOE 3x3 | ATK 1.
## [+] HEAL 1 for every target successfully hit.
## Globals: EffectType.DAMAGE + TargetShape.AOE_SQUARE; RANGE 0 ? SELF.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"bruiser_crimson_whirlwind")


static func _sim_contract(failures: Array[String]) -> void:
		_Scenarios.run_crimson_whirlwind(failures)
		_sim_upgrade(failures)


static func _sim_upgrade(failures: Array[String]) -> void:
	_Upgrades.run_for_factory(failures, &"bruiser_crimson_whirlwind")
