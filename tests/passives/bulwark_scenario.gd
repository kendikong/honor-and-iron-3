class_name BulwarkScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: +1 DEF per adjacent unit; [+] +1 STR per adjacent enemy.
## Globals: CombatSystem.get_dynamic_defense / get_dynamic_strength.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_KnightQaHarness.run_bulwark(failures)


static func _sim_contract(failures: Array[String]) -> void:
	var passive: PassiveData = _KnightQaHarness.factory_passive(&"bulwark")
	_KnightQaHarness.assert_true(
		failures, "bulwark/contract/passive",
		passive != null and passive.id == &"bulwark",
	)
	_KnightQaHarness.assert_true(
		failures, "bulwark/contract/description",
		passive != null and passive.description == "Gain +1 DEF per adjacent unit.",
	)
	_KnightQaHarness.assert_true(
		failures, "bulwark/contract/upgrade_str",
		passive != null and passive.upgraded_description == "[+] Also +1 STR per adjacent enemy.",
	)
