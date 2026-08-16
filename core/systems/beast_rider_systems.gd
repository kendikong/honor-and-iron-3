class_name BeastRiderSystems
extends RefCounted

## Shared runtime owner for Beast Rider's authored movement, landing, and
## pursuit rules. All behavior is selected by passive/module data flags.


static func has_passive_modifier(unit: UnitState, key: StringName) -> bool:
	if unit == null:
		return false
	for passive: PassiveData in unit.active_passives:
		if passive != null and passive.modifiers.has(key):
			return true
	return false


static func passive_value(
	unit: UnitState,
	key: StringName,
	upgraded_key: StringName,
	default_value: Variant,
) -> Variant:
	if unit == null:
		return default_value
	for passive: PassiveData in unit.active_passives:
		if passive == null or not passive.modifiers.has(key):
			continue
		if (
			upgraded_key != &""
			and unit.is_passive_upgraded(passive.id)
			and passive.modifiers.has(upgraded_key)
		):
			return passive.modifiers[upgraded_key]
		return passive.modifiers[key]
	return default_value


static func active_module_modifiers(actor: UnitState, ability: AbilityData) -> Dictionary:
	return AbilitySystem.active_modifier_profile(actor, ability)


static func turn_start(board: BoardState, unit: UnitState, _events: Array[SimEvent]) -> void:
	if unit == null or not unit.is_alive():
		return
	apply_promotion_airborne(unit, board)
	unit.passive_flags.erase("beast_split_attack_ready")
	unit.passive_flags.erase("beast_post_move_defense")


static func apply_promotion_airborne(unit: UnitState, board: BoardState = null) -> void:
	if unit == null or unit.has_status(GameEnums.StatusType.AIRBORNE):
		return
	var from_passive := has_passive_modifier(unit, &"airborne")
	var from_promotion := false
	if unit.definition != null:
		var bonuses: Dictionary = unit.definition.promotion_stat_bonuses.get(unit.promotion_id, {})
		from_promotion = bool(bonuses.get("airborne", false))
	if not from_passive and not from_promotion:
		return
	unit.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.AIRBORNE, 1))
	unit._recalculate_stats(board)


static func turn_end(_board: BoardState, unit: UnitState, _events: Array[SimEvent]) -> void:
	if unit == null:
		return
	unit.passive_flags.erase("beast_move_start")
	unit.passive_flags.erase("beast_tiles_moved")
	unit.passive_flags.erase("beast_split_attack_ready")
	unit.passive_flags.erase("beast_post_move_defense")
	unit.passive_flags.erase("beast_furious_charge_push")
	unit.passive_flags.erase("beast_maul_used")
	_drop_carried_ally(_board, unit, null, _events)


static func can_post_move(unit: UnitState) -> bool:
	return unit != null and has_passive_modifier(unit, &"split_movement")


static func prepare_action(board: BoardState, plan: Timeline, action: TimelineAction) -> void:
	if board == null or plan == null or action == null or action.type != GameEnums.ActionType.ABILITY:
		return
	var actor := board.get_unit_by_id(action.actor_id)
	if actor == null or not has_passive_modifier(actor, &"split_movement"):
		return
	for planned: TimelineAction in plan.entries:
		if (
			planned.actor_id == actor.id
			and planned.type == GameEnums.ActionType.MOVE
			and planned.move_timing == GameEnums.MoveTiming.POST_ACTION
		):
			actor.passive_flags["beast_split_attack_ready"] = true
			return


static func can_use_extra(
	board: BoardState,
	actor: UnitState,
	ability: AbilityData,
	action: TimelineAction,
) -> bool:
	if board == null or actor == null or ability == null or action == null:
		return false
	var modules := active_module_modifiers(actor, ability)
	if modules.get("feral_drag", false):
		var drag_range := int(passive_value(actor, &"grapple_range", &"upgraded_grapple_range", 1))
		if GridSystem.manhattan(actor.position, action.target_coord) > drag_range:
			return false
	return true


static func before_skill_move(
	_board: BoardState,
	unit: UnitState,
	_ability: AbilityData,
	_events: Array[SimEvent],
) -> void:
	if unit == null:
		return
	if not unit.passive_flags.has("beast_move_start"):
		unit.passive_flags["beast_move_start"] = unit.position


static func after_skill_move(
	board: BoardState,
	unit: UnitState,
	ability: AbilityData,
	events: Array[SimEvent],
) -> void:
	if unit == null or board == null:
		return
	_record_move_segment(unit)
	var modules := active_module_modifiers(unit, ability)
	if modules.get("pounce_land_adjacent", false):
		on_landing(board, unit, events)
	if modules.get("drag_remaining_movement", false):
		_drag_target_for_remaining_movement(board, unit, ability, events)


