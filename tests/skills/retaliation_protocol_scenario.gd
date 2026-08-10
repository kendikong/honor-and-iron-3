class_name KnightRetaliationProtocolScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Retaliation Protocol: SELF counter stance
## Globals: RETALIATION_PROTOCOL via AbilitySystem / EffectData
## Planning tier: fixture (run_planning_qa_gate.ps1)


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)


static func _sim_contract(failures: Array[String]) -> void:
	_KnightQaHarness.run_retaliation_protocol(failures)
