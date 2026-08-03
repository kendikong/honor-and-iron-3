class_name ShieldWallScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Adjacent allies +1 DEF + PULL immune; [+] aura range 2.
## Globals: CombatSystem.get_dynamic_defense shield_wall aura.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_KnightQaHarness.run_shield_wall(failures)


static func _sim_contract(failures: Array[String]) -> void:
	var passive: PassiveData = _KnightQaHarness.factory_passive(&"shield_wall")
	_KnightQaHarness.assert_true(
		failures, "shield_wall/contract/passive",
		passive != null and passive.id == &"shield_wall",
	)
	_KnightQaHarness.assert_true(
		failures, "shield_wall/contract/description",
		passive != null
		and passive.description == "Adjacent allies gain +1 DEF and PULL immunity.",
	)
	_KnightQaHarness.assert_true(
		failures, "shield_wall/contract/upgrade_range",
		passive != null and passive.upgraded_description == "[+] Range of aura = 2 tiles.",
	)
