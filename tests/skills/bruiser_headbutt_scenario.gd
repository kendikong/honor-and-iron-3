class_name BruiserHeadbuttScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")
const _Upgrades := preload("res://tests/class_scenario_upgrade_registry.gd")

## Planning tier: B

## Bible: Headbutt - RANGE 1 | ATK 3 | mutual 1 dmg + STAGGER.
## [+] bonus damage = Round Down(10% Max HP).
## Globals: EffectType.DAMAGE + DAMAGE_SELF + STAGGER on target and caster.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"bruiser_headbutt")


static func _sim_contract(failures: Array[String]) -> void:
		_Scenarios.run_headbutt(failures)
		_sim_upgrade(failures)


static func _sim_upgrade(failures: Array[String]) -> void:
	_Upgrades.run_for_factory(failures, &"bruiser_headbutt")
