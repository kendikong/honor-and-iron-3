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
	H.assert_true(
		failures, "concussion_blow/push",
		H.events_have_unit_pushed(result.events, 2),
	)
	var wall_board: BoardState = H.make_plain_board(Vector2i(8, 8), [Vector2i(5, 3)])
	H.place_bruiser(wall_board, 10, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_concussion_blow"))
	H.place_dummy(wall_board, 11, Vector2i(4, 3))
	var wall_skill: AbilityData = H.ability_on_unit(H.unit_on_board(wall_board, 10), &"bruiser_concussion_blow")
	var wall_plan := Timeline.new()
	wall_plan.add(H.plan_ability(10, wall_skill, Vector2i(4, 3), 11))
	var wall_result: SimResult = H.simulate_plan(wall_board, wall_plan)
	var wall_enemy: UnitState = wall_result.final_state.get_unit_by_id(11)
	H.assert_true(
		failures, "concussion_blow/wall_stagger",
		wall_enemy != null and H.has_status(wall_enemy, GameEnums.StatusType.STAGGER),
		"object_collision_stagger must STAGGER target on wall hit",
	)


static func run_concussion_blow_upgrade(failures: Array[String]) -> void:
	var cfg: Dictionary = H.with_upgraded_ability(
		H.bruiser_with_ability(&"bruiser_concussion_blow"),
		&"bruiser_concussion_blow",
	)
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(board, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board, 2, Vector2i(3, 3))
	H.place_dummy(board, 3, Vector2i(4, 3))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_concussion_blow")
	H.assert_true(
		failures, "concussion_blow/upgrade_mod",
		skill.upgraded_effects[1].modifiers.has("enemy_collision_stagger_both"),
	)
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(3, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var pushed: UnitState = result.final_state.get_unit_by_id(2)
	var blocker: UnitState = result.final_state.get_unit_by_id(3)
	H.assert_true(
		failures, "concussion_blow/upgrade_mutual_stagger",
		pushed != null and blocker != null
		and H.has_status(pushed, GameEnums.StatusType.STAGGER)
		and H.has_status(blocker, GameEnums.StatusType.STAGGER),
		"[+] enemy collision must STAGGER both units",
	)

static func run_cleave(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_cleave", "ARC DAMAGE",
		[GameEnums.EffectType.DAMAGE],
	)
	var ab: AbilityData = H.factory_ability(&"bruiser_cleave")
	H.assert_eq_int(failures, "cleave/shape", ab.target_shape, GameEnums.TargetShape.ARC)
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_cleave"))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var hp: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_cleave")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(failures, "cleave/hit", H.unit_hp(result.final_state, 2) < hp)
	var arc_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(arc_board, 10, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_cleave"))
	H.place_dummy(arc_board, 11, Vector2i(4, 3))
	H.place_dummy(arc_board, 12, Vector2i(4, 4))
	var hp_center: int = H.unit_hp(arc_board, 11)
	var hp_perp: int = H.unit_hp(arc_board, 12)
	var arc_skill: AbilityData = H.ability_on_unit(H.unit_on_board(arc_board, 10), &"bruiser_cleave")
	var arc_plan := Timeline.new()
	arc_plan.add(H.plan_ability(10, arc_skill, Vector2i(4, 3), 11))
	var arc_result: SimResult = H.simulate_plan(arc_board, arc_plan)
	H.assert_true(
		failures, "cleave/arc_center",
		H.unit_hp(arc_result.final_state, 11) < hp_center,
		"ARC center target must take damage",
	)
	H.assert_true(
		failures, "cleave/arc_perp",
		H.unit_hp(arc_result.final_state, 12) < hp_perp,
		"ARC perpendicular tile must take damage",
	)


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
	H.place_bruiser(board, 1, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_suplex"))
	H.place_dummy(board, 2, Vector2i(3, 4))
	var hp_before: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_suplex")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(3, 4), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	H.assert_eq_cell(failures, "suplex/behind_caster", enemy.position, Vector2i(3, 2))
	H.assert_true(failures, "suplex/damage", enemy.health.current_hp < hp_before)


static func run_suplex_upgrade(failures: Array[String]) -> void:
	var cfg: Dictionary = H.with_upgraded_ability(
		H.bruiser_with_ability(&"bruiser_suplex"),
		&"bruiser_suplex",
	)
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	var bruiser: UnitState = H.unit_on_board(board, 1)
	bruiser.health.current_hp = bruiser.health.max_hp
	H.place_dummy(board, 2, Vector2i(3, 4))
	var hp: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(bruiser, &"bruiser_suplex")
	H.assert_true(
		failures, "suplex/upgrade_mod",
		skill.upgraded_effects[0].modifiers.has("bonus_dmg_per_10_hp"),
	)
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(3, 4), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var dmg_up: int = hp - H.unit_hp(result.final_state, 2)
	var board_base: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board_base, 10, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_suplex"))
	var bruiser_base: UnitState = H.unit_on_board(board_base, 10)
	bruiser_base.health.current_hp = bruiser_base.health.max_hp
	H.place_dummy(board_base, 11, Vector2i(3, 4))
	var hp_base: int = H.unit_hp(board_base, 11)
	var base_skill: AbilityData = H.ability_on_unit(bruiser_base, &"bruiser_suplex")
	var plan_base := Timeline.new()
	plan_base.add(H.plan_ability(10, base_skill, Vector2i(3, 4), 11))
	var result_base: SimResult = H.simulate_plan(board_base, plan_base)
	var dmg_base: int = hp_base - H.unit_hp(result_base.final_state, 11)
	H.assert_true(
		failures, "suplex/upgrade_bonus_damage",
		dmg_up > dmg_base,
		"[+] bonus_dmg_per_10_hp must increase damage at full HP",
	)

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
	H.assert_eq_int(failures, "adrenaline_surge/self_cost", hp_before - after.health.current_hp, 5)
	H.assert_eq_int(failures, "adrenaline_surge/str", H.status_value(after, GameEnums.StatusType.STAT_BUFF_STR), 1)
	H.assert_eq_int(failures, "adrenaline_surge/mov", H.status_value(after, GameEnums.StatusType.STAT_BUFF_MOV), 1)
	var adj_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(adj_board, 10, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_adrenaline_surge"))
	H.place_dummy(adj_board, 11, Vector2i(4, 3))
	H.place_dummy(adj_board, 12, Vector2i(3, 4))
	var adj_bruiser: UnitState = H.unit_on_board(adj_board, 10)
	var adj_ab: AbilityData = H.ability_on_unit(adj_bruiser, &"bruiser_adrenaline_surge")
	H.assert_eq_int(
		failures, "adrenaline_surge/zero_ap_adjacent",
		AbilitySystem.get_action_point_cost(adj_bruiser, adj_ab, adj_board),
		0,
	)


static func run_earthshatter(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_earthshatter", "ARC + destroy",
		[GameEnums.EffectType.DAMAGE, GameEnums.EffectType.DESTROY_OBSTACLE],
	)
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_earthshatter"))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var hp: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_earthshatter")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(failures, "earthshatter/hit", H.unit_hp(result.final_state, 2) < hp)
	var destroy_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(destroy_board, 10, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_earthshatter"))
	var construct_def: UnitData = DataLibrary.get_unit(&"construct_turret")
	H.place_unit(
		destroy_board, 11, construct_def, GameEnums.Team.ENEMY, Vector2i(4, 4), {},
	)
	var construct_hp: int = H.unit_hp(destroy_board, 11)
	var destroy_skill: AbilityData = H.ability_on_unit(
		H.unit_on_board(destroy_board, 10), &"bruiser_earthshatter",
	)
	var destroy_plan := Timeline.new()
	destroy_plan.add(H.plan_ability(10, destroy_skill, Vector2i(4, 3), 11))
	var destroy_result: SimResult = H.simulate_plan(destroy_board, destroy_plan)
	H.assert_true(
		failures, "earthshatter/destroy_construct",
		H.unit_hp(destroy_result.final_state, 11) < construct_hp,
		"DESTROY_OBSTACLE must kill construct in ARC",
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
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = H.bruiser_with_ability(&"bruiser_meat_shield")
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	H.place_bruiser(board, 3, Vector2i(4, 3), {"active_abilities": [DataLibrary.get_universal_run()]})
	var shield: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_meat_shield")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, shield, Vector2i(4, 3), 3))
	var result: SimResult = H.simulate_plan(board, plan)
	var bruiser: UnitState = result.final_state.get_unit_by_id(1)
	var ally: UnitState = result.final_state.get_unit_by_id(3)
	H.assert_eq_cell(failures, "meat_shield/swap_bruiser", bruiser.position, Vector2i(4, 3))
	H.assert_eq_cell(failures, "meat_shield/swap_ally", ally.position, Vector2i(3, 3))
	H.assert_true(
		failures, "meat_shield/intercept",
		H.has_status(bruiser, GameEnums.StatusType.INTERCEPT),
	)
	var expiry_board: BoardState = result.final_state.clone()
	var advanced: SimResult = Simulator.simulate(expiry_board, Timeline.new())
	var mid_bruiser: UnitState = advanced.final_state.get_unit_by_id(1)
	H.assert_true(
		failures, "meat_shield/intercept_persists",
		mid_bruiser != null and H.has_status(mid_bruiser, GameEnums.StatusType.INTERCEPT),
		"INTERCEPT must remain active until turn boundary",
	)
	advanced = Simulator.simulate(advanced.final_state, Timeline.new())
	var expired_bruiser: UnitState = advanced.final_state.get_unit_by_id(1)
	H.assert_true(
		failures, "meat_shield/intercept_expires",
		expired_bruiser != null and not H.has_status(expired_bruiser, GameEnums.StatusType.INTERCEPT),
		"INTERCEPT must clear after turn boundary",
	)
	var redirect_board: BoardState = result.final_state
	H.place_unit(
		redirect_board,
		11,
		H.bruiser_unit_data(),
		GameEnums.Team.ENEMY,
		Vector2i(2, 3),
		{
			"active_abilities": [H.factory_ability(&"bruiser_headbutt")],
			"active_passives": [],
		},
	)
	var attacker: UnitState = redirect_board.get_unit_by_id(11)
	H.assert_true(
		failures, "meat_shield/no_crowd_breaker",
		attacker != null and not attacker.has_passive(&"crowd_breaker"),
		"redirect baseline must not include crowd_breaker splash",
	)
	var solo_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(
		solo_board, 30, Vector2i(3, 3), {"active_abilities": [DataLibrary.get_universal_run()]},
	)
	H.place_unit(
		solo_board,
		31,
		H.bruiser_unit_data(),
		GameEnums.Team.ENEMY,
		Vector2i(2, 3),
		{
			"active_abilities": [H.factory_ability(&"bruiser_headbutt")],
			"active_passives": [],
		},
	)
	var solo_attack: AbilityData = H.factory_ability(&"bruiser_headbutt")
	var solo_plan := Timeline.new()
	solo_plan.add(H.plan_ability(31, solo_attack, Vector2i(3, 3), 30))
	var solo_result: SimResult = H.simulate_plan(solo_board, solo_plan)
	var solo_incoming: int = H.sum_unit_incoming_damage_events(solo_result.events, 30)
	var attack_ab: AbilityData = H.factory_ability(&"bruiser_headbutt")
	var attack_plan := Timeline.new()
	attack_plan.add(H.plan_ability(11, attack_ab, Vector2i(3, 3), 3))
	var attack_result: SimResult = H.simulate_plan(redirect_board, attack_plan)
	var ally_after: UnitState = attack_result.final_state.get_unit_by_id(3)
	var ally_incoming: int = H.sum_unit_incoming_damage_events(attack_result.events, 3)
	var bruiser_incoming: int = H.sum_unit_incoming_damage_events(attack_result.events, 1)
	var ally_hp_split: int = H.sum_unit_hp_damage_events(attack_result.events, 3)
	H.assert_true(
		failures, "meat_shield/redirect_ally",
		ally_after != null and ally_hp_split > 0,
	)
	H.assert_true(
		failures, "meat_shield/interceptor_took",
		bruiser_incoming > 0,
		"INTERCEPT must route damage to the caster",
	)
	H.assert_true(
		failures, "meat_shield/ally_protected",
		ally_incoming < solo_incoming,
		"intercept must reduce ally incoming damage",
	)
	H.assert_eq_int(
		failures, "meat_shield/redirect_half",
		ally_incoming,
		bruiser_incoming,
	)
	var split_total: int = ally_incoming + bruiser_incoming
	H.assert_true(
		failures, "meat_shield/redirect_total",
		split_total > 0 and split_total <= solo_incoming,
		"intercept splits damage; post-mitigation total cannot exceed solo baseline",
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
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_frenzy"))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var hp: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_frenzy")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(failures, "frenzy/damage", H.unit_hp(result.final_state, 2) < hp)
	H.assert_eq_int(
		failures, "frenzy/hit_count",
		H.count_unit_hp_damage_events(result.events, 2),
		3,
	)


static func run_guttural_roar(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_guttural_roar", "AOE PUSH + DEF debuff",
		[GameEnums.EffectType.PUSH],
		[GameEnums.StatusType.STAT_DEBUFF_DEF],
	)
	var ab: AbilityData = H.factory_ability(&"bruiser_guttural_roar")
	H.assert_eq_int(failures, "guttural_roar/aoe", ab.target_shape, GameEnums.TargetShape.AOE_SQUARE)
	H.assert_eq_int(failures, "guttural_roar/aoe_size", ab.target_shape_size, 2)
	ab.ensure_targeting_flags_from_mode()
	H.assert_eq_int(failures, "guttural_roar/tile_targeting", ab.targeting_mode, GameEnums.TargetingMode.TILE)
	H.assert_true(failures, "guttural_roar/tile_flags", ab.has_targeting(GameEnums.TargetingFlags.TILE))
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_guttural_roar"))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var enemy_before: UnitState = H.unit_on_board(board, 2)
	var def_before: int = CombatSystem.get_dynamic_defense(board, enemy_before)
	var start: Vector2i = enemy_before.position
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_guttural_roar")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	H.assert_true(
		failures, "guttural_roar/push",
		enemy != null and enemy.position != start,
		"AOE PUSH must displace adjacent enemy",
	)
	var def_after: int = CombatSystem.get_dynamic_defense(result.final_state, enemy)
	H.assert_eq_int(
		failures, "guttural_roar/def_debuff",
		def_before - def_after,
		2,
	)
	var aoe_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(aoe_board, 10, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_guttural_roar"))
	H.place_dummy(aoe_board, 11, Vector2i(4, 3))
	H.place_dummy(aoe_board, 12, Vector2i(3, 4))
	var hp_side: int = H.unit_hp(aoe_board, 12)
	var aoe_skill: AbilityData = H.ability_on_unit(H.unit_on_board(aoe_board, 10), &"bruiser_guttural_roar")
	var aoe_plan := Timeline.new()
	aoe_plan.add(H.plan_ability(10, aoe_skill, Vector2i(4, 3), 11))
	var aoe_result: SimResult = H.simulate_plan(aoe_board, aoe_plan)
	var side_enemy: UnitState = aoe_result.final_state.get_unit_by_id(12)
	H.assert_true(
		failures, "guttural_roar/aoe_second",
		side_enemy != null
		and (
			H.unit_hp(aoe_result.final_state, 12) < hp_side
			or side_enemy.position != Vector2i(3, 4)
		),
		"AOE must PUSH or debuff multiple adjacent enemies",
	)

static func run_headbutt(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_headbutt", "mutual damage + stagger",
		[GameEnums.EffectType.DAMAGE, GameEnums.EffectType.DAMAGE_SELF],
		[GameEnums.StatusType.STAGGER],
	)
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_headbutt"))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var enemy_hp: int = H.unit_hp(board, 2)
	var bruiser_hp: int = H.unit_hp(board, 1)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_headbutt")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var enemy_damage: int = enemy_hp - H.unit_hp(result.final_state, 2)
	var self_damage: int = bruiser_hp - H.unit_hp(result.final_state, 1)
	var attacker: UnitState = H.unit_on_board(board, 1)
	var scaled_raw: int = CombatSystem.calculate_scaled_damage(
		attacker, 3, GameEnums.StatType.PHYSICAL, board,
	)
	var expected_enemy: int = H.damage_dealt_to_unit(board, 2, scaled_raw, attacker)
	H.assert_eq_int(failures, "headbutt/enemy_dmg", enemy_damage, expected_enemy)
	H.assert_eq_int(failures, "headbutt/self_dmg", self_damage, 1)
	var enemy_after: UnitState = result.final_state.get_unit_by_id(2)
	H.assert_true(
		failures, "headbutt/stagger",
		enemy_after != null and H.has_status(enemy_after, GameEnums.StatusType.STAGGER),
		"headbutt must STAGGER the target",
	)
	var bruiser_after: UnitState = result.final_state.get_unit_by_id(1)
	H.assert_true(
		failures, "headbutt/self_stagger",
		bruiser_after != null and H.has_status(bruiser_after, GameEnums.StatusType.STAGGER),
		"headbutt must STAGGER the caster",
	)


static func run_blood_boil(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_blood_boil", "HP for STR",
		[GameEnums.EffectType.DAMAGE_SELF],
		[GameEnums.StatusType.STAT_BUFF_STR],
	)
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_blood_boil"))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	var hp_before: int = bruiser.health.current_hp
	var skill: AbilityData = H.ability_on_unit(bruiser, &"bruiser_blood_boil")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, bruiser.position, bruiser.id))
	var result: SimResult = H.simulate_plan(board, plan)
	var after: UnitState = result.final_state.get_unit_by_id(1)
	H.assert_eq_int(failures, "blood_boil/hp_cost", hp_before - after.health.current_hp, 5)
	H.assert_eq_int(failures, "blood_boil/str_value", H.status_value(after, GameEnums.StatusType.STAT_BUFF_STR), 3)


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
	var board: BoardState = H.make_plain_board(Vector2i(12, 6))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_violent_collision"))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_violent_collision")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), -1))
	var result: SimResult = H.simulate_plan(board, plan)
	var bruiser: UnitState = result.final_state.get_unit_by_id(1)
	H.assert_true(
		failures, "violent_collision/dash",
		bruiser != null and bruiser.position == Vector2i(4, 3),
	)


