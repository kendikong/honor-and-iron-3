class_name BruiserBellyFlopScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Belly Flop — RANGE 2 | ATK 2 | jump to empty tile.
## [+] landing PUSH 1 to all adjacent enemies.
## Globals: EffectType.TELEPORT_CASTER + DAMAGE; damage_adjacent_on_landing modifier.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_belly_flop(failures)

