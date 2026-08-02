class_name BruiserCleaveScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Cleave — RANGE 1 | ARC | ATK 2; [+] Apply BLEED X (WPN) to all targets.
## Globals: EffectType.DAMAGE + TargetShape.ARC; upgrade ADD_STATUS BLEED + weapon_scaled modifier.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_cleave(failures)

