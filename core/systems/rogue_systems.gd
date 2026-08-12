extends RefCounted

## Shared Rogue lifecycle hooks.


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


static func _ability_modifiers(actor: UnitState, ability: AbilityData) -> Dictionary:
	if actor == null or ability == null:
		return {}
	var modules: Array[AbilityModule] = ability.get_active_modules(
		actor.is_ability_upgraded(ability.id),
	)
	if modules.is_empty():
		return {}
	return modules[0].legacy_modifiers if modules[0] != null else {}


static func has_innate_pass(unit: UnitState) -> bool:
	return has_passive_modifier(unit, &"pass") and has_passive_modifier(unit, &"ghost_move")


static func should_skip_trap_entry(unit: UnitState) -> bool:
	return has_innate_pass(unit)


static func turn_start(board: BoardState, unit: UnitState, events: Array[SimEvent]) -> void:
	if unit == null or not unit.is_alive() or board == null:
		return
	var per_debuff: int = int(passive_value(
		unit, &"turn_start_damage_per_debuff", &"upgraded_turn_start_damage_per_debuff", 0,
	))
	if per_debuff <= 0:
		return
	var unique := _unique_debuff_count(unit)
	if unique <= 0:
		return
	var raw := per_debuff * unique
	CombatSystem.deal_damage(
		board, unit, raw, events, &"true", true, false, unit, "Debuff Overload", raw,
	)


static func turn_end(board: BoardState, unit: UnitState, events: Array[SimEvent]) -> void:
	if unit == null or board == null:
		return
	unit.passive_flags.erase("rogue_move_start")
	unit.passive_flags.erase("rogue_tiles_moved")
	unit.passive_flags.erase("rogue_smoke_free_ap_used")
	if not unit.is_alive():
		return
	var threshold: float = float(passive_value(
		unit, &"killing_intent_threshold", &"upgraded_killing_intent_threshold", 0.50,
	))
	var ap_grant: int = int(passive_value(unit, &"end_adjacent_low_hp_ap", &"", 0))
	if ap_grant <= 0 or threshold <= 0.0:
		return
	for enemy: UnitState in board.units:
		if (
			enemy == null
			or not enemy.is_alive()
			or enemy.team == unit.team
			or GridSystem.manhattan(unit.position, enemy.position) != 1
		):
			continue
		if float(enemy.health.current_hp) / float(maxi(1, enemy.health.max_hp)) < threshold:
			unit.passive_flags["rogue_bonus_ap_next_turn"] = ap_grant
			break


static func apply_next_turn_ap_bonus(unit: UnitState) -> void:
	if unit == null:
		return
	var bonus: int = int(unit.passive_flags.get("rogue_bonus_ap_next_turn", 0))
	if bonus <= 0:
		return
	unit.ability.points_left += bonus
	unit.passive_flags.erase("rogue_bonus_ap_next_turn")


static func before_skill_move(
	board: BoardState,
	unit: UnitState,
	_ability: AbilityData,
	_events: Array[SimEvent],
) -> void:
	if unit == null:
		return
	unit.passive_flags["rogue_move_start"] = unit.position


static func after_skill_move(
	board: BoardState,
	unit: UnitState,
	ability: AbilityData,
	events: Array[SimEvent],
) -> void:
	if unit == null or board == null:
		return
	var enemy_ids: Array[int] = []
	for enemy_id: Variant in unit.passive_flags.get("rogue_crossed_enemy_ids", []):
		enemy_ids.append(int(enemy_id))
	if not enemy_ids.is_empty():
		on_moved_through_enemy(board, unit, enemy_ids, events, ability)
	unit.passive_flags.erase("rogue_crossed_enemy_ids")
	if unit.passive_flags.has("rogue_move_start"):
		var start: Vector2i = unit.passive_flags["rogue_move_start"]
		unit.passive_flags["rogue_tiles_moved"] = GridSystem.manhattan(start, unit.position)
		unit.passive_flags.erase("rogue_move_start")


static func track_crossed_enemy(unit: UnitState, enemy_id: int) -> void:
	if unit == null:
		return
	var crossed_ids: Array[int] = []
	for crossed_id: Variant in unit.passive_flags.get("rogue_crossed_enemy_ids", []):
		crossed_ids.append(int(crossed_id))
	if not crossed_ids.has(enemy_id):
		crossed_ids.append(enemy_id)
		unit.passive_flags["rogue_crossed_enemy_ids"] = crossed_ids


