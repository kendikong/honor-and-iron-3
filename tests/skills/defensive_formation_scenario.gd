class_name KnightDefensiveFormationScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Defensive Formation — AOE ally DEF + STURDY; [+] allies gain SHIELD 2.
## Globals: ADD_STATUS(STAT_BUFF_DEF), ADD_STATUS(STURDY); upgraded ARMOR_UP.


static func run_all(failures: Array[String]) -> void:
	_KnightQaHarness.run_active_smoke( 
		failures,
		&"knight_defensive_formation",
		"Defensive Formation",
		[],
		[GameEnums.StatusType.STAT_BUFF_DEF, GameEnums.StatusType.STURDY],
	)
	var form: AbilityData = _KnightQaHarness.factory_ability(&"knight_defensive_formation")
	_KnightQaHarness.assert_true(
		failures, "defensive_formation/upgrade/shield",
		_KnightQaHarness.ability_has_effect(form, GameEnums.EffectType.ARMOR_UP, true),
	)