static func run_crimson_whirlwind(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_crimson_whirlwind", "AOE damage",
		[GameEnums.EffectType.DAMAGE],
	)
	var ab: AbilityData = H.factory_ability(&"bruiser_crimson_whirlwind")
	H.assert_eq_int(failures, "crimson_whirlwind/aoe", ab.target_shape, GameEnums.TargetShape.AOE_SQUARE)
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_crimson_whirlwind"))
	H.place_dummy(board, 2, Vector2i(4, 3))
	H.place_dummy(board, 3, Vector2i(3, 4))
	var hp2: int = H.unit_hp(board, 2)
	var hp3: int = H.unit_hp(board, 3)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_crimson_whirlwind")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "crimson_whirlwind/multi_hit",
		H.unit_hp(result.final_state, 2) < hp2 and H.unit_hp(result.final_state, 3) < hp3,
		"AOE must damage multiple adjacent enemies",
	)


static func run_belly_flop(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_belly_flop", "teleport + damage",
		[GameEnums.EffectType.TELEPORT_CASTER, GameEnums.EffectType.DAMAGE],
	)
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = H.bruiser_with_ability(&"bruiser_belly_flop")
	cfg["passive_flags"] = {"training_unlimited_actions": true}
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	var bruiser_ap: UnitState = H.unit_on_board(board, 1)
	bruiser_ap.ability.max_points = 2
	bruiser_ap.ability.points_left = 2
	H.place_dummy(board, 2, Vector2i(5, 4))
	var hp: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_belly_flop")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(5, 3), -1))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_eq_cell(failures, "belly_flop/teleport", result.final_state.get_unit_by_id(1).position, Vector2i(5, 3))
	var damaged_adjacent := false
	for e: Variant in result.events:
		if e is SimEvent and e.type == GameEnums.SimEventType.UNIT_DAMAGED:
			if int(e.data.get("unit", -1)) == 2:
				damaged_adjacent = true
				break
	H.assert_true(
		failures, "belly_flop/adjacent_damage",
		damaged_adjacent or H.unit_hp(result.final_state, 2) < hp,
		"belly flop must DAMAGE enemies adjacent to landing tile",
	)


