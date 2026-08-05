class_name UnstoppableForceScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Unstoppable Force — immune STAGGER/ROOT; resist grants SHIELD 1.
## [+] resist grants SHIELD 2 instead.
## Globals: status_prevented_by_unstoppable_force + armor on resist.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_unstoppable_force(failures)

