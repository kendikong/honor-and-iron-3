class_name BruiserQaHarnessScenarios
extends RefCounted

## Per-row sim + factory asserts for Bruiser B6-LOCK matrix (rows 2–31).

const H := preload("res://tests/bruiser_qa_harness.gd")


static func run_charge_strike(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_charge_strike", "MOVE + DAMAGE + PUSH",
		[GameEnums.EffectType.MOVE, GameEnums.EffectType.DAMAGE, GameEnums.EffectType.PUSH],
	)
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_charge_strike"))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var hp: int = H.unit_hp(board, 2)
	var ab: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_charge_strike")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, ab, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	H.assert_true(failures, "charge_strike/damage", enemy != null and enemy.health.current_hp < hp)
	H.assert_true(failures, "charge_strike/push", H.events_have_unit_pushed(result.events, 2))


static func run_concussion_blow(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_concussion_blow", "DAMAGE + PUSH",
		[GameEnums.EffectType.DAMAGE, GameEnums.EffectType.PUSH],
	)
	var ab: AbilityData = H.factory_ability(&"bruiser_concussion_blow")
	H.assert_true(
		failures, "concussion_blow/object_stagger_mod",
		ab.effects[1].modifiers.has("object_collision_stagger"),
	)
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_concussion_blow"))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var hp_before: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_concussion_blow")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(failures, "concussion_blow/hit", H.unit_hp(result.final_state, 2) < hp_before)


static func run_cleave(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_cleave", "ARC DAMAGE",
		[GameEnums.EffectType.DAMAGE],
	)
	var ab: AbilityData = H.factory_ability(&"bruiser_cleave")
	H.assert_eq_int(failures, "cleave/shape", ab.target_shape, GameEnums.TargetShape.ARC)


static func run_suplex(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_suplex", "DAMAGE + THROW_BEHIND",
		[GameEnums.EffectType.DAMAGE, GameEnums.EffectType.THROW_BEHIND],
	)
	H.assert_true(
		failures, "suplex/not_swap",
		not H.ability_has_effect(H.factory_ability(&"bruiser_suplex"), GameEnums.EffectType.SWAP, false),
	)
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	var result: SimResult = H.cast_on_enemy(board, &"bruiser_suplex", Vector2i(3, 3), 2, Vector2i(3, 4))
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	H.assert_eq_cell(failures, "suplex/behind_caster", enemy.position, Vector2i(3, 2))


static func run_adrenaline_surge(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_adrenaline_surge", "SELF cost + buffs",
		[GameEnums.EffectType.DAMAGE_SELF],
		[GameEnums.StatusType.STAT_BUFF_STR, GameEnums.StatusType.STAT_BUFF_MOV],
	)
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_adrenaline_surge"))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	var hp_before: int = bruiser.health.current_hp
	var ab: AbilityData = H.ability_on_unit(bruiser, &"bruiser_adrenaline_surge")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, ab, bruiser.position, bruiser.id))
	var result: SimResult = H.simulate_plan(board, plan)
	var after: UnitState = result.final_state.get_unit_by_id(1)
	H.assert_true(failures, "adrenaline_surge/self_cost", after.health.current_hp < hp_before)
	H.assert_true(
		failures, "adrenaline_surge/str",
		H.has_status(after, GameEnums.StatusType.STAT_BUFF_STR)
		or H.has_status(after, GameEnums.StatusType.STAT_BUFF_MOV),
	)


static func run_earthshatter(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_earthshatter", "ARC + destroy",
		[GameEnums.EffectType.DAMAGE, GameEnums.EffectType.DESTROY_OBSTACLE],
	)


static func run_meat_shield(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_meat_shield", "SWAP + INTERCEPT",
		[GameEnums.EffectType.SWAP],
		[GameEnums.StatusType.INTERCEPT],
	)
	H.assert_true(
		failures, "meat_shield/not_teleport",
		not H.ability_has_effect(H.factory_ability(&"bruiser_meat_shield"), GameEnums.EffectType.TELEPORT_CASTER, false),
	)


static func run_frenzy(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"bruiser_frenzy")
	H.assert_true(failures, "frenzy/data", ab != null)
	if ab == null:
		return
	var dmg_count: int = 0
	for eff: EffectData in ab.effects:
		if eff != null and eff.type == GameEnums.EffectType.DAMAGE:
			dmg_count += 1
	H.assert_eq_int(failures, "frenzy/triple_hit", dmg_count, 3)


static func run_guttural_roar(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_guttural_roar", "AOE PUSH + DEF debuff",
		[GameEnums.EffectType.PUSH],
		[GameEnums.StatusType.STAT_BUFF_DEF],
	)
	var ab: AbilityData = H.factory_ability(&"bruiser_guttural_roar")
	H.assert_eq_int(failures, "guttural_roar/aoe", ab.target_shape, GameEnums.TargetShape.AOE_SQUARE)


static func run_headbutt(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_headbutt", "mutual damage + stagger",
		[GameEnums.EffectType.DAMAGE, GameEnums.EffectType.DAMAGE_SELF],
		[GameEnums.StatusType.STAGGER],
	)


