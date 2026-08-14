extends RefCounted

## Shared Shaman lifecycle hooks. AbilitySystem, CombatSystem, UnitState, and
## Simulator remain the canonical owners; this file only interprets generic
## Shaman data flags and module payloads.


static func dynamic_stat_adjustments(board: BoardState, unit: UnitState) -> Dictionary:
	var result := {"strength": 0, "magic": 0, "defense": 0, "movement": 0}
	if board == null or unit == null:
		return result
	if unit.passive_flags.get("shaman_wither", false):
		result.movement -= 2
	for source: UnitState in board.units:
		if source == null or not source.is_alive():
			continue
		var source_distance := GridSystem.manhattan(source.position, unit.position)
		if _is_guardian_source(source) and source_distance <= 1:
			result.defense += _guardian_defense(source)
		if (
			source.team != unit.team
			and _has_passive_modifier(source, &"soul_burn")
			and unit_has_debuff(unit)
		):
			result.movement -= int(_passive_value(
				source, &"soul_burn_mov", &"upgraded_soul_burn_mov", 1,
			))
		var aura := _hexing_aura(source)
		if aura.is_empty() or source_distance > int(aura.range):
			continue
		if source.team != unit.team:
			result.strength += int(aura.strength)
			result.magic += int(aura.magic)
			result.defense += int(aura.defense)
			result.movement += int(aura.movement)
			if bool(aura.miasma) and unit_has_debuff(unit):
				result.movement -= int(aura.miasma_movement)
	return result


static func can_gain_positive_buff(target: UnitState) -> bool:
	return target != null and not target.passive_flags.get("shaman_wither", false)


static func can_gain_shield(board: BoardState, target: UnitState) -> bool:
	if board == null or target == null:
		return true
	if target.passive_flags.get("shaman_wither", false):
		return false
	for source: UnitState in board.units:
		if source == null or source.team == target.team or not source.is_alive():
			continue
		var aura := _hexing_aura(source)
		if not aura.is_empty() and GridSystem.manhattan(source.position, target.position) <= int(aura.range):
			return false
	return true


static func turn_start(board: BoardState, unit: UnitState, events: Array[SimEvent]) -> void:
	if unit == null or not unit.is_alive():
		return
	if not unit.passive_flags.get("_shaman_aura_refreshed", false):
		for affected: UnitState in board.units:
			if affected != null and affected.is_alive():
				affected._recalculate_stats(board)
				affected.passive_flags["_shaman_aura_refreshed"] = true
	if unit.passive_flags.get("shaman_bloodlust_active", false):
		var hp_cost := int(unit.passive_flags.get("shaman_bloodlust_hp", 2))
		CombatSystem.deal_damage(board, unit, hp_cost, events, &"true", true, false, unit, "Bloodlust", hp_cost)
	_shaman_totem_pulses(board, unit, events)


static func turn_end(unit: UnitState) -> void:
	if unit != null:
		unit.passive_flags.erase("_shaman_aura_refreshed")
		if unit.passive_flags.has("shaman_wither"):
			var wither_turns := int(unit.passive_flags.get("shaman_wither_turns", 0)) - 1
			if wither_turns <= 0:
				unit.passive_flags.erase("shaman_wither")
				unit.passive_flags.erase("shaman_wither_turns")
			else:
				unit.passive_flags["shaman_wither_turns"] = wither_turns
		if unit.passive_flags.has("shaman_ghost_turns"):
			var ghost_turns := int(unit.passive_flags["shaman_ghost_turns"]) - 1
			if ghost_turns <= 0:
				unit.health.current_hp = 0
				unit.passive_flags.erase("shaman_ghost_turns")
			else:
				unit.passive_flags["shaman_ghost_turns"] = ghost_turns


static func damage_bonus(
	board: BoardState,
	attacker: UnitState,
	target: UnitState,
	effect: EffectData,
	source_type: StringName,
) -> int:
	if attacker == null or target == null:
		return 0
	var bonus := 0
	if effect != null and effect.modifiers.has("bonus_damage_per_debuff"):
		bonus += unit_debuff_count(target) * int(effect.modifiers["bonus_damage_per_debuff"])
	if effect != null and effect.modifiers.has("soul_siphon"):
		bonus += unit_debuff_count(target)
	if unit_has_debuff(target):
		if board == null:
			return bonus
		for source: UnitState in board.units:
			if source == null or source.team == target.team or not source.is_alive():
				continue
			if _has_passive_modifier(source, &"soul_burn"):
				bonus += _passive_value(
					source, &"soul_burn_damage", &"upgraded_soul_burn_damage", 1,
				)
			var aura := _hexing_aura(source)
			if (
				not aura.is_empty()
				and bool(aura.get("miasma", false))
				and GridSystem.manhattan(source.position, target.position) <= int(aura.range)
				and source_type in [&"bleed", &"burn", &"poison", &"hazard"]
			):
				bonus += _passive_value(
					source, &"miasma_dot_bonus", &"upgraded_miasma_dot_bonus", 1,
				)
	if attacker.passive_flags.get("shaman_next_attack_magic", false) \
			and effect != null and effect.scaling_stat == GameEnums.StatType.MAGICAL:
		bonus += int(attacker.passive_flags["shaman_next_attack_magic"])
		attacker.passive_flags.erase("shaman_next_attack_magic")
	return bonus


