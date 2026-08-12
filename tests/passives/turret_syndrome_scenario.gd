extends RefCounted
## Bible §12 passive: Turret Syndrome — end turn without moving spawns mini-turret at Floor(25% Max HP); [+] +50% Max HP.
## Globals: EngineerSystems + AbilitySystem + Simulator.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"turret_syndrome", failures)
