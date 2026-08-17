extends RefCounted

## Data-driven Mercenary innate, promotion passives, and typed ability extras.
## Does not preload AbilitySystem (circular parse dependency).


static func _is_basic_attack(ability: AbilityData) -> bool:
	if ability == null:
		return false
	return ability.id == &"basic_attack" or String(ability.id).ends_with("_basic")


static func _combat() -> Object:
	return load("res://core/systems/combat_system.gd")


static func passive_modifiers(unit: UnitState, key: StringName) -> Variant:
	if unit == null:
		return null
	for passive: PassiveData in unit.active_passives:
		if passive == null or not passive.modifiers.has(key):
			continue
		return passive.modifiers[key]
	return null


static func passive_mod_value(unit: UnitState, key: StringName, upgraded_key: StringName = &"") -> int:
	if unit == null:
		return 0
	for passive: PassiveData in unit.active_passives:
		if passive == null:
			continue
		if (
			upgraded_key != &""
			and unit.is_passive_upgraded(passive.id)
			and passive.modifiers.has(upgraded_key)
		):
			return int(passive.modifiers[upgraded_key])
		if passive.modifiers.has(key):
			return int(passive.modifiers[key])
	return 0


static func passive_mod_float(unit: UnitState, key: StringName, upgraded_key: StringName = &"") -> float:
	if unit == null:
		return 0.0
	for passive: PassiveData in unit.active_passives:
		if passive == null or not passive.modifiers.has(key):
			continue
		var base_val: float = float(passive.modifiers[key])
		if upgraded_key != &"" and unit.is_passive_upgraded(passive.id) and passive.modifiers.has(upgraded_key):
			return float(passive.modifiers[upgraded_key])
		return base_val
	return 0.0


static func turn_start(board: BoardState, unit: UnitState, events: Array[SimEvent]) -> void:
	if unit == null or not unit.is_alive():
		return
	if unit.passive_flags.get("predatory_following_pending", false):
		var str_bonus: int = int(unit.passive_flags.get("predatory_following_strength", 1))
		var mov_bonus: int = int(unit.passive_flags.get("predatory_following_move", 1))
		unit.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 1, str_bonus))
		unit.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_MOV, 1, mov_bonus))
		unit._recalculate_stats(board)
		unit.passive_flags.erase("predatory_following_pending")
		unit.passive_flags.erase("predatory_following_strength")
		unit.passive_flags.erase("predatory_following_move")
	if unit.passive_flags.get("next_turn_root_immune", false):
		unit.passive_flags["root_immune_this_turn"] = true
		unit.passive_flags.erase("next_turn_root_immune")
	if unit.passive_flags.get("next_turn_pull_immune", false):
		unit.passive_flags["pull_immune_this_turn"] = true
		unit.passive_flags.erase("next_turn_pull_immune")
	if unit.passive_flags.get("next_turn_slow_immune", false):
		unit.passive_flags["slow_immune_this_turn"] = true
		unit.passive_flags.erase("next_turn_slow_immune")
	var adj_enemies := _adjacent_enemy_count(board, unit)
	var per_enemy_mov: int = passive_mod_value(unit, &"adjacent_enemy_move")
	if per_enemy_mov > 0 and adj_enemies > 0:
		unit.movement.max_points += adj_enemies * per_enemy_mov
		unit.movement.points_left += adj_enemies * per_enemy_mov
	if passive_modifiers(unit, &"ignore_zoc") != null:
		unit.passive_flags["ignore_zoc"] = true
	if unit.is_passive_upgraded(&"swift_feet") and passive_modifiers(unit, &"upgraded_ignore_difficult_terrain") != null:
		unit.passive_flags["ignore_difficult_terrain"] = true