static func can_use_ritual_sacrifice(actor: UnitState, ability: AbilityData) -> bool:
	if actor == null or ability == null or ability.kind != GameEnums.AbilityKind.CLASS_SKILL:
		return false
	return (
		_has_passive_modifier(actor, &"ritual_sacrifice")
		and not actor.passive_flags.get("shaman_ritual_used_this_turn", false)
		and ability.action_point_cost > 0
	)


static func ritual_sacrifice_cost(actor: UnitState) -> int:
	if actor == null:
		return 0
	return _passive_value(
		actor, &"ritual_hp_cost", &"upgraded_ritual_hp_cost", 3,
	)


static func conduit_range_bonus(actor: UnitState, ability: AbilityData) -> int:
	if actor == null or ability == null or not _has_passive_modifier(actor, &"voodoo_conduit"):
		return 0
	var modules := ability.get_active_modules(actor.is_ability_upgraded(ability.id))
	for module: AbilityModule in modules:
		if module == null:
			continue
		if (
			module.legacy_modifiers.has("totem_kind")
			or module.legacy_modifiers.has("voodoo_link")
			or (
				module.primary_type == GameEnums.EffectType.ADD_STATUS
				and GameEnums.is_debuff(module.status_type)
			)
		):
			return _passive_value(
				actor, &"conduit_range_bonus", &"upgraded_conduit_range_bonus", 1,
			)
	return 0


static func unit_debuff_count(unit: UnitState) -> int:
	if unit == null:
		return 0
	var count := 0
	for status: StatusData in unit.active_statuses:
		if status != null and GameEnums.is_debuff(status.type):
			count += 1
	return count


static func on_healed(
	board: BoardState,
	healer: UnitState,
	target: UnitState,
	amount: int,
	events: Array[SimEvent],
) -> void:
	if board == null or healer == null or target == null or amount <= 0:
		return
	var linked_enemy := board.get_unit_by_id(
		int(target.passive_flags.get("shaman_bond_enemy_id", -1)),
	)
	if (
		linked_enemy != null
		and linked_enemy.is_alive()
		and healer.has_passive(&"sympathetic_magic")
	):
		if not healer.passive_flags.get("shaman_sympathetic_processing", false):
			healer.passive_flags["shaman_sympathetic_processing"] = true
			CombatSystem.heal(
				board,
				target,
				_passive_value(healer, &"linked_ally_heal", &"linked_ally_heal", 1),
				events,
			)
			healer.passive_flags.erase("shaman_sympathetic_processing")
		linked_enemy.passive_flags["shaman_bond_healed"] = true
		target.active_statuses.append(DataLibrary.make_status(
			GameEnums.StatusType.STAT_BUFF_MAG,
			1,
			_passive_value(
				healer, &"linked_ally_magic", &"upgraded_linked_ally_magic", 1,
			),
		))
		target._recalculate_stats(board)
	if _has_passive_modifier(healer, &"soul_weaver"):
		_transfer_oldest_debuff(board, healer, target, events)


static func on_kill(
	board: BoardState,
	killer: UnitState,
	victim: UnitState,
	events: Array[SimEvent],
) -> void:
	if board == null or killer == null or victim == null:
		return
	if not _has_passive_modifier(killer, &"soul_collector"):
		return
	var cap := _passive_value(killer, &"soul_orb_cap", &"upgraded_soul_orb_cap", 3)
	var dropped := int(killer.passive_flags.get("shaman_soul_orbs_dropped", 0))
	if dropped >= cap:
		return
	killer.passive_flags["shaman_soul_orbs_dropped"] = dropped + 1
	board.soul_orbs[victim.position] = {
		"owner_id": killer.id,
		"magic": _passive_value(killer, &"soul_orb_magic", &"soul_orb_magic", 1),
		"max_hp": _passive_value(killer, &"soul_orb_max_hp", &"soul_orb_max_hp", 1),
	}


