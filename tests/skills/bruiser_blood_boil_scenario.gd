class_name BruiserBloodBoilScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Blood Boil — SELF | spend 5 HP for STR +3 (1 turn).
## [+] spend 10 HP for STR +5 instead.
## Globals: EffectType.DAMAGE_SELF + ADD_STATUS_SELF STAT_BUFF_STR.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_blood_boil(failures)

