extends RefCounted

## Bible: lancer_glorious_charge — Lancer factory row via shared Simulator harness.
## Globals: AbilitySystem / Simulator (Rule A).

const _H := preload("res://tests/lancer_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

## Planning tier: B


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"lancer_glorious_charge")


static func _sim_contract(failures: Array[String]) -> void:
		_H.run_single_active(&"lancer_glorious_charge", failures)
