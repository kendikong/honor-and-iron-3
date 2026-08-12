extends RefCounted
## Bible §12 passive: Master Builder — +1 active Construct limit; [+] +2.
## Globals: EngineerSystems construct-limit owner.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"master_builder", failures)
