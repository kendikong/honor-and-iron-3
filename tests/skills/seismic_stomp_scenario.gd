class_name KnightSeismicStompScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Seismic Stomp: AOE DAMAGE + PURGE
## Globals: DAMAGE, PURGE via AbilitySystem / EffectData


static func run_all(failures: Array[String]) -> void:
	_KnightQaHarness.run_seismic_stomp(failures)

