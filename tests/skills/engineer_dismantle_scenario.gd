extends RefCounted
## Bible §12: Dismantle — RANGE 1, ATK 3, target -25% DEF; [+] generate 1 Scrap on hit.
## Globals: AbilitySystem + CombatSystem + Simulator.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"engineer_dismantle", failures)
	_H.run_upgrade_for(&"engineer_dismantle", failures)
