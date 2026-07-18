class_name AbilityData
extends Resource

## Purpose: A data-driven ability. An ability is a target rule + cost + a list of
## effects. Adding an ability means authoring a Resource, not writing code
## (constitution: "Abilities become data").
## Responsibilities: Describe targeting, cost, and the effects to apply.
## Dependencies: EffectData.
## Lifecycle: immutable definition shared by all units that own it.

@export var id: StringName = &""
@export var display_name: String = ""

## Action points consumed when used.
@export var action_point_cost: int = 1

## Maximum Manhattan distance from actor to target tile.
@export var range_tiles: int = 1

## The geometric shape of the affected area.
@export var target_shape: GameEnums.TargetShape = GameEnums.TargetShape.SINGLE

## The size/radius parameter for the geometric shape (e.g., 3 for 3x3 square).
@export var target_shape_size: int = 1

## Optional overrides for when the ability is upgraded. -1 means do not override.
@export var upgraded_range_tiles: int = -1
@export var upgraded_target_shape: GameEnums.TargetShape = GameEnums.TargetShape.SINGLE
@export var upgraded_target_shape_size: int = -1

## Ordered list of effects applied to the target, in order.
@export var effects: Array[EffectData] = []

## Effects applied to the target if this ability is upgraded.
@export var upgraded_effects: Array[EffectData] = []

## Description of what the upgrade does.
@export var upgrade_description: String = ""

## Maximum times this ability can be used per combat (-1 for unlimited).
@export var uses_per_combat: int = -1

## Opaque key the presentation layer maps to an animation/VFX/SFX.
## The simulation never loads or plays anything; it only forwards this string.
@export var presentation_key: StringName = &""

## Determines which stat (STR/MAG/NONE) scales the damage of this ability.
@export var scaling_stat: GameEnums.StatType = GameEnums.StatType.NONE

## Class movement skill from the Master Bible (Swap, Push Through, Leap, etc.).
## Always granted separately — never part of the rolled active-skill pool.
@export var is_movement_skill: bool = false
