class_name MomentumTransferScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Momentum Transfer — PUSH collision HEAL 1.
## [+] HEAL 1 and gain +1 STR.
## Globals: collision heal on PUSH via concussion_blow + battering_ram stack.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_momentum_transfer(failures)

