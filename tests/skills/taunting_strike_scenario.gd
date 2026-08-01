class_name KnightTauntingStrikeScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Taunting Strike — DAMAGE + PULL + TAUNT; [+] AOE pull upgrade.
## Globals: DAMAGE, PULL, ADD_STATUS(TAUNT) via AbilitySystem.


static func run_all(failures: Array[String]) -> void:
	_KnightQaHarness.run_active_smoke( 
		failures,
		&"knight_taunting_strike",
		"Taunting Strike",
		[GameEnums.EffectType.DAMAGE, GameEnums.EffectType.PULL],
		[GameEnums.StatusType.TAUNT],
	)
