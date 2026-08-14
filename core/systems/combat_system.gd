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

const MercenarySystems := preload("res://core/systems/mercenary_systems.gd")
const MonkSystems := preload("res://core/systems/monk_systems.gd")
const ShamanSystems := preload("res://core/systems/shaman_systems.gd")
const RogueSystems := preload("res://core/systems/rogue_systems.gd")
const BeastRiderSystems := preload("res://core/systems/beast_rider_systems.gd")
const EngineerSystems := preload("res://core/systems/engineer_systems.gd")

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
	if victim.has_passive(&"collision_retaliator"):
		if victim.is_passive_upgraded(&"collision_retaliator"):
			add_armor(board, victim, 2, events)
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
		
		# Target status debuffs — base and upgrade both apply when both keys exist.
		if passive.modifiers.has("collision_apply_target_status"):
			var base_status: int = int(passive.modifiers["collision_apply_target_status"])
			var base_amount: int = 1
			if passive.modifiers.has("collision_def_loss_wpn"):
				base_amount = wpn
			elif passive.modifiers.has("collision_apply_target_status_amount"):
				base_amount = int(passive.modifiers["collision_apply_target_status_amount"])
			if not try_resist_crowd_control(victim, base_status, events, board, pusher):
				victim.active_statuses.append(DataLibrary.make_status(base_status, 1, base_amount))
				victim._recalculate_stats()
		if is_upgraded and passive.modifiers.has("collision_apply_target_status_upgraded"):
			var upgraded_status: int = int(passive.modifiers["collision_apply_target_status_upgraded"])
			var upgraded_amount: int = 1
			if passive.modifiers.has("collision_apply_target_status_upgraded_amount"):
				upgraded_amount = int(passive.modifiers["collision_apply_target_status_upgraded_amount"])
			if not try_resist_crowd_control(victim, upgraded_status, events, board, pusher):
				victim.active_statuses.append(DataLibrary.make_status(upgraded_status, 1, upgraded_amount))
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
			def += mini(3, floori(missing_pct / 0.25))
		for passive: PassiveData in unit.active_passives:
			if (
				passive != null
				and passive.modifiers.has("moved_tiles_def_threshold")
				and unit.movement_points_spent_this_turn >= int(
					passive.modifiers["moved_tiles_def_threshold"]
				)
			):
				def += int(passive.modifiers.get("moved_tiles_def", 0))
		var engineer_def_pct := float(unit.passive_flags.get("engineer_target_def_pct", 0.0))
		if engineer_def_pct > 0.0:
			def = floori(def * (1.0 - engineer_def_pct))
		for dir: Vector2i in GridSystem.DIRECTIONS:
			var adjacent := board.get_unit_at(unit.position + dir)
			if (
				adjacent != null
				and adjacent.is_alive()
				and adjacent.team == unit.team
				and adjacent.definition != null
				and adjacent.definition.is_construct
				and int(adjacent.passive_flags.get("engineer_owner_id", -1)) >= 0
			):
				var owner := board.get_unit_by_id(
					int(adjacent.passive_flags.get("engineer_owner_id", -1))
				)
				if owner != null and owner.team == unit.team and owner.has_passive(&"shield_generator"):
					def += 1
					break
		
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
		str_val += mini(3, floori(missing_pct / 0.25))
		
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
	if stat_type == GameEnums.StatType.MAGICAL and target != null:
		target_def = floori(
			(get_dynamic_defense(board, target) + target.current_magic) / 2.0
		)
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
	
	pierce = apply_attack_passive_modifiers(board, attacker, target, pierce)
	deal_damage(board, target, raw_amount, events, dmg_type, pierce, false, attacker, source_label)


static func apply_attack_passive_modifiers(
	board: BoardState,
	attacker: UnitState,
	target: UnitState,
	pierce: bool,
) -> bool:
	if attacker == null or target == null:
		return pierce
	for passive: PassiveData in attacker.active_passives:
		if (
			passive == null
			or not passive.modifiers.has("overwhelming_bulk")
			or attacker.health.current_hp <= target.health.max_hp
		):
			continue
		pierce = true
		break
	return pierce


