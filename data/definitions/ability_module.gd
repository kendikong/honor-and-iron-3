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
@export var next_attack_pierce: bool = false
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

## Mage typed terrain, reaction, teleport, resource, and utility fields.
@export var blink: bool = false
@export var leave_elemental_surface: bool = false
@export var reaction_terrain: StringName = &""
@export var reaction_damage: int = 0
@export var bounce_surface_chain: bool = false
@export var lightning_surface: bool = false
@export var strike_all_surface: bool = false
@export var teleport_visible: bool = false
@export var delayed_next_turn: bool = false
@export var create_crater: bool = false
@export var pull_to_center: bool = false
@export var pull_surfaces: bool = false
@export var mana_shield: bool = false
@export var mana_shield_casting: bool = false
@export var destroy_corpse_on_kill: bool = false
@export var kill_grant_ap: int = 0
@export var utility_only: bool = false
@export var elemental_surge: bool = false
@export var elemental_surge_ap: int = 0
@export var construct_hp_pct: float = 0.0
@export var density_shift: bool = false
@export var ignore_target_magic_pct: float = 0.0
@export var creation_adjacent_damage: int = 0
@export var apply_weaken_enemy: bool = false

## Cleric typed healing, sanctuary, protection, and link fields.
@export var cost_all_movement: bool = false
@export var cleanse_target: bool = false
@export var mag_heal: bool = false
@export var enemy_mag_atk: int = 0
@export var shield_closest_ally_pct_damage: float = 0.0
@export var ally_str_per_debuff: int = 0
@export var sanctuary: bool = false
@export var sanctuary_enemy_push: int = 0
@export var creation_adjacent_push: int = 0
@export var holy_aura: bool = false
@export var life_link: bool = false
@export var life_link_reduction: int = 0
@export var revive_percent_max_hp: float = 0.0
@export var spend_self_hp: int = 0
@export var revive_shield: int = 0
@export var holy_ground: bool = false
@export var holy_ground_zone: bool = false
@export var holy_ground_def_down: int = 0
@export var stagger_if_debuffed: bool = false
@export var push: int = 0
@export var grant_ap: int = 0
@export var self_move_zero_next_turn: bool = false
@export var link_two_enemies: bool = false
@export var magic_link_damage: int = 0
@export var link_partner_pick: bool = false
@export var link_blind: bool = false

## Mercenary typed movement, attack, trap, and follow-up fields.
@export var pullback: bool = false
@export var pullback_ally_def: int = 0
@export var movement_mp_override: int = 0
@export var swift_strike: bool = false
@export var target_damaged_ap: int = 0
@export var remove_push_mitigation: bool = false
@export var prevent_target_shield: bool = false
@export var bonus_if_target_adjacent_to_ally: int = 0
@export var pierce: bool = false
@export var target_def_pct_debuff: float = 0.0
@export var target_def_pct_duration: int = 0
@export var if_target_attacked_caster_last_turn_bonus: int = 0
@export var if_target_attacked_caster_last_turn_stagger: bool = false
@export var target_def_debuff: int = 0
@export var on_kill_all_allies_heal: int = 0
@export var on_kill_all_allies_shield: int = 0
@export var next_skill_zero_ap: bool = false
@export var smoke_on_start: bool = false
@export var flank_run_adjacent_enemy_bonus: int = 0
@export var bleed_bonus_damage: int = 0
@export var duelist_mark_target: bool = false
@export var marked_target_defense: int = 0
@export var unacted_target_ignore_def_pct: float = 0.0

