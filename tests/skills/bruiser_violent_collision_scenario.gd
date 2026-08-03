class_name BruiserViolentCollisionScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Violent Collision — DASH 3 | bulldoze + recast MOVE 2 on enemy hit.
## [+] collisions apply STAGGER (1 turn).
## Globals: EffectType.DASH + bulldoze/violent_collision_recast modifiers.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_violent_collision(failures)

