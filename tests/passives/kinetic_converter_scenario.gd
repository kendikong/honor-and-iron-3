class_name KineticConverterScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: When hit gain STR/MOV next turn
## Globals: shared passive trigger pipeline (PassiveData on UnitState)


static func run_all(failures: Array[String]) -> void:
	_KnightQaHarness.assert_passive_registered( failures, &"kinetic_converter")

