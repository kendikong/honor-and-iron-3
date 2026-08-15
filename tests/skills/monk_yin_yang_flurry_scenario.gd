extends RefCounted

## Bible: Yin-Yang Flurry — RANGE 1, ATK 1 then MAG ATK 1; [+] second hit gets PIERCE if first deals 0.
## Globals: ordered AbilityModule resolution; same-target extras are layers.
## Modules: M0 physical DAMAGE + MAGICAL DAMAGE layer; [+] conditional PIERCE on that layer.
## Planning tier: B
## Data/Sim delegate: tests/monk_qa_harness.gd::run_single_ability
const _H := preload("res://tests/monk_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"monk_yin_yang_flurry", failures)
	_H.run_upgrade_sim_for(&"monk_yin_yang_flurry", failures)
	_Planning.run_for_factory(failures, &"monk_yin_yang_flurry")
