extends RefCounted

## Bible: Updraft — SELF; AIRBORNE and +1 MOV for 2 turns; [+] passing over enemy BLIND.
## Globals: ADD_STATUS_SELF AIRBORNE plus shared movement status layer.
## Modules: M0 self status duration 2; M1 MOV +1; [+] pass-over BLIND modifier.
## Planning tier: B
## Data/Sim delegate: tests/monk_qa_harness.gd::run_single_ability
const _H := preload("res://tests/monk_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"monk_updraft", failures)
	_H.run_upgrade_sim_for(&"monk_updraft", failures)
