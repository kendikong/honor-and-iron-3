extends RefCounted
## Bible §12: Frag Bomb — RANGE 3, AOE 3x3, ATK 2, ignite OIL; [+] refund 1 AP on construct destruction.
## Globals: AbilitySystem + EngineerSystems + CombatSystem + Simulator.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"engineer_frag_bomb", failures)
	_H.run_upgrade_for(&"engineer_frag_bomb", failures)