static func collect_soul_orb(
	board: BoardState,
	collector: UnitState,
	coord: Vector2i,
	events: Array[SimEvent],
) -> void:
	if board == null or collector == null or not board.soul_orbs.has(coord):
		return
	var orb: Dictionary = board.soul_orbs[coord]
	var owner := board.get_unit_by_id(int(orb.get("owner_id", -1)))
	if owner == null or owner.team != collector.team:
		return
	collector.active_statuses.append(DataLibrary.make_status(
		GameEnums.StatusType.STAT_BUFF_MAG, -1, int(orb.get("magic", 1)),
	))
	collector.health.max_hp += int(orb.get("max_hp", 1))
	collector.health.current_hp = mini(collector.health.max_hp, collector.health.current_hp + 1)
	collector._recalculate_stats(board)
	board.soul_orbs.erase(coord)
	events.append(SimEvent.make(GameEnums.SimEventType.STATUS_APPLIED, {
		"unit": collector.id, "soul_orb": true,
		"magic": int(orb.get("magic", 1)),
		"max_hp": int(orb.get("max_hp", 1)),
	}))


static func on_push_resolved(
	board: BoardState,
	pusher: UnitState,
	target: UnitState,
	ability_id: StringName,
	events: Array[SimEvent],
) -> void:
	if board == null or target == null or not target.is_alive():
		return
	if target.passive_flags.get("shaman_push_processing", false):
		return
	var partner := board.get_unit_by_id(int(target.passive_flags.get("shaman_link_partner_id", -1)))
	if (
		partner != null
		and partner.is_alive()
		and target.passive_flags.get("shaman_link_shared_push", false)
		and pusher != null
		and pusher.team != target.team
	):
		target.passive_flags["shaman_push_processing"] = true
		var distance := int(target.passive_flags.get("shaman_link_push_amount", 1))
		var direction := PhysicsSystem.cardinal_from_to(
			target.position, partner.position,
		)
		if direction != Vector2i.ZERO:
			PhysicsSystem.push(board, partner, direction, distance, events, pusher, ability_id)
		target.passive_flags.erase("shaman_push_processing")
	if (
		target.passive_flags.get("shaman_poison_spread_on_push", false)
		and target.has_status(GameEnums.StatusType.POISON)
	):
		for direction: Vector2i in GridSystem.DIRECTIONS:
			var adjacent := board.get_unit_at(target.position + direction)
			if (
				adjacent != null
				and adjacent.is_alive()
				and adjacent.team != target.team
				and not adjacent.has_status(GameEnums.StatusType.POISON)
			):
				adjacent.active_statuses.append(DataLibrary.make_status(
					GameEnums.StatusType.POISON, 1,
				))
				adjacent._recalculate_stats(board)


static func pre_status_application(
	board: BoardState,
	actor: UnitState,
	target: UnitState,
	effect: EffectData,
	events: Array[SimEvent],
	action: TimelineAction = null,
) -> bool:
	if actor == null or target == null or effect == null:
		return false
	if effect.modifiers.get("push_mitigation_zero", false):
		target.passive_flags["no_push_mitigation"] = true
	if (
		GameEnums.is_buff(effect.status_type)
		and effect.amount > 0
		and not can_gain_positive_buff(target)
	):
		events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
			"actor": actor.id, "reason": "wither_blocks_buff",
		}))
		return true
	if effect.modifiers.get("requires_missing_hp", false) \
			and target.health.current_hp >= target.health.max_hp:
		events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
			"actor": actor.id, "reason": "target_at_full_health",
		}))
		return true
	if effect.modifiers.get("terrify", false) and target.is_boss():
		if (
			not effect.modifiers.get("boss_fallback_purge_shield", false)
			and not effect.modifiers.get("boss_fallback_vulnerable", false)
		):
			return false
		target.armor = 0
		if effect.modifiers.get("boss_fallback_vulnerable", false):
			target.active_statuses.append(DataLibrary.make_status(
				GameEnums.StatusType.VULNERABLE, 1,
			))
		target._recalculate_stats(board)
		events.append(SimEvent.make(GameEnums.SimEventType.STATUS_APPLIED, {
			"unit": target.id, "boss_fallback": true,
			"stripped_shield": true,
		}))
		return true
	if effect.modifiers.get("hex", false):
		target.passive_flags["shaman_wither"] = true
		target.passive_flags["shaman_wither_turns"] = effect.status_duration
		if effect.modifiers.get("hex_vulnerable", false):
			target.active_statuses.append(DataLibrary.make_status(
				GameEnums.StatusType.VULNERABLE, effect.status_duration,
			))
		target._recalculate_stats(board)
		events.append(SimEvent.make(GameEnums.SimEventType.STATUS_APPLIED, {
			"unit": target.id, "status": &"wither",
		}))
		return true
	if effect.modifiers.get("poison_spread_on_push_collision", false):
		target.passive_flags["shaman_poison_spread_on_push"] = true
	if effect.modifiers.get("sympathetic_bond", false):
		var ally: UnitState = target if target.team == actor.team else null
		var enemy: UnitState = target if target.team != actor.team else null
		if action != null:
			var picked_ally := board.get_unit_by_id(AbilitySystem.module_target_unit_id(action, 0))
			var picked_enemy := board.get_unit_by_id(AbilitySystem.module_target_unit_id(action, 1))
			if picked_ally != null and picked_ally.team == actor.team:
				ally = picked_ally
			if picked_enemy != null and picked_enemy.team != actor.team:
				enemy = picked_enemy
		if ally == null or enemy == null:
			var module_count: int = AbilitySystem.active_modules_for(
				actor, action.ability if action != null else null,
			).size()
			if module_count >= 2:
				events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
					"actor": actor.id, "reason": "sympathetic_bond_requires_ally_and_enemy",
				}))
			return true
		link_ally_enemy(board, actor, ally, enemy, effect, events)
	return false


