class_name BruiserCrimsonWhirlwindScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/harness/bruiser_qa_harness_scenarios.gd")
const _Planning := preload("res://tests/harness/class_scenario_planning_contract.gd")
const _H := preload("res://tests/harness/bruiser_qa_harness.gd")

## Planning tier: B

## Bible: Crimson Whirlwind - RANGE 0 | AOE 3x3 | ATK 1.
## [+] PER_TARGET_HIT HEAL layer — HEAL 1 per enemy hit (binding matrix).
## Globals: EffectType.DAMAGE + TargetShape.AOE_SQUARE; RANGE 0 ? SELF.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"bruiser_crimson_whirlwind")


static func _sim_contract(failures: Array[String]) -> void:
	_Scenarios.run_crimson_whirlwind(failures)
	_sim_upgrade(failures)


static func _sim_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = _H.factory_ability(&"bruiser_crimson_whirlwind")
	_H.assert_true(
		failures, "crimson_whirlwind/upgrade/per_target_heal_layer",
		LayerShapeConversionRules.module_has_layer_signature(
			ab.upgraded_modules[0],
			GameEnums.LayerCondition.PER_TARGET_HIT,
			GameEnums.EffectType.HEAL,
		),
	)
	_H.assert_true(
		failures, "crimson_whirlwind/upgrade/no_module_knob",
		not ab.upgraded_modules[0].is_typed_extra_property_set("heal_if_targets_gte"),
	)
	var cfg: Dictionary = _H.with_upgraded_ability(
		_H.bruiser_with_ability(&"bruiser_crimson_whirlwind"),
		&"bruiser_crimson_whirlwind",
	)
	var board: BoardState = _H.make_plain_board(Vector2i(8, 8))
	_H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	var bruiser: UnitState = _H.unit_on_board(board, 1)
	bruiser.active_passives.clear()
	bruiser.health.current_hp = bruiser.health.max_hp - 3
	var hp: int = bruiser.health.current_hp
	_H.place_dummy(board, 2, Vector2i(4, 3))
	_H.place_dummy(board, 3, Vector2i(3, 4))
	_H.place_dummy(board, 4, Vector2i(2, 3))
	var skill: AbilityData = _H.ability_on_unit(bruiser, &"bruiser_crimson_whirlwind")
	var plan := Timeline.new()
	plan.add(_H.plan_ability(1, skill, Vector2i(3, 3), 1))
	var result: SimResult = _H.simulate_plan(board, plan)
	var heal_gain: int = _H.unit_hp(result.final_state, 1) - hp
	_H.assert_eq_int(
		failures, "crimson_whirlwind/upgrade/heal_per_hit",
		heal_gain,
		3,
	)
