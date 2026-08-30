extends RefCounted

const _HARNESS := preload("res://tests/archer_qa_harness.gd")

static func run_all(failures: Array[String]) -> void:
	_HARNESS.run_data_contract(failures)
	_HARNESS.run_shape_contract_smoke(failures)
	_HARNESS.run_active_execution_matrix(failures)
	_HARNESS.run_passive_runtime_smoke(failures)
