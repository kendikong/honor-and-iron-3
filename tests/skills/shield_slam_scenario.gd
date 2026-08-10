class_name KnightShieldSlamScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Shield Slam: DAMAGE + PUSH
## Globals: DAMAGE, PUSH via AbilitySystem / EffectData
## Planning tier: fixture (run_planning_qa_gate.ps1)


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)


static func _sim_contract(failures: Array[String]) -> void:
	_KnightQaHarness.run_shield_slam(failures)