static func turn_end_rollover(unit: UnitState) -> void:
	if unit == null:
		return
	var attacker_id: int = int(unit.passive_flags.get("last_attacker_id", -1))
	if attacker_id >= 0:
		unit.passive_flags["attacked_by_last_turn_id"] = attacker_id
	unit.passive_flags.erase("last_attacker_id")
	unit.passive_flags.erase("attacked_this_turn")
	unit.passive_flags.erase("ignore_zoc")
	unit.passive_flags.erase("ignore_difficult_terrain")
	unit.passive_flags.erase("moved_tiles_this_turn")


static func adjust_action_point_cost(
	board: BoardState,
	actor: UnitState,
	ability: AbilityData,
	base_cost: int,
) -> int:
	if actor == null or ability == null:
		return base_cost
	if actor.passive_flags.get("next_skill_zero_ap", false) and not _is_basic_attack(ability):
		return 0
	return base_cost


static func adjust_movement_point_cost(actor: UnitState, ability: AbilityData, base_cost: int) -> int:
	if actor == null or ability == null:
		return base_cost
	var mods: Dictionary = _ability_legacy_mods(actor, ability)
	if mods.has("movement_mp_override"):
		return int(mods["movement_mp_override"])
	return base_cost


static func can_use_extra(
	board: BoardState,
	actor: UnitState,
	ability: AbilityData,
	action: TimelineAction,
) -> bool:
	if actor == null or ability == null or board == null:
		return true
	var mods: Dictionary = _ability_legacy_mods(actor, ability)
	if mods.get("pullback", false):
		var pulled: UnitState = _pullback_front_unit(board, actor.position, action.target_coord)
		if pulled == null or not pulled.is_alive() or pulled.team != actor.team or pulled.id == actor.id:
			return false
	return true


static func before_skill_move(
	board: BoardState,
	actor: UnitState,
	ability: AbilityData,
	events: Array[SimEvent],
) -> void:
	if actor == null or board == null or ability == null:
		return
	actor.passive_flags["__move_start_pos"] = actor.position
	var mods: Dictionary = _ability_legacy_mods(actor, ability)
	if mods.get("smoke_on_start", false):
		_place_smoke(board, actor.position, events)


static func after_skill_move(
	board: BoardState,
	actor: UnitState,
	ability: AbilityData,
	events: Array[SimEvent],
) -> void:
	if actor == null or board == null or ability == null:
		return
	var mods: Dictionary = _ability_legacy_mods(actor, ability)
	if mods.get("pullback", false):
		var start_pos: Vector2i = actor.passive_flags.get("__move_start_pos", actor.position)
		_execute_pullback(board, actor, start_pos, events, mods)
	if mods.has("flank_run_adjacent_enemy_bonus"):
		actor.passive_flags["flank_run_attack_bonus"] = int(mods["flank_run_adjacent_enemy_bonus"])
	var start_pos: Vector2i = actor.passive_flags.get("__move_start_pos", actor.position)
	track_movement_tiles(board, actor, start_pos, actor.position)
	actor.passive_flags.erase("__move_start_pos")


static func adjust_attack_base(
	board: BoardState,
	actor: UnitState,
	target: UnitState,
	ability: AbilityData,
	base_amt: int,
) -> int:
	if actor == null:
		return base_amt
	var amount := base_amt
	var mods: Dictionary = _ability_legacy_mods(actor, ability)
	if mods.has("bleed_bonus_damage") and target != null and target.has_status(GameEnums.StatusType.BLEED):
		amount += int(mods["bleed_bonus_damage"])
	if mods.has("if_target_attacked_caster_last_turn_bonus") and target != null:
		if int(target.passive_flags.get("attacked_by_last_turn_id", -1)) == actor.id:
			amount += int(mods["if_target_attacked_caster_last_turn_bonus"])
	if actor.passive_flags.has("flank_run_attack_bonus"):
		amount += int(actor.passive_flags["flank_run_attack_bonus"])
		actor.passive_flags.erase("flank_run_attack_bonus")
	if actor.passive_flags.has("ruthless_next_attack_bonus"):
		amount += int(actor.passive_flags["ruthless_next_attack_bonus"])
		actor.passive_flags.erase("ruthless_next_attack_bonus")
	if actor.passive_flags.has("active_next_basic_bonus") and _is_basic_attack(ability):
		amount += int(actor.passive_flags["active_next_basic_bonus"])
	if target != null and _target_has_not_acted(target):
		amount += passive_mod_value(actor, &"unacted_attack_bonus")
		if mods.has("unacted_target_ignore_def_pct"):
			pass
	if target != null and target.health.current_hp >= target.health.max_hp:
		amount += passive_mod_value(actor, &"full_hp_attack_bonus", &"upgraded_full_hp_attack_bonus")
	if target != null and _is_controlled(target):
		amount += passive_mod_value(
			actor, &"controlled_target_attack_bonus", &"upgraded_controlled_target_attack_bonus",
		)
	if target != null and _hp_below_threshold(target, _executioner_threshold(actor)):
		amount += passive_mod_value(actor, &"executioner_attack_bonus")
	var ally_bonus: Variant = _legacy_mod_variant(actor, ability, &"bonus_if_target_adjacent_to_ally")
	var ally_adj: bool = (
		target != null
		and _target_adjacent_to_ally(board, target, actor.team, actor)
	)
	if ally_bonus != null and ally_adj:
		amount += int(ally_bonus)
	return amount


