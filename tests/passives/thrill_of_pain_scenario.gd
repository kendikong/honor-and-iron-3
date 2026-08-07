class_name ThrillOfPainScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Thrill of Pain — on damage, next attack ATK +2 and PUSH 1.
## [+] next attack ATK +3 instead.
## Globals: thrill_active passive flag + deal_damage_raw bonus path.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_thrill_of_pain(failures)

