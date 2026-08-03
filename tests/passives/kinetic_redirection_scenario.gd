class_name KineticRedirectionScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Mitigated DEF/SHIELD damage stacks +1 STR (max 3) for next attack; resets on attack; [+] PIERCE.
## Globals: CombatSystem.deal_damage stack + AbilitySystem attack reset / pierce hook.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_KnightQaHarness.run_kinetic_redirection(failures)


static func _sim_contract(failures: Array[String]) -> void:
	var passive: PassiveData = _KnightQaHarness.factory_passive(&"kinetic_redirection")
	_KnightQaHarness.assert_true(
		failures, "kinetic_redirection/contract/passive",
		passive != null and passive.id == &"kinetic_redirection",
	)
	_KnightQaHarness.assert_true(
		failures, "kinetic_redirection/contract/description",
		passive != null
		and passive.description == "Mitigating damage adds +1 STR to next attack (Stacks to +3).",
	)
	_KnightQaHarness.assert_true(
		failures, "kinetic_redirection/contract/upgrade_pierce",
		passive != null and passive.upgraded_description == "[+] Next attack gains PIERCE.",
	)
