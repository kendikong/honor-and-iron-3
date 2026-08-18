class_name KnightDefensiveFormationScenarioTest
extends RefCounted

const _KnightQaHarness := preload("res://tests/knight_qa_harness.gd")

## Bible: Defensive Formation - RANGE 0 | AOE 3 | Allies in range +2 DEF and immune PUSH/PULL 1 turn. [+] Allies also gain SHIELD 2.
## Globals: ADD_STATUS(STAT_BUFF_DEF), ADD_STATUS(STURDY); upgraded ARMOR_UP via AbilitySystem.
## Planning tier: fixture (run_planning_qa_gate.ps1)


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_KnightQaHarness.run_defensive_formation(failures)


static func _sim_contract(failures: Array[String]) -> void:
	var form: AbilityData = _KnightQaHarness.factory_ability(&"knight_defensive_formation")
	_KnightQaHarness.assert_true(
		failures, "defensive_formation/contract/aoe",
		form != null and form.target_shape == GameEnums.TargetShape.AOE_DIAMOND
		and form.target_shape_size == 3,
	)
	_KnightQaHarness.assert_eq_int(
		failures, "defensive_formation/contract/range",
		form.range_tiles,
		0,
	)
	_KnightQaHarness.assert_true(
		failures, "defensive_formation/contract/def_buff",
		_KnightQaHarness.ability_has_status_effect(
			form, GameEnums.StatusType.STAT_BUFF_DEF, false,
		),
	)
	_KnightQaHarness.assert_true(
		failures, "defensive_formation/contract/sturdy",
		_KnightQaHarness.ability_has_status_effect(
			form, GameEnums.StatusType.STURDY, false,
		),
	)
	_KnightQaHarness.assert_eq_int(
		failures, "defensive_formation/contract/def_amount",
		_KnightQaHarness.compiled_effects(form)[0].amount,
		2,
	)
	_KnightQaHarness.assert_true(
		failures, "defensive_formation/contract/upgrade_shield",
		_KnightQaHarness.ability_has_effect(form, GameEnums.EffectType.ARMOR_UP, true),
	)
	for eff: EffectData in _KnightQaHarness.compiled_effects(form):
		if eff == null:
			continue
		if eff.type in [GameEnums.EffectType.ADD_STATUS, GameEnums.EffectType.ARMOR_UP]:
			_KnightQaHarness.assert_true(
				failures, "defensive_formation/contract/exclude_caster_base",
				eff.modifiers.get("exclude_caster", false),
				"base defensive formation buff effects must exclude caster",
			)
	for eff_up: EffectData in _KnightQaHarness.compiled_effects(form, true):
		if eff_up == null:
			continue
		if eff_up.type in [GameEnums.EffectType.ADD_STATUS, GameEnums.EffectType.ARMOR_UP]:
			_KnightQaHarness.assert_true(
				failures, "defensive_formation/contract/exclude_caster_upgrade",
				eff_up.modifiers.get("exclude_caster", false),
				"upgraded defensive formation buff effects must exclude caster",
			)
