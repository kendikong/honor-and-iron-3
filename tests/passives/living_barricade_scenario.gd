class_name LivingBarricadeScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Allies behind immune to ranged; [+] allies behind +1 DEF.
## Globals: AbilitySystem._apply_effect_to_tile block + CombatSystem.get_dynamic_defense.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_KnightQaHarness.run_living_barricade(failures)


static func _sim_contract(failures: Array[String]) -> void:
	var passive: PassiveData = _KnightQaHarness.factory_passive(&"living_barricade")
	_KnightQaHarness.assert_true(
		failures, "living_barricade/contract/passive",
		passive != null and passive.id == &"living_barricade",
	)
	_KnightQaHarness.assert_true(
		failures, "living_barricade/contract/description",
		passive != null and passive.description == "Allies behind are immune to ranged attacks.",
	)
	_KnightQaHarness.assert_true(
		failures, "living_barricade/contract/upgrade_def",
		passive != null and passive.upgraded_description == "[+] Allies behind gain +1 DEF.",
	)
