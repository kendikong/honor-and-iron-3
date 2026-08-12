extends RefCounted
## Bible §12 passive: Chain Reaction — Construct detonation triggers friendly explosives in RANGE 2; [+] RANGE 3.
## Globals: EngineerSystems detonation reaction.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"chain_reaction", failures)
