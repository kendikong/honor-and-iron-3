class_name BloodForBloodScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Blood for Blood — if damaged last turn, attacks apply BLEED X (WPN).
## [+] attacks also gain ATK +1.
## Globals: damaged_last_turn passive flag + BLEED on attack.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_blood_for_blood(failures)

