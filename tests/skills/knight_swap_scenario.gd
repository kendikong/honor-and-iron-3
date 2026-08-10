class_name KnightSwapScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Swap - exchange tiles with ally (movement skill); [+] +2 DEF and SHIELD 2 rest of turn.
## Globals: EffectType.SWAP (movement ability data); ARMOR_UP + STAT_BUFF_DEF on upgrade.
## Planning tier: fixture (run_planning_qa_gate.ps1 — swap journeys K1–K4)


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)


static func _sim_contract(failures: Array[String]) -> void:
	_KnightQaHarness.run_swap_base(failures)
	_KnightQaHarness.run_swap_upgrade(failures)
