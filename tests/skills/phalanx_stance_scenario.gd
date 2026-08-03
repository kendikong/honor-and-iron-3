class_name KnightPhalanxStanceScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Phalanx Stance — SELF DEF +5 + STURDY until next turn; [+] RETALIATION_INFINITE_RANGE for Retaliation Protocol this turn.
## Globals: STURDY, STAT_BUFF_DEF, RETALIATION_INFINITE_RANGE, RETALIATION_PROTOCOL via AbilitySystem / CombatSystem


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_KnightQaHarness.run_phalanx_stance(failures)
	_KnightQaHarness.run_planning_commit_smoke(
		failures, &"knight_phalanx_stance", "phalanx", PlanningChecklistHarness.KNIGHT_START,
	)


static func _sim_contract(failures: Array[String]) -> void:
	var phalanx: AbilityData = _KnightQaHarness.factory_ability(&"knight_phalanx_stance")
	_KnightQaHarness.assert_true(
		failures, "phalanx/contract/sturdy",
		_KnightQaHarness.ability_has_status_effect(phalanx, GameEnums.StatusType.STURDY, false),
	)
	_KnightQaHarness.assert_true(
		failures, "phalanx/contract/def",
		_KnightQaHarness.ability_has_status_effect(phalanx, GameEnums.StatusType.STAT_BUFF_DEF, false),
	)
	_KnightQaHarness.assert_true(
		failures, "phalanx/contract/upgrade_infinite_range",
		_KnightQaHarness.ability_has_status_effect(
			phalanx, GameEnums.StatusType.RETALIATION_INFINITE_RANGE, true,
		),
	)

