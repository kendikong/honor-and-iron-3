extends RefCounted
## Bible §12 passive: Explosive Expert — explosives +1 damage to mechanicals and ignore DEF; [+] explosions ATK +2.
## Globals: AbilitySystem + CombatSystem.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"explosive_expert", failures)
