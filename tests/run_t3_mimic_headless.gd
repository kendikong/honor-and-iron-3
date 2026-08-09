extends Node

## Headless T3-mimic only: action_range_regression + planning_intent_contract_e2e.
## Not Tier 3 LIVE — fixture board, not TestBattle.

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	print("[SUITE] action_range_regression")
	ActionRangeRegressionTest.run_all(failures)
	print("[SUITE] intent_contract_e2e")
	PlanningIntentContractE2ETest.run_all(failures)
	if failures.is_empty():
		print("[PASS] T3 mimic headless (action_range + intent_contract)")
	else:
		for failure: String in failures:
			printerr("[FAIL] %s" % failure)
	get_tree().quit(0 if failures.is_empty() else 1)
