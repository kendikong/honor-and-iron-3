extends RefCounted
## Bible §12 passive: Field Technician — repair Constructs from RANGE 2 and grant +1 STR next attack; [+] +2 STR.
## Globals: EngineerSystems repair and next-attack state.
const _H := preload("res://tests/engineer_qa_harness.gd")
static func run_all(failures: Array[String]) -> void:
	_H.run_passive_factory(&"field_technician", failures)
