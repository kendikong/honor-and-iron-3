class_name KnightShieldSlamScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Shield Slam: DAMAGE + PUSH
## Globals: DAMAGE, PUSH via AbilitySystem / EffectData


static func run_all(failures: Array[String]) -> void:
	_KnightQaHarness.run_active_smoke( failures, &"knight_shield_slam", "Shield Slam", [GameEnums.EffectType.DAMAGE, GameEnums.EffectType.PUSH])

