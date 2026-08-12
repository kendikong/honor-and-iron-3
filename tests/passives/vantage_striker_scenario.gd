class_name BeastVantageStrikerScenarioTest
extends RefCounted

const _H := preload("res://tests/beast_rider_qa_harness.gd")

## Bible: Vantage Striker — ignore difficult terrain; +1 STR in hazards or higher elevation; [+] +2 STR.
## Globals: MovementSystem terrain cost and CombatSystem terrain damage bonus.
## Data/Sim delegate: tests/beast_rider_qa_harness.gd::run_passive_row

static func run_all(failures: Array[String]) -> void:
	_data_contract(failures)
	_sim_trigger(failures)

static func _data_contract(failures: Array[String]) -> void:
	_H.run_factory_matrix(failures)

static func _sim_trigger(failures: Array[String]) -> void:
	_H.run_passive_row(&"vantage_striker", failures)
