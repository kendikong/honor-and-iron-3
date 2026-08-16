extends RefCounted

## Shared data-driven Monk hooks.  The callers remain the canonical
## AbilitySystem/Simulator/CombatSystem owners; this file only interprets
## Monk PassiveData and ability-module modifiers at those lifecycle points.


static func passive_value(
	unit: UnitState,
	key: StringName,
	upgraded_key: StringName = &"",
	default_value: int = 0,
) -> int:
	if unit == null:
		return default_value
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
	return default_value


static func has_passive_modifier(unit: UnitState, key: StringName) -> bool:
	if unit == null:
		return false
	for passive: PassiveData in unit.active_passives:
		if passive != null and passive.modifiers.has(key):
			return true
	return false


static func turn_start(board: BoardState, unit: UnitState, events: Array[SimEvent]) -> void:
	if unit == null or not unit.is_alive():
		return
	if (
		has_passive_modifier(unit, &"perfect_form_strength")
		and unit.passive_flags.get("monk_perfect_form_ready", false)
	):
		var strength := passive_value(
			unit, &"perfect_form_strength", &"upgraded_perfect_form_strength", 1,
		)
		var movement := passive_value(
			unit, &"perfect_form_movement", &"upgraded_perfect_form_movement", 1,
		)
		unit.active_statuses.append(
			DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 1, strength),
		)
		unit.active_statuses.append(
			DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_MOV, 1, movement),
		)
		unit._recalculate_stats(board)
		unit.passive_flags.erase("monk_perfect_form_ready")
	if has_passive_modifier(unit, &"ignore_difficult_terrain"):
		unit.passive_flags["monk_light_step"] = true
	if has_passive_modifier(unit, &"evasive_acrobat"):
		unit.passive_flags["monk_ghost_move"] = true
	if (
		board != null
		and has_passive_modifier(unit, &"empty_adjacent_magic")
		and _all_adjacent_empty(board, unit)
	):
		var zen := _find_passive(unit, &"zen_defense")
		var shield := 1
		if zen != null and unit.is_passive_upgraded(zen.id):
			shield = int(zen.modifiers.get("upgraded_zen_defense_empty_shield", 2))
		CombatSystem.add_armor(board, unit, shield, events)


static func turn_end(board: BoardState, unit: UnitState, events: Array[SimEvent]) -> void:
	if unit == null or not unit.is_alive():
		return
	if has_passive_modifier(unit, &"perfect_form_strength"):
		unit.passive_flags["monk_perfect_form_ready"] = not unit.passive_flags.get(
			"damaged_this_turn", false,
		)
	var tile := board.get_tile(unit.position) if board != null else null
	if (
		tile != null
		and tile.definition != null
		and tile.definition.is_trap
		and has_passive_modifier(unit, &"disarm_end_trap")
	):
		var plain := DataLibrary.get_terrain(&"plain")
		if plain != null:
			board.set_tile_terrain(unit.position, plain)
			events.append(SimEvent.make(GameEnums.SimEventType.TERRAIN_CHANGED, {
				"coord": unit.position,
				"terrain": plain.id,
				"disarmed_by": unit.id,
			}))
		if unit.is_passive_upgraded(&"light_step"):
			CombatSystem.add_armor(
				board,
				unit,
				passive_value(unit, &"upgraded_light_step_shield", &"", 1),
				events,
			)
	unit.passive_flags.erase("monk_light_step")
	unit.passive_flags.erase("monk_ghost_move")
	unit.passive_flags.erase("monk_crossed_enemy")
	var inner_turns := int(unit.passive_flags.get("monk_inner_fire_turns", 0))
	if inner_turns > 0:
		inner_turns -= 1
		if inner_turns <= 0:
			unit.passive_flags.erase("monk_inner_fire_turns")
			unit.passive_flags.erase("monk_inner_fire_surface")
		else:
			unit.passive_flags["monk_inner_fire_turns"] = inner_turns


