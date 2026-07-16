class_name BehaviorData
extends Resource

## Purpose: Describes how an enemy decides its intent during planning.
## Responsibilities: Name a strategy and supply its parameters/abilities.
## Dependencies: AbilityData.
## Lifecycle: immutable; read by EnemyPlanner during the planning phase only.

## Strategy id interpreted by EnemyPlanner. Milestone 1 supports "melee_chase".
@export var strategy: StringName = &"melee_chase"

## The attack this enemy attempts after moving toward its target.
@export var attack: AbilityData

## Unit template spawned by the "summoner" strategy. Null for non-summoners.
@export var spawn_unit: UnitData

## Maximum active spawns before the summoner stops (0 = unlimited).
@export var max_spawns: int = 3
