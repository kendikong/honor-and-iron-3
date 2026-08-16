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

## Targeting: skip the caster when this module paints an allied/self area.
@export var exclude_caster: bool = false

## CREATE_HAZARD typed fields (ability-data.md §12.9).
@export var terrain_id: StringName = &""
@export var hazard_duration: int = 0
@export var hazard_status: GameEnums.StatusType = GameEnums.StatusType.NONE

## DAMAGE extras previously stuffed into legacy_modifiers.
@export var bonus_dmg_from_occupied: int = 0
@export var bonus_dmg_per_10_hp: int = 0
@export var bonus_dmg_pct_max_hp: float = 0.0
@export var heal_if_targets_gte: int = 0
@export var bounce_count: int = 0
@export var bounce_range: int = 0
@export var buff_on_push: int = 0

## Typed extras the Class Editor can add (replaces legacy_modifiers authoring).
@export var extras: Array[AbilityExtraRule] = []

## Transitional bag. Factories must leave this empty; compile may still stamp runtime keys.
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
	eff.modifiers = compile_runtime_modifiers()
	eff.modifiers.erase("hit_count")
	eff.modifiers.erase("repeat_hits")
	var hits: int = resolved_hit_count()
	if hits > 1:
		eff.modifiers["hit_count"] = hits
	return eff


func runtime_has(key: String) -> bool:
	return compile_runtime_modifiers().has(key)


func runtime_value(key: String, default_value: Variant = null) -> Variant:
	var bag: Dictionary = compile_runtime_modifiers()
	if bag.has(key):
		return bag[key]
	return default_value


func compile_runtime_modifiers() -> Dictionary:
	var bag: Dictionary = legacy_modifiers.duplicate(true)
	if exclude_caster or has_targeting(GameEnums.TargetingFlags.EXCLUDE_CASTER):
		bag["exclude_caster"] = true
	if terrain_id != StringName():
		bag["terrain_id"] = terrain_id
	if hazard_duration != 0:
		bag["hazard_duration"] = hazard_duration
	if hazard_status != GameEnums.StatusType.NONE:
		bag["hazard_status"] = hazard_status
	if bonus_dmg_from_occupied != 0:
		bag["bonus_dmg_from_occupied"] = bonus_dmg_from_occupied
	if bonus_dmg_per_10_hp != 0:
		bag["bonus_dmg_per_10_hp"] = bonus_dmg_per_10_hp
	if not is_zero_approx(bonus_dmg_pct_max_hp):
		bag["bonus_dmg_pct_max_hp"] = bonus_dmg_pct_max_hp
	if heal_if_targets_gte != 0:
		bag["heal_if_targets_gte"] = heal_if_targets_gte
	if bounce_count != 0:
		bag["bounce_count"] = bounce_count
	if bounce_range != 0:
		bag["bounce_range"] = bounce_range
	if buff_on_push != 0:
		bag["buff_on_push"] = buff_on_push
	if motion_mode == GameEnums.MotionMode.L_SHAPE:
		bag["l_shape_move"] = true
	for extra: AbilityExtraRule in extras:
		if extra == null:
			continue
		var extra_key: String = extra.runtime_key()
		if extra_key.is_empty():
			continue
		bag[extra_key] = extra.value
	for keyword: AbilityKeyword in keywords:
		if keyword == null:
			continue
		match keyword.keyword_id:
			GameEnums.AbilityKeywordId.GHOST:
				bag["ghost_move"] = 1
			GameEnums.AbilityKeywordId.PIERCE:
				if not bag.has("next_attack_pierce") and not bag.has("pierce"):
					bag["next_attack_pierce"] = 1
			GameEnums.AbilityKeywordId.BULLDOZE:
				bag["bulldoze"] = keyword.amount
				if keyword.push_amount != 0:
					bag["push"] = keyword.push_amount
			GameEnums.AbilityKeywordId.TRAMPLE:
				if primary_type != GameEnums.EffectType.TRAMPLE:
					bag["trample"] = keyword.amount
			_:
				pass
	return bag


func ingest_runtime_bag(bag: Dictionary) -> void:
	if bag.is_empty():
		return
	for key: Variant in bag:
		ingest_runtime_key(String(key), bag[key])


