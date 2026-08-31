class_name BruiserFrenzyScenarioTest
extends RefCounted

const _Scenarios := preload("res://tests/harness/bruiser_qa_harness_scenarios.gd")
const _Planning := preload("res://tests/harness/class_scenario_planning_contract.gd")
const _H := preload("res://tests/harness/bruiser_qa_harness.gd")

## Planning tier: B

## Bible: Frenzy - RANGE 1 | ATK 1 (3 times).
## [+] ON_KILL GRANT_AP layer — on kill gain 1 AP via kill_grant_ap (single runtime owner).
## Globals: triple EffectType.DAMAGE amount 1.


static func run_all(failures: Array[String]) -> void:
	_sim_contract(failures)
	_Planning.run_for_factory(failures, &"bruiser_frenzy")


static func _sim_contract(failures: Array[String]) -> void:
	_Scenarios.run_frenzy(failures)
	_sim_upgrade(failures)


static func _sim_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = _H.factory_ability(&"bruiser_frenzy")
	_H.assert_true(
		failures, "frenzy/upgrade/on_kill_layer",
		LayerShapeConversionRules.module_has_layer_signature(
			ab.upgraded_modules[0],
			GameEnums.LayerCondition.ON_KILL,
			GameEnums.EffectType.GRANT_AP,
		),
		"[+] must author ON_KILL GRANT_AP layer, not frenzy_on_kill_ap module knob",
	)
	_H.assert_true(
		failures, "frenzy/upgrade/no_module_knob",
		not ab.upgraded_modules[0].is_typed_extra_property_set("frenzy_on_kill_ap"),
	)
	var cfg: Dictionary = _H.with_upgraded_ability(
		_H.bruiser_with_ability(&"bruiser_frenzy"),
		&"bruiser_frenzy",
	)
	cfg["passive_flags"] = {"training_unlimited_actions": true}
	var board: BoardState = _H.make_plain_board(Vector2i(8, 8))
	_H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	_H.place_dummy(board, 2, Vector2i(4, 3))
	var enemy: UnitState = _H.unit_on_board(board, 2)
	enemy.health.current_hp = 1
	var bruiser: UnitState = _H.unit_on_board(board, 1)
	bruiser.ability.max_points = 3
	bruiser.ability.points_left = 1
	var skill: AbilityData = _H.ability_on_unit(bruiser, &"bruiser_frenzy")
	var plan := Timeline.new()
	plan.add(_H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = _H.simulate_plan(board, plan)
	var after: UnitState = result.final_state.get_unit_by_id(1)
	_H.assert_true(
		failures, "frenzy/upgrade/kill",
		not result.final_state.get_unit_by_id(2).is_alive(),
	)
	_H.assert_eq_int(
		failures, "frenzy/upgrade/on_kill_ap",
		after.ability.points_left,
		1,
	)