static func on_moved_through_enemy(
	board: BoardState,
	unit: UnitState,
	enemy_ids: Array[int],
	events: Array[SimEvent],
	ability: AbilityData = null,
) -> void:
	if unit == null or enemy_ids.is_empty():
		return
	var ability_mods := _ability_modifiers(unit, ability)
	for enemy_id: int in enemy_ids:
		var enemy := board.get_unit_by_id(enemy_id)
		if enemy == null or not enemy.is_alive():
			continue
		if has_passive_modifier(unit, &"cross_enemy_blind_mark"):
			enemy.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.BLIND, 1))
			enemy.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.MARK, 1))
			if unit.is_passive_upgraded(&"shadow_slip"):
				enemy.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.POISON, 1))
		if has_passive_modifier(unit, &"upgraded_pass_setup_pierce"):
			unit.passive_flags["rogue_pierce_target_id"] = enemy.id
		if ability_mods.get("blind_on_pass_over", false):
			enemy.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.BLIND, 1))


static func resolve_teleport_destination(
	board: BoardState,
	actor: UnitState,
	target: UnitState,
	aim_coord: Vector2i,
	motion_mode: int,
) -> Vector2i:
	if board == null or actor == null:
		return Vector2i(-1, -1)
	match motion_mode:
		GameEnums.MotionMode.ADJACENT_TO_TARGET:
			if target == null:
				return Vector2i(-1, -1)
			return _first_empty_adjacent(board, target.position)
		GameEnums.MotionMode.BEHIND_TARGET:
			if target == null:
				return Vector2i(-1, -1)
			return _empty_behind_target(board, target)
		GameEnums.MotionMode.TO_TARGET_UNIT:
			if target == null:
				return Vector2i(-1, -1)
			return target.position
		_:
			return aim_coord


static func after_teleport(
	board: BoardState,
	actor: UnitState,
	target: UnitState,
	ability: AbilityData,
	events: Array[SimEvent],
) -> void:
	if actor == null:
		return
	if has_passive_modifier(actor, &"teleport_stealth"):
		actor.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STEALTH, 1))
		actor._recalculate_stats(board)
	var teleport_bonus: int = int(passive_value(
		actor, &"after_teleport_attack_bonus", &"upgraded_after_teleport_attack_bonus", 0,
	))
	if teleport_bonus > 0:
		actor.passive_flags["rogue_after_teleport_attack_bonus"] = teleport_bonus
	if target != null and has_passive_modifier(actor, &"teleport_adjacent_mark_root"):
		if GridSystem.manhattan(actor.position, target.position) == 1:
			target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.MARK, 1))
			if not CombatSystem.try_resist_crowd_control(target, GameEnums.StatusType.ROOT, events):
				target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.ROOT, 1))
			if actor.is_passive_upgraded(&"shadow_strike"):
				if not CombatSystem.try_resist_crowd_control(target, GameEnums.StatusType.SILENCE, events):
					target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.SILENCE, 1))
			target._recalculate_stats(board)
	var ability_mods := _ability_modifiers(actor, ability)
	if int(ability_mods.get("behind_target_strength", 0)) > 0:
		actor.active_statuses.append(DataLibrary.make_status(
			GameEnums.StatusType.STAT_BUFF_STR,
			1,
			int(ability_mods["behind_target_strength"]),
		))
		actor._recalculate_stats(board)