static func before_skill_move(
	board: BoardState,
	unit: UnitState,
	ability: AbilityData,
	events: Array[SimEvent],
) -> void:
	if unit == null:
		return
	unit.passive_flags["monk_move_start"] = unit.position


static func after_skill_move(
	board: BoardState,
	unit: UnitState,
	ability: AbilityData,
	events: Array[SimEvent],
) -> void:
	if unit == null or board == null:
		return
	var enemy_ids: Array[int] = []
	for enemy_id: Variant in unit.passive_flags.get("monk_crossed_enemy_ids", []):
		enemy_ids.append(int(enemy_id))
	if not enemy_ids.is_empty():
		on_moved_through_enemy(board, unit, enemy_ids, events)
	unit.passive_flags.erase("monk_crossed_enemy_ids")
	unit.passive_flags.erase("monk_move_start")


static func on_moved_through_enemy(
	board: BoardState,
	unit: UnitState,
	enemy_ids: Array[int],
	events: Array[SimEvent],
) -> void:
	if unit == null or enemy_ids.is_empty():
		return
	unit.passive_flags["monk_crossed_enemy"] = true
	if has_passive_modifier(unit, &"flowing_ki"):
		unit.active_statuses.append(
			DataLibrary.make_status(
				GameEnums.StatusType.STAT_BUFF_MAG,
				1,
				passive_value(unit, &"flowing_ki_magic", &"", 1),
			),
		)
		if unit.is_passive_upgraded(&"flowing_ki"):
			unit.active_statuses.append(
				DataLibrary.make_status(
					GameEnums.StatusType.STAT_BUFF_STR,
					1,
					passive_value(unit, &"upgraded_flowing_ki_strength", &"", 1),
				),
			)
		unit._recalculate_stats(board)
	for enemy_id: int in enemy_ids:
		var enemy := board.get_unit_by_id(enemy_id)
		if enemy == null or not enemy.is_alive():
			continue
		var ability := unit.passive_flags.get("__current_ability", null) as AbilityData
		var ability_mods := _ability_modifiers(unit, ability)
		if has_passive_modifier(unit, &"evasive_acrobat_confusion"):
			enemy.active_statuses.append(DataLibrary.make_status(
				GameEnums.StatusType.CONFUSION, 1,
			))
			if unit.is_passive_upgraded(&"evasive_acrobat"):
				enemy.active_statuses.append(DataLibrary.make_status(
					GameEnums.StatusType.BLIND, 1,
				))
		if ability_mods.get("blind_on_pass_over", false):
			enemy.active_statuses.append(DataLibrary.make_status(
				GameEnums.StatusType.BLIND, 1,
			))


static func should_pierce(
	board: BoardState,
	unit: UnitState,
	target: UnitState,
) -> bool:
	if unit == null or target == null:
		return false
	if not has_passive_modifier(unit, &"attunement_pierce"):
		return false
	var tile := board.get_tile(target.position) if board != null else null
	return _is_elemental_tile(tile)


