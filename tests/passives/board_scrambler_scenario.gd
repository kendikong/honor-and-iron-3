extends RefCounted
## Bible: board_scrambler - Rogue passive via RogueSystems hooks in harness.
## Globals: RogueSystems + AbilitySystem + Simulator
## Data/Sim delegate: tests/rogue_qa_harness.gd::run_passive_factory
const _H := preload("res://tests/rogue_qa_harness.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"board_scrambler", failures)