static func after_standard_move(
	board: BoardState,
	unit: UnitState,
	events: Array[SimEvent],
) -> void:
	if unit == null or board == null:
		return
	var move_start: Vector2i = unit.passive_flags.get("beast_move_start", unit.position)
	_record_move_segment(unit)
	var min_charge_tiles: int = int(passive_value(
		unit, &"furious_charge_min_tiles", &"", 0,
	))
	var straight_tiles := unit.continuous_straight_tiles_this_turn
	if straight_tiles <= 0 and PhysicsSystem.straight_line_dir(move_start, unit.position) != Vector2i.ZERO:
		straight_tiles = GridSystem.manhattan(move_start, unit.position)
	if min_charge_tiles > 0 and straight_tiles >= min_charge_tiles:
		var push_amount: int = int(passive_value(
			unit, &"furious_charge_push", &"upgraded_furious_charge_push", 0,
		))
		if push_amount > 0:
			unit.passive_flags["beast_furious_charge_push"] = push_amount
	_grant_blood_scent_move(board, unit, move_start, unit.position)
	_sync_carried_ally(board, unit)
	_try_airlift_drop(board, unit, events)
	events.append(SimEvent.make(GameEnums.SimEventType.MATH_TELEMETRY, {
		"beast_tiles_moved": int(unit.passive_flags.get("beast_tiles_moved", 0)),
		"unit": unit.id,
	}))


static func _record_move_segment(unit: UnitState) -> void:
	if unit == null:
		return
	var start: Vector2i = unit.passive_flags.get("beast_move_start", unit.position)
	var segment := GridSystem.manhattan(start, unit.position)
	unit.passive_flags["beast_tiles_moved"] = int(
		unit.passive_flags.get("beast_tiles_moved", 0)
	) + segment
	if unit.turn_action_used and unit.is_passive_upgraded(&"gallop"):
		unit.passive_flags["beast_post_move_defense"] = int(
			passive_value(unit, &"upgraded_split_post_defense", &"", 1)
		)
	unit.passive_flags.erase("beast_move_start")


static func dynamic_stat_adjustments(board: BoardState, unit: UnitState) -> Dictionary:
	var result := {"strength": 0, "magic": 0, "defense": 0, "movement": 0}
	if board == null or unit == null:
		return result
	for source: UnitState in board.units:
		if (
			source == null
			or not source.is_alive()
			or source.team == unit.team
			or not has_passive_modifier(source, &"intimidating_presence_range")
		):
			continue
		var range_tiles := int(passive_value(
			source,
			&"intimidating_presence_range",
			&"upgraded_intimidating_presence_range",
			2,
		))
		if GridSystem.manhattan(source.position, unit.position) > range_tiles:
			continue
		result.defense -= int(passive_value(source, &"intimidating_presence_def", &"", 1))
		result.movement -= int(passive_value(source, &"intimidating_presence_move", &"", 1))
	if int(unit.passive_flags.get("beast_post_move_defense", 0)) > 0:
		result.defense += int(unit.passive_flags["beast_post_move_defense"])
	if int(unit.passive_flags.get("beast_airlift_next_strength", 0)) > 0:
		result.strength += int(unit.passive_flags["beast_airlift_next_strength"])
	return result


static func attack_strength_bonus(
	board: BoardState,
	attacker: UnitState,
	target: UnitState,
) -> int:
	if board == null or attacker == null or target == null:
		return 0
	var bonus := 0
	if has_passive_modifier(attacker, &"isolation_attack_strength") and _is_isolated(board, target):
		bonus += int(passive_value(attacker, &"isolation_attack_strength", &"", 2))
	if (
		attacker.passive_flags.get("beast_split_attack_ready", false)
		and attacker.is_passive_upgraded(&"gallop")
	):
		bonus += int(passive_value(attacker, &"upgraded_split_attack_strength", &"", 1))
	if (
		has_passive_modifier(attacker, &"vantage_attack_strength")
		and _is_hazard_or_elevated(board, attacker)
	):
		bonus += int(passive_value(
			attacker, &"vantage_attack_strength", &"upgraded_vantage_attack_strength", 1,
		))
	return bonus


