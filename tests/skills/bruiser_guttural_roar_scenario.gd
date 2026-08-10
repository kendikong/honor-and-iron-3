class_name BruiserGutturalRoarScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")
const _Upgrades := preload("res://tests/class_scenario_upgrade_registry.gd")

## Planning tier: B

## Bible: Guttural Roar - RANGE 0 | AOE 2 | PUSH 1 | DEF -2.
## [+] PUSH items/coins/scrap; item collision ATK 1.
## Globals: EffectType.PUSH + STAT_DEBUFF_DEF; TargetShape.AOE_SQUARE; RANGE 0 ? SELF.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"bruiser_guttural_roar")


static func _sim_contract(failures: Array[String]) -> void:
		_Scenarios.run_guttural_roar(failures)
		_sim_upgrade(failures)


static func _sim_upgrade(failures: Array[String]) -> void:
	_Upgrades.run_for_factory(failures, &"bruiser_guttural_roar")
