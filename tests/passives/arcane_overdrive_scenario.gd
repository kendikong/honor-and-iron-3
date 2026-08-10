extends RefCounted

## Bible: arcane_overdrive — Mage promotion passive factory + trigger contract.
const _H := preload("res://tests/mage_qa_harness.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"arcane_overdrive", failures)
