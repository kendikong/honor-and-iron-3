extends RefCounted

## Bible: blood_donation — Cleric promotion passive factory contract.
const _H := preload("res://tests/cleric_qa_harness.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_passive_row(&"blood_donation", failures)
