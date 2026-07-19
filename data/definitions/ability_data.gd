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

## Economy / timeline classification (see Master Bible § Universal Action Economy).
@export var kind: GameEnums.AbilityKind = GameEnums.AbilityKind.CLASS_SKILL

## Action points consumed when used (CLASS_SKILL only; Run AP is spent on MOVE via uses_run).
@export var action_point_cost: int = 1

## Movement points consumed when used (MOVEMENT_SKILL only).
@export var movement_point_cost: int = 0

## Maximum Manhattan distance from actor to target tile.
@export var range_tiles: int = 1

## Who may be targeted. Movement skills that select a unit default to ALLY_UNIT.
@export var targeting_mode: GameEnums.TargetingMode = GameEnums.TargetingMode.ANY_UNIT

## True when the ability may target the caster's own tile (self-buffs, Wait, etc.).
@export var can_target_self: bool = false

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

## Presentation anim override; AUTO uses kind + targeting rules.
@export var presentation_anim: GameEnums.PresentationAnim = GameEnums.PresentationAnim.AUTO

## Determines which stat (STR/MAG/NONE) scales the damage of this ability.
@export var scaling_stat: GameEnums.StatType = GameEnums.StatType.NONE

## Legacy mirror of kind == MOVEMENT_SKILL (kept for existing checks).
@export var is_movement_skill: bool = false


func is_movement_kind() -> bool:
	return kind == GameEnums.AbilityKind.MOVEMENT_SKILL or is_movement_skill


func is_pre_move_kind() -> bool:
	return is_movement_kind() or kind == GameEnums.AbilityKind.UNIVERSAL_RUN


func is_class_kind() -> bool:
	return kind == GameEnums.AbilityKind.CLASS_SKILL


func consumes_action_slot() -> bool:
	return kind == GameEnums.AbilityKind.CLASS_SKILL
