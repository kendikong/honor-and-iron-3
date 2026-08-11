extends RefCounted

## Bible: Flowing Ki — moving through/jumping over enemy grants MAG; [+] also STR.
## Globals: shared motion-path enemy crossing trigger and turn stats.
## Data/Sim delegate: tests/monk_qa_harness.gd::run_passive_factory
const _H := preload("res://tests/monk_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"flowing_ki", failures)