static func attack_strength_bonus(
	board: BoardState,
	actor: UnitState,
	target: UnitState,
	ability: AbilityData,
) -> int:
	if actor == null:
		return 0
	var bonus := 0
	if actor.passive_flags.has("next_attack_strength_bonus"):
		bonus += int(actor.passive_flags["next_attack_strength_bonus"])
		actor.passive_flags.erase("next_attack_strength_bonus")
	if target != null and _is_isolated(board, actor):
		bonus += passive_mod_value(
			actor, &"isolated_attack_strength", &"upgraded_isolated_attack_strength",
		)
	return bonus


static func extra_def_ignore_pct(
	board: BoardState,
	actor: UnitState,
	target: UnitState,
	ability: AbilityData,
) -> float:
	if actor == null:
		return 0.0
	var mods: Dictionary = _ability_legacy_mods(actor, ability)
	var ignore := 0.0
	if mods.has("unacted_target_ignore_def_pct") and target != null and _target_has_not_acted(target):
		ignore = maxf(ignore, float(mods["unacted_target_ignore_def_pct"]))
	if actor.passive_flags.get("active_next_basic_ignore_def", false) and _is_basic_attack(ability):
		ignore = maxf(ignore, float(actor.passive_flags.get("active_next_basic_ignore_def_pct", 0.5)))
	if actor.passive_flags.get("bonus_basic_ignore_def", false) and _is_basic_attack(ability):
		ignore = maxf(ignore, float(actor.passive_flags.get("bonus_basic_ignore_def_pct", 0.5)))
	if passive_modifiers(actor, &"strength_over_def_ignore_pct") != null and target != null:
		if actor.current_strength > target.current_defense:
			var pct: float = passive_mod_float(
				actor, &"strength_over_def_ignore_pct", &"upgraded_strength_over_def_ignore_pct",
			)
			ignore = maxf(ignore, pct)
	if passive_modifiers(actor, &"executioner_ignore_def") != null and target != null:
		if _hp_below_threshold(target, _executioner_threshold(actor)):
			ignore = 1.0
	return ignore


static func should_pierce(
	board: BoardState,
	actor: UnitState,
	target: UnitState,
	ability: AbilityData,
) -> bool:
	if actor == null:
		return false
	var mods: Dictionary = _ability_legacy_mods(actor, ability)
	if mods.get("pierce", false):
		return true
	if actor.passive_flags.get("next_attack_pierce", false):
		return true
	if passive_modifiers(actor, &"isolated_attack_pierce") != null and _is_isolated(board, actor):
		return true
	return false


