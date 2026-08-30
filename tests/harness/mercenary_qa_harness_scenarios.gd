class_name MercenaryQaHarnessScenarios
extends RefCounted

const H := preload("res://tests/mercenary_qa_harness.gd")
const MercenarySystems := preload("res://core/systems/mercenary_systems.gd")


static func run_predatory_momentum(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board, 1, Vector2i(2, 3), H.mercenary_with_passive(&"predatory_momentum"))
	H.place_dummy(board, 2, Vector2i(3, 3))
	var enemy: UnitState = H.unit_on_board(board, 2)
	enemy.health.current_hp = 2
	H.unit_on_board(board, 1).movement.points_left = 2
	var basic: AbilityData = null
	for ab: AbilityData in H.unit_on_board(board, 1).active_abilities:
		if ab != null and AbilitySystem._is_basic_attack(ab):
			basic = ab
			break
	H.assert_true(failures, "predatory/basic", basic != null)
	var hp_before: int = enemy.health.current_hp
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, basic, Vector2i(3, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "predatory/damage",
		H.unit_hp(result.final_state, 2) < hp_before,
	)
	H.assert_true(
		failures, "predatory/following_flag",
		result.final_state.get_unit_by_id(1).passive_flags.get("predatory_following_pending", false),
	)
	H.assert_eq_int(
		failures, "predatory/free_move",
		result.final_state.get_unit_by_id(1).movement.points_left, 3,
	)
	var next_turn_events: Array[SimEvent] = []
	var base_movement: int = result.final_state.get_unit_by_id(1).movement.max_points
	MercenarySystems.turn_end_rollover(result.final_state.get_unit_by_id(1))
	MercenarySystems.turn_start(
		result.final_state, result.final_state.get_unit_by_id(1), next_turn_events,
	)
	var next_turn_merc: UnitState = result.final_state.get_unit_by_id(1)
	H.assert_true(
		failures, "predatory/next_turn_strength",
		H.has_status(next_turn_merc, GameEnums.StatusType.STAT_BUFF_STR)
			and next_turn_merc.current_strength > next_turn_merc.definition.base_strength,
	)
	H.assert_true(
		failures, "predatory/next_turn_movement",
		H.has_status(next_turn_merc, GameEnums.StatusType.STAT_BUFF_MOV)
			and next_turn_merc.movement.max_points > base_movement,
	)


static func run_pullback(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board, 1, Vector2i(3, 4), H.mercenary_with_ability(&"mercenary_pullback"))
	H.place_ally(board, 2, Vector2i(4, 4))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_pullback")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(2, 4)))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_eq_cell(failures, "pullback/mercenary", H.unit_on_board(result.final_state, 1).position, Vector2i(2, 4))
	H.assert_eq_cell(failures, "pullback/ally", H.unit_on_board(result.final_state, 2).position, Vector2i(3, 4))