static func apply_attack_ignore_def(board: BoardState, actor: UnitState, target: UnitState) -> void:
	if actor == null or target == null:
		return
	if has_passive_modifier(actor, &"backstab_ignore_def") and _is_backstab_from_behind(actor, target):
		var target_def := CombatSystem.get_dynamic_defense(board, target)
		actor.passive_flags["attack_ignore_def"] = maxi(
			int(actor.passive_flags.get("attack_ignore_def", 0)),
			target_def,
		)
		if actor.is_passive_upgraded(&"backstab"):
			var wpn := 0
			if actor.definition != null and actor.definition.equipped_weapon != null:
				wpn = actor.definition.equipped_weapon.might
			if wpn > 0:
				target.active_statuses.append(DataLibrary.make_status(
					GameEnums.StatusType.BLEED, 1, wpn,
				))
				target._recalculate_stats(board)
	if int(actor.passive_flags.get("rogue_pierce_target_id", -1)) == target.id:
		var pierce_def := CombatSystem.get_dynamic_defense(board, target)
		actor.passive_flags["attack_ignore_def"] = maxi(
			int(actor.passive_flags.get("attack_ignore_def", 0)),
			pierce_def,
		)
		actor.passive_flags.erase("rogue_pierce_target_id")
	if (
		has_passive_modifier(actor, &"upgraded_stealth_attack_ignore_def")
		and actor.has_status(GameEnums.StatusType.STEALTH)
	):
		var stealth_def := CombatSystem.get_dynamic_defense(board, target)
		actor.passive_flags["attack_ignore_def"] = maxi(
			int(actor.passive_flags.get("attack_ignore_def", 0)),
			stealth_def,
		)


static func damage_bonus(
	board: BoardState,
	attacker: UnitState,
	target: UnitState,
	effect: EffectData,
) -> int:
	if attacker == null or target == null:
		return 0
	var bonus := 0
	var ability: AbilityData = attacker.passive_flags.get("__current_ability", null) as AbilityData
	var ability_mods := _ability_modifiers(attacker, ability)
	if effect != null and ability_mods.has("bonus_if_target_debuffed") and _has_debuff(target):
		bonus += int(ability_mods["bonus_if_target_debuffed"])
	if effect != null and ability_mods.has("if_target_staggered_bonus") and target.has_status(GameEnums.StatusType.STAGGER):
		bonus += int(ability_mods["if_target_staggered_bonus"])
	var teleport_bonus: int = int(attacker.passive_flags.get("rogue_after_teleport_attack_bonus", 0))
	if teleport_bonus > 0:
		bonus += teleport_bonus
		attacker.passive_flags.erase("rogue_after_teleport_attack_bonus")
	var moved_tiles: int = int(attacker.passive_flags.get("rogue_tiles_moved", 0))
	if moved_tiles > 0 and has_passive_modifier(attacker, &"moved_tiles_attack_strength"):
		bonus += moved_tiles * int(passive_value(attacker, &"moved_tiles_attack_strength", &"", 1))
	if _has_debuff(target):
		var per_status: int = int(passive_value(attacker, &"debuff_damage_per_status", &"", 0))
		if per_status > 0:
			bonus += per_status * _unique_debuff_count(target)
		if target.has_status(GameEnums.StatusType.CONFUSION):
			var confused_bonus: int = int(passive_value(
				attacker, &"upgraded_confused_damage_per_status", &"", 0,
			))
			if confused_bonus > 0:
				bonus += confused_bonus * _unique_debuff_count(target)
	if has_passive_modifier(attacker, &"marked_attack_weapon_bonus") and target.has_status(GameEnums.StatusType.MARK):
		var wpn := 0
		if attacker.definition != null and attacker.definition.equipped_weapon != null:
			wpn = attacker.definition.equipped_weapon.might
		bonus += wpn
	return bonus


static func should_pierce(
	board: BoardState,
	attacker: UnitState,
	target: UnitState,
	effect: EffectData,
) -> bool:
	if attacker == null or target == null or effect == null:
		return false
	if effect.modifiers.get("pierce_vs_blind", false) and target.has_status(GameEnums.StatusType.BLIND):
		return true
	return false


static func on_attack_hit(
	board: BoardState,
	attacker: UnitState,
	target: UnitState,
	_events: Array[SimEvent],
) -> void:
	if attacker == null or target == null or board == null:
		return
	if has_passive_modifier(attacker, &"spread_debuffs_on_attack") and _has_debuff(target):
		var spread_range: int = int(passive_value(
			attacker, &"miasma_spreader_range", &"upgraded_miasma_spreader_range", 1,
		))
		_spread_debuffs(board, target, spread_range)


