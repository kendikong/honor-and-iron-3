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

## Legacy motion metadata retained until ER-3 removes Motion Mode.
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

## CREATE_HAZARD typed fields (ability-data.md §2.2 / §5).
@export var terrain_id: StringName = &""
@export var hazard_duration: int = 0
@export var hazard_status: GameEnums.StatusType = GameEnums.StatusType.NONE

## DAMAGE extras that are now authored as typed module fields.
@export var bonus_dmg_from_occupied: int = 0
@export var bonus_dmg_per_10_hp: int = 0
@export var bonus_dmg_pct_max_hp: float = 0.0
@export var heal_if_targets_gte: int = 0
@export var bounce_count: int = 0
@export var bounce_range: int = 0
@export var buff_on_push: int = 0
@export var frenzy_on_kill_ap: int = 0
@export var push_board_items: int = 0
@export var item_collision_damage: int = 0
@export var item_collision_str_div: int = 0
@export var item_collision_vulnerable: int = 0
@export var violent_collision_recast: int = 0
@export var next_attack_strength: int = 0
@export var next_attack_bleed_weapon: bool = false
@export var next_turn: bool = false

## Archer typed positioning, hazard, targeting, and follow-up fields.
@export var preserve_facing: bool = false
@export var ignore_zoc: bool = false
@export var next_ranged_attack_strength: int = 0
@export var root_break_on_damage: bool = false
@export var skewer: int = 0
@export var bounce_walls_45: bool = false
@export var spread_status_adjacent: bool = false
@export var grapple_wall_pull_self: bool = false
@export var grapple_pass_through_damage: int = 0
@export var destroy_terrain: bool = false
@export var ignite_flammable_terrain: bool = false
@export var allies_range_bonus: int = 0
@export var allies_pierce: bool = false
@export var prevent_stealth_teleport: bool = false
@export var allow_friendly_target: bool = false
@export var ally_damage_zero: bool = false
@export var terrain_hazard_status: GameEnums.StatusType = GameEnums.StatusType.NONE
@export var trap_damage: int = 0
@export var trap_bleed_weapon: bool = false
@export var trap_vulnerable: bool = false
@export var crossing_weapon_damage: bool = false
@export var crossing_mov_penalty: int = 0
@export var crossing_blind: bool = false
@export var trap_def_debuff: int = 0
@export var strip_stealth: bool = false

## Lancer typed movement, reach, collision, and timing fields.
@export var limit_once_per_turn: bool = false
@export var range_one_damage_multiplier: float = 0.0
@export var halve_target_def_one_turn: bool = false
@export var armor_explosion_atk: int = 0
@export var bonus_atk_vs_fear_or_lower_movement: int = 0
@export var on_kill_max_move: int = 0
@export var next_turn_max_move: int = 0
@export var upgraded_trample: bool = false
@export var brace_attacker_stagger: int = 0
@export var pull_until_adjacent: bool = false
@export var pull_self_if_rooted: bool = false
@export var paired_ally_charge: bool = false
@export var paired_ally_strike_atk: int = 0
@export var on_kill_both_ap: int = 0
@export var vault_obstacle_or_gap_only: bool = false
@export var landing_adjacent_push: int = 0
@export var landing_adjacent_push_stagger: bool = false
@export var line_breaker: bool = false
@export var bonus_per_enemy_passed: int = 0
@export var create_trampled_terrain: bool = false

## Typed extras the Class Editor can add.
@export var extras: Array[AbilityExtraRule] = []

var _runtime_modifiers_cache: Dictionary = {}
var _runtime_modifiers_cache_valid: bool = false


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
	_ensure_runtime_modifiers_cache()
	return _runtime_modifiers_cache.has(key)


func runtime_value(key: String, default_value: Variant = null) -> Variant:
	_ensure_runtime_modifiers_cache()
	if _runtime_modifiers_cache.has(key):
		return _runtime_modifiers_cache[key]
	return default_value


func compile_runtime_modifiers() -> Dictionary:
	_ensure_runtime_modifiers_cache()
	return _runtime_modifiers_cache.duplicate(true)


func invalidate_runtime_modifiers_cache() -> void:
	_runtime_modifiers_cache.clear()
	_runtime_modifiers_cache_valid = false


