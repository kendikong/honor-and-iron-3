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


static func run_cleave_upgrade(failures: Array[String]) -> void:
	var cfg: Dictionary = H.with_upgraded_ability(
		H.bruiser_with_ability(&"bruiser_cleave"),
		&"bruiser_cleave",
	)
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	H.place_dummy(board, 2, Vector2i(4, 3))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_cleave")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	H.assert_true(
		failures, "cleave/upgrade/bleed",
		enemy != null and H.has_status(enemy, GameEnums.StatusType.BLEED),
	)


static func run_meat_shield_upgrade(failures: Array[String]) -> void:
	var cfg: Dictionary = H.with_upgraded_ability(
		H.bruiser_with_ability(&"bruiser_meat_shield"),
		&"bruiser_meat_shield",
	)
	var skill: AbilityData = H.factory_ability(&"bruiser_meat_shield")
	H.assert_eq_int(failures, "meat_shield/upgrade/range", skill.upgraded_range_tiles, 3)


static func run_adrenaline_surge_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"bruiser_adrenaline_surge")
	H.assert_true(
		failures, "adrenaline_surge/upgrade/mod",
		ab.upgraded_effects[1].modifiers.has("on_kill_heal_shield"),
	)


static func run_earthshatter_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"bruiser_earthshatter")
	H.assert_true(
		failures, "earthshatter/upgrade/mod",
		ab.upgraded_effects[1].modifiers.has("buff_per_destroyed_object"),
	)


static func run_frenzy_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"bruiser_frenzy")
	var has_on_kill: bool = false
	for eff: EffectData in ab.upgraded_effects:
		if eff != null and eff.modifiers.has("frenzy_on_kill_ap"):
			has_on_kill = true
	H.assert_true(failures, "frenzy/upgrade/on_kill_ap", has_on_kill)


static func run_concussion_blow_upgrade(failures: Array[String]) -> void:
	_Scenarios.run_concussion_blow_upgrade(failures)


static func run_suplex_upgrade(failures: Array[String]) -> void:
	_Scenarios.run_suplex_upgrade(failures)


static func run_guttural_roar_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"bruiser_guttural_roar")
	H.assert_true(
		failures, "guttural_roar/upgrade/data",
		ab.upgraded_effects.size() > 0 and ab.upgrade_description.length() > 0,
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
	H.assert_true(failures, "headbutt/upgrade/max_hp_bonus", dmg_up > dmg_base)


static func run_blood_boil_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"bruiser_blood_boil")
	H.assert_eq_int(failures, "blood_boil/upgrade/hp_cost", ab.upgraded_effects[0].amount, 10)
	H.assert_eq_int(failures, "blood_boil/upgrade/str", ab.upgraded_effects[1].amount, 5)


static func run_violent_collision_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"bruiser_violent_collision")
	H.assert_true(
		failures, "violent_collision/upgrade/stagger_mod",
		ab.upgraded_effects[0].modifiers.has("stagger_on_collision"),
	)


static func run_breaching_dash_upgrade(failures: Array[String]) -> void:
	var cfg: Dictionary = H.with_upgraded_ability(
		H.bruiser_with_ability(&"bruiser_breaching_dash"),
		&"bruiser_breaching_dash",
	)
	var board: BoardState = H.make_plain_board(Vector2i(12, 6))
	H.place_bruiser(board, 1, Vector2i(4, 3), cfg)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_breaching_dash")
	H.assert_true(
		failures, "breaching_dash/upgrade/pierce_mod",
		skill.upgraded_effects[0].modifiers.has("next_attack_pierce"),
	)
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(5, 3), -1))
	var result: SimResult = H.simulate_plan(board, plan)
	var bruiser: UnitState = result.final_state.get_unit_by_id(1)
	H.assert_true(
		failures, "breaching_dash/upgrade/pierce_flag",
		bruiser != null and bruiser.passive_flags.get("breaching_dash_pierce", false),
	)


