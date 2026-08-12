class_name BeastDiveBomberScenarioTest
extends RefCounted

const _H := preload("res://tests/beast_rider_qa_harness.gd")

## Bible: Dive Bomber — moving 4+ tiles before attack grants ATK +2; [+] threshold 3.
## Globals: MovementSystem turn movement telemetry and CombatSystem damage bonus.
## Data/Sim delegate: tests/beast_rider_qa_harness.gd::run_passive_row

static func run_all(failures: Array[String]) -> void:
	_data_contract(failures)
	_sim_trigger(failures)

static func _data_contract(failures: Array[String]) -> void:
	_H.run_factory_matrix(failures)

static func _sim_trigger(failures: Array[String]) -> void:
	_H.run_passive_row(&"dive_bomber", failures)
