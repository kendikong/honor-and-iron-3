class_name AbilitySystem
extends RefCounted

## Purpose: Runs the data-driven ability pipeline (Validate -> Execute -> Resolve).
## Responsibilities: Validate cost/range, spend action points, and interpret each
##   EffectData by delegating to the system that owns that effect.
## Dependencies: BoardState, UnitState, TimelineAction, EffectData, GridSystem,
##   CombatSystem, PhysicsSystem, SimEvent, GameEnums.
## Lifecycle: stateless; only static functions.

static func can_use(board: BoardState, action: TimelineAction) -> bool:
	var actor := board.get_unit_by_id(action.actor_id)
	if actor == null or not actor.is_alive():
		return false
	var ability := action.ability
	if ability == null:
		return false
	if actor.ability.points_left < ability.action_point_cost:
		return false
	var dist := GridSystem.manhattan(actor.position, action.target_coord)
	if ability_has_dash(ability):
		if PhysicsSystem.straight_line_dir(actor.position, action.target_coord) == Vector2i.ZERO:
			return false
		dist = PhysicsSystem.straight_line_distance(actor.position, action.target_coord)
	if dist > actor.get_ability_range(ability):
		return false
	if dist == 0 and actor.get_ability_range(ability) > 0 and not can_target_self(actor, ability):
		return false
		
	if dist > 1:
		var tile = board.get_tile(action.target_coord)
		if tile != null and not tile.is_empty():
			var target = board.get_unit_by_id(tile.occupant_id)
			if target != null and target.has_status(GameEnums.StatusType.STEALTH):
				return false
		
	if actor.has_status(GameEnums.StatusType.STUN) or actor.has_status(GameEnums.StatusType.SILENCE):
		return false
		
	# PACIFY prevents using abilities that deal DAMAGE
	if actor.has_status(GameEnums.StatusType.PACIFY):
		for effect in ability.effects:
			if effect.type == GameEnums.EffectType.DAMAGE or effect.type == GameEnums.EffectType.EXPLODE or effect.type == GameEnums.EffectType.RANGED_EXPLODE:
				return false
	
	for effect in ability.effects:
		if effect.type == GameEnums.EffectType.DASH:
			if PhysicsSystem.straight_line_dir(actor.position, action.target_coord) == Vector2i.ZERO:
				return false
			var steps := PhysicsSystem.straight_line_distance(actor.position, action.target_coord)
			if steps < 1 or steps > effect.amount:
				return false
				
	return true


static func can_target_self(actor: UnitState, ability: AbilityData) -> bool:
	if actor == null or ability == null:
		return false
	if DataLibrary.is_universal_wait(ability.id):
		return true
	if actor.get_ability_range(ability) == 0:
		return true
	var effects: Array[EffectData] = ability.effects
	if actor.is_ability_upgraded(ability.id) and not ability.upgraded_effects.is_empty():
		effects = ability.upgraded_effects
	if effects.is_empty():
		return false
	for effect: EffectData in effects:
		match effect.type:
			GameEnums.EffectType.ADD_STATUS_SELF, GameEnums.EffectType.DAMAGE_SELF:
				continue
			GameEnums.EffectType.HEAL, GameEnums.EffectType.ARMOR_UP, GameEnums.EffectType.CLEANSE:
				continue
			GameEnums.EffectType.ADD_STATUS:
				if GameEnums.is_buff(effect.status_type):
					continue
				return false
			_:
				return false
	return true


static func ability_has_dash(ability: AbilityData) -> bool:
	if ability == null:
		return false
	for eff in ability.effects:
		if eff.type == GameEnums.EffectType.DASH:
			return true
	return false


static func is_run_ability(ability: AbilityData) -> bool:
	return ability != null and DataLibrary.is_universal_run(ability.id)


static func is_wait_ability(ability: AbilityData) -> bool:
	return ability != null and DataLibrary.is_universal_wait(ability.id)


## Planning UI: skill button enabled when the unit could commit this ability now (ignores range).
static func ability_planning_selectable(actor: UnitState, ability: AbilityData) -> bool:
	if actor == null or ability == null:
		return false
	if actor.ability.points_left < ability.action_point_cost:
		return false
	if actor.has_status(GameEnums.StatusType.STUN) or actor.has_status(GameEnums.StatusType.SILENCE):
		return false
	if actor.has_status(GameEnums.StatusType.PACIFY) and ability_uses_attack_animation(ability):
		return false
	if consumes_action_slot(ability) and not actor.can_use_action_slot():
		return false
	return true


## Self-only buffs and Run do not consume the action slot (Wait still does when used).
static func consumes_action_slot(ability: AbilityData) -> bool:
	if ability == null:
		return false
	if is_wait_ability(ability) or is_run_ability(ability):
		return false
	if ability.effects.is_empty():
		return true
	for eff: EffectData in ability.effects:
		if eff.type != GameEnums.EffectType.ADD_STATUS_SELF:
			return true
	return false


