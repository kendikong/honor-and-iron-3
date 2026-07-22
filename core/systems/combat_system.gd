# ==============================================================================
# 🛑 WARNING TO AI AGENTS (HONOR & IRON ARCHITECTURE STRICT RULES) 🛑
# ==============================================================================
# DO NOT BRANCH ON `ability.id` IN THIS FILE. EVER.
# 
# Abilities are DATA, not engine code modifications. You are strictly forbidden
# from writing things like `if target.is_ability_upgraded("knight_indomitable_will")`
# to inject mechanics. If an ability needs custom behavior, you MUST add a new 
# generic flag to `GameEnums.EffectType` or `GameEnums.StatusType`, assign it 
# in the factory, and check for THAT flag here.
# 
# VIOLATING THIS RULE WILL CAUSE THE AUTOMATED ARCHITECTURE TEST TO FAIL.
# ==============================================================================
class_name CombatSystem
extends RefCounted

## Purpose: Owns damage and death (and nothing else).
## Responsibilities: Apply damage to a unit, emit damage/death events, clear
##   occupancy on death. Other systems delegate damage here rather than touching
##   HP directly (single source of truth).
## Dependencies: BoardState, UnitState, GridSystem, SimEvent, GameEnums.
## Lifecycle: stateless; only static functions.

const COLLISION_FORCE_MULT: float = 0.75
const COLLISION_EXCESS_DIVISOR: int = 3
const COLLISION_RETALIATOR_BASE_BONUS: int = 2

static func collision_base(excess_push: int, base_bonus: int = 0) -> int:
	return 1 + floori(float(excess_push) / float(COLLISION_EXCESS_DIVISOR)) + base_bonus

static func collision_scaled_raw(pusher: UnitState, base: int, board: BoardState) -> int:
	assert(pusher != null, "Collision damage requires an instigating pusher")
	var wpn := 0
	if pusher.definition != null and pusher.definition.equipped_weapon != null:
		wpn = pusher.definition.equipped_weapon.might
	var str_val := get_dynamic_strength(board, pusher)
	return floori(COLLISION_FORCE_MULT * (base + wpn) * (1.0 + str_val / 5.0))

static func deal_collision_damage(
	board: BoardState,
	pusher: UnitState,
	victim: UnitState,
	push_distance: int,
	tiles_moved: int,
	events: Array[SimEvent],
	base_bonus: int = 0,
) -> void:
	assert(pusher != null, "Collision damage requires an instigating pusher")
	if victim == null or not victim.is_alive():
		return
	var excess := maxi(0, push_distance - tiles_moved)
	var base := collision_base(excess, base_bonus)
	var wpn := 0
	if pusher.definition != null and pusher.definition.equipped_weapon != null:
		wpn = pusher.definition.equipped_weapon.might
	var str_val := get_dynamic_strength(board, pusher)
	var mult_raw := COLLISION_FORCE_MULT * (base + wpn) * (1.0 + str_val / 5.0)
	
	# Apply generic collision damage modifiers from passives
	for passive: PassiveData in pusher.active_passives:
		if passive.modifiers.has("collision_add_def_pct"):
			var def_pct: float = passive.modifiers["collision_add_def_pct"]
			mult_raw += get_dynamic_defense(board, pusher) * def_pct
			
	var scaled := floori(mult_raw)
	var target_def := get_dynamic_defense(board, victim)
	var fort := 0
	var tile := board.get_tile(victim.position)
	if tile != null and tile.definition != null:
		fort = tile.definition.fortitude
	events.append(SimEvent.make(GameEnums.SimEventType.MATH_TELEMETRY, {
		"type": &"collision",
		"base": base,
		"base_bonus": base_bonus,
		"excess_push": excess,
		"push_distance": push_distance,
		"tiles_moved": tiles_moved,
		"wpn": wpn,
		"stat_name": "STR",
		"stat_val": str_val,
		"multiplier_raw": mult_raw,
		"floored": scaled,
		"final_raw": scaled,
		"target_def": target_def,
		"fortitude": fort,
		"pusher_id": pusher.id,
	}))
	deal_damage(board, victim, scaled, events, &"collision", false, false, pusher, _collision_source_label(pusher))
	
	# Apply generic collision side-effect modifiers from passives
	for passive: PassiveData in pusher.active_passives:
		var is_upgraded := pusher.is_passive_upgraded(passive.id)
		
		# Target status debuffs
		var apply_status = -1
		var status_amount = 1
		if is_upgraded and passive.modifiers.has("collision_apply_target_status_upgraded"):
			apply_status = passive.modifiers["collision_apply_target_status_upgraded"]
			if passive.modifiers.has("collision_apply_target_status_upgraded_amount"):
				status_amount = passive.modifiers["collision_apply_target_status_upgraded_amount"]
		elif passive.modifiers.has("collision_apply_target_status"):
			apply_status = passive.modifiers["collision_apply_target_status"]
			if passive.modifiers.has("collision_apply_target_status_amount"):
				status_amount = passive.modifiers["collision_apply_target_status_amount"]
			
		if apply_status >= 0:
			victim.active_statuses.append(DataLibrary.make_status(apply_status, 1, status_amount))
			victim._recalculate_stats()
			
		# Shield granting
		if passive.modifiers.has("collision_grant_shield_str_def"):
			var shield_amt := str_val + get_dynamic_defense(board, pusher)
			add_armor(board, pusher, shield_amt, events)
			
		# Movement refund
		if is_upgraded and passive.modifiers.has("collision_refund_mov_if_upgraded"):
			var has_refunded: bool = pusher.passive_flags.get("collision_refunded_this_turn", false)
			if not has_refunded:
				pusher.passive_flags["collision_refunded_this_turn"] = true
				pusher.movement.points_left += 1