func _ensure_runtime_modifiers_cache() -> void:
	if _runtime_modifiers_cache_valid:
		return
	var bag: Dictionary = {}
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
	if frenzy_on_kill_ap != 0:
		bag["frenzy_on_kill_ap"] = frenzy_on_kill_ap
	if push_board_items != 0:
		bag["push_board_items"] = push_board_items
	if item_collision_damage != 0:
		bag["item_collision_damage"] = item_collision_damage
	if item_collision_str_div != 0:
		bag["item_collision_str_div"] = item_collision_str_div
	if item_collision_vulnerable != 0:
		bag["item_collision_vulnerable"] = item_collision_vulnerable
	if violent_collision_recast != 0:
		bag["violent_collision_recast"] = violent_collision_recast
	if next_attack_strength != 0:
		bag["next_attack_strength"] = next_attack_strength
	if next_attack_bleed_weapon:
		bag["bleed_weapon"] = true
	if next_turn:
		bag["next_turn"] = true
	if preserve_facing:
		bag["preserve_facing"] = true
	if ignore_zoc:
		bag["ignore_zoc"] = true
	if next_ranged_attack_strength != 0:
		bag["next_ranged_attack_strength"] = next_ranged_attack_strength
	if root_break_on_damage:
		bag["root_break_on_damage"] = true
	if skewer != 0:
		bag["skewer"] = skewer
	if bounce_walls_45:
		bag["bounce_walls_45"] = true
	if spread_status_adjacent:
		bag["spread_status_adjacent"] = true
	if grapple_wall_pull_self:
		bag["grapple_wall_pull_self"] = true
	if grapple_pass_through_damage != 0:
		bag["grapple_pass_through_damage"] = grapple_pass_through_damage
	if destroy_terrain:
		bag["destroy_terrain"] = true
	if ignite_flammable_terrain:
		bag["ignite_flammable_terrain"] = true
	if allies_range_bonus != 0:
		bag["allies_range_bonus"] = allies_range_bonus
	if allies_pierce:
		bag["allies_pierce"] = true
	if prevent_stealth_teleport:
		bag["prevent_stealth_teleport"] = true
	if allow_friendly_target:
		bag["allow_friendly_target"] = true
	if ally_damage_zero:
		bag["ally_damage_zero"] = true
	if terrain_hazard_status != GameEnums.StatusType.NONE:
		bag["trap_status"] = terrain_hazard_status
	if trap_damage != 0:
		bag["trap_damage"] = trap_damage
	if trap_bleed_weapon:
		bag["trap_bleed_weapon"] = true
	if trap_vulnerable:
		bag["trap_vulnerable"] = true
	if crossing_weapon_damage:
		bag["crossing_weapon_damage"] = true
	if crossing_mov_penalty != 0:
		bag["crossing_mov_penalty"] = crossing_mov_penalty
	if crossing_blind:
		bag["crossing_blind"] = true
	if trap_def_debuff != 0:
		bag["trap_def_debuff"] = trap_def_debuff
	if strip_stealth:
		bag["strip_stealth"] = true
	if limit_once_per_turn:
		bag["limit_once_per_turn"] = true
	if not is_zero_approx(range_one_damage_multiplier):
		bag["range_one_damage_multiplier"] = range_one_damage_multiplier
	if halve_target_def_one_turn:
		bag["halve_target_def_one_turn"] = true
	if armor_explosion_atk != 0:
		bag["armor_explosion_atk"] = armor_explosion_atk
	if bonus_atk_vs_fear_or_lower_movement != 0:
		bag["bonus_atk_vs_fear_or_lower_movement"] = bonus_atk_vs_fear_or_lower_movement
	if on_kill_max_move != 0:
		bag["on_kill_max_move"] = on_kill_max_move
	if next_turn_max_move != 0:
		bag["next_turn_max_move"] = next_turn_max_move
	if upgraded_trample:
		bag["upgraded_trample"] = true
	if brace_attacker_stagger != 0:
		bag["brace_attacker_stagger"] = brace_attacker_stagger
	if pull_until_adjacent:
		bag["pull_until_adjacent"] = true
	if pull_self_if_rooted:
		bag["pull_self_if_rooted"] = true
	if paired_ally_charge:
		bag["paired_ally_charge"] = true
	if paired_ally_strike_atk != 0:
		bag["paired_ally_strike_atk"] = paired_ally_strike_atk
	if on_kill_both_ap != 0:
		bag["on_kill_both_ap"] = on_kill_both_ap
	if vault_obstacle_or_gap_only:
		bag["vault_obstacle_or_gap_only"] = true
	if landing_adjacent_push != 0:
		bag["landing_adjacent_push"] = landing_adjacent_push
	if landing_adjacent_push_stagger:
		bag["landing_adjacent_push_stagger"] = true
	if line_breaker:
		bag["line_breaker"] = true
	if bonus_per_enemy_passed != 0:
		bag["bonus_per_enemy_passed"] = bonus_per_enemy_passed
	if create_trampled_terrain:
		bag["create_trampled_terrain"] = true
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
	if target_filter == GameEnums.ModuleTargetFilter.OCCUPANT:
		match target_filter_occupant:
			GameEnums.ModuleTargetFilterOccupant.ALLY_CORPSE:
				bag["ally_corpse"] = true
			GameEnums.ModuleTargetFilterOccupant.ALLY_CONSTRUCT:
				bag["construct_target_only"] = true
			GameEnums.ModuleTargetFilterOccupant.ADJACENT_CONSTRUCT:
				bag["recall_adjacent_construct"] = true
			GameEnums.ModuleTargetFilterOccupant.ITEM_OR_CORPSE:
				bag["fetch_item_or_corpse"] = true
			GameEnums.ModuleTargetFilterOccupant.DRAGGED_ENEMY:
				bag["maul_dragged_enemy"] = true
			_:
				pass
	_runtime_modifiers_cache = bag
	_runtime_modifiers_cache_valid = true


