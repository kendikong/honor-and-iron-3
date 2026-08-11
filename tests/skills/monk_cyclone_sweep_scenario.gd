extends RefCounted

## Bible: Cyclone Sweep — RANGE 1 ARC; PUSH 2 all targets; [+] +1 MOV per enemy pushed.
## Globals: shared GridSystem ARC footprint and PUSH resolution.
## Modules: M0 PUSH 2 ARC; [+] per-push movement modifier.
## Planning tier: B
## Data/Sim delegate: tests/monk_qa_harness.gd::run_single_ability
const _H := preload("res://tests/monk_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"monk_cyclone_sweep", failures)
	_H.run_upgrade_sim_for(&"monk_cyclone_sweep", failures)
