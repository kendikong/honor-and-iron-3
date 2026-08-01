class_name KnightIronGripScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Iron Grip — ROOT + IRON_GRIP_DEBUFF; [+] refund AP on ROOT/STAGGER target.
## Globals: ADD_STATUS(ROOT), ADD_STATUS(IRON_GRIP_DEBUFF); upgraded REFUND_AP_ON_CC.


static func run_all(failures: Array[String]) -> void:
	_KnightQaHarness.run_active_smoke( 
		failures,
		&"knight_iron_grip",
		"Iron Grip",
		[],
		[GameEnums.StatusType.ROOT, GameEnums.StatusType.IRON_GRIP_DEBUFF],
	)
	var grip: AbilityData = _KnightQaHarness.factory_ability(&"knight_iron_grip")
	_KnightQaHarness.assert_true(
		failures, "iron_grip/upgrade/refund",
		_KnightQaHarness.ability_has_effect(grip, GameEnums.EffectType.REFUND_AP_ON_CC, true),
	)
