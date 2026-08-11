extends RefCounted

## Bible: Geyser Strike — RANGE 2, MAG ATK 2, PUSH 1, creates WATER; [+] PUSH 2 on WATER.
## Globals: DAMAGE + PUSH + CREATE_HAZARD and shared shaped planning footprint.
## Modules: M0 magical DAMAGE range 2; PUSH layer; WATER layer; [+] conditional PUSH 2.
## Planning tier: B
## Data/Sim delegate: tests/monk_qa_harness.gd::run_single_ability
const _H := preload("res://tests/monk_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"monk_geyser_strike", failures)
	_H.run_upgrade_sim_for(&"monk_geyser_strike", failures)
