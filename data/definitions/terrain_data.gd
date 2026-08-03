class_name TerrainData
extends Resource

## Purpose: Static description of one kind of tile.
## Responsibilities: Hold terrain rules/metadata only.
## Dependencies: none.
## Lifecycle: immutable; shared by every TileState of this kind.

@export var id: StringName = &"plain"
@export var display_name: String = "Plain"

## If true, units cannot walk onto this tile (e.g. wall, deep forest).
@export var blocks_movement: bool = false

## If true, a pushed/pulled unit cannot be displaced onto this tile and
## collides instead (e.g. wall).
@export var stops_displacement: bool = false

## Damage dealt to a unit the moment it ENTERS this tile (pit, spikes, lava).
## 0 means the tile is harmless. A pit is modelled as blocks_movement=true (you
## won't walk in) + stops_displacement=false (you CAN be shoved in) + high damage.
@export var hazard_damage: int = 0

## Damage reduced from incoming attacks when standing on this tile.
@export var fortitude: int = 0

## If true, this tile is a bottomless pit. Instantly kills normal units; bosses take 5 damage and snap back.
@export var is_chasm: bool = false

## Movement points spent to enter this tile (plain = 1). Cracked earth uses 2 per Bible.
@export var mp_cost_per_tile: int = 1

