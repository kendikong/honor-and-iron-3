extends RefCounted
## Bible §12: Manual Detonation — RANGE 3, 0 AP, detonate friendly Construct/Mine for ATK 2 adjacent; [+] refund 1 Scrap.
## Globals: AbilitySystem + EngineerSystems + CombatSystem + Simulator.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"engineer_manual_detonation", failures)
	_H.run_upgrade_for(&"engineer_manual_detonation", failures)
