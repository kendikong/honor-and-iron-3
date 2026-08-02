class_name BruiserFrenzyScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Frenzy — RANGE 1 | ATK 1 (3 times).
## [+] frenzy_on_kill_ap — on kill gain 1 AP.
## Globals: triple EffectType.DAMAGE amount 1.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_frenzy(failures)
