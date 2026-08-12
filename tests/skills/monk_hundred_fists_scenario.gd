extends RefCounted

## Bible: Hundred Fists — RANGE 1, ATK 4; caster loses 2 MOV on following turn; [+] ATK per target status.
## Globals: physical DAMAGE plus following-turn economy and status-count modifiers.
## Modules: M0 physical DAMAGE range 1; [+] status-count bonus.
## Planning tier: B
## Data/Sim delegate: tests/monk_qa_harness.gd::run_single_ability
const _H := preload("res://tests/monk_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"monk_hundred_fists", failures)
	_H.run_upgrade_sim_for(&"monk_hundred_fists", failures)
	_Planning.run_for_factory(failures, &"monk_hundred_fists")
