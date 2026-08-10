extends RefCounted

## Bible: cleric_prayer_of_fortitude — Cleric ability factory + sim contract.
const _H := preload("res://tests/cleric_qa_harness.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_ability_row(&"cleric_prayer_of_fortitude", failures)