static func run_breaching_dash(failures: Array[String]) -> void:
	H.run_active_smoke(
		failures, &"bruiser_breaching_dash", "dash + destroy",
		[GameEnums.EffectType.DASH, GameEnums.EffectType.DESTROY_OBSTACLE],
	)
	var board: BoardState = H.make_plain_board(Vector2i(12, 6))
	H.place_bruiser(board, 1, Vector2i(4, 3), H.bruiser_with_ability(&"bruiser_breaching_dash"))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_breaching_dash")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(5, 3), -1))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_eq_cell(failures, "breaching_dash/lands", result.final_state.get_unit_by_id(1).position, Vector2i(5, 3))


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
	var neg_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(neg_board, 10, Vector2i(3, 3), {})
	H.place_dummy(neg_board, 11, Vector2i(4, 3))
	var neg_bruiser: UnitState = H.unit_on_board(neg_board, 10)
	neg_bruiser.health.current_hp = neg_bruiser.health.max_hp - 2
	var neg_hp: int = neg_bruiser.health.current_hp
	var neg_result: SimResult = H.simulate_plan(neg_board, Timeline.new())
	H.assert_eq_int(
		failures, "cellular_regeneration/no_passive",
		H.unit_hp(neg_result.final_state, 10),
		neg_hp,
	)
	H.assert_true(
		failures, "cellular_regeneration/heal",
		H.unit_hp(result.final_state, 1) == hp + 1,
		"adjacent enemy at turn start must HEAL exactly 1",
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
	var expected_bonus: int = floori(0.5 / 0.10)
	var str_at_half: int = CombatSystem.get_dynamic_strength(board, bruiser)
	var mov_at_half: int = bruiser.movement.max_points
	var plain_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(plain_board, 10, Vector2i(3, 3), {})
	var plain: UnitState = H.unit_on_board(plain_board, 10)
	plain.health.current_hp = plain.health.max_hp / 2
	plain._recalculate_stats()
	var str_plain: int = CombatSystem.get_dynamic_strength(plain_board, plain)
	var mov_plain: int = plain.movement.max_points
	H.assert_eq_int(failures, "adrenaline_junkie/str", str_at_half - str_plain, expected_bonus)
	H.assert_eq_int(failures, "adrenaline_junkie/mov", mov_at_half - mov_plain, expected_bonus)
	bruiser.health.current_hp = bruiser.health.max_hp
	bruiser._recalculate_stats(board)
	var str_full: int = CombatSystem.get_dynamic_strength(board, bruiser)
	var mov_full: int = bruiser.movement.max_points
	plain.health.current_hp = plain.health.max_hp
	plain._recalculate_stats(plain_board)
	H.assert_eq_int(failures, "adrenaline_junkie/full_hp_str", str_full - CombatSystem.get_dynamic_strength(plain_board, plain), 0)
	H.assert_eq_int(failures, "adrenaline_junkie/full_hp_mov", mov_full - plain.movement.max_points, 0)
	bruiser.health.current_hp = ceili(float(bruiser.health.max_hp) * 0.10)
	bruiser._recalculate_stats(board)
	var expected_nine: int = floori(0.9 / 0.10)
	H.assert_eq_int(
		failures, "adrenaline_junkie/ninety_pct_missing",
		CombatSystem.get_dynamic_strength(board, bruiser) - str_full,
		expected_nine,
	)


static func run_enraged(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"enraged")
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = H.with_single_passive(&"enraged", false)
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	var bruiser: UnitState = H.unit_on_board(board, 1)
	bruiser.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_DEBUFF_DEF, 1, 1))
	bruiser._recalculate_stats(board)
	var str_debuff: int = CombatSystem.get_dynamic_strength(board, bruiser)
	bruiser.active_statuses.clear()
	bruiser._recalculate_stats(board)
	var str_clean: int = CombatSystem.get_dynamic_strength(board, bruiser)
	H.assert_eq_int(failures, "enraged/debuff_str", str_debuff - str_clean, 1)
	bruiser.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_DEBUFF_DEF, 1, 1))
	bruiser.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_DEBUFF_DEF, 2, 1))
	bruiser._recalculate_stats(board)
	var str_dup: int = CombatSystem.get_dynamic_strength(board, bruiser)
	H.assert_eq_int(failures, "enraged/unique_debuff", str_dup - str_clean, 1)
	var plain_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(plain_board, 10, Vector2i(3, 3), {})
	var plain: UnitState = H.unit_on_board(plain_board, 10)
	plain.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_DEBUFF_DEF, 1, 1))
	plain._recalculate_stats(plain_board)
	var str_plain_debuff: int = CombatSystem.get_dynamic_strength(plain_board, plain)
	plain.active_statuses.clear()
	plain._recalculate_stats(plain_board)
	var str_plain_clean: int = CombatSystem.get_dynamic_strength(plain_board, plain)
	H.assert_eq_int(failures, "enraged/debuff_no_passive", str_plain_debuff - str_plain_clean, 0)
	bruiser.active_statuses.clear()
	bruiser.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_DEBUFF_DEF, 1, 1))
	bruiser.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_DEBUFF_MOV, 1, 1))
	bruiser._recalculate_stats(board)
	var str_two_types: int = CombatSystem.get_dynamic_strength(board, bruiser)
	H.assert_eq_int(failures, "enraged/two_unique_debuffs", str_two_types - str_clean, 2)
	var hazard_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.set_tile_trap(hazard_board, Vector2i(3, 3))
	H.place_bruiser(hazard_board, 20, Vector2i(3, 3), cfg)
	var str_hazard: int = CombatSystem.get_dynamic_strength(hazard_board, H.unit_on_board(hazard_board, 20))
	var plain_trap_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.set_tile_trap(plain_trap_board, Vector2i(3, 3))
	H.place_bruiser(plain_trap_board, 21, Vector2i(3, 3), {})
	var str_plain_trap: int = CombatSystem.get_dynamic_strength(
		plain_trap_board, H.unit_on_board(plain_trap_board, 21),
	)
	H.assert_eq_int(failures, "enraged/hazard_str", str_hazard - str_plain_trap, 1)


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
	H.assert_eq_int(failures, "last_stand/str_bonus", low_str - full_str, 2)
	H.assert_eq_int(failures, "last_stand/def_bonus", low_def - full_def, 2)
	var neg_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(neg_board, 10, Vector2i(3, 3), {})
	var plain: UnitState = H.unit_on_board(neg_board, 10)
	plain.health.current_hp = 1
	plain._recalculate_stats()
	var plain_low_str: int = CombatSystem.get_dynamic_strength(neg_board, plain)
	var plain_low_def: int = CombatSystem.get_dynamic_defense(neg_board, plain)
	plain.health.current_hp = plain.health.max_hp
	plain._recalculate_stats()
	var plain_full_str: int = CombatSystem.get_dynamic_strength(neg_board, plain)
	var plain_full_def: int = CombatSystem.get_dynamic_defense(neg_board, plain)
	H.assert_eq_int(failures, "last_stand/no_passive_str", plain_low_str - plain_full_str, 0)
	H.assert_eq_int(failures, "last_stand/no_passive_def", plain_low_def - plain_full_def, 0)
	var boundary_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(boundary_board, 20, Vector2i(3, 3), H.with_single_passive(&"last_stand", false))
	var boundary: UnitState = H.unit_on_board(boundary_board, 20)
	boundary.health.current_hp = ceili(float(boundary.health.max_hp) * 0.25)
	boundary._recalculate_stats()
	var boundary_str: int = CombatSystem.get_dynamic_strength(boundary_board, boundary)
	boundary.health.current_hp = boundary.health.max_hp
	boundary._recalculate_stats()
	var boundary_full_str: int = CombatSystem.get_dynamic_strength(boundary_board, boundary)
	H.assert_eq_int(failures, "last_stand/boundary_off", boundary_str - boundary_full_str, 0)


