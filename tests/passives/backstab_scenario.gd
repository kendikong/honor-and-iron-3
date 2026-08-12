extends RefCounted
## Bible: Backstab — attacks from behind ignore target DEF; [+] extended range.
## Globals: `RogueSystems.apply_attack_ignore_def` + `backstab_ignore_def` modifier.
## Data/Sim delegate: tests/rogue_qa_harness.gd::_run_passive_trigger
const _H := preload("res://tests/rogue_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H._run_passive_trigger(&"backstab", failures)