static func link_ally_enemy(
	board: BoardState,
	actor: UnitState,
	ally: UnitState,
	enemy: UnitState,
	effect: EffectData,
	events: Array[SimEvent],
) -> void:
	if board == null or actor == null or ally == null or enemy == null:
		return
	ally.passive_flags["shaman_bond_enemy_id"] = enemy.id
	enemy.passive_flags["shaman_bond_ally_id"] = ally.id
	enemy.passive_flags["shaman_bond_owner_id"] = actor.id
	enemy.passive_flags["shaman_bond_enemy_damage_heal"] = int(
		effect.modifiers.get("enemy_damage_ally_heal", 0),
	)
	if _has_passive_modifier(actor, &"spiritual_guardian"):
		ally.passive_flags["shaman_guardian_link"] = true
		ally.passive_flags["shaman_guardian_def"] = _passive_value(
			actor, &"guardian_aura_def", &"upgraded_guardian_aura_def", 1,
		)
		enemy.passive_flags["shaman_guardian_link"] = true
		enemy.passive_flags["shaman_guardian_def"] = ally.passive_flags[
			"shaman_guardian_def"
		]
	events.append(SimEvent.make(GameEnums.SimEventType.STATUS_APPLIED, {
		"unit": ally.id, "partner": enemy.id, "link": "sympathetic_bond",
	}))


static func _transfer_oldest_debuff(
	board: BoardState,
	healer: UnitState,
	target: UnitState,
	events: Array[SimEvent],
) -> void:
	var removed: StatusData = null
	for index: int in range(target.active_statuses.size()):
		var candidate: StatusData = target.active_statuses[index]
		if candidate != null and GameEnums.is_debuff(candidate.type):
			removed = target.active_statuses.pop_at(index)
			break
	if removed == null:
		return
	target._recalculate_stats(board)
	var transfer_count := _passive_value(
		healer, &"soul_weaver_transfer_count", &"upgraded_soul_weaver_transfer_count", 1,
	)
	var candidates: Array[UnitState] = []
	for enemy: UnitState in board.units:
		if enemy != null and enemy.is_alive() and enemy.team != healer.team:
			candidates.append(enemy)
	candidates.sort_custom(func(a: UnitState, b: UnitState) -> bool:
		var da := GridSystem.manhattan(healer.position, a.position)
		var db := GridSystem.manhattan(healer.position, b.position)
		return da < db or (da == db and a.id < b.id)
	)
	for index: int in mini(transfer_count, candidates.size()):
		candidates[index].active_statuses.append(removed.clone())
		candidates[index]._recalculate_stats(board)


