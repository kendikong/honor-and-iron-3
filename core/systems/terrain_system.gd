class_name TerrainSystem
extends RefCounted

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
	if dmg <= 0:
		return
		
	if unit.has_status(GameEnums.StatusType.AIRBORNE) or unit.has_status(GameEnums.StatusType.GHOST):
		return # Airborne and Ghost ignore hazard damage
		
	# Damage + any resulting death flow through CombatSystem so HP stays
	# single-sourced and the event log reads move -> land -> hazard -> death.
	CombatSystem.deal_damage(board, unit, dmg, events, &"hazard", false, false, null, tile.definition.display_name, dmg)

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
