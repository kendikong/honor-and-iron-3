class_name BeastGoreScenarioTest
extends RefCounted

const _H := preload("res://tests/beast_rider_qa_harness.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")

## Bible: Gore — RANGE 1 | ATK 2 | PUSH 1. BLEED → ATK +2; [+] VULNERABLE.
## Globals: AbilitySystem damage + PUSH layers; MercenarySystems.adjust_attack_base
## consumes bleed_bonus_damage for every class.
## Data/Sim delegate: tests/beast_rider_qa_harness.gd::run_ability_row

static func run_all(failures: Array[String]) -> void:
	_data_contract(failures)
	_sim_contract(failures)
	_sim_upgrade(failures)
	_H.run_gore_bible_proof(failures)
	_Planning.run_for_factory(failures, &"beast_gore")

static func _data_contract(failures: Array[String]) -> void:
	_H.run_factory_matrix(failures)

static func _sim_contract(failures: Array[String]) -> void:
	_H.run_ability_row(&"beast_gore", failures)

static func _sim_upgrade(failures: Array[String]) -> void:
	_H.run_ability_upgrade_row(&"beast_gore", failures)