static func damage_bonus(
	board: BoardState,
	attacker: UnitState,
	target: UnitState,
	_effect: EffectData,
) -> int:
	if board == null or attacker == null or target == null:
		return 0
	var bonus := 0
	if (
		attacker.is_passive_upgraded(&"isolation_tactics")
		and has_passive_modifier(attacker, &"upgraded_moved_tile_attack_strength")
	):
		var moved_tile_bonus := int(passive_value(
			attacker, &"upgraded_moved_tile_attack_strength", &"", 0,
		))
		if moved_tile_bonus > 0:
			bonus += moved_tile_bonus * int(attacker.passive_flags.get("beast_tiles_moved", 0))
	var dive_min := int(passive_value(
		attacker, &"dive_bomber_min_tiles", &"upgraded_dive_bomber_min_tiles", 0,
	))
	if dive_min > 0 and int(attacker.passive_flags.get("beast_tiles_moved", 0)) >= dive_min:
		bonus += int(passive_value(attacker, &"dive_bomber_attack_strength", &"", 2))
	var furious_push := int(attacker.passive_flags.get("beast_furious_charge_push", 0))
	if furious_push > 0:
		attacker.passive_flags["beast_pending_push"] = furious_push
	return bonus


static func should_pierce(
	board: BoardState,
	attacker: UnitState,
	target: UnitState,
	_effect: EffectData,
) -> bool:
	if board == null or attacker == null or target == null:
		return false
	if not has_passive_modifier(attacker, &"blood_scent_pierce"):
		return false
	return _is_bleeding(target) and _is_moving_toward(attacker, target)


static func on_attack_hit(
	board: BoardState,
	attacker: UnitState,
	target: UnitState,
	events: Array[SimEvent],
) -> void:
	if board == null or attacker == null or target == null:
		return
	var ability: AbilityData = attacker.passive_flags.get("__current_ability", null) as AbilityData
	var mods := active_module_modifiers(attacker, ability)
	if (
		has_passive_modifier(attacker, &"predatory_bleed_weapon")
		and (_is_bleeding(target) or _is_isolated(board, target))
	):
		var weapon_might := _weapon_might(attacker)
		target.active_statuses.append(DataLibrary.make_status(
			GameEnums.StatusType.BLEED, 1, weapon_might,
		))
		if attacker.is_passive_upgraded(&"predatory_drive"):
			target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.POISON, 1))
		target._recalculate_stats(board)
	if int(mods.get("landing_push", 0)) > 0:
		var land_dir := PhysicsSystem.cardinal_from_to(attacker.position, target.position)
		if land_dir != Vector2i.ZERO:
			PhysicsSystem.push(
				board, target, land_dir, int(mods["landing_push"]), events, attacker,
			)
	_try_pack_hunter_bite(board, attacker, target, events)
	var pending_push := int(attacker.passive_flags.get("beast_pending_push", 0))
	if pending_push > 0:
		var push_dir := PhysicsSystem.cardinal_from_to(attacker.position, target.position)
		PhysicsSystem.push(board, target, push_dir, pending_push, events, attacker)
		attacker.passive_flags.erase("beast_pending_push")


static func on_kill(
	board: BoardState,
	attacker: UnitState,
	target: UnitState,
	events: Array[SimEvent],
) -> void:
	if board == null or attacker == null or target == null:
		return
	var ability: AbilityData = attacker.passive_flags.get("__current_ability", null) as AbilityData
	var mods := active_module_modifiers(attacker, ability)
	if int(mods.get("on_kill_shield", 0)) > 0:
		CombatSystem.add_armor(board, attacker, int(mods["on_kill_shield"]), events)


static func _try_pack_hunter_bite(
	board: BoardState,
	attacker: UnitState,
	target: UnitState,
	events: Array[SimEvent],
) -> void:
	if board == null or attacker == null or target == null:
		return
	if attacker.passive_flags.get("pack_hunter_resolving", false):
		return
	var bite := int(passive_value(
		attacker, &"pack_hunter_bite", &"upgraded_pack_hunter_bite", 0,
	))
	if bite <= 0 or not _is_isolated(board, target):
		return
	var ignore_pct := float(passive_value(
		attacker, &"pack_hunter_def_ignore_pct", &"", 0.50,
	))
	var prev_ignore := int(attacker.passive_flags.get("attack_ignore_def", 0))
	var target_def := CombatSystem.get_dynamic_defense(board, target)
	attacker.passive_flags["pack_hunter_resolving"] = true
	attacker.passive_flags["attack_ignore_def"] = prev_ignore + floori(float(target_def) * ignore_pct)
	var scaled := CombatSystem.calculate_scaled_damage(
		attacker, bite, GameEnums.StatType.PHYSICAL, board,
	)
	CombatSystem.deal_damage_raw(
		board, attacker, target, scaled, GameEnums.StatType.PHYSICAL,
		events, "Pack Hunter", bite,
	)
	attacker.passive_flags["attack_ignore_def"] = prev_ignore
	attacker.passive_flags.erase("pack_hunter_resolving")


