extends RefCounted
## Bible §12 passive: Blast Shielding — immune to own explosion damage; [+] 3+ enemies grants 1 AP once/turn.
## Globals: EngineerSystems + CombatSystem.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"blast_shielding", failures)
