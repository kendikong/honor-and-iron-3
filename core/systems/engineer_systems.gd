extends RefCounted

## Shared Engineer lifecycle and modifier interpretation.
## No Engineer ability IDs are inspected here; authored module/passive keys are
## the only switches, so the same construct rules work for future classes.


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


static func has_ability_modifier(
	actor: UnitState,
	ability: AbilityData,
	key: StringName,
) -> bool:
	if actor == null or ability == null:
		return false
	for module: AbilityModule in ability.get_active_modules(
		actor.is_ability_upgraded(ability.id)
	):
		if module != null and module.legacy_modifiers.has(key):
			return true
	return false


static func barbed_wire_adjacent_defense(board: BoardState, unit: UnitState) -> int:
	if board == null or unit == null:
		return 0
	var bonus := 0
	for direction: Vector2i in GridSystem.DIRECTIONS:
		var coord := unit.position + direction
		var tile := board.get_tile(coord)
		if tile == null or tile.definition == null or tile.definition.id != &"barbed_wire":
			continue
		var payload: Dictionary = board.terrain_payloads.get(coord, {})
		bonus = maxi(bonus, int(payload.get("adjacent_defense_bonus", 0)))
	return bonus


static func ability_has_explosion(actor: UnitState, ability: AbilityData) -> bool:
	if actor == null or ability == null:
		return false
	for module: AbilityModule in ability.get_active_modules(
		actor.is_ability_upgraded(ability.id)
	):
		if module != null and module.primary_type in [
			GameEnums.EffectType.EXPLODE,
			GameEnums.EffectType.RANGED_EXPLODE,
		]:
			return true
		if module.legacy_modifiers.has("rocket_launcher") \
				or module.legacy_modifiers.has("mine_explode") \
				or module.legacy_modifiers.has("manual_detonation") \
				or module.legacy_modifiers.has("ignite_oil"):
			return true
	return false


static func _repair_range(engineer: UnitState) -> int:
	if has_passive_modifier(engineer, &"repair_range"):
		return int(passive_value(engineer, &"repair_range", &"", 2))
	return 1


static func _grant_repair_attack_bonus(engineer: UnitState) -> void:
	if engineer == null or not has_passive_modifier(engineer, &"repair_next_attack_strength"):
		return
	engineer.passive_flags["next_attack_strength_bonus"] = int(passive_value(
		engineer, &"repair_next_attack_strength",
		&"upgraded_repair_next_attack_strength", 1,
	))


static func _boost_owned_construct_hp(board: BoardState, engineer: UnitState, amount: int) -> void:
	if board == null or engineer == null or amount <= 0:
		return
	for construct: UnitState in board.units:
		if (
			construct == null
			or not construct.is_alive()
			or construct.definition == null
			or not construct.definition.is_construct
			or int(construct.passive_flags.get("engineer_owner_id", -1)) != engineer.id
		):
			continue
		construct.health.max_hp += amount
		construct.health.current_hp += amount


static func _flush_actor_delayed_effects(
	board: BoardState,
	actor: UnitState,
	events: Array[SimEvent],
) -> void:
	if board == null or actor == null or board.delayed_effects.is_empty():
		return
	var remaining: Array = []
	for entry: Dictionary in board.delayed_effects:
		if int(entry.get("actor_id", -1)) != actor.id:
			remaining.append(entry)
			continue
		AbilitySystem.execute_delayed_effect(board, entry, events)
	board.delayed_effects.clear()
	for entry: Dictionary in remaining:
		board.delayed_effects.append(entry)


static func is_pull_immune(board: BoardState, target: UnitState) -> bool:
	if board == null or target == null:
		return false
	for direction: Vector2i in GridSystem.DIRECTIONS:
		var turret := board.get_unit_at(target.position + direction)
		if (
			turret != null
			and turret.team == target.team
			and turret.definition != null
			and turret.definition.is_construct
			and turret.passive_flags.get("engineer_construct_kind", &"") == &"construct_turret"
		):
			var owner := board.get_unit_by_id(
				int(turret.passive_flags.get("engineer_owner_id", -1)),
			)
			if (
				owner != null
			):
				for passive: PassiveData in owner.active_passives:
					if (
						passive != null
						and passive.modifiers.has("upgraded_turret_adjacent_pull_immunity")
						and owner.is_passive_upgraded(passive.id)
					):
						return true
	return false