static func on_dealt_damage(
	board: BoardState,
	attacker: UnitState,
	target: UnitState,
	events: Array[SimEvent],
) -> void:
	if attacker == null or target == null or board == null:
		return
	var swap_range: int = int(passive_value(attacker, &"damage_swap_highest_hp_range", &"", 0))
	if swap_range <= 0:
		return
	var highest: UnitState = null
	var highest_hp := -1
	for candidate: UnitState in board.units:
		if (
			candidate == null
			or not candidate.is_alive()
			or candidate.team != target.team
			or candidate.id == target.id
		):
			continue
		if GridSystem.manhattan(target.position, candidate.position) > swap_range:
			continue
		if candidate.health.current_hp > highest_hp:
			highest_hp = candidate.health.current_hp
			highest = candidate
	if highest != null:
		PhysicsSystem.swap(board, target, highest, events)
		if attacker.is_passive_upgraded(&"board_scrambler"):
			if not CombatSystem.try_resist_crowd_control(target, GameEnums.StatusType.ROOT, events):
				target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.ROOT, 1))
				target._recalculate_stats(board)


static func on_kill(
	board: BoardState,
	attacker: UnitState,
	target: UnitState,
	events: Array[SimEvent],
) -> void:
	if attacker == null or target == null or board == null:
		return
	var ability: AbilityData = attacker.passive_flags.get("__current_ability", null) as AbilityData
	var ability_mods := _ability_modifiers(attacker, ability)
	if ability_mods.get("on_kill_spread_silence_adjacent", false):
		for dir: Vector2i in GridSystem.DIRECTIONS:
			var adjacent := board.get_unit_at(target.position + dir)
			if adjacent == null or not adjacent.is_alive() or adjacent.team == attacker.team:
				continue
			if not CombatSystem.try_resist_crowd_control(adjacent, GameEnums.StatusType.SILENCE, events):
				adjacent.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.SILENCE, 1))
	if int(ability_mods.get("kill_grant_ap", 0)) > 0:
		attacker.ability.points_left += int(ability_mods["kill_grant_ap"])
	if has_passive_modifier(attacker, &"on_kill_decoy_taunt"):
		_spawn_decoy(board, attacker, target.position, events)
	if ability_mods.get("on_kill_refresh_mark_zero_ap", false):
		attacker.passive_flags["rogue_free_mark_refresh"] = true
	if (
		has_passive_modifier(attacker, &"marked_attack_refund_move")
		and target.has_status(GameEnums.StatusType.MARK)
	):
		attacker.movement.points_left += int(passive_value(attacker, &"marked_attack_refund_move", &"", 1))


static func can_gain_shield(board: BoardState, target: UnitState) -> bool:
	if board == null or target == null:
		return true
	for source: UnitState in board.units:
		if source == null or source.team == target.team or not source.is_alive():
			continue
		if not has_passive_modifier(source, &"mind_static_no_shield"):
			continue
		var range_tiles: int = int(passive_value(
			source, &"mind_static_range", &"upgraded_mind_static_range", 2,
		))
		if GridSystem.manhattan(source.position, target.position) <= range_tiles:
			return false
	return true


static func incoming_damage_reduction_pct(board: BoardState, target: UnitState) -> float:
	if board == null or target == null:
		return 0.0
	for source: UnitState in board.units:
		if source == null or source.team == target.team or not source.is_alive():
			continue
		if not has_passive_modifier(source, &"mind_static_def_pct"):
			continue
		var range_tiles: int = int(passive_value(
			source, &"mind_static_range", &"upgraded_mind_static_range", 2,
		))
		if GridSystem.manhattan(source.position, target.position) <= range_tiles:
			return float(passive_value(
				source, &"mind_static_def_pct", &"upgraded_mind_static_def_pct", 0.25,
			))
	return 0.0


static func dynamic_stat_adjustments(board: BoardState, unit: UnitState) -> Dictionary:
	var result := {"strength": 0, "magic": 0, "defense": 0, "movement": 0}
	if board == null or unit == null:
		return result
	var reduction_pct := incoming_damage_reduction_pct(board, unit)
	if reduction_pct > 0.0:
		result.defense += floori(unit.current_defense * reduction_pct)
	return result


static func basic_attack_range_bonus(unit: UnitState) -> int:
	return int(passive_value(
		unit, &"basic_attack_range", &"upgraded_basic_attack_range", 0,
	))