static func get_dynamic_defense(board: BoardState, unit: UnitState) -> int:
	if unit == null: return 0
	var def = unit.current_defense
	var adjacent_units = 0
	var has_shield_wall_ally = false
	
	if board != null:
		for dir in GridSystem.DIRECTIONS:
			var adj = unit.position + dir
			var tile = board.get_tile(adj)
			if tile != null and not tile.is_empty():
				var occ = board.get_unit_by_id(tile.occupant_id)
				if occ != null and occ.is_alive():
					adjacent_units += 1
					if occ.team == unit.team and occ.has_passive(&"shield_wall"):
						has_shield_wall_ally = true
						
		# Shield Wall Range 2 check
		if not has_shield_wall_ally:
			for x in range(-2, 3):
				for y in range(-2, 3):
					if abs(x) + abs(y) == 2:
						var adj = unit.position + Vector2i(x, y)
						var tile = board.get_tile(adj)
						if tile != null and not tile.is_empty():
							var occ = board.get_unit_by_id(tile.occupant_id)
							if occ != null and occ.is_alive() and occ.team == unit.team and occ.has_passive(&"shield_wall") and occ.is_passive_upgraded(&"shield_wall"):
								has_shield_wall_ally = true
								break
				if has_shield_wall_ally: break
				
		# Living Barricade Upgrade Check (+1 DEF for ally behind)
		for dir in GridSystem.DIRECTIONS:
			var front_tile = unit.position + dir
			var knight = board.get_unit_at(front_tile)
			if knight != null and knight.team == unit.team and knight.has_passive(&"living_barricade") and knight.is_passive_upgraded(&"living_barricade"):
				# If we are directly behind the knight relative to some direction, wait, the rule says "Allies directly behind you". This usually applies if the enemy is attacking, but a flat +1 DEF aura behind them is easier to calculate if we assume the knight's facing determines "behind".
				if PhysicsSystem.facing_to_vector(knight.facing) == dir:
					def += 1
					break
	
	if unit.has_passive(&"bulwark"):
		var bonus = adjacent_units
		def += bonus
		
	if has_shield_wall_ally:
		def += 1
		
	if unit.has_status(GameEnums.StatusType.IRON_GRIP_DEBUFF):
		def = ceili(def / 2.0)
		
	return def

