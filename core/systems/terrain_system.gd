class_name TerrainSystem
extends RefCounted

const RogueSystems := preload("res://core/systems/rogue_systems.gd")

## Purpose: Owns tile-triggered terrain effects (and nothing else). This is the
## "Terrain" stage of the fixed resolution order; it runs the instant a unit lands
## on a tile, whether by walking or by being displaced.
## Responsibilities: When a unit ENTERS a tile, apply that tile's hazard (pit,
##   spikes) by delegating the actual HP change to CombatSystem (the damage owner).
## Dependencies: BoardState, UnitState, GridSystem, CombatSystem, SimEvent.
## Lifecycle: stateless; only static functions.

## Call right after a unit's position changes. No-ops on harmless tiles, so callers
## can invoke it unconditionally.
static func apply_landing(board: BoardState, unit: UnitState, events: Array[SimEvent]) -> void:
	_apply_tile_hazard(board, unit, unit.position, events)

## Apply hazard effects for entering `coord` without committing the unit's position.
static func apply_entry_at(board: BoardState, unit: UnitState, coord: Vector2i, events: Array[SimEvent]) -> void:
	_apply_tile_hazard(board, unit, coord, events)

static func _apply_tile_hazard(board: BoardState, unit: UnitState, coord: Vector2i, events: Array[SimEvent]) -> void:
	if unit == null or not unit.is_alive():
		return
	var tile := board.get_tile(coord)
	if tile == null or tile.definition == null:
		return
	if (
		unit.has_passive(&"lightfoot")
		and unit.is_passive_upgraded(&"lightfoot")
		and tile.definition.is_trap
	):
		return
	if tile.definition.is_chasm:
		var is_flying = (unit.definition != null and unit.definition.movement_type == GameEnums.MovementType.FLY) or unit.has_status(GameEnums.StatusType.AIRBORNE) or unit.has_status(GameEnums.StatusType.GHOST)
		if is_flying:
			pass # Flying/Airborne/Ghost units are immune to chasms
		elif unit.definition != null and unit.definition.is_boss:
			CombatSystem.deal_damage(board, unit, 5, events, &"hazard", false, false, null, "Pit", 5)
			_snap_boss_to_valid_tile(board, unit, events)
		else:
			var lethal := unit.health.max_hp * 99
			CombatSystem.deal_damage(board, unit, lethal, events, &"hazard", false, false, null, "Pit", lethal)
		return

	var dmg := tile.definition.hazard_damage
	var terrain_payload: Dictionary = board.terrain_payloads.get(coord, {})
	dmg += int(terrain_payload.get("hazard_damage_bonus", 0))
		
	if unit.has_passive(&"juggernaut") and tile.definition.id == &"trap":
		# Destroy the trap
		var new_def = DataLibrary.get_terrain(&"cracked")
		if new_def != null:
			tile = board.writable_tile(coord)
			if tile != null:
				tile.definition = new_def
			events.append(SimEvent.make(GameEnums.SimEventType.TERRAIN_CHANGED, {
				"coord": coord, "terrain": &"cracked"
			}))
		if unit.is_passive_upgraded(&"juggernaut"):
			CombatSystem.add_armor(board, unit, 1, events)
		return
		
	if unit.has_status(GameEnums.StatusType.AIRBORNE) or unit.has_status(GameEnums.StatusType.GHOST):
		return # Airborne and Ghost ignore hazard damage

	if dmg > 0 and unit.has_passive(&"safe_landing"):
		return # Safe Landing — zero hazard damage when entering a tile
		
	# Damage + entry payload flow through the shared terrain/combat stages.
	if dmg > 0:
		var entry_mult := float(unit.passive_flags.get("trap_entry_damage_multiplier", 1.0))
		if not is_equal_approx(entry_mult, 1.0):
			dmg = floori(float(dmg) * entry_mult)
			unit.passive_flags.erase("trap_entry_damage_multiplier")
		var trap_mult := int(unit.passive_flags.get("trap_collision_damage_multiplier", 1))
		if trap_mult > 1:
			dmg *= trap_mult
		CombatSystem.deal_damage(
			board, unit, dmg, events, &"hazard", false, false, null,
			tile.definition.display_name, dmg,
		)
	unit.passive_flags.erase("trap_collision_damage_multiplier")
	if not unit.is_alive():
		return
	RogueSystems.on_hazard_entry(board, unit, coord, events)
	var payload: Dictionary = board.terrain_payloads.get(coord, {})
	var terrain_owner := board.get_unit_by_id(int(payload.get("terrain_owner_id", -1)))
	if payload.get("sanctuary", false) and terrain_owner != null:
		if unit.team == terrain_owner.team:
			unit.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.STEALTH, 1))
			unit.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.INVULNERABLE, 1))
		elif payload.get("sanctuary_enemy_push", 0) > 0:
			PhysicsSystem.push(
				board,
				unit,
				PhysicsSystem.cardinal_from_to(terrain_owner.position, unit.position),
				int(payload["sanctuary_enemy_push"]),
				events,
				terrain_owner,
			)
	if payload.get("holy_ground", false) and terrain_owner != null and unit.team != terrain_owner.team:
		CombatSystem.deal_mag_atk(
			board, terrain_owner, unit, 1, events, "Holy Ground",
		)
		var def_down := int(payload.get("holy_ground_def_down", 0))
		if def_down > 0:
			unit.active_statuses.append(DataLibrary.make_status(
				GameEnums.StatusType.STAT_DEBUFF_DEF, 1, def_down,
			))
	if (
		payload.get("arcane_trail", false)
		and int(payload.get("arcane_trail_mag_atk", 0)) > 0
		and terrain_owner != null
		and unit.team != terrain_owner.team
	):
		CombatSystem.deal_mag_atk(
			board,
			terrain_owner,
			unit,
			int(payload["arcane_trail_mag_atk"]),
			events,
			"Arcane Trail",
		)
	if payload.get("crossing_weapon_damage", false):
		var weapon_damage := 0
		if payload.get("weapon_damage_owner", -1) >= 0:
			var owner := board.get_unit_by_id(int(payload["weapon_damage_owner"]))
			if owner != null and owner.definition != null and owner.definition.equipped_weapon != null:
				weapon_damage = owner.definition.equipped_weapon.might
		if weapon_damage > 0:
			CombatSystem.deal_damage(
				board, unit, weapon_damage, events, &"true", true, false, null,
				tile.definition.display_name, weapon_damage,
			)
			if not unit.is_alive():
				return
	if payload.get("crossing_blind", false):
		unit.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.BLIND, 1))
	if payload.get("created_area_weapon_damage", false):
		var weapon_damage := 0
		var damage_owner := board.get_unit_by_id(int(payload.get("weapon_damage_owner", -1)))
		if (
			damage_owner != null
			and damage_owner.definition != null
			and damage_owner.definition.equipped_weapon != null
		):
			weapon_damage = damage_owner.definition.equipped_weapon.might
		if weapon_damage > 0:
			CombatSystem.deal_damage(
				board, unit, weapon_damage, events, &"true", true, false, null,
				tile.definition.display_name, weapon_damage,
			)
			if not unit.is_alive():
				return
	if (
		payload.get("created_area_root", false)
		or payload.get("created_difficult_terrain_root", false)
	):
		if not unit.has_status(GameEnums.StatusType.ROOT):
			unit.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.ROOT, 1))
	if payload.get("created_area_poison", false):
		unit.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.POISON, 1))
	if payload.get("trap_vulnerable", false):
		unit.active_statuses.append(DataLibrary.make_status(GameEnums.StatusType.VULNERABLE, 1))
	var trap_bonus := int(payload.get("trap_damage_bonus", 0))
	if trap_bonus > 0:
		CombatSystem.deal_damage(
			board, unit, trap_bonus, events, &"true", true, false, null,
			tile.definition.display_name, trap_bonus,
		)
		if not unit.is_alive():
			return
	var bleed_amount := tile.definition.entry_bleed_amount
	if payload.get("skip_terrain_entry_bleed", false):
		bleed_amount = 0
	if payload.get("trap_bleed_weapon", false):
		bleed_amount = 0
		if unit.definition != null and unit.definition.equipped_weapon != null:
			bleed_amount = unit.definition.equipped_weapon.might
	if payload.get("trap_def_debuff", 0) is int:
		var def_down := int(payload.get("trap_def_debuff", 0))
		if def_down > 0:
			unit.active_statuses.append(DataLibrary.make_status(
				GameEnums.StatusType.STAT_DEBUFF_DEF, 1, def_down,
			))
	if payload.get("created_difficult_terrain_remove_fear", false):
		for i: int in range(unit.active_statuses.size() - 1, -1, -1):
			if unit.active_statuses[i].type == GameEnums.StatusType.FEAR:
				unit.active_statuses.remove_at(i)
	if (
		tile.definition.entry_status_duration > 0
		and not payload.get("skip_terrain_entry_status", false)
		and not CombatSystem.try_resist_crowd_control(unit, tile.definition.entry_status, events)
	):
		unit.active_statuses.append(StatusData.new(
			tile.definition.entry_status,
			tile.definition.entry_status_duration,
		))
		events.append(SimEvent.make(GameEnums.SimEventType.STATUS_APPLIED, {
			"unit": unit.id,
			"status_type": tile.definition.entry_status,
			"duration": tile.definition.entry_status_duration,
			"amount": 0,
			"terrain": tile.definition.id,
		}))
	if bleed_amount > 0:
		unit.active_statuses.append(StatusData.new(
			GameEnums.StatusType.BLEED,
			1,
			bleed_amount,
		))
		events.append(SimEvent.make(GameEnums.SimEventType.STATUS_APPLIED, {
			"unit": unit.id,
			"status_type": GameEnums.StatusType.BLEED,
			"duration": 1,
			"amount": bleed_amount,
			"terrain": tile.definition.id,
		}))
	if tile.definition.entry_vulnerable:
		unit.active_statuses.append(StatusData.new(GameEnums.StatusType.VULNERABLE, 1))
	if tile.definition.entry_move_penalty > 0:
		unit.active_statuses.append(StatusData.new(
			GameEnums.StatusType.STAT_DEBUFF_MOV,
			1,
			tile.definition.entry_move_penalty,
		))
	unit._recalculate_stats(board)

static func _snap_boss_to_valid_tile(board: BoardState, unit: UnitState, events: Array[SimEvent]) -> void:
	if not unit.is_alive():
		return
	var start := unit.position
	var queue := [start]
	var visited := {start: true}
	var valid_coord := start
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		var curr_tile = board.get_tile(curr)
		if GridSystem.is_passable(board, curr) and (curr_tile == null or curr_tile.definition == null or not curr_tile.definition.is_chasm):
			valid_coord = curr
			break
		for dir in GridSystem.DIRECTIONS:
			var next_coord = curr + dir
			if not visited.has(next_coord) and GridSystem.is_in_bounds(board, next_coord):
				visited[next_coord] = true
				queue.append(next_coord)
	
	if valid_coord != start:
		var from := unit.position
		GridSystem.set_occupant(board, unit.position, -1)
		unit.position = valid_coord
		GridSystem.set_occupant(board, unit.position, unit.id)
		events.append(SimEvent.make(GameEnums.SimEventType.UNIT_MOVED, {
			"actor": unit.id, "from": from, "to": unit.position,
			"steps": 1, "path": [valid_coord], "teleport": true,
		}))
