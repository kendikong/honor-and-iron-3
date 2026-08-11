extends RefCounted

## Bible: Soul Punch — RANGE 1, ATK 3 targets MAG instead of DEF; [+] permanently steal 1 MAG.
## Globals: physical DAMAGE with target-magic-defense and persistent-steal modifiers.
## Modules: M0 physical DAMAGE range 1; [+] target magic defense and steal delta.
## Planning tier: B
## Data/Sim delegate: tests/monk_qa_harness.gd::run_single_ability
const _H := preload("res://tests/monk_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"monk_soul_punch", failures)
	_H.run_upgrade_sim_for(&"monk_soul_punch", failures)
