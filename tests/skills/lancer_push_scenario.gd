extends RefCounted

## Bible: lancer_push - Lancer factory row via shared Simulator harness.
## Globals: AbilitySystem / Simulator (Rule A).

const _H := preload("res://tests/lancer_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")
const _Upgrades := preload("res://tests/class_scenario_upgrade_registry.gd")

## Planning tier: B


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"lancer_push")


static func _sim_contract(failures: Array[String]) -> void:
		_H.run_push_smoke(failures)
		_sim_upgrade(failures)

static func _sim_upgrade(failures: Array[String]) -> void:
	_Upgrades.run_for_factory(failures, &"lancer_push")
