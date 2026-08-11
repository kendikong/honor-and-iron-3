extends RefCounted

## Bible: Mantra of Peace — RANGE 0, AOE 2; WEAKEN 1 turn; [+] allies HEAL 1.
## Globals: AOE target footprint, ADD_STATUS WEAKEN, and HEAL layer.
## Modules: M0 AOE_CROSS size 2 status; [+] ally heal layer.
## Planning tier: B
## Data/Sim delegate: tests/monk_qa_harness.gd::run_single_ability
const _H := preload("res://tests/monk_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"monk_mantra_of_peace", failures)
	_H.run_upgrade_sim_for(&"monk_mantra_of_peace", failures)
