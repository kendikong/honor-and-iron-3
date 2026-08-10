extends RefCounted

## Bible: plunging_attack — Lancer passive trigger via Simulator (Rule A).
## Globals: PassiveData pipeline + shared combat resolution.

const _H := preload("res://tests/lancer_qa_harness.gd")


static func run_all(failures: Array[String]) -> void:
	_H.run_single_passive(&"plunging_attack", failures)