func ingest_runtime_key(key: String, value: Variant) -> void:
	if key.is_empty():
		return
	match key:
		"exclude_caster":
			exclude_caster = bool(value)
			targeting_flags |= GameEnums.TargetingFlags.EXCLUDE_CASTER
			return
		"terrain_id":
			terrain_id = StringName(value)
			return
		"hazard_duration":
			hazard_duration = int(value)
			return
		"hazard_status":
			hazard_status = value as GameEnums.StatusType
			return
		"bonus_dmg_from_occupied":
			bonus_dmg_from_occupied = int(value)
			return
		"bonus_dmg_per_10_hp":
			bonus_dmg_per_10_hp = int(value)
			return
		"bonus_dmg_pct_max_hp":
			bonus_dmg_pct_max_hp = float(value)
			return
		"heal_if_targets_gte":
			heal_if_targets_gte = int(value)
			return
		"bounce_count":
			bounce_count = int(value)
			return
		"bounce_range":
			bounce_range = int(value)
			return
		"buff_on_push":
			buff_on_push = int(value)
			return
		"l_shape_move":
			motion_mode = GameEnums.MotionMode.L_SHAPE
			return
		"ghost_move":
			_ensure_keyword(GameEnums.AbilityKeywordId.GHOST)
			return
		"hit_count", "repeat_hits":
			if primary_type == GameEnums.EffectType.DAMAGE:
				hit_count = maxi(hit_count, int(value))
			return
		"target_hp_below_pct":
			if target_filter == GameEnums.ModuleTargetFilter.NONE:
				set_condition_hp_below_pct(
					clampi(roundi(float(value) * 100.0), 1, 100)
				)
			return
		"requires_missing_hp":
			if bool(value) and target_filter == GameEnums.ModuleTargetFilter.NONE:
				set_condition_hp_below_pct(100)
			return
		"lower_hp_only":
			if bool(value) and target_filter == GameEnums.ModuleTargetFilter.NONE:
				set_condition_hp_below_caster()
			return
		"requires_debuff":
			if bool(value) and target_filter == GameEnums.ModuleTargetFilter.NONE:
				set_condition_any_debuff()
			return
		"requires_bleed_or_poison":
			if bool(value) and target_filter == GameEnums.ModuleTargetFilter.NONE:
				set_condition_status(GameEnums.StatusType.BLEED, GameEnums.StatusType.POISON)
			return
		"target_unacted_only":
			if bool(value) and target_filter == GameEnums.ModuleTargetFilter.NONE:
				set_condition_not_acted()
			return
		"target_constitution_at_most_strength":
			if bool(value) and target_filter == GameEnums.ModuleTargetFilter.NONE:
				set_condition_con_leq_caster_str()
			return
		"construct_target_only":
			if bool(value) and target_filter == GameEnums.ModuleTargetFilter.NONE:
				set_condition_occupant(GameEnums.ModuleTargetFilterOccupant.ALLY_CONSTRUCT)
			return
		"recall_adjacent_construct":
			if bool(value) and target_filter == GameEnums.ModuleTargetFilter.NONE:
				set_condition_occupant(GameEnums.ModuleTargetFilterOccupant.ADJACENT_CONSTRUCT)
			return
		"fetch_item_or_corpse":
			if bool(value) and target_filter == GameEnums.ModuleTargetFilter.NONE:
				set_condition_occupant(GameEnums.ModuleTargetFilterOccupant.ITEM_OR_CORPSE)
			return
		"ally_corpse":
			if bool(value) and target_filter == GameEnums.ModuleTargetFilter.NONE:
				set_condition_occupant(GameEnums.ModuleTargetFilterOccupant.ALLY_CORPSE)
			return
		"maul_dragged_enemy":
			if bool(value) and target_filter == GameEnums.ModuleTargetFilter.NONE:
				set_condition_occupant(GameEnums.ModuleTargetFilterOccupant.DRAGGED_ENEMY)
			return
		_:
			pass
	for extra: AbilityExtraRule in extras:
		if extra != null and extra.runtime_key() == key:
			extra.value = value
			return
	var extra := AbilityExtraRule.new()
	extra.id = AbilityExtraRule.id_for_key(key)
	extra.value = value
	if extra.id == AbilityExtraRule.Id.NONE:
		extra.override_key = key
	extras.append(extra)


func _ensure_keyword(keyword_id: GameEnums.AbilityKeywordId) -> void:
	for keyword: AbilityKeyword in keywords:
		if keyword != null and keyword.keyword_id == keyword_id:
			return
	var keyword := AbilityKeyword.new()
	keyword.keyword_id = keyword_id
	keyword.amount = 1
	keywords.append(keyword)


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