static func run_colossal_mass(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"colossal_mass")
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.with_single_passive(&"colossal_mass", false))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	var expected_bonus: int = floori(float(bruiser.health.max_hp) / 15.0)
	var str_with: int = CombatSystem.get_dynamic_strength(board, bruiser)
	var plain_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(plain_board, 10, Vector2i(3, 3), {})
	var str_plain: int = CombatSystem.get_dynamic_strength(plain_board, H.unit_on_board(plain_board, 10))
	H.assert_eq_int(failures, "colossal_mass/str_bonus", str_with - str_plain, expected_bonus)
	bruiser.health.current_hp = 1
	bruiser._recalculate_stats(board)
	var str_wounded: int = CombatSystem.get_dynamic_strength(board, bruiser)
	H.assert_eq_int(failures, "colossal_mass/max_hp_not_current", str_wounded, str_with)


static func run_overwhelming_bulk(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"overwhelming_bulk")
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.with_single_passive(&"overwhelming_bulk", false))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	var enemy: UnitState = H.unit_on_board(board, 2)
	enemy.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, 20))
	enemy._recalculate_stats()
	enemy.health.max_hp = 10
	enemy.health.current_hp = 10
	H.assert_true(
		failures, "overwhelming_bulk/precond",
		bruiser.health.current_hp > enemy.health.max_hp,
		"bruiser current HP must exceed enemy max HP for pierce",
	)
	var hp_before: int = enemy.health.current_hp
	var events: Array[SimEvent] = []
	CombatSystem.deal_damage_raw(
		board, bruiser, enemy, 8, GameEnums.StatType.PHYSICAL, events, "bulk_test",
	)
	var dmg_bulk: int = hp_before - enemy.health.current_hp
	var board2: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board2, 10, Vector2i(3, 3), {})
	H.place_dummy(board2, 11, Vector2i(4, 3))
	var bruiser2: UnitState = H.unit_on_board(board2, 10)
	var enemy2: UnitState = H.unit_on_board(board2, 11)
	enemy2.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, 20))
	enemy2._recalculate_stats()
	enemy2.health.max_hp = 10
	enemy2.health.current_hp = 10
	var hp2: int = enemy2.health.current_hp
	var events2: Array[SimEvent] = []
	CombatSystem.deal_damage_raw(
		board2, bruiser2, enemy2, 8, GameEnums.StatType.PHYSICAL, events2, "bulk_test",
	)
	var dmg_plain: int = hp2 - enemy2.health.current_hp
	H.assert_true(failures, "overwhelming_bulk/pierce_deals", dmg_bulk > 0)
	H.assert_true(
		failures, "overwhelming_bulk/pierce",
		dmg_bulk > dmg_plain,
		"attacker HP > target Max HP must pierce DEF and deal more damage",
	)


