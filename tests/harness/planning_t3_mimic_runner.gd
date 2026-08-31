class_name PlanningT3MimicRunner
extends RefCounted

## RefCounted harness — do NOT run with --script.
## Headless CLI: godot --headless --path . --script res://tests/runners/run_t3_mimic_headless.gd

const _IntentSot := preload("res://tests/harness/intent_source_of_truth_gate_test.gd")

## Fixture Parity Suite (headless): action_range + intent_contract + full T3 live checklist.
## Not Tier 3 LIVE — fixture board, not TestBattle.
static func run_all(failures: Array[String]) -> void:
	print("[SUITE] action_range_regression")
	ActionRangeRegressionTest.run_all(failures)
	print("[SUITE] intent_contract_e2e")
	PlanningIntentContractE2ETest.run_all(failures)
	var intent_failures: Array[String] = []
	print("[SUITE] intent_source_of_truth")
	_IntentSot.run_all(intent_failures)
	failures.append_array(intent_failures)
	var checklist_failures: Array[String] = []
	print("[SUITE] t3_live_headless_checklist")
	PlanningT3LiveHeadlessChecklistTest.run_all(checklist_failures)
	failures.append_array(checklist_failures)