static func after_ability_execute(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	events: Array[SimEvent],
) -> void:
	if actor == null or action == null or action.ability == null:
		return
	var modifiers := _ability_modifiers(actor, action.ability)
	if modifiers.get("bloodlust", false):
		var target := board.get_unit_by_id(action.target_unit_id)
		if target != null and target.team == actor.team:
			target.passive_flags["shaman_bloodlust_active"] = true
			target.passive_flags["shaman_bloodlust_hp"] = int(modifiers.get("bloodlust_hp", 2))
			target.passive_flags["shaman_bloodlust_bleed_on_attack"] = bool(
				modifiers.get("bloodlust_bleed_on_attack", false),
			)
			target._recalculate_stats(board)
	if modifiers.has("totem_kind"):
		actor.passive_flags["shaman_last_totem_spawned"] = true
		if _has_passive_modifier(actor, &"spiritual_offering"):
			var shield := _passive_value(actor, &"offering_shield", &"upgraded_offering_shield", 1)
			CombatSystem.add_armor(board, actor, shield, events)
	if modifiers.get("ritual_sacrifice", false):
		actor.passive_flags["shaman_ritual_used_this_turn"] = true
	if (
		actor.passive_flags.get("shaman_echo_next_cast", false)
		and not modifiers.has("ally_corpse")
		and not actor.passive_flags.get("__shaman_echo_repeat", false)
	):
		actor.passive_flags.erase("shaman_echo_next_cast")
		actor.passive_flags["__shaman_echo_repeat"] = true
		var force_upgraded := bool(actor.passive_flags.get("shaman_echo_upgraded", false))
		var already_upgraded := actor.is_ability_upgraded(action.ability.id)
		if force_upgraded and not already_upgraded:
			actor.upgraded_abilities.append(action.ability.id)
		AbilitySystem.execute(board, action, events)
		if force_upgraded and not already_upgraded:
			actor.upgraded_abilities.erase(action.ability.id)
		actor.passive_flags.erase("__shaman_echo_repeat")


static func on_dealt_damage(
	board: BoardState,
	attacker: UnitState,
	target: UnitState,
	action: TimelineAction,
	effect: EffectData,
	events: Array[SimEvent],
	source_type: StringName = &"",
) -> void:
	if attacker == null or target == null or board == null:
		return
	if (
		attacker.has_passive(&"echoing_spirits")
		and source_type in [&"hazard", &"bleed", &"burn", &"poison"]
	):
		attacker.passive_flags["shaman_next_attack_magic"] = 1
	var partner := board.get_unit_by_id(int(target.passive_flags.get("shaman_link_partner_id", -1)))
	if (
		partner != null
		and partner.is_alive()
		and not target.passive_flags.get("shaman_link_processing", false)
		and target.passive_flags.has("shaman_link_weapon")
	):
		target.passive_flags["shaman_link_processing"] = true
		var shared := int(target.passive_flags.get("shaman_link_weapon", 1))
		CombatSystem.deal_damage(
			board, partner, shared, events, &"true", true, true, attacker,
			"Spirit Link", shared,
		)
		if (
			target.passive_flags.get("shaman_link_blind", false)
			or (
				effect != null
				and effect.modifiers.get("linked_enemy_blind", false)
			)
		) and partner.is_alive():
			partner.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.BLIND, 1))
		target.passive_flags.erase("shaman_link_processing")
	if target.passive_flags.has("shaman_bond_ally_id"):
		var bonded_ally := board.get_unit_by_id(
			int(target.passive_flags["shaman_bond_ally_id"]),
		)
		var bond_heal := int(target.passive_flags.get("shaman_bond_enemy_damage_heal", 0))
		if bonded_ally != null and bonded_ally.is_alive() and bond_heal > 0:
			CombatSystem.heal(board, bonded_ally, bond_heal, events)
	if (
		action != null
		and effect != null
		and effect.modifiers.get("pain_spike", false)
		and partner != null
		and partner.is_alive()
	):
		var spike := int(effect.modifiers.get("linked_enemy_damage", 1))
		CombatSystem.deal_damage(
			board, partner, spike, events, &"physical", true, true, attacker,
			"Pain Spike", spike,
		)
	if (
		attacker.passive_flags.get("shaman_bloodlust_bleed_on_attack", false)
		and target.is_alive()
		and action != null
		and action.ability != null
		and action.ability.has_tag(AbilityModuleBridge.TAG_ATTACK)
	):
		var weapon := attacker.definition.equipped_weapon.might if attacker.definition.equipped_weapon != null else 1
		target.active_statuses.append(DataLibrary.make_status(
			GameEnums.StatusType.BLEED, 1, weapon,
		))
		target._recalculate_stats(board)
	if (
		GridSystem.manhattan(attacker.position, target.position) == 1
		and target.has_passive(&"hexing_touch")
	):
		_apply_hexing_touch(target, attacker)
	if target.has_passive(&"voodoo_doll") and attacker != null:
		_voodoo_doll_revenge(board, target, events)


