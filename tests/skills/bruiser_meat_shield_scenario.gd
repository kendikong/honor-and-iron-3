class_name BruiserMeatShieldScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Meat Shield — RANGE 1 ally SWAP + INTERCEPT 50% this turn.
## [+] upgraded RANGE 3 + intercept_grant_str +2 per interception.
## Globals: EffectType.SWAP + ADD_STATUS_SELF INTERCEPT.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_meat_shield(failures)
