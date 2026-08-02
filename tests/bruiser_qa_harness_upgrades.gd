class_name BruiserQaHarnessUpgrades
extends RefCounted

## [+] tier sim asserts for B6-LOCK matrix (factory upgraded_effects / upgraded passives).

const H := preload("res://tests/bruiser_qa_harness.gd")
const _Scenarios := preload("res://tests/bruiser_qa_harness_scenarios.gd")


static func run_upgrade_for(row_name: String, failures: Array[String]) -> void:
	match row_name:
		"charge_strike": run_charge_strike_upgrade(failures)
		"cleave": run_cleave_upgrade(failures)
		"concussion_blow": run_concussion_blow_upgrade(failures)
		"suplex": run_suplex_upgrade(failures)
		"adrenaline_surge": run_adrenaline_surge_upgrade(failures)
		"earthshatter": run_earthshatter_upgrade(failures)
		"meat_shield": run_meat_shield_upgrade(failures)
		"frenzy": run_frenzy_upgrade(failures)
		"guttural_roar": run_guttural_roar_upgrade(failures)
		"headbutt": run_headbutt_upgrade(failures)
		"blood_boil": run_blood_boil_upgrade(failures)
		"violent_collision": run_violent_collision_upgrade(failures)
		"crimson_whirlwind": run_crimson_whirlwind_upgrade(failures)
		"belly_flop": run_belly_flop_upgrade(failures)
		"breaching_dash": run_breaching_dash_upgrade(failures)
		"cellular_regeneration": run_cellular_regeneration_upgrade(failures)
		"blood_for_blood": run_blood_for_blood_upgrade(failures)
		"adrenaline_junkie": run_adrenaline_junkie_upgrade(failures)
		"enraged": run_enraged_upgrade(failures)
		"last_stand": run_last_stand_upgrade(failures)
		"colossal_mass": run_colossal_mass_upgrade(failures)
		"overwhelming_bulk": run_overwhelming_bulk_upgrade(failures)
		"thrill_of_pain": run_thrill_of_pain_upgrade(failures)
		"momentum_of_titan": run_momentum_of_titan_upgrade(failures)
		"scar_tissue": run_scar_tissue_upgrade(failures)
		"momentum_transfer": run_momentum_transfer_upgrade(failures)
		"crowd_breaker": run_crowd_breaker_upgrade(failures)
		"juggernaut": run_juggernaut_upgrade(failures)
		"battering_ram": run_battering_ram_upgrade(failures)
		"unstoppable_force": run_unstoppable_force_upgrade(failures)
		_:
			pass


static func run_charge_strike_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"bruiser_charge_strike")
	H.assert_true(
		failures, "charge_strike/upgrade/ghost",
		ab.upgraded_effects[0].modifiers.has("ghost_move"),
	)
	H.assert_true(
		failures, "charge_strike/upgrade/terrain_bonus",
		ab.upgraded_effects[1].modifiers.has("bonus_dmg_from_terrain"),
	)
	var cfg: Dictionary = H.with_upgraded_ability(
		H.bruiser_with_ability(&"bruiser_charge_strike"),
		&"bruiser_charge_strike",
	)
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.set_tile_terrain(board, Vector2i(2, 3), &"tall_grass")
	H.place_bruiser(board, 1, Vector2i(1, 3), cfg)
	H.place_dummy(board, 2, Vector2i(3, 3))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	var hp: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(bruiser, &"bruiser_charge_strike")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(3, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "charge_strike/upgrade/terrain_flag",
		bruiser.passive_flags.get("passed_through_terrain", false),
	)
	var dmg_cracked: int = hp - H.unit_hp(result.final_state, 2)
	var board_plain: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(board_plain, 10, Vector2i(1, 3), cfg)
	H.place_dummy(board_plain, 11, Vector2i(3, 3))
	var hp_plain: int = H.unit_hp(board_plain, 11)
	var plain_skill: AbilityData = H.ability_on_unit(H.unit_on_board(board_plain, 10), &"bruiser_charge_strike")
	var plain_plan := Timeline.new()
	plain_plan.add(H.plan_ability(10, plain_skill, Vector2i(3, 3), 11))
	var plain_result: SimResult = H.simulate_plan(board_plain, plain_plan)
	var dmg_plain: int = hp_plain - H.unit_hp(plain_result.final_state, 11)
	var base_power: int = ab.upgraded_effects[1].amount
	var expected_delta: int = (
		CombatSystem.calculate_scaled_damage(bruiser, base_power + 2, GameEnums.StatType.PHYSICAL, board)
		- CombatSystem.calculate_scaled_damage(bruiser, base_power, GameEnums.StatType.PHYSICAL, board)
	)
	H.assert_eq_int(
		failures, "charge_strike/upgrade/terrain_dmg",
		dmg_cracked - dmg_plain,
		expected_delta,
	)
	var ghost_board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(ghost_board, 20, Vector2i(2, 3), cfg)
	H.place_dummy(ghost_board, 21, Vector2i(3, 3))
	H.place_dummy(ghost_board, 22, Vector2i(4, 3))
	var ghost_skill: AbilityData = H.ability_on_unit(H.unit_on_board(ghost_board, 20), &"bruiser_charge_strike")
	var ghost_plan := Timeline.new()
	ghost_plan.add(H.plan_ability(20, ghost_skill, Vector2i(4, 3), 22))
	var ghost_result: SimResult = H.simulate_plan(ghost_board, ghost_plan)
	H.assert_eq_cell(
		failures, "charge_strike/upgrade/ghost_path",
		ghost_result.final_state.get_unit_by_id(20).position,
		Vector2i(4, 3),
	)