static func on_construct_entered(
	board: BoardState,
	unit: UnitState,
	construct: UnitState,
	events: Array[SimEvent],
) -> void:
	if (
		board == null
		or unit == null
		or construct == null
		or unit.team == construct.team
		or construct.passive_flags.get("engineer_construct_kind", &"") != &"magnetic_mine"
	):
		return
	var owner := board.get_unit_by_id(int(construct.passive_flags.get("engineer_owner_id", -1)))
	if owner == null:
		return
	var spawn_modifiers: Dictionary = construct.passive_flags.get("engineer_spawn_modifiers", {})
	if spawn_modifiers.get("absorbs_items_scrap", false) and unit.scrap > 0:
		owner.scrap += unit.scrap
		unit.scrap = 0
	var pull_direction := PhysicsSystem.cardinal_from_to(unit.position, construct.position)
	if pull_direction != Vector2i.ZERO:
		PhysicsSystem.push(board, unit, pull_direction, 2, events, owner)
	CombatSystem.deal_damage(
		board, unit, 2, events, &"physical", false, false, owner, "Magnetic Mine", 2,
	)
	_destroy_construct(board, owner, construct, events)


static func after_damage(
	board: BoardState,
	target: UnitState,
	armor_before: int,
	events: Array[SimEvent],
) -> void:
	if (
		board == null
		or target == null
		or armor_before <= 0
		or target.armor > 0
		or not target.passive_flags.get("engineer_scrap_shield_spent", false)
	):
		return
	var should_explode := bool(
		target.passive_flags.get("engineer_scrap_shield_depletion_explode", false)
	)
	target.passive_flags.erase("engineer_scrap_shield_spent")
	target.passive_flags.erase("engineer_scrap_shield_depletion_explode")
	if not should_explode:
		return
	var owner := board.get_unit_by_id(
		int(target.passive_flags.get("engineer_scrap_shield_owner_id", -1)),
	)
	var weapon_damage := (
		owner.definition.equipped_weapon.might
		if owner != null
		and owner.definition != null
		and owner.definition.equipped_weapon != null
		else 1
	)
	for direction: Vector2i in GridSystem.DIRECTIONS:
		var victim := board.get_unit_at(target.position + direction)
		if victim == null or victim.team == target.team:
			continue
		CombatSystem.deal_damage(
			board, victim, weapon_damage, events, &"physical", false, false,
			owner, "Scrap Shield", weapon_damage,
		)
		var push_direction := PhysicsSystem.cardinal_from_to(target.position, victim.position)
		if push_direction != Vector2i.ZERO:
			PhysicsSystem.push(board, victim, push_direction, 1, events, owner)


static func grant_overclock(construct: UnitState) -> void:
	if construct == null:
		return
	if not construct.has_status(GameEnums.StatusType.OVERCLOCK):
		construct.active_statuses.append(
			DataLibrary.make_status(GameEnums.StatusType.OVERCLOCK, 1)
		)
	construct.passive_flags["engineer_overclocked"] = true


static func damage_adjustment(
	_board: BoardState,
	actor: UnitState,
	target: UnitState,
	effect: EffectData,
) -> Dictionary:
	if actor == null or effect == null:
		return {}
	var adjustment := {"amount": 0, "pierce": false}
	var current_ability := actor.passive_flags.get("__current_ability", null) as AbilityData
	if (
		current_ability != null
		and actor.is_ability_upgraded(current_ability.id)
		and effect.modifiers.has("scrap_attack_bonus")
		and actor.scrap > 0
	):
		actor.scrap -= 1
		adjustment["amount"] = int(effect.modifiers["scrap_attack_bonus"])
		actor.passive_flags["engineer_flak_bleed_target"] = target.id if target != null else -1
	if effect.type in [GameEnums.EffectType.EXPLODE, GameEnums.EffectType.RANGED_EXPLODE]:
		if has_passive_modifier(actor, &"explosive_ignore_def"):
			adjustment["pierce"] = true
		if target != null and target.definition != null and target.definition.is_construct:
			adjustment["amount"] = int(adjustment["amount"]) + int(passive_value(
				actor, &"explosive_mechanical_bonus", &"", 0,
			))
		for passive: PassiveData in actor.active_passives:
			if (
				passive != null
				and passive.modifiers.has("explosive_mechanical_bonus")
				and actor.is_passive_upgraded(passive.id)
			):
				adjustment["amount"] = int(adjustment["amount"]) + int(
					passive.modifiers.get("upgraded_explosion_attack_bonus", 0)
				)
				break
	return adjustment


