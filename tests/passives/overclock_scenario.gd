extends RefCounted
## Bible §12 passive: Overclock — Constructs act twice/turn and take 1 damage/turn; [+] take 0 damage.
## Globals: EngineerSystems.player_phase_end + CombatSystem.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"overclock", failures)
