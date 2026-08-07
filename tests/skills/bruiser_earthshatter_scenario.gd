class_name BruiserEarthshatterScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Earthshatter — RANGE 1 | ARC | ATK 2 | destroy traps/cover in area.
## [+] buff_per_destroyed_object — +1 ATK per destroyed object.
## Globals: EffectType.DAMAGE + DESTROY_OBSTACLE + TargetShape.ARC.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_earthshatter(failures)
