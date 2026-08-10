extends RefCounted

## Bible: selfless_siphon — HEAL split to self via Simulator.
const _H := preload("res://tests/cleric_qa_harness.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_selfless_siphon(failures)
