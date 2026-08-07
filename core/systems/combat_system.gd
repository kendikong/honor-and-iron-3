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
			
	if pusher.has_passive(&"momentum_of_titan"):
		var pct = 0.20 if pusher.is_passive_upgraded(&"momentum_of_titan") else 0.10
		mult_raw += floori(pusher.health.max_hp * pct)
			
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
	
	if pusher.has_passive(&"momentum_transfer"):
		var heal_amt = 1
		heal(board, pusher, heal_amt, events)
		if pusher.is_passive_upgraded(&"momentum_transfer"):
			pusher.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 1, 1))
			pusher._recalculate_stats()
	
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
			if not try_resist_crowd_control(victim, apply_status, events):
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
						var adj_tile = board.get_tile(adj)
						if adj_tile != null and not adj_tile.is_empty():
							var occ = board.get_unit_by_id(adj_tile.occupant_id)
							if occ != null and occ.is_alive() and occ.team == unit.team and occ.has_passive(&"shield_wall") and occ.is_passive_upgraded(&"shield_wall"):
								has_shield_wall_ally = true
								break
				if has_shield_wall_ally: break
				
		# Living Barricade Upgrade Check (+1 DEF for ally behind)
		for dir in GridSystem.DIRECTIONS:
			var front_tile = unit.position + dir
			var knight = board.get_unit_at(front_tile)
			if knight != null and knight.team == unit.team and knight.has_passive(&"living_barricade") and knight.is_passive_upgraded(&"living_barricade"):
				if PhysicsSystem.facing_to_vector(knight.facing) == dir:
					def += 1
					break
	
		if unit.has_passive(&"last_stand") and unit.health.current_hp < unit.health.max_hp * 0.25:
			def += 3 if unit.is_passive_upgraded(&"last_stand") else 2
			
		if unit.has_passive(&"adrenaline_junkie") and unit.is_passive_upgraded(&"adrenaline_junkie"):
			var missing_pct = (unit.health.max_hp - unit.health.current_hp) / float(unit.health.max_hp)
			def += floori(missing_pct / 0.20)
		for passive: PassiveData in unit.active_passives:
			if (
				passive != null
				and passive.modifiers.has("moved_tiles_def_threshold")
				and unit.movement_points_spent_this_turn >= int(
					passive.modifiers["moved_tiles_def_threshold"]
				)
			):
				def += int(passive.modifiers.get("moved_tiles_def", 0))
		
	if unit.has_passive(&"bulwark"):
		var bonus = adjacent_units
		def += bonus
		
	if has_shield_wall_ally:
		def += 1
		
	if unit.has_status(GameEnums.StatusType.IRON_GRIP_DEBUFF):
		for status: StatusData in unit.active_statuses:
			if status.type == GameEnums.StatusType.IRON_GRIP_DEBUFF:
				# Bible: DEF halved on the target's next turn — not the cast turn.
				if status.ticks_remaining <= status.duration * 2:
					def = ceili(def / 2.0)
				break
		
	return def

