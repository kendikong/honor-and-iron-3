class_name TileState
extends RefCounted

## Purpose: The live state of one grid cell.
## Responsibilities: Track terrain kind and current occupant; clone itself.
## Dependencies: TerrainData (shared template).
## Lifecycle: created when a BoardState is built; deep-copied for every preview.

var coord: Vector2i = Vector2i.ZERO
var definition: TerrainData

## Id of the unit standing here, or -1 when empty. Occupancy is owned by the
## grid, mirrored here so lookups are O(1).
var occupant_id: int = -1

static func create(p_coord: Vector2i, def: TerrainData) -> TileState:
	var tile := TileState.new()
	tile.coord = p_coord
	tile.definition = def
	return tile

func is_empty() -> bool:
	return occupant_id == -1

func clone() -> TileState:
	var copy := TileState.new()
	copy.coord = coord
	copy.definition = definition  # shared immutable template; never cloned
	copy.occupant_id = occupant_id
	return copy
