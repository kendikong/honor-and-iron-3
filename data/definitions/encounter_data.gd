class_name EncounterData
extends Resource

## Purpose: Everything needed to construct one battle's starting BoardState.
## Responsibilities: Grid size, terrain layout, and unit placements.
## Dependencies: TerrainData, UnitPlacement.
## Lifecycle: immutable; consumed once to build a BoardState.

@export var display_name: String = ""
@export var map_description: String = ""

@export var grid_size: Vector2i = Vector2i(8, 8)

## Terrain used for every tile not explicitly listed in tile_terrains.
@export var default_terrain: TerrainData

## Terrain used for tiles listed in wall_coords (legacy; prefer tile_terrains).
@export var wall_terrain: TerrainData

## Coordinates that should use wall_terrain instead of default_terrain.
@export var wall_coords: Array[Vector2i] = []

## Per-tile terrain overrides. Key: Vector2i coord, Value: TerrainData.
## Takes precedence over wall_coords. Supports arbitrary terrain types per tile.
@export var tile_terrains: Dictionary = {}

@export var player_spawns: Array[UnitPlacement] = []
@export var enemy_spawns: Array[UnitPlacement] = []