## Monk typed movement, surface, combo, and follow-up fields.
@export var leap_absorb_surface: bool = false
@export var track_first_hit_zero: bool = false
@export var chakra_shift: bool = false
@export var chakra_burst_damage: int = 0
@export var chakra_burst_shape: GameEnums.TargetShape = GameEnums.TargetShape.SINGLE
@export var chakra_burst_size: int = 0
@export var stop_adjacent_first_enemy: bool = false
@export var dash_absorb_element: bool = false
@export var target_magic_defense: bool = false
@export var steal_target_magic: int = 0
@export var next_turn_move_penalty: int = 0
@export var bonus_per_target_status: int = 0
@export var mantra_peace_weaken: bool = false
@export var inner_fire: bool = false
@export var inner_fire_surface: bool = false
@export var landed_magic_bonus: int = 0
@export var enemy_pushed_mov: int = 0
@export var blind_on_pass_over: bool = false

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
	if next_attack_pierce:
		bag["next_attack_pierce"] = true
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
	if blink:
		bag["blink"] = true
	if leave_elemental_surface:
		bag["leave_elemental_surface"] = true
	if reaction_terrain != StringName():
		bag["reaction_terrain"] = reaction_terrain
	if reaction_damage != 0:
		bag["reaction_damage"] = reaction_damage
	if bounce_surface_chain:
		bag["surface_chain"] = true
	if lightning_surface:
		bag["lightning"] = true
	if strike_all_surface:
		bag["strike_all_surface"] = true
	if teleport_visible:
		bag["teleport_visible"] = true
	if delayed_next_turn:
		bag["delayed_next_turn"] = true
	if create_crater:
		bag["create_crater"] = true
	if pull_to_center:
		bag["pull_to_center"] = true
	if pull_surfaces:
		bag["pull_surfaces"] = true
	if mana_shield:
		bag["mana_shield"] = true
	if mana_shield_casting:
		bag["mana_shield_casting"] = true
	if destroy_corpse_on_kill:
		bag["destroy_corpse_on_kill"] = true
	if kill_grant_ap != 0:
		bag["kill_grant_ap"] = kill_grant_ap
	if utility_only:
		bag["utility_only"] = true
	if elemental_surge:
		bag["elemental_surge"] = true
	if elemental_surge_ap != 0:
		bag["elemental_surge_ap"] = elemental_surge_ap
	if not is_zero_approx(construct_hp_pct):
		bag["construct_hp_pct"] = construct_hp_pct
	if density_shift:
		bag["density_shift"] = true
	if not is_zero_approx(ignore_target_magic_pct):
		bag["ignore_target_magic_pct"] = ignore_target_magic_pct
	if creation_adjacent_damage != 0:
		bag["creation_adjacent_damage"] = creation_adjacent_damage
	if apply_weaken_enemy:
		bag["apply_weaken_enemy"] = true
	if cost_all_movement:
		bag["cost_all_movement"] = true
	if cleanse_target:
		bag["cleanse_target"] = true
	if mag_heal:
		bag["mag_heal"] = true
	if enemy_mag_atk != 0:
		bag["enemy_mag_atk"] = enemy_mag_atk
	if not is_zero_approx(shield_closest_ally_pct_damage):
		bag["shield_closest_ally_pct_damage"] = shield_closest_ally_pct_damage
	if ally_str_per_debuff != 0:
		bag["ally_str_per_debuff"] = ally_str_per_debuff
	if sanctuary:
		bag["sanctuary"] = true
	if sanctuary_enemy_push != 0:
		bag["sanctuary_enemy_push"] = sanctuary_enemy_push
	if creation_adjacent_push != 0:
		bag["creation_adjacent_push"] = creation_adjacent_push
	if holy_aura:
		bag["holy_aura"] = true
	if life_link:
		bag["life_link"] = true
	if life_link_reduction != 0:
		bag["life_link_reduction"] = life_link_reduction
	if not is_zero_approx(revive_percent_max_hp):
		bag["revive_percent_max_hp"] = revive_percent_max_hp
	if spend_self_hp != 0:
		bag["spend_self_hp"] = spend_self_hp
	if revive_shield != 0:
		bag["revive_shield"] = revive_shield
	if holy_ground:
		bag["holy_ground"] = true
	if holy_ground_zone:
		bag["holy_ground_zone"] = true
	if holy_ground_def_down != 0:
		bag["holy_ground_def_down"] = holy_ground_def_down
	if stagger_if_debuffed:
		bag["stagger_if_debuffed"] = true
	if push != 0:
		bag["push"] = push
	if grant_ap != 0:
		bag["grant_ap"] = grant_ap
	if self_move_zero_next_turn:
		bag["self_move_zero_next_turn"] = true
	if link_two_enemies:
		bag["link_two_enemies"] = true
	if magic_link_damage != 0:
		bag["magic_link_damage"] = magic_link_damage
	if link_partner_pick:
		bag["link_partner_pick"] = true
	if link_blind:
		bag["link_blind"] = true
	if pullback:
		bag["pullback"] = true
	if pullback_ally_def != 0:
		bag["pullback_ally_def"] = pullback_ally_def
	if movement_mp_override != 0:
		bag["movement_mp_override"] = movement_mp_override
	if swift_strike:
		bag["swift_strike"] = true
	if target_damaged_ap != 0:
		bag["target_damaged_ap"] = target_damaged_ap
	if remove_push_mitigation:
		bag["remove_push_mitigation"] = true
	if prevent_target_shield:
		bag["prevent_target_shield"] = true
	if bonus_if_target_adjacent_to_ally != 0:
		bag["bonus_if_target_adjacent_to_ally"] = bonus_if_target_adjacent_to_ally
	if pierce:
		bag["pierce"] = true
	if not is_zero_approx(target_def_pct_debuff):
		bag["target_def_pct_debuff"] = target_def_pct_debuff
	if target_def_pct_duration != 0:
		bag["target_def_pct_duration"] = target_def_pct_duration
	if if_target_attacked_caster_last_turn_bonus != 0:
		bag["if_target_attacked_caster_last_turn_bonus"] = if_target_attacked_caster_last_turn_bonus
	if if_target_attacked_caster_last_turn_stagger:
		bag["if_target_attacked_caster_last_turn_stagger"] = true
	if target_def_debuff != 0:
		bag["target_def_debuff"] = target_def_debuff
	if on_kill_all_allies_heal != 0:
		bag["on_kill_all_allies_heal"] = on_kill_all_allies_heal
	if on_kill_all_allies_shield != 0:
		bag["on_kill_all_allies_shield"] = on_kill_all_allies_shield
	if next_skill_zero_ap:
		bag["next_skill_zero_ap"] = true
	if smoke_on_start:
		bag["smoke_on_start"] = true
	if flank_run_adjacent_enemy_bonus != 0:
		bag["flank_run_adjacent_enemy_bonus"] = flank_run_adjacent_enemy_bonus
	if bleed_bonus_damage != 0:
		bag["bleed_bonus_damage"] = bleed_bonus_damage
	if duelist_mark_target:
		bag["duelist_mark_target"] = true
	if marked_target_defense != 0:
		bag["marked_target_defense"] = marked_target_defense
	if not is_zero_approx(unacted_target_ignore_def_pct):
		bag["unacted_target_ignore_def_pct"] = unacted_target_ignore_def_pct
	if leap_absorb_surface:
		bag["leap_absorb_surface"] = true
	if track_first_hit_zero:
		bag["track_first_hit_zero"] = true
	if chakra_shift:
		bag["chakra_shift"] = true
	if chakra_burst_damage != 0:
		bag["chakra_burst_damage"] = chakra_burst_damage
	if chakra_burst_shape != GameEnums.TargetShape.SINGLE:
		bag["chakra_burst_shape"] = chakra_burst_shape
	if chakra_burst_size != 0:
		bag["chakra_burst_size"] = chakra_burst_size
	if stop_adjacent_first_enemy:
		bag["stop_adjacent_first_enemy"] = true
	if dash_absorb_element:
		bag["dash_absorb_element"] = true
	if target_magic_defense:
		bag["target_magic_defense"] = true
	if steal_target_magic != 0:
		bag["steal_target_magic"] = steal_target_magic
	if next_turn_move_penalty != 0:
		bag["next_turn_move_penalty"] = next_turn_move_penalty
	if bonus_per_target_status != 0:
		bag["bonus_per_target_status"] = bonus_per_target_status
	if mantra_peace_weaken:
		bag["mantra_peace_weaken"] = true
	if inner_fire:
		bag["inner_fire"] = true
	if inner_fire_surface:
		bag["inner_fire_surface"] = true
	if landed_magic_bonus != 0:
		bag["landed_magic_bonus"] = landed_magic_bonus
	if enemy_pushed_mov != 0:
		bag["enemy_pushed_mov"] = enemy_pushed_mov
	if blind_on_pass_over:
		bag["blind_on_pass_over"] = true
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
		"next_attack_pierce":
			next_attack_pierce = bool(value)
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
		"blink":
			blink = bool(value)
			return
		"leave_elemental_surface":
			leave_elemental_surface = bool(value)
			return
		"reaction_terrain":
			reaction_terrain = StringName(value)
			return
		"reaction_damage":
			reaction_damage = int(value)
			return
		"surface_chain":
			bounce_surface_chain = bool(value)
			return
		"lightning":
			lightning_surface = bool(value)
			return
		"strike_all_surface":
			strike_all_surface = bool(value)
			return
		"teleport_visible":
			teleport_visible = bool(value)
			return
		"delayed_next_turn":
			delayed_next_turn = bool(value)
			return
		"create_crater":
			create_crater = bool(value)
			return
		"pull_to_center":
			pull_to_center = bool(value)
			return
		"pull_surfaces":
			pull_surfaces = bool(value)
			return
		"mana_shield":
			mana_shield = bool(value)
			return
		"mana_shield_casting":
			mana_shield_casting = bool(value)
			return
		"destroy_corpse_on_kill":
			destroy_corpse_on_kill = bool(value)
			return
		"kill_grant_ap":
			kill_grant_ap = int(value)
			return
		"utility_only":
			utility_only = bool(value)
			return
		"elemental_surge":
			elemental_surge = bool(value)
			return
		"elemental_surge_ap":
			elemental_surge_ap = int(value)
			return
		"construct_hp_pct":
			construct_hp_pct = float(value)
			return
		"density_shift":
			density_shift = bool(value)
			return
		"ignore_target_magic_pct":
			ignore_target_magic_pct = float(value)
			return
		"creation_adjacent_damage":
			creation_adjacent_damage = int(value)
			return
		"apply_weaken_enemy":
			apply_weaken_enemy = bool(value)
			return
		"cost_all_movement":
			cost_all_movement = bool(value)
			return
		"cleanse_target":
			cleanse_target = bool(value)
			return
		"mag_heal":
			mag_heal = bool(value)
			return
		"enemy_mag_atk":
			enemy_mag_atk = int(value)
			return
		"shield_closest_ally_pct_damage":
			shield_closest_ally_pct_damage = float(value)
			return
		"ally_str_per_debuff":
			ally_str_per_debuff = int(value)
			return
		"sanctuary":
			sanctuary = bool(value)
			return
		"sanctuary_enemy_push":
			sanctuary_enemy_push = int(value)
			return
		"creation_adjacent_push":
			creation_adjacent_push = int(value)
			return
		"holy_aura":
			holy_aura = bool(value)
			return
		"life_link":
			life_link = bool(value)
			return
		"life_link_reduction":
			life_link_reduction = int(value)
			return
		"revive_percent_max_hp":
			revive_percent_max_hp = float(value)
			return
		"spend_self_hp":
			spend_self_hp = int(value)
			return
		"revive_shield":
			revive_shield = int(value)
			return
		"holy_ground":
			holy_ground = bool(value)
			return
		"holy_ground_zone":
			holy_ground_zone = bool(value)
			return
		"holy_ground_def_down":
			holy_ground_def_down = int(value)
			return
		"stagger_if_debuffed":
			stagger_if_debuffed = bool(value)
			return
		"push":
			push = int(value)
			return
		"grant_ap":
			grant_ap = int(value)
			return
		"self_move_zero_next_turn":
			self_move_zero_next_turn = bool(value)
			return
		"link_two_enemies":
			link_two_enemies = bool(value)
			return
		"magic_link_damage":
			magic_link_damage = int(value)
			return
		"link_partner_pick":
			link_partner_pick = bool(value)
			return
		"link_blind":
			link_blind = bool(value)
			return
		"pullback":
			pullback = bool(value)
			return
		"pullback_ally_def":
			pullback_ally_def = int(value)
			return
		"movement_mp_override":
			movement_mp_override = int(value)
			return
		"swift_strike":
			swift_strike = bool(value)
			return
		"target_damaged_ap":
			target_damaged_ap = int(value)
			return
		"remove_push_mitigation":
			remove_push_mitigation = bool(value)
			return
		"prevent_target_shield":
			prevent_target_shield = bool(value)
			return
		"bonus_if_target_adjacent_to_ally":
			bonus_if_target_adjacent_to_ally = int(value)
			return
		"pierce":
			pierce = bool(value)
			return
		"target_def_pct_debuff":
			target_def_pct_debuff = float(value)
			return
		"target_def_pct_duration":
			target_def_pct_duration = int(value)
			return
		"if_target_attacked_caster_last_turn_bonus":
			if_target_attacked_caster_last_turn_bonus = int(value)
			return
		"if_target_attacked_caster_last_turn_stagger":
			if_target_attacked_caster_last_turn_stagger = bool(value)
			return
		"target_def_debuff":
			target_def_debuff = int(value)
			return
		"on_kill_all_allies_heal":
			on_kill_all_allies_heal = int(value)
			return
		"on_kill_all_allies_shield":
			on_kill_all_allies_shield = int(value)
			return
		"next_skill_zero_ap":
			next_skill_zero_ap = bool(value)
			return
		"smoke_on_start":
			smoke_on_start = bool(value)
			return
		"flank_run_adjacent_enemy_bonus":
			flank_run_adjacent_enemy_bonus = int(value)
			return
		"bleed_bonus_damage":
			bleed_bonus_damage = int(value)
			return
		"duelist_mark_target":
			duelist_mark_target = bool(value)
			return
		"marked_target_defense":
			marked_target_defense = int(value)
			return
		"unacted_target_ignore_def_pct":
			unacted_target_ignore_def_pct = float(value)
			return
		"leap_absorb_surface":
			leap_absorb_surface = bool(value)
			return
		"track_first_hit_zero":
			track_first_hit_zero = bool(value)
			return
		"chakra_shift":
			chakra_shift = bool(value)
			return
		"chakra_burst_damage":
			chakra_burst_damage = int(value)
			return
		"chakra_burst_shape":
			chakra_burst_shape = int(value)
			return
		"chakra_burst_size":
			chakra_burst_size = int(value)
			return
		"stop_adjacent_first_enemy":
			stop_adjacent_first_enemy = bool(value)
			return
		"dash_absorb_element":
			dash_absorb_element = bool(value)
			return
		"target_magic_defense":
			target_magic_defense = bool(value)
			return
		"steal_target_magic":
			steal_target_magic = int(value)
			return
		"next_turn_move_penalty":
			next_turn_move_penalty = int(value)
			return
		"bonus_per_target_status":
			bonus_per_target_status = int(value)
			return
		"mantra_peace_weaken":
			mantra_peace_weaken = bool(value)
			return
		"inner_fire":
			inner_fire = bool(value)
			return
		"inner_fire_surface":
			inner_fire_surface = bool(value)
			return
		"landed_magic_bonus":
			landed_magic_bonus = int(value)
			return
		"enemy_pushed_mov":
			enemy_pushed_mov = int(value)
			return
		"blind_on_pass_over":
			blind_on_pass_over = bool(value)
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
