class_name BruiserViolentCollisionScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Violent Collision — DASH 3 | bulldoze + IF_COLLIDED gated follow-up (AP recast).
## [+] collisions apply STAGGER (1 turn).
## Globals: EffectType.DASH + bulldoze; ModuleGate.IF_COLLIDED (not anonymous stamp).


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_violent_collision(failures)