static func run_swift_strike(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	var start: Vector2i = Vector2i(2, 3)
	var move_pos: Vector2i = Vector2i(3, 3)
	var enemy_pos: Vector2i = Vector2i(4, 3)
	H.place_mercenary(board, 1, start, H.mercenary_with_ability(&"mercenary_swift_strike"))
	H.place_dummy(board, 2, enemy_pos)
	var hp: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_swift_strike")
	var action := TimelineAction.make_ability(1, skill, enemy_pos, 2)
	action.awaiting_target = false
	action.awaiting_module_index = -1
	var plan := Timeline.new()
	plan.add(action)
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(failures, "swift_strike/damage", H.unit_hp(result.final_state, 2) < hp)
	H.assert_eq_cell(
		failures, "swift_strike/pos",
		H.unit_on_board(result.final_state, 1).position,
		move_pos,
	)


static func run_defense_strike(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board, 1, Vector2i(2, 3), H.mercenary_with_ability(&"mercenary_defense_strike"))
	H.place_dummy(board, 2, Vector2i(3, 3))
	var hp: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_defense_strike")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(3, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(failures, "defense_strike/damage", H.unit_hp(result.final_state, 2) < hp)
	H.assert_true(
		failures, "defense_strike/def_buff",
		H.has_status(H.unit_on_board(result.final_state, 1), GameEnums.StatusType.STAT_BUFF_DEF),
	)


static func run_blade_storm(failures: Array[String]) -> void:
	var cfg_no: Dictionary = {
		"active_abilities": [
			H._basic_attack_for(H.mercenary_unit_data()),
			H.factory_ability(&"mercenary_blade_storm"),
		],
		"active_passives": [],
	}
	var board_no: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board_no, 1, Vector2i(2, 3), cfg_no)
	H.place_dummy(board_no, 2, Vector2i(3, 3))
	H.unit_on_board(board_no, 2).health.max_hp = 100
	H.unit_on_board(board_no, 2).health.current_hp = 100
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board_no, 1), &"mercenary_blade_storm")
	var plan_no := Timeline.new()
	plan_no.add(H.plan_ability(1, skill, Vector2i(3, 3), 2))
	var loss_no: int = H.hp_loss_from_plan(board_no, plan_no, 2)

	var board_yes: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board_yes, 1, Vector2i(2, 3), cfg_no)
	H.place_mercenary(board_yes, 3, Vector2i(3, 4), {})
	H.place_dummy(board_yes, 2, Vector2i(3, 3))
	H.unit_on_board(board_yes, 2).health.max_hp = 100
	H.unit_on_board(board_yes, 2).health.current_hp = 100
	var plan_yes := Timeline.new()
	plan_yes.add(H.plan_ability(1, skill, Vector2i(3, 3), 2))
	var loss_yes: int = H.hp_loss_from_plan(board_yes, plan_yes, 2)
	H.assert_true(failures, "blade_storm/outcome/damage", loss_no > 0)
	H.assert_true(
		failures, "blade_storm/outcome/ally_adjacent_bonus",
		loss_yes > loss_no,
		"ally adjacent to target must add ATK +2",
	)


static func run_caltrop_toss(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board, 1, Vector2i(2, 3), H.mercenary_with_ability(&"mercenary_caltrop_toss"))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_caltrop_toss")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var tile := result.final_state.get_tile(Vector2i(4, 3))
	H.assert_true(failures, "caltrop_toss/hazard", tile != null and tile.definition.id == &"caltrop_trap")


static func run_feint(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board, 1, Vector2i(2, 3), H.mercenary_with_ability(&"mercenary_feint"))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_feint")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(2, 3)))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "feint/pierce_flag",
		result.final_state.get_unit_by_id(1).passive_flags.get("next_turn_attack_pierce", false),
	)
	H.assert_eq_int(
		failures, "feint/no_same_turn_strength",
		int(result.final_state.get_unit_by_id(1).passive_flags.get("next_attack_strength_bonus", 0)),
		0,
	)
	H.assert_eq_int(
		failures, "feint/pending_strength",
		int(result.final_state.get_unit_by_id(1).passive_flags.get("next_turn_attack_strength_bonus", 0)),
		1,
	)


static func run_riposte_strike(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board, 1, Vector2i(2, 3), H.mercenary_with_ability(&"mercenary_riposte_strike"))
	H.place_dummy(board, 2, Vector2i(3, 3))
	H.unit_on_board(board, 2).passive_flags["attacked_by_last_turn_id"] = 1
	var hp: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_riposte_strike")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(3, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(failures, "riposte/damage", H.unit_hp(result.final_state, 2) < hp)
	H.assert_true(
		failures, "riposte/outcome/stagger",
		H.has_status(H.unit_on_board(result.final_state, 2), GameEnums.StatusType.STAGGER),
		"attacked-last-turn targets must suffer STAGGER",
	)


static func run_sever(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board, 1, Vector2i(2, 3), H.mercenary_with_ability(&"mercenary_sever"))
	H.place_mercenary(board, 3, Vector2i(1, 3), {})
	H.place_dummy(board, 2, Vector2i(3, 3))
	var ally: UnitState = H.unit_on_board(board, 3)
	ally.health.current_hp = ally.health.max_hp - 2
	var ally_hp_before: int = ally.health.current_hp
	H.unit_on_board(board, 2).health.current_hp = 1
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_sever")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(3, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(failures, "sever/kill", not H.unit_on_board(result.final_state, 2).is_alive())
	H.assert_eq_int(
		failures, "sever/ally_heal",
		H.unit_on_board(result.final_state, 3).health.current_hp - ally_hp_before,
		1,
	)


