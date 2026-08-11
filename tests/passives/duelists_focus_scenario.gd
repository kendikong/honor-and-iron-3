class_name DuelistsFocusScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/mercenary_qa_harness_scenarios.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")
const _Upgrades := preload("res://tests/class_scenario_upgrade_registry.gd")

## Bible: Duelist's Focus — Unacted BLIND.
## Globals: MercenarySystems + AbilitySystem + Simulator.simulate_player_turn
## Data/Sim delegate: tests/mercenary_qa_harness_scenarios.gd::run_duelists_focus


static func run_all(failures: Array[String]) -> void:
	_sim_trigger(failures)
	_Planning.run_for_factory(failures, &"duelists_focus")


static func _sim_trigger(failures: Array[String]) -> void:
	_Scenarios.run_duelists_focus(failures)
	_sim_upgrade(failures)


static func _sim_upgrade(failures: Array[String]) -> void:
	_Upgrades.run_for_factory(failures, &"duelists_focus")
