class_name KnightIndomitableWillScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Indomitable Will: SHIELD from missing HP
## Globals: ARMOR_UP, INDOMITABLE_WILL via AbilitySystem / EffectData


static func run_all(failures: Array[String]) -> void:
	_KnightQaHarness.run_indomitable_will(failures)