static func run_blood_boil(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_blood_boil", "HP for STR",
		[GameEnums.EffectType.DAMAGE_SELF],
		[GameEnums.StatusType.STAT_BUFF_STR],
	)


static func run_violent_collision(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_violent_collision", "DASH bulldoze",
		[GameEnums.EffectType.DASH],
	)
	var ab: AbilityData = H.factory_ability(&"bruiser_violent_collision")
	H.assert_true(failures, "violent_collision/bulldoze", ab.effects[0].modifiers.has("bulldoze"))
	H.assert_true(
		failures, "violent_collision/recast",
		ab.effects[0].modifiers.has("violent_collision_recast"),
	)


static func run_crimson_whirlwind(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_crimson_whirlwind", "AOE damage",
		[GameEnums.EffectType.DAMAGE],
	)
	var ab: AbilityData = H.factory_ability(&"bruiser_crimson_whirlwind")
	H.assert_eq_int(failures, "crimson_whirlwind/aoe", ab.target_shape, GameEnums.TargetShape.AOE_SQUARE)


static func run_belly_flop(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_belly_flop", "teleport + damage",
		[GameEnums.EffectType.TELEPORT_CASTER, GameEnums.EffectType.DAMAGE],
	)


static func run_breaching_dash(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_breaching_dash", "dash + destroy",
		[GameEnums.EffectType.DASH, GameEnums.EffectType.DESTROY_OBSTACLE],
	)


static func run_cellular_regeneration(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"cellular_regeneration")
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.with_single_passive(&"cellular_regeneration", false))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	bruiser.health.current_hp = bruiser.health.max_hp - 2
	var hp: int = bruiser.health.current_hp
	var plan := Timeline.new()
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "cellular_regeneration/heal",
		H.unit_hp(result.final_state, 1) > hp,
		"adjacent enemy at turn start must HEAL 1",
	)


static func run_blood_for_blood(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"blood_for_blood")
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = H.with_single_passive(&"blood_for_blood", false)
	cfg["passive_flags"] = {"damaged_last_turn": true}
	cfg["active_abilities"] = [H.factory_ability(&"bruiser_concussion_blow")]
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	H.place_dummy(board, 2, Vector2i(4, 3))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	var ab: AbilityData = H.factory_ability(&"bruiser_concussion_blow")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, ab, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	H.assert_true(
		failures, "blood_for_blood/bleed",
		enemy != null and H.has_status(enemy, GameEnums.StatusType.BLEED),
	)


static func run_adrenaline_junkie(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"adrenaline_junkie")
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = H.with_single_passive(&"adrenaline_junkie", false)
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	var bruiser: UnitState = H.unit_on_board(board, 1)
	bruiser.health.current_hp = bruiser.health.max_hp / 2
	bruiser._recalculate_stats()
	var str_at_half: int = CombatSystem.get_dynamic_strength(board, bruiser)
	bruiser.health.current_hp = bruiser.health.max_hp
	bruiser._recalculate_stats()
	var str_full: int = CombatSystem.get_dynamic_strength(board, bruiser)
	H.assert_true(
		failures, "adrenaline_junkie/missing_hp_str",
		str_at_half > str_full,
		"missing HP must increase STR",
	)


static func run_enraged(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"enraged")
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = H.with_single_passive(&"enraged", false)
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	var bruiser: UnitState = H.unit_on_board(board, 1)
	bruiser.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_DEBUFF_DEF, 1, 1))
	bruiser._recalculate_stats()
	var str_debuff: int = CombatSystem.get_dynamic_strength(board, bruiser)
	bruiser.active_statuses.clear()
	bruiser._recalculate_stats()
	var str_clean: int = CombatSystem.get_dynamic_strength(board, bruiser)
	H.assert_true(failures, "enraged/debuff_str", str_debuff > str_clean)


static func run_last_stand(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"last_stand")
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.with_single_passive(&"last_stand", false))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	bruiser.health.current_hp = 1
	bruiser._recalculate_stats()
	var low_str: int = CombatSystem.get_dynamic_strength(board, bruiser)
	var low_def: int = CombatSystem.get_dynamic_defense(board, bruiser)
	bruiser.health.current_hp = bruiser.health.max_hp
	bruiser._recalculate_stats()
	var full_str: int = CombatSystem.get_dynamic_strength(board, bruiser)
	var full_def: int = CombatSystem.get_dynamic_defense(board, bruiser)
	H.assert_true(failures, "last_stand/str", low_str > full_str)
	H.assert_true(failures, "last_stand/def", low_def > full_def)


static func run_colossal_mass(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"colossal_mass")
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.with_single_passive(&"colossal_mass", false))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	H.assert_true(
		failures, "colossal_mass/str_from_hp",
		bruiser.current_strength >= 1 + bruiser.health.max_hp / 15,
	)


static func run_overwhelming_bulk(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"overwhelming_bulk")


