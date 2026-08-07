class_name BruiserChargeStrikeScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Charge Strike — MOVE 2 | ATK 3 | PUSH 1; [+] GHOST during MOVE, ATK +2 through terrain.
## Globals: EffectType.MOVE + DAMAGE + PUSH; ghost_move / bonus_dmg_from_terrain modifiers on upgrade.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_charge_strike(failures)
