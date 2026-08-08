class_name ClericQaRunner
extends RefCounted

const _HARNESS := preload("res://tests/cleric_qa_harness.gd")

static func run_all(failures: Array[String]) -> void:
	_HARNESS.run_all(failures)
