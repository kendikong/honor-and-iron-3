class_name BruiserConcussionBlowScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Concussion Blow — RANGE 1 | ATK 2 | PUSH 1 | object collision STAGGER.
## [+] enemy_collision_stagger_both — mutual STAGGER on enemy collision.
## Globals: EffectType.DAMAGE + PUSH; object_collision_stagger / enemy_collision_stagger_both modifiers.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_concussion_blow(failures)

