extends RefCounted

## Bible: Inner Fire — SELF for 2 turns; physical attacks deal MAG ATK 1 splash; [+] splash creates FIRE.
## Globals: ADD_STATUS_SELF and shared attack follow-up/surface pipeline.
## Modules: M0 self status duration 2; [+] fire-surface modifier.
## Planning tier: B
## Data/Sim delegate: tests/monk_qa_harness.gd::run_single_ability
const _H := preload("res://tests/monk_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"monk_inner_fire", failures)
	_H.run_upgrade_sim_for(&"monk_inner_fire", failures)
	_Planning.run_for_factory(failures, &"monk_inner_fire")
