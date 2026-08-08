class_name BoardState
extends RefCounted

## Purpose: The complete, single source of truth for one battle at one instant:
## grid, units, locked enemy intents, and turn counter.
## Responsibilities: Own all runtime battle state; provide lookups; clone itself
## cheaply so previews can run on a throwaway copy.
## Dependencies: TileState, UnitState, Intent.
## Lifecycle: built from an EncounterData; deep-copied for every preview; the
##   real instance is adopted/replaced on execute.

var grid_size: Vector2i = Vector2i.ZERO
var tiles: Dictionary = {}          # Vector2i -> TileState
var units: Array[UnitState] = []
var intents: Array[Intent] = []
var items: Array[Vector2i] = []
var turn_index: int = 0
var pending_pushes: Array[Dictionary] = []
var temporary_terrain_turns: Dictionary = {}
var temporary_terrain_previous: Dictionary = {}
var terrain_payloads: Dictionary = {}
var delayed_effects: Array[Dictionary] = []

func get_tile(coord: Vector2i) -> TileState:
	return tiles.get(coord, null)


func set_tile_terrain(coord: Vector2i, terrain: TerrainData) -> void:
	assert(terrain != null, "BoardState.set_tile_terrain requires terrain")
	tiles[coord] = TileState.create(coord, terrain)


func is_in_bounds(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.y >= 0 and coord.x < grid_size.x and coord.y < grid_size.y

func get_unit_by_id(unit_id: int) -> UnitState:
	for unit in units:
		if unit.id == unit_id:
			return unit
	return null

func get_unit_at(coord: Vector2i) -> UnitState:
	var tile := get_tile(coord)
	if tile == null or tile.is_empty():
		return null
	return get_unit_by_id(tile.occupant_id)

func living_units() -> Array[UnitState]:
	var result: Array[UnitState] = []
	for unit in units:
		if unit.is_alive():
			result.append(unit)
	return result

func has_living_team(team: GameEnums.Team) -> bool:
	for unit in units:
		if unit.is_alive() and unit.team == team:
			return true
	return false

## Deterministic next ID: one past the highest existing ID.
func next_unit_id() -> int:
	var max_id := -1
	for unit in units:
		if unit.id > max_id:
			max_id = unit.id
	return max_id + 1

## Add a unit mid-combat (summoner spawns). Caller must set occupancy via GridSystem.
func add_unit(unit: UnitState) -> void:
	units.append(unit)

## Count living spawns that share the given UnitData definition (for spawn cap).
func count_living_by_definition(def: UnitData) -> int:
	var count := 0
	for unit in units:
		if unit.is_alive() and unit.definition == def:
			count += 1
	return count

func clone() -> BoardState:
	var copy := BoardState.new()
	copy.grid_size = grid_size
	copy.turn_index = turn_index
	# Dictionary preserves insertion order in Godot 4, so cloning is deterministic.
	for key in tiles:
		copy.tiles[key] = (tiles[key] as TileState).clone()
	for unit in units:
		copy.units.append(unit.clone())
	copy.items = items.duplicate()
	for intent in intents:
		copy.intents.append(intent.clone())
	copy.pending_pushes = pending_pushes.duplicate(true)
	copy.temporary_terrain_turns = temporary_terrain_turns.duplicate(true)
	copy.temporary_terrain_previous = temporary_terrain_previous.duplicate(true)
	copy.terrain_payloads = terrain_payloads.duplicate(true)
	copy.delayed_effects = delayed_effects.duplicate(true)
	return copy