static func run_second_wind(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board, 1, Vector2i(2, 3), H.mercenary_with_ability(&"mercenary_second_wind"))
	var merc: UnitState = H.unit_on_board(board, 1)
	merc.health.current_hp = merc.health.max_hp - 2
	var ap_before: int = merc.ability.points_left
	var hp_before: int = merc.health.current_hp
	var skill: AbilityData = H.ability_on_unit(merc, &"mercenary_second_wind")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(2, 3)))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "second_wind/heal",
		H.unit_hp(result.final_state, 1) > hp_before,
	)
	H.assert_eq_int(
		failures, "second_wind/no_same_turn_ap",
		result.final_state.get_unit_by_id(1).ability.points_left,
		ap_before - 1,
	)
	H.assert_eq_int(
		failures, "second_wind/pending_ap",
		int(result.final_state.get_unit_by_id(1).passive_flags.get("next_turn_grant_ap", 0)),
		1,
	)


static func run_tactical_retreat(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board, 1, Vector2i(4, 3), H.mercenary_with_ability(&"mercenary_tactical_retreat"))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_tactical_retreat")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(1, 3)))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_eq_cell(failures, "tactical_retreat/pos", H.unit_on_board(result.final_state, 1).position, Vector2i(1, 3))
	var smoke_tile: TileState = result.final_state.get_tile(Vector2i(4, 3))
	H.assert_true(
		failures, "tactical_retreat/smoke_start",
		smoke_tile != null and smoke_tile.definition != null
			and smoke_tile.definition.id == &"smoke"
			and result.final_state.temporary_terrain_turns.get(Vector2i(4, 3), 0) == 2,
	)


static func run_executioners_blade(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board, 1, Vector2i(2, 3), H.mercenary_with_ability(&"mercenary_executioners_blade"))
	H.place_dummy(board, 2, Vector2i(3, 3))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_executioners_blade")
	H.assert_true(
		failures, "executioners_blade/healthy_illegal",
		not AbilitySystem.can_use(board, H.plan_ability(1, skill, Vector2i(3, 3), 2)),
	)
	H.unit_on_board(board, 2).health.current_hp = 2
	H.assert_true(
		failures, "executioners_blade/wounded_legal",
		AbilitySystem.can_use(board, H.plan_ability(1, skill, Vector2i(3, 3), 2)),
	)
	var action: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_executioners_blade")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, action, Vector2i(3, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "executioners_blade/kill",
		not H.unit_on_board(result.final_state, 2).is_alive(),
	)

	var board_up: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg_up: Dictionary = H.with_upgraded_ability(
		H.mercenary_with_ability(&"mercenary_executioners_blade"), &"mercenary_executioners_blade",
	)
	H.place_mercenary(board_up, 1, Vector2i(2, 3), cfg_up)
	H.place_dummy(board_up, 2, Vector2i(3, 3))
	H.unit_on_board(board_up, 2).health.current_hp = 2
	var merc_up: UnitState = H.unit_on_board(board_up, 1)
	merc_up.ability.max_points = 10
	merc_up.ability.points_left = 10
	var action_up: AbilityData = H.ability_on_unit(merc_up, &"mercenary_executioners_blade")
	var plan_up := Timeline.new()
	plan_up.add(H.plan_ability(1, action_up, Vector2i(3, 3), 2))
	var result_up: SimResult = H.simulate_plan(board_up, plan_up)
	var ap_cost: int = AbilitySystem.get_action_point_cost(merc_up, action_up, board_up)
	H.assert_eq_int(
		failures, "executioners_blade/upgrade/kill_ap",
		result_up.final_state.get_unit_by_id(1).ability.points_left,
		10 - ap_cost + 1,
	)


static func run_precision_strike(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board, 1, Vector2i(2, 3), H.mercenary_with_ability(&"mercenary_precision_strike"))
	H.place_dummy(board, 2, Vector2i(3, 3))
	var hp: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_precision_strike")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(3, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(failures, "precision_strike/damage", H.unit_hp(result.final_state, 2) < hp)