func import_effect_modifiers(modifiers: Dictionary) -> void:
	if modifiers.is_empty():
		return
	for key: Variant in modifiers:
		ingest_runtime_key(String(key), modifiers[key])


func ingest_runtime_key(key: String, value: Variant) -> void:
	if key.is_empty():
		return
	invalidate_runtime_modifiers_cache()
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
		"frenzy_on_kill_ap":
			frenzy_on_kill_ap = int(value)
			return
		"push_board_items":
			push_board_items = int(value)
			return
		"item_collision_damage":
			item_collision_damage = int(value)
			return
		"item_collision_str_div":
			item_collision_str_div = int(value)
			return
		"item_collision_vulnerable":
			item_collision_vulnerable = int(value)
			return
		"violent_collision_recast":
			violent_collision_recast = int(value)
			return
		"next_attack_strength":
			next_attack_strength = int(value)
			return
		"bleed_weapon":
			next_attack_bleed_weapon = bool(value)
			return
		"next_turn":
			next_turn = bool(value)
			return
		"preserve_facing":
			preserve_facing = bool(value)
			return
		"ignore_zoc":
			ignore_zoc = bool(value)
			return
		"next_ranged_attack_strength":
			next_ranged_attack_strength = int(value)
			return
		"root_break_on_damage":
			root_break_on_damage = bool(value)
			return
		"skewer":
			skewer = int(value)
			return
		"bounce_walls_45":
			bounce_walls_45 = bool(value)
			return
		"spread_status_adjacent":
			spread_status_adjacent = bool(value)
			return
		"grapple_wall_pull_self":
			grapple_wall_pull_self = bool(value)
			return
		"grapple_pass_through_damage":
			grapple_pass_through_damage = int(value)
			return
		"destroy_terrain":
			destroy_terrain = bool(value)
			return
		"ignite_flammable_terrain":
			ignite_flammable_terrain = bool(value)
			return
		"allies_range_bonus":
			allies_range_bonus = int(value)
			return
		"allies_pierce":
			allies_pierce = bool(value)
			return
		"prevent_stealth_teleport":
			prevent_stealth_teleport = bool(value)
			return
		"allow_friendly_target":
			allow_friendly_target = bool(value)
			return
		"ally_damage_zero":
			ally_damage_zero = bool(value)
			return
		"trap_status":
			terrain_hazard_status = value as GameEnums.StatusType
			return
		"trap_damage":
			trap_damage = int(value)
			return
		"trap_bleed_weapon":
			trap_bleed_weapon = bool(value)
			return
		"trap_vulnerable":
			trap_vulnerable = bool(value)
			return
		"crossing_weapon_damage":
			crossing_weapon_damage = bool(value)
			return
		"crossing_mov_penalty":
			crossing_mov_penalty = int(value)
			return
		"crossing_blind":
			crossing_blind = bool(value)
			return
		"trap_def_debuff":
			trap_def_debuff = int(value)
			return
		"strip_stealth":
			strip_stealth = bool(value)
			return
		"limit_once_per_turn":
			limit_once_per_turn = bool(value)
			return
		"range_one_damage_multiplier":
			range_one_damage_multiplier = float(value)
			return
		"halve_target_def_one_turn":
			halve_target_def_one_turn = bool(value)
			return
		"armor_explosion_atk":
			armor_explosion_atk = int(value)
			return
		"bonus_atk_vs_fear_or_lower_movement":
			bonus_atk_vs_fear_or_lower_movement = int(value)
			return
		"on_kill_max_move":
			on_kill_max_move = int(value)
			return
		"next_turn_max_move":
			next_turn_max_move = int(value)
			return
		"upgraded_trample":
			upgraded_trample = bool(value)
			return
		"brace_attacker_stagger":
			brace_attacker_stagger = int(value)
			return
		"pull_until_adjacent":
			pull_until_adjacent = bool(value)
			return
		"pull_self_if_rooted":
			pull_self_if_rooted = bool(value)
			return
		"paired_ally_charge":
			paired_ally_charge = bool(value)
			return
		"paired_ally_strike_atk":
			paired_ally_strike_atk = int(value)
			return
		"on_kill_both_ap":
			on_kill_both_ap = int(value)
			return
		"vault_obstacle_or_gap_only":
			vault_obstacle_or_gap_only = bool(value)
			return
		"landing_adjacent_push":
			landing_adjacent_push = int(value)
			return
		"landing_adjacent_push_stagger":
			landing_adjacent_push_stagger = bool(value)
			return
		"line_breaker":
			line_breaker = bool(value)
			return
		"bonus_per_enemy_passed":
			bonus_per_enemy_passed = int(value)
			return
		"create_trampled_terrain":
			create_trampled_terrain = bool(value)
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
	invalidate_runtime_modifiers_cache()


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
