extends RefCounted
## Bible §12 passive: Overclocked Maintenance — 1 MOV adjacent repairs 2, cleanses, grants SHIELD Floor(Max HP/10); [+] repairs 4.
## Globals: EngineerSystems + MovementSystem + CombatSystem.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"overclocked_maintenance", failures)
