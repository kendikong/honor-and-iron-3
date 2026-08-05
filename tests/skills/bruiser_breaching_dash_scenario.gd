class_name BruiserBreachingDashScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Breaching Dash — DASH 3 | destroy destructible cover on path.
## [+] next attack this turn gains PIERCE.
## Globals: EffectType.DASH + DESTROY_OBSTACLE; DASH_LINE targeting.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_breaching_dash(failures)

