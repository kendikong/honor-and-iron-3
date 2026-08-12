class_name BeastAerialSuperiorityScenarioTest
extends RefCounted

const _H := preload("res://tests/beast_rider_qa_harness.gd")

## Bible: Aerial Superiority — +2 DEF versus grounded melee; [+] grounded ROOT immunity.
## Globals: CombatSystem defense and crowd-control resistance.
## Data/Sim delegate: tests/beast_rider_qa_harness.gd::run_passive_row

static func run_all(failures: Array[String]) -> void:
	_data_contract(failures)
	_sim_trigger(failures)

static func _data_contract(failures: Array[String]) -> void:
	_H.run_factory_matrix(failures)

static func _sim_trigger(failures: Array[String]) -> void:
	_H.run_passive_row(&"aerial_superiority", failures)