static func apply_run_boost(actor: UnitState, events: Array[SimEvent]) -> void:
	_apply_running_boost(actor, events)


static func running_move_bonus(max_move: int) -> int:
	return int(floor(float(max_move) * 0.5))


static func preview_move_budget_with_run(unit: UnitState) -> int:
	if unit == null:
		return 0
	if unit.has_status(GameEnums.StatusType.RUNNING):
		return unit.movement.points_left
	return unit.movement.points_left + running_move_bonus(unit.movement.max_points)


static func movement_requires_run(
	board: BoardState,
	unit: UnitState,
	target_coord: Vector2i,
	waypoints: Array[Vector2i] = [],
) -> bool:
	if unit == null or unit.has_status(GameEnums.StatusType.RUNNING):
		return false
	var base_mp: int = unit.movement.points_left
	if MovementSystem.can_reach_coord(board, unit, target_coord, waypoints, base_mp):
		return false
	return MovementSystem.can_reach_coord(
		board, unit, target_coord, waypoints, preview_move_budget_with_run(unit),
	)


## True when selecting this ability should suppress basic walk (drag route, move highlights).
## Trample dashes like Bowling Charge are optional skills — basic movement stays available.
static func ability_blocks_basic_movement(ability: AbilityData) -> bool:
	if not ability_has_dash(ability):
		return false
	if ability.id in [&"knight_bowling_charge"]:
		return false
	return true

static func ability_uses_attack_animation(ability: AbilityData) -> bool:
	if ability == null or ability.is_movement_skill or DataLibrary.is_universal_run(ability.id):
		return false
	if DataLibrary.is_universal_wait(ability.id):
		return false
	if ability_is_offensive_dash(ability):
		return true
	var offensive_effects: Array[GameEnums.EffectType] = [
		GameEnums.EffectType.DAMAGE,
		GameEnums.EffectType.PUSH,
		GameEnums.EffectType.PULL,
		GameEnums.EffectType.EXPLODE,
		GameEnums.EffectType.RANGED_EXPLODE,
	]
	for eff: EffectData in ability.effects:
		if eff.type in offensive_effects:
			return true
	for eff: EffectData in ability.upgraded_effects:
		if eff.type in offensive_effects:
			return true
	return false


static func ability_is_offensive_dash(ability: AbilityData) -> bool:
	if not ability_has_dash(ability):
		return false
	var offensive_effects: Array[GameEnums.EffectType] = [
		GameEnums.EffectType.DAMAGE,
		GameEnums.EffectType.PUSH,
		GameEnums.EffectType.PULL,
		GameEnums.EffectType.EXPLODE,
		GameEnums.EffectType.RANGED_EXPLODE,
	]
	for eff in ability.effects:
		if eff.type in offensive_effects:
			return true
	for eff in ability.upgraded_effects:
		if eff.type in offensive_effects:
			return true
	if ability.id in [&"knight_bowling_charge", &"knight_trampling_advance", &"bruiser_violent_collision"]:
		return true
	return false

## Extra damage when striking a target from the tile behind its facing.
const BACKSTAB_BONUS: int = 2

