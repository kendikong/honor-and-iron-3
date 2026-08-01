class_name InterceptTacticsScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Redirect skill grants +DEF
## Globals: shared passive trigger pipeline (PassiveData on UnitState)


static func run_all(failures: Array[String]) -> void:
	_KnightQaHarness.assert_passive_registered( failures, &"intercept_tactics")

