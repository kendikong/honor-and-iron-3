class_name BruiserEarthshatterScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

## Planning tier: B

## Bible: Earthshatter — RANGE 1 | ARC | ATK 2 | destroy traps/cover in area.
## [+] buff_per_destroyed_object — +1 ATK per destroyed object.
## Globals: EffectType.DAMAGE + DESTROY_OBSTACLE + TargetShape.ARC.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"bruiser_earthshatter")


static func _sim_contract(failures: Array[String]) -> void:
		_Scenarios.run_earthshatter(failures)
