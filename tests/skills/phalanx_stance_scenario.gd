class_name KnightPhalanxStanceScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Phalanx Stance: SELF STURDY + DEF buff
## Globals: STURDY, STAT_BUFF_DEF via AbilitySystem / EffectData


static func run_all(failures: Array[String]) -> void:
	_KnightQaHarness.run_self_buff( failures, &"knight_phalanx_stance", GameEnums.StatusType.STURDY)