static func run_flank_and_run(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board, 1, Vector2i(2, 3), H.mercenary_with_ability(&"mercenary_flank_and_run"))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_flank_and_run")
	var before: Vector2i = H.unit_on_board(board, 1).position
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(3, 3)))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "flank_and_run/pos_changed",
		H.unit_on_board(result.final_state, 1).position != before,
	)
	H.assert_eq_int(
		failures, "flank_and_run/pending_bonus",
		int(result.final_state.get_unit_by_id(1).passive_flags.get("next_turn_flank_run_attack_bonus", 0)),
		2,
	)
	var actor: UnitState = result.final_state.get_unit_by_id(1)
	var enemy: UnitState = result.final_state.get_unit_by_id(2)
	enemy.turn_action_used = true
	enemy.health.current_hp = enemy.health.max_hp - 1
	MercenarySystems.turn_end_rollover(actor)
	MercenarySystems.turn_start(result.final_state, actor, [])
	var basic: AbilityData = H.basic_attack_for_unit(actor)
	actor.passive_flags.erase("flank_run_attack_bonus")
	var baseline_attack: int = MercenarySystems.adjust_attack_base(
		result.final_state, actor, enemy, basic, 1,
	)
	actor.passive_flags["flank_run_attack_bonus"] = 2
	var adjusted_attack: int = MercenarySystems.adjust_attack_base(
		result.final_state, actor, enemy, basic, 1,
	)
	H.assert_eq_int(
		failures, "flank_and_run/next_attack_bonus",
		adjusted_attack - baseline_attack, 2,
	)
	H.assert_true(
		failures, "flank_and_run/bonus_consumed",
		not actor.passive_flags.has("flank_run_attack_bonus"),
	)
	var negative_board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(
		negative_board, 1, Vector2i(2, 3),
		H.mercenary_with_ability(&"mercenary_flank_and_run"),
	)
	var negative_skill: AbilityData = H.ability_on_unit(
		H.unit_on_board(negative_board, 1), &"mercenary_flank_and_run",
	)
	var negative_plan := Timeline.new()
	negative_plan.add(H.plan_ability(1, negative_skill, Vector2i(2, 5)))
	var negative_result: SimResult = H.simulate_plan(negative_board, negative_plan)
	H.assert_true(
		failures, "flank_and_run/no_adjacent_bonus",
		not negative_result.final_state.get_unit_by_id(1).passive_flags.has(
			"next_turn_flank_run_attack_bonus",
		),
	)


static func run_hamstring(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board, 1, Vector2i(2, 3), H.mercenary_with_ability(&"mercenary_hamstring"))
	H.place_dummy(board, 2, Vector2i(3, 3))
	var hp_before: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_hamstring")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(3, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	var enemy: UnitState = H.unit_on_board(result.final_state, 2)
	H.assert_true(failures, "hamstring/damage", H.unit_hp(result.final_state, 2) < hp_before)
	H.assert_true(
		failures, "hamstring/move_cap",
		enemy.movement.max_points <= 1,
		"hamstring must cap target MP to 1 via set_max_move",
	)


static func run_acrobatic_vault(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board, 1, Vector2i(2, 3), H.mercenary_with_ability(&"mercenary_acrobatic_vault"))
	H.place_dummy(board, 2, Vector2i(3, 3))
	var hp: int = H.unit_hp(board, 2)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_acrobatic_vault")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3)))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(failures, "acrobatic_vault/damage", H.unit_hp(result.final_state, 2) < hp)
	H.assert_eq_cell(
		failures, "acrobatic_vault/land",
		H.unit_on_board(result.final_state, 1).position,
		Vector2i(4, 3),
	)


