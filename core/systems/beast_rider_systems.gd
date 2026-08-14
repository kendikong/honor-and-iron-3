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
	if actor == null or ability == null:
		return {}
	var modules := ability.get_active_modules(actor.is_ability_upgraded(ability.id))
	for module: AbilityModule in modules:
		if module != null and not module.legacy_modifiers.is_empty():
			return module.legacy_modifiers
	return {}


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
	if modules.get("target_constitution_at_most_strength", false):
		var target := (
			board.get_unit_by_id(action.target_unit_id)
			if action.target_unit_id >= 0
			else board.get_unit_at(action.target_coord)
		)
		if target == null or int(target.health.max_hp / 5) > actor.current_strength:
			return false
	if modules.get("requires_bleed_or_poison", false):
		var target := (
			board.get_unit_by_id(action.target_unit_id)
			if action.target_unit_id >= 0
			else board.get_unit_at(action.target_coord)
		)
		if target == null or (
			not target.has_status(GameEnums.StatusType.BLEED)
			and not target.has_status(GameEnums.StatusType.POISON)
		):
			return false
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
		var pounce_target := AbilitySystem.module_target_unit_id(action, 1)
		if pounce_target < 0:
			pounce_target = action.target_unit_id
		if pounce_target >= 0:
			actor.passive_flags["beast_pounce_target_id"] = pounce_target
	if mods.get("feral_drag", false):
		var drag_target_id := action.target_unit_id
		if drag_target_id < 0:
			drag_target_id = AbilitySystem.module_target_unit_id(action, 0)
		actor.passive_flags["beast_drag_target_id"] = drag_target_id


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
		apply_reposition(board, actor, board.get_unit_at(action.target_coord), events)
	if mods.get("landing_vulnerable", false):
		_apply_landing_vulnerable(board, actor, events)
		on_landing(board, actor, events)
	if mods.get("drag_remaining_movement", false):
		_drag_target_for_remaining_movement(board, actor, action.ability, events)


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
	var destination := resolve_reposition_destination(board, actor, target)
	if destination == Vector2i(-1, -1):
		return
	GridSystem.set_occupant(board, target.position, -1)
	target.position = destination
	GridSystem.set_occupant(board, destination, target.id)
	events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
		"unit": target.id, "to": destination, "reposition": true,
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
