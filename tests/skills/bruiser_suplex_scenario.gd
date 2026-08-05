class_name BruiserSuplexScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Suplex — RANGE 1 | ATK 4 | THROW_BEHIND to empty tile behind caster.
## [+] bonus_dmg_per_10_hp — +1 ATK per 10 current HP. Rule B: THROW_BEHIND, not SWAP.
## Globals: EffectType.DAMAGE + THROW_BEHIND; upgrade bonus_dmg_per_10_hp modifier.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_suplex(failures)