static func run_duelists_challenge(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board, 1, Vector2i(2, 3), H.mercenary_with_ability(&"mercenary_duelists_challenge"))
	H.place_dummy(board, 2, Vector2i(5, 3))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_duelists_challenge")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(5, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "duelists/taunt",
		H.has_status(H.unit_on_board(result.final_state, 2), GameEnums.StatusType.TAUNT),
	)
	var taunt_turns: int = 0
	for s: StatusData in H.unit_on_board(result.final_state, 2).active_statuses:
		if s.type == GameEnums.StatusType.TAUNT:
			taunt_turns = s.duration
	H.assert_eq_int(failures, "duelists/taunt_duration", taunt_turns, 1)
	H.assert_true(
		failures, "duelists/mark",
		H.has_status(H.unit_on_board(result.final_state, 2), GameEnums.StatusType.MARK),
	)
	var upgraded_board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(
		upgraded_board, 1, Vector2i(2, 3),
		H.with_upgraded_ability(
			H.mercenary_with_ability(&"mercenary_duelists_challenge"),
			&"mercenary_duelists_challenge",
		),
	)
	H.place_dummy(upgraded_board, 2, Vector2i(5, 3))
	var upgraded_skill: AbilityData = H.ability_on_unit(
		H.unit_on_board(upgraded_board, 1), &"mercenary_duelists_challenge",
	)
	var upgraded_plan := Timeline.new()
	upgraded_plan.add(H.plan_ability(1, upgraded_skill, Vector2i(5, 3), 2))
	var upgraded_result: SimResult = H.simulate_plan(upgraded_board, upgraded_plan)
	var marked_actor: UnitState = H.unit_on_board(upgraded_result.final_state, 1)
	var marked_enemy: UnitState = H.unit_on_board(upgraded_result.final_state, 2)
	var challenge_events: Array[SimEvent] = []
	var hp_before_attack: int = marked_actor.health.current_hp
	CombatSystem.deal_damage(
		upgraded_result.final_state, marked_actor, 5, challenge_events,
		&"physical", false, false, marked_enemy, "Marked target test", 5,
	)
	H.assert_eq_int(
		failures, "duelists/upgrade/defense_bonus",
		MercenarySystems.marked_defense_bonus(marked_actor, marked_enemy), 2,
	)
	H.assert_true(
		failures, "duelists/upgrade/mitigation",
		hp_before_attack - marked_actor.health.current_hp < 5,
	)


static func run_calculated_strike(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.mercenary_with_passive(&"calculated_strike")
	cfg["active_abilities"] = [
		H.factory_ability(&"mercenary_pullback"),
		H.factory_ability(&"mercenary_sever"),
	]
	H.place_mercenary(board, 1, Vector2i(3, 4), cfg)
	H.place_ally(board, 3, Vector2i(4, 4))
	var move: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_pullback")
	var attack: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_sever")
	H.place_dummy(board, 2, Vector2i(2, 3))
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, move, Vector2i(2, 4)))
	plan.add(H.plan_ability(1, attack, Vector2i(2, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "calculated_strike/move_spent",
		result.final_state.get_unit_by_id(1).movement_points_spent_this_turn > 0,
	)
	var calculated_actor: UnitState = result.final_state.get_unit_by_id(1)
	H.assert_true(
		failures, "calculated_strike/attack_buffs",
		H.has_status(calculated_actor, GameEnums.StatusType.STAT_BUFF_STR)
			and H.has_status(calculated_actor, GameEnums.StatusType.STAT_BUFF_DEF),
	)


static func run_weapon_master(failures: Array[String]) -> void:
	var board_no: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board_no, 1, Vector2i(2, 3), {
		"active_abilities": [H.factory_ability(&"mercenary_swift_strike")],
		"active_passives": [],
	})
	H.place_dummy(board_no, 2, Vector2i(4, 3))
	H.unit_on_board(board_no, 2).health.max_hp = 100
	H.unit_on_board(board_no, 2).health.current_hp = 100
	H.buff_merc_strength(board_no, 1, 60)
	H.buff_dummy_defense(board_no, 2, 15)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board_no, 1), &"mercenary_swift_strike")
	var plan_no := Timeline.new()
	plan_no.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var loss_no: int = H.hp_loss_from_plan(board_no, plan_no, 2)

	var board_yes: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.mercenary_with_passive(&"weapon_master")
	cfg["active_abilities"] = [H.factory_ability(&"mercenary_swift_strike")]
	H.place_mercenary(board_yes, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board_yes, 2, Vector2i(4, 3))
	H.buff_merc_strength(board_yes, 1, 60)
	H.buff_dummy_defense(board_yes, 2, 15)
	var plan_yes := Timeline.new()
	plan_yes.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var loss_yes: int = H.hp_loss_from_plan(board_yes, plan_yes, 2)
	H.assert_true(
		failures, "weapon_master/outcome/high_def_bonus",
		loss_yes > loss_no,
		"weapon master must add STR-over-DEF damage vs high-DEF targets",
	)


