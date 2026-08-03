class_name InterceptTacticsScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Redirect skill grants +2 DEF; [+] +3 DEF.
## Globals: AbilitySystem intercept_tactics hook on redirect skills.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_KnightQaHarness.run_intercept_tactics(failures)


static func _sim_contract(failures: Array[String]) -> void:
	var passive: PassiveData = _KnightQaHarness.factory_passive(&"intercept_tactics")
	_KnightQaHarness.assert_true(
		failures, "intercept_tactics/contract/passive",
		passive != null and passive.id == &"intercept_tactics",
	)
	_KnightQaHarness.assert_true(
		failures, "intercept_tactics/contract/description",
		passive != null and passive.description == "Using a redirect skill grants +2 DEF.",
	)
	_KnightQaHarness.assert_true(
		failures, "intercept_tactics/contract/upgrade_def",
		passive != null and passive.upgraded_description == "[+] +3 DEF.",
	)
