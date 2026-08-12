extends RefCounted
## Bible: Blink Strike - Rogue promotion passive, basic attack range.
## Globals: RogueSystems + AbilitySystem + Simulator
## Data/Sim delegate: tests/rogue_qa_harness.gd::_run_passive_trigger
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H._run_passive_trigger(&"blink_strike", failures)
