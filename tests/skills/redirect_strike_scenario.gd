class_name KnightRedirectStrikeScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Redirect Strike: SELF INTERCEPT
## Globals: INTERCEPT via AbilitySystem / EffectData


static func run_all(failures: Array[String]) -> void:
	_KnightQaHarness.run_self_buff( failures, &"knight_redirect_strike", GameEnums.StatusType.INTERCEPT)

