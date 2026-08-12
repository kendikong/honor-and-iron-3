extends RefCounted

## Bible: Chakra Shift — SELF; swap STR and MAG for 2 turns; [+] MAG ATK 1 AOE 2 burst.
## Globals: ADD_STATUS_SELF with shared stat-state modifier and AOE footprint.
## Modules: M0 self status duration 2; [+] burst modifier and AOE shape.
## Planning tier: B
## Data/Sim delegate: tests/monk_qa_harness.gd::run_single_ability
const _H := preload("res://tests/monk_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"monk_chakra_shift", failures)
	_H.run_upgrade_sim_for(&"monk_chakra_shift", failures)
	_Planning.run_for_factory(failures, &"monk_chakra_shift")