static func incoming_damage_reduction(
	board: BoardState,
	target: UnitState,
	source_type: StringName,
	attacker: UnitState,
) -> int:
	if (
		board == null
		or target == null
		or source_type != &"physical"
		or attacker == null
		or GridSystem.manhattan(attacker.position, target.position) <= 1
	):
		return 0
	var base := int(passive_value(
		target,
		&"ranged_damage_reduction_base",
		&"upgraded_ranged_damage_reduction_base",
		0,
	))
	if base <= 0:
		return 0
	return floori(float(target.current_defense) / 2.0) + base


static func on_enemy_entered_adjacent(
	board: BoardState,
	watcher: UnitState,
	intruder: UnitState,
	events: Array[SimEvent],
) -> void:
	if board == null or watcher == null or intruder == null:
		return
	if watcher.team == intruder.team or not intruder.is_alive():
		return
	if GridSystem.manhattan(watcher.position, intruder.position) != 1:
		return
	var attack := int(passive_value(
		watcher, &"adjacent_entry_attack", &"upgraded_adjacent_entry_attack", 0,
	))
	if attack <= 0:
		return
	var raw := CombatSystem.calculate_scaled_damage(
		watcher, attack, GameEnums.StatType.PHYSICAL, board,
	)
	CombatSystem.deal_damage_raw(
		board,
		watcher,
		intruder,
		raw,
		GameEnums.StatType.PHYSICAL,
		events,
		"Territorial",
		attack,
	)


static func on_landing(
	board: BoardState,
	unit: UnitState,
	events: Array[SimEvent],
) -> void:
	if board == null or unit == null or not unit.is_alive():
		return
	if not has_passive_modifier(unit, &"safe_landing"):
		return
	var push_amount := int(passive_value(
		unit, &"landing_shockwave_push", &"upgraded_landing_shockwave_push", 0,
	))
	if push_amount <= 0:
		return
	var size := int(passive_value(unit, &"landing_shockwave_size", &"", 3))
	var tiles := GridSystem.get_affected_tiles(
		board, unit.position, unit.position, GameEnums.TargetShape.AOE_SQUARE, size,
	)
	for tile: Vector2i in tiles:
		var pushed := board.get_unit_at(tile)
		if pushed == null or pushed.id == unit.id or not pushed.is_alive():
			continue
		var direction := PhysicsSystem.cardinal_from_to(unit.position, pushed.position)
		if direction == Vector2i.ZERO:
			continue
		PhysicsSystem.push(board, pushed, direction, push_amount, events, unit)


static func before_ability_execute(
	_board: BoardState,
	actor: UnitState,
	action: TimelineAction,
) -> void:
	if actor == null or action == null or action.ability == null:
		return
	var mods := active_module_modifiers(actor, action.ability)
	if mods.get("pounce_land_adjacent", false):
		var pounce_target := action.target_unit_id
		if pounce_target < 0:
			pounce_target = AbilitySystem.module_target_unit_id(action, 0)
		if pounce_target >= 0:
			actor.passive_flags["beast_pounce_target_id"] = pounce_target
	if mods.get("feral_drag", false):
		var drag_target_id := action.target_unit_id
		if drag_target_id < 0:
			drag_target_id = AbilitySystem.module_target_unit_id(action, 0)
		actor.passive_flags["beast_drag_target_id"] = drag_target_id
	if mods.get("run_down_pass_adjacent_push", 0) > 0:
		actor.passive_flags["beast_dash_start"] = actor.position
	if int(mods.get("pull_before_attack", 0)) > 0:
		var claws_target: UnitState = (
			AbilitySystem.resolve_action_target(_board, action)
			if _board != null
			else null
		)
		if claws_target != null and claws_target.team != actor.team:
			var pull_dir := PhysicsSystem.cardinal_from_to(claws_target.position, actor.position)
			if pull_dir != Vector2i.ZERO:
				var pull_events: Array[SimEvent] = []
				PhysicsSystem.push(
					_board, claws_target, pull_dir, int(mods["pull_before_attack"]),
					pull_events, actor, action.ability.id,
				)


