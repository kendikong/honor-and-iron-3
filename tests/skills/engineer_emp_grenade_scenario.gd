extends RefCounted
## Bible §12: EMP Grenade — RANGE 4 AOE 2x2, purge buffs, SILENCE, destroy standard constructs; [+] heal 10 and Overclock allies.
## Globals: AbilitySystem + CombatSystem + EngineerSystems + Simulator.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"engineer_emp_grenade", failures)
	_H.run_upgrade_for(&"engineer_emp_grenade", failures)
