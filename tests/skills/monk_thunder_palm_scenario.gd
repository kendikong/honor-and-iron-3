extends RefCounted

## Bible: Thunder Palm — RANGE 1, MAG ATK 3; WATER/FROZEN chains 50%; [+] STAGGER.
## Globals: EffectType.DAMAGE, surface-chain modifier, ADD_STATUS STAGGER.
## Modules: M0 ON_ACTION magical DAMAGE range 1; [+] STAGGER layer.
## Planning tier: B
## Data/Sim delegate: tests/monk_qa_harness.gd::run_single_ability
const _H := preload("res://tests/monk_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"monk_thunder_palm", failures)
	_H.run_upgrade_sim_for(&"monk_thunder_palm", failures)
	_Planning.run_for_factory(failures, &"monk_thunder_palm")
