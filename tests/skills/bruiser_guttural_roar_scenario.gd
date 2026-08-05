class_name BruiserGutturalRoarScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Guttural Roar — RANGE 0 | AOE 2 | PUSH 1 | DEF -2.
## [+] PUSH items/coins/scrap; item collision ATK 1.
## Globals: EffectType.PUSH + STAT_DEBUFF_DEF; TargetShape.AOE_SQUARE; RANGE 0 ? SELF.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_guttural_roar(failures)