static func run_cleave_upgrade(failures: Array[String]) -> void:
	var cfg: Dictionary = H.with_upgraded_ability(
		H.bruiser_with_ability(&"bruiser_cleave"),
		&"bruiser_cleave",
	)
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	H.place_dummy(board, 2, Vector2i(4, 3))
	H.place_dummy(board, 3, Vector2i(4, 4))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_cleave")
	var bruiser: UnitState = H.unit_on_board(board, 1)
	var wpn: int = bruiser.definition.equipped_weapon.might if bruiser.definition.equipped_weapon != null else 0
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var enemy_center: UnitState = result.final_state.get_unit_by_id(2)
	var enemy_perp: UnitState = result.final_state.get_unit_by_id(3)
	H.assert_true(
		failures, "cleave/upgrade/bleed_center",
		enemy_center != null and H.has_status(enemy_center, GameEnums.StatusType.BLEED),
	)
	H.assert_true(
		failures, "cleave/upgrade/bleed_perp",
		enemy_perp != null and H.has_status(enemy_perp, GameEnums.StatusType.BLEED),
	)
	H.assert_eq_int(
		failures, "cleave/upgrade/bleed_wpn",
		H.status_value(enemy_center, GameEnums.StatusType.BLEED),
		wpn,
	)


static func run_meat_shield_upgrade(failures: Array[String]) -> void:
	var cfg: Dictionary = H.with_upgraded_ability(
		H.bruiser_with_ability(&"bruiser_meat_shield"),
		&"bruiser_meat_shield",
	)
	var skill: AbilityData = H.factory_ability(&"bruiser_meat_shield")
	H.assert_eq_int(failures, "meat_shield/upgrade/range", skill.upgraded_range_tiles, 3)
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(board, 1, Vector2i(2, 3), cfg)
	H.place_bruiser(board, 3, Vector2i(5, 3), {"active_abilities": [DataLibrary.get_universal_run()]})
	var shield: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_meat_shield")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, shield, Vector2i(5, 3), 3))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_eq_cell(failures, "meat_shield/upgrade/swap", result.final_state.get_unit_by_id(1).position, Vector2i(5, 3))
	var intercept_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(intercept_board, 10, Vector2i(3, 3), cfg)
	H.place_bruiser(intercept_board, 12, Vector2i(4, 3), {"active_abilities": [DataLibrary.get_universal_run()]})
	var intercept_shield: AbilityData = H.ability_on_unit(H.unit_on_board(intercept_board, 10), &"bruiser_meat_shield")
	var intercept_plan := Timeline.new()
	intercept_plan.add(H.plan_ability(10, intercept_shield, Vector2i(4, 3), 12))
	var intercept_swap: SimResult = H.simulate_plan(intercept_board, intercept_plan)
	var bruiser: UnitState = intercept_swap.final_state.get_unit_by_id(10)
	H.place_unit(
		intercept_swap.final_state,
		11,
		H.bruiser_unit_data(),
		GameEnums.Team.ENEMY,
		Vector2i(2, 3),
		{"active_abilities": [H.factory_ability(&"bruiser_concussion_blow")]},
	)
	var attack_ab: AbilityData = H.factory_ability(&"bruiser_concussion_blow")
	var attack_plan := Timeline.new()
	attack_plan.add(H.plan_ability(11, attack_ab, Vector2i(3, 3), 12))
	var attack_result: SimResult = H.simulate_plan(intercept_swap.final_state, attack_plan)
	var bruiser_after: UnitState = attack_result.final_state.get_unit_by_id(10)
	var intercept_str_amount: int = 0
	for status: StatusData in bruiser_after.active_statuses:
		if status.type == GameEnums.StatusType.STAT_BUFF_STR and status.duration == 1:
			intercept_str_amount = maxi(intercept_str_amount, status.value)
	H.assert_eq_int(
		failures, "meat_shield/upgrade/intercept_str",
		intercept_str_amount,
		2,
	)


static func run_adrenaline_surge_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"bruiser_adrenaline_surge")
	H.assert_true(
		failures, "adrenaline_surge/upgrade/mod",
		ab.upgraded_effects[1].modifiers.has("on_kill_heal_shield"),
	)
	var cfg: Dictionary = H.with_upgraded_ability(
		H.bruiser_with_abilities([&"bruiser_adrenaline_surge", &"bruiser_concussion_blow"]),
		&"bruiser_adrenaline_surge",
	)
	cfg["passive_flags"] = {"training_unlimited_actions": true}
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	H.place_dummy(board, 2, Vector2i(4, 3))
	var enemy: UnitState = H.unit_on_board(board, 2)
	enemy.health.current_hp = 1
	var bruiser: UnitState = H.unit_on_board(board, 1)
	bruiser.ability.max_points = 3
	bruiser.ability.points_left = 3
	var hp_before: int = bruiser.health.current_hp
	var armor_before: int = bruiser.armor
	var surge: AbilityData = H.ability_on_unit(bruiser, &"bruiser_adrenaline_surge")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, surge, bruiser.position, bruiser.id))
	var blow: AbilityData = H.ability_on_unit(bruiser, &"bruiser_concussion_blow")
	plan.add(H.plan_ability(1, blow, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var after: UnitState = result.final_state.get_unit_by_id(1)
	H.assert_true(
		failures, "adrenaline_surge/upgrade/on_kill",
		not result.final_state.get_unit_by_id(2).is_alive() and after != null,
	)
	H.assert_eq_int(failures, "adrenaline_surge/upgrade/shield", after.armor, armor_before + 2)
	H.assert_eq_int(failures, "adrenaline_surge/upgrade/heal", after.health.current_hp, hp_before - 4)
	var base_cfg: Dictionary = H.bruiser_with_abilities([&"bruiser_adrenaline_surge", &"bruiser_concussion_blow"])
	base_cfg["passive_flags"] = {"training_unlimited_actions": true}
	var base_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(base_board, 10, Vector2i(3, 3), base_cfg)
	H.place_dummy(base_board, 12, Vector2i(4, 3))
	var base_enemy: UnitState = H.unit_on_board(base_board, 12)
	base_enemy.health.current_hp = 1
	var base_bruiser: UnitState = H.unit_on_board(base_board, 10)
	base_bruiser.ability.max_points = 3
	base_bruiser.ability.points_left = 3
	var base_armor: int = base_bruiser.armor
	var base_surge: AbilityData = H.ability_on_unit(base_bruiser, &"bruiser_adrenaline_surge")
	var base_plan := Timeline.new()
	base_plan.add(H.plan_ability(10, base_surge, base_bruiser.position, base_bruiser.id))
	var base_blow: AbilityData = H.ability_on_unit(base_bruiser, &"bruiser_concussion_blow")
	base_plan.add(H.plan_ability(10, base_blow, Vector2i(4, 3), 12))
	var base_result: SimResult = H.simulate_plan(base_board, base_plan)
	var base_after: UnitState = base_result.final_state.get_unit_by_id(10)
	H.assert_eq_int(
		failures, "adrenaline_surge/upgrade/base_no_on_kill",
		base_after.armor,
		base_armor,
	)


static func run_earthshatter_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"bruiser_earthshatter")
	H.assert_true(
		failures, "earthshatter/upgrade/mod",
		ab.upgraded_effects[1].modifiers.has("buff_per_destroyed_object"),
	)
	var cfg: Dictionary = H.with_upgraded_ability(
		H.bruiser_with_ability(&"bruiser_earthshatter"),
		&"bruiser_earthshatter",
	)
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	var construct_def: UnitData = DataLibrary.get_unit(&"construct_turret")
	H.place_unit(board, 11, construct_def, GameEnums.Team.ENEMY, Vector2i(4, 4), {})
	var bruiser_before: UnitState = H.unit_on_board(board, 1)
	var str_before: int = CombatSystem.get_dynamic_strength(board, bruiser_before)
	var skill: AbilityData = H.ability_on_unit(bruiser_before, &"bruiser_earthshatter")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 11))
	var result: SimResult = H.simulate_plan(board, plan)
	var bruiser: UnitState = result.final_state.get_unit_by_id(1)
	var construct_after: UnitState = result.final_state.get_unit_by_id(11)
	H.assert_true(
		failures, "earthshatter/upgrade/destroyed",
		construct_after == null or not construct_after.is_alive(),
	)
	var str_after: int = CombatSystem.get_dynamic_strength(result.final_state, bruiser)
	H.assert_eq_int(
		failures, "earthshatter/upgrade/str_buff",
		str_after - str_before,
		1,
	)


