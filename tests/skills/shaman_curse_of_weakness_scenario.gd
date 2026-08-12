extends RefCounted

## Bible: shaman_curse_of_weakness — class_abilities.txt section 10 Shaman active skill.
## Globals: AbilitySystem, ShamanSystems, ClassScenarioSimOutcome.
## Data/Sim delegate: tests/shaman_qa_harness.gd::run_single_ability
const _H := preload("res://tests/shaman_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"shaman_curse_of_weakness", failures)
	_H.run_upgrade_sim_for(&"shaman_curse_of_weakness", failures)
	_Planning.run_for_factory(failures, &"shaman_curse_of_weakness")