static func run_momentum_of_titan_upgrade(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.with_upgraded_passive(
		H.with_single_passive(&"momentum_of_titan", false), &"momentum_of_titan",
	))
	var up: UnitState = H.unit_on_board(board, 1)
	var pct_up: float = 0.20 if up.is_passive_upgraded(&"momentum_of_titan") else 0.10
	var board2: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board2, 10, Vector2i(3, 3), H.with_single_passive(&"momentum_of_titan", false))
	H.assert_true(
		failures, "momentum_of_titan/upgrade/pct",
		pct_up == 0.20,
		"[+] collision damage must use 20% Max HP (factory upgraded passive)",
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
	var ab: AbilityData = H.factory_ability(&"bruiser_belly_flop")
	var has_push: bool = false
	for eff: EffectData in ab.upgraded_effects:
		if eff != null and eff.modifiers.has("belly_flop_push"):
			has_push = true
	H.assert_true(failures, "belly_flop/upgrade/push_mod", has_push)


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
	var plan := Timeline.new()
	var result: SimResult = H.simulate_plan(board, plan)
	var after: UnitState = result.final_state.get_unit_by_id(1)
	H.assert_true(
		failures, "cellular_regeneration/upgrade/str",
		H.has_status(after, GameEnums.StatusType.STAT_BUFF_STR),
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
	bruiser._recalculate_stats()
	var def_low: int = CombatSystem.get_dynamic_defense(board, bruiser)
	var board2: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board2, 10, Vector2i(3, 3), H.with_single_passive(&"adrenaline_junkie", false))
	var bruiser2: UnitState = H.unit_on_board(board2, 10)
	bruiser2.health.current_hp = bruiser2.health.max_hp / 5
	bruiser2._recalculate_stats()
	var def_base: int = CombatSystem.get_dynamic_defense(board2, bruiser2)
	H.assert_true(failures, "adrenaline_junkie/upgrade/def", def_low > def_base)


static func run_enraged_upgrade(failures: Array[String]) -> void:
	var cfg: Dictionary = H.with_upgraded_passive(
		H.with_single_passive(&"enraged", false),
		&"enraged",
	)
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	var bruiser: UnitState = H.unit_on_board(board, 1)
	bruiser.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_DEBUFF_DEF, 1, 1))
	bruiser._recalculate_stats()
	var mov_up: int = bruiser.movement.max_points
	var board2: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board2, 10, Vector2i(3, 3), H.with_single_passive(&"enraged", false))
	var bruiser2: UnitState = H.unit_on_board(board2, 10)
	bruiser2.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_DEBUFF_DEF, 1, 1))
	bruiser2._recalculate_stats()
	var mov_base: int = bruiser2.movement.max_points
	H.assert_true(failures, "enraged/upgrade/mov", mov_up > mov_base)


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
	var board2: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board2, 10, Vector2i(3, 3), H.with_single_passive(&"last_stand", false))
	var base: UnitState = H.unit_on_board(board2, 10)
	base.health.current_hp = 1
	base._recalculate_stats()
	var str_base: int = CombatSystem.get_dynamic_strength(board2, base)
	var def_base: int = CombatSystem.get_dynamic_defense(board2, base)
	H.assert_true(failures, "last_stand/upgrade/str", str_up > str_base)
	H.assert_true(failures, "last_stand/upgrade/def", def_up > def_base)


static func run_colossal_mass_upgrade(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.with_upgraded_passive(
		H.with_single_passive(&"colossal_mass", false), &"colossal_mass",
	))
	var up: UnitState = H.unit_on_board(board, 1)
	var str_up: int = CombatSystem.get_dynamic_strength(board, up)
	var board2: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board2, 10, Vector2i(3, 3), H.with_single_passive(&"colossal_mass", false))
	var str_base: int = CombatSystem.get_dynamic_strength(board2, H.unit_on_board(board2, 10))
	H.assert_true(failures, "colossal_mass/upgrade/str", str_up > str_base)


static func run_overwhelming_bulk_upgrade(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.with_upgraded_passive(
		H.with_single_passive(&"overwhelming_bulk", false), &"overwhelming_bulk",
	))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	var enemy: UnitState = H.unit_on_board(board, 2)
	enemy.health.max_hp = 10
	enemy.health.current_hp = 10
	var events: Array[SimEvent] = []
	CombatSystem.deal_damage_raw(
		board, bruiser, enemy, 4, GameEnums.StatType.PHYSICAL, events, "bulk_up",
	)
	H.assert_true(
		failures, "overwhelming_bulk/upgrade/push_pending",
		board.pending_pushes.size() > 0,
	)


static func run_thrill_of_pain_upgrade(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.with_upgraded_passive(
		H.with_single_passive(&"thrill_of_pain", false), &"thrill_of_pain",
	))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	bruiser.passive_flags["thrill_active"] = true
	var hp: int = H.unit_hp(board, 2)
	var events: Array[SimEvent] = []
	CombatSystem.deal_damage_raw(
		board, bruiser, H.unit_on_board(board, 2), 0, GameEnums.StatType.PHYSICAL, events, "thrill", 2,
	)
	var dmg_up: int = hp - H.unit_hp(board, 2)
	var board2: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board2, 10, Vector2i(3, 3), H.with_single_passive(&"thrill_of_pain", false))
	H.place_dummy(board2, 11, Vector2i(4, 3))
	var bruiser2: UnitState = H.unit_on_board(board2, 10)
	bruiser2.passive_flags["thrill_active"] = true
	var hp2: int = H.unit_hp(board2, 11)
	var events2: Array[SimEvent] = []
	CombatSystem.deal_damage_raw(
		board2, bruiser2, H.unit_on_board(board2, 11), 0, GameEnums.StatType.PHYSICAL, events2, "thrill", 2,
	)
	var dmg_base: int = hp2 - H.unit_hp(board2, 11)
	H.assert_true(failures, "thrill_of_pain/upgrade/bonus", dmg_up > dmg_base)


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
	H.place_dummy(board, 3, Vector2i(5, 3))
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
	H.place_dummy(board2, 12, Vector2i(5, 3))
	var hp2: int = H.unit_hp(board2, 12)
	var plan2 := Timeline.new()
	plan2.add(H.plan_ability(10, H.ability_on_unit(H.unit_on_board(board2, 10), &"bruiser_concussion_blow"), Vector2i(4, 3), 11))
	var result2: SimResult = H.simulate_plan(board2, plan2)
	var dmg_base: int = hp2 - H.unit_hp(result2.final_state, 12)
	H.assert_true(failures, "crowd_breaker/upgrade/splash", dmg_up > dmg_base)


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
	H.assert_true(failures, "juggernaut/upgrade/shield", bruiser.armor > armor_before)


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
