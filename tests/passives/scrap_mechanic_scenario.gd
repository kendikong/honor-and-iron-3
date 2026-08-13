extends RefCounted

const _H := preload("res://tests/engineer_qa_harness.gd")

## Bible §12: Scrap Mechanic — enemy death in RANGE 3 drops Scrap; [+] drops 2.
## Globals: EngineerSystems + AbilitySystem + CombatSystem + Simulator.
## Data/Sim delegate: tests/engineer_qa_harness.gd::run_passive_row

static func run_all(failures: Array[String]) -> void:
	_data_contract(failures)
	_sim_trigger(failures)

static func _data_contract(failures: Array[String]) -> void:
	_H.run_factory_matrix(failures)

static func _sim_trigger(failures: Array[String]) -> void:
	_H.run_passive_row(&"scrap_mechanic", failures)
