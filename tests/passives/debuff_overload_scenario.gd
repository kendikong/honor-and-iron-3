extends RefCounted
## Bible: Debuff Overload — enemies take +1 unmitigated damage per unique debuff at Rogue turn start; [+] +2.
## Globals: `RogueSystems.turn_start` + `CombatSystem.deal_damage` (true damage).
## Data/Sim delegate: tests/rogue_qa_harness.gd::_run_passive_trigger
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"debuff_overload", failures)
