class_name CellularRegenerationScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Cellular Regeneration — HEAL 1 if 1+ adjacent enemies at turn start.
## [+] also gain +1 STR if 2+ adjacent enemies.
## Globals: passive turn-start hook; adjacent enemy count scaling.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_cellular_regeneration(failures)

