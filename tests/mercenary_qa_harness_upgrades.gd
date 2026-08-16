class_name MercenaryQaHarnessUpgrades
extends RefCounted

const H := preload("res://tests/mercenary_qa_harness.gd")
const S := preload("res://tests/mercenary_qa_harness_scenarios.gd")
const MercenarySystems := preload("res://core/systems/mercenary_systems.gd")


static func run_upgrade_for(row_name: String, failures: Array[String]) -> void:
	match row_name:
		"pullback":
			_run_pullback_upgrade(failures)
		"blade_storm":
			_run_blade_storm_upgrade(failures)
		"defense_strike":
			_run_defense_strike_upgrade(failures)
		"second_wind":
			_run_second_wind_upgrade(failures)
		"executioners_blade":
			_run_executioners_blade_upgrade(failures)
		"precision_strike":
			_run_precision_strike_upgrade(failures)
		_:
			pass


static func run_passive_upgrade_for(passive_id: StringName, failures: Array[String]) -> void:
	match passive_id:
		&"weapon_master":
			_run_weapon_master_upgrade(failures)
		&"calculated_strike":
			_run_calculated_strike_upgrade(failures)
		&"blood_scent":
			_run_blood_scent_upgrade(failures)
		&"predatory_momentum":
			_run_predatory_momentum_upgrade(failures)
		&"ruthless":
			_run_ruthless_upgrade(failures)
		&"coup_de_grace":
			_run_coup_de_grace_upgrade(failures)
		_:
			pass


static func _run_pullback_upgrade(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.with_upgraded_ability(
		H.mercenary_with_ability(&"mercenary_pullback"), &"mercenary_pullback",
	)
	H.place_mercenary(board, 1, Vector2i(3, 4), cfg)
	H.place_ally(board, 2, Vector2i(4, 4))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_pullback")
	var actor: UnitState = H.unit_on_board(board, 1)
	H.assert_eq_int(
		failures,
		"pullback/upgrade/mp",
		AbilitySystem.movement_point_cost(actor, skill),
		1,
	)
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(2, 4)))
	var result: SimResult = H.simulate_plan(board, plan)
	var ally: UnitState = H.unit_on_board(result.final_state, 2)
	H.assert_true(
		failures, "pullback/upgrade/ally_def_buff",
		H.has_status(ally, GameEnums.StatusType.STAT_BUFF_DEF),
	)


static func _run_blade_storm_upgrade(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.with_upgraded_ability(
		H.mercenary_with_ability(&"mercenary_blade_storm"), &"mercenary_blade_storm",
	)
	H.place_mercenary(board, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board, 2, Vector2i(3, 3))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_blade_storm")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(3, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "blade_storm/upgrade/bleed",
		H.has_status(H.unit_on_board(result.final_state, 2), GameEnums.StatusType.BLEED),
	)


static func _run_defense_strike_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"mercenary_defense_strike")
	H.assert_true(
		failures, "defense_strike/upgrade_mods",
		ab.upgraded_modules[0].legacy_modifiers.has("remove_push_mitigation"),
	)


static func _run_second_wind_upgrade(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.with_upgraded_ability(
		H.mercenary_with_ability(&"mercenary_second_wind"), &"mercenary_second_wind",
	)
	H.place_mercenary(board, 1, Vector2i(2, 3), cfg)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_second_wind")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(2, 3)))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "second_wind/upgrade/zero_ap",
		result.final_state.get_unit_by_id(1).passive_flags.get("next_skill_zero_ap", false),
	)


static func _run_executioners_blade_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"mercenary_executioners_blade")
	H.assert_true(
		failures, "executioners_blade/upgrade/kill_ap",
		ab.upgraded_modules[0].legacy_modifiers.has("kill_grant_ap"),
	)


static func _run_precision_strike_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"mercenary_precision_strike")
	H.assert_true(
		failures, "precision_strike/upgrade/ignore",
		float(ab.upgraded_modules[0].legacy_modifiers.get("unacted_target_ignore_def_pct", 0.0)) >= 1.0,
	)


static func _run_weapon_master_upgrade(failures: Array[String]) -> void:
	var board_no: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board_no, 1, Vector2i(2, 3), {
		"active_abilities": [H.factory_ability(&"mercenary_swift_strike")],
		"active_passives": [H.factory_passive(&"weapon_master")],
	})
	H.place_dummy(board_no, 2, Vector2i(4, 3))
	H.buff_merc_strength(board_no, 1, 40)
	H.buff_dummy_defense(board_no, 2, 25)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board_no, 1), &"mercenary_swift_strike")
	var plan_no := Timeline.new()
	plan_no.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var loss_no: int = H.hp_loss_from_plan(board_no, plan_no, 2)

	var board_up: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.with_upgraded_passive(H.mercenary_with_passive(&"weapon_master"), &"weapon_master")
	cfg["active_abilities"] = [H.factory_ability(&"mercenary_swift_strike")]
	H.place_mercenary(board_up, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board_up, 2, Vector2i(4, 3))
	H.buff_merc_strength(board_up, 1, 60)
	H.buff_dummy_defense(board_up, 2, 15)
	var plan_up := Timeline.new()
	plan_up.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var loss_up: int = H.hp_loss_from_plan(board_up, plan_up, 2)
	H.assert_true(
		failures, "weapon_master/upgrade/more_ignore",
		loss_up > loss_no,
		"[+] must ignore more DEF than base weapon master",
	)