static func run_frenzy_upgrade(failures: Array[String]) -> void:
	var cfg: Dictionary = H.with_upgraded_ability(
		H.bruiser_with_ability(&"bruiser_frenzy"),
		&"bruiser_frenzy",
	)
	cfg["passive_flags"] = {"training_unlimited_actions": true}
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	H.place_dummy(board, 2, Vector2i(4, 3))
	var enemy: UnitState = H.unit_on_board(board, 2)
	enemy.health.current_hp = 1
	var bruiser: UnitState = H.unit_on_board(board, 1)
	bruiser.ability.max_points = 3
	bruiser.ability.points_left = 1
	var skill: AbilityData = H.ability_on_unit(bruiser, &"bruiser_frenzy")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var after: UnitState = result.final_state.get_unit_by_id(1)
	H.assert_true(
		failures, "frenzy/upgrade/kill",
		not result.final_state.get_unit_by_id(2).is_alive(),
	)
	H.assert_eq_int(
		failures, "frenzy/upgrade/on_kill_ap",
		after.ability.points_left,
		1,
	)


static func run_concussion_blow_upgrade(failures: Array[String]) -> void:
	_Scenarios.run_concussion_blow_upgrade(failures)


static func run_suplex_upgrade(failures: Array[String]) -> void:
	_Scenarios.run_suplex_upgrade(failures)


static func run_guttural_roar_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"bruiser_guttural_roar")
	H.assert_true(
		failures, "guttural_roar/upgrade/push_mod",
		ab.upgraded_effects[0].modifiers.has("push_board_items"),
	)
	H.assert_true(
		failures, "guttural_roar/upgrade/collision_mod",
		ab.upgraded_effects[0].modifiers.has("item_collision_damage"),
	)
	var cfg: Dictionary = H.with_upgraded_ability(
		H.bruiser_with_ability(&"bruiser_guttural_roar"),
		&"bruiser_guttural_roar",
	)
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	H.place_dummy(board, 2, Vector2i(5, 3))
	board.items.append(Vector2i(4, 3))
	var hp: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_guttural_roar")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3)))
	var result: SimResult = H.simulate_plan(board, plan)
	var final_items: Array = result.final_state.items
	var item_pushed_east: bool = false
	for coord: Variant in final_items:
		if coord is Vector2i and coord.x >= 5 and coord.y == 3:
			item_pushed_east = true
			break
	H.assert_true(
		failures, "guttural_roar/upgrade/item_push",
		not final_items.has(Vector2i(4, 3)),
	)
	H.assert_true(
		failures, "guttural_roar/upgrade/item_dest",
		item_pushed_east,
		"item must be pushed east into the enemy",
	)
	H.assert_eq_int(
		failures, "guttural_roar/upgrade/item_collision",
		hp - H.unit_hp(result.final_state, 2),
		1,
	)


static func run_headbutt_upgrade(failures: Array[String]) -> void:
	var cfg: Dictionary = H.with_upgraded_ability(
		H.bruiser_with_ability(&"bruiser_headbutt"),
		&"bruiser_headbutt",
	)
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	H.place_dummy(board, 2, Vector2i(4, 3))
	var hp: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_headbutt")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var dmg_up: int = hp - H.unit_hp(result.final_state, 2)
	var board2: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board2, 10, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_headbutt"))
	H.place_dummy(board2, 11, Vector2i(4, 3))
	var hp2: int = H.unit_hp(board2, 11)
	var base_skill: AbilityData = H.ability_on_unit(H.unit_on_board(board2, 10), &"bruiser_headbutt")
	var plan2 := Timeline.new()
	plan2.add(H.plan_ability(10, base_skill, Vector2i(4, 3), 11))
	var result2: SimResult = H.simulate_plan(board2, plan2)
	var dmg_base: int = hp2 - H.unit_hp(result2.final_state, 11)
	var bruiser_up: UnitState = H.unit_on_board(board, 1)
	var expected_bonus: int = floori(float(bruiser_up.health.max_hp) * 0.1)
	H.assert_true(
		failures, "headbutt/upgrade/mod",
		skill.upgraded_effects[0].modifiers.has("bonus_dmg_pct_max_hp"),
	)
	H.assert_true(
		failures, "headbutt/upgrade/max_hp_bonus",
		dmg_up - dmg_base >= expected_bonus,
	)


