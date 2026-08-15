class_name BruiserChargeStrikeScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")
const _Planning := preload("res://tests/class_scenario_planning_contract.gd")
const _Upgrades := preload("res://tests/class_scenario_upgrade_registry.gd")

## Bible: Charge Strike - MOVE 2 | ATK 3 | PUSH 1; [+] GHOST during MOVE, ATK +2 through an occupied tile.
## Globals: EffectType.MOVE + DAMAGE + PUSH; ghost_move / bonus_dmg_from_occupied modifiers on upgrade.
## Modules: M0 MOVE (own aim) + M1 DAMAGE (own aim) + PUSH layer on DAMAGE (see bruiser_factory)
## Planning tier: B
## Data/Sim delegate: tests/bruiser_qa_harness_scenarios.gd::run_charge_strike


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"bruiser_charge_strike")


static func _sim_contract(failures: Array[String]) -> void:
		_Scenarios.run_charge_strike(failures)
		_run_postmove_planning_contract(failures)
		_sim_upgrade(failures)


static func _sim_upgrade(failures: Array[String]) -> void:
	_Upgrades.run_for_factory(failures, &"bruiser_charge_strike")


static func _run_postmove_planning_contract(failures: Array[String]) -> void:
	const TAG := "charge_strike/postmove"
	const _Lib := preload("res://tests/movement_planning_smoke_lib.gd")
	_Lib.run_awaiting_smoke(
		failures,
		&"bruiser",
		&"bruiser_charge_strike",
		TAG,
		Vector2i(1, 3),
		Vector2i(2, 3),
		Vector2i(3, 3),
		Vector2i(3, 3),
		false,
		Vector2i(-999999, -999999),
		[],
		[],
		"charge_strike",
		Vector2i(-1, -1),
		false,
		Vector2i(1, 3),
		false,
	)