static func get_dynamic_strength(board: BoardState, unit: UnitState) -> int:
	if unit == null: return 0
	var str_val = unit.current_strength
	
	if board != null and unit.has_passive(&"bulwark") and unit.is_passive_upgraded(&"bulwark"):
		var adj_enemies = 0
		for dir in GridSystem.DIRECTIONS:
			var adj = unit.position + dir
			var tile = board.get_tile(adj)
			if tile != null and not tile.is_empty():
				var occ = board.get_unit_by_id(tile.occupant_id)
				if occ != null and occ.is_alive() and occ.team != unit.team:
					adj_enemies += 1
		str_val += adj_enemies
		
	return str_val

static func calculate_scaled_damage(attacker: UnitState, base_power: int, stat_type: GameEnums.StatType, board: BoardState = null) -> int:
	var wpn = 0
	if attacker.definition != null and attacker.definition.equipped_weapon != null:
		wpn = attacker.definition.equipped_weapon.might
	var stat_val = get_dynamic_strength(board, attacker) if stat_type == GameEnums.StatType.PHYSICAL else attacker.current_magic
	return floori((base_power + wpn) * (1.0 + stat_val / 5.0))

static func append_damage_telemetry(
	board: BoardState,
	attacker: UnitState,
	target: UnitState,
	base_power: int,
	stat_type: GameEnums.StatType,
	events: Array[SimEvent],
	final_raw: int,
	extras: Dictionary = {},
) -> void:
	if target == null:
		return
	var wpn := 0
	if attacker != null and attacker.definition != null and attacker.definition.equipped_weapon != null:
		wpn = attacker.definition.equipped_weapon.might
	var stat_name := "STR"
	var stat_val := 0
	if stat_type == GameEnums.StatType.MAGICAL:
		stat_name = "MAG"
		stat_val = attacker.current_magic if attacker != null else 0
	else:
		stat_val = get_dynamic_strength(board, attacker) if attacker != null else 0
	var mult_raw := (base_power + wpn) * (1.0 + stat_val / 5.0)
	var target_def := get_dynamic_defense(board, target)
	if stat_type == GameEnums.StatType.MAGICAL:
		target_def = target.current_magic
	var fort := 0
	var tile := board.get_tile(target.position)
	if tile != null and tile.definition != null:
		fort = tile.definition.fortitude
	var data: Dictionary = {
		"type": "damage",
		"base": base_power,
		"wpn": wpn,
		"stat_name": stat_name,
		"stat_val": stat_val,
		"multiplier_raw": mult_raw,
		"floored": floori(mult_raw),
		"final_raw": final_raw,
		"target_def": target_def,
		"fortitude": fort,
		"vulnerable": target.has_status(GameEnums.StatusType.VULNERABLE),
		"electrified": target.has_status(GameEnums.StatusType.ELECTRIFIED),
		"pierce": attacker.has_status(GameEnums.StatusType.PIERCE) if attacker != null else false,
	}
	for key in extras:
		data[key] = extras[key]
	events.append(SimEvent.make(GameEnums.SimEventType.MATH_TELEMETRY, data))

static func append_flat_damage_telemetry(
	board: BoardState,
	target: UnitState,
	amount: int,
	events: Array[SimEvent],
	pierce: bool = false,
) -> void:
	if target == null:
		return
	var target_def := get_dynamic_defense(board, target)
	var fort := 0
	var tile := board.get_tile(target.position)
	if tile != null and tile.definition != null:
		fort = tile.definition.fortitude
	events.append(SimEvent.make(GameEnums.SimEventType.MATH_TELEMETRY, {
		"type": "damage",
		"base": amount,
		"wpn": 0,
		"stat_name": "STR",
		"stat_val": 0,
		"multiplier_raw": float(amount),
		"floored": amount,
		"final_raw": amount,
		"target_def": target_def,
		"fortitude": fort,
		"vulnerable": target.has_status(GameEnums.StatusType.VULNERABLE),
		"electrified": target.has_status(GameEnums.StatusType.ELECTRIFIED),
		"pierce": pierce,
	}))

