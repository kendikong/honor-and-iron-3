class_name ArcherSidestepScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/archer_qa_harness_scenarios.gd")

## Bible: Sidestep — MOVE 1 | ignore ZOC; [+] next ranged attack +1 STR.
## Globals: EffectType.MOVE PRE_MOVE planner; next_ranged_attack_strength on upgrade.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_sidestep(failures)