static func can_use_recall(
	board: BoardState,
	actor: UnitState,
	destination: Vector2i,
) -> bool:
	if board == null or actor == null or not GridSystem.is_in_bounds(board, destination):
		return false
	if GridSystem.is_occupied(board, destination) or not GridSystem.is_passable(board, destination):
		return false
	for construct: UnitState in board.units:
		if (
			construct != null
			and construct.is_alive()
			and construct.team == actor.team
			and construct.definition != null
			and construct.definition.is_construct
			and GridSystem.manhattan(construct.position, destination) == 1
		):
			return true
	return false


static func can_pass_through_friendly_construct(
	unit: UnitState,
	occupant: UnitState,
) -> bool:
	return (
		unit != null
		and occupant != null
		and occupant.team == unit.team
		and occupant.definition != null
		and occupant.definition.is_construct
		and has_passive_modifier(unit, &"construct_passable")
	)


static func on_construct_passed(
	board: BoardState,
	unit: UnitState,
	construct: UnitState,
	events: Array[SimEvent],
) -> void:
	if not can_pass_through_friendly_construct(unit, construct):
		return
	if not unit.is_passive_upgraded(&"blueprint_tread"):
		return
	CombatSystem.add_armor(board, unit, 1, events)
	CombatSystem.add_armor(board, construct, 1, events)


static func after_movement(
	board: BoardState,
	unit: UnitState,
	events: Array[SimEvent],
) -> void:
	if unit == null or board == null or unit.movement_points_spent_this_turn <= 0:
		return
	if has_passive_modifier(unit, &"maintenance_repair"):
		for construct: UnitState in board.units:
			if (
				construct == null
				or not construct.is_alive()
				or construct.definition == null
				or not construct.definition.is_construct
				or construct.team != unit.team
				or GridSystem.manhattan(unit.position, construct.position) != 1
			):
				continue
			CombatSystem.heal(
				board,
				construct,
				int(passive_value(unit, &"maintenance_repair", &"upgraded_maintenance_repair", 1)),
				events,
			)
			AbilitySystem.cleanse_unit(construct, events)
			var shield := int(passive_value(unit, &"maintenance_shield", &"", 1))
			CombatSystem.add_armor(board, unit, shield, events)
			CombatSystem.add_armor(board, construct, shield, events)
			_grant_repair_attack_bonus(unit)
			break
	# Field Technician extends Blueprint Tread range; it does not auto-heal on move.


static func turn_start(
	_board: BoardState,
	unit: UnitState,
	_events: Array[SimEvent],
) -> void:
	if unit == null:
		return
	if unit.passive_flags.get("engineer_exhaust_next_turn", false):
		unit.ability.points_left = 0
		unit.passive_flags.erase("engineer_exhaust_next_turn")
	unit.passive_flags.erase("engineer_scrap_shield_spent")
	unit.passive_flags.erase("engineer_explosion_ap_granted")
	unit.passive_flags.erase("engineer_recycling_ap_granted")
	unit.passive_flags.erase("engineer_construct_destroyed_by_ability")
	unit.passive_flags.erase("__engineer_event_start")


static func turn_end(
	_board: BoardState,
	unit: UnitState,
	_events: Array[SimEvent],
) -> void:
	if unit == null:
		return
	if unit.definition != null and unit.definition.is_construct:
		unit.passive_flags.erase("engineer_overclocked")
	unit.passive_flags.erase("engineer_target_def_pct")
	unit.passive_flags.erase("engineer_construct_attack_bonus")
	unit.passive_flags.erase("engineer_exhaust_next_turn")


static func player_phase_end(board: BoardState, events: Array[SimEvent]) -> void:
	if board == null:
		return
	var engineers: Array[UnitState] = []
	for unit: UnitState in board.units:
		if unit != null and unit.is_alive() and unit.team == GameEnums.Team.PLAYER:
			if has_passive_modifier(unit, &"construct_repair_adjacent"):
				engineers.append(unit)
			_spawn_stationary_turret(board, unit, events)
	for engineer: UnitState in engineers:
		_repair_adjacent_construct(board, engineer, events)
	_resolve_turrets(board, events)
	_apply_overclock_turn_damage(board, events)


static func on_spawned(
	board: BoardState,
	owner: UnitState,
	spawned: UnitState,
	effect: EffectData,
	_action: TimelineAction,
	_events: Array[SimEvent],
) -> void:
	if (
		board == null
		or owner == null
		or spawned == null
		or spawned.definition == null
		or not spawned.definition.is_construct
	):
		return
	spawned.passive_flags["engineer_owner_id"] = owner.id
	spawned.passive_flags["engineer_construct_kind"] = spawned.definition.id
	spawned.passive_flags["engineer_spawn_modifiers"] = (
		effect.modifiers.duplicate(true) if effect != null else {}
	)
	_apply_construct_bonuses(owner, spawned)


