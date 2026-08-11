class_name PlanningT3MimicRunner
extends RefCounted

const _JourneysTest := preload("res://tests/planning_t3_mimic_journeys_test.gd")
const _BibleFixtureTest := preload("res://tests/planning_bible_fixture_test.gd")


## Fixture Parity Suite (headless): action_range + intent_contract + journeys + bible session.
## Not Tier 3 LIVE — fixture board, not TestBattle.
static func run_all(failures: Array[String]) -> void:
	print("[SUITE] action_range_regression")
	ActionRangeRegressionTest.run_all(failures)
	print("[SUITE] intent_contract_e2e")
	PlanningIntentContractE2ETest.run_all(failures)
	print("[SUITE] t3_mimic_journeys")
	_JourneysTest.run_all(failures)
	print("[SUITE] bible_fixture")
	_BibleFixtureTest.run_all(failures)