static func on_dealt_damage(
	board: BoardState,
	actor: UnitState,
	target: UnitState,
	events: Array[SimEvent],
	is_basic: bool,
	was_full_hp: bool = false,
) -> void:
	if actor == null or not actor.is_alive():
		return
	actor.passive_flags["attacked_this_turn"] = true
	if target != null and actor.passive_flags.get("next_attack_bleed_weapon", false):
		var bleed_amount: int = 1
		if actor.definition != null and actor.definition.equipped_weapon != null:
			bleed_amount = actor.definition.equipped_weapon.might
		target.active_statuses.append(
			DataLibrary.make_status(GameEnums.StatusType.BLEED, 1, bleed_amount)
		)
		events.append(SimEvent.make(GameEnums.SimEventType.STATUS_APPLIED, {
			"unit": target.id,
			"status_type": GameEnums.StatusType.BLEED,
			"duration": 1,
			"amount": bleed_amount,
		}))
	if _has_predatory_momentum(actor):
		var str_bonus: int = passive_mod_value(actor, &"predatory_following_strength", &"upgraded_predatory_following_strength")
		var mov_bonus: int = passive_mod_value(actor, &"predatory_following_move", &"upgraded_predatory_following_move")
		actor.passive_flags["predatory_following_pending"] = true
		actor.passive_flags["predatory_following_strength"] = str_bonus
		actor.passive_flags["predatory_following_move"] = mov_bonus
	if passive_mod_value(actor, &"after_damage_move") > 0:
		var move_amt: int = passive_mod_value(actor, &"after_damage_move", &"upgraded_after_damage_move")
		actor.movement.points_left = mini(actor.movement.max_points, actor.movement.points_left + move_amt)
	if target != null and was_full_hp:
		if passive_modifiers(actor, &"full_hp_attack_bleed_weapon") != null:
			var wpn: int = 0
			if actor.definition != null and actor.definition.equipped_weapon != null:
				wpn = actor.definition.equipped_weapon.might
			if wpn > 0:
				target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.BLEED, 1, wpn))
	if target != null and _target_has_not_acted(target):
		if passive_modifiers(actor, &"unacted_attack_blind") != null:
			target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.BLIND, 1))
		if actor.is_passive_upgraded(&"duelists_focus") and passive_modifiers(actor, &"upgraded_unacted_attack_weaken") != null:
			target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.WEAKEN, 1))
	if target != null:
		var ability: AbilityData = actor.passive_flags.get("__current_ability", null) as AbilityData
		var mods: Dictionary = _ability_legacy_mods(actor, ability)
		if mods.has("if_target_attacked_caster_last_turn_stagger"):
			if int(target.passive_flags.get("attacked_by_last_turn_id", -1)) == actor.id:
				target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAGGER, 1))
		if mods.has("target_damaged_ap") and target.passive_flags.get("damaged_this_turn", false):
			actor.ability.points_left = mini(actor.ability.max_points, actor.ability.points_left + int(mods["target_damaged_ap"]))
	if is_basic and actor.passive_flags.get("predatory_free_move_pending", false):
		var free_move: int = passive_mod_value(actor, &"predatory_free_move")
		actor.movement.points_left = mini(actor.movement.max_points, actor.movement.points_left + free_move)
		actor.passive_flags.erase("predatory_free_move_pending")


