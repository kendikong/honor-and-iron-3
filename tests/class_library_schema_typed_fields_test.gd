class_name ClassLibrarySchemaTypedFieldsTest
extends RefCounted


static func run_all(failures: Array[String]) -> void:
	var schema: Script = load("res://ui/class_library_schema.gd") as Script
	var source := AbilityModule.new()
	source.strip_stealth = true
	source.spread_status_adjacent = true
	source.next_ranged_attack_strength = 2
	source.allies_pierce = true
	source.trap_def_debuff = 2
	source.paired_ally_charge = true
	source.bonus_per_enemy_passed = 1
	source.create_trampled_terrain = true
	source.vault_obstacle_or_gap_only = true
	source.blink = true
	source.leave_elemental_surface = true
	source.reaction_terrain = &"fire"
	source.reaction_damage = 2
	source.bounce_surface_chain = true
	source.teleport_visible = true
	source.mana_shield = true
	source.kill_grant_ap = 1
	source.construct_hp_pct = 0.5
	source.ignore_target_magic_pct = 0.25
	source.mag_heal = true
	source.enemy_mag_atk = 4
	source.life_link = true
	source.life_link_reduction = 3
	source.revive_percent_max_hp = 0.1
	source.holy_ground = true
	source.link_blind = true
	source.cost_all_movement = true
	source.cleanse_target = true
	source.shield_closest_ally_pct_damage = 0.5
	source.ally_str_per_debuff = 1
	source.sanctuary = true
	source.sanctuary_enemy_push = 1
	source.creation_adjacent_push = 1
	source.holy_aura = true
	source.spend_self_hp = 10
	source.revive_shield = 2
	source.holy_ground_zone = true
	source.holy_ground_def_down = 1
	source.stagger_if_debuffed = true
	source.push = 2
	source.grant_ap = 1
	source.grant_scrap = 2
	source.self_move_zero_next_turn = true
	source.link_two_enemies = true
	source.magic_link_damage = 1
	source.link_partner_pick = true
	source.pullback = true
	source.pullback_ally_def = 2
	source.movement_mp_override = 1
	source.swift_strike = true
	source.target_damaged_ap = 1
	source.remove_push_mitigation = true
	source.prevent_target_shield = true
	source.bonus_if_target_adjacent_to_ally = 2
	source.next_attack_pierce = true
	source.target_def_pct_debuff = 0.25
	source.target_def_pct_duration = 2
	source.if_target_attacked_caster_last_turn_bonus = 2
	source.if_target_attacked_caster_last_turn_stagger = true
	source.target_def_debuff = 2
	source.on_kill_all_allies_heal = 1
	source.on_kill_all_allies_shield = 1
	source.next_skill_zero_ap = true
	source.smoke_on_start = true
	source.flank_run_adjacent_enemy_bonus = 2
	source.bleed_bonus_damage = 2
	source.duelist_mark_target = true
	source.marked_target_defense = 2
	source.unacted_target_ignore_def_pct = 0.5
	source.leap_absorb_surface = true
	source.track_first_hit_zero = true
	source.chakra_shift = true
	source.chakra_burst_damage = 1
	source.chakra_burst_shape = GameEnums.TargetShape.AOE_CROSS
	source.chakra_burst_size = 2
	source.stop_adjacent_first_enemy = true
	source.dash_absorb_element = true
	source.target_magic_defense = true
	source.steal_target_magic = 1
	source.next_turn_move_penalty = 2
	source.bonus_per_target_status = 1
	source.mantra_peace_weaken = true
	source.inner_fire = true
	source.inner_fire_surface = true
	source.landed_magic_bonus = 2
	source.enemy_pushed_mov = 1
	source.blind_on_pass_over = true
	source.relocate_target = true
	source.move_active_totem = true
	source.totem_kind = &"guard"
	source.pulse_aoe = 2
	source.pulse_heal = 1
	source.pulse_cleanse = true
	source.ghost_duration = 1
	source.ghost_hp_pct = 0.25
	source.pain_spike = true
	source.linked_enemy_damage = 1
	source.linked_enemy_blind = true
	source.slip_past = true
	source.land_opposite_target = true
	source.move_through_adjacent_unit = true
	source.kidnap = true
	source.swap_collision_stagger_both = true
	source.pierce_vs_blind = true
	source.hazard_blind_on_entry = true
	source.reposition_opposite_side = true
	source.reposition_movement_cost = 2
	source.reposition_range = 2
	source.pounce_land_adjacent = true
	source.feral_drag = true
	source.drag_remaining_movement = true
	source.redirect_incoming_damage = true
	source.drop_adjacent = true
	source.does_not_consume_action_slot = true
	source.limit_once_per_turn = true
	source.drop_trap_damage_multiplier = 2.0
	source.pull_before_attack = 1
	source.purge_buffs = true
	source.on_kill_shield = 2
	source.run_down_pass_adjacent_push = 1
	source.trample_atk = 2
	source.run_down_push_bleed_weapon = true
	source.intercept_push_attacker = 2
	source.airlift_pickup_step = 1
	source.airlift_drop_step = 3
	source.airlift_keep_caster = true
	source.airlift_ally_attack_strength = 1
	source.arrival_overclock = true
	source.target_def_pct_loss = 0.25
	source.on_hit_scrap = 1
	source.ignite_oil_area = true
	source.construct_spawn = true
	source.turret_attack = 1
	source.on_death_adjacent_damage = 2
	source.ignite_oil = true
	source.construct_destruction_refund_ap = 1
	source.mine_pull = 2
	source.mine_damage = 2
	source.mine_explode = true
	source.absorbs_items_scrap = true
	source.tesla_wall = true
	source.manual_detonation_stagger = true
	source.scrap_attack_bonus = 2
	source.scrap_bleed_weapon = true
	source.wrench_smack = true
	source.wrench_strength_bonus = 1
	source.emp_grenade = true
	source.mechanical_boss_damage_wpn = 3
	source.emp_friendly_construct_heal = 2
	source.emp_friendly_construct_overclock = true
	source.rocket_launcher = true
	source.exhaust_next_turn = true
	source.sacrifice_construct_instant = true
	source.scrap_shield = true
	source.scrap_multiplier = 2
	source.shield_depletion_explode = true
	source.manual_detonation = true
	source.refund_scrap = 1
	source.overdrive_injection = true
	source.construct_unmitigated_damage = 2
	source.refund_scrap_on_construct_death = 1
	source.barbed_wire = true
	source.entry_root = true
	source.adjacent_defense_bonus = 1
	var layer := AbilityLayer.new()
	layer.push_collision_pierce = true
	layer.crossing_blind = true
	layer.range_one_damage_multiplier = 0.7
	layer.damage_multiplier = 2.0
	layer.side_attack_only = true
	layer.target_after_move_adjacent = true
	layer.elemental_surface = true
	layer.reaction_terrain = &"frozen"
	layer.reaction_steam_splash = true
	layer.reaction_steam_splash_size = 1
	layer.reaction_steam_splash_damage = 2
	layer.set_max_move = 1
	layer.arcane_trail = true
	layer.creation_adjacent_damage = 1
	layer.terrain_id = &"fire"
	layer.hazard_duration = 2
	layer.counterattack_melee = true
	layer.counterattack_on_intercept = true
	layer.bleed_weapon = true
	layer.skip_terrain_entry_status = true
	layer.skip_terrain_entry_bleed = true
	layer.hazard_damage_bonus = 1
	layer.trap_damage_bonus = 2
	layer.grant_ap = 1
	layer.grant_scrap = 2
	layer.next_turn = true
	layer.burning_splash_magic = 2
	layer.burning_splash_shape = GameEnums.TargetShape.AOE_CROSS
	layer.pierce_if_first_zero = true
	layer.damage_adjacent_on_landing = true
	layer.require_dash_line_enemy = true
	layer.dash_absorb_element = true
	layer.collision_splash_damage = 2
	layer.collision_splash_weaken = true
	layer.push_if_target_on_water = 2
	layer.lightning_rod = true
	layer.construct_hp_pct = 0.5
	layer.spawn_furthest_empty_on_line = true
	layer.movement_penalty = 2
	layer.from_behind_only = true
	layer.hazard_blind_on_entry = true
	layer.poison_hazard = true
	layer.landing_push = 1
	layer.status_requires_debuff = true
	layer.cone_all_targets = true
	layer.wall_collision_stagger = true
	layer.oil_field = true
	source.layers.append(layer)
	var engineer_layer := AbilityLayer.new()
	engineer_layer.terrain_id = &"oil"
	engineer_layer.hazard_duration = 3
	engineer_layer.oil_field = true
	source.layers.append(engineer_layer)
	var encoded: Dictionary = schema.call("module_to_dict", source) as Dictionary
	var restored := AbilityModule.new()
	schema.call(
		"apply_module_dict", restored, encoded, GameEnums.PlannerGroup.PRE_MOVE,
	)
	_assert(failures, "strip_stealth", restored.strip_stealth)
	_assert(failures, "spread_status_adjacent", restored.spread_status_adjacent)
	_assert(failures, "next_ranged_attack_strength", restored.next_ranged_attack_strength == 2)
	_assert(failures, "allies_pierce", restored.allies_pierce)
	_assert(failures, "trap_def_debuff", restored.trap_def_debuff == 2)
	_assert(failures, "paired_ally_charge", restored.paired_ally_charge)
	_assert(failures, "bonus_per_enemy_passed", restored.bonus_per_enemy_passed == 1)
	_assert(failures, "create_trampled_terrain", restored.create_trampled_terrain)
	_assert(failures, "vault_obstacle_or_gap_only", restored.vault_obstacle_or_gap_only)
	_assert(failures, "blink", restored.blink)
	_assert(failures, "leave_elemental_surface", restored.leave_elemental_surface)
	_assert(failures, "reaction_terrain", restored.reaction_terrain == &"fire")
	_assert(failures, "reaction_damage", restored.reaction_damage == 2)
	_assert(failures, "bounce_surface_chain", restored.bounce_surface_chain)
	_assert(failures, "teleport_visible", restored.teleport_visible)
	_assert(failures, "mana_shield", restored.mana_shield)
	_assert(failures, "kill_grant_ap", restored.kill_grant_ap == 1)
	_assert(failures, "construct_hp_pct", is_equal_approx(restored.construct_hp_pct, 0.5))
	_assert(failures, "ignore_target_magic_pct", is_equal_approx(restored.ignore_target_magic_pct, 0.25))
	_assert(failures, "mag_heal", restored.mag_heal)
	_assert(failures, "enemy_mag_atk", restored.enemy_mag_atk == 4)
	_assert(failures, "life_link", restored.life_link)
	_assert(failures, "life_link_reduction", restored.life_link_reduction == 3)
	_assert(failures, "revive_percent_max_hp", is_equal_approx(restored.revive_percent_max_hp, 0.1))
	_assert(failures, "holy_ground", restored.holy_ground)
	_assert(failures, "link_blind", restored.link_blind)
	_assert(failures, "cost_all_movement", restored.cost_all_movement)
	_assert(failures, "cleanse_target", restored.cleanse_target)
	_assert(failures, "shield_closest_ally_pct_damage", is_equal_approx(restored.shield_closest_ally_pct_damage, 0.5))
	_assert(failures, "ally_str_per_debuff", restored.ally_str_per_debuff == 1)
	_assert(failures, "sanctuary", restored.sanctuary)
	_assert(failures, "sanctuary_enemy_push", restored.sanctuary_enemy_push == 1)
	_assert(failures, "creation_adjacent_push", restored.creation_adjacent_push == 1)
	_assert(failures, "holy_aura", restored.holy_aura)
	_assert(failures, "spend_self_hp", restored.spend_self_hp == 10)
	_assert(failures, "revive_shield", restored.revive_shield == 2)
	_assert(failures, "holy_ground_zone", restored.holy_ground_zone)
	_assert(failures, "holy_ground_def_down", restored.holy_ground_def_down == 1)
	_assert(failures, "stagger_if_debuffed", restored.stagger_if_debuffed)
	_assert(failures, "push", restored.push == 2)
	_assert(failures, "grant_ap", restored.grant_ap == 1)
	_assert(failures, "grant_scrap", restored.grant_scrap == 2)
	_assert(failures, "self_move_zero_next_turn", restored.self_move_zero_next_turn)
	_assert(failures, "link_two_enemies", restored.link_two_enemies)
	_assert(failures, "magic_link_damage", restored.magic_link_damage == 1)
	_assert(failures, "link_partner_pick", restored.link_partner_pick)
	_assert(failures, "pullback", restored.pullback)
	_assert(failures, "pullback_ally_def", restored.pullback_ally_def == 2)
	_assert(failures, "movement_mp_override", restored.movement_mp_override == 1)
	_assert(failures, "swift_strike", restored.swift_strike)
	_assert(failures, "target_damaged_ap", restored.target_damaged_ap == 1)
	_assert(failures, "remove_push_mitigation", restored.remove_push_mitigation)
	_assert(failures, "prevent_target_shield", restored.prevent_target_shield)
	_assert(failures, "bonus_if_target_adjacent_to_ally", restored.bonus_if_target_adjacent_to_ally == 2)
	_assert(failures, "next_attack_pierce", restored.next_attack_pierce)
	_assert(failures, "target_def_pct_debuff", is_equal_approx(restored.target_def_pct_debuff, 0.25))
	_assert(failures, "target_def_pct_duration", restored.target_def_pct_duration == 2)
	_assert(failures, "if_target_attacked_caster_last_turn_bonus", restored.if_target_attacked_caster_last_turn_bonus == 2)
	_assert(failures, "if_target_attacked_caster_last_turn_stagger", restored.if_target_attacked_caster_last_turn_stagger)
	_assert(failures, "target_def_debuff", restored.target_def_debuff == 2)
	_assert(failures, "on_kill_all_allies_heal", restored.on_kill_all_allies_heal == 1)
	_assert(failures, "on_kill_all_allies_shield", restored.on_kill_all_allies_shield == 1)
	_assert(failures, "next_skill_zero_ap", restored.next_skill_zero_ap)
	_assert(failures, "smoke_on_start", restored.smoke_on_start)
	_assert(failures, "flank_run_adjacent_enemy_bonus", restored.flank_run_adjacent_enemy_bonus == 2)
	_assert(failures, "bleed_bonus_damage", restored.bleed_bonus_damage == 2)
	_assert(failures, "duelist_mark_target", restored.duelist_mark_target)
	_assert(failures, "marked_target_defense", restored.marked_target_defense == 2)
	_assert(failures, "unacted_target_ignore_def_pct", is_equal_approx(restored.unacted_target_ignore_def_pct, 0.5))
	_assert(failures, "leap_absorb_surface", restored.leap_absorb_surface)
	_assert(failures, "track_first_hit_zero", restored.track_first_hit_zero)
	_assert(failures, "chakra_shift", restored.chakra_shift)
	_assert(failures, "chakra_burst_damage", restored.chakra_burst_damage == 1)
	_assert(failures, "chakra_burst_shape", restored.chakra_burst_shape == GameEnums.TargetShape.AOE_CROSS)
	_assert(failures, "chakra_burst_size", restored.chakra_burst_size == 2)
	_assert(failures, "stop_adjacent_first_enemy", restored.stop_adjacent_first_enemy)
	_assert(failures, "dash_absorb_element", restored.dash_absorb_element)
	_assert(failures, "target_magic_defense", restored.target_magic_defense)
	_assert(failures, "steal_target_magic", restored.steal_target_magic == 1)
	_assert(failures, "next_turn_move_penalty", restored.next_turn_move_penalty == 2)
	_assert(failures, "bonus_per_target_status", restored.bonus_per_target_status == 1)
	_assert(failures, "mantra_peace_weaken", restored.mantra_peace_weaken)
	_assert(failures, "inner_fire", restored.inner_fire)
	_assert(failures, "inner_fire_surface", restored.inner_fire_surface)
	_assert(failures, "landed_magic_bonus", restored.landed_magic_bonus == 2)
	_assert(failures, "enemy_pushed_mov", restored.enemy_pushed_mov == 1)
	_assert(failures, "blind_on_pass_over", restored.blind_on_pass_over)
	_assert(failures, "relocate_target", restored.relocate_target)
	_assert(failures, "move_active_totem", restored.move_active_totem)
	_assert(failures, "totem_kind", restored.totem_kind == &"guard")
	_assert(failures, "pulse_aoe", restored.pulse_aoe == 2)
	_assert(failures, "pulse_heal", restored.pulse_heal == 1)
	_assert(failures, "pulse_cleanse", restored.pulse_cleanse)
	_assert(failures, "ghost_duration", restored.ghost_duration == 1)
	_assert(failures, "ghost_hp_pct", is_equal_approx(restored.ghost_hp_pct, 0.25))
	_assert(failures, "pain_spike", restored.pain_spike)
	_assert(failures, "linked_enemy_damage", restored.linked_enemy_damage == 1)
	_assert(failures, "linked_enemy_blind", restored.linked_enemy_blind)
	_assert(failures, "slip_past", restored.slip_past)
	_assert(failures, "land_opposite_target", restored.land_opposite_target)
	_assert(failures, "move_through_adjacent_unit", restored.move_through_adjacent_unit)
	_assert(failures, "kidnap", restored.kidnap)
	_assert(failures, "swap_collision_stagger_both", restored.swap_collision_stagger_both)
	_assert(failures, "pierce_vs_blind", restored.pierce_vs_blind)
	_assert(failures, "hazard_blind_on_entry", restored.hazard_blind_on_entry)
	_assert(
		failures,
		"beast_module_typed_fields",
		restored.reposition_opposite_side
		and restored.reposition_movement_cost == 2
		and restored.reposition_range == 2
		and restored.pounce_land_adjacent
		and restored.feral_drag
		and restored.drag_remaining_movement
		and restored.redirect_incoming_damage
		and restored.drop_adjacent
		and restored.does_not_consume_action_slot
		and is_equal_approx(restored.drop_trap_damage_multiplier, 2.0)
		and restored.pull_before_attack == 1
		and restored.purge_buffs
		and restored.on_kill_shield == 2
		and restored.run_down_pass_adjacent_push == 1
		and restored.trample_atk == 2
		and restored.run_down_push_bleed_weapon
		and restored.intercept_push_attacker == 2
		and restored.airlift_pickup_step == 1
		and restored.airlift_drop_step == 3
		and restored.airlift_keep_caster
		and restored.airlift_ally_attack_strength == 1,
	)
	_assert(
		failures,
		"beast_layer_typed_fields",
		restored.layers[0].landing_push == 1
		and restored.layers[0].status_requires_debuff
		and restored.layers[0].cone_all_targets
		and restored.layers[0].wall_collision_stagger
		and restored.layers[0].oil_field,
	)
	_assert(
		failures,
		"engineer_layer_schema_fields",
		restored.layers.size() > 1
		and restored.layers[1].terrain_id == &"oil"
		and restored.layers[1].hazard_duration == 3
		and restored.layers[1].oil_field,
	)
	_assert(
		failures,
		"engineer_module_typed_fields",
		restored.does_not_consume_action_slot
		and restored.limit_once_per_turn
		and restored.arrival_overclock
		and is_equal_approx(restored.target_def_pct_loss, 0.25)
		and restored.on_hit_scrap == 1
		and restored.ignite_oil_area
		and restored.construct_spawn
		and restored.turret_attack == 1
		and restored.on_death_adjacent_damage == 2
		and restored.ignite_oil
		and restored.construct_destruction_refund_ap == 1
		and restored.mine_pull == 2
		and restored.mine_damage == 2
		and restored.mine_explode
		and restored.absorbs_items_scrap
		and restored.tesla_wall
		and restored.manual_detonation_stagger
		and restored.scrap_attack_bonus == 2
		and restored.scrap_bleed_weapon
		and restored.wrench_smack
		and restored.wrench_strength_bonus == 1
		and restored.emp_grenade
		and restored.mechanical_boss_damage_wpn == 3
		and restored.emp_friendly_construct_heal == 2
		and restored.emp_friendly_construct_overclock
		and restored.rocket_launcher
		and restored.exhaust_next_turn
		and restored.sacrifice_construct_instant
		and restored.scrap_shield
		and restored.scrap_multiplier == 2
		and restored.shield_depletion_explode
		and restored.manual_detonation
		and restored.refund_scrap == 1
		and restored.overdrive_injection
		and restored.construct_unmitigated_damage == 2
		and restored.refund_scrap_on_construct_death == 1
		and restored.barbed_wire
		and restored.entry_root
		and restored.adjacent_defense_bonus == 1,
	)
	_assert(failures, "layer_push_collision_pierce", restored.layers[0].push_collision_pierce)
	_assert(failures, "layer_crossing_blind", restored.layers[0].crossing_blind)
	_assert(failures, "layer_elemental_surface", restored.layers[0].elemental_surface)
	_assert(failures, "layer_reaction_terrain", restored.layers[0].reaction_terrain == &"frozen")
	_assert(failures, "layer_reaction_steam_splash", restored.layers[0].reaction_steam_splash)
	_assert(failures, "layer_reaction_steam_splash_size", restored.layers[0].reaction_steam_splash_size == 1)
	_assert(failures, "layer_reaction_steam_splash_damage", restored.layers[0].reaction_steam_splash_damage == 2)
	_assert(failures, "layer_set_max_move", restored.layers[0].set_max_move == 1)
	_assert(failures, "layer_arcane_trail", restored.layers[0].arcane_trail)
	_assert(failures, "layer_creation_adjacent_damage", restored.layers[0].creation_adjacent_damage == 1)
	_assert(failures, "layer_terrain_id", restored.layers[0].terrain_id == &"fire")
	_assert(failures, "layer_hazard_duration", restored.layers[0].hazard_duration == 2)
	_assert(failures, "layer_counterattack_melee", restored.layers[0].counterattack_melee)
	_assert(failures, "layer_counterattack_on_intercept", restored.layers[0].counterattack_on_intercept)
	_assert(failures, "layer_bleed_weapon", restored.layers[0].bleed_weapon)
	_assert(failures, "layer_skip_terrain_entry_status", restored.layers[0].skip_terrain_entry_status)
	_assert(failures, "layer_skip_terrain_entry_bleed", restored.layers[0].skip_terrain_entry_bleed)
	_assert(failures, "layer_hazard_damage_bonus", restored.layers[0].hazard_damage_bonus == 1)
	_assert(failures, "layer_trap_damage_bonus", restored.layers[0].trap_damage_bonus == 2)
	_assert(failures, "layer_grant_ap", restored.layers[0].grant_ap == 1)
	_assert(failures, "layer_grant_scrap", restored.layers[0].grant_scrap == 2)
	_assert(failures, "layer_next_turn", restored.layers[0].next_turn)
	_assert(failures, "layer_burning_splash_magic", restored.layers[0].burning_splash_magic == 2)
	_assert(failures, "layer_burning_splash_shape", restored.layers[0].burning_splash_shape == GameEnums.TargetShape.AOE_CROSS)
	_assert(failures, "layer_pierce_if_first_zero", restored.layers[0].pierce_if_first_zero)
	_assert(failures, "layer_damage_adjacent_on_landing", restored.layers[0].damage_adjacent_on_landing)
	_assert(failures, "layer_require_dash_line_enemy", restored.layers[0].require_dash_line_enemy)
	_assert(failures, "layer_dash_absorb_element", restored.layers[0].dash_absorb_element)
	_assert(failures, "layer_collision_splash_damage", restored.layers[0].collision_splash_damage == 2)
	_assert(failures, "layer_collision_splash_weaken", restored.layers[0].collision_splash_weaken)
	_assert(failures, "layer_push_if_target_on_water", restored.layers[0].push_if_target_on_water == 2)
	_assert(failures, "layer_lightning_rod", restored.layers[0].lightning_rod)
	_assert(failures, "layer_construct_hp_pct", is_equal_approx(restored.layers[0].construct_hp_pct, 0.5))
	_assert(failures, "layer_spawn_furthest_empty_on_line", restored.layers[0].spawn_furthest_empty_on_line)
	_assert(failures, "layer_movement_penalty", restored.layers[0].movement_penalty == 2)
	_assert(failures, "layer_from_behind_only", restored.layers[0].from_behind_only)
	_assert(failures, "layer_hazard_blind_on_entry", restored.layers[0].hazard_blind_on_entry)
	_assert(failures, "layer_poison_hazard", restored.layers[0].poison_hazard)
	var copied := AbilityModule.new()
	DataLibrary._copy_extras(source, copied)
	_assert(failures, "copy_cleric_life_link", copied.life_link)
	_assert(failures, "copy_cleric_sanctuary", copied.sanctuary)
	_assert(failures, "copy_cleric_revive", is_equal_approx(copied.revive_percent_max_hp, 0.1))
	_assert(failures, "copy_cleric_link", copied.link_two_enemies and copied.magic_link_damage == 1)
	_assert(
		failures,
		"layer_range_one_damage_multiplier",
		is_equal_approx(restored.layers[0].range_one_damage_multiplier, 0.7),
	)
	_assert(
		failures,
		"layer_damage_multiplier",
		is_equal_approx(restored.layers[0].damage_multiplier, 2.0),
	)
	_assert(failures, "layer_side_attack_only", restored.layers[0].side_attack_only)
	_assert(
		failures,
		"layer_target_after_move_adjacent",
		restored.layers[0].target_after_move_adjacent,
	)
	_assert(
		failures,
		"copy_monk_surface_combo",
		copied.leap_absorb_surface
		and copied.chakra_burst_shape == GameEnums.TargetShape.AOE_CROSS
		and copied.landed_magic_bonus == 2,
	)
	_assert(
		failures,
		"copy_shaman_typed_fields",
		copied.totem_kind == &"guard"
		and copied.ghost_duration == 1
		and copied.pain_spike
		and copied.linked_enemy_damage == 1,
	)
	_assert(
		failures,
		"copy_rogue_typed_fields",
		copied.slip_past
		and copied.kidnap
		and copied.swap_collision_stagger_both
		and copied.hazard_blind_on_entry,
	)
	_assert(
		failures,
		"copy_beast_rider_typed_fields",
		copied.reposition_opposite_side
		and copied.reposition_movement_cost == 2
		and copied.pounce_land_adjacent
		and copied.feral_drag
		and copied.drop_trap_damage_multiplier == 2.0
		and copied.run_down_push_bleed_weapon
		and copied.airlift_drop_step == 3,
	)
	var copied_beast_module := source.duplicate(true) as AbilityModule
	_assert(
		failures,
		"copy_beast_rider_layer_typed_fields",
		copied_beast_module.layers.size() >= 1
		and copied_beast_module.layers[0].landing_push == 1
		and copied_beast_module.layers[0].status_requires_debuff
		and copied_beast_module.layers[0].cone_all_targets
		and copied_beast_module.layers[0].wall_collision_stagger,
	)
	_assert(
		failures,
		"copy_engineer_typed_fields",
		copied.arrival_overclock
		and is_equal_approx(copied.target_def_pct_loss, 0.25)
		and copied.construct_spawn
		and copied.turret_attack == 1
		and copied.mine_pull == 2
		and copied.mine_damage == 2
		and copied.mine_explode
		and copied.scrap_attack_bonus == 2
		and copied.scrap_bleed_weapon
		and copied.emp_grenade
		and copied.rocket_launcher
		and copied.sacrifice_construct_instant
		and copied.scrap_shield
		and copied.manual_detonation
		and copied.overdrive_injection
		and copied.barbed_wire
		and copied.adjacent_defense_bonus == 1,
	)


static func _assert(failures: Array[String], key: String, condition: bool) -> void:
	if not condition:
		failures.append("typed schema roundtrip lost %s" % key)
