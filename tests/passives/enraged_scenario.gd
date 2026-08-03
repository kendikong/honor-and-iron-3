class_name EnragedScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Enraged — +1 STR per unique debuff or hazard.
## [+] also +1 MOV per debuff/hazard.
## Globals: unique debuff/hazard count via CombatSystem stat hooks.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_enraged(failures)

