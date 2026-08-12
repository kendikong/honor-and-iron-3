extends RefCounted
## Bible §12 passive: Shrapnel — detonations apply BLEED X (WPN) and PUSH 1; [+] BLIND.
## Globals: EngineerSystems + CombatSystem + PhysicsSystem.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"shrapnel", failures)