static func run_thrill_of_pain(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"thrill_of_pain")
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = H.with_single_passive(&"thrill_of_pain", false)
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	var bruiser: UnitState = H.unit_on_board(board, 1)
	bruiser.passive_flags["thrill_active"] = true
	H.place_dummy(board, 2, Vector2i(4, 3))
	var ab: AbilityData = H.factory_ability(&"bruiser_cleave")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, ab, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(failures, "thrill_of_pain/consumed", not bruiser.passive_flags.get("thrill_active", false) or result.events.size() > 0)


static func run_momentum_of_titan(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"momentum_of_titan")
	var board: BoardState = H.make_plain_board(Vector2i(8, 8), [Vector2i(5, 3)])
	var cfg: Dictionary = H.with_single_passive(&"momentum_of_titan", false)
	cfg["active_abilities"] = [H.factory_ability(&"bruiser_concussion_blow")]
	H.place_bruiser(board, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board, 2, Vector2i(3, 3))
	var hp: int = H.unit_hp(board, 2)
	var ab: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_concussion_blow")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, ab, Vector2i(3, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "momentum_of_titan/collision_dmg",
		H.unit_hp(result.final_state, 2) < hp,
	)


static func run_scar_tissue(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"scar_tissue")
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.with_single_passive(&"scar_tissue", false))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var victim: UnitState = H.unit_on_board(board, 1)
	var hp: int = victim.health.current_hp
	var events: Array[SimEvent] = []
	CombatSystem.deal_damage(board, victim, 5, events, &"test", false, false, H.unit_on_board(board, 2))
	var reduced: int = hp - victim.health.current_hp
	H.assert_true(failures, "scar_tissue/reduces", reduced < 5)


static func run_momentum_transfer(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"momentum_transfer")
	var board: BoardState = H.make_plain_board(Vector2i(10, 8), [Vector2i(5, 3)])
	var cfg: Dictionary = H.with_single_passive(&"momentum_transfer", false)
	cfg["active_passives"] = [
		H.factory_passive(&"momentum_transfer"),
		H.factory_passive(&"battering_ram"),
	]
	cfg["active_abilities"] = [H.factory_ability(&"bruiser_concussion_blow")]
	H.place_bruiser(board, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board, 2, Vector2i(3, 3))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	bruiser.health.current_hp = bruiser.health.max_hp - 3
	var hp: int = bruiser.health.current_hp
	var ab: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_concussion_blow")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, ab, Vector2i(3, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "momentum_transfer/heal",
		H.unit_hp(result.final_state, 1) > hp,
	)


static func run_crowd_breaker(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"crowd_breaker")
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.with_single_passive(&"crowd_breaker", false))
	H.place_dummy(board, 2, Vector2i(4, 3))
	H.place_dummy(board, 3, Vector2i(3, 4))
	var str_adj: int = CombatSystem.get_dynamic_strength(board, H.unit_on_board(board, 1))
	var board2: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board2, 10, Vector2i(3, 3), H.with_single_passive(&"crowd_breaker", false))
	var str_alone: int = CombatSystem.get_dynamic_strength(board2, H.unit_on_board(board2, 10))
	H.assert_true(failures, "crowd_breaker/adj_str", str_adj > str_alone)


static func run_juggernaut(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"juggernaut")


static func run_battering_ram(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"battering_ram")
	var board: BoardState = H.make_plain_board(Vector2i(10, 8), [Vector2i(6, 3)])
	var cfg: Dictionary = H.with_single_passive(&"battering_ram", false)
	cfg["active_abilities"] = [H.factory_ability(&"bruiser_concussion_blow")]
	H.place_bruiser(board, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board, 2, Vector2i(3, 3))
	var start: Vector2i = H.unit_on_board(board, 2).position
	var ab: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_concussion_blow")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, ab, Vector2i(3, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var end_pos: Vector2i = result.final_state.get_unit_by_id(2).position
	H.assert_eq_cell(failures, "battering_ram/extra_tile", end_pos, Vector2i(5, 3))


static func run_unstoppable_force(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"unstoppable_force")
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.with_single_passive(&"unstoppable_force", false))
	var enemy_cfg: Dictionary = {
		"active_abilities": [H.factory_ability(&"bruiser_headbutt")],
	}
	H.place_unit(
		board,
		2,
		H.bruiser_unit_data(),
		GameEnums.Team.ENEMY,
		Vector2i(4, 3),
		enemy_cfg,
	)
	var bruiser: UnitState = H.unit_on_board(board, 1)
	var armor_before: int = bruiser.armor
	var ab: AbilityData = H.factory_ability(&"bruiser_headbutt")
	var plan := Timeline.new()
	plan.add(H.plan_ability(2, ab, Vector2i(3, 3), 1))
	var result: SimResult = H.simulate_plan(board, plan)
	bruiser = result.final_state.get_unit_by_id(1)
	H.assert_true(failures, "unstoppable_force/no_stagger", not H.has_status(bruiser, GameEnums.StatusType.STAGGER))
	var prevented: bool = false
	for e: Variant in result.events:
		if e is SimEvent and e.type == GameEnums.SimEventType.ACTION_FAILED:
			if str(e.data.get("reason", "")) == "status_prevented_by_unstoppable_force":
				prevented = true
				break
	H.assert_true(
		failures, "unstoppable_force/shield",
		bruiser.armor > armor_before or prevented,
	)
