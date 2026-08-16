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
@export var status_type: GameEnums.StatusType = GameEnums.StatusType.NONE
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
## Legal-click category (ability-data.md §2.5). Gate is “does this module run.”
@export var target_filter: GameEnums.ModuleTargetFilter = GameEnums.ModuleTargetFilter.NONE
@export var target_filter_hp: GameEnums.ModuleTargetFilterHp = GameEnums.ModuleTargetFilterHp.BELOW_PCT
## Used when target_filter == HP and target_filter_hp == BELOW_PCT. 50 means current HP < 50% of max.
@export var target_filter_hp_pct: int = 0
@export var target_filter_status_mode: GameEnums.ModuleTargetFilterStatus = GameEnums.ModuleTargetFilterStatus.ANY_DEBUFF
@export var target_filter_status: GameEnums.StatusType = GameEnums.StatusType.NONE
## Optional second status; target may have either (BLEED or POISON).
@export var target_filter_status_or: GameEnums.StatusType = GameEnums.StatusType.NONE
@export var target_filter_stat: GameEnums.ModuleTargetFilterStat = GameEnums.ModuleTargetFilterStat.CON_LEQ_CASTER_STR
@export var target_filter_occupant: GameEnums.ModuleTargetFilterOccupant = GameEnums.ModuleTargetFilterOccupant.ALLY_CONSTRUCT

## Optional per-module anim override; AUTO inherits skill header.
@export var presentation_anim: GameEnums.PresentationAnim = GameEnums.PresentationAnim.AUTO

## DAMAGE-only typed fields (migrated from EffectData exports).
@export var bonus_if_adjacent_at_cast: int = 0
@export var def_debuff_before_damage: int = 0
## DAMAGE-only. 1 = single hit. Compile copies values > 1 onto the effect for AbilitySystem.
@export var hit_count: int = 1

## Transitional bag for modifier keys not yet typed (ability-data.md §12.9). Prefer typed fields.
@export var legacy_modifiers: Dictionary = {}


func has_targeting(flag: int) -> bool:
	return (targeting_flags & flag) != 0


func primary_as_effect() -> EffectData:
	var eff := EffectData.new()
	eff.type = primary_type
	eff.amount = amount
	if GameEnums.effect_type_applies_status(primary_type):
		eff.status_type = status_type
		eff.status_duration = status_duration
	else:
		eff.status_type = GameEnums.StatusType.NONE
	if GameEnums.effect_type_uses_module_scaling(primary_type):
		eff.scaling_stat = scaling_stat
	else:
		eff.scaling_stat = GameEnums.StatType.NONE
	if GameEnums.effect_type_uses_spawn_unit(primary_type):
		eff.spawn_unit_id = spawn_unit_id
	else:
		eff.spawn_unit_id = &""
	if primary_type == GameEnums.EffectType.DAMAGE:
		eff.bonus_if_adjacent_at_cast = bonus_if_adjacent_at_cast
		eff.def_debuff_before_damage = def_debuff_before_damage
	else:
		eff.bonus_if_adjacent_at_cast = 0
		eff.def_debuff_before_damage = 0
	eff.modifiers = legacy_modifiers.duplicate(true)
	eff.modifiers.erase("hit_count")
	eff.modifiers.erase("repeat_hits")
	var hits: int = resolved_hit_count()
	if hits > 1:
		eff.modifiers["hit_count"] = hits
	return eff


func resolved_hit_count() -> int:
	if primary_type != GameEnums.EffectType.DAMAGE:
		return 1
	return maxi(1, hit_count)


func set_condition_hp_below_pct(pct: int) -> void:
	target_filter = GameEnums.ModuleTargetFilter.HP
	target_filter_hp = GameEnums.ModuleTargetFilterHp.BELOW_PCT
	target_filter_hp_pct = pct


func set_condition_hp_below_caster() -> void:
	target_filter = GameEnums.ModuleTargetFilter.HP
	target_filter_hp = GameEnums.ModuleTargetFilterHp.BELOW_CASTER_HP
	target_filter_hp_pct = 0


func set_condition_any_debuff() -> void:
	target_filter = GameEnums.ModuleTargetFilter.STATUS
	target_filter_status_mode = GameEnums.ModuleTargetFilterStatus.ANY_DEBUFF


func set_condition_status(
	status: GameEnums.StatusType,
	status_or: GameEnums.StatusType = GameEnums.StatusType.NONE,
) -> void:
	target_filter = GameEnums.ModuleTargetFilter.STATUS
	target_filter_status_mode = GameEnums.ModuleTargetFilterStatus.SPECIFIC
	target_filter_status = status
	target_filter_status_or = status_or


func set_condition_not_acted() -> void:
	target_filter = GameEnums.ModuleTargetFilter.STATUS
	target_filter_status_mode = GameEnums.ModuleTargetFilterStatus.NOT_ACTED


func set_condition_con_leq_caster_str() -> void:
	target_filter = GameEnums.ModuleTargetFilter.STAT
	target_filter_stat = GameEnums.ModuleTargetFilterStat.CON_LEQ_CASTER_STR


func set_condition_occupant(occupant: GameEnums.ModuleTargetFilterOccupant) -> void:
	target_filter = GameEnums.ModuleTargetFilter.OCCUPANT
	target_filter_occupant = occupant
