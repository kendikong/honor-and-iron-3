extends RefCounted

## Bible: Vaulting Strike — vault over an enemy grants ATK +2 against them; [+] +3.
## Globals: shared vault motion and vaulted-target attack context.
## Data/Sim delegate: tests/monk_qa_harness.gd::run_passive_factory
const _H := preload("res://tests/monk_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"vaulting_strike", failures)