static func _run_calculated_strike_upgrade(failures: Array[String]) -> void:
	var board_no: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg_no: Dictionary = H.mercenary_with_passive(&"calculated_strike")
	cfg_no["active_abilities"] = [
		H.factory_ability(&"mercenary_pullback"),
		H.factory_ability(&"mercenary_sever"),
	]
	H.place_mercenary(board_no, 1, Vector2i(3, 4), cfg_no)
	H.place_ally(board_no, 3, Vector2i(4, 4))
	H.place_dummy(board_no, 2, Vector2i(2, 3))
	H.unit_on_board(board_no, 2).health.current_hp = 1
	H.unit_on_board(board_no, 1).ability.max_points = 4
	H.unit_on_board(board_no, 1).ability.points_left = 4
	var pull: AbilityData = H.ability_on_unit(H.unit_on_board(board_no, 1), &"mercenary_pullback")
	var sever: AbilityData = H.ability_on_unit(H.unit_on_board(board_no, 1), &"mercenary_sever")
	var plan_no := Timeline.new()
	plan_no.add(H.plan_ability(1, pull, Vector2i(2, 4)))
	plan_no.add(H.plan_ability(1, sever, Vector2i(2, 3), 2))
	var ap_no: int = H.simulate_plan(board_no, plan_no).final_state.get_unit_by_id(1).ability.points_left

	var board_up: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg_up: Dictionary = H.with_upgraded_passive(
		H.mercenary_with_passive(&"calculated_strike"), &"calculated_strike",
	)
	cfg_up["active_abilities"] = [
		H.factory_ability(&"mercenary_pullback"),
		H.factory_ability(&"mercenary_sever"),
	]
	H.place_mercenary(board_up, 1, Vector2i(3, 4), cfg_up)
	H.place_ally(board_up, 3, Vector2i(4, 4))
	H.place_dummy(board_up, 2, Vector2i(2, 3))
	H.unit_on_board(board_up, 2).health.current_hp = 1
	H.unit_on_board(board_up, 1).ability.max_points = 4
	H.unit_on_board(board_up, 1).ability.points_left = 4
	var plan_up := Timeline.new()
	plan_up.add(H.plan_ability(1, pull, Vector2i(2, 4)))
	plan_up.add(H.plan_ability(1, sever, Vector2i(2, 3), 2))
	var ap_up: int = H.simulate_plan(board_up, plan_up).final_state.get_unit_by_id(1).ability.points_left
	H.assert_true(
		failures, "calculated_strike/upgrade/kill_ap",
		ap_up > ap_no,
		"[+] kill after movement must refund more AP than base passive",
	)


static func _run_blood_scent_upgrade(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.with_upgraded_passive(H.mercenary_with_passive(&"blood_scent"), &"blood_scent")
	cfg["active_abilities"] = [H.factory_ability(&"mercenary_tactical_retreat")]
	H.place_mercenary(board, 1, Vector2i(2, 4), cfg)
	H.place_dummy(board, 2, Vector2i(5, 4))
	H.unit_on_board(board, 2).health.current_hp = 4
	H.unit_on_board(board, 2).health.max_hp = 20
	var merc: UnitState = H.unit_on_board(board, 1)
	var mov_before: int = merc.movement.max_points
	var retreat: AbilityData = H.ability_on_unit(merc, &"mercenary_tactical_retreat")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, retreat, Vector2i(4, 4)))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_eq_int(
		failures, "blood_scent/upgrade/move",
		H.unit_on_board(result.final_state, 1).movement.max_points - mov_before,
		2,
	)


static func _run_predatory_momentum_upgrade(failures: Array[String]) -> void:
	var passive: PassiveData = H.factory_passive(&"predatory_momentum")
	H.assert_true(
		failures, "predatory_momentum/upgrade/threshold",
		float(passive.modifiers.get("upgraded_predatory_threshold", 0.0)) > float(
			passive.modifiers.get("predatory_threshold", 0.0),
		),
	)


static func _run_ruthless_upgrade(failures: Array[String]) -> void:
	var passive: PassiveData = H.factory_passive(&"ruthless")
	H.assert_true(
		failures, "ruthless/upgrade/bonus",
		int(passive.modifiers.get("upgraded_kill_next_attack_bonus", 0))
			> int(passive.modifiers.get("kill_next_attack_bonus", 0)),
	)


static func _run_coup_de_grace_upgrade(failures: Array[String]) -> void:
	var passive: PassiveData = H.factory_passive(&"coup_de_grace")
	H.assert_true(
		failures, "coup_de_grace/upgrade/fear_range",
		int(passive.modifiers.get("upgraded_basic_kill_fear_range", 0)) >= 2,
	)
