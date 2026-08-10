class_name KnightIndomitableWillScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Indomitable Will - SELF | Convert all missing HP into SHIELD for 2 turns. [+] When SHIELD expires, gain +2 STR.
## Globals: ARMOR_UP(MISSING_HP scaling) + INDOMITABLE_WILL status via AbilitySystem; expiry in Simulator._tick_statuses; shield-break in CombatSystem.deal_damage.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_KnightQaHarness.run_indomitable_will(failures)
	_KnightQaHarness.run_planning_commit_smoke(
		failures, &"knight_indomitable_will", "indomitable", PlanningChecklistHarness.KNIGHT_START,
	)


static func _sim_contract(failures: Array[String]) -> void:
	var indo: AbilityData = _KnightQaHarness.factory_ability(&"knight_indomitable_will")
	_KnightQaHarness.assert_true(
		failures, "indomitable/contract/self_target",
		indo != null and indo.can_target_self
		and indo.targeting_mode == GameEnums.TargetingMode.SELF,
	)
	_KnightQaHarness.assert_true(
		failures, "indomitable/contract/armor_up",
		_KnightQaHarness.ability_has_effect(indo, GameEnums.EffectType.ARMOR_UP, false),
	)
	_KnightQaHarness.assert_true(
		failures, "indomitable/contract/missing_hp_scaling",
		indo != null and indo.effects[0].scaling_stat == GameEnums.StatType.MISSING_HP,
	)
	_KnightQaHarness.assert_true(
		failures, "indomitable/contract/status",
		_KnightQaHarness.ability_has_status_effect(
			indo, GameEnums.StatusType.INDOMITABLE_WILL, false,
		),
	)
	_KnightQaHarness.assert_true(
		failures, "indomitable/contract/upgrade_status",
		indo != null and indo.upgraded_effects.size() > 0
		and indo.upgraded_effects[1].status_type == GameEnums.StatusType.INDOMITABLE_WILL_UPGRADED,
	)