static func find_lightning_rod_redirect(board: BoardState, victim: UnitState) -> UnitState:
	if board == null or victim == null:
		return null
	for candidate: UnitState in board.units:
		if (
			candidate == null
			or not candidate.is_alive()
			or candidate.id == victim.id
			or candidate.team != victim.team
			or not candidate.passive_flags.get("shaman_lightning_rod", false)
		):
			continue
		if GridSystem.manhattan(candidate.position, victim.position) <= 1:
			return candidate
	return null


static func incoming_damage_bonus(target: UnitState) -> int:
	if target == null or not target.passive_flags.has("shaman_link_damage_bonus"):
		return 0
	return int(target.passive_flags["shaman_link_damage_bonus"])


static func incoming_damage_reduction(
	board: BoardState,
	target: UnitState,
	attacker: UnitState,
) -> int:
	if board == null or target == null or attacker == null:
		return 0
	if GridSystem.manhattan(target.position, attacker.position) <= 1:
		return 0
	for source: UnitState in board.units:
		if (
			source != null
			and source.is_alive()
			and source.team == target.team
			and source.passive_flags.get("shaman_totem_kind", &"") == &"guard"
			and GridSystem.manhattan(source.position, target.position) <= 1
		):
			return int(source.passive_flags.get("shaman_guard_ranged_reduction", 2))
	return 0


static func apply_spiritual_offering_on_hp_spend(
	board: BoardState,
	actor: UnitState,
	events: Array[SimEvent],
) -> void:
	if actor == null or not _has_passive_modifier(actor, &"spiritual_offering"):
		return
	var shield := _passive_value(actor, &"offering_shield", &"upgraded_offering_shield", 1)
	CombatSystem.add_armor(board, actor, shield, events)


static func on_spawned(
	board: BoardState,
	actor: UnitState,
	construct: UnitState,
	effect: EffectData,
	action: TimelineAction,
	events: Array[SimEvent],
) -> void:
	if actor == null or construct == null or effect == null:
		return
	if effect.modifiers.get("ally_corpse", false):
		construct.passive_flags["shaman_ghost_owner_id"] = actor.id
		construct.passive_flags["shaman_ghost_turns"] = int(
			effect.modifiers.get("ghost_duration", 1),
		)
		construct.passive_flags["shaman_ghost_echo_next_cast"] = true
		var ghost_hp := maxi(1, floori(
			actor.health.max_hp * float(effect.modifiers.get("ghost_hp_pct", 0.25)),
		))
		construct.health.max_hp = ghost_hp
		construct.health.current_hp = ghost_hp
		actor.passive_flags["shaman_ghost_id"] = construct.id
		actor.passive_flags["shaman_echo_next_cast"] = true
		if effect.modifiers.get("echo_upgraded", false):
			actor.passive_flags["shaman_echo_upgraded"] = true
		construct.passive_flags["shaman_guardian_link"] = true
		construct.passive_flags["shaman_guardian_def"] = _passive_value(
			actor, &"guardian_aura_def", &"upgraded_guardian_aura_def", 1,
		)
		construct._recalculate_stats(board)
		return
	if effect.modifiers.get("lightning_rod", false):
		construct.passive_flags["shaman_lightning_rod"] = true
	if not effect.modifiers.has("totem_kind"):
		return
	construct.passive_flags["shaman_totem_kind"] = effect.modifiers["totem_kind"]
	construct.passive_flags["shaman_totem_owner_id"] = actor.id
	var totem_modifiers: Dictionary = effect.modifiers.duplicate(true)
	var conduit_bonus := _passive_value(
		actor, &"conduit_range_bonus", &"upgraded_conduit_range_bonus", 0,
	) if _has_passive_modifier(actor, &"voodoo_conduit") else 0
	if totem_modifiers.has("pulse_aoe"):
		totem_modifiers["pulse_aoe"] = int(totem_modifiers["pulse_aoe"]) + conduit_bonus
	construct.passive_flags["shaman_totem_modifiers"] = totem_modifiers
	construct.passive_flags["shaman_totem_upgraded"] = actor.is_ability_upgraded(action.ability.id)
	construct.passive_flags["shaman_guardian_link"] = _has_passive_modifier(
		actor, &"spiritual_guardian",
	)
	construct.passive_flags["shaman_guard_ranged_reduction"] = int(
		effect.modifiers.get("ranged_reduction", 0),
	)
	construct.passive_flags["shaman_guardian_def"] = _passive_value(
		actor, &"guardian_aura_def", &"upgraded_guardian_aura_def", 1,
	)
	var hex_passive := _find_passive(actor, &"hexing_presence")
	if hex_passive != null:
		var hex_upgraded := actor.is_passive_upgraded(hex_passive.id)
		construct.passive_flags["shaman_totem_hex_range"] = int(hex_passive.modifiers.get(
			"upgraded_hexing_presence_range" if hex_upgraded else "hexing_presence_range", 2,
		))
		construct.passive_flags["shaman_totem_hex_mov"] = int(hex_passive.modifiers.get(
			"upgraded_hexing_presence_mov" if hex_upgraded else "hexing_presence_mov", 0,
		))
	construct._recalculate_stats(board)
	if _has_passive_modifier(actor, &"echoing_spirits") and actor.is_passive_upgraded(&"echoing_spirits"):
		var bonus_hp := int(_passive_value(actor, &"upgraded_totem_hp", &"upgraded_totem_hp", 2))
		construct.health.max_hp += bonus_hp
		construct.health.current_hp += bonus_hp