static func run_thrill_of_pain(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"thrill_of_pain")
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.with_single_passive(&"thrill_of_pain", false))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	var enemy: UnitState = H.unit_on_board(board, 2)
	H.assert_true(
		failures, "thrill_of_pain/inactive",
		not bruiser.passive_flags.get("thrill_active", false),
	)
	var trigger_events: Array[SimEvent] = []
	CombatSystem.deal_damage(board, bruiser, 3, trigger_events, &"physical", false, false, enemy)
	H.assert_true(
		failures, "thrill_of_pain/on_damage_active",
		bruiser.passive_flags.get("thrill_active", false),
	)
	var hp: int = enemy.health.current_hp
	var base_scaled: int = CombatSystem.calculate_scaled_damage(
		bruiser, 2, GameEnums.StatType.PHYSICAL, board,
	)
	var events: Array[SimEvent] = []
	CombatSystem.deal_damage_raw(
		board, bruiser, enemy, base_scaled, GameEnums.StatType.PHYSICAL, events, "thrill_test", 2,
	)
	var dmg_thrill: int = hp - enemy.health.current_hp
	var board_base: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board_base, 10, Vector2i(3, 3), H.with_single_passive(&"thrill_of_pain", false))
	H.place_dummy(board_base, 11, Vector2i(4, 3))
	var bruiser_base: UnitState = H.unit_on_board(board_base, 10)
	var enemy_base: UnitState = H.unit_on_board(board_base, 11)
	var hp_base: int = enemy_base.health.current_hp
	var events_base: Array[SimEvent] = []
	CombatSystem.deal_damage_raw(
		board_base, bruiser_base, enemy_base,
		base_scaled, GameEnums.StatType.PHYSICAL, events_base, "base", 2,
	)
	var dmg_no_thrill: int = hp_base - enemy_base.health.current_hp
	var expected_delta: int = (
		CombatSystem.calculate_scaled_damage(bruiser, 4, GameEnums.StatType.PHYSICAL, board)
		- base_scaled
	)
	H.assert_eq_int(failures, "thrill_of_pain/bonus_damage", dmg_thrill - dmg_no_thrill, expected_delta)
	H.assert_true(
		failures, "thrill_of_pain/consumed",
		not bruiser.passive_flags.get("thrill_active", false),
	)
	H.assert_true(
		failures, "thrill_of_pain/push",
		board.pending_pushes.size() > 0,
		"thrill attack must enqueue a PUSH on the target",
	)
	var self_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(self_board, 20, Vector2i(3, 3), H.with_single_passive(&"thrill_of_pain", false))
	var self_bruiser: UnitState = H.unit_on_board(self_board, 20)
	var self_events: Array[SimEvent] = []
	CombatSystem.deal_damage(self_board, self_bruiser, 4, self_events, &"physical", false, false, null, "self")
	H.assert_true(
		failures, "thrill_of_pain/self_damage_active",
		self_bruiser.passive_flags.get("thrill_active", false),
	)