static func after_ability_execute(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	events: Array[SimEvent],
) -> void:
	if board == null or actor == null or action == null or action.ability == null:
		return
	var mods := active_module_modifiers(actor, action.ability)
	if mods.get("reposition_opposite_side", false):
		apply_reposition(
			board, actor, AbilitySystem.resolve_action_target(board, action), events,
		)
	if mods.get("landing_vulnerable", false):
		_apply_landing_vulnerable(board, actor, events)
		on_landing(board, actor, events)
	if mods.get("drag_remaining_movement", false):
		_drag_target_for_remaining_movement(board, actor, action.ability, events)
	if mods.get("redirect_incoming_damage", false):
		actor.passive_flags["beast_redirect_to_id"] = int(
			actor.passive_flags.get("beast_drag_target_id", -1),
		)
	if mods.get("maul_dragged_enemy", false):
		_resolve_maul_drop(board, actor, action, mods, events)
	if mods.get("fetch_item_or_corpse", false):
		_resolve_fetch(board, actor, action, mods, events)
	if mods.get("airlift_pickup_step", 0) > 0:
		_resolve_airlift(board, actor, action, mods, events)
	if int(mods.get("run_down_pass_adjacent_push", 0)) > 0:
		_resolve_run_down_pass(board, actor, action, mods, events)
	if int(mods.get("intercept_push_attacker", 0)) > 0:
		actor.passive_flags["intercept_push_attacker"] = int(mods["intercept_push_attacker"])
		var ward := board.get_unit_by_id(AbilitySystem.module_target_unit_id(action, 1))
		if ward == null:
			for dir: Vector2i in GridSystem.DIRECTIONS:
				var adjacent := board.get_unit_at(actor.position + dir)
				if adjacent != null and adjacent.team == actor.team and adjacent.id != actor.id:
					ward = adjacent
					break
		if ward != null:
			actor.passive_flags["intercept_ward_id"] = ward.id
			actor.passive_flags["intercept_range"] = 1


static func resolve_reposition_destination(
	board: BoardState,
	actor: UnitState,
	target: UnitState,
) -> Vector2i:
	if board == null or actor == null or target == null:
		return Vector2i(-1, -1)
	var direction := PhysicsSystem.cardinal_from_to(target.position, actor.position)
	if direction == Vector2i.ZERO:
		return Vector2i(-1, -1)
	var destination := actor.position + direction
	if (
		GridSystem.is_in_bounds(board, destination)
		and not GridSystem.is_occupied(board, destination)
		and not GridSystem.is_wall(board, destination)
	):
		return destination
	return Vector2i(-1, -1)


static func apply_reposition(
	board: BoardState,
	actor: UnitState,
	target: UnitState,
	events: Array[SimEvent],
) -> void:
	if board == null or actor == null or target == null:
		return
	if target.team != actor.team or target.id == actor.id:
		return
	var destination := resolve_reposition_destination(board, actor, target)
	if destination == Vector2i(-1, -1):
		return
	var from_cell: Vector2i = target.position
	GridSystem.set_occupant(board, from_cell, -1)
	target.position = destination
	GridSystem.set_occupant(board, destination, target.id)
	events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
		"unit": target.id,
		"actor": target.id,
		"from": from_cell,
		"to": destination,
		"path": [from_cell, destination],
		"reposition": true,
		"teleport": true,
	}))


static func _drag_target_for_remaining_movement(
	board: BoardState,
	actor: UnitState,
	ability: AbilityData,
	events: Array[SimEvent],
) -> void:
	var target := board.get_unit_at(actor.position)
	if target == null:
		target = board.get_unit_by_id(int(actor.passive_flags.get("beast_drag_target_id", -1)))
	if target == null or target.team == actor.team:
		return
	var distance := maxi(0, actor.movement.points_left)
	if distance <= 0:
		return
	var direction := PhysicsSystem.cardinal_from_to(target.position, actor.position)
	if direction == Vector2i.ZERO:
		return
	PhysicsSystem.push(board, target, direction, distance, events, actor, ability.id)
	actor.movement.points_left = 0


static func _apply_landing_vulnerable(
	board: BoardState,
	actor: UnitState,
	_events: Array[SimEvent],
) -> void:
	for candidate: UnitState in board.units:
		if candidate == null or candidate.team == actor.team or not candidate.is_alive():
			continue
		if GridSystem.manhattan(candidate.position, actor.position) <= 1:
			candidate.active_statuses.append(DataLibrary.make_status(
				GameEnums.StatusType.VULNERABLE, 1,
			))
			candidate._recalculate_stats(board)


static func _is_isolated(board: BoardState, unit: UnitState) -> bool:
	if board == null or unit == null:
		return false
	for candidate: UnitState in board.units:
		if (
			candidate != null
			and candidate.is_alive()
			and candidate.team == unit.team
			and candidate.id != unit.id
			and GridSystem.manhattan(candidate.position, unit.position) <= 1
		):
			return false
	return true


static func _is_bleeding(unit: UnitState) -> bool:
	return unit != null and unit.has_status(GameEnums.StatusType.BLEED)


