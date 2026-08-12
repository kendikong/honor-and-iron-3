extends RefCounted
## Bible: Board Scrambler - Rogue promotion passive, high-health damage swap.
## Globals: RogueSystems + AbilitySystem + Simulator
## Data/Sim delegate: tests/rogue_qa_harness.gd::_run_passive_trigger
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H._run_passive_trigger(&"board_scrambler", failures)
