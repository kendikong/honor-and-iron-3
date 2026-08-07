class_name ColossalMassScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Colossal Mass — +1 STR per 15 Max HP.
## [+] +1 STR per 10 Max HP instead.
## Globals: Max-HP-scaled STR via CombatSystem.get_dynamic_strength.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_colossal_mass(failures)