static func _is_moving_toward(actor: UnitState, target: UnitState) -> bool:
	if actor == null or target == null:
		return false
	var start: Vector2i = actor.passive_flags.get("beast_move_start", actor.position)
	return GridSystem.manhattan(start, target.position) > GridSystem.manhattan(actor.position, target.position)


static func _is_hazard_or_elevated(board: BoardState, unit: UnitState) -> bool:
	if board == null or unit == null:
		return false
	var tile := board.get_tile(unit.position)
	if tile == null or tile.definition == null:
		return false
	if tile.definition.hazard_damage > 0:
		return true
	return bool(tile.definition.elevated)


static func _weapon_might(unit: UnitState) -> int:
	if unit == null or unit.definition == null or unit.definition.equipped_weapon == null:
		return 0
	return unit.definition.equipped_weapon.might


static func grounded_melee_defense_bonus(
	_board: BoardState,
	target: UnitState,
	attacker: UnitState,
) -> int:
	if target == null or attacker == null:
		return 0
	if not has_passive_modifier(target, &"grounded_melee_defense"):
		return 0
	if attacker.has_status(GameEnums.StatusType.AIRBORNE):
		return 0
	if GridSystem.manhattan(target.position, attacker.position) > 1:
		return 0
	return int(passive_value(target, &"grounded_melee_defense", &"", 2))


static func resists_grounded_root(target: UnitState, attacker: UnitState) -> bool:
	if target == null or attacker == null:
		return false
	if not target.is_passive_upgraded(&"aerial_superiority"):
		return false
	if not has_passive_modifier(target, &"upgraded_grounded_root_immunity"):
		return false
	return not attacker.has_status(GameEnums.StatusType.AIRBORNE)


static func apply_collision_riders(
	board: BoardState,
	pusher: UnitState,
	victim: UnitState,
	events: Array[SimEvent],
	from_drop: bool,
) -> void:
	if pusher == null or victim == null:
		return
	if has_passive_modifier(pusher, &"collision_weapon_true_damage"):
		var extra := _weapon_might(pusher)
		if extra > 0:
			CombatSystem.deal_damage(
				board, victim, extra, events, &"true", true, false, pusher, "Terminal Velocity", extra,
			)
	if has_passive_modifier(pusher, &"collision_vulnerable"):
		if not CombatSystem.try_resist_crowd_control(victim, GameEnums.StatusType.VULNERABLE, events, board, pusher):
			victim.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.VULNERABLE, 1))
			victim._recalculate_stats(board)
	if from_drop and pusher.is_passive_upgraded(&"terminal_velocity"):
		if not CombatSystem.try_resist_crowd_control(victim, GameEnums.StatusType.STAGGER, events, board, pusher):
			victim.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAGGER, 1))
			victim._recalculate_stats(board)


static func on_zero_incoming_damage(board: BoardState, defender: UnitState, events: Array[SimEvent]) -> void:
	if defender == null or not has_passive_modifier(defender, &"miss_zero_damage_strength"):
		return
	defender.active_statuses.append(DataLibrary.make_status(
		GameEnums.StatusType.STAT_BUFF_STR, 1,
		int(passive_value(defender, &"miss_zero_damage_strength", &"", 1)),
	))
	defender.ability.points_left += int(passive_value(defender, &"miss_zero_damage_ap", &"", 1))
	if defender.is_passive_upgraded(&"beasts_instinct"):
		CombatSystem.add_armor(
			board, defender,
			int(passive_value(defender, &"upgraded_miss_zero_damage_shield", &"", 1)),
			events,
		)
	defender._recalculate_stats(board)


static func redirect_incoming_target(board: BoardState, target: UnitState) -> UnitState:
	if board == null or target == null:
		return target
	var redirect_id := int(target.passive_flags.get("beast_redirect_to_id", -1))
	if redirect_id < 0:
		return target
	var redirected := board.get_unit_by_id(redirect_id)
	if redirected == null or not redirected.is_alive():
		return target
	return redirected


static func _grant_blood_scent_move(
	board: BoardState,
	unit: UnitState,
	from: Vector2i,
	to: Vector2i,
) -> void:
	if not has_passive_modifier(unit, &"blood_scent_pierce"):
		return
	var bonus := int(passive_value(unit, &"blood_scent_move", &"upgraded_blood_scent_move", 0))
	if bonus <= 0:
		return
	var before := _nearest_bleed_distance(board, unit, from)
	var after := _nearest_bleed_distance(board, unit, to)
	if before < 0 or after < 0 or after >= before:
		return
	unit.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_MOV, 1, bonus))
	unit._recalculate_stats(board)
	unit.movement.points_left += bonus