static func unit_has_debuff(unit: UnitState) -> bool:
	if unit == null:
		return false
	for status: StatusData in unit.active_statuses:
		if status != null and GameEnums.is_debuff(status.type):
			return true
	return false


static func _shaman_totem_pulses(board: BoardState, owner: UnitState, events: Array[SimEvent]) -> void:
	var totems: Array[UnitState] = []
	for candidate: UnitState in board.units:
		if (
			candidate != null
			and candidate.is_alive()
			and candidate.passive_flags.get("shaman_totem_owner_id", -1) == owner.id
		):
			totems.append(candidate)
	for totem: UnitState in totems:
		var mods: Dictionary = totem.passive_flags.get("shaman_totem_modifiers", {})
		var pulse_count := 2 if _has_passive_modifier(owner, &"echoing_spirits") else 1
		for _pulse: int in range(pulse_count):
			var radius := int(mods.get("pulse_aoe", 0))
			if radius <= 0:
				continue
			var shape := GameEnums.TargetShape.AOE_CROSS
			var affected := GridSystem.get_affected_tiles(board, totem.position, totem.position, shape, radius)
			for coord: Vector2i in affected:
				var target := board.get_unit_at(coord)
				if target == null or not target.is_alive():
					continue
				var kind: StringName = mods.get("totem_kind", &"")
				if kind == &"healing" and target.team == owner.team:
					var hp_before := target.health.current_hp
					CombatSystem.heal(board, target, int(mods.get("pulse_heal", 1)), events)
					on_healed(
						board, owner, target, target.health.current_hp - hp_before, events,
					)
					if totem.passive_flags.get("shaman_totem_upgraded", false):
						AbilitySystem.cleanse_unit(target, events)
				elif kind == &"flame" and target.team != owner.team:
					var raw := CombatSystem.calculate_scaled_damage(
						owner, int(mods.get("pulse_mag_atk", 1)), GameEnums.StatType.MAGICAL, board,
					)
					CombatSystem.deal_damage(board, target, raw, events, &"magical", false, false, owner, "Flame Totem")
				elif kind == &"earthbind" and target.team != owner.team:
					if CombatSystem.try_resist_crowd_control(target, GameEnums.StatusType.ROOT, events):
						continue
					target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.ROOT, 1))
					if totem.passive_flags.get("shaman_totem_upgraded", false):
						target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.WEAKEN, 1))
						target._recalculate_stats(board)
	_shaman_totem_fire(board, totems, events)


static func _shaman_totem_fire(board: BoardState, totems: Array[UnitState], events: Array[SimEvent]) -> void:
	for totem: UnitState in totems:
		var mods: Dictionary = totem.passive_flags.get("shaman_totem_modifiers", {})
		if mods.get("totem_kind", &"") != &"flame" or not totem.passive_flags.get("shaman_totem_upgraded", false):
			continue
		var fire := DataLibrary._effect(GameEnums.EffectType.CREATE_HAZARD, 0)
		fire.modifiers = {"terrain_id": &"fire", "hazard_duration": 1}
		var owner := board.get_unit_by_id(int(totem.passive_flags.get("shaman_totem_owner_id", -1)))
		if owner != null:
			var action := TimelineAction.make_ability(owner.id, DataLibrary.get_universal_wait(), totem.position)
			AbilitySystem.apply_external_effect(board, owner, action, fire, events, totem.position, totem)


