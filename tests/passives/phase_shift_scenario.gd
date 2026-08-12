extends RefCounted
## Bible: Phase Shift - Rogue promotion passive, teleport stealth.
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"phase_shift", failures)