static func execute(board: BoardState, action: TimelineAction, events: Array[SimEvent]) -> void:
	if not can_use(board, action):
		events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
			"actor": action.actor_id, "reason": "cannot_use_ability",
		}))
		return

	var actor := board.get_unit_by_id(action.actor_id)
	var ability := action.ability
	actor.ability.points_left -= action.ability.action_point_cost
	if not actor.has_unlimited_training_actions() and consumes_action_slot(ability):
		actor.turn_action_used = true

	# Wait is an exhaustion state — consumes the action slot silently (no VFX / log event).
	if DataLibrary.is_universal_wait(ability.id):
		apply_canto_move_refund(actor)
		return

	var target_coord := _resolve_target_coord(board, action)
	
	# Turn to face the target before resolving (positioning matters next exchange).
	var new_facing := PhysicsSystem.facing_from_vector(PhysicsSystem.cardinal_from_to(actor.position, target_coord))
	if action.ability.id == &"knight_seismic_stomp":
		new_facing = GameEnums.Facing.SOUTH
	if actor.facing != new_facing:
		actor.facing = new_facing
		events.append(SimEvent.make(GameEnums.SimEventType.UNIT_FACED, {"unit": actor.id, "facing": actor.facing}))
	var shape = action.ability.target_shape
	var shape_size = action.ability.target_shape_size
	if actor != null and actor.is_ability_upgraded(action.ability.id):
		if action.ability.upgraded_target_shape != GameEnums.TargetShape.SINGLE or action.ability.upgraded_target_shape_size != -1:
			shape = action.ability.upgraded_target_shape if action.ability.upgraded_target_shape != GameEnums.TargetShape.SINGLE else shape
			shape_size = action.ability.upgraded_target_shape_size if action.ability.upgraded_target_shape_size != -1 else shape_size
			
	var affected_tiles := GridSystem.get_affected_tiles(board, actor.position, target_coord, shape, shape_size)
	
	events.append(SimEvent.make(GameEnums.SimEventType.ABILITY_USED, {
		"actor": action.actor_id,
		"ability": action.ability.id,
		"ability_name": action.ability.display_name,
		"target_coord": target_coord,
		"target_unit": action.target_unit_id,
		"is_dash": ability_has_dash(action.ability),
	}))
	
	var effects_to_apply = action.ability.effects
	if actor.is_ability_upgraded(action.ability.id) and action.ability.upgraded_effects.size() > 0:
		effects_to_apply = action.ability.upgraded_effects
		
	if action.ability.id == &"knight_phalanx_stance" and actor.is_ability_upgraded(&"knight_phalanx_stance"):
		actor.passive_flags["phalanx_infinite_range"] = true
	
	for effect in effects_to_apply:
		if effect.type in [GameEnums.EffectType.DASH, GameEnums.EffectType.TELEPORT_CASTER]:
			_apply_effect_to_tile(board, actor, action, effect, events, target_coord, board.get_unit_at(target_coord))
			continue
		for tile_coord in affected_tiles:
			var target_unit := board.get_unit_at(tile_coord)
			_apply_effect_to_tile(board, actor, action, effect, events, tile_coord, target_unit)

	if actor != null and actor.is_alive() and actor.has_passive(&"intercept_tactics"):
		var is_redirect = false
		for effect in effects_to_apply:
			if effect.type in [GameEnums.EffectType.ADD_STATUS, GameEnums.EffectType.ADD_STATUS_SELF] \
					and effect.status_type in [GameEnums.StatusType.INTERCEPT, GameEnums.StatusType.TAUNT]:
				is_redirect = true
				break
		if is_redirect:
			var def_bonus = 3 if actor.is_passive_upgraded(&"intercept_tactics") else 2
			actor.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, def_bonus))
			actor._recalculate_stats()
			
	if actor != null and actor.is_alive() and actor.has_passive(&"kinetic_redirection"):
		var is_attack = false
		for effect in effects_to_apply:
			if effect.type in [GameEnums.EffectType.DAMAGE, GameEnums.EffectType.EXPLODE, GameEnums.EffectType.RANGED_EXPLODE]:
				is_attack = true
				break
		if is_attack:
			var stacks = actor.passive_flags.get("kinetic_redirection_stacks", 0)
			if stacks > 0:
				actor.passive_flags["kinetic_redirection_stacks"] = 0
				var to_remove = []
				for status in actor.active_statuses:
					if status.type == GameEnums.StatusType.STAT_BUFF_STR and status.duration == -1:
						to_remove.append(status)
				for status in to_remove:
					actor.active_statuses.erase(status)
				actor._recalculate_stats()

	apply_canto_move_refund(actor)


static func apply_canto_move_refund(actor: UnitState) -> void:
	if actor == null:
		return
	if actor.has_passive(&"canto") or actor.has_status(GameEnums.StatusType.CANTO):
		actor.movement.points_left = actor.movement.max_points
		var has_canto_status := false
		for status: StatusData in actor.active_statuses:
			if status.type == GameEnums.StatusType.CANTO:
				has_canto_status = true
				break
		if not has_canto_status:
			actor.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.CANTO, 1, 0))
		actor._recalculate_stats()

