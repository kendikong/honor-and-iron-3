class_name RallyingPresenceScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Adjacent allies +1 MOV at turn start; [+] +2 MOV.
## Globals: Simulator._tick_start_of_turn rallying_presence hook.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_KnightQaHarness.run_rallying_presence(failures)


static func _sim_contract(failures: Array[String]) -> void:
	var passive: PassiveData = _KnightQaHarness.factory_passive(&"rallying_presence")
	_KnightQaHarness.assert_true(
		failures, "rallying_presence/contract/passive",
		passive != null and passive.id == &"rallying_presence",
	)
	_KnightQaHarness.assert_true(
		failures, "rallying_presence/contract/description",
		passive != null and passive.description == "Allies starting turn adjacent gain +1 MOV.",
	)
	_KnightQaHarness.assert_true(
		failures, "rallying_presence/contract/upgrade_mov",
		passive != null and passive.upgraded_description == "[+] +2 MOV.",
	)
