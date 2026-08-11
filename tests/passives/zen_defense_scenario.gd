extends RefCounted

## Bible: Zen Defense — +1 MAG per empty adjacent tile; four empty grants SHIELD 1; [+] SHIELD 2.
## Globals: shared occupancy-aware stat recalculation and shield state.
## Data/Sim delegate: tests/monk_qa_harness.gd::run_passive_factory
const _H := preload("res://tests/monk_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"zen_defense", failures)
