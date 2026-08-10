extends RefCounted

## Bible: lasting_terrain — Mage promotion passive factory + trigger contract.
const _H := preload("res://tests/mage_qa_harness.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"lasting_terrain", failures)
