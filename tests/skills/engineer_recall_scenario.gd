extends RefCounted
## Bible §12: Recall — 3 MOV teleport to empty tile adjacent to active Construct; [+] Overclock on arrival.
## Globals: EngineerSystems + MovementSystem + AbilitySystem + Simulator.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"engineer_recall", failures)
	_H.run_upgrade_for(&"engineer_recall", failures)