static func on_construct_destroyed(
	board: BoardState,
	construct: UnitState,
	events: Array[SimEvent],
) -> void:
	if construct == null or construct.definition == null or not construct.definition.is_construct:
		return
	var owner := board.get_unit_by_id(int(construct.passive_flags.get("engineer_owner_id", -1)))
	if owner == null:
		return
	var spawn_modifiers: Dictionary = construct.passive_flags.get(
		"engineer_spawn_modifiers", {}
	)
	var death_damage := int(spawn_modifiers.get("on_death_adjacent_damage", 0))
	if death_damage > 0:
		for direction: Vector2i in GridSystem.DIRECTIONS:
			var target := board.get_unit_at(construct.position + direction)
			if target != null and target.is_alive() and target.team != owner.team:
				CombatSystem.deal_damage(
					board, target, death_damage, events, &"physical", false, false,
					owner, "Construct Death", death_damage,
				)
	if has_passive_modifier(owner, &"construct_destroyed_scrap"):
		var amount := int(passive_value(
			owner, &"construct_destroyed_scrap",
			&"upgraded_construct_destroyed_scrap", 2,
		))
		owner.scrap += amount
		if not owner.passive_flags.get("engineer_recycling_ap_granted", false):
			owner.ability.points_left = mini(owner.ability.max_points, owner.ability.points_left + 1)
			owner.passive_flags["engineer_recycling_ap_granted"] = true
	if (
		owner.passive_flags.get("__current_ability", null) != null
		and has_ability_modifier(
			owner,
			owner.passive_flags["__current_ability"] as AbilityData,
			&"construct_destruction_refund_ap",
		)
	):
		owner.passive_flags["engineer_construct_destroyed_by_ability"] = true
	_trigger_chain_reaction(board, owner, construct.position, construct.id, events)
	var overdrive_scrap := int(construct.passive_flags.get("overdrive_scrap_on_death", 0))
	if overdrive_scrap > 0:
		owner.scrap += overdrive_scrap


static func on_kill(
	board: BoardState,
	attacker: UnitState,
	target: UnitState,
	_events: Array[SimEvent],
) -> void:
	if board == null or target == null or target.definition == null or target.definition.is_construct:
		return
	for engineer: UnitState in board.units:
		if (
			engineer == null
			or not engineer.is_alive()
			or engineer.team == target.team
			or not has_passive_modifier(engineer, &"enemy_death_scrap_range")
			or GridSystem.manhattan(engineer.position, target.position) > int(
				passive_value(engineer, &"enemy_death_scrap_range", &"", 3)
			)
		):
			continue
		var amount := int(passive_value(
			engineer, &"upgraded_enemy_death_scrap",
			&"", 1,
		))
		for passive: PassiveData in engineer.active_passives:
			if passive != null and passive.modifiers.has("enemy_death_scrap_range"):
				amount = 2 if engineer.is_passive_upgraded(passive.id) else 1
				break
		engineer.scrap += amount
		_boost_owned_construct_hp(board, engineer, amount)


