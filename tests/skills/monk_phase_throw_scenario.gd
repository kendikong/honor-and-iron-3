extends RefCounted

## Bible: Phase Throw — RANGE 1; swap position with target enemy; [+] ROOT after swapping.
## Globals: EffectType.SWAP and ordered ADD_STATUS ROOT layer.
## Modules: M0 SWAP range 1 to enemy; [+] ROOT layer.
## Planning tier: B
## Data/Sim delegate: tests/monk_qa_harness.gd::run_single_ability
const _H := preload("res://tests/monk_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"monk_phase_throw", failures)
	_H.run_upgrade_sim_for(&"monk_phase_throw", failures)
	_Planning.run_for_factory(failures, &"monk_phase_throw")
