class_name EffectData
extends Resource

## Purpose: One combat primitive (deal damage, push N tiles, ...).
## Responsibilities: Hold values only. The matching system interprets behavior
## (constitution: "Behavior should be interpreted by systems").
## Dependencies: GameEnums.
## Lifecycle: authored as part of an AbilityData; immutable at runtime.

@export var type: GameEnums.EffectType = GameEnums.EffectType.DAMAGE

## Generic magnitude: damage amount, push distance, etc. Meaning depends on type.
@export var amount: int = 0

## Used only for ADD_STATUS effects.
@export var status_type: GameEnums.StatusType
@export var status_duration: int = 1

## Optional: scale the effect amount based on a caster's stat (e.g. DEF, MISSING_HP).
@export var scaling_stat: GameEnums.StatType = GameEnums.StatType.NONE

## DAMAGE only: flat bonus if target was already adjacent when cast (Shield Slam).
@export var bonus_if_adjacent_at_cast: int = 0

## DAMAGE only: apply temporary DEF debuff before resolving damage (Shield Slam [+]).
@export var def_debuff_before_damage: int = 0

## Used only for SPAWN effects. Refers to a UnitData ID in DataLibrary.
@export var spawn_unit_id: StringName

## Flexible dictionary for storing effect-specific modifiers and flags (e.g. "ghost_move", "bonus_dmg_from_terrain").
@export var modifiers: Dictionary = {}