static func run_blood_boil_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"bruiser_blood_boil")
	H.assert_eq_int(failures, "blood_boil/upgrade/hp_cost", ab.upgraded_effects[0].amount, 10)
	H.assert_eq_int(failures, "blood_boil/upgrade/str", ab.upgraded_effects[1].amount, 5)
	var cfg: Dictionary = H.with_upgraded_ability(
		H.bruiser_with_ability(&"bruiser_blood_boil"),
		&"bruiser_blood_boil",
	)
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	var bruiser: UnitState = H.unit_on_board(board, 1)
	var hp_before: int = bruiser.health.current_hp
	var skill: AbilityData = H.ability_on_unit(bruiser, &"bruiser_blood_boil")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, bruiser.position, bruiser.id))
	var result: SimResult = H.simulate_plan(board, plan)
	var after: UnitState = result.final_state.get_unit_by_id(1)
	H.assert_eq_int(failures, "blood_boil/upgrade/hp_cost_sim", hp_before - after.health.current_hp, 10)
	H.assert_eq_int(failures, "blood_boil/upgrade/str_sim", H.status_value(after, GameEnums.StatusType.STAT_BUFF_STR), 5)


static func run_violent_collision_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"bruiser_violent_collision")
	H.assert_true(
		failures, "violent_collision/upgrade/stagger_mod",
		ab.upgraded_effects[0].modifiers.has("stagger_on_collision"),
	)
	var cfg: Dictionary = H.with_upgraded_ability(
		H.bruiser_with_ability(&"bruiser_violent_collision"),
		&"bruiser_violent_collision",
	)
	cfg["passive_flags"] = {"training_unlimited_actions": true}
	var board: BoardState = H.make_plain_board(Vector2i(8, 6), [Vector2i(4, 3)])
	H.place_bruiser(board, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board, 2, Vector2i(3, 3))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_violent_collision")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), -1))
	var result: SimResult = H.simulate_plan(board, plan)
	var victim: UnitState = result.final_state.get_unit_by_id(2)
	H.assert_true(
		failures, "violent_collision/upgrade/stagger",
		victim != null and H.has_status(victim, GameEnums.StatusType.STAGGER),
		"upgraded dash collision must STAGGER the bulldozed enemy",
	)


static func run_breaching_dash_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"bruiser_breaching_dash")
	H.assert_true(
		failures, "breaching_dash/upgrade/pierce_mod",
		ab.upgraded_effects[0].modifiers.has("next_attack_pierce"),
	)
	var base_cfg: Dictionary = {
		"active_abilities": [
			DataLibrary.get_universal_run(),
			H.factory_ability(&"bruiser_breaching_dash"),
			H.factory_ability(&"bruiser_headbutt"),
		],
	}
	var cfg: Dictionary = H.with_upgraded_ability(base_cfg, &"bruiser_breaching_dash")
	cfg["passive_flags"] = {"training_unlimited_actions": true}
	var board: BoardState = H.make_plain_board(Vector2i(12, 6))
	H.place_bruiser(board, 1, Vector2i(2, 3), cfg)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_breaching_dash")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), -1))
	var result: SimResult = H.simulate_plan(board, plan)
	var bruiser: UnitState = result.final_state.get_unit_by_id(1)
	H.assert_true(
		failures, "breaching_dash/upgrade/pierce_flag",
		bruiser != null and bruiser.passive_flags.get("breaching_dash_pierce", false),
	)
	var pierce_board: BoardState = H.make_plain_board(Vector2i(12, 6))
	H.place_bruiser(pierce_board, 20, Vector2i(2, 3), cfg)
	H.place_dummy(pierce_board, 21, Vector2i(4, 3))
	var enemy: UnitState = H.unit_on_board(pierce_board, 21)
	enemy.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, 20))
	enemy._recalculate_stats()
	var dash_skill: AbilityData = H.ability_on_unit(H.unit_on_board(pierce_board, 20), &"bruiser_breaching_dash")
	var dash_plan := Timeline.new()
	dash_plan.add(H.plan_ability(20, dash_skill, Vector2i(3, 3), -1))
	var dash_result: SimResult = H.simulate_plan(pierce_board, dash_plan)
	var dash_bruiser: UnitState = dash_result.final_state.get_unit_by_id(20)
	H.assert_true(
		failures, "breaching_dash/upgrade/pierce_flag_mid",
		dash_bruiser != null and dash_bruiser.passive_flags.get("breaching_dash_pierce", false),
	)
	dash_bruiser.ability.max_points = 3
	dash_bruiser.ability.points_left = 3
	var hp_before: int = H.unit_hp(dash_result.final_state, 21)
	var headbutt_skill: AbilityData = H.ability_on_unit(dash_bruiser, &"bruiser_headbutt")
	var attack_plan := Timeline.new()
	attack_plan.add(H.plan_ability(20, headbutt_skill, Vector2i(4, 3), 21))
	var pierce_result: SimResult = H.simulate_plan(dash_result.final_state, attack_plan)
	H.assert_true(
		failures, "breaching_dash/upgrade/pierce_events",
		H.events_have_damage_pierce(pierce_result.events, true),
	)
	var dmg_pierce: int = hp_before - H.unit_hp(pierce_result.final_state, 21)
	var control_board: BoardState = H.make_plain_board(Vector2i(12, 6))
	H.place_bruiser(control_board, 30, Vector2i(2, 3), cfg)
	H.place_dummy(control_board, 31, Vector2i(4, 3))
	var control_enemy: UnitState = H.unit_on_board(control_board, 31)
	control_enemy.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, 20))
	control_enemy._recalculate_stats()
	var control_hp: int = H.unit_hp(control_board, 31)
	var control_headbutt: AbilityData = H.ability_on_unit(
		H.unit_on_board(control_board, 30), &"bruiser_headbutt",
	)
	var control_plan := Timeline.new()
	control_plan.add(H.plan_ability(30, control_headbutt, Vector2i(4, 3), 31))
	var control_result: SimResult = H.simulate_plan(control_board, control_plan)
	var dmg_control: int = control_hp - H.unit_hp(control_result.final_state, 31)
	H.assert_true(
		failures, "breaching_dash/upgrade/pierce_dmg",
		dmg_pierce > dmg_control,
		"upgraded breaching dash must grant PIERCE damage on the next attack",
	)


