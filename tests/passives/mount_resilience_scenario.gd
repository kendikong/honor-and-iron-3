class_name BeastMountResilienceScenarioTest
extends RefCounted

const _H := preload("res://tests/beast_rider_qa_harness.gd")

## Bible: Mount Resilience — ranged damage reduced by Floor(DEF/2)+1; [+] +2 instead.
## Globals: CombatSystem incoming damage mitigation.
## Data/Sim delegate: tests/beast_rider_qa_harness.gd::run_passive_row

static func run_all(failures: Array[String]) -> void:
	_data_contract(failures)
	_sim_trigger(failures)

static func _data_contract(failures: Array[String]) -> void:
	_H.run_factory_matrix(failures)

static func _sim_trigger(failures: Array[String]) -> void:
	_H.run_passive_row(&"mount_resilience", failures)
