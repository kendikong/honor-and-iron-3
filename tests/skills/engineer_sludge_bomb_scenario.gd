extends RefCounted
## Bible §12: Sludge Bomb — RANGE 3, AOE 3x3, ATK 1, create OIL; [+] ignite entire OIL area.
## Globals: AbilitySystem + GridSystem + TerrainSystem + Simulator.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"engineer_sludge_bomb", failures)
	_H.run_upgrade_for(&"engineer_sludge_bomb", failures)