static func counter_attack(
	board: BoardState,
	defender: UnitState,
	attacker: UnitState,
	atk_power: int,
	events: Array[SimEvent],
	source_label: String = "Counter Attack",
) -> void:
	if defender == null or attacker == null or not defender.is_alive() or not attacker.is_alive():
		return
	if defender.team == attacker.team or atk_power <= 0:
		return
	events.append(SimEvent.make(GameEnums.SimEventType.COUNTER_ATTACK, {
		"actor": defender.id,
		"target_unit": attacker.id,
		"target_coord": attacker.position,
		"atk_power": atk_power,
		"source_label": source_label,
	}))
	var scaled := calculate_scaled_damage(defender, atk_power, GameEnums.StatType.PHYSICAL, board)
	deal_damage_raw(board, defender, attacker, scaled, GameEnums.StatType.PHYSICAL, events, source_label, atk_power)

static func _collision_source_label(pusher: UnitState) -> String:
	if pusher != null and pusher.definition != null:
		return "Collision (%s)" % pusher.definition.display_name
	return "Collision"

static func deal_damage_raw(
	board: BoardState,
	attacker: UnitState,
	target: UnitState,
	raw_amount: int,
	stat_type: GameEnums.StatType,
	events: Array[SimEvent],
	source_label: String = "",
	base_power: int = -1,
) -> void:
	if attacker != null and target != null and base_power >= 0:
		append_damage_telemetry(board, attacker, target, base_power, stat_type, events, raw_amount)
	var dmg_type = &"physical"
	if stat_type == GameEnums.StatType.MAGICAL:
		dmg_type = &"magical"
	var pierce = attacker.has_status(GameEnums.StatusType.PIERCE) if attacker != null else false
	deal_damage(board, target, raw_amount, events, dmg_type, pierce, false, attacker, source_label)

