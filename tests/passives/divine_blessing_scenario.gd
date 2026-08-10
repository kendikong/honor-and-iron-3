extends RefCounted

## Bible: divine_blessing — Cleric promotion passive factory contract.
const _H := preload("res://tests/cleric_qa_harness.gd")

static func run_all(failures: Array[String]) -> void:
	_sim_trigger(failures)


static func _sim_trigger(failures: Array[String]) -> void:
		_H.run_passive_row(&"divine_blessing", failures)
