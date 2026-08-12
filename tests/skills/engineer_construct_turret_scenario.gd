extends RefCounted
## Bible §12: Construct Turret — RANGE 2 summon Turret ATK 1/turn; [+] ATK 2 adjacent on death.
## Globals: AbilitySystem + EngineerSystems + CombatSystem + Simulator.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"engineer_construct_turret", failures)
	_H.run_upgrade_for(&"engineer_construct_turret", failures)
