extends RefCounted

## Bible: cleric_holy_wrath — Cleric ability factory + sim contract.
const _H := preload("res://tests/cleric_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

## Planning tier: B

static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"cleric_holy_wrath")


static func _sim_contract(failures: Array[String]) -> void:
		_H.run_ability_row(&"cleric_holy_wrath", failures)
