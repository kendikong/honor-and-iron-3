extends RefCounted
## Bible §12: Scrap Shield — RANGE 2 consume Scrap; ally gains SHIELD 2x Scrap; [+] depletion explodes WPN/PUSH 1.
## Globals: AbilitySystem + CombatSystem + EngineerSystems + Simulator.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"engineer_scrap_shield", failures)
	_H.run_upgrade_for(&"engineer_scrap_shield", failures)