static func _nearest_bleed_distance(board: BoardState, actor: UnitState, from: Vector2i) -> int:
	var best := -1
	for unit: UnitState in board.units:
		if unit == null or not unit.is_alive() or unit.team == actor.team:
			continue
		if not _is_bleeding(unit):
			continue
		var dist := GridSystem.manhattan(from, unit.position)
		if best < 0 or dist < best:
			best = dist
	return best


static func has_legal_fetch_target(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	ability: AbilityData,
) -> bool:
	if board == null or actor == null or action == null:
		return false
	var coord := action.target_coord
	if board.items.find(coord) >= 0:
		return true
	var occupant := board.get_unit_at(coord)
	if occupant != null and not occupant.is_alive():
		return true
	var mods: Dictionary = active_module_modifiers(actor, ability)
	if int(mods.get("pull_light_ally", 0)) > 0:
		var ally: UnitState = AbilitySystem.resolve_action_target(board, action)
		if (
			ally != null
			and ally.team == actor.team
			and ally.is_alive()
			and int(ally.health.max_hp / 5) <= actor.current_strength
		):
			return true
	return false


static func _first_empty_adjacent(board: BoardState, origin: Vector2i) -> Vector2i:
	for dir: Vector2i in GridSystem.DIRECTIONS:
		var dest := origin + dir
		if (
			GridSystem.is_in_bounds(board, dest)
			and not GridSystem.is_occupied(board, dest)
			and not GridSystem.is_wall(board, dest)
		):
			return dest
	return Vector2i(-1, -1)


static func _resolve_maul_drop(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	mods: Dictionary,
	events: Array[SimEvent],
) -> void:
	var dragged := board.get_unit_by_id(int(actor.passive_flags.get("beast_drag_target_id", -1)))
	if dragged == null:
		dragged = AbilitySystem.resolve_action_target(board, action)
	if dragged == null:
		return
	var dest := _first_empty_adjacent(board, actor.position)
	if dest == Vector2i(-1, -1):
		dest = _first_empty_adjacent(board, dragged.position)
	if dest == Vector2i(-1, -1):
		return
	GridSystem.set_occupant(board, dragged.position, -1)
	dragged.position = dest
	GridSystem.set_occupant(board, dest, dragged.id)
	events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
		"unit": dragged.id, "to": dest, "maul_drop": true,
	}))
	actor.passive_flags.erase("beast_drag_target_id")
	var tile := board.get_tile(dest)
	if (
		float(mods.get("drop_trap_damage_multiplier", 0.0)) > 0.0
		and tile != null
		and tile.definition != null
		and tile.definition.is_trap
	):
		actor.passive_flags["trap_collision_damage_multiplier"] = int(
			mods["drop_trap_damage_multiplier"],
		)
		dragged.passive_flags["trap_entry_damage_multiplier"] = float(
			mods["drop_trap_damage_multiplier"],
		)
		TerrainSystem.apply_entry_at(board, dragged, dest, events)


static func _resolve_fetch(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	mods: Dictionary,
	events: Array[SimEvent],
) -> void:
	var dest := _first_empty_adjacent(board, actor.position)
	if dest == Vector2i(-1, -1):
		return
	var item_idx := board.items.find(action.target_coord)
	if item_idx >= 0:
		board.items[item_idx] = dest
		events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
			"item": true, "from": action.target_coord, "to": dest,
		}))
		return
	var occupant := board.get_unit_at(action.target_coord)
	if occupant != null and not occupant.is_alive():
		GridSystem.set_occupant(board, occupant.position, -1)
		occupant.position = dest
		events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
			"unit": occupant.id, "to": dest, "fetch_corpse": true,
		}))
		return
	if int(mods.get("pull_light_ally", 0)) > 0:
		var ally: UnitState = AbilitySystem.resolve_action_target(board, action)
		if ally != null and ally.team == actor.team and ally.is_alive():
			var pull_dir := PhysicsSystem.cardinal_from_to(ally.position, actor.position)
			if pull_dir != Vector2i.ZERO:
				PhysicsSystem.push(
					board, ally, pull_dir, int(mods["pull_light_ally"]),
					events, actor, action.ability.id,
				)


