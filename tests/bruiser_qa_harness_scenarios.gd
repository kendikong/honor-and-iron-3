class_name BruiserQaHarnessScenarios
extends RefCounted

## Per-row sim + factory asserts for Bruiser B6-LOCK matrix (rows 2–31).

const H := preload("res://tests/bruiser_qa_harness.gd")
const KH := preload("res://tests/knight_qa_harness.gd")


static func run_charge_strike(failures: Array[String]) -> void:
	## Bible: MOVE 2 | ATK 3 | PUSH 1 — class_abilities.txt § Charge Strike (Siegebreaker).
	H.run_active_smoke(
		failures, &"bruiser_charge_strike", "MOVE 2 | ATK 3 | PUSH 1",
		[GameEnums.EffectType.MOVE, GameEnums.EffectType.DAMAGE, GameEnums.EffectType.PUSH],
	)
	var factory_ab: AbilityData = H.factory_ability(&"bruiser_charge_strike")
	H.assert_eq_int(failures, "charge_strike/range", factory_ab.range_tiles, 2)
	var charge_effects := KH.compiled_effects(factory_ab)
	H.assert_eq_int(failures, "charge_strike/move_amount", charge_effects[0].amount, 2)
	H.assert_eq_int(failures, "charge_strike/dmg_amount", charge_effects[1].amount, 3)
	H.assert_eq_int(failures, "charge_strike/push_amount", charge_effects[2].amount, 1)
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(board, 1, Vector2i(1, 3), H.bruiser_with_ability(&"bruiser_charge_strike"))
	H.place_dummy(board, 2, Vector2i(3, 3))
	var bruiser_before: UnitState = H.unit_on_board(board, 1)
	var hp: int = H.unit_hp(board, 2)
	var ab: AbilityData = H.ability_on_unit(bruiser_before, &"bruiser_charge_strike")
	var plan := Timeline.new()
	plan.add(_plan_charge_strike(1, ab, Vector2i(2, 3), Vector2i(3, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var bruiser_after: UnitState = result.final_state.get_unit_by_id(1)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	H.assert_eq_cell(failures, "charge_strike/bruiser_pos", bruiser_after.position, Vector2i(2, 3))
	H.assert_eq_cell(failures, "charge_strike/enemy_pos", enemy.position, Vector2i(4, 3))
	H.assert_true(
		failures, "charge_strike/moved",
		H.events_actor_moved(result.events, 1),
		"Charge Strike must MOVE toward target before ATK",
	)
	var enemy_damage: int = hp - enemy.health.current_hp
	var scaled_raw: int = CombatSystem.calculate_scaled_damage(
		bruiser_before, 3, GameEnums.StatType.PHYSICAL, board,
	)
	var expected_enemy: int = H.damage_dealt_to_unit(board, 2, scaled_raw, bruiser_before)
	H.assert_eq_int(failures, "charge_strike/dmg_dealt", enemy_damage, expected_enemy)
	H.assert_eq_int(failures, "charge_strike/push_distance", H.event_push_distance(result.events, 2), 1)
	var far_board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(far_board, 10, Vector2i(1, 3), H.bruiser_with_ability(&"bruiser_charge_strike"))
	H.place_dummy(far_board, 11, Vector2i(5, 3))
	var far_ab: AbilityData = H.ability_on_unit(H.unit_on_board(far_board, 10), &"bruiser_charge_strike")
	var far_action: TimelineAction = _plan_charge_strike(10, far_ab, Vector2i(5, 3), Vector2i(5, 3), 11)
	H.assert_true(
		failures, "charge_strike/out_of_range",
		not AbilitySystem.can_use(far_board, far_action),
		"MOVE 2 then melee must reject a landing beyond MOVE range",
	)


static func _plan_charge_strike(
	actor_id: int,
	ability: AbilityData,
	land: Vector2i,
	enemy_pos: Vector2i,
	enemy_id: int,
) -> TimelineAction:
	var action: TimelineAction = H.plan_ability(actor_id, ability, land, -1)
	AbilitySystem.set_module_target(action, 0, land, -1)
	AbilitySystem.set_module_target(action, 1, enemy_pos, enemy_id)
	return action


static func run_concussion_blow(failures: Array[String]) -> void:
	## Bible: Concussion Blow — RANGE 1 | ATK 2 | PUSH 1 | object STAGGER; [+] mutual enemy STAGGER.
	H.run_active_smoke(
		failures, &"bruiser_concussion_blow", "RANGE 1 | ATK 2 | PUSH 1",
		[GameEnums.EffectType.DAMAGE, GameEnums.EffectType.PUSH],
	)
	var factory_ab: AbilityData = H.factory_ability(&"bruiser_concussion_blow")
	H.assert_eq_int(failures, "concussion_blow/range", factory_ab.range_tiles, 1)
	var concussion_effects := KH.compiled_effects(factory_ab)
	H.assert_eq_int(failures, "concussion_blow/dmg_amount", concussion_effects[0].amount, 2)
	H.assert_eq_int(failures, "concussion_blow/push_amount", concussion_effects[1].amount, 1)
	H.assert_true(
		failures, "concussion_blow/object_stagger_mod",
		factory_ab.modules[0].layers[0].object_collision_stagger,
	)
	H.assert_eq_int(
		failures, "concussion_blow/object_stagger_val",
		int(factory_ab.modules[0].layers[0].object_collision_stagger),
		1,
	)
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_concussion_blow"))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var bruiser_before: UnitState = H.unit_on_board(board, 1)
	var hp: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(bruiser_before, &"bruiser_concussion_blow")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var bruiser_after: UnitState = result.final_state.get_unit_by_id(1)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	H.assert_eq_cell(failures, "concussion_blow/bruiser_pos", bruiser_after.position, Vector2i(3, 3))
	H.assert_eq_cell(failures, "concussion_blow/enemy_pos", enemy.position, Vector2i(5, 3))
	var enemy_damage: int = hp - enemy.health.current_hp
	var scaled_raw: int = CombatSystem.calculate_scaled_damage(
		bruiser_before, 2, GameEnums.StatType.PHYSICAL, board,
	)
	var expected_enemy: int = H.damage_dealt_to_unit(board, 2, scaled_raw, bruiser_before)
	H.assert_eq_int(failures, "concussion_blow/dmg_dealt", enemy_damage, expected_enemy)
	H.assert_eq_int(failures, "concussion_blow/push_distance", H.event_push_distance(result.events, 2), 1)
	H.assert_true(
		failures, "concussion_blow/open_no_stagger",
		enemy != null and not H.has_status(enemy, GameEnums.StatusType.STAGGER),
		"open-board PUSH must not STAGGER without wall/collision",
	)
	var far_board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(far_board, 10, Vector2i(1, 3), H.bruiser_with_ability(&"bruiser_concussion_blow"))
	H.place_dummy(far_board, 11, Vector2i(3, 3))
	var far_ab: AbilityData = H.ability_on_unit(H.unit_on_board(far_board, 10), &"bruiser_concussion_blow")
	var far_action: TimelineAction = H.plan_ability(10, far_ab, Vector2i(3, 3), 11)
	H.assert_true(
		failures, "concussion_blow/out_of_range",
		not AbilitySystem.can_use(far_board, far_action),
		"RANGE 1 must reject non-adjacent targets",
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
		skill.upgraded_modules[0].layers[0].enemy_collision_stagger_both,
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
	## Bible: Cleave — RANGE 1 | ARC | ATK 2; [+] BLEED X (WPN) on all targets.
	H.run_active_smoke(
		failures, &"bruiser_cleave", "RANGE 1 | ARC | ATK 2",
		[GameEnums.EffectType.DAMAGE],
	)
	var factory_ab: AbilityData = H.factory_ability(&"bruiser_cleave")
	H.assert_eq_int(failures, "cleave/range", factory_ab.range_tiles, 1)
	H.assert_eq_int(failures, "cleave/shape", factory_ab.target_shape, GameEnums.TargetShape.ARC)
	H.assert_eq_int(failures, "cleave/dmg_amount", KH.compiled_effects(factory_ab)[0].amount, 2)
	H.assert_true(
		failures, "cleave/tile_flags",
		factory_ab.has_targeting(GameEnums.TargetingFlags.TILE)
		and factory_ab.has_targeting(GameEnums.TargetingFlags.ENEMY),
		"Cleave ARC must use TILE|ENEMY awaiting-input targeting (Volley pattern)",
	)
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_cleave"))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var bruiser_before: UnitState = H.unit_on_board(board, 1)
	var hp: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(bruiser_before, &"bruiser_cleave")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var bruiser_after: UnitState = result.final_state.get_unit_by_id(1)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	H.assert_eq_cell(failures, "cleave/bruiser_pos", bruiser_after.position, Vector2i(3, 3))
	var enemy_damage: int = hp - enemy.health.current_hp
	var scaled_raw: int = CombatSystem.calculate_scaled_damage(
		bruiser_before, 2, GameEnums.StatType.PHYSICAL, board,
	)
	var expected_enemy: int = H.damage_dealt_to_unit(board, 2, scaled_raw, bruiser_before)
	H.assert_eq_int(failures, "cleave/dmg_dealt", enemy_damage, expected_enemy)
	H.assert_true(
		failures, "cleave/base_no_bleed",
		not H.has_status(enemy, GameEnums.StatusType.BLEED),
		"base Cleave must not apply BLEED without upgrade",
	)
	var far_board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(far_board, 10, Vector2i(1, 3), H.bruiser_with_ability(&"bruiser_cleave"))
	H.place_dummy(far_board, 11, Vector2i(3, 3))
	var far_ab: AbilityData = H.ability_on_unit(H.unit_on_board(far_board, 10), &"bruiser_cleave")
	var far_action: TimelineAction = H.plan_ability(10, far_ab, Vector2i(3, 3), 11)
	H.assert_true(
		failures, "cleave/out_of_range",
		not AbilitySystem.can_use(far_board, far_action),
		"RANGE 1 must reject non-adjacent targets",
	)
	var arc_board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(arc_board, 10, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_cleave"))
	H.place_dummy(arc_board, 11, Vector2i(4, 3))
	H.place_dummy(arc_board, 12, Vector2i(4, 4))
	H.place_dummy(arc_board, 13, Vector2i(5, 3))
	var arc_bruiser: UnitState = H.unit_on_board(arc_board, 10)
	var hp_center: int = H.unit_hp(arc_board, 11)
	var hp_perp: int = H.unit_hp(arc_board, 12)
	var hp_outside: int = H.unit_hp(arc_board, 13)
	var arc_skill: AbilityData = H.ability_on_unit(arc_bruiser, &"bruiser_cleave")
	var arc_plan := Timeline.new()
	arc_plan.add(H.plan_ability(10, arc_skill, Vector2i(4, 3), 11))
	var arc_result: SimResult = H.simulate_plan(arc_board, arc_plan)
	var center_dmg: int = hp_center - H.unit_hp(arc_result.final_state, 11)
	var perp_dmg: int = hp_perp - H.unit_hp(arc_result.final_state, 12)
	var scaled_arc: int = CombatSystem.calculate_scaled_damage(
		arc_bruiser, 2, GameEnums.StatType.PHYSICAL, arc_board,
	)
	var expected_arc: int = H.damage_dealt_to_unit(arc_board, 11, scaled_arc, arc_bruiser)
	H.assert_eq_int(failures, "cleave/arc_center_dmg", center_dmg, expected_arc)
	H.assert_eq_int(failures, "cleave/arc_perp_dmg", perp_dmg, expected_arc)
	H.assert_eq_int(failures, "cleave/arc_outside", H.unit_hp(arc_result.final_state, 13), hp_outside)
	H.assert_grid_footprint_excludes(
		failures,
		"cleave/grid_arc",
		arc_board,
		Vector2i(3, 3),
		Vector2i(4, 3),
		GameEnums.TargetShape.ARC,
		1,
		Vector2i(5, 3),
	)
	var tile_board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(tile_board, 20, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_cleave"))
	H.place_dummy(tile_board, 21, Vector2i(4, 4))
	H.place_dummy(tile_board, 22, Vector2i(4, 2))
	var tile_bruiser: UnitState = H.unit_on_board(tile_board, 20)
	var hp_north: int = H.unit_hp(tile_board, 21)
	var hp_south: int = H.unit_hp(tile_board, 22)
	var tile_skill: AbilityData = H.ability_on_unit(tile_bruiser, &"bruiser_cleave")
	var tile_action: TimelineAction = TimelineAction.make_ability(20, tile_skill, Vector2i(4, 3), -1)
	H.assert_true(
		failures, "cleave/tile_aim/can_use",
		AbilitySystem.can_use(tile_board, tile_action),
		"empty ARC center tile must be a legal Cleave target",
	)
	var tile_plan := Timeline.new()
	tile_plan.add(tile_action)
	var tile_result: SimResult = H.simulate_plan(tile_board, tile_plan)
	var north_dmg: int = hp_north - H.unit_hp(tile_result.final_state, 21)
	var south_dmg: int = hp_south - H.unit_hp(tile_result.final_state, 22)
	var scaled_tile: int = CombatSystem.calculate_scaled_damage(
		tile_bruiser, 2, GameEnums.StatType.PHYSICAL, tile_board,
	)
	var expected_tile: int = H.damage_dealt_to_unit(tile_board, 21, scaled_tile, tile_bruiser)
	H.assert_eq_int(failures, "cleave/tile_aim/north_dmg", north_dmg, expected_tile)
	H.assert_eq_int(failures, "cleave/tile_aim/south_dmg", south_dmg, expected_tile)


static func run_suplex(failures: Array[String]) -> void:
	## Bible: Suplex — RANGE 1 | ATK 4 | THROW_BEHIND to empty tile behind caster; [+] +1 ATK per 10 current HP.
	H.run_active_smoke(
		failures, &"bruiser_suplex", "RANGE 1 | ATK 4 | THROW_BEHIND",
		[GameEnums.EffectType.THROW_BEHIND, GameEnums.EffectType.DAMAGE],
	)
	var factory_ab: AbilityData = H.factory_ability(&"bruiser_suplex")
	H.assert_eq_int(failures, "suplex/range", factory_ab.range_tiles, 1)
	H.assert_eq_int(
		failures, "suplex/primary",
		factory_ab.modules[0].primary_type, GameEnums.EffectType.THROW_BEHIND,
	)
	H.assert_eq_int(failures, "suplex/dmg_amount", KH.compiled_effects(factory_ab)[1].amount, 4)
	H.assert_true(
		failures, "suplex/not_swap",
		not H.ability_has_effect(factory_ab, GameEnums.EffectType.SWAP, false),
	)
	H.assert_true(
		failures, "suplex/throw_behind",
		H.ability_has_effect(factory_ab, GameEnums.EffectType.THROW_BEHIND, false),
	)
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_suplex"))
	H.place_dummy(board, 2, Vector2i(3, 4))
	var bruiser_before: UnitState = H.unit_on_board(board, 1)
	var hp_before: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(bruiser_before, &"bruiser_suplex")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(3, 4), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var bruiser_after: UnitState = result.final_state.get_unit_by_id(1)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	H.assert_eq_cell(failures, "suplex/bruiser_pos", bruiser_after.position, Vector2i(3, 3))
	H.assert_eq_cell(failures, "suplex/behind_caster", enemy.position, Vector2i(3, 2))
	var enemy_damage: int = hp_before - enemy.health.current_hp
	var dmg_math: Dictionary = H.first_damage_math(result.events)
	H.assert_eq_int(failures, "suplex/dmg_base_amt", int(dmg_math.get("base", -1)), 4)
	var expected_enemy: int = H.damage_dealt_to_unit(
		board, 2, int(dmg_math.get("final_raw", 0)), bruiser_before,
	)
	H.assert_eq_int(failures, "suplex/dmg_dealt", enemy_damage, expected_enemy)
	var throw_i: int = -1
	var dmg_i: int = -1
	for i: int in range(result.events.size()):
		var ev: SimEvent = result.events[i]
		if (
			throw_i < 0
			and ev.type == GameEnums.SimEventType.UNIT_MOVED
			and int(ev.data.get("unit", -1)) == 2
		):
			throw_i = i
		if (
			dmg_i < 0
			and ev.type == GameEnums.SimEventType.UNIT_DAMAGED
			and int(ev.data.get("unit", -1)) == 2
		):
			dmg_i = i
	H.assert_true(
		failures, "suplex/throw_then_damage",
		throw_i >= 0 and dmg_i > throw_i,
		"THROW_BEHIND must resolve before ATK 4",
	)
	var far_board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(far_board, 10, Vector2i(1, 3), H.bruiser_with_ability(&"bruiser_suplex"))
	H.place_dummy(far_board, 11, Vector2i(3, 3))
	var far_ab: AbilityData = H.ability_on_unit(H.unit_on_board(far_board, 10), &"bruiser_suplex")
	var far_action: TimelineAction = H.plan_ability(10, far_ab, Vector2i(3, 3), 11)
	H.assert_true(
		failures, "suplex/out_of_range",
		not AbilitySystem.can_use(far_board, far_action),
		"RANGE 1 must reject non-adjacent targets",
	)
	var blocked_board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(blocked_board, 20, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_suplex"))
	H.place_dummy(blocked_board, 21, Vector2i(3, 2))
	H.place_dummy(blocked_board, 22, Vector2i(3, 4))
	var blocked_skill: AbilityData = H.ability_on_unit(H.unit_on_board(blocked_board, 20), &"bruiser_suplex")
	var blocked_plan := Timeline.new()
	blocked_plan.add(H.plan_ability(20, blocked_skill, Vector2i(3, 4), 22))
	var blocked_result: SimResult = H.simulate_plan(blocked_board, blocked_plan)
	var blocked_enemy: UnitState = blocked_result.final_state.get_unit_by_id(22)
	H.assert_eq_cell(
		failures, "suplex/blocked_behind_pos",
		blocked_enemy.position,
		Vector2i(3, 4),
	)


static func run_suplex_upgrade(failures: Array[String]) -> void:
	var ab: AbilityData = H.factory_ability(&"bruiser_suplex")
	H.assert_true(
		failures, "suplex/upgrade/mod",
		ab.upgraded_modules[0].bonus_dmg_per_10_hp > 0,
	)
	H.assert_eq_int(
		failures, "suplex/upgrade/mod_val",
		ab.upgraded_modules[0].bonus_dmg_per_10_hp,
		1,
	)
	var cfg: Dictionary = H.with_upgraded_ability(
		H.bruiser_with_ability(&"bruiser_suplex"),
		&"bruiser_suplex",
	)
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	var bruiser: UnitState = H.unit_on_board(board, 1)
	bruiser.health.current_hp = bruiser.health.max_hp
	H.place_dummy(board, 2, Vector2i(3, 4))
	var hp: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(bruiser, &"bruiser_suplex")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(3, 4), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var dmg_up: int = hp - H.unit_hp(result.final_state, 2)
	var hp_tiers: int = floori(float(bruiser.health.current_hp) / 10.0)
	var up_math: Dictionary = H.first_damage_math(result.events)
	H.assert_eq_int(failures, "suplex/upgrade/dmg_base_amt", int(up_math.get("base", -1)), 4 + hp_tiers)
	var expected_up: int = H.damage_dealt_to_unit(
		board, 2, int(up_math.get("final_raw", 0)), bruiser,
	)
	H.assert_eq_int(failures, "suplex/upgrade/dmg_dealt", dmg_up, expected_up)
	var board_base: BoardState = H.make_plain_board(Vector2i(10, 8))
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
	var base_math: Dictionary = H.first_damage_math(result_base.events)
	H.assert_eq_int(failures, "suplex/upgrade/base_dmg_base_amt", int(base_math.get("base", -1)), 4)
	var expected_base: int = H.damage_dealt_to_unit(
		board_base, 11, int(base_math.get("final_raw", 0)), bruiser_base,
	)
	H.assert_eq_int(failures, "suplex/upgrade/base_dmg_dealt", dmg_base, expected_base)
	H.assert_true(
		failures, "suplex/upgrade_bonus_damage",
		dmg_up > dmg_base,
		"[+] bonus_dmg_per_10_hp must increase damage at full HP",
	)

static func run_adrenaline_surge(failures: Array[String]) -> void:
	## Bible: Adrenaline Surge — SELF | spend 5 HP | +1 MOV +1 STR next turn; 0 AP if 2+ adjacent enemies.
	H.run_active_smoke(
		failures, &"bruiser_adrenaline_surge", "SELF | spend 5 HP | +1 MOV +1 STR",
		[],
		[GameEnums.StatusType.STAT_BUFF_STR, GameEnums.StatusType.STAT_BUFF_MOV],
	)
	var factory_ab: AbilityData = H.factory_ability(&"bruiser_adrenaline_surge")
	H.assert_eq_int(failures, "adrenaline_surge/header_hp_cost", factory_ab.secondary_value, 5)
	H.assert_eq_int(
		failures, "adrenaline_surge/header_hp_resource",
		factory_ab.secondary_resource, GameEnums.CostResource.HP,
	)
	H.assert_eq_int(
		failures, "adrenaline_surge/zero_ap_threshold",
		factory_ab.cost_modifier_n,
		2,
	)
	H.assert_eq_int(failures, "adrenaline_surge/targeting", factory_ab.targeting_mode, GameEnums.TargetingMode.SELF)
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
	H.assert_eq_int(failures, "adrenaline_surge/no_same_turn_str", H.status_value(after, GameEnums.StatusType.STAT_BUFF_STR), 0)
	H.assert_eq_int(failures, "adrenaline_surge/no_same_turn_mov", H.status_value(after, GameEnums.StatusType.STAT_BUFF_MOV), 0)
	H.assert_eq_int(failures, "adrenaline_surge/next_turn_str", int(after.passive_flags.get("next_turn_str_bonus", 0)), 1)
	H.assert_eq_int(failures, "adrenaline_surge/next_turn_mov", int(after.passive_flags.get("next_turn_max_move_bonus", 0)), 1)
	for eff: EffectData in KH.compiled_effects(ab):
		if eff != null and eff.type in [
			GameEnums.EffectType.ADD_STATUS_SELF,
		] and eff.status_type in [
			GameEnums.StatusType.STAT_BUFF_STR,
			GameEnums.StatusType.STAT_BUFF_MOV,
		]:
			H.assert_eq_int(failures, "adrenaline_surge/buff_duration", eff.status_duration, 1)
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
	var solo_board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(solo_board, 20, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_adrenaline_surge"))
	H.place_dummy(solo_board, 21, Vector2i(4, 3))
	var solo_bruiser: UnitState = H.unit_on_board(solo_board, 20)
	var solo_ab: AbilityData = H.ability_on_unit(solo_bruiser, &"bruiser_adrenaline_surge")
	H.assert_true(
		failures, "adrenaline_surge/one_adjacent_pays_ap",
		AbilitySystem.get_action_point_cost(solo_bruiser, solo_ab, solo_board) > 0,
		"0 AP only when adjacent to 2+ enemies",
	)


static func run_earthshatter(failures: Array[String]) -> void:
	## Bible: Earthshatter — RANGE 1 | ARC | ATK 2 | destroy traps/cover in area.
	H.run_active_smoke(
		failures, &"bruiser_earthshatter", "RANGE 1 | ARC | ATK 2 | DESTROY",
		[GameEnums.EffectType.DAMAGE, GameEnums.EffectType.DESTROY_OBSTACLE],
	)
	var factory_ab: AbilityData = H.factory_ability(&"bruiser_earthshatter")
	H.assert_eq_int(failures, "earthshatter/range", factory_ab.range_tiles, 1)
	H.assert_eq_int(failures, "earthshatter/shape", factory_ab.target_shape, GameEnums.TargetShape.ARC)
	H.assert_eq_int(failures, "earthshatter/dmg_amount", KH.compiled_effects(factory_ab)[0].amount, 2)
	H.assert_true(
		failures, "earthshatter/destroy_effect",
		H.ability_has_effect(factory_ab, GameEnums.EffectType.DESTROY_OBSTACLE, false),
	)
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_earthshatter"))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var bruiser_before: UnitState = H.unit_on_board(board, 1)
	var hp: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(bruiser_before, &"bruiser_earthshatter")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_eq_cell(failures, "earthshatter/bruiser_pos", result.final_state.get_unit_by_id(1).position, Vector2i(3, 3))
	var enemy_damage: int = hp - H.unit_hp(result.final_state, 2)
	var dmg_math: Dictionary = H.first_damage_math(result.events)
	H.assert_eq_int(failures, "earthshatter/dmg_base_amt", int(dmg_math.get("base", -1)), 2)
	var expected_enemy: int = H.damage_dealt_to_unit(
		board, 2, int(dmg_math.get("final_raw", 0)), bruiser_before,
	)
	H.assert_eq_int(failures, "earthshatter/dmg_dealt", enemy_damage, expected_enemy)
	var far_board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(far_board, 10, Vector2i(1, 3), H.bruiser_with_ability(&"bruiser_earthshatter"))
	H.place_dummy(far_board, 11, Vector2i(3, 3))
	var far_ab: AbilityData = H.ability_on_unit(H.unit_on_board(far_board, 10), &"bruiser_earthshatter")
	var far_action: TimelineAction = H.plan_ability(10, far_ab, Vector2i(3, 3), 11)
	H.assert_true(
		failures, "earthshatter/out_of_range",
		not AbilitySystem.can_use(far_board, far_action),
	)
	var arc_board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(arc_board, 20, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_earthshatter"))
	H.place_dummy(arc_board, 21, Vector2i(4, 3))
	H.place_dummy(arc_board, 22, Vector2i(4, 4))
	H.place_dummy(arc_board, 23, Vector2i(5, 3))
	var arc_bruiser: UnitState = H.unit_on_board(arc_board, 20)
	var hp_center: int = H.unit_hp(arc_board, 21)
	var hp_perp: int = H.unit_hp(arc_board, 22)
	var hp_outside: int = H.unit_hp(arc_board, 23)
	var arc_skill: AbilityData = H.ability_on_unit(arc_bruiser, &"bruiser_earthshatter")
	var arc_plan := Timeline.new()
	arc_plan.add(H.plan_ability(20, arc_skill, Vector2i(4, 3), 21))
	var arc_result: SimResult = H.simulate_plan(arc_board, arc_plan)
	var center_dmg: int = hp_center - H.unit_hp(arc_result.final_state, 21)
	var perp_dmg: int = hp_perp - H.unit_hp(arc_result.final_state, 22)
	var arc_math: Dictionary = H.first_damage_math(arc_result.events)
	var expected_arc: int = H.damage_dealt_to_unit(
		arc_board, 21, int(arc_math.get("final_raw", 0)), arc_bruiser,
	)
	H.assert_eq_int(failures, "earthshatter/arc_center_dmg", center_dmg, expected_arc)
	H.assert_eq_int(failures, "earthshatter/arc_perp_dmg", perp_dmg, expected_arc)
	H.assert_eq_int(failures, "earthshatter/arc_outside", H.unit_hp(arc_result.final_state, 23), hp_outside)
	H.assert_grid_footprint_excludes(
		failures,
		"earthshatter/grid_arc",
		arc_board,
		Vector2i(3, 3),
		Vector2i(4, 3),
		GameEnums.TargetShape.ARC,
		1,
		Vector2i(5, 3),
	)
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
	var construct_after: UnitState = destroy_result.final_state.get_unit_by_id(11)
	H.assert_true(
		failures, "earthshatter/destroy_construct",
		construct_after == null or not construct_after.is_alive(),
		"DESTROY_OBSTACLE must kill construct in ARC",
	)


static func run_meat_shield(failures: Array[String]) -> void:
	## Bible: Meat Shield — RANGE 1 ally SWAP + INTERCEPT 50%; [+] RANGE 3 + STR per intercept.
	H.run_active_smoke(
		failures, &"bruiser_meat_shield", "RANGE 1 ally SWAP + INTERCEPT",
		[GameEnums.EffectType.SWAP],
		[GameEnums.StatusType.INTERCEPT],
	)
	var factory_ab: AbilityData = H.factory_ability(&"bruiser_meat_shield")
	H.assert_eq_int(failures, "meat_shield/range", factory_ab.range_tiles, 1)
	H.assert_eq_int(failures, "meat_shield/targeting", factory_ab.targeting_mode, GameEnums.TargetingMode.ALLY_UNIT)
	var intercept_layer: AbilityLayer = factory_ab.modules[0].layers[0]
	H.assert_true(
		failures,
		"meat_shield/intercept_layer",
		intercept_layer != null
			and intercept_layer.effect != null
			and intercept_layer.effect.type == GameEnums.EffectType.ADD_STATUS_SELF
			and intercept_layer.effect.status_duration == 1,
		"INTERCEPT must be authored on the module layer for one turn",
	)
	var upgraded_intercept: AbilityLayer = factory_ab.upgraded_modules[0].layers[0]
	H.assert_eq_int(
		failures,
		"meat_shield/intercept_grant_str",
		upgraded_intercept.intercept_grant_str,
		2,
	)
	H.assert_true(
		failures, "meat_shield/not_teleport",
		not H.ability_has_effect(factory_ab, GameEnums.EffectType.TELEPORT_CASTER, false),
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
	var post_board: BoardState = advanced.final_state.clone()
	H.place_unit(
		post_board,
		40,
		H.bruiser_unit_data(),
		GameEnums.Team.ENEMY,
		Vector2i(3, 2),
		{
			"active_abilities": [H.factory_ability(&"bruiser_concussion_blow")],
			"active_passives": [],
		},
	)
	var post_plan := Timeline.new()
	post_plan.add(H.plan_ability(40, H.factory_ability(&"bruiser_concussion_blow"), Vector2i(3, 3), 3))
	var post_result: SimResult = H.simulate_plan(post_board, post_plan)
	H.assert_eq_int(
		failures, "meat_shield/post_expiry/no_redirect",
		H.sum_unit_incoming_damage_events(post_result.events, 1),
		0,
	)
	var redirect_board: BoardState = result.final_state
	H.place_unit(
		redirect_board,
		11,
		H.bruiser_unit_data(),
		GameEnums.Team.ENEMY,
		Vector2i(3, 2),
		{
			"active_abilities": [H.factory_ability(&"bruiser_concussion_blow")],
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
			"active_abilities": [H.factory_ability(&"bruiser_concussion_blow")],
			"active_passives": [],
		},
	)
	var solo_attack: AbilityData = H.factory_ability(&"bruiser_concussion_blow")
	var solo_plan := Timeline.new()
	solo_plan.add(H.plan_ability(31, solo_attack, Vector2i(3, 3), 30))
	var solo_result: SimResult = H.simulate_plan(solo_board, solo_plan)
	var solo_incoming: int = H.sum_unit_incoming_damage_events(solo_result.events, 30)
	var attack_ab: AbilityData = H.factory_ability(&"bruiser_concussion_blow")
	var attack_plan := Timeline.new()
	attack_plan.add(H.plan_ability(11, attack_ab, Vector2i(3, 3), 3))
	var attack_result: SimResult = H.simulate_plan(redirect_board, attack_plan)
	var ally_after: UnitState = attack_result.final_state.get_unit_by_id(3)
	var ally_incoming: int = H.sum_unit_incoming_damage_events(attack_result.events, 3)
	var bruiser_incoming: int = H.sum_unit_incoming_damage_events(attack_result.events, 1)
	H.assert_true(
		failures, "meat_shield/redirect_ally",
		solo_incoming > 0
			and ally_after != null
			and ally_incoming > 0
			and bruiser_incoming > 0
			and ally_incoming == bruiser_incoming
			and ally_incoming < solo_incoming,
		"INTERCEPT must 50/50 split incoming damage vs solo baseline",
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
	var far_board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(far_board, 20, Vector2i(1, 3), H.bruiser_with_ability(&"bruiser_meat_shield"))
	H.place_bruiser(far_board, 21, Vector2i(4, 3), {"active_abilities": [DataLibrary.get_universal_run()]})
	var far_shield: AbilityData = H.ability_on_unit(H.unit_on_board(far_board, 20), &"bruiser_meat_shield")
	var far_action: TimelineAction = H.plan_ability(20, far_shield, Vector2i(4, 3), 21)
	H.assert_true(
		failures, "meat_shield/out_of_range",
		not AbilitySystem.can_use(far_board, far_action),
		"RANGE 1 must reject non-adjacent ally targets",
	)


static func run_frenzy(failures: Array[String]) -> void:
	## Bible: Frenzy — RANGE 1 | ATK 1 (3 times); [+] on kill gain 1 AP.
	H.run_active_smoke(
		failures, &"bruiser_frenzy", "RANGE 1 | ATK 1 x3",
		[GameEnums.EffectType.DAMAGE],
	)
	var ab: AbilityData = H.factory_ability(&"bruiser_frenzy")
	H.assert_eq_int(failures, "frenzy/range", ab.range_tiles, 1)
	H.assert_eq_int(failures, "frenzy/module_amount", ab.modules[0].amount, 1)
	H.assert_eq_int(failures, "frenzy/module_hit_count", ab.modules[0].hit_count, 3)
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_frenzy"))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var bruiser_before: UnitState = H.unit_on_board(board, 1)
	var hp: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(bruiser_before, &"bruiser_frenzy")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_eq_cell(failures, "frenzy/bruiser_pos", result.final_state.get_unit_by_id(1).position, Vector2i(3, 3))
	H.assert_eq_int(
		failures, "frenzy/hit_count",
		H.count_unit_hp_damage_events(result.events, 2),
		3,
	)
	var total_dmg: int = H.sum_unit_hp_damage_events(result.events, 2)
	H.assert_true(failures, "frenzy/damage", total_dmg > 0 and H.unit_hp(result.final_state, 2) < hp)
	var dmg_math: Dictionary = H.first_damage_math(result.events)
	H.assert_eq_int(failures, "frenzy/dmg_base_amt", int(dmg_math.get("base", -1)), 1)
	var expected_hit: int = H.damage_dealt_to_unit(
		board, 2, int(dmg_math.get("final_raw", 0)), bruiser_before,
	)
	H.assert_eq_int(failures, "frenzy/dmg_per_hit", total_dmg, expected_hit * 3)
	var far_board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(far_board, 10, Vector2i(1, 3), H.bruiser_with_ability(&"bruiser_frenzy"))
	H.place_dummy(far_board, 11, Vector2i(3, 3))
	var far_ab: AbilityData = H.ability_on_unit(H.unit_on_board(far_board, 10), &"bruiser_frenzy")
	var far_action: TimelineAction = H.plan_ability(10, far_ab, Vector2i(3, 3), 11)
	H.assert_true(
		failures, "frenzy/out_of_range",
		not AbilitySystem.can_use(far_board, far_action),
	)


static func run_guttural_roar(failures: Array[String]) -> void:
	## Bible: Guttural Roar — RANGE 0 | AOE 2 | PUSH 1 | DEF -2; [+] item push + collision ATK 1.
	H.run_active_smoke(
		failures, &"bruiser_guttural_roar", "RANGE 0 | AOE 2 | PUSH 1 | DEF -2",
		[GameEnums.EffectType.PUSH],
		[GameEnums.StatusType.STAT_DEBUFF_DEF],
	)
	var ab: AbilityData = H.factory_ability(&"bruiser_guttural_roar")
	H.assert_eq_int(failures, "guttural_roar/range", ab.range_tiles, 0)
	H.assert_eq_int(failures, "guttural_roar/aoe", ab.target_shape, GameEnums.TargetShape.AOE_SQUARE)
	H.assert_eq_int(failures, "guttural_roar/aoe_size", ab.target_shape_size, 2)
	var roar_effects := KH.compiled_effects(ab)
	H.assert_eq_int(failures, "guttural_roar/push_amount", roar_effects[0].amount, 1)
	H.assert_eq_int(failures, "guttural_roar/def_debuff_amount", roar_effects[1].amount, 2)
	ab.ensure_targeting_flags_from_mode()
	H.assert_eq_int(failures, "guttural_roar/self_targeting", ab.targeting_mode, GameEnums.TargetingMode.SELF)
	H.assert_true(failures, "guttural_roar/self_flags", ab.has_targeting(GameEnums.TargetingFlags.SELF))
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_guttural_roar"))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var enemy_before: UnitState = H.unit_on_board(board, 2)
	var def_before: int = CombatSystem.get_dynamic_defense(board, enemy_before)
	var start: Vector2i = enemy_before.position
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_guttural_roar")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(3, 3), 1))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_eq_cell(failures, "guttural_roar/bruiser_pos", result.final_state.get_unit_by_id(1).position, Vector2i(3, 3))
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
	var side_start: Vector2i = Vector2i(3, 4)
	var side_def_before: int = CombatSystem.get_dynamic_defense(aoe_board, H.unit_on_board(aoe_board, 12))
	var aoe_skill: AbilityData = H.ability_on_unit(H.unit_on_board(aoe_board, 10), &"bruiser_guttural_roar")
	var aoe_plan := Timeline.new()
	aoe_plan.add(H.plan_ability(10, aoe_skill, Vector2i(3, 3), 10))
	var aoe_result: SimResult = H.simulate_plan(aoe_board, aoe_plan)
	var side_enemy: UnitState = aoe_result.final_state.get_unit_by_id(12)
	var side_def_after: int = CombatSystem.get_dynamic_defense(aoe_result.final_state, side_enemy)
	H.assert_true(
		failures, "guttural_roar/aoe_second",
		side_enemy != null
		and (
			side_enemy.position != side_start
			or side_def_before - side_def_after >= 2
		),
		"AOE must PUSH or DEF-debuff multiple adjacent enemies from caster anchor",
	)

	var roar_footprint: Array[Vector2i] = GridSystem.get_affected_tiles(
		null, Vector2i(3, 3), Vector2i(3, 3), GameEnums.TargetShape.AOE_SQUARE, 2,
	)
	H.assert_true(
		failures, "guttural_roar/grid_diagonal",
		roar_footprint.has(Vector2i(4, 4)),
		"AOE 2 square must include diagonal tiles",
	)
	H.assert_true(
		failures, "guttural_roar/grid_outside",
		not roar_footprint.has(Vector2i(6, 3)),
		"AOE 2 square must exclude tiles beyond radius 2",
	)


static func run_headbutt(failures: Array[String]) -> void:
	## Bible: Headbutt — RANGE 1 | ATK 3 | mutual 1 dmg + STAGGER; [+] bonus % Max HP damage.
	H.run_active_smoke(
		failures, &"bruiser_headbutt", "RANGE 1 | ATK 3 | mutual STAGGER",
		[GameEnums.EffectType.DAMAGE, GameEnums.EffectType.DAMAGE_SELF],
		[GameEnums.StatusType.STAGGER],
	)
	var factory_ab: AbilityData = H.factory_ability(&"bruiser_headbutt")
	H.assert_eq_int(failures, "headbutt/range", factory_ab.range_tiles, 1)
	var headbutt_effects := KH.compiled_effects(factory_ab)
	H.assert_eq_int(failures, "headbutt/dmg_amount", headbutt_effects[0].amount, 3)
	H.assert_eq_int(failures, "headbutt/self_dmg_amount", headbutt_effects[1].amount, 1)
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
	H.assert_eq_cell(failures, "headbutt/bruiser_pos", result.final_state.get_unit_by_id(1).position, Vector2i(3, 3))
	var dmg_math: Dictionary = H.first_damage_math(result.events)
	H.assert_eq_int(failures, "headbutt/dmg_base_amt", int(dmg_math.get("base", -1)), 3)
	var expected_enemy: int = H.damage_dealt_to_unit(
		board, 2, int(dmg_math.get("final_raw", 0)), attacker,
	)
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
	var far_board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(far_board, 10, Vector2i(1, 3), H.bruiser_with_ability(&"bruiser_headbutt"))
	H.place_dummy(far_board, 11, Vector2i(3, 3))
	var far_ab: AbilityData = H.ability_on_unit(H.unit_on_board(far_board, 10), &"bruiser_headbutt")
	var far_action: TimelineAction = H.plan_ability(10, far_ab, Vector2i(3, 3), 11)
	H.assert_true(
		failures, "headbutt/out_of_range",
		not AbilitySystem.can_use(far_board, far_action),
		"RANGE 1 must reject non-adjacent targets",
	)


static func run_blood_boil(failures: Array[String]) -> void:
	## Bible: Blood Boil — SELF | spend 5 HP; next-turn attacks gain ATK +2 and BLEED WPN.
	H.run_active_smoke(
		failures, &"bruiser_blood_boil", "SELF | 5 HP for next-turn ATK + BLEED",
		[],
	)
	var factory_ab: AbilityData = H.factory_ability(&"bruiser_blood_boil")
	H.assert_eq_int(failures, "blood_boil/header_hp_cost", factory_ab.secondary_value, 5)
	H.assert_eq_int(failures, "blood_boil/header_hp_resource", factory_ab.secondary_resource, GameEnums.CostResource.HP)
	H.assert_eq_int(failures, "blood_boil/next_attack_strength", factory_ab.modules[0].next_attack_strength, 2)
	H.assert_true(failures, "blood_boil/next_attack_bleed", factory_ab.modules[0].next_attack_bleed_weapon)
	H.assert_true(failures, "blood_boil/next_turn", factory_ab.modules[0].next_turn)
	H.assert_eq_int(failures, "blood_boil/targeting", factory_ab.targeting_mode, GameEnums.TargetingMode.SELF)
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = H.bruiser_with_ability(&"bruiser_blood_boil")
	cfg["active_abilities"].append(H.factory_ability(&"bruiser_headbutt"))
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	H.place_dummy(board, 2, Vector2i(4, 3))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	var hp_before: int = bruiser.health.current_hp
	var skill: AbilityData = H.ability_on_unit(bruiser, &"bruiser_blood_boil")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, bruiser.position, bruiser.id))
	var result: SimResult = H.simulate_plan(board, plan)
	var after: UnitState = result.final_state.get_unit_by_id(1)
	H.assert_eq_int(failures, "blood_boil/hp_cost", hp_before - after.health.current_hp, 5)
	H.assert_eq_int(failures, "blood_boil/no_same_turn_str", H.status_value(after, GameEnums.StatusType.STAT_BUFF_STR), 0)
	H.assert_eq_int(
		failures, "blood_boil/pending_strength",
		int(after.passive_flags.get("next_turn_attack_strength_bonus", 0)), 2,
	)
	H.assert_true(
		failures, "blood_boil/pending_bleed",
		after.passive_flags.get("next_turn_attack_bleed_weapon", false),
	)
	H.simulate_plan(board, Timeline.new())
	var next_turn_actor: UnitState = board.get_unit_by_id(1)
	H.assert_eq_int(
		failures, "blood_boil/promoted_strength",
		int(next_turn_actor.passive_flags.get("next_attack_strength_bonus", 0)), 2,
	)
	H.assert_true(
		failures, "blood_boil/promoted_bleed",
		next_turn_actor.passive_flags.get("next_attack_bleed_weapon", false),
	)
	next_turn_actor.turn_action_used = false
	next_turn_actor.ability.points_left = next_turn_actor.ability.max_points
	var basic: AbilityData = H.ability_on_unit(next_turn_actor, &"bruiser_headbutt")
	H.assert_true(failures, "blood_boil/attack_loaded", basic != null)
	var attack_plan := Timeline.new()
	attack_plan.add(H.plan_ability(1, basic, Vector2i(4, 3), 2))
	var attack_result: SimResult = H.simulate_plan(board, attack_plan)
	H.assert_true(
		failures, "blood_boil/attack_used",
		H.events_have_ability(attack_result.events, &"bruiser_headbutt"),
	)
	H.assert_true(
		failures, "blood_boil/attack_damaged",
		H.events_have_type(attack_result.events, GameEnums.SimEventType.UNIT_DAMAGED),
	)
	var bleed_applied := false
	for event: SimEvent in attack_result.events:
		if (
			event.type == GameEnums.SimEventType.STATUS_APPLIED
			and event.data.get("status_type") == GameEnums.StatusType.BLEED
		):
			bleed_applied = true
			break
	H.assert_true(failures, "blood_boil/attack_bleed", bleed_applied)


static func run_violent_collision(failures: Array[String]) -> void:
	## Bible: Violent Collision — MOVE 3 | bulldoze + recast MOVE 2; [+] collision STAGGER.
	H.run_active_smoke(
		failures, &"bruiser_violent_collision", "DASH 3 | bulldoze + recast",
		[GameEnums.EffectType.DASH],
	)
	var ab: AbilityData = H.factory_ability(&"bruiser_violent_collision")
	H.assert_eq_int(failures, "violent_collision/dash_amount", ab.modules[0].amount, 3)
	H.assert_true(failures, "violent_collision/bulldoze", ab.modules[0].runtime_has("bulldoze"))
	H.assert_true(
		failures, "violent_collision/recast_mod",
		ab.modules[0].violent_collision_recast > 0,
	)
	var cfg: Dictionary = H.bruiser_with_ability(&"bruiser_violent_collision")
	cfg["passive_flags"] = {"training_unlimited_actions": true}
	var board: BoardState = H.make_plain_board(Vector2i(8, 6), [Vector2i(5, 3)])
	H.place_bruiser(board, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board, 2, Vector2i(4, 3))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_violent_collision")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(5, 3), -1))
	var result: SimResult = H.simulate_plan(board, plan)
	var bruiser: UnitState = result.final_state.get_unit_by_id(1)
	H.assert_true(
		failures, "violent_collision/dash",
		bruiser != null and bruiser.position.x >= 4,
	)
	var recast_board: BoardState = H.make_plain_board(Vector2i(8, 6), [Vector2i(5, 3)])
	H.place_bruiser(recast_board, 10, Vector2i(2, 3), H.bruiser_with_ability(&"bruiser_violent_collision"))
	H.place_dummy(recast_board, 11, Vector2i(4, 3))
	var recast_bruiser: UnitState = H.unit_on_board(recast_board, 10)
	var ap_before: int = recast_bruiser.ability.points_left
	var recast_skill: AbilityData = H.ability_on_unit(recast_bruiser, &"bruiser_violent_collision")
	var recast_plan := Timeline.new()
	recast_plan.add(H.plan_ability(10, recast_skill, Vector2i(5, 3), -1))
	var mid_result: SimResult = H.simulate_plan(recast_board, recast_plan)
	var mid_bruiser: UnitState = mid_result.final_state.get_unit_by_id(10)
	H.assert_true(
		failures, "violent_collision/recast_used",
		mid_bruiser != null and mid_bruiser.passive_flags.get("violent_collision_recast_used", false),
	)
	H.assert_true(
		failures, "violent_collision/recast_ap_refund",
		mid_bruiser != null and mid_bruiser.ability.points_left >= ap_before,
		"collision recast must refund AP for the Bible follow-up MOVE",
	)
	H.assert_true(
		failures, "violent_collision/recast_action_slot",
		mid_bruiser != null and not mid_bruiser.turn_action_used,
		"collision recast must reopen the action slot for a second MOVE",
	)
	var follow_board: BoardState = H.make_plain_board(Vector2i(10, 6))
	H.place_bruiser(follow_board, 10, mid_bruiser.position, H.bruiser_with_ability(&"bruiser_violent_collision"))
	var follow_skill: AbilityData = H.ability_on_unit(H.unit_on_board(follow_board, 10), &"bruiser_violent_collision")
	var follow_plan := Timeline.new()
	follow_plan.add(H.plan_ability(10, follow_skill, Vector2i(6, 3), -1))
	var recast_result: SimResult = H.simulate_plan(follow_board, follow_plan)
	var after_recast: UnitState = recast_result.final_state.get_unit_by_id(10)
	H.assert_eq_cell(
		failures, "violent_collision/recast_followup_move",
		after_recast.position if after_recast != null else Vector2i.ZERO,
		Vector2i(6, 3),
	)


static func run_crimson_whirlwind(failures: Array[String]) -> void:
	## Bible: Crimson Whirlwind — RANGE 0 | AOE 3x3 | ATK 1; [+] HEAL 1 per target hit.
	H.run_active_smoke(
		failures, &"bruiser_crimson_whirlwind", "RANGE 0 | AOE 3x3 | ATK 1",
		[GameEnums.EffectType.DAMAGE],
	)
	var ab: AbilityData = H.factory_ability(&"bruiser_crimson_whirlwind")
	H.assert_eq_int(failures, "crimson_whirlwind/range", ab.range_tiles, 0)
	H.assert_eq_int(failures, "crimson_whirlwind/aoe", ab.target_shape, GameEnums.TargetShape.AOE_SQUARE)
	H.assert_eq_int(failures, "crimson_whirlwind/aoe_size", ab.target_shape_size, 1)
	H.assert_eq_int(failures, "crimson_whirlwind/dmg_amount", KH.compiled_effects(ab)[0].amount, 1)
	ab.ensure_targeting_flags_from_mode()
	H.assert_eq_int(failures, "crimson_whirlwind/self_targeting", ab.targeting_mode, GameEnums.TargetingMode.SELF)
	H.assert_true(failures, "crimson_whirlwind/self_flags", ab.has_targeting(GameEnums.TargetingFlags.SELF))
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_crimson_whirlwind"))
	H.place_dummy(board, 2, Vector2i(4, 3))
	H.place_dummy(board, 3, Vector2i(3, 4))
	var hp2: int = H.unit_hp(board, 2)
	var hp3: int = H.unit_hp(board, 3)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_crimson_whirlwind")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(3, 3), 1))
	var result: SimResult = H.simulate_plan(board, plan)
	var bruiser_before: UnitState = H.unit_on_board(board, 1)
	H.assert_eq_cell(failures, "crimson_whirlwind/bruiser_pos", result.final_state.get_unit_by_id(1).position, Vector2i(3, 3))
	var dmg_math: Dictionary = H.first_damage_math(result.events)
	H.assert_eq_int(failures, "crimson_whirlwind/dmg_base_amt", int(dmg_math.get("base", -1)), 1)
	var expected_hit: int = H.damage_dealt_to_unit(
		board, 2, int(dmg_math.get("final_raw", 0)), bruiser_before,
	)
	var total_center: int = H.sum_unit_hp_damage_events(result.events, 2)
	var total_side: int = H.sum_unit_hp_damage_events(result.events, 3)
	var center_hits: int = H.count_unit_hp_damage_events(result.events, 2)
	var side_hits: int = H.count_unit_hp_damage_events(result.events, 3)
	H.assert_eq_int(failures, "crimson_whirlwind/dmg_center", total_center, expected_hit * center_hits)
	H.assert_true(
		failures, "crimson_whirlwind/dmg_side",
		total_side > 0 and side_hits > 0,
		"AOE must deal scaled damage to secondary target",
	)
	H.assert_true(
		failures, "crimson_whirlwind/multi_hit",
		H.unit_hp(result.final_state, 2) < hp2 and H.unit_hp(result.final_state, 3) < hp3,
		"AOE must damage multiple adjacent enemies",
	)
	var whirl_footprint: Array[Vector2i] = GridSystem.get_affected_tiles(
		null, Vector2i(3, 3), Vector2i(3, 3), GameEnums.TargetShape.AOE_SQUARE, 1,
	)
	H.assert_true(
		failures, "crimson_whirlwind/grid_outside",
		not whirl_footprint.has(Vector2i(6, 6)),
		"AOE_SQUARE 3x3 footprint must exclude distant tiles",
	)


static func run_belly_flop(failures: Array[String]) -> void:
	## Bible: Belly Flop — RANGE 2 | ATK 2 | jump to empty tile; [+] landing PUSH 1 adjacent.
	H.run_active_smoke(
		failures, &"bruiser_belly_flop", "RANGE 2 | JUMP + ATK 2",
		[GameEnums.EffectType.JUMP, GameEnums.EffectType.DAMAGE],
	)
	var factory_ab: AbilityData = H.factory_ability(&"bruiser_belly_flop")
	H.assert_eq_int(failures, "belly_flop/range", factory_ab.range_tiles, 2)
	H.assert_eq_int(failures, "belly_flop/ap_cost", factory_ab.action_point_cost, 1)
	var belly_effects := KH.compiled_effects(factory_ab)
	H.assert_eq_int(failures, "belly_flop/jump_amount", belly_effects[0].amount, 2)
	H.assert_eq_int(failures, "belly_flop/dmg_amount", belly_effects[1].amount, 2)
	H.assert_eq_int(failures, "belly_flop/aoe", factory_ab.target_shape, GameEnums.TargetShape.AOE_CROSS)
	H.assert_eq_int(failures, "belly_flop/aoe_size", factory_ab.target_shape_size, 1)
	var flop_footprint: Array[Vector2i] = GridSystem.get_affected_tiles(
		null, Vector2i(5, 3), Vector2i(5, 3), GameEnums.TargetShape.AOE_CROSS, 1,
	)
	H.assert_true(
		failures, "belly_flop/footprint_in",
		flop_footprint.has(Vector2i(5, 4)),
		"AOE_CROSS 1 must include cardinal tiles around the landing",
	)
	H.assert_true(
		failures, "belly_flop/footprint_out",
		not flop_footprint.has(Vector2i(6, 4)),
		"AOE_CROSS 1 must exclude diagonal tiles",
	)
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = H.bruiser_with_ability(&"bruiser_belly_flop")
	cfg["passive_flags"] = {"training_unlimited_actions": true}
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	var bruiser_ap: UnitState = H.unit_on_board(board, 1)
	bruiser_ap.ability.points_left = 1
	H.place_dummy(board, 2, Vector2i(5, 4))
	H.place_dummy(board, 3, Vector2i(6, 4))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_belly_flop")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(5, 3), -1))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_eq_cell(failures, "belly_flop/jump", result.final_state.get_unit_by_id(1).position, Vector2i(5, 3))
	var damaged_adjacent := false
	var damaged_outside := false
	for e: Variant in result.events:
		if e is SimEvent and e.type == GameEnums.SimEventType.UNIT_DAMAGED:
			var hit_id: int = int(e.data.get("unit", -1))
			if hit_id == 2:
				damaged_adjacent = true
			elif hit_id == 3:
				damaged_outside = true
	H.assert_true(
		failures, "belly_flop/adjacent_damage",
		damaged_adjacent,
		"belly flop must emit UNIT_DAMAGED for enemy adjacent to landing tile",
	)
	H.assert_true(
		failures, "belly_flop/outside_unharmed",
		not damaged_outside,
		"belly flop AOE_CROSS must not damage a diagonal tile outside the blast",
	)
	var far_board: BoardState = H.make_plain_board(Vector2i(10, 8))
	var far_cfg: Dictionary = H.bruiser_with_ability(&"bruiser_belly_flop")
	H.place_bruiser(far_board, 10, Vector2i(1, 3), far_cfg)
	var far_ab: AbilityData = H.ability_on_unit(H.unit_on_board(far_board, 10), &"bruiser_belly_flop")
	var far_action: TimelineAction = H.plan_ability(10, far_ab, Vector2i(4, 3), -1)
	H.assert_true(
		failures, "belly_flop/out_of_range",
		not AbilitySystem.can_use(far_board, far_action),
		"RANGE 2 must reject tiles beyond 2 steps",
	)


static func run_breaching_dash(failures: Array[String]) -> void:
	## Bible: Breaching Dash — DASH 3 | destroy cover on path; [+] next attack PIERCE.
	H.run_active_smoke(
		failures, &"bruiser_breaching_dash", "DASH 3 | DESTROY_OBSTACLE",
		[GameEnums.EffectType.DASH, GameEnums.EffectType.DESTROY_OBSTACLE],
	)
	var factory_ab: AbilityData = H.factory_ability(&"bruiser_breaching_dash")
	H.assert_eq_int(failures, "breaching_dash/dash_amount", KH.compiled_effects(factory_ab)[0].amount, 3)
	H.assert_true(
		failures, "breaching_dash/destroy_effect",
		H.ability_has_effect(factory_ab, GameEnums.EffectType.DESTROY_OBSTACLE, false),
	)
	var board: BoardState = H.make_plain_board(Vector2i(12, 6))
	H.place_bruiser(board, 1, Vector2i(4, 3), H.bruiser_with_ability(&"bruiser_breaching_dash"))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"bruiser_breaching_dash")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(5, 3), -1))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_eq_cell(failures, "breaching_dash/lands", result.final_state.get_unit_by_id(1).position, Vector2i(5, 3))
	var destroy_board: BoardState = H.make_plain_board(Vector2i(12, 6))
	var dash_cfg: Dictionary = H.bruiser_with_ability(&"bruiser_breaching_dash")
	dash_cfg["passive_flags"] = {"training_unlimited_actions": true}
	H.place_bruiser(destroy_board, 10, Vector2i(3, 3), dash_cfg)
	var construct_def: UnitData = DataLibrary.get_unit(&"construct_turret")
	H.place_unit(
		destroy_board, 11, construct_def, GameEnums.Team.ENEMY, Vector2i(5, 3), {},
	)
	var construct_hp: int = H.unit_hp(destroy_board, 11)
	var dash_skill: AbilityData = H.ability_on_unit(
		H.unit_on_board(destroy_board, 10), &"bruiser_breaching_dash",
	)
	var dash_plan := Timeline.new()
	dash_plan.add(H.plan_ability(10, dash_skill, Vector2i(6, 3), -1))
	var dash_result: SimResult = H.simulate_plan(destroy_board, dash_plan)
	var construct_after: UnitState = dash_result.final_state.get_unit_by_id(11)
	H.assert_true(
		failures, "breaching_dash/destroy_cover",
		construct_after == null or not construct_after.is_alive() or H.unit_hp(dash_result.final_state, 11) < construct_hp,
		"DESTROY_OBSTACLE must kill construct on dash path",
	)


static func run_cellular_regeneration(failures: Array[String]) -> void:
	## Bible: Sanguine Regeneration trigger plus Reactive Adrenaline interaction.
	H.assert_passive_registered(failures, &"cellular_regeneration")
	_run_reactive_adrenaline(failures)


static func run_reactive_adrenaline(failures: Array[String]) -> void:
	## Bible: adjacent enemies convert Sanguine Regeneration into SHIELD and grant STR.
	H.assert_passive_registered(failures, &"reactive_adrenaline")
	_run_reactive_adrenaline(failures)


static func _run_reactive_adrenaline(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), H.with_single_passive(&"reactive_adrenaline", true))
	H.place_dummy(board, 2, Vector2i(4, 3))
	H.place_dummy(board, 3, Vector2i(3, 4))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	bruiser.health.current_hp = bruiser.health.max_hp - 2
	var hp: int = bruiser.health.current_hp
	var plan := Timeline.new()
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_eq_int(
		failures, "cellular_regeneration/no_heal_when_reactive",
		H.unit_hp(result.final_state, 1),
		hp,
	)
	H.assert_true(
		failures, "reactive_adrenaline/shield",
		result.final_state.get_unit_by_id(1).armor > 0,
		"Reactive Adrenaline converts the turn-start heal into SHIELD",
	)
	H.assert_true(
		failures, "reactive_adrenaline/strength",
		H.has_status(result.final_state.get_unit_by_id(1), GameEnums.StatusType.STAT_BUFF_STR),
		"adjacent enemies must grant Reactive Adrenaline STR",
	)


static func run_blood_for_blood(failures: Array[String]) -> void:
	## Bible: Blood for Blood — damaged last turn → attacks apply BLEED (WPN); [+] ATK +1.
	H.assert_passive_registered(failures, &"blood_for_blood")
	## Turn 1: real damage → full Simulator.simulate end-of-turn sets damaged_last_turn.
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = H.with_single_passive(&"blood_for_blood", false)
	cfg["active_abilities"] = [H.factory_ability(&"bruiser_concussion_blow")]
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	H.place_dummy(board, 2, Vector2i(4, 3))
	var bruiser: UnitState = H.unit_on_board(board, 1)
	var wpn: int = 0
	if bruiser.definition != null and bruiser.definition.equipped_weapon != null:
		wpn = bruiser.definition.equipped_weapon.might
	var dmg_events: Array[SimEvent] = []
	CombatSystem.deal_damage(
		board, bruiser, 1, dmg_events, &"physical", true, false, null, "BloodForBloodQa",
	)
	H.assert_true(
		failures, "blood_for_blood/damaged_this_turn",
		bool(bruiser.passive_flags.get("damaged_this_turn", false)),
	)
	var after_hurt: SimResult = Simulator.simulate(board, Timeline.new())
	H.assert_true(
		failures, "blood_for_blood/damaged_last_turn",
		bool(after_hurt.final_state.get_unit_by_id(1).passive_flags.get("damaged_last_turn", false)),
		"end-of-turn must promote damaged_this_turn → damaged_last_turn",
	)
	## Turn 2: attack must apply BLEED = WPN from the real flag (not injected).
	var strike: AbilityData = H.ability_on_unit(
		after_hurt.final_state.get_unit_by_id(1), &"bruiser_concussion_blow",
	)
	var strike_plan := Timeline.new()
	strike_plan.add(H.plan_ability(1, strike, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(after_hurt.final_state, strike_plan)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	H.assert_true(
		failures, "blood_for_blood/bleed",
		enemy != null and H.has_status(enemy, GameEnums.StatusType.BLEED),
	)
	H.assert_eq_int(
		failures, "blood_for_blood/bleed_wpn",
		H.status_value(enemy, GameEnums.StatusType.BLEED),
		wpn,
	)
	var neg_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	var neg_cfg: Dictionary = H.with_single_passive(&"blood_for_blood", false)
	neg_cfg["active_abilities"] = [H.factory_ability(&"bruiser_concussion_blow")]
	H.place_bruiser(neg_board, 10, Vector2i(3, 3), neg_cfg)
	H.place_dummy(neg_board, 11, Vector2i(4, 3))
	var neg_ab: AbilityData = H.ability_on_unit(H.unit_on_board(neg_board, 10), &"bruiser_concussion_blow")
	var neg_plan := Timeline.new()
	neg_plan.add(H.plan_ability(10, neg_ab, Vector2i(4, 3), 11))
	var neg_result: SimResult = H.simulate_plan(neg_board, neg_plan)
	var neg_enemy: UnitState = neg_result.final_state.get_unit_by_id(11)
	H.assert_true(
		failures, "blood_for_blood/no_bleed_without_flag",
		neg_enemy != null and not H.has_status(neg_enemy, GameEnums.StatusType.BLEED),
		"without damaged_last_turn attacks must not apply BLEED",
	)


static func run_adrenaline_junkie(failures: Array[String]) -> void:
	## Bible: Adrenaline Junkie — +MOV/+STR per 25% missing HP (max +3); [+] +DEF per 25% missing HP (max +3).
	H.assert_passive_registered(failures, &"adrenaline_junkie")
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = H.with_single_passive(&"adrenaline_junkie", false)
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	var bruiser: UnitState = H.unit_on_board(board, 1)
	bruiser.health.current_hp = bruiser.health.max_hp / 2
	bruiser._recalculate_stats()
	var expected_bonus: int = mini(3, floori(0.5 / 0.25))
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
	var missing_pct: float = (
		float(bruiser.health.max_hp - bruiser.health.current_hp) / float(bruiser.health.max_hp)
	)
	var expected_nine: int = mini(3, floori(missing_pct / 0.25))
	H.assert_eq_int(
		failures, "adrenaline_junkie/ninety_pct_missing",
		CombatSystem.get_dynamic_strength(board, bruiser) - str_full,
		expected_nine,
	)


static func run_enraged(failures: Array[String]) -> void:
	## Bible: Enraged — +1 STR per unique debuff/hazard; [+] +1 MOV per debuff/hazard.
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
	## Bible: Last Stand — HP < 25% → +2 STR/DEF; [+] +3 STR/DEF instead.
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
	## Bible: Colossal Mass — +1 STR per 15 Max HP; [+] per 10 Max HP instead.
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
	## Altered Max HP proves floor(max_hp/15) scaling (not a constant buff).
	## Set after _recalculate_stats — that path restores definition Max HP.
	var big_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(big_board, 20, Vector2i(3, 3), H.with_single_passive(&"colossal_mass", false))
	var big: UnitState = H.unit_on_board(big_board, 20)
	big.health.max_hp = 45
	big.health.current_hp = 45
	var plain_big: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(plain_big, 21, Vector2i(3, 3), {})
	var plain_big_u: UnitState = H.unit_on_board(plain_big, 21)
	plain_big_u.health.max_hp = 45
	plain_big_u.health.current_hp = 45
	H.assert_eq_int(
		failures, "colossal_mass/str_at_45_max",
		CombatSystem.get_dynamic_strength(big_board, big) - CombatSystem.get_dynamic_strength(plain_big, plain_big_u),
		floori(45.0 / 15.0),
	)


static func run_overwhelming_bulk(failures: Array[String]) -> void:
	## Bible: Overwhelming Bulk — Current HP > target Max HP → PIERCE; [+] PUSH 1 on attacks.
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
	var cfg_ab: Dictionary = H.with_single_passive(&"overwhelming_bulk", false)
	cfg_ab["active_abilities"] = [H.factory_ability(&"bruiser_headbutt")]
	var board_ab: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board_ab, 20, Vector2i(3, 3), cfg_ab)
	H.place_dummy(board_ab, 21, Vector2i(4, 3))
	var bruiser_ab: UnitState = H.unit_on_board(board_ab, 20)
	bruiser_ab.health.max_hp = 150
	bruiser_ab.health.current_hp = 150
	var enemy_ab: UnitState = H.unit_on_board(board_ab, 21)
	enemy_ab.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, 20))
	enemy_ab._recalculate_stats()
	enemy_ab.health.max_hp = 10
	enemy_ab.health.current_hp = 10
	var hp_ab: int = enemy_ab.health.current_hp
	var skill_ab: AbilityData = H.ability_on_unit(H.unit_on_board(board_ab, 20), &"bruiser_headbutt")
	var events_ab: Array[SimEvent] = []
	AbilitySystem.execute(
		board_ab,
		TimelineAction.make_ability(20, skill_ab, Vector2i(4, 3), 21),
		events_ab,
	)
	H.assert_true(
		failures, "overwhelming_bulk/ability_pierce_events",
		H.events_have_damage_pierce(events_ab, true),
	)
	var dmg_ab: int = H.sum_unit_hp_damage_events(events_ab, 21)
	var board_ctl: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(board_ctl, 30, Vector2i(3, 3), H.bruiser_with_ability(&"bruiser_headbutt"))
	H.place_dummy(board_ctl, 31, Vector2i(4, 3))
	var bruiser_ctl: UnitState = H.unit_on_board(board_ctl, 30)
	bruiser_ctl.health.max_hp = 150
	bruiser_ctl.health.current_hp = 150
	var enemy_ctl: UnitState = H.unit_on_board(board_ctl, 31)
	enemy_ctl.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, 20))
	enemy_ctl._recalculate_stats()
	enemy_ctl.health.max_hp = 10
	enemy_ctl.health.current_hp = 10
	var skill_ctl: AbilityData = H.ability_on_unit(H.unit_on_board(board_ctl, 30), &"bruiser_headbutt")
	var events_ctl: Array[SimEvent] = []
	AbilitySystem.execute(
		board_ctl,
		TimelineAction.make_ability(30, skill_ctl, Vector2i(4, 3), 31),
		events_ctl,
	)
	var dmg_ctl: int = H.sum_unit_hp_damage_events(events_ctl, 31)
	H.assert_true(
		failures, "overwhelming_bulk/ability_pierce_dmg",
		dmg_ab > dmg_ctl and dmg_ab > 0,
		"AbilitySystem DAMAGE path must pierce when bulk precond met (bulk=%d control=%d)" % [dmg_ab, dmg_ctl],
	)


static func run_thrill_of_pain(failures: Array[String]) -> void:
	## Bible: Thrill of Pain — on damage, next attack ATK +2 + PUSH 1; [+] ATK +3 instead.
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
	## Bible: Momentum of the Titan — PUSH collision +10% Max HP dmg; [+] 20% Max HP.
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
	## Bible: Scar Tissue — reduce physical dmg by 1 per 20 Max/missing HP; [+] additional 1.
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
	H.assert_true(
		failures, "scar_tissue/cap",
		scar_bonus <= floori(float(victim.health.max_hp) / 10.0),
		"Scar Tissue mitigation must not exceed Floor(Max HP / 10)",
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
	## Bible: Momentum Transfer — PUSH collision HEAL 1; [+] HEAL 1 and +1 STR.
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
	H.assert_eq_int(
		failures, "momentum_transfer/heal",
		H.unit_hp(result.final_state, 1),
		hp + 2,
	)
	var plain_board: BoardState = H.make_plain_board(Vector2i(10, 8), [Vector2i(5, 3)])
	var plain_cfg: Dictionary = {
		"active_passives": [H.factory_passive(&"battering_ram")],
		"active_abilities": [H.factory_ability(&"bruiser_concussion_blow")],
	}
	H.place_bruiser(plain_board, 20, Vector2i(2, 3), plain_cfg)
	H.place_dummy(plain_board, 21, Vector2i(3, 3))
	var plain_bruiser: UnitState = H.unit_on_board(plain_board, 20)
	plain_bruiser.health.current_hp = plain_bruiser.health.max_hp - 3
	var plain_hp: int = plain_bruiser.health.current_hp
	var plain_ab: AbilityData = H.ability_on_unit(plain_bruiser, &"bruiser_concussion_blow")
	var plain_plan := Timeline.new()
	plain_plan.add(H.plan_ability(20, plain_ab, Vector2i(3, 3), 21))
	var plain_result: SimResult = H.simulate_plan(plain_board, plain_plan)
	H.assert_eq_int(
		failures, "momentum_transfer/plain_no_heal",
		H.unit_hp(plain_result.final_state, 20),
		plain_hp + 1,
	)


static func run_crowd_breaker(failures: Array[String]) -> void:
	## Bible: Crowd Breaker — +1 STR per adjacent enemy + splash ATK 1; [+] splash ATK 2.
	H.assert_passive_registered(failures, &"crowd_breaker")
	var board: BoardState = H.make_plain_board(Vector2i(8, 8))
	var cfg: Dictionary = H.with_single_passive(&"crowd_breaker", false)
	cfg["active_abilities"] = [H.factory_ability(&"bruiser_concussion_blow")]
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	H.place_dummy(board, 2, Vector2i(4, 3))
	H.place_dummy(board, 3, Vector2i(4, 4))
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
	H.place_dummy(board_plain, 22, Vector2i(4, 4))
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
	H.assert_eq_int(
		failures, "crowd_breaker/splash_vs_plain",
		splash_dmg - splash_plain,
		1,
	)
	var multi_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(multi_board, 30, Vector2i(3, 3), H.with_single_passive(&"crowd_breaker", false))
	H.place_dummy(multi_board, 31, Vector2i(4, 3))
	H.place_dummy(multi_board, 32, Vector2i(3, 4))
	var multi_alone: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(multi_alone, 33, Vector2i(3, 3), H.with_single_passive(&"crowd_breaker", false))
	H.assert_eq_int(
		failures, "crowd_breaker/adj_str_two",
		CombatSystem.get_dynamic_strength(multi_board, H.unit_on_board(multi_board, 30))
		- CombatSystem.get_dynamic_strength(multi_alone, H.unit_on_board(multi_alone, 33)),
		2,
	)


static func run_juggernaut(failures: Array[String]) -> void:
	## Bible: Juggernaut — trap destroy for 0 damage; [+] trap destroy grants SHIELD 1.
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
	## Bible: Battering Ram — PUSH +1 tile; [+] wall collision STAGGER.
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
	var plain_board: BoardState = H.make_plain_board(Vector2i(10, 8), [Vector2i(6, 3)])
	H.place_bruiser(
		plain_board, 10, Vector2i(2, 3),
		{"active_abilities": [H.factory_ability(&"bruiser_concussion_blow")]},
	)
	H.place_dummy(plain_board, 11, Vector2i(3, 3))
	var plain_ab: AbilityData = H.ability_on_unit(H.unit_on_board(plain_board, 10), &"bruiser_concussion_blow")
	var plain_plan := Timeline.new()
	plain_plan.add(H.plan_ability(10, plain_ab, Vector2i(3, 3), 11))
	var plain_result: SimResult = H.simulate_plan(plain_board, plain_plan)
	var plain_end: Vector2i = plain_result.final_state.get_unit_by_id(11).position
	H.assert_eq_cell(failures, "battering_ram/base_push", plain_end, Vector2i(4, 3))
	H.assert_eq_int(
		failures, "battering_ram/extra_tile_delta",
		end_pos.x - plain_end.x,
		1,
	)


static func run_unstoppable_force(failures: Array[String]) -> void:
	## Bible: Unstoppable Force — STAGGER/ROOT immune; resist grants SHIELD 1; [+] SHIELD 2.
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
	var prevented_stagger: bool = false
	for e: Variant in result.events:
		if e is SimEvent and e.type == GameEnums.SimEventType.ACTION_FAILED:
			if str(e.data.get("reason", "")) == "status_prevented_by_unstoppable_force":
				prevented_stagger = true
				break
	H.assert_true(failures, "unstoppable_force/stagger_prevented", prevented_stagger)
	H.assert_eq_int(
		failures, "unstoppable_force/shield_gain",
		bruiser.armor - armor_before,
		1,
	)
	var root_board: BoardState = H.make_plain_board(Vector2i(8, 8))
	H.place_bruiser(root_board, 3, Vector2i(3, 3), H.with_single_passive(&"unstoppable_force", false))
	var root_enemy_cfg: Dictionary = {
		"active_abilities": [KH.factory_ability(&"knight_iron_grip")],
	}
	H.place_unit(
		root_board,
		4,
		H.bruiser_unit_data(),
		GameEnums.Team.ENEMY,
		Vector2i(4, 3),
		root_enemy_cfg,
	)
	var root_bruiser: UnitState = H.unit_on_board(root_board, 3)
	var armor_root_before: int = root_bruiser.armor
	var grip: AbilityData = KH.factory_ability(&"knight_iron_grip")
	var root_plan := Timeline.new()
	root_plan.add(H.plan_ability(4, grip, Vector2i(3, 3), 3))
	var root_result: SimResult = H.simulate_plan(root_board, root_plan)
	root_bruiser = root_result.final_state.get_unit_by_id(3)
	H.assert_true(
		failures, "unstoppable_force/no_root",
		not H.has_status(root_bruiser, GameEnums.StatusType.ROOT),
	)
	var prevented_root: bool = false
	for e: Variant in root_result.events:
		if e is SimEvent and e.type == GameEnums.SimEventType.ACTION_FAILED:
			if str(e.data.get("reason", "")) == "status_prevented_by_unstoppable_force":
				prevented_root = true
				break
	H.assert_true(failures, "unstoppable_force/root_prevented", prevented_root)
	H.assert_eq_int(
		failures, "unstoppable_force/root_shield_gain",
		root_bruiser.armor - armor_root_before,
		1,
	)
	## Collision / physics STAGGER path must also respect Unstoppable Force (shared helper).
	var push_only: AbilityData = DataLibrary._make_ability(
		&"qa_plain_push_uf", "QA Plain Push", 1,
		[DataLibrary._module(
			GameEnums.EffectType.PUSH, 1, 1, 1, GameEnums.TargetingFlags.ENEMY,
		)],
		1,
	)
	var col_board: BoardState = H.make_plain_board(Vector2i(8, 8), [Vector2i(4, 3)])
	H.place_bruiser(col_board, 30, Vector2i(3, 3), H.with_single_passive(&"unstoppable_force", false))
	var ram_cfg: Dictionary = H.with_upgraded_passive(
		H.with_single_passive(&"battering_ram", false),
		&"battering_ram",
	)
	ram_cfg["active_abilities"] = [push_only]
	H.place_unit(
		col_board, 31, H.bruiser_unit_data(), GameEnums.Team.ENEMY, Vector2i(2, 3), ram_cfg,
	)
	var uf_before: UnitState = H.unit_on_board(col_board, 30)
	var armor_col_before: int = uf_before.armor
	var ram_push: AbilityData = H.ability_on_unit(H.unit_on_board(col_board, 31), &"qa_plain_push_uf")
	var col_plan := Timeline.new()
	col_plan.add(H.plan_ability(31, ram_push, Vector2i(3, 3), 30))
	var col_result: SimResult = H.simulate_plan(col_board, col_plan)
	var uf_after: UnitState = col_result.final_state.get_unit_by_id(30)
	H.assert_true(
		failures, "unstoppable_force/collision_no_stagger",
		uf_after != null and not H.has_status(uf_after, GameEnums.StatusType.STAGGER),
		"wall/collision STAGGER must be resisted by Unstoppable Force",
	)
	H.assert_eq_int(
		failures, "unstoppable_force/collision_shield",
		uf_after.armor - armor_col_before,
		1,
	)
