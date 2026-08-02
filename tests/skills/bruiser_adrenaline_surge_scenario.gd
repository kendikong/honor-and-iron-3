class_name BruiserAdrenalineSurgeScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")

## Bible: Adrenaline Surge — SELF | spend 5 HP | +1 MOV +1 STR 1 turn; 0 AP if 2+ adjacent enemies.
## [+] on_kill_heal_shield — on kill HEAL 1 and SHIELD 2.
## Globals: DAMAGE_SELF + STAT_BUFF_STR/MOV self; zero_ap_adjacent_enemies / on_kill_heal_shield modifiers.


static func run_all(failures: Array[String]) -> void:
	_Scenarios.run_adrenaline_surge(failures)
