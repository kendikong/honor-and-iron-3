extends Node

const _JourneysTest := preload("res://tests/planning_t3_mimic_journeys_test.gd")
const _BibleFixtureTest := preload("res://tests/planning_bible_fixture_test.gd")

## Fixture Parity Suite (headless): action_range + intent_contract + journeys + bible session.
## Not Tier 3 LIVE — fixture board, not TestBattle.

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	print("[SUITE] action_range_regression")
	ActionRangeRegressionTest.run_all(failures)
	print("[SUITE] intent_contract_e2e")
	PlanningIntentContractE2ETest.run_all(failures)
	print("[SUITE] t3_mimic_journeys")
	_JourneysTest.run_all(failures)
	print("[SUITE] bible_fixture")
	_BibleFixtureTest.run_all(failures)
	if failures.is_empty():
		print("[PASS] Fixture Parity Suite (action_range + intent + journeys + bible)")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	get_tree().quit(0 if failures.is_empty() else 1)
