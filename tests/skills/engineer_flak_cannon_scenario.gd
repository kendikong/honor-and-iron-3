extends RefCounted
## Bible §12: Flak Cannon — RANGE 1 ARC, ATK 2, PUSH 1; [+] consume Scrap for ATK +2 and BLEED X.
## Globals: AbilitySystem + GridSystem + PhysicsSystem + Simulator.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"engineer_flak_cannon", failures)
	_H.run_upgrade_for(&"engineer_flak_cannon", failures)
