extends RefCounted
## Bible §12 passive: Shield Generator — allies adjacent to turrets +1 DEF; [+] PULL immunity.
## Globals: EngineerSystems + CombatSystem.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"shield_generator", failures)