static func after_ability_execute(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	events: Array[SimEvent],
) -> void:
	if actor == null or action == null or action.ability == null:
		return
	var modules: Array[AbilityModule] = action.ability.get_active_modules(
		actor.is_ability_upgraded(action.ability.id)
	)
	for module_index: int in modules.size():
		var module: AbilityModule = modules[module_index]
		if module == null:
			continue
		var modifiers := module.legacy_modifiers
		if modifiers.get("sacrifice_construct_instant", false):
			var sacrifice_target := board.get_unit_by_id(
				AbilitySystem.module_target_unit_id(action, module_index)
			)
			if (
				sacrifice_target != null
				and sacrifice_target.is_alive()
				and sacrifice_target.team == actor.team
				and sacrifice_target.definition != null
				and sacrifice_target.definition.is_construct
			):
				_destroy_construct(board, actor, sacrifice_target, events)
				_flush_actor_delayed_effects(board, actor, events)
		if modifiers.get("ignite_oil", false) or modifiers.get("ignite_oil_area", false):
			_ignite_oil(board, actor, action, module, events)
		if modifiers.get("scrap_shield", false):
			_apply_scrap_shield(board, actor, action, events)
		if modifiers.get("wrench_smack", false):
			_apply_wrench(board, actor, action, module, events)
		if modifiers.get("manual_detonation", false):
			_detonate_construct(board, actor, action, module, events)
		if modifiers.get("overdrive_injection", false):
			_apply_overdrive_cost(board, actor, action, module, events)
		if modifiers.get("emp_grenade", false):
			_apply_emp_construct_rules(board, actor, action, module, events)
		if modifiers.has("target_def_pct_loss"):
			var target := board.get_unit_by_id(action.target_unit_id)
			if target == null:
				target = board.get_unit_at(action.target_coord)
			if target != null:
				target.passive_flags["engineer_target_def_pct"] = float(
					modifiers["target_def_pct_loss"]
				)
		if modifiers.get("arrival_overclock", false):
			for construct: UnitState in board.units:
				if (
					construct != null
					and construct.is_alive()
					and construct.team == actor.team
					and construct.definition != null
					and construct.definition.is_construct
					and GridSystem.manhattan(construct.position, actor.position) == 1
				):
					grant_overclock(construct)
					break
		if modifiers.get("on_hit_scrap", false) and _ability_hit(events, actor.id):
			actor.scrap += int(modifiers["on_hit_scrap"])
		if (
			modifiers.get("construct_destruction_refund_ap", 0) > 0
			and actor.passive_flags.get("engineer_construct_destroyed_by_ability", false)
		):
			actor.ability.points_left = mini(actor.ability.max_points, actor.ability.points_left + 1)
			actor.passive_flags.erase("engineer_construct_destroyed_by_ability")
		if modifiers.get("scrap_bleed_weapon", false):
			var bleed_target := board.get_unit_by_id(
				int(actor.passive_flags.get("engineer_flak_bleed_target", -1))
			)
			if bleed_target != null and bleed_target.is_alive():
				var bleed_amount := (
					actor.definition.equipped_weapon.might
					if actor.definition != null and actor.definition.equipped_weapon != null
					else 1
				)
				bleed_target.active_statuses.append(
					DataLibrary.make_status(GameEnums.StatusType.BLEED, 1, bleed_amount)
				)
			actor.passive_flags.erase("engineer_flak_bleed_target")
		if modifiers.get("exhaust_next_turn", false):
			actor.passive_flags["engineer_exhaust_next_turn"] = true
		if (
			ability_has_explosion(actor, action.ability)
			and actor.is_passive_upgraded(&"blast_shielding")
			and not actor.passive_flags.get("engineer_explosion_ap_granted", false)
		):
			var event_start := int(actor.passive_flags.get("__engineer_event_start", 0))
			var enemy_hits := 0
			for event_index: int in range(event_start, events.size()):
				var event := events[event_index]
				if event.type != GameEnums.SimEventType.UNIT_DAMAGED:
					continue
				var victim := board.get_unit_by_id(int(event.data.get("unit", -1)))
				if victim != null and victim.team != actor.team and int(event.data.get("amount", 0)) > 0:
					enemy_hits += 1
			if enemy_hits >= 3:
				actor.ability.points_left = mini(actor.ability.max_points, actor.ability.points_left + 1)
				actor.passive_flags["engineer_explosion_ap_granted"] = true
	actor.passive_flags.erase("engineer_explosion_active")
	actor.passive_flags.erase("__engineer_event_start")


static func _apply_construct_bonuses(owner: UnitState, construct: UnitState) -> void:
	var hp_bonus := int(passive_value(
		owner, &"construct_hp_bonus_pct", &"upgraded_construct_hp_bonus_pct", 0,
	))
	if hp_bonus > 0:
		var bonus_hp := floori(construct.health.max_hp * hp_bonus / 100.0)
		construct.health.max_hp += bonus_hp
		construct.health.current_hp += bonus_hp
	var def_inherit := int(passive_value(
		owner, &"construct_def_inherit_pct", &"upgraded_construct_def_inherit_pct", 0,
	))
	if def_inherit > 0:
		construct.active_statuses.append(DataLibrary.make_status(
			GameEnums.StatusType.STAT_BUFF_DEF, 999,
			floori(owner.current_defense * def_inherit / 100.0),
		))
	construct._recalculate_stats()