static func deal_damage(
	board: BoardState,
	target: UnitState,
	amount: int,
	events: Array[SimEvent],
	source_type: StringName = &"physical",
	pierce: bool = false,
	is_intercepted: bool = false,
	attacker: UnitState = null,
	source_label: String = "",
	telemetry_base: int = -1,
) -> void:
	if target == null:
		return
	if amount <= 0:
		events.append(SimEvent.make(GameEnums.SimEventType.UNIT_DAMAGED, {
			"unit": target.id,
			"amount": 0,
			"hp": target.health.current_hp if target.health != null else 0,
			"armor": target.armor,
			"hp_damaged": 0,
			"armor_damaged": 0,
			"damage_type": source_type,
			"source_label": source_label,
		}))
		return
		
	var was_alive := target.is_alive()
		
	if target.has_status(GameEnums.StatusType.INVULNERABLE):
		return
		
	if target.has_status(GameEnums.StatusType.ELECTRIFIED):
		amount += 1

	if telemetry_base >= 0:
		append_flat_damage_telemetry(board, target, telemetry_base, events, pierce or source_type == &"true")
		
	if not is_intercepted and source_type != &"hazard":
		for dir in GridSystem.DIRECTIONS:
			var adj = target.position + dir
			if GridSystem.is_in_bounds(board, adj):
				var adj_tile = board.get_tile(adj)
				if adj_tile != null and not adj_tile.is_empty() and adj_tile.occupant_id != target.id:
					var ally = board.get_unit_by_id(adj_tile.occupant_id)
					if ally != null and ally.is_alive() and ally.team == target.team and ally.has_status(GameEnums.StatusType.INTERCEPT):
						var is_upgraded = false
						for status in ally.active_statuses:
							if status.type == GameEnums.StatusType.INTERCEPT and status.value == 1:
								is_upgraded = true
								break
						
						var intercept_amount = floori(amount * 0.5)
						if intercept_amount > 0:
							amount -= intercept_amount
							if is_upgraded:
								ally.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_DEF, 1, 2))
								ally._recalculate_stats()
							CombatSystem.deal_damage(
								board, ally, intercept_amount, events, source_type, pierce, true, attacker, source_label, intercept_amount
							)
						break # Only one interceptor triggers

	var fort := 0
	var tile := board.get_tile(target.position)
	if tile != null and tile.definition != null:
		fort = tile.definition.fortitude
		
	var mitigation: int = CombatSystem.get_dynamic_defense(board, target)
	if source_type == &"magical":
		mitigation = target.current_magic
		
	if pierce:
		mitigation = 0
		fort = 0
		
	if source_type == &"hazard":
		mitigation = 0
		fort = 0
		
	if attacker != null and target.has_passive(&"shield_mastery"):
		var dir_to_attacker = PhysicsSystem.cardinal_from_to(target.position, attacker.position)
		if PhysicsSystem.facing_to_vector(target.facing) == dir_to_attacker:
			var shield_amt = 3 if target.is_passive_upgraded(&"shield_mastery") else 2
			target.armor += shield_amt

	if source_type != &"hazard" and target.has_passive(&"kinetic_armor") and target.armor > 0:
		amount -= 2 if target.is_passive_upgraded(&"kinetic_armor") else 1
		amount = maxi(0, amount)

	var incoming := maxi(0, amount - fort - mitigation)
	var mitigated_amount = amount - incoming
	if incoming <= 0:
		if mitigated_amount > 0 and target.has_passive(&"kinetic_redirection"):
			target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 1, 1))
		events.append(SimEvent.make(GameEnums.SimEventType.UNIT_DAMAGED, {
			"unit": target.id,
			"amount": 0,
			"hp": target.health.current_hp,
			"armor": target.armor,
			"hp_damaged": 0,
			"armor_damaged": 0,
			"damage_type": source_type,
			"source_label": source_label,
		}))
		return
		
	var old_armor = target.armor
	var armor_dmg := mini(target.armor, incoming)
	target.armor -= armor_dmg
	var hp_dmg := incoming - armor_dmg
	
	if old_armor > 0 and target.armor <= 0 and (target.has_status(GameEnums.StatusType.INDOMITABLE_WILL) or target.has_status(GameEnums.StatusType.INDOMITABLE_WILL_UPGRADED)):
		if target.has_status(GameEnums.StatusType.INDOMITABLE_WILL_UPGRADED):
			target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 99, 2))
		var to_remove = []
		for status in target.active_statuses:
			if status.type == GameEnums.StatusType.INDOMITABLE_WILL or status.type == GameEnums.StatusType.INDOMITABLE_WILL_UPGRADED:
				to_remove.append(status)
		for status in to_remove:
			target.active_statuses.erase(status)
		target._recalculate_stats()
	
	if hp_dmg > 0:
		target.health.current_hp = maxi(0, target.health.current_hp - hp_dmg)
		
		# Root and Pacify break instantly on damage
		var new_statuses: Array[StatusData] = []
		var removed_statuses = false
		for status in target.active_statuses:
			if status.type in [GameEnums.StatusType.ROOT, GameEnums.StatusType.PACIFY]:
				removed_statuses = true
				events.append(SimEvent.make(GameEnums.SimEventType.STATUS_REMOVED, {
					"unit": target.id, "reason": "damage_taken"
				}))
			else:
				new_statuses.append(status)
		if removed_statuses:
			target.active_statuses = new_statuses
			target._recalculate_stats()
		
	events.append(SimEvent.make(GameEnums.SimEventType.UNIT_DAMAGED, {
		"unit": target.id,
		"amount": incoming,
		"hp": target.health.current_hp,
		"armor": target.armor,
		"hp_damaged": hp_dmg,
		"armor_damaged": armor_dmg,
		"damage_type": source_type,
		"source_label": source_label,
	}))
	
	if hp_dmg + armor_dmg > 0:
		if mitigated_amount > 0 and target.has_passive(&"kinetic_redirection"):
			var stacks = target.passive_flags.get("kinetic_redirection_stacks", 0)
			if stacks < 3:
				target.passive_flags["kinetic_redirection_stacks"] = stacks + 1
				target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, -1, 1))
			
		if target.has_passive(&"kinetic_converter"):
			var str_buff = 2 if target.is_passive_upgraded(&"kinetic_converter") else 1
			target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 1, str_buff))
			target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_MOV, 1, 1))
				
		if target.has_passive(&"thorny_carapace") and attacker != null:
			if GridSystem.manhattan(target.position, attacker.position) == 1:
				var reflect_pct = 1.0 if target.is_passive_upgraded(&"thorny_carapace") else 0.5
				var reflect = maxi(1, floori((hp_dmg + armor_dmg) * reflect_pct))
				append_flat_damage_telemetry(board, attacker, reflect, events)
				deal_damage_raw(board, target, attacker, reflect, GameEnums.StatType.PHYSICAL, events, "Thorny Carapace")
				var push_dir = PhysicsSystem.cardinal_from_to(target.position, attacker.position)
				PhysicsSystem.push(board, attacker, push_dir, 1, events, target)
				
		if target.has_status(GameEnums.StatusType.THORNS) and attacker != null:
			if GridSystem.manhattan(target.position, attacker.position) == 1:
				var reflect_pct = 0
				for status in target.active_statuses:
					if status.type == GameEnums.StatusType.THORNS:
						reflect_pct = status.amount
						break
				var reflect = maxi(1, floori((hp_dmg + armor_dmg) * (reflect_pct / 100.0)))
				append_flat_damage_telemetry(board, attacker, reflect, events)
				deal_damage_raw(board, target, attacker, reflect, GameEnums.StatType.PHYSICAL, events, "Thorns")
				
		if target.has_status(GameEnums.StatusType.RETALIATION_PROTOCOL) and attacker != null:
			var has_infinite_range := target.has_status(GameEnums.StatusType.RETALIATION_INFINITE_RANGE)
			if has_infinite_range or GridSystem.manhattan(target.position, attacker.position) == 1:
				var retal_dmg := calculate_scaled_damage(target, 2, GameEnums.StatType.PHYSICAL, board)
				deal_damage_raw(board, target, attacker, retal_dmg, GameEnums.StatType.PHYSICAL, events, "Retaliation Protocol", 2)
				var is_upgraded = false
				for status in target.active_statuses:
					if status.type == GameEnums.StatusType.RETALIATION_PROTOCOL and status.amount == 1:
						is_upgraded = true
						break
				if is_upgraded:
					var push_dir = PhysicsSystem.cardinal_from_to(target.position, attacker.position)
					PhysicsSystem.push(board, attacker, push_dir, 1, events, target)

	if target.health.current_hp <= 0 and target.has_passive(&"indestructible_bastion") and not target.passive_flags.get("bastion_used", false):
		target.health.current_hp = 1
		target.armor += target.current_defense
		target.passive_flags["bastion_used"] = true
		if target.is_passive_upgraded(&"indestructible_bastion"):
			target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 99, 2))
			
	if was_alive and not target.is_alive():
		GridSystem.set_occupant(board, target.position, -1)
		events.append(SimEvent.make(GameEnums.SimEventType.UNIT_DIED, {
			"unit": target.id,
		}))