static func run_momentum_of_titan_upgrade(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(8, 8), [Vector2i(4, 3)])
	var cfg: Dictionary = H.with_upgraded_passive(
		H.with_single_passive(&"momentum_of_titan", false),
		&"momentum_of_titan",
	)
	cfg["active_abilities"] = [H.factory_ability(&"bruiser_concussion_blow")]
	H.place_bruiser(board, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board, 2, Vector2i(3, 3))
	var enemy_up: UnitState = H.unit_on_board(board, 2)
	enemy_up.health.max_hp = 300
	enemy_up.health.current_hp = 300
	enemy_up._recalculate_stats()
	var bruiser: UnitState = H.unit_on_board(board, 1)
	var bonus_up: int = floori(bruiser.health.max_hp * 0.20)
	var bonus_base: int = floori(bruiser.health.max_hp * 0.10)
	H.assert_true(failures, "momentum_of_titan/upgrade/pct", bonus_up > bonus_base)
	var hp: int = H.unit_hp(board, 2)
	var ab: AbilityData = H.ability_on_unit(bruiser, &"bruiser_concussion_blow")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, ab, Vector2i(3, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var dmg_up: int = hp - H.unit_hp(result.final_state, 2)
	var cfg_base: Dictionary = H.with_single_passive(&"momentum_of_titan", false)
	cfg_base["active_abilities"] = [H.factory_ability(&"bruiser_concussion_blow")]
	var board_base: BoardState = H.make_plain_board(Vector2i(8, 8), [Vector2i(4, 3)])
	H.place_bruiser(board_base, 10, Vector2i(2, 3), cfg_base)
	H.place_dummy(board_base, 11, Vector2i(3, 3))
	var enemy_base: UnitState = H.unit_on_board(board_base, 11)
	enemy_base.health.max_hp = 300
	enemy_base.health.current_hp = 300
	enemy_base._recalculate_stats()
	var hp_base: int = H.unit_hp(board_base, 11)
	var plan_base := Timeline.new()
	plan_base.add(H.plan_ability(10, H.ability_on_unit(H.unit_on_board(board_base, 10), &"bruiser_concussion_blow"), Vector2i(3, 3), 11))
	var result_base: SimResult = H.simulate_plan(board_base, plan_base)
	var dmg_base: int = hp_base - H.unit_hp(result_base.final_state, 11)
	H.assert_eq_int(
		failures, "momentum_of_titan/upgrade/collision_delta",
		dmg_up - dmg_base,
		bonus_up - bonus_base,
	)


static func run_momentum_transfer_upgrade(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(8, 8), [Vector2i(5, 3)])
	var cfg: Dictionary = H.with_upgraded_passive(
		H.with_single_passive(&"momentum_transfer", false),
		&"momentum_transfer",
	)
	cfg["active_passives"] = [
		H.factory_passive(&"momentum_transfer"),
		H.factory_passive(&"battering_ram"),
	]
	cfg["active_abilities"] = [H.factory_ability(&"bruiser_concussion_blow")]
	H.place_bruiser(board, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board, 2, Vector2i(3, 3))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	var str_before: int = CombatSystem.get_dynamic_strength(board, bruiser)
	var ab: AbilityData = H.ability_on_unit(bruiser, &"bruiser_concussion_blow")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, ab, Vector2i(3, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var after: UnitState = result.final_state.get_unit_by_id(1)
	H.assert_true(
		failures, "momentum_transfer/upgrade/str",
		H.has_status(after, GameEnums.StatusType.STAT_BUFF_STR),
		"[+] collision heal path must grant +1 STR",
	)
	H.assert_true(
		failures, "momentum_transfer/upgrade/str_delta",
		CombatSystem.get_dynamic_strength(result.final_state, after) > str_before,
	)


static func run_battering_ram_upgrade(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(8, 8), [Vector2i(4, 3)])
	var cfg: Dictionary = H.with_upgraded_passive(
		H.with_single_passive(&"battering_ram", false),
		&"battering_ram",
	)
	cfg["active_abilities"] = [H.factory_ability(&"bruiser_concussion_blow")]
	H.place_bruiser(board, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board, 2, Vector2i(3, 3))
	var ab: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_concussion_blow")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, ab, Vector2i(3, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	H.assert_true(
		failures, "battering_ram/upgrade/wall_stagger",
		enemy != null and H.has_status(enemy, GameEnums.StatusType.STAGGER),
	)


static func run_crimson_whirlwind_upgrade(failures: Array[String]) -> void:
	var cfg: Dictionary = H.with_upgraded_ability(
		H.bruiser_with_ability(&"bruiser_crimson_whirlwind"),
		&"bruiser_crimson_whirlwind",
	)
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	var bruiser: UnitState = H.unit_on_board(board, 1)
	bruiser.health.current_hp = bruiser.health.max_hp - 3
	var hp: int = bruiser.health.current_hp
	H.place_dummy(board, 2, Vector2i(4, 3))
	var skill: AbilityData = H.ability_on_unit(bruiser, &"bruiser_crimson_whirlwind")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "crimson_whirlwind/upgrade/heal",
		H.unit_hp(result.final_state, 1) > hp,
	)