static func on_attack_hit(
	board: BoardState,
	attacker: UnitState,
	target: UnitState,
	action: TimelineAction,
	effect: EffectData,
	target_hp_before: int,
	events: Array[SimEvent],
) -> void:
	if attacker == null or target == null or target_hp_before <= target.health.current_hp:
		return
	var absorbed: StringName = attacker.passive_flags.get("monk_absorbed_element", &"") as StringName
	if absorbed != &"":
		var absorbed_surface := DataLibrary._effect(GameEnums.EffectType.CREATE_HAZARD, 0)
		absorbed_surface.modifiers = {
			"terrain_id": absorbed,
			"hazard_duration": 1,
			"elemental_surface": true,
		}
		AbilitySystem.apply_external_effect(
			board, attacker, action, absorbed_surface, events, target.position, target,
		)
		attacker.passive_flags.erase("monk_absorbed_element")
	var target_tile := board.get_tile(target.position) if board != null else null
	var ability := attacker.passive_flags.get("__current_ability", null) as AbilityData
	var ability_mods := _ability_modifiers(attacker, ability)
	if (
		ability_mods.get("surface_chain", false)
		and target_tile != null
		and target_tile.definition != null
		and target_tile.definition.id in [&"water", &"frozen"]
	):
		var chain_amount := maxi(1, floori(float(effect.amount) * 0.5))
		for candidate: UnitState in board.units:
			if (
				candidate == null
				or candidate == target
				or not candidate.is_alive()
				or candidate.team == attacker.team
			):
				continue
			var candidate_tile := board.get_tile(candidate.position)
			if (
				candidate_tile == null
				or candidate_tile.definition == null
				or candidate_tile.definition.id != target_tile.definition.id
			):
				continue
			CombatSystem.deal_damage(
				board,
				candidate,
				chain_amount,
				events,
				&"magical",
				false,
				false,
				attacker,
				"Thunder Palm",
				chain_amount,
			)
		target_tile = board.get_tile(target.position)
	if not attacker.passive_flags.get("monk_reaction_depth", false) \
			and ability_mods.get("burning_splash_magic", 0) > 0 \
			and target.has_status(GameEnums.StatusType.BURN):
		var splash_amount := int(ability_mods["burning_splash_magic"])
		attacker.passive_flags["monk_reaction_depth"] = true
		for direction: Vector2i in GridSystem.DIRECTIONS:
			var adjacent := board.get_unit_at(target.position + direction)
			if adjacent == null or not adjacent.is_alive() or adjacent.team == attacker.team:
				continue
			CombatSystem.deal_damage(
				board,
				adjacent,
				CombatSystem.calculate_scaled_damage(
					attacker, splash_amount, GameEnums.StatType.MAGICAL, board,
				),
				events,
				&"magical",
				false,
				false,
				attacker,
				"Scorching Kick",
				splash_amount,
			)
	if _is_elemental_tile(target_tile):
		var attunement := _find_passive(attacker, &"elemental_attunement")
		if attunement != null and attacker.is_passive_upgraded(attunement.id):
			var attunement_status := (
				GameEnums.StatusType.BURN
				if target_tile.definition.id == &"fire"
				else GameEnums.StatusType.BLEED
			)
			target.active_statuses.append(DataLibrary.make_status(
				attunement_status,
				1,
				passive_value(attacker, &"attunement_burn_mag", &"", attacker.current_magic),
			))
	if _is_hazard_tile(target_tile):
		var chakra := _find_passive(attacker, &"chakra_burn")
		if chakra != null:
			target.active_statuses.append(DataLibrary.make_status(
				GameEnums.StatusType.BURN,
				1,
				passive_value(attacker, &"chakra_burn_mag", &"", attacker.current_magic),
			))
			if attacker.is_passive_upgraded(chakra.id):
				target.active_statuses.append(DataLibrary.make_status(
					GameEnums.StatusType.BLIND, 1,
				))
	if effect != null and effect.modifiers.has("steal_target_magic"):
		var stolen := int(effect.modifiers["steal_target_magic"])
		target.passive_flags["monk_stolen_magic"] = int(
			target.passive_flags.get("monk_stolen_magic", 0),
		) + stolen
		target._recalculate_stats(board)
	if action != null and action.ability != null \
			and attacker.passive_flags.get("monk_inner_fire_turns", 0) > 0 \
			and effect.scaling_stat == GameEnums.StatType.PHYSICAL:
		var splash := DataLibrary._effect(GameEnums.EffectType.DAMAGE, 1)
		splash.scaling_stat = GameEnums.StatType.MAGICAL
		if attacker.passive_flags.get("monk_inner_fire_surface", false):
			splash.modifiers["create_fire_after_damage"] = true
		for direction: Vector2i in GridSystem.DIRECTIONS:
			var adjacent := board.get_unit_at(target.position + direction)
			if adjacent == null or not adjacent.is_alive() or adjacent.team == attacker.team:
				continue
			AbilitySystem.apply_external_effect(
				board, attacker, action, splash, events, adjacent.position, adjacent,
			)
			if splash.modifiers.get("create_fire_after_damage", false):
				var fire := DataLibrary._effect(GameEnums.EffectType.CREATE_HAZARD, 0)
				fire.modifiers = {
					"terrain_id": &"fire",
					"hazard_duration": 1,
					"elemental_surface": true,
				}
				AbilitySystem.apply_external_effect(
					board, attacker, action, fire, events, adjacent.position, adjacent,
				)
		attacker.passive_flags.erase("monk_reaction_depth")


