class_name BatteringRamScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Battering Ram — PUSH pushes target 1 additional tile.
## [+] wall collision STAGGER on pushed enemies.
## Globals: extra PUSH distance on concussion_blow harness path.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_battering_ram(failures)

