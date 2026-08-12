extends RefCounted
## Bible: rogue_slip_past - Rogue movement skill, pass-through push proof.
## Globals: RogueSystems + MovementSystem + Simulator
## Data/Sim delegate: tests/rogue_qa_harness.gd::run_single_ability
const _H := preload("res://tests/rogue_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"rogue_slip_past", failures)
	_H.run_upgrade_for(&"rogue_slip_past", failures)
	_Planning.run_for_factory(failures, &"rogue_slip_past")
