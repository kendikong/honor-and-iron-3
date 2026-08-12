extends RefCounted
## Bible §12: Tesla Barricade — RANGE 1 build wall at Floor(150% caster Max HP); [+] manual detonation STAGGER.
## Globals: AbilitySystem + EngineerSystems + Simulator.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"engineer_tesla_barricade", failures)
	_H.run_upgrade_for(&"engineer_tesla_barricade", failures)
