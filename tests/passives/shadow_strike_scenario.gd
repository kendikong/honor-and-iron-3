extends RefCounted
## Bible: Shadow Strike - Rogue promotion passive, teleport adjacency mark/root.
## Globals: RogueSystems + AbilitySystem + Simulator
## Data/Sim delegate: tests/rogue_qa_harness.gd::_run_passive_trigger
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H._run_passive_trigger(&"shadow_strike", failures)
