class_name AdrenalineJunkieScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Adrenaline Junkie — +MOV/+STR per 10% missing HP.
## [+] +DEF per 20% missing HP.
## Globals: missing-HP stat scaling via _recalculate_stats.


static func run_all(failures: Array[String]) -> void:
	_sim_trigger(failures)


static func _sim_trigger(failures: Array[String]) -> void:
		_Scenarios.run_adrenaline_junkie(failures)

