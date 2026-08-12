extends RefCounted
## Bible: Shadow Clone - Rogue promotion passive, decoy/taunt on kill.
## Globals: RogueSystems + AbilitySystem + Simulator
## Data/Sim delegate: tests/rogue_qa_harness.gd::run_passive_factory
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"shadow_clone", failures)
