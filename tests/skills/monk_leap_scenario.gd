extends RefCounted

## Bible: Leap — cost 2 MOV; vault over one obstacle, gap, trap, or unit to the empty tile behind it.
## Globals: EffectType.TELEPORT_CASTER + MotionMode.VAULT_OVER; preview/commit slots.
## Modules: M0 ON_ACTION TELEPORT_CASTER range 1; [+] max range 3 and elemental landing absorption.
## Planning tier: B
## Data/Sim delegate: tests/monk_qa_harness.gd::run_single_ability
const _H := preload("res://tests/monk_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_factory_matrix(failures)
	_H.run_upgrade_sim_for(&"monk_leap", failures)
	_Planning.run_for_factory(failures, &"monk_leap")
