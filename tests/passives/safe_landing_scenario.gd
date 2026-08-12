class_name BeastSafeLandingScenarioTest
extends RefCounted

const _H := preload("res://tests/beast_rider_qa_harness.gd")

## Bible: Safe Landing — landing takes 0 hazard damage and creates 3x3 PUSH 1; [+] PUSH 2.
## Globals: TerrainSystem landing lifecycle and PhysicsSystem shockwave.
## Data/Sim delegate: tests/beast_rider_qa_harness.gd::run_passive_row

static func run_all(failures: Array[String]) -> void:
	_data_contract(failures)
	_sim_trigger(failures)

static func _data_contract(failures: Array[String]) -> void:
	_H.run_factory_matrix(failures)

static func _sim_trigger(failures: Array[String]) -> void:
	_H.run_passive_row(&"safe_landing", failures)
