class_name MomentumOfTitanScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Momentum of the Titan — PUSH collision +10% Max HP damage.
## [+] collision damage increases to 20% Max HP.
## Globals: PUSH wall collision bonus via concussion_blow harness path.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_momentum_of_titan(failures)

