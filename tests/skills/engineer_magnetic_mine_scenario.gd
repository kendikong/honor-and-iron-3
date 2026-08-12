extends RefCounted
## Bible §12: Magnetic Mine — RANGE 3, PULL 2 then ATK 2 explosion; [+] absorb items/Scrap.
## Globals: AbilitySystem + EngineerSystems + PhysicsSystem + Simulator.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"engineer_magnetic_mine", failures)
	_H.run_upgrade_for(&"engineer_magnetic_mine", failures)
