class_name BeastFuriousChargeScenarioTest
extends RefCounted

const _H := preload("res://tests/beast_rider_qa_harness.gd")

## Bible: Furious Charge — straight 3+ tile move gives next attack PUSH 1; [+] PUSH 2.
## Globals: MovementSystem straight-path telemetry and PhysicsSystem push.
## Data/Sim delegate: tests/beast_rider_qa_harness.gd::run_passive_row

static func run_all(failures: Array[String]) -> void:
	_data_contract(failures)
	_sim_trigger(failures)

static func _data_contract(failures: Array[String]) -> void:
	_H.run_factory_matrix(failures)

static func _sim_trigger(failures: Array[String]) -> void:
	_H.run_passive_row(&"furious_charge", failures)
