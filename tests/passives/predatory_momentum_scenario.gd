extends RefCounted
const _H := preload("res://tests/mercenary_qa_harness.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_passive_scenario(&"predatory_momentum", failures)
