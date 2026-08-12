class_name BeastBeastsInstinctScenarioTest
extends RefCounted

const _H := preload("res://tests/beast_rider_qa_harness.gd")

## Bible: Beast's Instinct — enemy miss or 0 damage grants STR +1 and AP +1; [+] SHIELD 1.
## Globals: CombatSystem zero-damage reaction lifecycle.
## Data/Sim delegate: tests/beast_rider_qa_harness.gd::run_passive_row

static func run_all(failures: Array[String]) -> void:
	_data_contract(failures)
	_sim_trigger(failures)

static func _data_contract(failures: Array[String]) -> void:
	_H.run_factory_matrix(failures)

static func _sim_trigger(failures: Array[String]) -> void:
	_H.run_passive_row(&"beasts_instinct", failures)
