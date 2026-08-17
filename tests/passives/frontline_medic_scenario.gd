extends RefCounted

## Bible: frontline_medic — Cleric promotion passive factory contract.
const _H := preload("res://tests/cleric_qa_harness.gd")

static func run_all(failures: Array[String]) -> void:
	_sim_trigger(failures)


static func _sim_trigger(failures: Array[String]) -> void:
	_H.run_frontline_medic_proof(failures)
