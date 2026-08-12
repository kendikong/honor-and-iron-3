extends RefCounted
## Bible §12: Barbed Wire — RANGE 3 ARC, create 3-tile wall with BLEED X and ROOT; [+] adjacent +1 DEF.
## Globals: AbilitySystem + GridSystem + TerrainSystem + Simulator.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"engineer_barbed_wire", failures)
	_H.run_upgrade_for(&"engineer_barbed_wire", failures)