static func _apply_effect_to_tile(board: BoardState, actor: UnitState, action: TimelineAction, effect: EffectData, events: Array[SimEvent], tile_coord: Vector2i, target: UnitState) -> void:
	if target != null and actor != target and actor != null:
		var dist = GridSystem.manhattan(actor.position, target.position)
		var is_ranged = dist > 1
		var is_aoe = action.ability.target_shape != GameEnums.TargetShape.SINGLE
		
		if is_ranged or is_aoe:
			var dir_to_target = PhysicsSystem.cardinal_from_to(actor.position, target.position)
			var front_tile = target.position - dir_to_target
			var knight = board.get_unit_at(front_tile)
			if knight != null and knight.team == target.team and knight.has_passive(&"living_barricade"):
				var protects_aoe = knight.is_passive_upgraded(&"living_barricade")
				if (is_ranged and not is_aoe) or (is_aoe and protects_aoe):
					events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
						"actor": actor.id, "reason": "blocked_by_living_barricade",
						"target": target.id
					}))
					return
					
	if target != null:
		var hostile := false
		var friendly := false
		if effect.type in [GameEnums.EffectType.DAMAGE, GameEnums.EffectType.PURGE, GameEnums.EffectType.PUSH, GameEnums.EffectType.PULL]:
			hostile = true
		elif effect.type in [GameEnums.EffectType.HEAL, GameEnums.EffectType.ARMOR_UP, GameEnums.EffectType.CLEANSE]:
			friendly = true
		elif effect.type == GameEnums.EffectType.ADD_STATUS:
			if GameEnums.is_buff(effect.status_type):
				friendly = true
			elif GameEnums.is_debuff(effect.status_type):
				hostile = true
				
		if target == actor:
			if not friendly and not effect.type in [GameEnums.EffectType.ADD_STATUS_SELF, GameEnums.EffectType.DAMAGE_SELF, GameEnums.EffectType.TELEPORT_CASTER]:
				return
		elif actor != null:
			if hostile and target.team == actor.team:
				return
			if friendly and target.team != actor.team:
				return

	match effect.type:
		GameEnums.EffectType.DAMAGE:
			var pierce = false
			if actor.has_passive(&"kinetic_redirection") and actor.is_passive_upgraded(&"kinetic_redirection"):
				if actor.passive_flags.get("kinetic_redirection_stacks", 0) > 0:
					pierce = true
					
			var base_amt := effect.amount
			var amount := base_amt
			
			var wpn := 0
			if actor.definition != null and actor.definition.equipped_weapon != null:
				wpn = actor.definition.equipped_weapon.might
			
			var stat_val := actor.current_strength
			var stat_name := "STR"
			
			if action.ability.scaling_stat == GameEnums.StatType.PHYSICAL:
				stat_val = CombatSystem.get_dynamic_strength(board, actor)
			elif action.ability.scaling_stat == GameEnums.StatType.MAGICAL:
				stat_val = actor.current_magic
				stat_name = "MAG"
				
			if base_amt > 0:
				var raw = (base_amt + wpn) * (1.0 + stat_val / 5.0)
				amount = floori(raw)
				
			var dmg_type = &"physical"
			if action.ability.scaling_stat == GameEnums.StatType.MAGICAL:
				dmg_type = &"magical"
				
			var vuln = false
			var elec = false
			var backstabbed = false
			var target_def = 0
			var fort = 0
			
			var temp_def_debuff = null
			if target != null and action.ability.id == &"knight_shield_slam":
				if GridSystem.manhattan(actor.position, target.position) == 1:
					base_amt += 2
				if actor.is_ability_upgraded(&"knight_shield_slam"):
					temp_def_debuff = DataLibrary.make_status(GameEnums.StatusType.STAT_DEBUFF_DEF, 1, 1)
					target.active_statuses.append(temp_def_debuff)
					target._recalculate_stats()
			
			if target != null:
				if _is_backstab(actor, target):
					amount += BACKSTAB_BONUS
					backstabbed = true
				target_def = CombatSystem.get_dynamic_defense(board, target)
				var tile = board.get_tile(target.position)
				if tile != null and tile.definition != null:
					fort = tile.definition.fortitude
				vuln = target.has_status(GameEnums.StatusType.VULNERABLE)
				elec = target.has_status(GameEnums.StatusType.ELECTRIFIED)
				
			events.append(SimEvent.make(GameEnums.SimEventType.MATH_TELEMETRY, {
				"type": "damage",
				"base": base_amt,
				"wpn": wpn,
				"stat_name": stat_name,
				"stat_val": stat_val,
				"multiplier_raw": (base_amt + wpn) * (1.0 + stat_val / 5.0),
				"floored": floori((base_amt + wpn) * (1.0 + stat_val / 5.0)),
				"backstab": backstabbed,
				"backstab_bonus": BACKSTAB_BONUS if backstabbed else 0,
				"final_raw": amount,
				"target_def": target_def, "fortitude": fort,
				"vulnerable": vuln, "electrified": elec,
				"pierce": pierce
			}))
			CombatSystem.deal_damage(board, target, amount, events, dmg_type, pierce, false, null, action.ability.display_name)
			
			if temp_def_debuff != null and target != null:
				target.active_statuses.erase(temp_def_debuff)
				target._recalculate_stats()
		GameEnums.EffectType.PUSH:
			if target != null:
				var is_immune = false
				if target.has_status(GameEnums.StatusType.INVULNERABLE) or (not target.has_status(GameEnums.StatusType.VULNERABLE) and target.has_status(GameEnums.StatusType.STURDY)):
					is_immune = true
				if target.has_passive(&"stand_ground") and not target.has_status(GameEnums.StatusType.VULNERABLE):
					is_immune = true
					if actor != null and actor.team != target.team:
						var stand_amt := 2 if target.is_passive_upgraded(&"stand_ground") else 1
						CombatSystem.counter_attack(board, target, actor, stand_amt, events, "Stand Ground")
				
				if action.ability.id == &"knight_defensive_formation":
					for status in target.active_statuses:
						if status.type == GameEnums.StatusType.STURDY:
							if status.duration == 1:
								is_immune = true
								break
				
				if not is_immune:
					var dir := PhysicsSystem.cardinal_from_to(actor.position, target.position)
					
					var pending := {
						"type": "push",
						"target_id": target.id,
						"dir": dir,
						"amount": effect.amount,
						"actor_id": actor.id,
						"ability_id": action.ability.id
					}
					
					if action.ability.id == &"knight_shield_bash" and actor.is_ability_upgraded(&"knight_shield_bash"):
						pending["stun_on_collision"] = true
						
					if action.ability.id == &"knight_chain_hook" and actor.is_ability_upgraded(&"knight_chain_hook"):
						pending["vulnerable_on_adjacent"] = true
					
					board.pending_pushes.append(pending)
		GameEnums.EffectType.PULL:
			if target != null:
				var is_immune := false
				if target.has_passive(&"stand_ground") and not target.has_status(GameEnums.StatusType.VULNERABLE):
					is_immune = true
					if actor != null and actor.team != target.team:
						var stand_amt := 2 if target.is_passive_upgraded(&"stand_ground") else 1
						CombatSystem.counter_attack(board, target, actor, stand_amt, events, "Stand Ground")
				for dir in GridSystem.DIRECTIONS:
					var adj_unit = board.get_unit_at(target.position + dir)
					if adj_unit != null and adj_unit.team == target.team and adj_unit.has_passive(&"shield_wall"):
						is_immune = true
						break
				if not is_immune:
					for x in range(-2, 3):
						for y in range(-2, 3):
							if abs(x) + abs(y) == 2:
								var adj = target.position + Vector2i(x, y)
								var adj_unit = board.get_unit_at(adj)
								if adj_unit != null and adj_unit.team == target.team and adj_unit.has_passive(&"shield_wall") and adj_unit.is_passive_upgraded(&"shield_wall"):
									is_immune = true
									break
						if is_immune: break
				if not is_immune:
					var dir := PhysicsSystem.cardinal_from_to(target.position, actor.position)
					
					var pending := {
						"type": "pull",
						"target_id": target.id,
						"dir": dir,
						"amount": effect.amount,
						"actor_id": actor.id,
						"ability_id": action.ability.id
					}
					
					if action.ability.id == &"knight_chain_hook" and actor.is_ability_upgraded(&"knight_chain_hook"):
						pending["vulnerable_on_adjacent"] = true
						
					board.pending_pushes.append(pending)
		GameEnums.EffectType.SWAP:
			if target != null:
				PhysicsSystem.swap(board, actor, target, events)
		GameEnums.EffectType.HEAL:
			if target != null:
				var heal_amount := effect.amount
				if action.ability.scaling_stat == GameEnums.StatType.MAGICAL:
					var wpn := 0
					if actor.definition != null and actor.definition.equipped_weapon != null:
						wpn = actor.definition.equipped_weapon.might
					var raw = (effect.amount + wpn) * (1.0 + actor.current_magic / 5.0) * 0.20 + (target.health.max_hp * 0.20)
					heal_amount = floori(raw)
				elif effect.scaling_stat == GameEnums.StatType.MAX_HP:
					var raw = effect.amount * 0.1 * target.health.max_hp
					heal_amount = floori(raw)
				CombatSystem.heal(board, target, heal_amount, events)
		GameEnums.EffectType.ARMOR_UP:
			if target != null:
				var shield_amount = effect.amount
				if effect.scaling_stat == GameEnums.StatType.MAX_HP:
					shield_amount = floori(effect.amount * 0.1 * target.health.max_hp)
				elif effect.scaling_stat == GameEnums.StatType.DEFENSE:
					shield_amount = floori(effect.amount + actor.current_defense)
				elif effect.scaling_stat == GameEnums.StatType.MISSING_HP:
					shield_amount = floori(effect.amount + (actor.health.max_hp - actor.health.current_hp))
				var old_armor = target.armor
				target.armor += shield_amount
				if target.armor > old_armor:
					events.append(SimEvent.make(GameEnums.SimEventType.UNIT_ARMORED, {
						"unit": target.id,
						"amount": shield_amount,
						"armor": target.armor,
					}))
		GameEnums.EffectType.EXPLODE:
			# AoE self-destruct: damage ALL adjacent units (friend and foe) + actor.
			var center := tile_coord
			events.append(SimEvent.make(GameEnums.SimEventType.UNIT_EXPLODED, {
				"actor": actor.id, "coord": center, "damage": effect.amount,
			}))
			for dir in GridSystem.DIRECTIONS:
				var adj := center + dir
				var adj_unit := board.get_unit_at(adj)
				if adj_unit != null and adj_unit.is_alive():
					var dmg_type = &"physical" if action.ability.scaling_stat == GameEnums.StatType.PHYSICAL else &"magical"
					CombatSystem.deal_damage(
						board, adj_unit, effect.amount, events, dmg_type, false, false, null,
						action.ability.display_name, effect.amount
					)
			# Self-destruct: kill the bomber.
			CombatSystem.deal_damage(
				board, actor, actor.health.current_hp, events, &"physical", false, false, null,
				action.ability.display_name, actor.health.current_hp
			)
		GameEnums.EffectType.RANGED_EXPLODE:
			# AoE explosion without self-destruct: damage target coordinate and all adjacent tiles.
			var center := tile_coord
			events.append(SimEvent.make(GameEnums.SimEventType.UNIT_EXPLODED, {
				"actor": actor.id, "coord": center, "damage": effect.amount,
			}))
			var target_unit := board.get_unit_at(center)
			var dmg_type = &"physical" if action.ability.scaling_stat == GameEnums.StatType.PHYSICAL else &"magical"
			if target_unit != null and target_unit.is_alive():
				CombatSystem.deal_damage(
					board, target_unit, effect.amount, events, dmg_type, false, false, null,
					action.ability.display_name, effect.amount
				)
			for dir in GridSystem.DIRECTIONS:
				var adj := center + dir
				var adj_unit := board.get_unit_at(adj)
				if adj_unit != null and adj_unit.is_alive():
					CombatSystem.deal_damage(
						board, adj_unit, effect.amount, events, dmg_type, false, false, null,
						action.ability.display_name, effect.amount
					)
		GameEnums.EffectType.SPAWN:
			var coord := tile_coord
			if effect.spawn_unit_id != &"":
				if GridSystem.is_occupied(board, coord) or not GridSystem.is_passable(board, coord):
					events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
						"actor": actor.id, "reason": "spawn_blocked",
					}))
					return
				var construct_def := DataLibrary.get_unit(effect.spawn_unit_id)
				if construct_def == null:
					events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
						"actor": actor.id, "reason": "unknown_spawn_id",
					}))
					return
				var construct_id := board.next_unit_id()
				var construct := UnitState.create(construct_id, construct_def, actor.team, coord)
				if construct_def.is_construct:
					var scaled_hp := floori(actor.health.max_hp * (construct_def.construct_scaling_percent / 100.0))
					construct.health.max_hp = maxi(1, scaled_hp)
					construct.health.current_hp = construct.health.max_hp
					construct.active_statuses.append(StatusData.new(GameEnums.StatusType.STURDY, 999, 0))
					construct._recalculate_stats()
				board.add_unit(construct)
				GridSystem.set_occupant(board, coord, construct_id)
				events.append(SimEvent.make(GameEnums.SimEventType.UNIT_SPAWNED, {
					"actor": actor.id,
					"unit": construct_id,
					"coord": coord,
				}))
			else:
				# Summoner: create a minion at target_coord from behavior.spawn_unit.
				if actor.definition == null or actor.definition.behavior == null:
					return
				var spawn_def := actor.definition.behavior.spawn_unit
				if spawn_def == null:
					return
				if not GridSystem.is_in_bounds(board, coord) or GridSystem.is_occupied(board, coord):
					return
				var cap := actor.definition.behavior.max_spawns
				if cap > 0 and board.count_living_by_definition(spawn_def) >= cap:
					return
				var new_id := board.next_unit_id()
				var spawned := UnitState.create(new_id, spawn_def, actor.team, coord)
				board.add_unit(spawned)
				GridSystem.set_occupant(board, coord, new_id)
				events.append(SimEvent.make(GameEnums.SimEventType.UNIT_SPAWNED, {
					"spawner": actor.id, "unit": new_id,
					"definition": spawn_def.id, "coord": coord,
				}))
		GameEnums.EffectType.ADD_STATUS:
			if target != null:
				if target.has_status(GameEnums.StatusType.INVULNERABLE) and GameEnums.is_debuff(effect.status_type):
					events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
						"actor": target.id, "reason": "status_prevented_by_invulnerable",
					}))
					return
					
				if target.is_boss() and GameEnums.is_debuff(effect.status_type) and effect.status_type in [GameEnums.StatusType.STUN, GameEnums.StatusType.ROOT, GameEnums.StatusType.SILENCE, GameEnums.StatusType.PACIFY, GameEnums.StatusType.FEAR, GameEnums.StatusType.CONFUSION, GameEnums.StatusType.POLYMORPH, GameEnums.StatusType.TAUNT]:
					events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
						"actor": target.id, "reason": "boss_immune_to_cc",
					}))
					return
					
				var stat_val = effect.amount
				if effect.scaling_stat == GameEnums.StatType.DEFENSE:
					stat_val = effect.amount + actor.current_defense
				var status := StatusData.new(effect.status_type, effect.status_duration, stat_val)
				target.active_statuses.append(status)
				target._recalculate_stats()
				events.append(SimEvent.make(GameEnums.SimEventType.STATUS_APPLIED, {
					"unit": target.id,
					"status_type": effect.status_type,
					"duration": effect.status_duration,
					"amount": effect.amount,
				}))
		GameEnums.EffectType.CLEANSE:
			if target != null:
				var new_statuses: Array[StatusData] = []
				for status in target.active_statuses:
					if not GameEnums.is_debuff(status.type):
						new_statuses.append(status)
				target.active_statuses = new_statuses
				target._recalculate_stats()
				events.append(SimEvent.make(GameEnums.SimEventType.STATUS_REMOVED, {
					"unit": target.id, "reason": "cleanse"
				}))
		GameEnums.EffectType.PURGE:
			if target != null:
				for i in range(target.active_statuses.size() - 1, -1, -1):
					if GameEnums.is_buff(target.active_statuses[i].type):
						var removed = target.active_statuses.pop_at(i)
						events.append(SimEvent.make(GameEnums.SimEventType.STATUS_REMOVED, {
							"unit": target.id, "status_type": removed.type
						}))
				target.armor = 0
				target._recalculate_stats()
		GameEnums.EffectType.DASH:
			var dir := PhysicsSystem.straight_line_dir(actor.position, action.target_coord)
			var dash_steps := PhysicsSystem.straight_line_distance(actor.position, action.target_coord)
			if dir != Vector2i.ZERO and dash_steps >= 1 and dash_steps <= effect.amount:
				var pending = {
					"type": "dash",
					"target_id": actor.id,
					"dir": dir,
					"amount": dash_steps,
					"actor_id": actor.id,
					"ability_id": action.ability.id
				}
				if action.ability.id == &"knight_bowling_charge":
					pending["trample_collision"] = true
					pending["pass_through_push"] = 1
					pending["caster_collision_immune"] = true
				if action.ability.id == &"knight_bowling_charge" and actor.is_ability_upgraded(&"knight_bowling_charge"):
					pending["bowling_upgrade"] = true
				if action.ability.id == &"knight_trampling_advance" and actor.is_ability_upgraded(&"knight_trampling_advance"):
					pending["trampling_upgrade"] = true
				board.pending_pushes.append(pending)
			# Dash collision logic moved to resolve_pending_pushes
			pass
		GameEnums.EffectType.DESTROY_OBSTACLE:
			if target != null and target.definition.is_construct:
				CombatSystem.deal_damage(
					board, target, target.health.current_hp, events, &"physical", false, false, null,
					action.ability.display_name, target.health.current_hp
				)
		GameEnums.EffectType.TELEPORT_CASTER:
			if not GridSystem.is_occupied(board, tile_coord) and not GridSystem.is_wall(board, tile_coord):
				GridSystem.set_occupant(board, actor.position, -1)
				actor.position = tile_coord
				GridSystem.set_occupant(board, actor.position, actor.id)
				events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
					"unit": actor.id, "to": actor.position
				}))
		GameEnums.EffectType.CHANGE_TERRAIN:
			# Amount parameter can be used to select terrain type, for now just hardcode cracked
			var terrain_id = &"cracked"
			var tile = board.get_tile(tile_coord)
			if tile != null:
				var new_def = DataLibrary.get_terrain(terrain_id)
				if new_def != null:
					tile.definition = new_def
					events.append(SimEvent.make(GameEnums.SimEventType.TERRAIN_CHANGED, {
						"coord": tile_coord, "terrain": terrain_id
					}))
		GameEnums.EffectType.REFUND_AP_ON_CC:
			if target != null:
				if target.has_status(GameEnums.StatusType.ROOT) or target.has_status(GameEnums.StatusType.STUN):
					actor.ability.points_left = mini(actor.definition.action_points, actor.ability.points_left + 1)

		GameEnums.EffectType.ADD_STATUS_SELF:
			if actor.has_status(GameEnums.StatusType.INVULNERABLE) and GameEnums.is_debuff(effect.status_type):
				events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
					"actor": actor.id, "reason": "status_prevented_by_invulnerable",
				}))
				return
			if effect.status_type == GameEnums.StatusType.RUNNING:
				_apply_running_boost(actor, events)
				return
			var status := StatusData.new(effect.status_type, effect.status_duration, effect.amount)
			actor.active_statuses.append(status)
			actor._recalculate_stats()
			events.append(SimEvent.make(GameEnums.SimEventType.STATUS_APPLIED, {
				"unit": actor.id,
				"status_type": effect.status_type,
				"duration": effect.status_duration,
				"amount": effect.amount,
			}))
		GameEnums.EffectType.DAMAGE_SELF:
			CombatSystem.deal_damage(
				board, actor, effect.amount, events, &"true", true, false, null,
				"%s (self)" % action.ability.display_name, effect.amount
			)

