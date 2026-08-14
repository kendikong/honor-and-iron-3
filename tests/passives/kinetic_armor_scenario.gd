class_name KineticArmorScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Kinetic Armor — incoming damage reduced by Floor(DEF / 2) if SHIELD active; [+] Floor((DEF + 2) / 2).
## Globals: CombatSystem.deal_damage passive hook when target.armor > 0.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_KnightQaHarness.run_kinetic_armor(failures)


static func _sim_contract(failures: Array[String]) -> void:
	var passive: PassiveData = _KnightQaHarness.factory_passive(&"kinetic_armor")
	_KnightQaHarness.assert_true(
		failures, "kinetic_armor/contract/passive",
		passive != null and passive.id == &"kinetic_armor",
	)
	_KnightQaHarness.assert_true(
		failures, "kinetic_armor/contract/description",
		passive != null
		and passive.description == "Incoming damage reduced by Floor(DEF / 2) if SHIELD is active.",
	)
	_KnightQaHarness.assert_true(
		failures, "kinetic_armor/contract/upgrade_text",
		passive != null and passive.upgraded_description == "[+] Floor((DEF + 2) / 2).",
	)