static func run_belly_flop_upgrade(failures: Array[String]) -> void:
	var cfg: Dictionary = H.with_upgraded_ability(
		H.bruiser_with_ability(&"bruiser_belly_flop"),
		&"bruiser_belly_flop",
	)
	cfg["passive_flags"] = {"training_unlimited_actions": true}
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	var bruiser_ap: UnitState = H.unit_on_board(board, 1)
	bruiser_ap.ability.max_points = 2
	bruiser_ap.ability.points_left = 2
	H.place_dummy(board, 2, Vector2i(5, 4))
	var start: Vector2i = H.unit_on_board(board, 2).position
	var skill: AbilityData = H.ability_on_unit(bruiser_ap, &"bruiser_belly_flop")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(5, 3), -1))
	var result: SimResult = H.simulate_plan(board, plan)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	H.assert_true(
		failures, "belly_flop/upgrade/push",
		enemy != null and enemy.position != start,
	)


static func run_cellular_regeneration_upgrade(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = H.with_upgraded_passive(
		H.with_single_passive(&"cellular_regeneration", false),
		&"cellular_regeneration",
	)
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	H.place_dummy(board, 2, Vector2i(4, 3))
	H.place_dummy(board, 3, Vector2i(3, 4))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	bruiser.health.current_hp = bruiser.health.max_hp - 2
	var hp: int = bruiser.health.current_hp
	var plan := Timeline.new()
	var result: SimResult = H.simulate_plan(board, plan)
	var after: UnitState = result.final_state.get_unit_by_id(1)
	H.assert_eq_int(
		failures, "cellular_regeneration/upgrade/heal",
		after.health.current_hp,
		hp + 1,
	)
	H.assert_true(
		failures, "cellular_regeneration/upgrade/str",
		H.has_status(after, GameEnums.StatusType.STAT_BUFF_STR),
	)
	var board_one: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board_one, 10, Vector2i(3, 3), cfg)
	H.place_dummy(board_one, 11, Vector2i(4, 3))
	var one_hp: int = H.unit_on_board(board_one, 10).health.current_hp
	var one_result: SimResult = H.simulate_plan(board_one, Timeline.new())
	var one_after: UnitState = one_result.final_state.get_unit_by_id(10)
	H.assert_true(
		failures, "cellular_regeneration/upgrade/no_str_one_adj",
		not H.has_status(one_after, GameEnums.StatusType.STAT_BUFF_STR),
		"[+] STR buff requires 2+ adjacent enemies",
	)


static func run_blood_for_blood_upgrade(failures: Array[String]) -> void:
	var cfg: Dictionary = H.with_upgraded_passive(
		H.with_single_passive(&"blood_for_blood", false),
		&"blood_for_blood",
	)
	cfg["passive_flags"] = {"damaged_last_turn": true}
	cfg["active_abilities"] = [H.factory_ability(&"bruiser_concussion_blow")]
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	H.place_dummy(board, 2, Vector2i(4, 3))
	var hp: int = H.unit_hp(board, 2)
	var ab: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_concussion_blow")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, ab, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var dmg_up: int = hp - H.unit_hp(result.final_state, 2)
	var board2: BoardState = H.make_plain_board(Vector2i(8, 8))
	var cfg2: Dictionary = H.with_single_passive(&"blood_for_blood", false)
	cfg2["passive_flags"] = {"damaged_last_turn": true}
	cfg2["active_abilities"] = [H.factory_ability(&"bruiser_concussion_blow")]
	H.place_bruiser(board2, 10, Vector2i(3, 3), cfg2)
	H.place_dummy(board2, 11, Vector2i(4, 3))
	var hp2: int = H.unit_hp(board2, 11)
	var ab2: AbilityData = H.ability_on_unit(H.unit_on_board(board2, 10), &"bruiser_concussion_blow")
	var plan2 := Timeline.new()
	plan2.add(H.plan_ability(10, ab2, Vector2i(4, 3), 11))
	var result2: SimResult = H.simulate_plan(board2, plan2)
	var dmg_base: int = hp2 - H.unit_hp(result2.final_state, 11)
	H.assert_true(failures, "blood_for_blood/upgrade/extra_dmg", dmg_up > dmg_base)


static func run_adrenaline_junkie_upgrade(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = H.with_upgraded_passive(
		H.with_single_passive(&"adrenaline_junkie", false),
		&"adrenaline_junkie",
	)
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	var bruiser: UnitState = H.unit_on_board(board, 1)
	bruiser.health.current_hp = bruiser.health.max_hp / 5
	bruiser._recalculate_stats(board)
	var def_low: int = CombatSystem.get_dynamic_defense(board, bruiser)
	var board2: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board2, 10, Vector2i(3, 3), H.with_single_passive(&"adrenaline_junkie", false))
	var bruiser2: UnitState = H.unit_on_board(board2, 10)
	bruiser2.health.current_hp = bruiser2.health.max_hp / 5
	bruiser2._recalculate_stats(board2)
	var def_base: int = CombatSystem.get_dynamic_defense(board2, bruiser2)
	var expected_def: int = floori(
		(bruiser.health.max_hp - bruiser.health.current_hp) / float(bruiser.health.max_hp) / 0.20
	)
	H.assert_eq_int(failures, "adrenaline_junkie/upgrade/def", def_low - def_base, expected_def)


static func run_enraged_upgrade(failures: Array[String]) -> void:
	var cfg: Dictionary = H.with_upgraded_passive(
		H.with_single_passive(&"enraged", false),
		&"enraged",
	)
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	var bruiser: UnitState = H.unit_on_board(board, 1)
	bruiser.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_DEBUFF_DEF, 1, 1))
	bruiser._recalculate_stats(board)
	var mov_up: int = bruiser.movement.max_points
	var board2: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board2, 10, Vector2i(3, 3), H.with_single_passive(&"enraged", false))
	var bruiser2: UnitState = H.unit_on_board(board2, 10)
	bruiser2.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_DEBUFF_DEF, 1, 1))
	bruiser2._recalculate_stats(board2)
	var mov_base: int = bruiser2.movement.max_points
	H.assert_eq_int(failures, "enraged/upgrade/mov", mov_up - mov_base, 1)
	var trap_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.set_tile_trap(trap_board, Vector2i(3, 3))
	H.place_bruiser(trap_board, 20, Vector2i(3, 3), cfg)
	var trap_bruiser: UnitState = H.unit_on_board(trap_board, 20)
	trap_bruiser._recalculate_stats(trap_board)
	var plain_trap_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(plain_trap_board, 21, Vector2i(3, 3), cfg)
	var plain_trap: UnitState = H.unit_on_board(plain_trap_board, 21)
	plain_trap._recalculate_stats(plain_trap_board)
	H.assert_eq_int(
		failures, "enraged/upgrade/hazard_mov",
		trap_bruiser.movement.max_points - plain_trap.movement.max_points,
		1,
	)