static func run_dual_wield_momentum(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.mercenary_with_passive(&"dual_wield_momentum")
	cfg["active_abilities"].append(H.factory_ability(&"mercenary_hamstring"))
	H.place_mercenary(board, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board, 2, Vector2i(3, 3))
	H.unit_on_board(board, 2).health.max_hp = 80
	H.unit_on_board(board, 2).health.current_hp = 80
	var merc: UnitState = H.unit_on_board(board, 1)
	merc.ability.points_left = merc.ability.max_points
	var skill: AbilityData = H.ability_on_unit(merc, &"mercenary_hamstring")
	var basic: AbilityData = H.basic_attack_for_unit(merc)
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(3, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "dual_wield/bonus_basic",
		H.events_ability_count(result.events, basic.id) > 0
			or H.count_event_type(result.events, GameEnums.SimEventType.UNIT_DAMAGED) >= 2,
		"active skill must trigger bonus basic attack",
	)


static func run_precision_edge(failures: Array[String]) -> void:
	var board_full: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.mercenary_with_passive(&"precision_edge")
	cfg["active_abilities"] = [H.factory_ability(&"mercenary_swift_strike")]
	H.place_mercenary(board_full, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board_full, 2, Vector2i(4, 3))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board_full, 1), &"mercenary_swift_strike")
	var plan_full := Timeline.new()
	plan_full.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var loss_full: int = H.hp_loss_from_plan(board_full, plan_full, 2)

	var board_hurt: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board_hurt, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board_hurt, 2, Vector2i(4, 3))
	H.unit_on_board(board_hurt, 2).health.current_hp -= 3
	var plan_hurt := Timeline.new()
	plan_hurt.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var loss_hurt: int = H.hp_loss_from_plan(board_hurt, plan_hurt, 2)
	H.assert_true(
		failures, "precision_edge/outcome/full_hp_target_bonus",
		loss_full > loss_hurt,
		"full-HP targets must take more damage with precision edge",
	)


static func run_duelists_focus(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.mercenary_with_passive(&"duelists_focus")
	cfg["active_abilities"] = [H.factory_ability(&"mercenary_swift_strike")]
	H.place_mercenary(board, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board, 2, Vector2i(4, 3))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_swift_strike")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "duelists_focus/blind",
		H.has_status(H.unit_on_board(result.final_state, 2), GameEnums.StatusType.BLIND),
	)


static func run_tactical_versatility(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.mercenary_with_passive(&"tactical_versatility")
	cfg["active_abilities"] = [H.factory_ability(&"mercenary_feint")]
	H.place_mercenary(board, 1, Vector2i(2, 3), cfg)
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_feint")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(2, 3)))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "tactical_versatility/next_basic",
		result.final_state.get_unit_by_id(1).passive_flags.has("active_next_basic_bonus"),
	)


static func run_swift_feet(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board, 1, Vector2i(3, 3), H.mercenary_with_passive(&"swift_feet"))
	H.place_dummy(board, 2, Vector2i(4, 3))
	var merc: UnitState = H.unit_on_board(board, 1)
	var base_mov: int = merc.movement.max_points
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, H.factory_ability(&"mercenary_feint"), Vector2i(3, 3)))
	var result: SimResult = H.simulate_plan(board, plan)
	MercenarySystems.turn_start(result.final_state, result.final_state.get_unit_by_id(1), [])
	H.assert_true(
		failures, "swift_feet/move_bonus",
		result.final_state.get_unit_by_id(1).movement.max_points > base_mov,
	)
	H.assert_true(
		failures, "swift_feet/ignore_zoc",
		result.final_state.get_unit_by_id(1).passive_flags.get("ignore_zoc", false),
	)
	var upgraded_board: BoardState = H.make_plain_board(Vector2i(10, 8))
	var upgraded_cfg: Dictionary = H.with_upgraded_passive(
		H.mercenary_with_passive(&"swift_feet"), &"swift_feet",
	)
	H.place_mercenary(upgraded_board, 1, Vector2i(3, 3), upgraded_cfg)
	H.place_dummy(upgraded_board, 2, Vector2i(4, 3))
	var upgraded_plan := Timeline.new()
	upgraded_plan.add(H.plan_ability(1, H.factory_ability(&"mercenary_feint"), Vector2i(3, 3)))
	var upgraded_result: SimResult = H.simulate_plan(upgraded_board, upgraded_plan)
	MercenarySystems.turn_start(
		upgraded_result.final_state, upgraded_result.final_state.get_unit_by_id(1), [],
	)
	H.assert_true(
		failures, "swift_feet/upgrade/ignore_difficult",
		upgraded_result.final_state.get_unit_by_id(1).passive_flags.get(
			"ignore_difficult_terrain", false,
		),
	)


