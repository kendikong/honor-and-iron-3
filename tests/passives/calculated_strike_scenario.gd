class_name CalculatedStrikeScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/mercenary_qa_harness_scenarios.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")
const _Upgrades := preload("res://tests/class_scenario_upgrade_registry.gd")

## Bible: Calculated Strike — Move before attack buff.
## Globals: MercenarySystems + AbilitySystem + Simulator.simulate_player_turn
## Data/Sim delegate: tests/mercenary_qa_harness_scenarios.gd::run_calculated_strike


static func run_all(failures: Array[String]) -> void:
	_sim_trigger(failures)
	_Planning.run_for_factory(failures, &"calculated_strike")


static func _sim_trigger(failures: Array[String]) -> void:
	_Scenarios.run_calculated_strike(failures)
	_sim_upgrade(failures)


static func _sim_upgrade(failures: Array[String]) -> void:
	_Upgrades.run_for_factory(failures, &"calculated_strike")