static func run_last_stand_upgrade(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.with_upgraded_passive(
		H.with_single_passive(&"last_stand", false), &"last_stand",
	))
	var up: UnitState = H.unit_on_board(board, 1)
	up.health.current_hp = 1
	up._recalculate_stats()
	var str_up: int = CombatSystem.get_dynamic_strength(board, up)
	var def_up: int = CombatSystem.get_dynamic_defense(board, up)
	up.health.current_hp = up.health.max_hp
	up._recalculate_stats()
	var str_full: int = CombatSystem.get_dynamic_strength(board, up)
	var def_full: int = CombatSystem.get_dynamic_defense(board, up)
	H.assert_eq_int(failures, "last_stand/upgrade/str", str_up - str_full, 3)
	H.assert_eq_int(failures, "last_stand/upgrade/def", def_up - def_full, 3)


static func run_colossal_mass_upgrade(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.with_upgraded_passive(
		H.with_single_passive(&"colossal_mass", false), &"colossal_mass",
	))
	var up: UnitState = H.unit_on_board(board, 1)
	var str_up: int = CombatSystem.get_dynamic_strength(board, up)
	var board2: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board2, 10, Vector2i(3, 3), H.with_single_passive(&"colossal_mass", false))
	var base_bruiser: UnitState = H.unit_on_board(board2, 10)
	var str_base: int = CombatSystem.get_dynamic_strength(board2, base_bruiser)
	var expected_delta: int = (
		floori(float(up.health.max_hp) / 10.0) - floori(float(base_bruiser.health.max_hp) / 15.0)
	)
	H.assert_eq_int(failures, "colossal_mass/upgrade/str", str_up - str_base, expected_delta)


static func run_overwhelming_bulk_upgrade(failures: Array[String]) -> void:
	var cfg: Dictionary = H.with_single_passive(&"overwhelming_bulk", false)
	cfg["active_abilities"] = [H.factory_ability(&"bruiser_headbutt")]
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	H.place_dummy(board, 2, Vector2i(4, 3))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	bruiser.upgraded_passives.append(&"overwhelming_bulk")
	bruiser.health.max_hp = 150
	bruiser.health.current_hp = 150
	bruiser._recalculate_stats()
	var enemy: UnitState = H.unit_on_board(board, 2)
	enemy.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, 20))
	enemy.health.max_hp = 80
	enemy.health.current_hp = 80
	enemy._recalculate_stats()
	H.assert_true(
		failures, "overwhelming_bulk/upgrade/precond",
		bruiser.is_passive_upgraded(&"overwhelming_bulk")
			and bruiser.health.current_hp > enemy.health.max_hp,
	)
	var start_pos: Vector2i = enemy.position
	var skill: AbilityData = H.ability_on_unit(bruiser, &"bruiser_headbutt")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "overwhelming_bulk/upgrade/pierce_events",
		H.events_have_damage_pierce(result.events, true),
		"upgraded bulk pierce must apply on AbilitySystem DAMAGE path",
	)
	var after: UnitState = result.final_state.get_unit_by_id(2)
	H.assert_true(
		failures, "overwhelming_bulk/upgrade/push_lands",
		after != null and after.position != start_pos,
		"upgraded overwhelming bulk must PUSH 1 on pierce ability attack",
	)


static func run_thrill_of_pain_upgrade(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.with_upgraded_passive(
		H.with_single_passive(&"thrill_of_pain", false), &"thrill_of_pain",
	))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	var enemy_up: UnitState = H.unit_on_board(board, 2)
	var trig: Array[SimEvent] = []
	CombatSystem.deal_damage(board, bruiser, 3, trig, &"physical", false, false, enemy_up)
	H.assert_true(
		failures, "thrill_of_pain/upgrade/thrill_active",
		bruiser.passive_flags.get("thrill_active", false),
	)
	var hp: int = enemy_up.health.current_hp
	var base_scaled: int = CombatSystem.calculate_scaled_damage(
		bruiser, 2, GameEnums.StatType.PHYSICAL, board,
	)
	var events: Array[SimEvent] = []
	CombatSystem.deal_damage_raw(
		board, bruiser, enemy_up, base_scaled, GameEnums.StatType.PHYSICAL, events, "thrill", 2,
	)
	var dmg_up: int = hp - enemy_up.health.current_hp
	var board2: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board2, 10, Vector2i(3, 3), H.with_single_passive(&"thrill_of_pain", false))
	H.place_dummy(board2, 11, Vector2i(4, 3))
	var bruiser2: UnitState = H.unit_on_board(board2, 10)
	var enemy_base: UnitState = H.unit_on_board(board2, 11)
	var trig2: Array[SimEvent] = []
	CombatSystem.deal_damage(board2, bruiser2, 3, trig2, &"physical", false, false, enemy_base)
	var hp2: int = enemy_base.health.current_hp
	var base_scaled2: int = CombatSystem.calculate_scaled_damage(
		bruiser2, 2, GameEnums.StatType.PHYSICAL, board2,
	)
	var events2: Array[SimEvent] = []
	CombatSystem.deal_damage_raw(
		board2, bruiser2, enemy_base, base_scaled2, GameEnums.StatType.PHYSICAL, events2, "thrill", 2,
	)
	var dmg_base: int = hp2 - enemy_base.health.current_hp
	var expected_upgrade_delta: int = (
		CombatSystem.calculate_scaled_damage(bruiser, 5, GameEnums.StatType.PHYSICAL, board)
		- CombatSystem.calculate_scaled_damage(bruiser, 4, GameEnums.StatType.PHYSICAL, board)
	)
	H.assert_eq_int(failures, "thrill_of_pain/upgrade/bonus", dmg_up - dmg_base, expected_upgrade_delta)