static func _voodoo_doll_revenge(board: BoardState, shaman: UnitState, events: Array[SimEvent]) -> void:
	var closest: UnitState = null
	var distance := 1_000_000
	for candidate: UnitState in board.units:
		if (
			candidate == null
			or not candidate.is_alive()
			or candidate.team == shaman.team
			or not unit_has_debuff(candidate)
		):
			continue
		var candidate_distance := GridSystem.manhattan(shaman.position, candidate.position)
		if candidate_distance < distance:
			closest = candidate
			distance = candidate_distance
	if closest == null:
		return
	var weapon := shaman.definition.equipped_weapon.might if shaman.definition.equipped_weapon != null else 1
	if shaman.is_passive_upgraded(&"voodoo_doll"):
		weapon *= 2
	CombatSystem.deal_damage(board, closest, weapon, events, &"true", true, true, shaman, "Voodoo Doll", weapon)


static func _hexing_aura(source: UnitState) -> Dictionary:
	var passive := _find_passive(source, &"hexing_presence")
	if passive != null:
		var upgraded := source.is_passive_upgraded(passive.id)
		return {
			"range": int(passive.modifiers.get(
				"upgraded_hexing_presence_range" if upgraded else "hexing_presence_range", 2,
			)),
			"strength": int(passive.modifiers.get("hexing_presence_str", -2)),
			"magic": int(passive.modifiers.get("hexing_presence_mag", -2)),
			"defense": int(passive.modifiers.get("hexing_presence_def", -2)),
			"movement": int(passive.modifiers.get(
				"upgraded_hexing_presence_mov" if upgraded else "hexing_presence_mov", 0,
			)),
			"miasma": _has_passive_modifier(source, &"miasma_resonance"),
			"miasma_movement": 1,
		}
	var totem_kind: StringName = source.passive_flags.get("shaman_totem_kind", &"")
	if totem_kind != &"":
		return {
			"range": int(source.passive_flags.get("shaman_totem_hex_range", 2)),
			"strength": -2,
			"magic": -2,
			"defense": -2,
			"movement": int(source.passive_flags.get("shaman_totem_hex_mov", 0)),
			"miasma": false,
			"miasma_movement": 0,
		}
	return {}


static func _is_guardian_source(source: UnitState) -> bool:
	return source.passive_flags.get("shaman_guardian_link", false)


static func _guardian_defense(source: UnitState) -> int:
	return int(source.passive_flags.get("shaman_guardian_def", 1))


static func _ability_modifiers(actor: UnitState, ability: AbilityData) -> Dictionary:
	var result := {}
	if ability == null:
		return result
	for module: AbilityModule in ability.get_active_modules(actor.is_ability_upgraded(ability.id)):
		if module != null:
			result.merge(module.legacy_modifiers)
			for layer: AbilityLayer in module.layers:
				if layer != null and layer.effect != null:
					result.merge(layer.effect.modifiers)
	return result


static func _find_passive(unit: UnitState, passive_id: StringName) -> PassiveData:
	if unit == null:
		return null
	for passive: PassiveData in unit.active_passives:
		if passive != null and passive.id == passive_id:
			return passive
	return null


static func _has_passive_modifier(unit: UnitState, key: StringName) -> bool:
	if unit == null:
		return false
	for passive: PassiveData in unit.active_passives:
		if passive != null and passive.modifiers.has(key):
			return true
	return false


static func _passive_value(unit: UnitState, key: StringName, upgraded_key: StringName, default_value: int) -> int:
	var passive := _find_passive(unit, key)
	if passive == null:
		for candidate: PassiveData in unit.active_passives:
			if candidate != null and candidate.modifiers.has(key):
				passive = candidate
				break
	if passive == null:
		return default_value
	if unit.is_passive_upgraded(passive.id) and passive.modifiers.has(upgraded_key):
		return int(passive.modifiers[upgraded_key])
	return int(passive.modifiers.get(key, default_value))


static func _apply_hexing_touch(shaman: UnitState, attacker: UnitState) -> void:
	var passive := _find_passive(shaman, &"hexing_touch")
	if passive == null:
		return
	attacker.active_statuses.append(DataLibrary.make_status(
		GameEnums.StatusType.STAT_DEBUFF_DEF, -1,
		absi(int(passive.modifiers.get("hexing_touch_def", -1))),
	))
	attacker.active_statuses.append(DataLibrary.make_status(
		GameEnums.StatusType.WEAKEN, -1,
		absi(int(passive.modifiers.get("hexing_touch_str", -1))),
	))
	if shaman.is_passive_upgraded(passive.id):
		attacker.active_statuses.append(DataLibrary.make_status(
			GameEnums.StatusType.STAT_DEBUFF_MOV, -1,
			absi(int(passive.modifiers.get("upgraded_hexing_touch_mov", -1))),
		))
	attacker._recalculate_stats()
