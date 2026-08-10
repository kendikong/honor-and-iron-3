class_name KnightFortifyScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Fortify - ally DEF buff scaled by caster DEF; [+] THORNS 50%.
## Globals: ADD_STATUS(STAT_BUFF_DEF) via AbilitySystem.
## Planning tier: fixture (run_planning_qa_gate.ps1)


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)


static func _sim_contract(failures: Array[String]) -> void:
	_KnightQaHarness.run_fortify(failures)
