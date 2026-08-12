extends RefCounted
## Bible §12: Blueprint Tread — GHOST through friendly Constructs; adjacent end-turn repair; [+] pass-through SHIELD 1.
## Globals: EngineerSystems + MovementSystem + CombatSystem.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"blueprint_tread", failures)