static func _apply_running_boost(actor: UnitState, events: Array[SimEvent]) -> void:
	if actor.has_status(GameEnums.StatusType.RUNNING):
		return
	var bonus: int = running_move_bonus(actor.movement.max_points)
	if bonus <= 0:
		return
	actor.movement.max_points += bonus
	actor.movement.points_left += bonus
	actor.active_statuses.append(StatusData.new(GameEnums.StatusType.RUNNING, 1, bonus))
	actor._recalculate_stats()
	events.append(SimEvent.make(GameEnums.SimEventType.STATUS_APPLIED, {
		"unit": actor.id,
		"status_type": GameEnums.StatusType.RUNNING,
		"duration": 1,
		"amount": bonus,
	}))


static func _resolve_target(board: BoardState, action: TimelineAction) -> UnitState:
	if action.target_unit_id >= 0:
		return board.get_unit_by_id(action.target_unit_id)
	return board.get_unit_at(action.target_coord)

static func _resolve_target_coord(board: BoardState, action: TimelineAction) -> Vector2i:
	if action.target_unit_id >= 0:
		var target = board.get_unit_by_id(action.target_unit_id)
		if target != null:
			return target.position
	return action.target_coord

## True when the attacker stands on the tile directly behind the target's facing.
static func _is_backstab(actor: UnitState, target: UnitState) -> bool:
	var behind := -PhysicsSystem.facing_to_vector(target.facing)
	return PhysicsSystem.cardinal_from_to(target.position, actor.position) == behind

