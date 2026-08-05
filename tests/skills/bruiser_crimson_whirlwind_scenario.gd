class_name BruiserCrimsonWhirlwindScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Crimson Whirlwind — RANGE 0 | AOE 3x3 | ATK 1.
## [+] HEAL 1 for every target successfully hit.
## Globals: EffectType.DAMAGE + TargetShape.AOE_SQUARE; RANGE 0 ? SELF.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_crimson_whirlwind(failures)

