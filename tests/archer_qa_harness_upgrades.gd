class_name ArcherQaHarnessUpgrades
extends RefCounted

const H := preload("res://tests/archer_qa_harness.gd")


static func run_upgrade_for(row_name: String, failures: Array[String]) -> void:
	match row_name:
		"sidestep":
			run_sidestep_upgrade(failures)
		"power_shot":
			run_power_shot_upgrade(failures)
		"volley":
			run_volley_upgrade(failures)
		_:
			pass


static func run_sidestep_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"archer_sidestep")
	H.assert_true(
		failures, "sidestep/upgrade/mod",
		ab.upgraded_modules[0].runtime_has("next_ranged_attack_strength"),
	)
	var cfg: Dictionary = H.with_upgraded_ability(
		H.archer_with_ability(&"archer_sidestep"),
		&"archer_sidestep",
	)
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_archer(board, 1, Vector2i(2, 3), cfg)
	var skill: AbilityData = H.ability_on_unit(board.get_unit_by_id(1), &"archer_sidestep")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(3, 3), -1, GameEnums.MoveTiming.PRE_ACTION))
	var result: SimResult = H.simulate_plan(board, plan)
	var archer: UnitState = result.final_state.get_unit_by_id(1)
	H.assert_true(
		failures, "sidestep/upgrade/upgraded_profile",
		archer != null and archer.is_ability_upgraded(&"archer_sidestep"),
	)
	var resolved: AbilityData = H.ability_on_unit(archer, &"archer_sidestep")
	H.assert_true(
		failures, "sidestep/upgrade/mod",
		resolved != null and resolved.upgraded_modules[0].runtime_has("next_ranged_attack_strength"),
	)


static func run_power_shot_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"archer_power_shot")
	H.assert_true(
		failures, "power_shot/upgrade/compiled",
		not ab.upgraded_effects.is_empty(),
	)
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.with_upgraded_ability(H.archer_with_ability(&"archer_power_shot"), &"archer_power_shot")
	H.place_archer(board, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board, 2, Vector2i(5, 3))
	var hp: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(board.get_unit_by_id(1), &"archer_power_shot")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(5, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "power_shot/upgrade/damage",
		H.unit_hp(result.final_state, 2) < hp,
	)


static func run_volley_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"archer_volley")
	H.assert_true(
		failures, "volley/upgrade/compiled",
		not ab.upgraded_effects.is_empty(),
	)
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.with_upgraded_ability(H.archer_with_ability(&"archer_volley"), &"archer_volley")
	H.place_archer(board, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board, 2, Vector2i(4, 3))
	H.place_dummy(board, 3, Vector2i(4, 4))
	var hp_in: int = H.unit_hp(board, 2) + H.unit_hp(board, 3)
	var skill: AbilityData = H.ability_on_unit(board.get_unit_by_id(1), &"archer_volley")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), -1))
	var result: SimResult = H.simulate_plan(board, plan)
	var dmg_in: int = hp_in - (H.unit_hp(result.final_state, 2) + H.unit_hp(result.final_state, 3))
	H.assert_true(failures, "volley/upgrade/aoe_hits", dmg_in > 0)
