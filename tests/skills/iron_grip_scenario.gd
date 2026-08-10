class_name KnightIronGripScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Iron Grip - RANGE 1 ROOT + IRON_GRIP_DEBUFF (DEF halved next turn); [+] refund 1 AP when target already ROOT/STAGGER.
## Globals: ADD_STATUS(ROOT), ADD_STATUS(IRON_GRIP_DEBUFF); upgraded REFUND_AP_ON_CC via AbilitySystem.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_KnightQaHarness.run_iron_grip(failures)
	_KnightQaHarness.run_planning_commit_smoke(
		failures, &"knight_iron_grip", "iron_grip", Vector2i(5, 5),
		false, Vector2i(-1, -1), Vector2i(5, 5),
	)


static func _sim_contract(failures: Array[String]) -> void:
	var grip: AbilityData = _KnightQaHarness.factory_ability(&"knight_iron_grip")
	_KnightQaHarness.assert_true(
		failures, "iron_grip/contract/root",
		_KnightQaHarness.ability_has_status_effect(grip, GameEnums.StatusType.ROOT, false),
	)
	_KnightQaHarness.assert_true(
		failures, "iron_grip/contract/debuff",
		_KnightQaHarness.ability_has_status_effect(
			grip, GameEnums.StatusType.IRON_GRIP_DEBUFF, false,
		),
	)
	_KnightQaHarness.assert_true(
		failures, "iron_grip/contract/upgrade_refund",
		_KnightQaHarness.ability_has_effect(grip, GameEnums.EffectType.REFUND_AP_ON_CC, true),
	)
	_KnightQaHarness.assert_true(
		failures, "iron_grip/contract/range",
		grip != null and grip.range_tiles == 1,
		"iron grip must be RANGE 1",
	)