static func on_kill(
	board: BoardState,
	attacker: UnitState,
	target: UnitState,
	events: Array[SimEvent],
	source_label: String,
	is_basic: bool,
) -> void:
	if attacker == null or not attacker.is_alive():
		return
	var ability: AbilityData = attacker.passive_flags.get("__current_ability", null) as AbilityData
	var mods: Dictionary = _ability_legacy_mods(attacker, ability)
	if mods.has("on_kill_all_allies_heal"):
		for unit: UnitState in board.units:
			if unit != null and unit.is_alive() and unit.team == attacker.team:
				_combat().heal(board, unit, int(mods["on_kill_all_allies_heal"]), events)
	if mods.has("on_kill_all_allies_shield"):
		for unit: UnitState in board.units:
			if unit != null and unit.is_alive() and unit.team == attacker.team:
				_combat().add_armor(board, unit, int(mods["on_kill_all_allies_shield"]), events)
	if passive_mod_value(attacker, &"kill_refund_ap") > 0:
		attacker.ability.points_left = mini(
			attacker.ability.max_points,
			attacker.ability.points_left + passive_mod_value(attacker, &"kill_refund_ap"),
		)
	var ruthless_bonus: int = passive_mod_value(
		attacker, &"kill_next_attack_bonus", &"upgraded_kill_next_attack_bonus",
	)
	if ruthless_bonus > 0:
		attacker.passive_flags["ruthless_next_attack_bonus"] = ruthless_bonus
	if is_basic:
		var heal: int = passive_mod_value(attacker, &"basic_kill_heal")
		if heal > 0:
			_combat().heal(board, attacker, heal, events)
		var move_bonus: int = passive_mod_value(attacker, &"basic_kill_move")
		if move_bonus > 0:
			attacker.movement.max_points += move_bonus
			attacker.movement.points_left += move_bonus
		if attacker.is_passive_upgraded(&"coup_de_grace"):
			var fear_range: int = passive_mod_value(attacker, &"upgraded_basic_kill_fear_range")
			_apply_fear_near(board, attacker, fear_range, events)
	if (
		attacker.passive_flags.get("movement_before_attack", false)
		or attacker.movement_points_spent_this_turn > 0
	):
		var kill_ap: int = passive_mod_value(
			attacker,
			&"movement_before_attack_kill_ap",
			&"upgraded_movement_before_attack_kill_ap",
		)
		if kill_ap > 0:
			attacker.ability.points_left = mini(attacker.ability.max_points, attacker.ability.points_left + kill_ap)


static func after_ability_execute(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	events: Array[SimEvent],
	attack_was_used: bool,
) -> void:
	if actor == null or action == null:
		return
	var ability: AbilityData = action.ability
	actor.passive_flags.erase("__current_ability")
	if ability != null and not _is_basic_attack(ability):
		if _ability_has_movement_tag(ability):
			_apply_calculated_strike(board, actor)
		if passive_mod_value(actor, &"active_next_basic_bonus") > 0:
			actor.passive_flags["active_next_basic_bonus"] = passive_mod_value(actor, &"active_next_basic_bonus")
			actor.passive_flags["active_free_move_pending"] = passive_mod_value(actor, &"active_free_move")
			if actor.is_passive_upgraded(&"tactical_versatility"):
				actor.passive_flags["active_next_basic_ignore_def"] = true
				actor.passive_flags["active_next_basic_ignore_def_pct"] = float(
					passive_modifiers(actor, &"upgraded_active_next_basic_ignore_def_pct")
				)
		if (
			passive_mod_value(actor, &"active_skill_bonus_basic_attack") > 0
			and action.target_unit_id >= 0
		):
			_queue_bonus_basic(board, actor, action, events)
	if actor.passive_flags.get("active_free_move_pending", 0) > 0:
		var pending: int = int(actor.passive_flags["active_free_move_pending"])
		actor.movement.points_left = mini(actor.movement.max_points, actor.movement.points_left + pending)
		actor.passive_flags.erase("active_free_move_pending")
	var post_mods: Dictionary = _ability_legacy_mods(actor, ability)
	if ability != null:
		if post_mods.get("next_attack_pierce", false):
			actor.passive_flags["next_attack_pierce"] = true
		if post_mods.has("next_attack_strength"):
			actor.passive_flags["next_attack_strength_bonus"] = int(post_mods["next_attack_strength"])
		if post_mods.has("target_def_pct_debuff") and actor.is_ability_upgraded(ability.id):
			actor.passive_flags["feint_def_debuff_pct"] = float(post_mods["target_def_pct_debuff"])
			actor.passive_flags["feint_def_debuff_duration"] = int(
				post_mods.get("target_def_pct_duration", 2),
			)
		if post_mods.get("duelist_mark_target", false) and action.target_unit_id >= 0:
			actor.passive_flags["duelist_mark_target_id"] = action.target_unit_id
			if post_mods.has("marked_target_defense"):
				actor.passive_flags["duelist_mark_defense_bonus"] = int(post_mods["marked_target_defense"])
			else:
				actor.passive_flags.erase("duelist_mark_defense_bonus")
		if post_mods.get("next_skill_zero_ap", false) and actor.is_ability_upgraded(ability.id):
			actor.passive_flags["next_skill_zero_ap"] = true
	if attack_was_used:
		actor.passive_flags.erase("next_attack_bleed_weapon")


