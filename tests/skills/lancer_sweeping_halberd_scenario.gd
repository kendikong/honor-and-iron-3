extends RefCounted

## Bible: lancer_sweeping_halberd — RANGE 2 | ARC | ATK 2; [+] extended sweep.
## Globals: GridSystem.get_affected_tiles ARC + Simulator execution.

const _H := preload("res://tests/lancer_qa_harness.gd")


static func run_all(failures: Array[String]) -> void:
	_H.run_single_active(&"lancer_sweeping_halberd", failures)
	_H.run_sweeping_halberd_footprint(failures)
