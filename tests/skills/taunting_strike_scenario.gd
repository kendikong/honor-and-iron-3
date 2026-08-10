class_name KnightTauntingStrikeScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Taunting Strike - RANGE 2 ATK 1 PULL 1 TAUNT; [+] RANGE 3 AOE 3x3 PULL 2 all enemies.
## Globals: EffectType.DAMAGE, PULL, ADD_STATUS(TAUNT) via AbilitySystem.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_KnightQaHarness.run_taunting_strike(failures)
	_KnightQaHarness.run_planning_commit_smoke(
		failures, &"knight_taunting_strike", "taunting", PlanningChecklistHarness.ENEMY_POS,
	)


static func _sim_contract(failures: Array[String]) -> void:
	var strike: AbilityData = _KnightQaHarness.factory_ability(&"knight_taunting_strike")
	_KnightQaHarness.assert_true(
		failures, "taunting/contract/damage",
		_KnightQaHarness.ability_has_effect(strike, GameEnums.EffectType.DAMAGE, false),
	)
	_KnightQaHarness.assert_true(
		failures, "taunting/contract/damage_amount",
		strike != null and strike.effects[0].amount == 1,
		"taunting strike base DAMAGE must be ATK 1",
	)
	_KnightQaHarness.assert_true(
		failures, "taunting/contract/pull",
		_KnightQaHarness.ability_has_effect(strike, GameEnums.EffectType.PULL, false),
	)
	_KnightQaHarness.assert_true(
		failures, "taunting/contract/pull_amount",
		strike != null and strike.effects[1].amount == 1,
		"taunting strike base PULL must be 1",
	)
	_KnightQaHarness.assert_true(
		failures, "taunting/contract/taunt",
		_KnightQaHarness.ability_has_status_effect(strike, GameEnums.StatusType.TAUNT, false),
	)
	_KnightQaHarness.assert_true(
		failures, "taunting/contract/range",
		strike != null and strike.range_tiles == 2,
		"taunting strike must be RANGE 2",
	)
	_KnightQaHarness.assert_true(
		failures, "taunting/contract/upgrade_range",
		strike != null and strike.upgraded_modules[0].max_range == 3,
	)
	_KnightQaHarness.assert_true(
		failures, "taunting/contract/upgrade_aoe",
		strike != null
		and strike.upgraded_modules[0].target_shape == GameEnums.TargetShape.AOE_SQUARE
		and strike.upgraded_modules[0].target_shape_size == 1,
	)
	_KnightQaHarness.assert_true(
		failures, "taunting/contract/upgrade_pull2",
		strike != null and strike.upgraded_effects[1].amount == 2,
	)
