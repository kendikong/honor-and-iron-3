class_name BeastIntimidatingPresenceScenarioTest
extends RefCounted

const _H := preload("res://tests/beast_rider_qa_harness.gd")

## Bible: Intimidating Presence — enemies in RANGE 2 suffer permanent -1 DEF and -1 MOVE; [+] RANGE 3.
## Globals: UnitState dynamic stat recalculation from aura-like passive data.
## Data/Sim delegate: tests/beast_rider_qa_harness.gd::run_passive_row

static func run_all(failures: Array[String]) -> void:
	_data_contract(failures)
	_sim_trigger(failures)

static func _data_contract(failures: Array[String]) -> void:
	_H.run_factory_matrix(failures)

static func _sim_trigger(failures: Array[String]) -> void:
	_H.run_passive_row(&"intimidating_presence", failures)
