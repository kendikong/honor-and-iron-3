class_name AbilityModule
extends Resource

## Purpose: One ordered skill step — primary effect + aim + keywords + layers + gate.
## Responsibilities: Describe a single modular step (ability-data.md §2).
## Dependencies: EffectData, AbilityKeyword, AbilityLayer, GameEnums.
## Lifecycle: authored on AbilityData.modules / upgraded_modules; immutable at runtime.

@export var execution_phase: GameEnums.ModulePhase = GameEnums.ModulePhase.ON_ACTION

## Primary combat primitive for this step.
@export var primary_type: GameEnums.EffectType = GameEnums.EffectType.DAMAGE
@export var amount: int = 0
@export var status_type: GameEnums.StatusType = GameEnums.StatusType.STAT_BUFF_STR
@export var status_duration: int = 1
@export var scaling_stat: GameEnums.StatType = GameEnums.StatType.NONE
@export var spawn_unit_id: StringName = &""

## Motion mode when primary is motion (MOVE/DASH/SWAP/…).
@export var motion_mode: GameEnums.MotionMode = GameEnums.MotionMode.NONE

@export var min_range: int = 0
@export var max_range: int = 1
@export var requires_los: bool = true
@export var range_origin: GameEnums.RangeOrigin = GameEnums.RangeOrigin.ACTOR

@export var target_shape: GameEnums.TargetShape = GameEnums.TargetShape.SINGLE
@export var target_shape_size: int = 1

@export var aim_binding: GameEnums.AimBinding = GameEnums.AimBinding.NEW_AIM
## Used when aim_binding == SAME_AS_MODULE_N (0-based module index).
@export var aim_module_index: int = 0

## Targeting bitmask (TargetingFlags) for this module's aim.
@export var targeting_flags: int = 0

@export var keywords: Array[AbilityKeyword] = []
@export var layers: Array[AbilityLayer] = []
@export var gate: GameEnums.ModuleGate = GameEnums.ModuleGate.ALWAYS

## Optional per-module anim override; AUTO inherits skill header.
@export var presentation_anim: GameEnums.PresentationAnim = GameEnums.PresentationAnim.AUTO

## DAMAGE-only typed fields (migrated from EffectData exports).
@export var bonus_if_adjacent_at_cast: int = 0
@export var def_debuff_before_damage: int = 0

## Transitional bag for modifier keys not yet typed (ability-data.md §12.9). Prefer typed fields.
@export var legacy_modifiers: Dictionary = {}


func has_targeting(flag: int) -> bool:
	return (targeting_flags & flag) != 0


func primary_as_effect() -> EffectData:
	var eff := EffectData.new()
	eff.type = primary_type
	eff.amount = amount
	eff.status_type = status_type
	eff.status_duration = status_duration
	eff.scaling_stat = scaling_stat
	eff.spawn_unit_id = spawn_unit_id
	eff.bonus_if_adjacent_at_cast = bonus_if_adjacent_at_cast
	eff.def_debuff_before_damage = def_debuff_before_damage
	eff.modifiers = legacy_modifiers.duplicate(true)
	return eff
