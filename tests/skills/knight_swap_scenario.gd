class_name KnightSwapScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Swap — exchange tiles with ally (movement skill); [+] +2 DEF and SHIELD 2 rest of turn.
## Globals: EffectType.SWAP (movement ability data); ARMOR_UP + STAT_BUFF_DEF on upgrade.


static func run_all(failures: Array[String]) -> void:
	_KnightQaHarness.run_swap_base( failures)
	_KnightQaHarness.run_swap_upgrade( failures)
	_KnightQaHarness.run_planning_commit_smoke(
		failures, &"knight_swap", "swap", Vector2i(4, 4), true, Vector2i(4, 4),
		Vector2i(-999999, -999999), false,
	)