static func count_enraged_debuff_hazard_sources(board: BoardState, unit: UnitState) -> int:
	if unit == null or not unit.has_passive(&"enraged"):
		return 0
	var count := 0
	var counted_types := {}
	for status in unit.active_statuses:
		if GameEnums.is_debuff(status.type) and not counted_types.has(status.type):
			counted_types[status.type] = true
			count += 1
	if board != null:
		var unit_tile := board.get_tile(unit.position)
		if unit_tile != null and unit_tile.definition != null and unit_tile.definition.id == &"trap":
			count += 1
	return count

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
		
	if unit.has_passive(&"adrenaline_junkie"):
		var missing_pct = (unit.health.max_hp - unit.health.current_hp) / float(unit.health.max_hp)
		str_val += floori(missing_pct / 0.10)
		
	if unit.has_passive(&"enraged"):
		str_val += count_enraged_debuff_hazard_sources(board, unit)
		
	if unit.has_passive(&"last_stand") and unit.health.current_hp < unit.health.max_hp * 0.25:
		str_val += 3 if unit.is_passive_upgraded(&"last_stand") else 2
		
	if unit.has_passive(&"colossal_mass"):
		var div = 10 if unit.is_passive_upgraded(&"colossal_mass") else 15
		str_val += floori(unit.health.max_hp / float(div))
		
	if board != null and unit.has_passive(&"crowd_breaker"):
		var adj_enemies = 0
		for dir in GridSystem.DIRECTIONS:
			var adj = unit.position + dir
			var adj_tile = board.get_tile(adj)
			if adj_tile != null and not adj_tile.is_empty():
				var occ = board.get_unit_by_id(adj_tile.occupant_id)
				if occ != null and occ.is_alive() and occ.team != unit.team:
					adj_enemies += 1
		str_val += adj_enemies
	for passive: PassiveData in unit.active_passives:
		if passive != null and passive.modifiers.has("straight_line_str_per_tile"):
			str_val += unit.continuous_straight_tiles_this_turn * int(
				passive.modifiers["straight_line_str_per_tile"]
			)
	str_val += int(unit.passive_flags.get("paired_strength_bonus", 0))
		
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
	if attacker != null and attacker.has_passive(&"thrill_of_pain") and attacker.passive_flags.get("thrill_active", false):
		attacker.passive_flags["thrill_active"] = false
		var bonus = 3 if attacker.is_passive_upgraded(&"thrill_of_pain") else 2
		if base_power >= 0:
			base_power += bonus
			raw_amount = calculate_scaled_damage(attacker, base_power, stat_type, board)
		if target != null:
			var dir := PhysicsSystem.cardinal_from_to(attacker.position, target.position)
			board.pending_pushes.append({
				"type": "push",
				"target_id": target.id,
				"dir": dir,
				"amount": 1,
				"actor_id": attacker.id,
				"ability_id": &"thrill_of_pain"
			})

	if attacker != null and target != null and base_power >= 0:
		append_damage_telemetry(board, attacker, target, base_power, stat_type, events, raw_amount)
	var dmg_type = &"physical"
	if stat_type == GameEnums.StatType.MAGICAL:
		dmg_type = &"magical"
	var pierce = attacker.has_status(GameEnums.StatusType.PIERCE) if attacker != null else false
	
	if attacker != null and attacker.passive_flags.has("breaching_dash_pierce"):
		pierce = true
		attacker.passive_flags.erase("breaching_dash_pierce")
	
	if attacker != null and target != null and attacker.has_passive(&"overwhelming_bulk"):
		if attacker.health.current_hp > target.health.max_hp:
			pierce = true
			if attacker.is_passive_upgraded(&"overwhelming_bulk"):
				var dir := PhysicsSystem.cardinal_from_to(attacker.position, target.position)
				board.pending_pushes.append({
					"type": "push",
					"target_id": target.id,
					"dir": dir,
					"amount": 1,
					"actor_id": attacker.id,
					"ability_id": &"overwhelming_bulk"
				})
				
	deal_damage(board, target, raw_amount, events, dmg_type, pierce, false, attacker, source_label)

