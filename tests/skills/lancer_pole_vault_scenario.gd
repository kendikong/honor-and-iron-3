extends RefCounted

## Bible: lancer_pole_vault — Lancer factory row via shared Simulator harness.
## Globals: AbilitySystem / Simulator (Rule A).

const _H := preload("res://tests/lancer_qa_harness.gd")


static func run_all(failures: Array[String]) -> void:
	_H.run_single_active(&"lancer_pole_vault", failures)