static func on_dealt_damage(
	board: BoardState,
	attacker: UnitState,
	target: UnitState,
	events: Array[SimEvent],
) -> void:
	if attacker == null or target == null:
		return
	var ability := attacker.passive_flags.get("__current_ability", null) as AbilityData
	var effect := DataLibrary._effect(GameEnums.EffectType.DAMAGE, 0)
	effect.scaling_stat = (
		ability.scaling_stat if ability != null else GameEnums.StatType.PHYSICAL
	)
	var mods := _ability_modifiers(attacker, ability)
	effect.modifiers = mods
	var action := TimelineAction.new()
	action.actor_id = attacker.id
	action.type = GameEnums.ActionType.ABILITY
	action.ability = ability
	action.target_coord = target.position
	on_attack_hit(
		board,
		attacker,
		target,
		action,
		effect,
		target.health.current_hp + 1,
		events,
	)


static func damage_bonus(
	board: BoardState,
	attacker: UnitState,
	_target: UnitState,
	_effect: EffectData,
) -> int:
	if board == null or attacker == null:
		return 0
	if not has_passive_modifier(attacker, &"adjacent_elemental_attack"):
		return 0
	var adjacent_elemental := 0
	for direction: Vector2i in GridSystem.DIRECTIONS:
		var adjacent := board.get_tile(attacker.position + direction)
		if _is_elemental_tile(adjacent):
			adjacent_elemental += 1
	return adjacent_elemental * int(passive_value(
		attacker,
		&"adjacent_elemental_attack",
		&"upgraded_adjacent_elemental_attack",
		1,
	))


static func on_weave_consumed(
	board: BoardState,
	actor: UnitState,
	target_coord: Vector2i,
	events: Array[SimEvent],
) -> void:
	if actor == null or board == null or not has_passive_modifier(actor, &"weaver_resonance"):
		return
	var _formula_key := int(passive_value(actor, &"weaver_resonance_damage", &"", 1))
	var damage := maxi(
		_formula_key,
		floori(float(actor.current_strength + actor.current_magic) * 0.5),
	)
	CombatSystem.add_armor(
		board,
		actor,
		passive_value(actor, &"weaver_resonance_shield", &"", 1),
		events,
	)
	var upgraded := actor.is_passive_upgraded(&"weavers_resonance")
	var source_type: StringName = (
		&"physical" if actor.current_strength >= actor.current_magic else &"magical"
	)
	for coord: Vector2i in GridSystem.get_affected_tiles(
		board,
		actor.position,
		target_coord,
		GameEnums.TargetShape.AOE_CROSS,
		1,
	):
		var victim := board.get_unit_at(coord)
		if victim == null or not victim.is_alive() or victim.team == actor.team:
			continue
		CombatSystem.deal_damage(
			board,
			victim,
			damage,
			events,
			source_type,
			false,
			false,
			actor,
			"Weaver's Resonance",
			damage,
		)
		if upgraded:
			victim.active_statuses.append(DataLibrary.make_status(
				GameEnums.StatusType.WEAKEN, 1,
			))


