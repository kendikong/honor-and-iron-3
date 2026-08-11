class_name KnightSeismicStompScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Seismic Stomp - RANGE 0 AOE 1 ATK 2 PURGE all enemies; [+] CRACKED terrain (MOVE cost ×2 via TerrainData.mp_cost_per_tile).
## Globals: EffectType.DAMAGE, PURGE, CHANGE_TERRAIN via AbilitySystem.
## Planning tier: fixture (run_planning_qa_gate.ps1)


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)


static func _sim_contract(failures: Array[String]) -> void:
	_KnightQaHarness.run_seismic_stomp(failures)
	var stomp: AbilityData = _KnightQaHarness.factory_ability(&"knight_seismic_stomp")
	_KnightQaHarness.assert_true(
		failures, "seismic/contract/damage",
		_KnightQaHarness.ability_has_effect(stomp, GameEnums.EffectType.DAMAGE, false),
	)
	_KnightQaHarness.assert_true(
		failures, "seismic/contract/damage_amount",
		stomp != null and stomp.effects[0].amount == 2,
		"seismic stomp base DAMAGE must be ATK 2",
	)
	_KnightQaHarness.assert_true(
		failures, "seismic/contract/purge",
		_KnightQaHarness.ability_has_effect(stomp, GameEnums.EffectType.PURGE, false),
	)
	_KnightQaHarness.assert_true(
		failures, "seismic/contract/aoe",
		stomp != null and stomp.target_shape == GameEnums.TargetShape.AOE_SQUARE
		and stomp.target_shape_size == 1,
		"seismic stomp must be AOE 1 (3x3 square size 1)",
	)
	_KnightQaHarness.assert_true(
		failures, "seismic/contract/range",
		stomp != null and stomp.range_tiles == 0,
		"seismic stomp must be RANGE 0",
	)
	_KnightQaHarness.assert_true(
		failures, "seismic/contract/upgrade_terrain",
		_KnightQaHarness.ability_has_effect(stomp, GameEnums.EffectType.CHANGE_TERRAIN, true),
	)