static func run_hit_and_run(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.mercenary_with_passive(&"hit_and_run")
	cfg["active_abilities"] = [H.factory_ability(&"mercenary_swift_strike")]
	H.place_mercenary(board, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board, 2, Vector2i(4, 3))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_swift_strike")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "hit_and_run/move_points",
		H.unit_on_board(result.final_state, 1).movement.points_left > 0,
	)


static func run_evasive(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.mercenary_with_passive(&"evasive")
	cfg["active_abilities"] = [H.factory_ability(&"mercenary_tactical_retreat")]
	H.place_mercenary(board, 1, Vector2i(1, 3), cfg)
	var merc: UnitState = H.unit_on_board(board, 1)
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, H.ability_on_unit(merc, &"mercenary_tactical_retreat"), Vector2i(4, 3)))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "evasive/root_flag",
		result.final_state.get_unit_by_id(1).passive_flags.get("root_immune_this_turn", false),
	)
	H.assert_true(
		failures, "evasive/defense",
		H.has_status(
			result.final_state.get_unit_by_id(1), GameEnums.StatusType.STAT_BUFF_DEF,
		),
	)
	var upgraded_board: BoardState = H.make_plain_board(Vector2i(10, 8))
	var upgraded_cfg: Dictionary = H.with_upgraded_passive(
		H.mercenary_with_passive(&"evasive"), &"evasive",
	)
	upgraded_cfg["active_abilities"] = [H.factory_ability(&"mercenary_tactical_retreat")]
	H.place_mercenary(upgraded_board, 1, Vector2i(1, 3), upgraded_cfg)
	var upgraded_plan := Timeline.new()
	upgraded_plan.add(H.plan_ability(
		1,
		H.ability_on_unit(
			H.unit_on_board(upgraded_board, 1), &"mercenary_tactical_retreat",
		),
		Vector2i(4, 3),
	))
	var upgraded_result: SimResult = H.simulate_plan(upgraded_board, upgraded_plan)
	var upgraded_merc: UnitState = upgraded_result.final_state.get_unit_by_id(1)
	H.assert_true(
		failures, "evasive/upgrade/immunities",
		upgraded_merc.passive_flags.get("pull_immune_this_turn", false)
			and upgraded_merc.passive_flags.get("slow_immune_this_turn", false),
	)


static func run_flanking_maneuver(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.mercenary_with_passive(&"flanking_maneuver")
	cfg["active_abilities"] = [H.factory_ability(&"mercenary_swift_strike")]
	H.place_mercenary(board, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board, 2, Vector2i(4, 3))
	var merc: UnitState = H.unit_on_board(board, 1)
	var skill: AbilityData = H.ability_on_unit(merc, &"mercenary_swift_strike")
	H.unit_on_board(board, 2).health.max_hp = 100
	H.unit_on_board(board, 2).health.current_hp = 100
	H.buff_merc_strength(board, 1, 20)
	H.buff_dummy_defense(board, 2, 15)
	var isolated_plan := Timeline.new()
	isolated_plan.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var isolated_loss: int = H.hp_loss_from_plan(board, isolated_plan, 2)
	H.assert_true(
		failures, "flanking_maneuver/outcome/isolated_pierce",
		MercenarySystems.should_pierce(board, merc, H.unit_on_board(board, 2), skill)
			and isolated_loss > 0,
		"the real attack path must resolve damage with the isolated pierce rule",
	)


static func run_dirty_fighting(failures: Array[String]) -> void:
	var board_no: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.mercenary_with_passive(&"dirty_fighting")
	cfg["active_abilities"] = [H.factory_ability(&"mercenary_swift_strike")]
	H.place_mercenary(board_no, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board_no, 2, Vector2i(4, 3))
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board_no, 1), &"mercenary_swift_strike")
	var plan_no := Timeline.new()
	plan_no.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var loss_no: int = H.hp_loss_from_plan(board_no, plan_no, 2)

	var board_yes: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board_yes, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board_yes, 2, Vector2i(4, 3))
	H.unit_on_board(board_yes, 2).active_statuses.append(
		DataLibrary.make_status(GameEnums.StatusType.STAGGER, 1),
	)
	var plan_yes := Timeline.new()
	plan_yes.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var loss_yes: int = H.hp_loss_from_plan(board_yes, plan_yes, 2)
	H.assert_true(
		failures, "dirty_fighting/outcome/stagger_bonus",
		loss_yes > loss_no,
		"staggered targets must take extra damage",
	)


