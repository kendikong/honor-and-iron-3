extends RefCounted

## Bible: plunging_attack — Lancer factory row via shared Simulator harness.
## Globals: AbilitySystem / Simulator (Rule A).

const _H := preload("res://tests/lancer_qa_harness.gd")


static func run_all(failures: Array[String]) -> void:
	_H.run_passive_runtime_smoke(failures)
