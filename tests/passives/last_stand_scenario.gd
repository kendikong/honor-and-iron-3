class_name LastStandScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Last Stand — HP < 25% grants +2 STR and +2 DEF.
## [+] grants +3 STR and +3 DEF instead.
## Globals: low-HP threshold stat buff via _recalculate_stats.


static func run_all(failures: Array[String]) -> void:
	_sim_trigger(failures)


static func _sim_trigger(failures: Array[String]) -> void:
		_Scenarios.run_last_stand(failures)

