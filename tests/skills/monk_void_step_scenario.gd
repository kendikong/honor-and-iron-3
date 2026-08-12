extends RefCounted

## Bible: Void Step — RANGE 3; teleport to an empty tile adjacent to an ally; [+] landed tile +2 MAG.
## Globals: TELEPORT_CASTER with ADJACENT_TO_TARGET and ally targeting.
## Modules: M0 teleport range 3 to ally; [+] landing stat modifier.
## Planning tier: B
## Data/Sim delegate: tests/monk_qa_harness.gd::run_single_ability
const _H := preload("res://tests/monk_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_factory_matrix(failures)
	_Planning.run_for_factory(failures, &"monk_void_step")
