class_name BeastRiderBloodScentScenarioTest
extends RefCounted

const _H := preload("res://tests/beast_rider_qa_harness.gd")

## Bible: Blood Scent — +1 MOVE and PIERCE toward BLEEDing enemy; [+] +2 MOVE.
## Globals: MovementSystem direction intent and CombatSystem pierce validation.
## Data/Sim delegate: tests/beast_rider_qa_harness.gd::run_passive_row

static func run_all(failures: Array[String]) -> void:
	_data_contract(failures)
	_sim_trigger(failures)

static func _data_contract(failures: Array[String]) -> void:
	_H.run_factory_matrix(failures)

static func _sim_trigger(failures: Array[String]) -> void:
	_H.run_passive_row(&"blood_scent", failures)