static func apply_post_attack_push_passives(
	board: BoardState,
	attacker: UnitState,
	target: UnitState,
	events: Array[SimEvent],
	ability_id: StringName = &"",
) -> void:
	if attacker == null or target == null or not target.is_alive():
		return
	for passive: PassiveData in attacker.active_passives:
		if (
			passive == null
			or not passive.modifiers.has("overwhelming_bulk")
			or not attacker.is_passive_upgraded(passive.id)
			or attacker.health.current_hp <= target.health.max_hp
		):
			continue
		var push_dir := PhysicsSystem.cardinal_from_to(attacker.position, target.position)
		if push_dir == Vector2i.ZERO:
			return
		PhysicsSystem.push(
			board, target, push_dir, 1, events, attacker, ability_id,
		)
		break


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
	if (
		attacker != null
		and target == attacker
		and attacker.passive_flags.get("engineer_explosion_active", false)
		and EngineerSystems.has_passive_modifier(attacker, &"own_explosion_immunity")
	):
		return
	if (
		board != null
		and source_type == &"magical"
		and attacker != null
		and attacker.team != target.team
	):
		var lightning_rod := ShamanSystems.find_lightning_rod_redirect(board, target)
		if lightning_rod != null:
			target = lightning_rod
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
	amount += ShamanSystems.incoming_damage_bonus(target)
	amount = maxi(
		0,
		amount - ShamanSystems.incoming_damage_reduction(board, target, attacker),
	)
	amount = maxi(
		0,
		amount - BeastRiderSystems.incoming_damage_reduction(
			board, target, source_type, attacker,
		),
	)
	if (
		attacker != null
		and attacker.passive_flags.get("shaman_wither", false)
	):
		if attacker.is_boss():
			amount = floori(amount * 0.75)
		else:
			amount = floori(amount * 0.50)

	if telemetry_base >= 0:
		append_flat_damage_telemetry(board, target, telemetry_base, events, pierce or source_type == &"true")
		
	var life_link_source := board.get_unit_by_id(
		int(target.passive_flags.get("life_link_source_id", -1))
	)
	if (
		life_link_source != null
		and life_link_source.is_alive()
		and life_link_source.team == target.team
	):
		amount = maxi(
			0,
			amount - int(target.passive_flags.get("life_link_damage_reduction", 0)),
		)
	if (
		source_type == &"magical"
		and target.passive_flags.has("magic_chain_partner_id")
		and not target.passive_flags.get("magic_chain_processing", false)
	):
		var partner := board.get_unit_by_id(
			int(target.passive_flags["magic_chain_partner_id"])
		)
		if partner != null and partner.is_alive():
			target.passive_flags["magic_chain_processing"] = true
			partner.passive_flags["magic_chain_processing"] = true
			deal_damage(
				board,
				partner,
				1,
				events,
				&"magical",
				false,
				true,
				attacker,
				"Martyr's Chains",
				1,
			)
			if target.passive_flags.get("magic_chain_blind", false) and partner.is_alive():
				partner.active_statuses.append(DataLibrary.make_status(
					GameEnums.StatusType.BLIND,
					1,
				))
			target.passive_flags.erase("magic_chain_processing")
			partner.passive_flags.erase("magic_chain_processing")

	if not is_intercepted and source_type != &"hazard":
		for ally: UnitState in board.units:
			if ally == null or not ally.is_alive() or ally.id == target.id:
				continue
			if ally.team != target.team or not ally.has_status(GameEnums.StatusType.INTERCEPT):
				continue
			var ward_id: int = int(ally.passive_flags.get("intercept_ward_id", -1))
			var intercept_range: int = int(ally.passive_flags.get("intercept_range", 1))
			var dist: int = GridSystem.manhattan(ally.position, target.position)
			if ward_id >= 0:
				if target.id != ward_id or dist > maxi(1, intercept_range):
					continue
			elif dist != 1:
				continue
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
				if (
					ally.passive_flags.get("counterattack_on_intercept", false)
					and attacker != null
					and attacker.is_alive()
				):
					counter_attack(board, ally, attacker, 1, events, "Shield of Faith")
					ally.passive_flags.erase("counterattack_on_intercept")
			break

	var fort := 0
	var tile := board.get_tile(target.position)
	if tile != null and tile.definition != null:
		fort = tile.definition.fortitude
		
	var mitigation: int = CombatSystem.get_dynamic_defense(board, target)
	if (
		source_type == &"physical"
		and attacker != null
		and attacker.passive_flags.get("target_magic_defense_override", false)
	):
		mitigation = target.current_magic
	mitigation += MercenarySystems.marked_defense_bonus(target, attacker)
	if attacker != null:
		mitigation = maxi(
			0,
			mitigation - int(attacker.passive_flags.get("attack_ignore_def", 0)),
		)
	if target.has_passive(&"scar_tissue"):
		var missing_hp = target.health.max_hp - target.health.current_hp
		var scar_step := 15 if target.is_passive_upgraded(&"scar_tissue") else 20
		var reduction = maxi(floori(target.health.max_hp / float(scar_step)), floori(missing_hp / float(scar_step)))
		reduction = mini(reduction, floori(target.health.max_hp / 10.0))
		mitigation += reduction

	if (
		source_type == &"physical"
		and attacker != null
		and target.has_passive(&"collision_retaliator")
		and GridSystem.manhattan(target.position, attacker.position) <= 3
	):
		var attacker_vector := attacker.position - target.position
		var front_vector := PhysicsSystem.facing_to_vector(target.facing)
		if front_vector.x * attacker_vector.x + front_vector.y * attacker_vector.y > 0:
			var frontal_def := 2
			for passive: PassiveData in target.active_passives:
				if passive == null or not passive.modifiers.has("bastion_front_def"):
					continue
				frontal_def = int(passive.modifiers["bastion_front_def"])
				if target.is_passive_upgraded(passive.id):
					frontal_def = int(passive.modifiers.get("upgraded_bastion_front_def", frontal_def))
				break
			mitigation += frontal_def
		
	if source_type == &"magical":
		var target_magic := target.current_magic
		if attacker != null:
			target_magic = floori(
				target_magic
				* (1.0 - float(attacker.passive_flags.get("mage_target_magic_ignore_pct", 0.0)))
			)
		mitigation = floori(
			(get_dynamic_defense(board, target) + target_magic) / 2.0
		)
		
	if pierce:
		mitigation = 0
		fort = 0
		
	if source_type == &"hazard":
		mitigation = 0
		fort = 0
		
	if source_type != &"hazard" and target.has_passive(&"kinetic_armor") and target.armor > 0:
		var kinetic_def := target.current_defense
		var kinetic_reduce := floori(kinetic_def / 2.0)
		if target.is_passive_upgraded(&"kinetic_armor"):
			kinetic_reduce = floori((kinetic_def + 2) / 2.0)
		amount -= kinetic_reduce
		amount = maxi(0, amount)

	var incoming := maxi(0, amount - fort - mitigation)
	var mitigated_amount = amount - incoming
	var phalanx_passive: PassiveData = null
	for passive: PassiveData in target.active_passives:
		if passive != null and passive.modifiers.has("phalanx_deflection"):
			phalanx_passive = passive
			break
	if (
		source_type == &"physical"
		and attacker != null
		and phalanx_passive != null
		and GridSystem.manhattan(target.position, attacker.position) <= 3
	):
		var attacker_vector := attacker.position - target.position
		var front_vector := PhysicsSystem.facing_to_vector(target.facing)
		if front_vector.x * attacker_vector.x + front_vector.y * attacker_vector.y > 0:
			var energy_cap_multiplier := int(
				phalanx_passive.modifiers.get("kinetic_energy_cap_def_multiplier", 2)
			)
			if target.is_passive_upgraded(phalanx_passive.id):
				energy_cap_multiplier = int(
					phalanx_passive.modifiers.get(
						"upgraded_kinetic_energy_cap_def_multiplier",
						energy_cap_multiplier,
					)
				)
			var energy_cap := target.current_defense * energy_cap_multiplier
			var energy_gain := floori(mitigated_amount * 0.5)
			target.passive_flags["kinetic_energy"] = mini(
				energy_cap,
				int(target.passive_flags.get("kinetic_energy", 0)) + energy_gain,
			)
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
	var shieldable := incoming
	if source_type == &"physical":
		for passive: PassiveData in target.active_passives:
			if passive == null or not passive.modifiers.has("arcane_overdrive_shield_bypass"):
				continue
			shieldable = floori(
				incoming * (1.0 - float(passive.modifiers["arcane_overdrive_shield_bypass"]))
			)
			break
	var armor_dmg := mini(target.armor, shieldable)
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
	
	var was_full_hp := target.health.current_hp >= target.health.max_hp
	if hp_dmg > 0:
		target.passive_flags["exact_lethal_damage"] = hp_dmg == target.health.current_hp
		target.health.current_hp = maxi(0, target.health.current_hp - hp_dmg)
		
		# Root and Pacify break instantly on damage. WEAKEN breaks on direct hits but
		# persists through DoT/hazard (Mantra of Peace and global DoT/hazard rule).
		var dot_or_hazard := source_type in [&"hazard", &"bleed", &"burn", &"poison"]
		var new_statuses: Array[StatusData] = []
		var removed_statuses = false
		for status in target.active_statuses:
			if status.type in [GameEnums.StatusType.ROOT, GameEnums.StatusType.PACIFY]:
				removed_statuses = true
				events.append(SimEvent.make(GameEnums.SimEventType.STATUS_REMOVED, {
					"unit": target.id, "reason": "damage_taken"
				}))
			elif status.type == GameEnums.StatusType.WEAKEN and not dot_or_hazard:
				removed_statuses = true
				events.append(SimEvent.make(GameEnums.SimEventType.STATUS_REMOVED, {
					"unit": target.id, "reason": "damage_taken", "status": "weaken"
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
	EngineerSystems.after_damage(board, target, old_armor, events)
	_apply_cleric_damage_reactions(board, target, attacker, source_type, events)
	_apply_generic_damage_passives(board, target, attacker, source_type, events)

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
		if attacker != null:
			target.passive_flags["last_attacker_id"] = attacker.id
			MercenarySystems.on_dealt_damage(
				board,
				attacker,
				target,
				events,
				MercenarySystems._is_basic_attack(
					attacker.passive_flags.get("__current_ability", null) as AbilityData,
				),
				was_full_hp,
			)
			MonkSystems.on_dealt_damage(board, attacker, target, events)
			RogueSystems.on_dealt_damage(board, attacker, target, events)
			BeastRiderSystems.on_attack_hit(board, attacker, target, events)
			RogueSystems.on_attack_hit(board, attacker, target, events)
			var shaman_ability := attacker.passive_flags.get("__current_ability", null) as AbilityData
			var shaman_action := TimelineAction.new()
			shaman_action.actor_id = attacker.id
			shaman_action.ability = shaman_ability
			var shaman_effect := DataLibrary._effect(GameEnums.EffectType.DAMAGE, 0)
			if shaman_ability != null:
				for module: AbilityModule in shaman_ability.get_active_modules(
					attacker.is_ability_upgraded(shaman_ability.id)
				):
					if module != null:
						shaman_effect.modifiers.merge(module.legacy_modifiers)
			ShamanSystems.on_dealt_damage(
				board, attacker, target, shaman_action, shaman_effect, events, source_type,
			)
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

	if target.health.current_hp <= 0:
		for rescuer: UnitState in board.units:
			if (
				rescuer == null
				or not rescuer.is_alive()
				or rescuer.team != target.team
				or rescuer.id == target.id
				or rescuer.passive_flags.get("divine_intervention_used", false)
			):
				continue
			var save_passive: PassiveData = null
			for passive: PassiveData in rescuer.active_passives:
				if passive != null and passive.modifiers.has("lethal_ally_save"):
					save_passive = passive
					break
			if save_passive == null:
				continue
			var rescue_cell := Vector2i(-1, -1)
			for direction: Vector2i in GridSystem.DIRECTIONS:
				var candidate := rescuer.position + direction
				if GridSystem.is_passable(board, candidate) and not GridSystem.is_occupied(board, candidate):
					rescue_cell = candidate
					break
			if rescue_cell == Vector2i(-1, -1):
				continue
			GridSystem.set_occupant(board, target.position, -1)
			target.position = rescue_cell
			GridSystem.set_occupant(board, rescue_cell, target.id)
			target.health.current_hp = 1
			rescuer.passive_flags["divine_intervention_used"] = true
			if rescuer.is_passive_upgraded(save_passive.id):
				target.armor += int(save_passive.modifiers.get("upgraded_lethal_ally_shield", 0))
			events.append(SimEvent.make(GameEnums.SimEventType.UNIT_HEALED, {
				"unit": target.id, "amount": 1, "divine_intervention": true,
			}))
			break
			
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
		EngineerSystems.on_construct_destroyed(board, target, events)
		EngineerSystems.on_kill(board, attacker, target, events)
		
		if attacker != null and attacker.is_alive():
			MercenarySystems.on_kill(
				board,
				attacker,
				target,
				events,
				source_label,
				MercenarySystems._is_basic_attack(
					attacker.passive_flags.get("__current_ability", null) as AbilityData,
				),
			)
			ShamanSystems.on_kill(board, attacker, target, events)
			RogueSystems.on_kill(board, attacker, target, events)
			BeastRiderSystems.on_kill(board, attacker, target, events)
			if attacker.passive_flags.get("mage_spell_in_progress", false):
				for passive: PassiveData in attacker.active_passives:
					if passive == null or not passive.modifiers.has("mana_siphon"):
						continue
					if not attacker.passive_flags.get("mage_ap_refunded", false):
						attacker.ability.points_left = mini(
							attacker.ability.max_points,
							attacker.ability.points_left + 1,
						)
						attacker.passive_flags["mage_ap_refunded"] = true
					else:
						heal(board, attacker, attacker.current_magic, events)
						var max_stacks := int(passive.modifiers.get("arcane_overchannel_max", 3))
						attacker.passive_flags["arcane_overchannel_stacks"] = mini(
							max_stacks,
							int(attacker.passive_flags.get("arcane_overchannel_stacks", 0)) + 1,
						)
					if attacker.is_passive_upgraded(passive.id):
						heal(
							board,
							attacker,
							int(passive.modifiers.get("mana_siphon_heal", 1)),
							events,
						)
					break
			if attacker.passive_flags.get("destroy_corpse_on_kill", false):
				target.passive_flags["corpse_destroyed"] = true
			if (
				attacker.passive_flags.has("kill_grant_ap")
				and not attacker.passive_flags.get("mage_ap_refunded", false)
			):
				attacker.ability.points_left = mini(
					attacker.ability.max_points,
					attacker.ability.points_left + int(attacker.passive_flags["kill_grant_ap"]),
				)
				attacker.passive_flags["mage_ap_refunded"] = true
			if target.passive_flags.get("exact_lethal_damage", false):
				for passive: PassiveData in attacker.active_passives:
					if passive == null or not passive.modifiers.has("exact_lethal_followup_damage"):
						continue
					var followup_power := int(passive.modifiers["exact_lethal_followup_damage"])
					if attacker.is_passive_upgraded(passive.id):
						followup_power = int(
							passive.modifiers.get(
								"upgraded_exact_lethal_followup_damage",
								followup_power,
							)
						)
					var nearest: UnitState = null
					var nearest_distance := 1_000_000
					for candidate: UnitState in board.units:
						if (
							candidate == null
							or not candidate.is_alive()
							or candidate.team == attacker.team
							or candidate.id == target.id
						):
							continue
						var candidate_distance := GridSystem.manhattan(target.position, candidate.position)
						if candidate_distance < nearest_distance:
							nearest = candidate
							nearest_distance = candidate_distance
					if nearest != null:
						var followup_raw := calculate_scaled_damage(
							attacker, followup_power, GameEnums.StatType.PHYSICAL, board,
						)
						deal_damage(
							board, nearest, followup_raw, events, &"physical",
							false, false, attacker, "Barrage", followup_raw,
						)
					break
			target.passive_flags.erase("exact_lethal_damage")
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
	board: BoardState = null,
	source: UnitState = null,
) -> bool:
	if target == null or not target.is_alive():
		return false
	if (
		status_type == GameEnums.StatusType.ROOT
		and target.passive_flags.get("root_immune_this_turn", false)
	):
		return true
	if target.is_boss() and _is_hard_crowd_control(status_type):
		_apply_boss_hard_cc_fallback(board, source, target, status_type, events)
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


static func _is_hard_crowd_control(status_type: int) -> bool:
	return status_type in [
		GameEnums.StatusType.STAGGER,
		GameEnums.StatusType.ROOT,
		GameEnums.StatusType.SILENCE,
		GameEnums.StatusType.PACIFY,
		GameEnums.StatusType.FEAR,
		GameEnums.StatusType.CONFUSION,
		GameEnums.StatusType.POLYMORPH,
		GameEnums.StatusType.TAUNT,
	]


static func _apply_boss_hard_cc_fallback(
	board: BoardState,
	source: UnitState,
	target: UnitState,
	status_type: int,
	events: Array[SimEvent],
) -> void:
	if target == null:
		return
	events.append(SimEvent.make(GameEnums.SimEventType.ACTION_FAILED, {
		"actor": target.id, "reason": "boss_immune_to_cc",
	}))
	match status_type:
		GameEnums.StatusType.STAGGER:
			var wpn := 0
			if source != null and source.definition != null and source.definition.equipped_weapon != null:
				wpn = source.definition.equipped_weapon.might
			if wpn > 0 and board != null:
				deal_damage(
					board, target, wpn, events, &"true", true, false, source,
					"Boss CC Fallback", wpn,
				)
		GameEnums.StatusType.ROOT:
			target.active_statuses.append(
				DataLibrary.make_status(GameEnums.StatusType.STAT_DEBUFF_MOV, 1, 2),
			)
			target._recalculate_stats(board)
		GameEnums.StatusType.SILENCE:
			target.passive_flags["cannot_gain_shield"] = true
		GameEnums.StatusType.PACIFY:
			target.active_statuses.append(
				DataLibrary.make_status(GameEnums.StatusType.STAT_BUFF_STR, 1, -2),
			)
			target._recalculate_stats(board)
		GameEnums.StatusType.FEAR:
			if board != null and source != null:
				var away := PhysicsSystem.cardinal_from_to(source.position, target.position)
				if away != Vector2i.ZERO:
					PhysicsSystem.push(board, target, away, 2, events, source)
		GameEnums.StatusType.CONFUSION:
			target.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.BLIND, 1))
		_:
			pass