static func run_executioner(failures: Array[String]) -> void:
	var board_no: BoardState = H.make_plain_board(Vector2i(10, 8))
	H.place_mercenary(board_no, 1, Vector2i(2, 3), {
		"active_abilities": [H.factory_ability(&"mercenary_swift_strike")],
		"active_passives": [],
	})
	H.place_dummy(board_no, 2, Vector2i(4, 3))
	H.unit_on_board(board_no, 2).health.current_hp = 40
	H.unit_on_board(board_no, 2).health.max_hp = 100
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board_no, 1), &"mercenary_swift_strike")
	var plan_no := Timeline.new()
	plan_no.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var loss_no: int = H.hp_loss_from_plan(board_no, plan_no, 2)

	var board_yes: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.mercenary_with_passive(&"executioner")
	cfg["active_abilities"] = [H.factory_ability(&"mercenary_swift_strike")]
	H.place_mercenary(board_yes, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board_yes, 2, Vector2i(4, 3))
	H.unit_on_board(board_yes, 2).health.current_hp = 40
	H.unit_on_board(board_yes, 2).health.max_hp = 100
	var plan_yes := Timeline.new()
	plan_yes.add(H.plan_ability(1, skill, Vector2i(4, 3), 2))
	var loss_yes: int = H.hp_loss_from_plan(board_yes, plan_yes, 2)
	H.assert_true(
		failures, "executioner/outcome/wounded_bonus",
		loss_yes > loss_no,
		"executioner must add damage vs targets below 50% HP",
	)


static func run_blood_scent(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.mercenary_with_passive(&"blood_scent")
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
	H.assert_true(
		failures, "blood_scent/outcome/move_bonus",
		H.unit_on_board(result.final_state, 1).movement.max_points > mov_before,
		"moving closer to wounded enemy must grant bonus MOV",
	)


static func run_ruthless(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.mercenary_with_passive(&"ruthless")
	cfg["active_abilities"] = [H.factory_ability(&"mercenary_sever")]
	H.place_mercenary(board, 1, Vector2i(2, 3), cfg)
	H.place_dummy(board, 2, Vector2i(3, 3))
	H.unit_on_board(board, 2).health.current_hp = 1
	var skill: AbilityData = H.ability_on_unit(H.unit_on_board(board, 1), &"mercenary_sever")
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, skill, Vector2i(3, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(
		failures, "ruthless/bonus_flag",
		result.final_state.get_unit_by_id(1).passive_flags.has("ruthless_next_attack_bonus"),
	)


static func run_coup_de_grace(failures: Array[String]) -> void:
	var board: BoardState = H.make_plain_board(Vector2i(10, 8))
	var cfg: Dictionary = H.mercenary_with_passive(&"coup_de_grace")
	var attacker: UnitState = H.place_mercenary(board, 1, Vector2i(2, 3), cfg)
	attacker.health.current_hp = attacker.health.max_hp - 2
	var attacker_hp_before: int = attacker.health.current_hp
	H.place_dummy(board, 2, Vector2i(3, 3))
	H.unit_on_board(board, 2).health.current_hp = 1
	var basic: AbilityData = null
	for ab: AbilityData in H.unit_on_board(board, 1).active_abilities:
		if ab != null and AbilitySystem._is_basic_attack(ab):
			basic = ab
			break
	var plan := Timeline.new()
	plan.add(H.plan_ability(1, basic, Vector2i(3, 3), 2))
	var result: SimResult = H.simulate_plan(board, plan)
	H.assert_true(failures, "coup_de_grace/kill", not H.unit_on_board(result.final_state, 2).is_alive())
	H.assert_eq_int(
		failures, "coup_de_grace/heal",
		H.unit_on_board(result.final_state, 1).health.current_hp - attacker_hp_before,
		1,
	)
	H.assert_true(
		failures, "coup_de_grace/move_refund",
		H.unit_on_board(result.final_state, 1).movement.points_left > 0,
	)
