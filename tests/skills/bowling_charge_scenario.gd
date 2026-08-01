class_name KnightBowlingChargeScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Bowling Charge: DASH + BULLDOZE
## Globals: DASH, BULLDOZE via AbilitySystem / EffectData


static func run_all(failures: Array[String]) -> void:
	_KnightQaHarness.run_active_smoke( failures, &"knight_bowling_charge", "Bowling Charge", [GameEnums.EffectType.DASH, GameEnums.EffectType.BULLDOZE])

