extends RefCounted
## Bible §12: Wrench Smack — RANGE 1 ATK 2; Construct target HEAL 2, cleanse debuffs, grant OVERCLOCK; [+] +1 STR.
## Globals: AbilitySystem + CombatSystem + EngineerSystems + Simulator.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"engineer_wrench_smack", failures)
	_H.run_upgrade_for(&"engineer_wrench_smack", failures)
