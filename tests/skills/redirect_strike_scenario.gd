class_name KnightRedirectStrikeScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Redirect Strike â€” SELF INTERCEPT (50% adjacent-ally damage, rounded down); [+] DEF +2 per redirected hit.
## Globals: ADD_STATUS_SELF(INTERCEPT) via AbilitySystem; split in CombatSystem.deal_damage.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_KnightQaHarness.run_redirect_strike(failures)
	_KnightQaHarness.run_planning_commit_smoke(
		failures, &"knight_redirect_strike", "redirect", PlanningChecklistHarness.KNIGHT_START,
	)


static func _sim_contract(failures: Array[String]) -> void:
	var redirect: AbilityData = _KnightQaHarness.factory_ability(&"knight_redirect_strike")
	_KnightQaHarness.assert_true(
		failures, "redirect/contract/intercept",
		_KnightQaHarness.ability_has_status_effect(
			redirect, GameEnums.StatusType.INTERCEPT, true,
		),
	)
	_KnightQaHarness.assert_true(
		failures, "redirect/contract/self_target",
		redirect != null and redirect.can_target_self
		and redirect.targeting_mode == GameEnums.TargetingMode.SELF,
	)
	_KnightQaHarness.assert_true(
		failures, "redirect/contract/range",
		redirect != null and redirect.range_tiles == 2,
		"redirect strike must be RANGE 2 per Bible",
	)
	_KnightQaHarness.assert_eq_int(
		failures, "redirect/contract/library_range_parity",
		redirect.range_tiles,
		_KnightQaHarness.library_ability_range_tiles(&"knight_redirect_strike"),
	)
	_KnightQaHarness.assert_true(
		failures, "redirect/contract/upgrade_intercept_value",
		redirect != null and redirect.upgraded_modules[0].amount == 1,
		"upgraded INTERCEPT effect amount must be 1 for [+] DEF tracking",
	)