static func run_momentum_of_titan(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"momentum_of_titan")
	var board: BoardState = H.make_plain_board(Vector2i(8, 8), [Vector2i(4, 3)])
	var cfg: Dictionary = H.with_single_passive(&"momentum_of_titan", false)
	cfg["active_abilities"] = [H.factory_ability(&"bruiser_concussion_blow")]
	H.place_bruiser(board, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board, 2, Vector2i(3, 3))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	var expected_bonus: int = floori(float(bruiser.health.max_hp) * 0.10)
	var hp: int = H.unit_hp(board, 2)
	var ab: AbilityData = H.ability_on_unit(bruiser, &"bruiser_concussion_blow")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, ab, Vector2i(3, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var dmg_with: int = hp - H.unit_hp(result.final_state, 2)
	var board_plain: BoardState = H.make_plain_board(Vector2i(8, 8), [Vector2i(4, 3)])
	H.place_bruiser(
		board_plain, 10, Vector2i(2, 3),
		{"active_abilities": [H.factory_ability(&"bruiser_concussion_blow")]},
	)
	H.place_dummy(board_plain, 11, Vector2i(3, 3))
	var hp_plain: int = H.unit_hp(board_plain, 11)
	var ab_plain: AbilityData = H.ability_on_unit(H.unit_on_board(board_plain, 10), &"bruiser_concussion_blow")
	var plan_plain := Timeline.new()
	plan_plain.add(H.plan_ability(10, ab_plain, Vector2i(3, 3), 11))
	var result_plain: SimResult = H.simulate_plan(board_plain, plan_plain)
	var dmg_plain: int = hp_plain - H.unit_hp(result_plain.final_state, 11)
	H.assert_true(
		failures, "momentum_of_titan/collision_dmg",
		dmg_with > dmg_plain,
		"PUSH wall collision must add max-HP-scaled damage with passive",
	)
	H.assert_true(
		failures, "momentum_of_titan/bonus_at_least",
		dmg_with - dmg_plain >= expected_bonus,
	)


static func run_scar_tissue(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"scar_tissue")
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.with_single_passive(&"scar_tissue", false))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var victim: UnitState = H.unit_on_board(board, 1)
	victim.health.current_hp = victim.health.max_hp - 10
	victim._recalculate_stats()
	var hp: int = victim.health.current_hp
	var events: Array[SimEvent] = []
	CombatSystem.deal_damage(board, victim, 8, events, &"physical", false, false, H.unit_on_board(board, 2))
	var reduced: int = hp - victim.health.current_hp
	H.assert_true(failures, "scar_tissue/reduces", reduced < 8)
	var plain_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(plain_board, 10, Vector2i(3, 3), {})
	H.place_dummy(plain_board, 11, Vector2i(4, 3))
	var plain_victim: UnitState = H.unit_on_board(plain_board, 10)
	plain_victim.health.current_hp = plain_victim.health.max_hp - 10
	plain_victim._recalculate_stats()
	var plain_hp: int = plain_victim.health.current_hp
	var plain_events: Array[SimEvent] = []
	CombatSystem.deal_damage(
		plain_board, plain_victim, 8, plain_events, &"physical", false, false, H.unit_on_board(plain_board, 11),
	)
	var plain_reduced: int = plain_hp - plain_victim.health.current_hp
	var scar_bonus: int = maxi(
		floori(float(victim.health.max_hp) / 20.0),
		floori(float(victim.health.max_hp - victim.health.current_hp) / 20.0),
	)
	H.assert_eq_int(
		failures, "scar_tissue/exact",
		plain_reduced - reduced,
		scar_bonus,
	)
	H.assert_true(
		failures, "scar_tissue/vs_plain",
		reduced < plain_reduced,
		"scar tissue must mitigate more than a bruiser without the passive (same damage, same missing HP)",
	)


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
	var cfg: Dictionary = H.with_single_passive(&"crowd_breaker", false)
	cfg["active_abilities"] = [H.factory_ability(&"bruiser_concussion_blow")]
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	H.place_dummy(board, 2, Vector2i(4, 3))
	H.place_dummy(board, 3, Vector2i(5, 3))
	var str_adj: int = CombatSystem.get_dynamic_strength(board, H.unit_on_board(board, 1))
	var hp_splash: int = H.unit_hp(board, 3)
	var ab: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_concussion_blow")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, ab, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var splash_dmg: int = hp_splash - H.unit_hp(result.final_state, 3)
	var board_plain: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(
		board_plain, 20, Vector2i(3, 3),
		{"active_abilities": [H.factory_ability(&"bruiser_concussion_blow")]},
	)
	H.place_dummy(board_plain, 21, Vector2i(4, 3))
	H.place_dummy(board_plain, 22, Vector2i(5, 3))
	var hp_plain_splash: int = H.unit_hp(board_plain, 22)
	var ab_plain: AbilityData = H.ability_on_unit(H.unit_on_board(board_plain, 20), &"bruiser_concussion_blow")
	var plan_plain := Timeline.new()
	plan_plain.add(H.plan_ability(20, ab_plain, Vector2i(4, 3), 21))
	var result_plain: SimResult = H.simulate_plan(board_plain, plan_plain)
	var splash_plain: int = hp_plain_splash - H.unit_hp(result_plain.final_state, 22)
	var board2: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board2, 10, Vector2i(3, 3), H.with_single_passive(&"crowd_breaker", false))
	var str_alone: int = CombatSystem.get_dynamic_strength(board2, H.unit_on_board(board2, 10))
	H.assert_eq_int(failures, "crowd_breaker/adj_str", str_adj - str_alone, 1)
	H.assert_eq_int(failures, "crowd_breaker/splash_amount", splash_dmg, 1)
	H.assert_true(
		failures, "crowd_breaker/splash_bonus",
		splash_dmg > splash_plain,
		"crowd breaker must add splash damage to adjacent targets",
	)


