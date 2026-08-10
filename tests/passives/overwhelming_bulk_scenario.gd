class_name OverwhelmingBulkScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Overwhelming Bulk — Current HP > target Max HP grants PIERCE.
## [+] attacks also apply PUSH 1.
## Globals: PIERCE flag on AbilitySystem DAMAGE path; events_have_damage_pierce.


static func run_all(failures: Array[String]) -> void:
	_sim_trigger(failures)


static func _sim_trigger(failures: Array[String]) -> void:
		_Scenarios.run_overwhelming_bulk(failures)

