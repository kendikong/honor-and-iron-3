extends RefCounted

## Bible: Light Step — ignore difficult terrain/traps; ending on trap disarms it; [+] SHIELD 1.
## Globals: shared movement terrain-cost and trap-resolution pipeline.
## Data/Sim delegate: tests/monk_qa_harness.gd::run_passive_factory
const _H := preload("res://tests/monk_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"light_step", failures)