static func _apply_generic_damage_passives(
	board: BoardState,
	target: UnitState,
	attacker: UnitState,
	source_type: StringName,
	events: Array[SimEvent],
) -> void:
	if target == null or not target.is_alive():
		return
	for passive: PassiveData in target.active_passives:
		if passive == null or not passive.modifiers.has("mana_leak"):
			continue
		var pulse := int(passive.modifiers["mana_leak"])
		if target.is_passive_upgraded(passive.id):
			pulse = int(passive.modifiers.get("upgraded_mana_leak", pulse))
		for direction: Vector2i in GridSystem.DIRECTIONS:
			var adjacent := board.get_unit_at(target.position + direction)
			if adjacent == null or adjacent.team == target.team or not adjacent.is_alive():
				continue
			var raw := calculate_scaled_damage(
				target,
				pulse,
				GameEnums.StatType.MAGICAL,
				board,
			)
			deal_damage_raw(
				board,
				target,
				adjacent,
				raw,
				GameEnums.StatType.MAGICAL,
				events,
				"Mana Leak",
				pulse,
			)
		break


static func _apply_cleric_damage_reactions(
	board: BoardState,
	target: UnitState,
	attacker: UnitState,
	source_type: StringName,
	events: Array[SimEvent],
) -> void:
	if target == null or not target.is_alive():
		return
	if target.passive_flags.get("cleric_damage_reactions", false):
		return
	target.passive_flags["cleric_damage_reactions"] = true
	if (
		target.passive_flags.get("counterattack_melee", false)
		and attacker != null
		and attacker.is_alive()
		and GridSystem.manhattan(target.position, attacker.position) == 1
	):
		counter_attack(board, target, attacker, 1, events, "Prayer of Fortitude")
		target.passive_flags.erase("counterattack_melee")
	for passive: PassiveData in target.active_passives:
		if passive == null:
			continue
		if passive.modifiers.has("hit_adjacent_pulse"):
			var pulse := int(passive.modifiers["hit_adjacent_pulse"])
			if target.is_passive_upgraded(passive.id):
				pulse = int(passive.modifiers.get("upgraded_hit_adjacent_pulse", pulse))
			for direction: Vector2i in GridSystem.DIRECTIONS:
				var adjacent := board.get_unit_at(target.position + direction)
				if adjacent != null and adjacent.team != target.team:
					deal_damage(
						board,
						adjacent,
						pulse,
						events,
						&"magical",
						false,
						false,
						target,
						"Martyr's Blood",
						pulse,
					)
		if (
			attacker != null
			and attacker.team != target.team
			and passive.modifiers.has("melee_attacker_pulse")
			and GridSystem.manhattan(target.position, attacker.position) == 1
		):
			var pulse := int(passive.modifiers["melee_attacker_pulse"])
			var push_amount := int(passive.modifiers.get("melee_attacker_push", 0))
			if target.is_passive_upgraded(passive.id):
				push_amount = int(passive.modifiers.get("upgraded_melee_attacker_push", push_amount))
			deal_damage(board, attacker, pulse, events, &"magical", false, true, target, "Retribution", pulse)
			if push_amount > 0 and attacker.is_alive():
				PhysicsSystem.push(
					board,
					attacker,
					PhysicsSystem.cardinal_from_to(target.position, attacker.position),
					push_amount,
					events,
					target,
				)
	for source: UnitState in board.units:
		if (
			source == null
			or source.team != target.team
			or attacker == null
			or attacker.team == source.team
			or not source.is_alive()
			or GridSystem.manhattan(source.position, target.position)
				> int(_cleric_modifier(source, "ally_hit_retribution_range", 0))
		):
			continue
		for passive: PassiveData in source.active_passives:
			if passive == null or not passive.modifiers.has("ally_hit_retribution_range"):
				continue
			var retaliation := int(passive.modifiers.get("ally_hit_retribution_damage", 1))
			if source.is_passive_upgraded(passive.id):
				retaliation = int(passive.modifiers.get(
					"upgraded_ally_hit_retribution_damage",
					retaliation,
				))
			deal_damage(
				board,
				attacker,
				retaliation,
				events,
				&"magical",
				false,
				true,
				source,
				"Divine Retribution",
				retaliation,
			)
			break
	for source: UnitState in board.units:
		if (
			source == null
			or source.team != target.team
			or attacker == null
			or attacker.team == source.team
			or not source.is_alive()
		):
			continue
		for passive: PassiveData in source.active_passives:
			if passive == null or not passive.modifiers.has("ally_damaged_str"):
				continue
			target.active_statuses.append(DataLibrary.make_status(
				GameEnums.StatusType.STAT_BUFF_STR,
				1,
				int(passive.modifiers["ally_damaged_str"]),
			))
			if source.is_passive_upgraded(passive.id):
				target.active_statuses.append(DataLibrary.make_status(
					GameEnums.StatusType.STAT_BUFF_DEF,
					1,
					int(passive.modifiers.get("upgraded_ally_damaged_def", 0)),
				))
			break
	target._recalculate_stats(board)
	target.passive_flags.erase("cleric_damage_reactions")


static func _cleric_modifier(unit: UnitState, key: String, default_value: int) -> int:
	for passive: PassiveData in unit.active_passives:
		if passive != null and passive.modifiers.has(key):
			return int(passive.modifiers[key])
	return default_value


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
	if target.passive_flags.get("shield_blocked", false):
		return
	if target.passive_flags.get("cannot_gain_shield", false):
		return
	if not ShamanSystems.can_gain_shield(board, target):
		return
	if not RogueSystems.can_gain_shield(board, target):
		return
	if target.has_status(GameEnums.StatusType.VULNERABLE):
		return # Cannot gain SHIELD while vulnerable
	target.armor += amount
	events.append(SimEvent.make(GameEnums.SimEventType.UNIT_ARMORED, {
		"unit": target.id,
		"amount": amount,
		"armor": target.armor,
	}))