static func after_ability_execute(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	events: Array[SimEvent],
) -> void:
	if actor == null or action == null:
		return
	var mods := _ability_modifiers(actor, action.ability)
	if mods.has("next_turn_move_penalty"):
		actor.passive_flags["monk_next_turn_move_penalty"] = int(
			mods["next_turn_move_penalty"],
		)
	if mods.has("inner_fire"):
		actor.passive_flags["monk_inner_fire_turns"] = 2
		actor.passive_flags["monk_inner_fire_surface"] = bool(
			mods.get("inner_fire_surface", false),
		)
	if mods.get("leap_absorb_surface", false) \
			and _is_elemental_tile(board.get_tile(actor.position)):
		var land_tile := board.get_tile(actor.position)
		if land_tile != null and land_tile.definition != null:
			actor.passive_flags["monk_absorbed_element"] = land_tile.definition.id
	if mods.has("landed_magic_bonus") and actor.passive_flags.get(
			"jumped_or_teleported_this_turn", false,
	):
		actor.active_statuses.append(DataLibrary.make_status(
			GameEnums.StatusType.STAT_BUFF_MAG, 1, int(mods["landed_magic_bonus"]),
		))
		actor._recalculate_stats(board)
	if mods.has("enemy_pushed_mov"):
		var pushed := int(actor.passive_flags.get("monk_pushed_enemies", 0))
		if pushed > 0:
			actor.movement.max_points += pushed * int(mods["enemy_pushed_mov"])
			actor.movement.points_left += pushed * int(mods["enemy_pushed_mov"])
			actor.passive_flags.erase("monk_pushed_enemies")
	if actor.passive_flags.get("monk_next_turn_move_penalty", 0) > 0:
		actor.passive_flags["monk_next_turn_move_penalty"] = int(
			actor.passive_flags["monk_next_turn_move_penalty"],
		)
	actor.passive_flags.erase("monk_first_hit_zero")
	actor._recalculate_stats(board)


static func on_terrain_created(
	board: BoardState,
	actor: UnitState,
	coord: Vector2i,
	events: Array[SimEvent],
) -> void:
	if actor == null or not has_passive_modifier(actor, &"terrain_created_defense"):
		return
	var amount := passive_value(actor, &"terrain_created_defense", &"", 1)
	var upgraded := _find_passive(actor, &"elemental_shield")
	if upgraded != null and actor.is_passive_upgraded(upgraded.id):
		amount = passive_value(actor, &"upgraded_terrain_created_defense", &"", amount)
	actor.active_statuses.append(DataLibrary.make_status(
		GameEnums.StatusType.STAT_BUFF_DEF, 1, amount,
	))
	actor._recalculate_stats(board)


static func on_turn_start_penalty(board: BoardState, actor: UnitState) -> void:
	var penalty := int(actor.passive_flags.get("monk_next_turn_move_penalty", 0))
	if penalty <= 0:
		return
	actor.active_statuses.append(DataLibrary.make_status(
		GameEnums.StatusType.STAT_DEBUFF_MOV, 1, penalty,
	))
	actor.passive_flags.erase("monk_next_turn_move_penalty")
	actor._recalculate_stats(board)


static func _ability_modifiers(actor: UnitState, ability: AbilityData) -> Dictionary:
	return AbilitySystem.active_modifier_profile(actor, ability)


static func _find_passive(unit: UnitState, passive_id: StringName) -> PassiveData:
	if unit == null:
		return null
	for passive: PassiveData in unit.active_passives:
		if passive != null and passive.id == passive_id:
			return passive
	return null


static func _is_elemental_tile(tile: TileState) -> bool:
	return tile != null and tile.definition != null and tile.definition.id in [
		&"fire", &"frozen", &"water", &"steam", &"oil",
	]


static func _all_adjacent_empty(board: BoardState, unit: UnitState) -> bool:
	for direction: Vector2i in GridSystem.DIRECTIONS:
		var tile := board.get_tile(unit.position + direction)
		if tile == null or not tile.is_empty():
			return false
	return true


static func _is_hazard_tile(tile: TileState) -> bool:
	return tile != null and tile.definition != null and (
		tile.definition.hazard_damage > 0 or tile.definition.is_trap
	)
