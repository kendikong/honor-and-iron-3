extends RefCounted
## Bible §12 passive: Automation — turrets gain ATK +1 and RANGE +1; [+] ATK +2.
## Globals: EngineerSystems + AbilitySystem.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"automation", failures)
