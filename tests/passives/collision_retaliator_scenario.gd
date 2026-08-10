class_name CollisionRetaliatorScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Enemy collision into knight suffers retaliation damage
## Globals: shared passive trigger pipeline (PassiveData on UnitState)


static func run_all(failures: Array[String]) -> void:
	_sim_trigger(failures)


static func _sim_trigger(failures: Array[String]) -> void:
		_KnightQaHarness.run_collision_retaliator(failures)
		_KnightQaHarness.run_collision_retaliator_upgrade(failures)

