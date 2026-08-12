extends RefCounted
## Bible §12: Rocket Launcher — GLOBAL AOE 3x3 ATK 4, destroy cover/traps, exhaust next turn; [+] sacrifice Construct to fire instantly.
## Globals: AbilitySystem + EngineerSystems + CombatSystem + Simulator.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"engineer_rocket_launcher", failures)
	_H.run_upgrade_for(&"engineer_rocket_launcher", failures)