static func apply_feint_on_target(target: UnitState, actor: UnitState) -> void:
	if actor == null or target == null:
		return
	if actor.passive_flags.has("feint_def_debuff_pct"):
		var pct: float = float(actor.passive_flags["feint_def_debuff_pct"])
		var duration: int = int(actor.passive_flags.get("feint_def_debuff_duration", 2))
		var debuff := DataLibrary.make_status(GameEnums.StatusType.STAT_DEBUFF_DEF, duration)
		debuff.amount = maxi(1, ceili(target.current_defense * pct))
		target.active_statuses.append(debuff)
		actor.passive_flags.erase("feint_def_debuff_pct")
		actor.passive_flags.erase("feint_def_debuff_duration")


static func marked_defense_bonus(defender: UnitState, attacker: UnitState) -> int:
	if defender == null or attacker == null:
		return 0
	if int(defender.passive_flags.get("duelist_mark_target_id", -1)) != attacker.id:
		return 0
	return int(defender.passive_flags.get("duelist_mark_defense_bonus", 0))


static func track_movement_tiles(
	board: BoardState,
	unit: UnitState,
	from: Vector2i,
	to: Vector2i,
) -> void:
	if unit == null:
		return
	var dist: int = GridSystem.manhattan(from, to)
	if dist <= 0:
		return
	var moved: int = int(unit.passive_flags.get("moved_tiles_this_turn", 0)) + dist
	unit.passive_flags["moved_tiles_this_turn"] = moved
	var threshold: int = passive_mod_value(unit, &"moved_tiles_evasive_threshold")
	if threshold > 0 and moved >= threshold:
		var def_bonus: int = passive_mod_value(unit, &"moved_tiles_evasive_defense")
		if def_bonus > 0:
			unit.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, def_bonus))
		if passive_modifiers(unit, &"moved_tiles_root_immunity") != null:
			unit.passive_flags["root_immune_this_turn"] = true
		if unit.is_passive_upgraded(&"evasive"):
			if passive_modifiers(unit, &"upgraded_moved_pull_immunity") != null:
				unit.passive_flags["pull_immune_this_turn"] = true
			if passive_modifiers(unit, &"upgraded_moved_slow_immunity") != null:
				unit.passive_flags["slow_immune_this_turn"] = true
	var blood_threshold: float = _passive_threshold(unit, &"blood_scent_threshold")
	if board != null and blood_threshold > 0.0:
		var before_dist: int = _nearest_wounded_enemy_distance(board, unit, from, blood_threshold)
		var after_dist: int = _nearest_wounded_enemy_distance(board, unit, to, blood_threshold)
		if before_dist >= 0 and after_dist >= 0 and after_dist < before_dist:
			var blood_mov: int = passive_mod_value(
				unit, &"blood_scent_move", &"upgraded_blood_scent_move",
			)
			if blood_mov > 0:
				unit.active_statuses.append(
					DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_MOV, 1, blood_mov),
				)
				unit._recalculate_stats(board)
				unit.movement.points_left += blood_mov


static func _nearest_wounded_enemy_distance(
	board: BoardState,
	actor: UnitState,
	from: Vector2i,
	threshold: float,
) -> int:
	if board == null or actor == null:
		return -1
	var best: int = -1
	for unit: UnitState in board.units:
		if unit == null or not unit.is_alive() or unit.team == actor.team:
			continue
		if not _hp_below_threshold(unit, threshold):
			continue
		var dist: int = GridSystem.manhattan(from, unit.position)
		if best < 0 or dist < best:
			best = dist
	return best


