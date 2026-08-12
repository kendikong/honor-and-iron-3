extends RefCounted
## Bible: Miasma Spreader - Rogue promotion passive, spread debuffs on attack.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"miasma_spreader", failures)