static func _spawn_stationary_turret(
	board: BoardState,
	engineer: UnitState,
	events: Array[SimEvent],
) -> void:
	if (
		not has_passive_modifier(engineer, &"stationary_mini_turret")
		or engineer.movement_points_spent_this_turn > 0
		or _active_construct_count(board, engineer) >= _construct_limit(engineer)
	):
		return
	for direction: Vector2i in GridSystem.DIRECTIONS:
		var coord := engineer.position + direction
		if not GridSystem.is_passable(board, coord) or GridSystem.is_occupied(board, coord):
			continue
		var definition := DataLibrary.get_unit(&"construct_turret")
		if definition == null:
			return
		var turret := UnitState.create(board.next_unit_id(), definition, engineer.team, coord)
		var hp := maxi(1, floori(engineer.health.max_hp * 25 / 100.0))
		if engineer.is_passive_upgraded(&"turret_syndrome"):
			hp = maxi(1, floori(hp * 1.5))
		turret.health.max_hp = hp
		turret.health.current_hp = turret.health.max_hp
		turret.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STURDY, 999))
		turret.passive_flags["engineer_owner_id"] = engineer.id
		turret.passive_flags["engineer_construct_kind"] = &"construct_turret"
		turret.passive_flags["engineer_spawn_modifiers"] = {"turret_attack": 1}
		board.add_unit(turret)
		GridSystem.set_occupant(board, coord, turret.id)
		events.append(SimEvent.make(GameEnums.SimEventType.UNIT_SPAWNED, {
			"actor": engineer.id, "unit": turret.id, "coord": coord,
		}))
		return


static func _repair_adjacent_construct(
	board: BoardState,
	engineer: UnitState,
	events: Array[SimEvent],
) -> void:
	for construct: UnitState in board.units:
		if (
			construct == null
			or not construct.is_alive()
			or construct.definition == null
			or not construct.definition.is_construct
			or construct.team != engineer.team
			or GridSystem.manhattan(engineer.position, construct.position) > _repair_range(engineer)
		):
			continue
		CombatSystem.heal(
			board, construct, int(passive_value(
				engineer, &"construct_repair_adjacent", &"", 1,
			)), events,
		)
		_grant_repair_attack_bonus(engineer)
		return


static func _resolve_turrets(board: BoardState, events: Array[SimEvent]) -> void:
	for turret: UnitState in board.units:
		if (
			turret == null
			or not turret.is_alive()
			or turret.definition == null
			or not turret.definition.is_construct
			or turret.passive_flags.get("engineer_construct_kind", &"") != &"construct_turret"
		):
			continue
		var owner := board.get_unit_by_id(int(turret.passive_flags.get("engineer_owner_id", -1)))
		if owner == null:
			continue
		var attacks := 1
		if (
			has_passive_modifier(owner, &"construct_overclock")
			or turret.passive_flags.get("engineer_overclocked", false)
		):
			attacks = 2
		for _attack_index: int in attacks:
			var target := _nearest_enemy(board, turret, _turret_range(owner))
			if target == null:
				break
			var power := 1 + int(passive_value(
				owner, &"turret_attack_bonus", &"upgraded_turret_attack_bonus", 0,
			))
			power += int(turret.passive_flags.get("engineer_construct_attack_bonus", 0))
			turret.passive_flags.erase("engineer_construct_attack_bonus")
			CombatSystem.deal_damage(
				board, target, power, events, &"physical", false, false,
				owner, "Turret", power,
			)


static func _apply_overclock_turn_damage(board: BoardState, events: Array[SimEvent]) -> void:
	for construct: UnitState in board.units:
		if (
			construct == null
			or not construct.is_alive()
			or construct.definition == null
			or not construct.definition.is_construct
		):
			continue
		var owner := board.get_unit_by_id(int(construct.passive_flags.get("engineer_owner_id", -1)))
		if owner == null or not has_passive_modifier(owner, &"construct_overclock"):
			continue
		var damage := int(passive_value(
			owner, &"overclock_turn_damage", &"upgraded_overclock_turn_damage", 1,
		))
		if damage > 0:
			CombatSystem.deal_damage(
				board, construct, damage, events, &"true", true, false,
				owner, "Overclock", damage,
			)


static func _apply_scrap_shield(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	_events: Array[SimEvent],
) -> void:
	var target := board.get_unit_by_id(action.target_unit_id)
	if target == null:
		target = board.get_unit_at(action.target_coord)
	if target == null or actor.scrap <= 0:
		return
	var spent := actor.scrap
	actor.scrap = 0
	target.armor += spent * 2
	target.passive_flags["engineer_scrap_shield_spent"] = true
	target.passive_flags["engineer_scrap_shield_owner_id"] = actor.id
	target.passive_flags["engineer_scrap_shield_depletion_explode"] = actor.is_ability_upgraded(
		action.ability.id
	)


static func _apply_wrench(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	module: AbilityModule,
	events: Array[SimEvent],
) -> void:
	var target := board.get_unit_by_id(action.target_unit_id)
	if target == null:
		target = board.get_unit_at(action.target_coord)
	if target == null or target.team != actor.team or target.definition == null or not target.definition.is_construct:
		return
	CombatSystem.heal(board, target, 2, events)
	AbilitySystem.cleanse_unit(target, events)
	grant_overclock(target)
	var bonus := int(module.legacy_modifiers.get("wrench_strength_bonus", 0))
	if actor.is_ability_upgraded(action.ability.id) and bonus > 0:
		actor.passive_flags["next_attack_strength_bonus"] = bonus
	_grant_repair_attack_bonus(actor)


