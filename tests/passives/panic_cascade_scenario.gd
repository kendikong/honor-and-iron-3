extends RefCounted
## Bible: Panic Cascade - Rogue promotion passive, damage per target status.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"panic_cascade", failures)
