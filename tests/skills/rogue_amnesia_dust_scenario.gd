extends RefCounted
## Bible: rogue_amnesia_dust - Rogue active skill via shared RogueSystems / AbilitySystem / Simulator.
## Globals: RogueSystems + AbilitySystem + Simulator
## Data/Sim delegate: tests/rogue_qa_harness.gd::run_single_ability
const _H := preload("res://tests/rogue_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"rogue_amnesia_dust", failures)
	_H.run_upgrade_for(&"rogue_amnesia_dust", failures)
	_Planning.run_for_factory(failures, &"rogue_amnesia_dust")