static func _apply_overdrive_cost(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	module: AbilityModule,
	events: Array[SimEvent],
) -> void:
	var target := board.get_unit_by_id(action.target_unit_id)
	if target == null:
		target = board.get_unit_at(action.target_coord)
	if target == null or target.definition == null or not target.definition.is_construct:
		return
	grant_overclock(target)
	CombatSystem.deal_damage(
		board, target, 2, events, &"true", true, false, actor,
		"Overdrive Injection", 2,
	)
	if actor.is_ability_upgraded(action.ability.id):
		target.passive_flags["overdrive_scrap_on_death"] = int(
			module.legacy_modifiers.get("refund_scrap_on_construct_death", 1)
		)


static func _detonate_construct(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	module: AbilityModule,
	events: Array[SimEvent],
) -> void:
	var target := board.get_unit_by_id(action.target_unit_id)
	if target == null:
		target = board.get_unit_at(action.target_coord)
	if (
		target == null
		or target.definition == null
		or not target.definition.is_construct
		or target.team != actor.team
	):
		return
	var owner := board.get_unit_by_id(int(target.passive_flags.get("engineer_owner_id", -1)))
	if owner == null:
		owner = actor
	_detonate_device(board, owner, target, "Manual Detonation", events)
	if module.legacy_modifiers.get("refund_scrap", 0) > 0:
		actor.scrap += int(module.legacy_modifiers["refund_scrap"])


static func _apply_emp_construct_rules(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	module: AbilityModule,
	events: Array[SimEvent],
) -> void:
	var area := GridSystem.get_affected_tiles(
		board, action.target_coord, action.target_coord,
		module.target_shape, module.target_shape_size,
	)
	for coord: Vector2i in area:
		var target := board.get_unit_at(coord)
		if target == null or target.definition == null:
			continue
		if target.team == actor.team:
			if (
				target.definition.is_construct
				and module.legacy_modifiers.has("emp_friendly_construct_heal")
			):
				CombatSystem.heal(
					board,
					target,
					int(module.legacy_modifiers["emp_friendly_construct_heal"]),
					events,
				)
				if module.legacy_modifiers.get("emp_friendly_construct_overclock", false):
					grant_overclock(target)
			continue
		if target.definition.is_construct:
			var boss_damage := int(module.legacy_modifiers.get("mechanical_boss_damage_wpn", 0))
			CombatSystem.deal_damage(
				board, target, boss_damage if target.definition.is_boss else target.health.current_hp,
				events, &"true", true, false, actor, "EMP Grenade", boss_damage,
			)


static func _ignite_oil(
	board: BoardState,
	actor: UnitState,
	action: TimelineAction,
	module: AbilityModule,
	events: Array[SimEvent],
) -> void:
	var coords := GridSystem.get_affected_tiles(
		board, action.target_coord, action.target_coord,
		module.target_shape, module.target_shape_size,
	)
	for coord: Vector2i in coords:
		var tile := board.get_tile(coord)
		if tile == null or tile.definition == null or tile.definition.id != &"oil":
			continue
		board.set_tile_terrain(coord, DataLibrary.get_terrain(&"fire"))
		events.append(SimEvent.make(GameEnums.SimEventType.TERRAIN_CHANGED, {
			"coord": coord, "terrain": &"fire",
		}))


static func _destroy_construct(
	board: BoardState,
	_owner: UnitState,
	construct: UnitState,
	events: Array[SimEvent],
) -> void:
	if construct == null or not construct.is_alive():
		return
	var position := construct.position
	construct.health.current_hp = 0
	on_construct_destroyed(board, construct, events)
	if board.get_unit_at(position) == construct:
		GridSystem.set_occupant(board, position, -1)