static func after_ability_execute(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	events: Array[SimEvent],
) -> void:
	if actor == null or action == null or action.ability == null:
		return
	var ability_mods := _ability_modifiers(actor, action.ability)
	if ability_mods.get("target_def_debuff", false):
		var target := board.get_unit_at(action.target_coord)
		if target != null and target.team != actor.team:
			target.active_statuses.append(DataLibrary.make_status(
				GameEnums.StatusType.STAT_DEBUFF_DEF, 1, 1,
			))
			target._recalculate_stats(board)
	if ability_mods.get("if_target_unacted_stagger", false):
		var stagger_target := board.get_unit_at(action.target_coord)
		if stagger_target != null and not stagger_target.turn_action_used:
			if not CombatSystem.try_resist_crowd_control(stagger_target, GameEnums.StatusType.STAGGER, events):
				stagger_target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAGGER, 1))
				stagger_target._recalculate_stats(board)
	if ability_mods.get("target_unacted_only", false):
		var dust_target := board.get_unit_at(action.target_coord)
		if dust_target != null and dust_target.turn_action_used:
			return
	if ability_mods.get("inherit_incoming_attacks", false):
		var swap_target := board.get_unit_by_id(action.target_unit_id)
		if swap_target != null:
			actor.passive_flags["rogue_inherit_attacks_target_id"] = swap_target.id
			swap_target.passive_flags["rogue_redirect_attacks_to_id"] = actor.id
	if ability_mods.get("smoke_stealth_outside_attackers", false):
		_apply_smoke_stealth(board, actor, events)
	if ability_mods.get("smoke_ally_heal_per_turn", false):
		_apply_smoke_heal(board, actor, events)
	if ability_mods.get("hazard_blind_on_entry", false):
		actor.passive_flags["rogue_hazard_blind_on_entry"] = true


static func apply_smoke_spell_bonus(board: BoardState, actor: UnitState, ability: AbilityData) -> void:
	if actor == null or ability == null or ability.kind != GameEnums.AbilityKind.CLASS_SKILL:
		return
	if not has_passive_modifier(actor, &"smoke_spell_magic"):
		return
	if not _is_in_smoke(board, actor):
		return
	var magic_bonus: int = int(passive_value(
		actor, &"smoke_spell_magic", &"upgraded_smoke_spell_magic", 2,
	))
	actor.passive_flags["mage_spell_magic_bonus"] = magic_bonus
	if (
		has_passive_modifier(actor, &"smoke_spell_free_ap")
		and not actor.passive_flags.get("rogue_smoke_free_ap_used", false)
		and ability.action_point_cost > 0
	):
		actor.passive_flags["rogue_smoke_free_ap"] = true


static func consume_smoke_free_ap(actor: UnitState, ability: AbilityData) -> bool:
	if actor == null or ability == null:
		return false
	if not actor.passive_flags.get("rogue_smoke_free_ap", false):
		return false
	actor.passive_flags.erase("rogue_smoke_free_ap")
	actor.passive_flags["rogue_smoke_free_ap_used"] = true
	return true


static func _is_in_smoke(board: BoardState, unit: UnitState) -> bool:
	if board == null or unit == null:
		return false
	var tile := board.get_tile(unit.position)
	return tile != null and tile.definition != null and tile.definition.id == &"smoke"


static func _apply_smoke_stealth(
	board: BoardState,
	actor: UnitState,
	_events: Array[SimEvent],
) -> void:
	for unit: UnitState in board.units:
		if unit == null or not unit.is_alive() or unit.team != actor.team:
			continue
		if not _is_in_smoke(board, unit):
			continue
		unit.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STEALTH, 1))
		unit._recalculate_stats(board)


static func _apply_smoke_heal(
	board: BoardState,
	actor: UnitState,
	events: Array[SimEvent],
) -> void:
	for unit: UnitState in board.units:
		if unit == null or not unit.is_alive() or unit.team != actor.team:
			continue
		if not _is_in_smoke(board, unit):
			continue
		CombatSystem.heal(board, unit, 1, events)


