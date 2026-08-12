extends RefCounted
## Bible §12: Overdrive Injection — RANGE 1, Construct +2 STR and OVERCLOCK, caster suffers 2 unmitigated damage; [+] refund Scrap on death.
## Globals: AbilitySystem + CombatSystem + EngineerSystems + Simulator.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"engineer_overdrive_injection", failures)
	_H.run_upgrade_for(&"engineer_overdrive_injection", failures)
