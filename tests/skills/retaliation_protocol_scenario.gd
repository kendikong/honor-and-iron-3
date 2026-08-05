class_name KnightRetaliationProtocolScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Retaliation Protocol: SELF counter stance
## Globals: RETALIATION_PROTOCOL via AbilitySystem / AbilityModule


static func run_all(failures: Array[String]) -> void:
	_KnightQaHarness.run_retaliation_protocol(failures)
	_KnightQaHarness.run_planning_commit_smoke(
		failures, &"knight_retaliation_protocol", "retaliation", PlanningChecklistHarness.KNIGHT_START,
	)

