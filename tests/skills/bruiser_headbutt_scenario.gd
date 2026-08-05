class_name BruiserHeadbuttScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Headbutt — RANGE 1 | ATK 3 | mutual 1 dmg + STAGGER.
## [+] bonus damage = Round Down(10% Max HP).
## Globals: EffectType.DAMAGE + DAMAGE_SELF + STAGGER on target and caster.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_headbutt(failures)

