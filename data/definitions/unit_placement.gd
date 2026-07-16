class_name UnitPlacement
extends Resource

## Purpose: Pairs a unit template with where it starts on the board.
## Responsibilities: Spawn data only.
## Dependencies: UnitData.
## Lifecycle: read once when an encounter builds its BoardState.

@export var unit: UnitData
@export var coord: Vector2i = Vector2i.ZERO
