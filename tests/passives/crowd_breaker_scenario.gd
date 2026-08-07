class_name CrowdBreakerScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Crowd Breaker — +1 STR per adjacent enemy; splash ATK 1.
## [+] splash damage ATK 2.
## Globals: adjacent-enemy STR + splash damage on ability hits.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_crowd_breaker(failures)