static func _apply_kinetic_redirection_stack(target: UnitState) -> void:
	if target == null or not target.has_passive(&"kinetic_redirection"):
		return
	var stacks: int = int(target.passive_flags.get("kinetic_redirection_stacks", 0))
	if stacks >= 3:
		return
	target.passive_flags["kinetic_redirection_stacks"] = stacks + 1
	target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, -1, 1))

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
	if attacker != null and GridSystem.manhattan(target.position, attacker.position) > 1:
		for passive: PassiveData in target.active_passives:
			if (
				passive != null
				and passive.modifiers.has("moved_tiles_ranged_immunity")
				and target.movement_points_spent_this_turn >= int(
					passive.modifiers.get("moved_tiles_def_threshold", 0)
				)
			):
				events.append(SimEvent.make(GameEnums.SimEventType.UNIT_DAMAGED, {
					"unit": target.id,
					"amount": 0,
					"hp": target.health.current_hp,
					"armor": target.armor,
					"hp_damaged": 0,
					"armor_damaged": 0,
					"damage_type": source_type,
					"source_label": source_label,
					"ranged_immune": true,
				}))
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
		
	if (
		attacker != null
		and source_type == &"physical"
		and GridSystem.manhattan(target.position, attacker.position) == 1
		and target.has_status(GameEnums.StatusType.BRACED)
	):
		var brace_power := 2
		for status: StatusData in target.active_statuses:
			if status.type == GameEnums.StatusType.BRACED and status.value > 0:
				brace_power = status.value
				break
		for i: int in range(target.active_statuses.size() - 1, -1, -1):
			if target.active_statuses[i].type == GameEnums.StatusType.BRACED:
				target.active_statuses.remove_at(i)
		target._recalculate_stats()
		events.append(SimEvent.make(GameEnums.SimEventType.UNIT_DAMAGED, {
			"unit": target.id,
			"amount": 0,
			"hp": target.health.current_hp,
			"armor": target.armor,
			"hp_damaged": 0,
			"armor_damaged": 0,
			"damage_type": source_type,
			"source_label": source_label,
			"braced": true,
		}))
		counter_attack(board, target, attacker, brace_power, events, "Brace")
		if target.passive_flags.get("braced_attacker_stagger", false):
			if not try_resist_crowd_control(attacker, GameEnums.StatusType.STAGGER, events):
				attacker.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAGGER, 1))
				attacker._recalculate_stats()
			target.passive_flags.erase("braced_attacker_stagger")
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
							var intercept_str: int = int(ally.passive_flags.get("meat_shield_intercept_str", 0))
							if intercept_str > 0:
								ally.active_statuses.append(
									DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 1, intercept_str),
								)
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
	if attacker != null:
		mitigation = maxi(
			0,
			mitigation - int(attacker.passive_flags.get("attack_ignore_def", 0)),
		)
	if target.has_passive(&"scar_tissue"):
		var missing_hp = target.health.max_hp - target.health.current_hp
		var reduction = maxi(floori(target.health.max_hp / 20.0), floori(missing_hp / 20.0))
		if target.is_passive_upgraded(&"scar_tissue"):
			reduction += 1
		mitigation += reduction
		
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
		if (
			source_type != &"hazard"
			and mitigated_amount > 0
			and target.has_passive(&"kinetic_redirection")
		):
			_apply_kinetic_redirection_stack(target)
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

	if target.has_passive(&"thrill_of_pain"):
		target.passive_flags["thrill_active"] = true
		
	if attacker != null and (source_type == &"physical" or source_type == &"magical"):
		if attacker.has_passive(&"blood_for_blood") and attacker.passive_flags.get("damaged_last_turn", false):
			var wpn = 0
			if attacker.definition != null and attacker.definition.equipped_weapon != null:
				wpn = attacker.definition.equipped_weapon.might
			if wpn > 0:
				target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.BLEED, 1, wpn))
					
		if attacker.has_passive(&"crowd_breaker"):
			var splash = 2 if attacker.is_passive_upgraded(&"crowd_breaker") else 1
			for dir in GridSystem.DIRECTIONS:
				var adj = target.position + dir
				var adj_tile = board.get_tile(adj)
				if adj_tile != null and not adj_tile.is_empty() and adj_tile.occupant_id != target.id:
					var adj_unit = board.get_unit_by_id(adj_tile.occupant_id)
					if adj_unit != null and adj_unit.is_alive():
						deal_damage(board, adj_unit, splash, events, &"true", true, true, attacker, "Splash Damage")
	
	if hp_dmg + armor_dmg > 0:
		target.passive_flags["damaged_this_turn"] = true
		if (
			source_type != &"hazard"
			and target.has_passive(&"kinetic_redirection")
			and (mitigated_amount > 0 or armor_dmg > 0)
		):
			_apply_kinetic_redirection_stack(target)
			
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
				
		if (
			target.has_status(GameEnums.StatusType.RETALIATION_PROTOCOL)
			and attacker != null
			and not attacker.passive_flags.get("suppress_melee_counter", false)
		):
			var has_infinite_range := target.has_status(GameEnums.StatusType.RETALIATION_INFINITE_RANGE)
			if has_infinite_range or GridSystem.manhattan(target.position, attacker.position) == 1:
				var retal_dmg := calculate_scaled_damage(target, 2, GameEnums.StatType.PHYSICAL, board)
				deal_damage_raw(board, target, attacker, retal_dmg, GameEnums.StatType.PHYSICAL, events, "Retaliation Protocol", 2)
				if target.is_ability_upgraded(&"knight_retaliation_protocol"):
					var push_dir = PhysicsSystem.cardinal_from_to(target.position, attacker.position)
					PhysicsSystem.push(board, attacker, push_dir, 1, events, target)

	if target.health.current_hp <= 0 and target.has_passive(&"indestructible_bastion") and not target.passive_flags.get("bastion_used", false):
		target.health.current_hp = 1
		target.armor += target.current_defense
		target.passive_flags["bastion_used"] = true
		if target.is_passive_upgraded(&"indestructible_bastion"):
			target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 99, 2))
			
	if was_alive and not target.is_alive():
		if attacker != null and attacker.is_alive():
			for passive: PassiveData in attacker.active_passives:
				if passive != null and passive.modifiers.has("kill_vault"):
					attacker.passive_flags["springboard_pending_coord"] = target.position
					break
		GridSystem.set_occupant(board, target.position, -1)
		events.append(SimEvent.make(GameEnums.SimEventType.UNIT_DIED, {
			"unit": target.id,
		}))
		
		if attacker != null and attacker.is_alive():
			if attacker.passive_flags.has("adrenaline_surge_active"):
				heal(board, attacker, 1, events)
				add_armor(board, attacker, 2, events)
			if attacker.passive_flags.has("on_kill_max_move"):
				var move_bonus: int = int(attacker.passive_flags["on_kill_max_move"])
				attacker.movement.max_points += move_bonus
				attacker.movement.points_left += move_bonus
				attacker.passive_flags.erase("on_kill_max_move")
			if attacker.passive_flags.has("paired_ally_id"):
				var paired_ally := board.get_unit_by_id(
					int(attacker.passive_flags["paired_ally_id"])
				)
				if paired_ally != null and paired_ally.is_alive():
					paired_ally.ability.points_left += 1
					attacker.ability.points_left += 1
				attacker.passive_flags.erase("paired_ally_id")
				attacker.passive_flags.erase("paired_strength_bonus")
			if attacker.passive_flags.get("frenzy_on_kill_ap", false) and source_label == "Frenzy":
				attacker.ability.points_left += 1

## Bible Unstoppable Force: immune to STAGGER/ROOT; resisting grants SHIELD 1 ([+] 2).
## Returns true if status was prevented (caller must not apply it).
static func try_resist_crowd_control(
	target: UnitState,
	status_type: int,
	events: Array[SimEvent],
) -> bool:
	if target == null or not target.is_alive():
		return false
	if (
		status_type == GameEnums.StatusType.ROOT
		and target.passive_flags.get("root_immune_this_turn", false)
	):
		return true
	if not target.has_passive(&"unstoppable_force"):
		return false
	if status_type != GameEnums.StatusType.STAGGER and status_type != GameEnums.StatusType.ROOT:
		return false
	var shield: int = 2 if target.is_passive_upgraded(&"unstoppable_force") else 1
	target.armor += shield
	events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
		"actor": target.id,
		"reason": "status_prevented_by_unstoppable_force",
	}))
	return true


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