static func _spawn_decoy(
	board: BoardState,
	owner: UnitState,
	coord: Vector2i,
	events: Array[SimEvent],
) -> void:
	if not GridSystem.is_in_bounds(board, coord) or GridSystem.is_occupied(board, coord):
		return
	var spawn_def := DataLibrary.get_training_dummy()
	if spawn_def == null:
		return
	var decoy_id := board.next_unit_id()
	var decoy := UnitState.create(decoy_id, spawn_def, owner.team, coord)
	decoy.health.max_hp = 1
	decoy.health.current_hp = 1
	decoy.passive_flags["rogue_decoy"] = true
	decoy.passive_flags["rogue_decoy_owner_id"] = owner.id
	var taunt_turns: int = int(passive_value(owner, &"on_kill_decoy_taunt", &"", 1))
	decoy.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.TAUNT, taunt_turns))
	board.add_unit(decoy)
	GridSystem.set_occupant(board, coord, decoy_id)
	events.append(SimEvent.make(GameEnums.SimEventType.UNIT_SPAWNED, {
		"unit": decoy_id, "coord": coord, "decoy": true,
	}))


static func _spread_debuffs(board: BoardState, source: UnitState, spread_range: int) -> void:
	var debuffs: Array = []
	for status in source.active_statuses:
		if GameEnums.is_debuff(status.type):
			debuffs.append(status)
	if debuffs.is_empty():
		return
	for candidate: UnitState in board.units:
		if (
			candidate == null
			or not candidate.is_alive()
			or candidate.team != source.team
			or candidate.id == source.id
		):
			continue
		if GridSystem.manhattan(source.position, candidate.position) > spread_range:
			continue
		for status in debuffs:
			candidate.active_statuses.append(DataLibrary.make_status(
				status.type, status.duration, status.value,
			))
		candidate._recalculate_stats(board)


static func _has_debuff(unit: UnitState) -> bool:
	for status in unit.active_statuses:
		if GameEnums.is_debuff(status.type):
			return true
	return false


static func _unique_debuff_count(unit: UnitState) -> int:
	var seen := {}
	for status in unit.active_statuses:
		if GameEnums.is_debuff(status.type):
			seen[status.type] = true
	return seen.size()


static func _is_backstab_from_behind(actor: UnitState, target: UnitState) -> bool:
	var behind := -PhysicsSystem.facing_to_vector(target.facing)
	return PhysicsSystem.cardinal_from_to(target.position, actor.position) == behind


static func _first_empty_adjacent(board: BoardState, center: Vector2i) -> Vector2i:
	for direction: Vector2i in GridSystem.DIRECTIONS:
		var candidate := center + direction
		if (
			GridSystem.is_in_bounds(board, candidate)
			and not GridSystem.is_occupied(board, candidate)
			and not GridSystem.is_wall(board, candidate)
		):
			return candidate
	return Vector2i(-1, -1)


static func _empty_behind_target(board: BoardState, target: UnitState) -> Vector2i:
	var behind := target.position - PhysicsSystem.facing_to_vector(target.facing)
	if (
		GridSystem.is_in_bounds(board, behind)
		and not GridSystem.is_occupied(board, behind)
		and not GridSystem.is_wall(board, behind)
	):
		return behind
	return _first_empty_adjacent(board, target.position)


static func resolve_grapple_pull(
	board: BoardState,
	actor: UnitState,
	target: UnitState,
	tile_coord: Vector2i,
	effect: EffectData,
) -> Dictionary:
	if effect == null or not effect.modifiers.get("grapple_bidirectional", false):
		return {"pull_self": false, "pull_target": target}
	if target != null:
		return {"pull_self": false, "pull_target": target}
	if (
		effect.modifiers.get("pull_self_or_target", false)
		and GridSystem.is_in_bounds(board, tile_coord)
		and not GridSystem.is_occupied(board, tile_coord)
		and GridSystem.manhattan(actor.position, tile_coord) <= int(effect.amount)
	):
		return {"pull_self": true, "pull_target": null, "destination": tile_coord}
	return {"pull_self": false, "pull_target": target}


static func on_hazard_entry(
	board: BoardState,
	unit: UnitState,
	coord: Vector2i,
	_events: Array[SimEvent],
) -> void:
	if unit == null or board == null:
		return
	var payload: Dictionary = board.terrain_payloads.get(coord, {})
	if payload.get("hazard_blind_on_entry", false):
		if not unit.has_status(GameEnums.StatusType.BLIND):
			unit.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.BLIND, 1))
			unit._recalculate_stats(board)
