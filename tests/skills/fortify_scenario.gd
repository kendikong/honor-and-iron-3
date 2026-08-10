class_name KnightFortifyScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Fortify - ally DEF buff scaled by caster DEF; [+] THORNS 50%.
## Globals: ADD_STATUS(STAT_BUFF_DEF) via AbilitySystem.


static func run_all(failures: Array[String]) -> void:
	_KnightQaHarness.run_fortify(failures)
	_KnightQaHarness.run_planning_commit_smoke(
		failures, &"knight_fortify", "fortify", Vector2i(4, 4), true, Vector2i(4, 4),
	)