static func resolve_pending_pushes(board: BoardState, events: Array[SimEvent]) -> void:
	var pending = board.pending_pushes.duplicate()
	board.pending_pushes.clear()
	
	for push in pending:
		var target = board.get_unit_by_id(push.target_id)
		var actor = board.get_unit_by_id(push.actor_id) if push.has("actor_id") else null
		var ability_id = push.ability_id
		var push_type = push.get("type", "push")
		
		if target == null or not target.is_alive():
			continue
			
		var push_ev_start = events.size()
		if push_type == "dash":
			PhysicsSystem.dash(
				board, target, push.dir, push.amount, events, actor, ability_id,
				int(push.get("pass_through_atk", 0)),
				int(push.get("pass_through_push", 0)),
				String(push.get("source_label", "")),
				push.get("trample_collision", false),
				push.get("caster_collision_immune", false),
			)
		else:
			PhysicsSystem.push(board, target, push.dir, push.amount, events, actor, ability_id)
		
		if push_type == "push" or push_type == "pull":
			if push.get("stun_on_collision", false):
				for i in range(push_ev_start, events.size()):
					var ev = events[i]
					if ev.type == GameEnums.SimEventType.COLLISION and ev.data.get("unit") == target.id:
						target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STUN, 1))
						target._recalculate_stats()
						break
			
			if push.get("vulnerable_on_adjacent", false) and actor != null:
				if GridSystem.manhattan(actor.position, target.position) == 1:
					target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.VULNERABLE, 1))
					target._recalculate_stats()
					
		elif push_type == "dash":
			if ability_id == &"knight_bowling_charge" and push.get("bowling_upgrade", false):
				for i in range(push_ev_start, events.size()):
					var ev = events[i]
					if ev.type != GameEnums.SimEventType.COLLISION:
						continue
					var pushed_id: int = ev.data.get("unit", -1)
					if pushed_id == -1 or not ev.data.has("against_unit"):
						continue
					var pushed_unit := board.get_unit_by_id(pushed_id)
					var chain_hit := board.get_unit_by_id(ev.data.get("against_unit"))
					if pushed_unit != null and chain_hit != null and chain_hit.team != target.team:
						var chain_dmg := CombatSystem.calculate_scaled_damage(
							target, 2, GameEnums.StatType.PHYSICAL, board
						)
						CombatSystem.deal_damage_raw(
							board, target, pushed_unit, chain_dmg, GameEnums.StatType.PHYSICAL, events, "Bowling Charge", 2
						)
						CombatSystem.deal_damage_raw(
							board, target, chain_hit, chain_dmg, GameEnums.StatType.PHYSICAL, events, "Bowling Charge", 2
						)
			elif ability_id == &"knight_trampling_advance":
				var traveled := 0
				var hit_unit_id := -1
				for i in range(push_ev_start, events.size()):
					var ev = events[i]
					if ev.type == GameEnums.SimEventType.UNIT_MOVED and ev.data.get("actor", ev.data.get("unit", -1)) == target.id:
						traveled = ev.data.get("steps", ev.data.get("distance", 0))
					elif ev.type == GameEnums.SimEventType.UNIT_PUSHED and ev.data.get("unit") == target.id:
						traveled = ev.data.get("distance", 0)
				for i in range(push_ev_start, events.size()):
					var ev = events[i]
					if ev.type == GameEnums.SimEventType.COLLISION and ev.data.get("unit") == target.id:
						if ev.data.has("against_unit"):
							hit_unit_id = ev.data.get("against_unit")
							break
				if hit_unit_id != -1:
					var target_hit = board.get_unit_by_id(hit_unit_id)
					if target_hit != null:
						var trample_dmg := CombatSystem.calculate_scaled_damage(
							target, 2, GameEnums.StatType.PHYSICAL, board
						)
						CombatSystem.deal_damage_raw(
							board, target, target_hit, trample_dmg, GameEnums.StatType.PHYSICAL, events, "Trampling Advance", 2
						)
						PhysicsSystem.push(board, target_hit, push.dir, 1, events, target)
						GridSystem.set_occupant(board, target.position, target.id)
				
				if push.get("trampling_upgrade", false) and traveled > 0:
					target.armor += traveled
					events.append(SimEvent.make(GameEnums.SimEventType.UNIT_ARMORED, {
						"unit": target.id,
						"amount": traveled,
						"armor": target.armor,
					}))
