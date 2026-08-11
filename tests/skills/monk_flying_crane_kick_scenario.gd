extends RefCounted

## Bible: Flying Crane Kick — DASH 3, ATK 2; [+] hazard crossed absorbs its element.
## Globals: EffectType.DASH + shared movement collision pipeline.
## Modules: M0 DASH range 3 to empty tile with physical damage layer; [+] element absorption.
## Planning tier: B
## Data/Sim delegate: tests/monk_qa_harness.gd::run_single_ability
const _H := preload("res://tests/monk_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"monk_flying_crane_kick", failures)
	_H.run_upgrade_sim_for(&"monk_flying_crane_kick", failures)
