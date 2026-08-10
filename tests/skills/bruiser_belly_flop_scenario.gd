class_name BruiserBellyFlopScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")
const _Upgrades := preload("res://tests/class_scenario_upgrade_registry.gd")

## Planning tier: B

## Bible: Belly Flop - RANGE 2 | ATK 2 | jump to empty tile.
## [+] landing PUSH 1 to all adjacent enemies.
## Globals: EffectType.TELEPORT_CASTER + DAMAGE; damage_adjacent_on_landing modifier.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"bruiser_belly_flop")


static func _sim_contract(failures: Array[String]) -> void:
		_Scenarios.run_belly_flop(failures)
		_sim_upgrade(failures)


static func _sim_upgrade(failures: Array[String]) -> void:
	_Upgrades.run_for_factory(failures, &"bruiser_belly_flop")
