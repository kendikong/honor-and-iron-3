extends RefCounted

## Bible: cleric_holy_wrath — Cleric ability factory + sim contract.
const _H := preload("res://tests/cleric_qa_harness.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_ability_row(&"cleric_holy_wrath", failures)