static func run_scar_tissue_upgrade(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.with_upgraded_passive(
		H.with_single_passive(&"scar_tissue", false), &"scar_tissue",
	))
	var victim: UnitState = H.unit_on_board(board, 1)
	victim.health.current_hp = victim.health.max_hp - 10
	victim._recalculate_stats()
	var hp: int = victim.health.current_hp
	var events: Array[SimEvent] = []
	CombatSystem.deal_damage(board, victim, 8, events, &"physical", false, false, null)
	var reduced_up: int = hp - victim.health.current_hp
	var board2: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board2, 10, Vector2i(3, 3), H.with_single_passive(&"scar_tissue", false))
	var victim2: UnitState = H.unit_on_board(board2, 10)
	victim2.health.current_hp = victim2.health.max_hp - 10
	victim2._recalculate_stats()
	var hp2: int = victim2.health.current_hp
	var events2: Array[SimEvent] = []
	CombatSystem.deal_damage(board2, victim2, 8, events2, &"physical", false, false, null)
	var reduced_base: int = hp2 - victim2.health.current_hp
	var scar_bonus: int = maxi(
		floori(float(victim.health.max_hp) / 20.0),
		floori(float(victim.health.max_hp - victim.health.current_hp) / 20.0),
	) + 1
	H.assert_eq_int(
		failures, "scar_tissue/upgrade/exact",
		reduced_base - reduced_up,
		1,
	)
	H.assert_true(failures, "scar_tissue/upgrade/more_reduce", reduced_up < reduced_base)


static func run_crowd_breaker_upgrade(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = H.with_upgraded_passive(
		H.with_single_passive(&"crowd_breaker", false),
		&"crowd_breaker",
	)
	cfg["active_abilities"] = [H.factory_ability(&"bruiser_concussion_blow")]
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	H.place_dummy(board, 2, Vector2i(4, 3))
	H.place_dummy(board, 3, Vector2i(4, 4))
	var hp_splash: int = H.unit_hp(board, 3)
	var ab: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_concussion_blow")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, ab, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var dmg_up: int = hp_splash - H.unit_hp(result.final_state, 3)
	var board2: BoardState = H.make_plain_board(Vector2i(8, 8))
	var cfg2: Dictionary = H.with_single_passive(&"crowd_breaker", false)
	cfg2["active_abilities"] = [H.factory_ability(&"bruiser_concussion_blow")]
	H.place_bruiser(board2, 10, Vector2i(3, 3), cfg2)
	H.place_dummy(board2, 11, Vector2i(4, 3))
	H.place_dummy(board2, 12, Vector2i(4, 4))
	var hp2: int = H.unit_hp(board2, 12)
	var plan2 := Timeline.new()
	plan2.add(H.plan_ability(10, H.ability_on_unit(H.unit_on_board(board2, 10), &"bruiser_concussion_blow"), Vector2i(4, 3), 11))
	var result2: SimResult = H.simulate_plan(board2, plan2)
	var dmg_base: int = hp2 - H.unit_hp(result2.final_state, 12)
	H.assert_eq_int(failures, "crowd_breaker/upgrade/splash", dmg_up - dmg_base, 1)


static func run_juggernaut_upgrade(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.set_tile_trap(board, Vector2i(4, 3))
	var cfg: Dictionary = H.with_upgraded_passive(
		H.with_single_passive(&"juggernaut", false),
		&"juggernaut",
	)
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	var bruiser: UnitState = H.unit_on_board(board, 1)
	var armor_before: int = bruiser.armor
	GridSystem.set_occupant(board, Vector2i(3, 3), -1)
	bruiser.position = Vector2i(4, 3)
	GridSystem.set_occupant(board, Vector2i(4, 3), bruiser.id)
	var events: Array[SimEvent] = []
	TerrainSystem.apply_landing(board, bruiser, events)
	H.assert_eq_int(failures, "juggernaut/upgrade/shield", bruiser.armor, armor_before + 1)


static func run_unstoppable_force_upgrade(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.with_upgraded_passive(
		H.with_single_passive(&"unstoppable_force", false), &"unstoppable_force",
	))
	var enemy_cfg: Dictionary = {"active_abilities": [H.factory_ability(&"bruiser_headbutt")]}
	H.place_unit(board, 2, H.bruiser_unit_data(), GameEnums.Team.ENEMY, Vector2i(4, 3), enemy_cfg)
	var bruiser: UnitState = H.unit_on_board(board, 1)
	var armor_before: int = bruiser.armor
	var ab: AbilityData = H.factory_ability(&"bruiser_headbutt")
	var plan := Timeline.new()
	plan.add(H.plan_ability(2, ab, Vector2i(3, 3), 1))
	var result: SimResult = H.simulate_plan(board, plan)
	bruiser = result.final_state.get_unit_by_id(1)
	var board2: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board2, 10, Vector2i(3, 3), H.with_single_passive(&"unstoppable_force", false))
	H.place_unit(board2, 11, H.bruiser_unit_data(), GameEnums.Team.ENEMY, Vector2i(4, 3), enemy_cfg)
	var armor_base_before: int = H.unit_on_board(board2, 10).armor
	var plan2 := Timeline.new()
	plan2.add(H.plan_ability(11, ab, Vector2i(3, 3), 10))
	var result2: SimResult = H.simulate_plan(board2, plan2)
	var armor_up_gain: int = bruiser.armor - armor_before
	var armor_base_gain: int = result2.final_state.get_unit_by_id(10).armor - armor_base_before
	H.assert_true(failures, "unstoppable_force/upgrade/shield", armor_up_gain > armor_base_gain)


static func enemy_def_buff(board: BoardState, unit_id: int, amount: int) -> void:
	var enemy: UnitState = H.unit_on_board(board, unit_id)
	enemy.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, amount))
	enemy._recalculate_stats()
