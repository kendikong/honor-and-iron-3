class_name MercenaryDefenseStrikeScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/mercenary_qa_harness_scenarios.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")
const _Upgrades := preload("res://tests/class_scenario_upgrade_registry.gd")

## Bible: Defense Strike — ATK + DEF buff.
## Globals: MercenarySystems + AbilitySystem + Simulator.simulate_player_turn
## Data/Sim delegate: tests/mercenary_qa_harness_scenarios.gd::run_defense_strike


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"mercenary_defense_strike")


static func _sim_contract(failures: Array[String]) -> void:
	_Scenarios.run_defense_strike(failures)
	_sim_upgrade(failures)


static func _sim_upgrade(failures: Array[String]) -> void:
	_Upgrades.run_for_factory(failures, &"mercenary_defense_strike")
