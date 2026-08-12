extends RefCounted

## Bible: Spirit Palm — RANGE 2, MAG ATK 2, PUSH 1; collision triggers ATK 2 splash; [+] WEAKEN.
## Globals: DAMAGE + PUSH collision pipeline and conditional splash layer.
## Modules: M0 magical DAMAGE range 2; M1 PUSH 1; [+] collision splash/WEAKEN modifiers.
## Planning tier: B
## Data/Sim delegate: tests/monk_qa_harness.gd::run_single_ability
const _H := preload("res://tests/monk_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"monk_spirit_palm", failures)
	_H.run_upgrade_sim_for(&"monk_spirit_palm", failures)
	_Planning.run_for_factory(failures, &"monk_spirit_palm")