static func _queue_bonus_basic(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	events: Array[SimEvent],
) -> void:
	var basic: AbilityData = null
	for ab: AbilityData in actor.active_abilities:
		if ab != null and _is_basic_attack(ab):
			basic = ab
			break
	if basic == null:
		return
	var followup := TimelineAction.make_ability(
		actor.id, basic, action.target_coord, action.target_unit_id,
	)
	var ability_system: Object = load("res://core/systems/ability_system.gd")
	actor.passive_flags["dual_wield_bonus_basic"] = true
	if not ability_system.can_use(board, followup):
		actor.passive_flags.erase("dual_wield_bonus_basic")
		return
	actor.passive_flags["bonus_basic_ignore_def"] = actor.is_passive_upgraded(&"dual_wield_momentum")
	if actor.passive_flags["bonus_basic_ignore_def"]:
		actor.passive_flags["bonus_basic_ignore_def_pct"] = passive_mod_float(
			actor, &"upgraded_bonus_basic_ignore_def_pct",
		)
	ability_system.execute(board, followup, events)
	actor.passive_flags.erase("dual_wield_bonus_basic")


static func _pullback_front_unit(
	board: BoardState,
	start_pos: Vector2i,
	dest: Vector2i,
) -> UnitState:
	if board == null:
		return null
	var delta := dest - start_pos
	if delta == Vector2i.ZERO:
		return null
	return board.get_unit_at(start_pos - delta)


static func _execute_pullback(
	board: BoardState,
	actor: UnitState,
	start_pos: Vector2i,
	events: Array[SimEvent],
	mods: Dictionary,
) -> void:
	var delta := actor.position - start_pos
	if delta == Vector2i.ZERO:
		return
	var pulled: UnitState = _pullback_front_unit(board, start_pos, actor.position)
	if pulled == null or not pulled.is_alive() or pulled.team != actor.team or pulled.id == actor.id:
		return
	var dest := pulled.position + delta
	if GridSystem.is_wall(board, dest) or GridSystem.is_occupied(board, dest):
		return
	GridSystem.set_occupant(board, pulled.position, -1)
	pulled.position = dest
	GridSystem.set_occupant(board, dest, pulled.id)
	events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {"unit": pulled.id, "to": dest}))
	if mods.has("pullback_ally_def"):
		pulled.active_statuses.append(
			DataLibrary.make_status(
				GameEnums.StatusType.STAT_BUFF_DEF, 1, int(mods["pullback_ally_def"]),
			),
		)
		pulled._recalculate_stats(board)


static func _place_smoke(board: BoardState, coord: Vector2i, events: Array[SimEvent]) -> void:
	var smoke: TerrainData = DataLibrary.get_terrain(&"smoke")
	if smoke == null:
		return
	var tile := board.get_tile(coord)
	if tile != null and not board.temporary_terrain_previous.has(coord):
		board.temporary_terrain_previous[coord] = tile.definition
	board.set_tile_terrain(coord, smoke)
	board.temporary_terrain_turns[coord] = 2
	events.append(SimEvent.make(GameEnums.SimEventType.TERRAIN_CHANGED, {
		"coord": coord, "terrain": smoke.id,
	}))


static func _apply_fear_near(
	board: BoardState,
	actor: UnitState,
	range_tiles: int,
	events: Array[SimEvent],
) -> void:
	var nearest: UnitState = null
	var nearest_dist := 1_000_000
	for candidate: UnitState in board.units:
		if candidate == null or not candidate.is_alive() or candidate.team == actor.team:
			continue
		var dist := GridSystem.manhattan(actor.position, candidate.position)
		if dist <= range_tiles and dist < nearest_dist:
			nearest = candidate
			nearest_dist = dist
	if nearest != null:
		nearest.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.FEAR, 1))


static func _legacy_mod_variant(
	actor: UnitState,
	ability: AbilityData,
	key: StringName,
) -> Variant:
	if ability == null:
		return null
	var mods: Dictionary = _ability_legacy_mods(actor, ability)
	if mods.has(key):
		return mods[key]
	var str_key := String(key)
	if mods.has(str_key):
		return mods[str_key]
	return null