static func _detonate_device(
	board: BoardState,
	owner: UnitState,
	device: UnitState,
	source_label: String,
	events: Array[SimEvent],
) -> void:
	if board == null or owner == null or device == null or not device.is_alive():
		return
	var center := device.position
	var blast_size := 1 + int(passive_value(owner, &"explosion_aoe_bonus", &"", 0))
	var victims := GridSystem.get_affected_tiles(
		board, center, center, GameEnums.TargetShape.AOE_CROSS, blast_size,
	)
	var destroy_traps := owner.is_passive_upgraded(&"expanded_blast")
	for coord: Vector2i in victims:
		if destroy_traps:
			var tile := board.get_tile(coord)
			if (
				tile != null
				and tile.definition != null
				and (tile.definition.is_trap or tile.definition.blocks_movement)
			):
				var plain := DataLibrary.get_terrain(&"plain")
				if plain != null:
					board.set_tile_terrain(coord, plain)
					board.terrain_payloads.erase(coord)
					events.append(SimEvent.make(GameEnums.SimEventType.TERRAIN_CHANGED, {
						"coord": coord, "terrain": &"plain", "destroyed_by": owner.id,
					}))
		var victim := board.get_unit_at(coord)
		if victim == null or victim.team == owner.team:
			continue
		CombatSystem.deal_damage(
			board, victim, 2, events, &"physical", false, false, owner, source_label, 2,
		)
		var spawn_modifiers: Dictionary = device.passive_flags.get(
			"engineer_spawn_modifiers", {},
		)
		if spawn_modifiers.get("manual_detonation_stagger", false):
			if not CombatSystem.try_resist_crowd_control(
				victim, GameEnums.StatusType.STAGGER, events, board, owner,
			):
				victim.active_statuses.append(
					DataLibrary.make_status(GameEnums.StatusType.STAGGER, 1)
				)
				victim._recalculate_stats(board)
		if has_passive_modifier(owner, &"detonation_bleed_weapon"):
			var weapon_damage := (
				owner.definition.equipped_weapon.might
				if owner.definition != null and owner.definition.equipped_weapon != null
				else 1
			)
			victim.active_statuses.append(
				DataLibrary.make_status(GameEnums.StatusType.BLEED, 1, weapon_damage)
			)
			if owner.is_passive_upgraded(&"shrapnel"):
				victim.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.BLIND, 1))
			var push_direction := PhysicsSystem.cardinal_from_to(center, victim.position)
			if push_direction != Vector2i.ZERO:
				PhysicsSystem.push(board, victim, push_direction, 1, events, owner)
	_destroy_construct(board, owner, device, events)


static func _trigger_chain_reaction(
	board: BoardState,
	owner: UnitState,
	center: Vector2i,
	excluded_id: int,
	events: Array[SimEvent],
) -> void:
	if owner == null or not has_passive_modifier(owner, &"chain_reaction_range"):
		return
	var chain_range := int(passive_value(
		owner, &"chain_reaction_range", &"upgraded_chain_reaction_range", 2,
	))
	var devices: Array[UnitState] = []
	for candidate: UnitState in board.units:
		if (
			candidate != null
			and candidate.id != excluded_id
			and candidate.is_alive()
			and candidate.team == owner.team
			and candidate.definition != null
			and candidate.definition.is_construct
			and candidate.passive_flags.get("engineer_spawn_modifiers", {}).get(
				"mine_explode", false
			)
			and GridSystem.manhattan(candidate.position, center) <= chain_range
		):
			devices.append(candidate)
	for device: UnitState in devices:
		_detonate_device(board, owner, device, "Chain Reaction", events)


static func _active_construct_count(board: BoardState, owner: UnitState) -> int:
	var count := 0
	for unit: UnitState in board.units:
		if (
			unit != null
			and unit.is_alive()
			and unit.definition != null
			and unit.definition.is_construct
			and int(unit.passive_flags.get("engineer_owner_id", -1)) == owner.id
		):
			count += 1
	return count


static func _construct_limit(owner: UnitState) -> int:
	return 3 + int(passive_value(
		owner, &"active_construct_limit", &"upgraded_active_construct_limit", 0,
	))


static func _turret_range(owner: UnitState) -> int:
	return 1 + int(passive_value(owner, &"turret_range_bonus", &"", 0))


static func _nearest_enemy(
	board: BoardState,
	source: UnitState,
	max_range: int,
) -> UnitState:
	var nearest: UnitState = null
	var nearest_distance := 1_000_000
	for unit: UnitState in board.units:
		if (
			unit == null
			or not unit.is_alive()
			or unit.team == source.team
			or GridSystem.manhattan(unit.position, source.position) > max_range
		):
			continue
		var distance := GridSystem.manhattan(unit.position, source.position)
		if distance < nearest_distance:
			nearest = unit
			nearest_distance = distance
	return nearest


static func _ability_hit(events: Array[SimEvent], actor_id: int) -> bool:
	for index: int in range(events.size() - 1, maxi(-1, events.size() - 12), -1):
		var event := events[index]
		if event.type == GameEnums.SimEventType.UNIT_DAMAGED and int(
			event.data.get("source", -1)
		) == actor_id:
			return true
	return false
