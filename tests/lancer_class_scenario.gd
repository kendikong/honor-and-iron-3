extends RefCounted

const _HARNESS := preload("res://tests/lancer_qa_harness.gd")

static func run_all(failures: Array[String]) -> void:
	_HARNESS.run_data_contract(failures)
	_HARNESS.run_push_smoke(failures)