static func _ability_legacy_mods(actor: UnitState, ability: AbilityData) -> Dictionary:
	return AbilitySystem.active_modifier_profile(actor, ability)


static func _resolve_target_unit(board: BoardState, action: TimelineAction) -> UnitState:
	return AbilitySystem.resolve_action_target(board, action)


static func _has_predatory_momentum(unit: UnitState) -> bool:
	return passive_modifiers(unit, &"predatory_momentum") != null


static func _predatory_threshold(unit: UnitState) -> float:
	return passive_mod_float(unit, &"predatory_threshold", &"upgraded_predatory_threshold")


static func _executioner_threshold(unit: UnitState) -> float:
	return passive_mod_float(
		unit, &"executioner_threshold", &"upgraded_executioner_threshold",
	)


static func _hp_below_threshold(unit: UnitState, threshold: float) -> bool:
	if unit == null or unit.health == null or unit.health.max_hp <= 0:
		return false
	return float(unit.health.current_hp) / float(unit.health.max_hp) < threshold


static func consume_next_skill_zero_ap(actor: UnitState, ability: AbilityData) -> void:
	if actor == null or ability == null:
		return
	if actor.passive_flags.get("next_skill_zero_ap", false) and not _is_basic_attack(ability):
		actor.passive_flags.erase("next_skill_zero_ap")


static func _ability_has_movement_tag(ability: AbilityData) -> bool:
	if ability == null:
		return false
	return ability.tags.has(&"movement")


static func _apply_calculated_strike(board: BoardState, actor: UnitState) -> void:
	if actor == null or passive_mod_value(actor, &"movement_before_attack_strength") <= 0:
		return
	actor.passive_flags["movement_before_attack"] = true
	var str_bonus: int = passive_mod_value(actor, &"movement_before_attack_strength")
	var def_bonus: int = passive_mod_value(actor, &"movement_before_attack_defense")
	if str_bonus > 0:
		actor.active_statuses.append(
			DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 1, str_bonus),
		)
	if def_bonus > 0:
		actor.active_statuses.append(
			DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, def_bonus),
		)
	actor._recalculate_stats(board)


static func _target_has_not_acted(target: UnitState) -> bool:
	if target == null:
		return false
	return not target.turn_action_used


static func _is_isolated(board: BoardState, actor: UnitState) -> bool:
	for dir: Vector2i in GridSystem.DIRECTIONS:
		var ally := board.get_unit_at(actor.position + dir)
		if ally != null and ally.is_alive() and ally.team == actor.team and ally.id != actor.id:
			return false
	return true


static func _is_controlled(target: UnitState) -> bool:
	return (
		target.has_status(GameEnums.StatusType.STAGGER)
		or target.has_status(GameEnums.StatusType.ROOT)
		or target.has_status(GameEnums.StatusType.POISON)
	)


static func _target_adjacent_to_ally(
	board: BoardState,
	target: UnitState,
	team: GameEnums.Team,
	actor: UnitState = null,
) -> bool:
	if board == null or target == null:
		return false
	for unit: UnitState in board.units:
		if unit == null or not unit.is_alive() or unit.team != team or unit.id == target.id:
			continue
		if actor != null and unit.id == actor.id:
			continue
		if GridSystem.manhattan(unit.position, target.position) == 1:
			return true
	return false


static func _adjacent_enemy_count(board: BoardState, actor: UnitState) -> int:
	var count := 0
	for dir: Vector2i in GridSystem.DIRECTIONS:
		var unit := board.get_unit_at(actor.position + dir)
		if unit != null and unit.is_alive() and unit.team != actor.team:
			count += 1
	return count


static func _passive_threshold(unit: UnitState, key: StringName) -> float:
	var raw: Variant = passive_modifiers(unit, key)
	if raw == null:
		return -1.0
	return float(raw)


