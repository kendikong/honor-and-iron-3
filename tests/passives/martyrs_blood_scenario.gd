extends RefCounted

## Bible: martyrs_blood — Cleric promotion passive factory contract.
const _H := preload("res://tests/cleric_qa_harness.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_passive_row(&"martyrs_blood", failures)
