class_name PlanningT3MimicRunner
extends RefCounted

const _Checklist := preload("res://tests/planning_t3_live_headless_checklist_test.gd")

## Fixture Parity Suite (headless): action_range + intent_contract + full T3 live checklist.
## Not Tier 3 LIVE — fixture board, not TestBattle.
static func run_all(failures: Array[String]) -> void:
	print("[SUITE] action_range_regression")
	ActionRangeRegressionTest.run_all(failures)
	print("[SUITE] intent_contract_e2e")
	PlanningIntentContractE2ETest.run_all(failures)
	print("[SUITE] t3_live_headless_checklist")
	_Checklist.run_all(failures)