static func heal(board: BoardState, target: UnitState, amount: int, events: Array[SimEvent]) -> void:
	if target == null or not target.is_alive() or amount <= 0:
		return
		
	var final_amount = amount
	if target.has_status(GameEnums.StatusType.POISON):
		# "Healing received is reduced by 50% (rounded down)".
		# To make the outcome weaker for the caster (Weaker Rounding Rule), the final heal should be rounded down.
		final_amount = floori(amount * 0.5)
		if final_amount <= 0:
			return
		
	var old_hp := target.health.current_hp
	target.health.current_hp = mini(target.health.max_hp, target.health.current_hp + final_amount)
	if target.health.current_hp > old_hp:
		events.append(SimEvent.make(GameEnums.SimEventType.UNIT_HEALED, {
			"unit": target.id,
			"amount": target.health.current_hp - old_hp,
			"hp": target.health.current_hp,
		}))

static func add_armor(board: BoardState, target: UnitState, amount: int, events: Array[SimEvent]) -> void:
	if target == null or not target.is_alive() or amount <= 0:
		return
	if target.has_status(GameEnums.StatusType.VULNERABLE):
		return # Cannot gain SHIELD while vulnerable
	target.armor += amount
	events.append(SimEvent.make(GameEnums.SimEventType.UNIT_ARMORED, {
		"unit": target.id,
		"amount": amount,
		"armor": target.armor,
	}))