static func _resolve_airlift(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	mods: Dictionary,
	events: Array[SimEvent],
) -> void:
	var ally: UnitState = AbilitySystem.resolve_action_target(board, action)
	if ally == null or ally.team != actor.team or ally.id == actor.id:
		return
	GridSystem.set_occupant(board, ally.position, -1)
	ally.position = actor.position
	ally.passive_flags["beast_carried_by"] = actor.id
	ally.passive_flags["airlift_cannot_act"] = true
	actor.passive_flags["beast_carried_ally_id"] = ally.id
	var drop_range := int(mods.get("airlift_drop_step", 3))
	var drop := AbilitySystem.module_target_coord(action, 1)
	if drop == Vector2i.ZERO or drop == action.target_coord:
		drop = _first_empty_adjacent(board, actor.position)
	if (
		drop != Vector2i(-1, -1)
		and GridSystem.manhattan(actor.position, drop) <= drop_range
		and GridSystem.is_in_bounds(board, drop)
		and not GridSystem.is_occupied(board, drop)
		and not GridSystem.is_wall(board, drop)
	):
		_place_carried_ally(board, actor, ally, drop, events)
	if int(mods.get("airlift_ally_attack_strength", 0)) > 0:
		ally.passive_flags["beast_airlift_next_strength"] = int(mods["airlift_ally_attack_strength"])
	actor.passive_flags["beast_drop_collision"] = true


static func _sync_carried_ally(board: BoardState, rider: UnitState) -> void:
	var ally := board.get_unit_by_id(int(rider.passive_flags.get("beast_carried_ally_id", -1)))
	if ally == null or not ally.is_alive():
		return
	ally.position = rider.position


static func _try_airlift_drop(board: BoardState, rider: UnitState, events: Array[SimEvent]) -> void:
	var drop: Vector2i = rider.passive_flags.get("beast_airlift_drop_coord", Vector2i(-1, -1))
	if drop == Vector2i(-1, -1):
		return
	var ally := board.get_unit_by_id(int(rider.passive_flags.get("beast_carried_ally_id", -1)))
	if ally == null:
		return
	_place_carried_ally(board, rider, ally, drop, events)


static func _place_carried_ally(
	board: BoardState,
	rider: UnitState,
	ally: UnitState,
	drop: Vector2i,
	events: Array[SimEvent],
) -> void:
	ally.position = drop
	GridSystem.set_occupant(board, drop, ally.id)
	ally.passive_flags.erase("beast_carried_by")
	ally.passive_flags.erase("airlift_cannot_act")
	rider.passive_flags.erase("beast_carried_ally_id")
	rider.passive_flags.erase("beast_airlift_drop_coord")
	events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
		"unit": ally.id, "to": drop, "airlift_drop": true,
	}))


static func _drop_carried_ally(
	board: BoardState,
	rider: UnitState,
	preferred: Variant,
	events: Array[SimEvent],
) -> void:
	if board == null or rider == null:
		return
	var ally := board.get_unit_by_id(int(rider.passive_flags.get("beast_carried_ally_id", -1)))
	if ally == null:
		return
	var drop := _first_empty_adjacent(board, rider.position)
	if preferred is Vector2i and preferred != Vector2i(-1, -1):
		drop = preferred
	if drop == Vector2i(-1, -1):
		return
	_place_carried_ally(board, rider, ally, drop, events)


static func _resolve_run_down_pass(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	mods: Dictionary,
	events: Array[SimEvent],
) -> void:
	var start: Vector2i = actor.passive_flags.get("beast_dash_start", actor.position)
	var dest := action.target_coord
	var dir := PhysicsSystem.straight_line_dir(start, dest)
	var steps := PhysicsSystem.straight_line_distance(start, dest)
	if dir == Vector2i.ZERO or steps <= 0:
		return
	var push_amt := int(mods.get("run_down_pass_adjacent_push", 1))
	var pushed_ids: Dictionary = {}
	for step_i: int in range(1, steps + 1):
		var cell := start + dir * step_i
		for side: Vector2i in GridSystem.DIRECTIONS:
			var adj := cell + side
			var enemy := board.get_unit_at(adj)
			if (
				enemy == null
				or not enemy.is_alive()
				or enemy.team == actor.team
				or pushed_ids.has(enemy.id)
			):
				continue
			if PhysicsSystem.straight_line_dir(start, enemy.position) == dir:
				continue
			pushed_ids[enemy.id] = true
			var away := PhysicsSystem.cardinal_from_to(cell, enemy.position)
			if away == Vector2i.ZERO:
				away = side
			PhysicsSystem.push(board, enemy, away, push_amt, events, actor, action.ability.id)
			if mods.get("run_down_push_bleed_weapon", false):
				enemy.active_statuses.append(DataLibrary.make_status(
					GameEnums.StatusType.BLEED, 1, _weapon_might(actor),
				))
				enemy._recalculate_stats(board)
	actor.passive_flags.erase("beast_dash_start")

