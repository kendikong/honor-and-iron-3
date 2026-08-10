extends RefCounted

## Bible: cleric_holy_light - Cleric ability factory + sim contract.
const _H := preload("res://tests/cleric_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")
const _Upgrades := preload("res://tests/class_scenario_upgrade_registry.gd")

## Planning tier: B

static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"cleric_holy_light")


static func _sim_contract(failures: Array[String]) -> void:
		_H.run_ability_row(&"cleric_holy_light", failures)
		_sim_upgrade(failures)

static func _sim_upgrade(failures: Array[String]) -> void:
	_Upgrades.run_for_factory(failures, &"cleric_holy_light")