static func run_juggernaut(failures: Array[String]) -> void:
	H.assert_passive_registered(failures, &"juggernaut")
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.set_tile_trap(board, Vector2i(4, 3))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.with_single_passive(&"juggernaut", false))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	var hp: int = bruiser.health.current_hp
	GridSystem.set_occupant(board, Vector2i(3, 3), -1)
	bruiser.position = Vector2i(4, 3)
	GridSystem.set_occupant(board, Vector2i(4, 3), bruiser.id)
	var events: Array[SimEvent] = []
	TerrainSystem.apply_landing(board, bruiser, events)
	H.assert_true(
		failures, "juggernaut/trap_destroyed",
		H.events_have_terrain_changed(events, Vector2i(4, 3)),
	)
	H.assert_eq_int(failures, "juggernaut/no_trap_dmg", bruiser.health.current_hp, hp)
	var plain_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.set_tile_trap(plain_board, Vector2i(4, 3))
	H.place_bruiser(plain_board, 10, Vector2i(3, 3), {})
	var plain: UnitState = H.unit_on_board(plain_board, 10)
	var plain_hp: int = plain.health.current_hp
	GridSystem.set_occupant(plain_board, Vector2i(3, 3), -1)
	plain.position = Vector2i(4, 3)
	GridSystem.set_occupant(plain_board, Vector2i(4, 3), plain.id)
	var plain_events: Array[SimEvent] = []
	TerrainSystem.apply_landing(plain_board, plain, plain_events)
	H.assert_true(
		failures, "juggernaut/plain_takes_trap",
		plain.health.current_hp < plain_hp,
		"without juggernaut, trap landing must deal hazard damage",
	)


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
