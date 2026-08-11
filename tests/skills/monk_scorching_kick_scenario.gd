extends RefCounted

## Bible: Scorching Kick — RANGE 1, ATK 2, target tile becomes FIRE; [+] burning target gets MAG ATK 2 splash.
## Globals: EffectType.DAMAGE + CREATE_HAZARD and elemental-surface modifiers.
## Modules: M0 ON_ACTION DAMAGE range 1; layer CREATE_HAZARD FIRE; [+] burning splash.
## Planning tier: B
## Data/Sim delegate: tests/monk_qa_harness.gd::run_single_ability
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")
const _H := preload("res://tests/monk_qa_harness.gd")

static func run_all(failures: Array[String]) -> void:
	_H.run_single_ability(&"monk_scorching_kick", failures)
	_H.run_upgrade_sim_for(&"monk_scorching_kick", failures)
	_Planning.run_for_factory(failures, &"monk_scorching_kick")
