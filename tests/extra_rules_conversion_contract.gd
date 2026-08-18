class_name ExtraRulesConversionContract
extends RefCounted

## Fail-loud Extra Rules conversion bar.
## Add an ability id to CONVERTED_SKILL_IDS only after extras and leftover Extra Rule keys are gone.

const CONVERTED_SKILL_IDS: Array[StringName] = [
	&"knight_defensive_formation",
	&"bruiser_push_through",
	&"bruiser_charge_strike",
	&"bruiser_concussion_blow",
	&"bruiser_cleave",
	&"bruiser_suplex",
	&"bruiser_adrenaline_surge",
	&"bruiser_earthshatter",
	&"bruiser_meat_shield",
	&"bruiser_frenzy",
	&"bruiser_guttural_roar",
	&"bruiser_headbutt",
	&"bruiser_blood_boil",
	&"bruiser_violent_collision",
	&"bruiser_crimson_whirlwind",
	&"bruiser_belly_flop",
	&"bruiser_breaching_dash",
	&"archer_sidestep",
	&"archer_power_shot",
	&"archer_volley",
	&"archer_pinning_arrow",
	&"archer_piercing_shot",
	&"archer_toxic_spore_arrow",
	&"archer_grapple_arrow",
	&"archer_explosive_arrow",
	&"archer_hunters_mark",
	&"archer_repelling_shot",
	&"archer_bear_trap",
	&"archer_suppressing_fire",
	&"archer_caltrop_trap",
	&"archer_parting_shot",
	&"archer_scouts_eye",
	&"lancer_push",
	&"lancer_piercing_charge",
	&"lancer_sweeping_halberd",
	&"lancer_vaulting_leap",
	&"lancer_run_down",
	&"lancer_rallying_cry",
	&"lancer_flanking_maneuver",
	&"lancer_brace",
	&"lancer_harpoon_toss",
	&"lancer_glorious_charge",
	&"lancer_pole_vault",
	&"lancer_line_breaker",
	&"lancer_spear_wall",
	&"lancer_meteor_drop",
	&"mage_blink",
	&"mage_fireball",
	&"mage_ice_shard",
	&"mage_chain_lightning",
	&"mage_arcane_push",
	&"mage_teleport",
	&"mage_meteor",
	&"mage_black_hole",
	&"mage_time_warp",
	&"mage_mana_shield",
	&"mage_disintegrate",
	&"mage_gravity_well",
	&"mage_elemental_surge",
	&"mage_earth_spike",
	&"mage_density_shift",
	&"mage_arcane_barrage",
	&"cleric_guardian_step",
	&"cleric_holy_light",
	&"cleric_smite",
	&"cleric_cleansing_aura",
	&"cleric_sanctuary",
	&"cleric_divine_hammer",
	&"cleric_life_link",
	&"cleric_blinding_ray",
	&"cleric_prayer_of_fortitude",
	&"cleric_resurrection",
	&"cleric_consecrate_ground",
	&"cleric_holy_wrath",
	&"cleric_divine_guidance",
	&"cleric_shield_of_faith",
	&"cleric_martyrs_chains",
	&"mercenary_pullback",
	&"mercenary_swift_strike",
	&"mercenary_defense_strike",
	&"mercenary_blade_storm",
	&"mercenary_caltrop_toss",
	&"mercenary_feint",
	&"mercenary_riposte_strike",
	&"mercenary_sever",
	&"mercenary_second_wind",
	&"mercenary_tactical_retreat",
	&"mercenary_executioners_blade",
	&"mercenary_precision_strike",
	&"mercenary_flank_and_run",
	&"mercenary_hamstring",
	&"mercenary_acrobatic_vault",
	&"mercenary_duelists_challenge",
	&"monk_leap",
	&"monk_scorching_kick",
	&"monk_thunder_palm",
	&"monk_yin_yang_flurry",
	&"monk_chakra_shift",
	&"monk_phase_throw",
	&"monk_flying_crane_kick",
	&"monk_spirit_palm",
	&"monk_soul_punch",
	&"monk_hundred_fists",
	&"monk_mantra_of_peace",
	&"monk_inner_fire",
	&"monk_void_step",
	&"monk_cyclone_sweep",
	&"monk_updraft",
	&"monk_geyser_strike",
	&"rogue_slip_past",
	&"rogue_shadow_step",
	&"rogue_kidney_strike",
	&"rogue_smoke_bomb",
	&"rogue_evasive_strike",
	&"rogue_grappling_hook",
	&"rogue_switcheroo",
	&"rogue_shadow_swap",
	&"rogue_blindside",
	&"rogue_throat_slit",
	&"rogue_amnesia_dust",
	&"rogue_death_mark",
	&"rogue_lethal_flourish",
	&"rogue_kidnap",
	&"rogue_shuriken_volley",
	&"rogue_poison_flask",
	&"beast_reposition",
	&"beast_pounce",
	&"beast_feral_drag",
	&"beast_maul",
	&"beast_bestial_roar",
	&"beast_raking_claws",
	&"beast_rest_recover",
	&"beast_intimidate",
	&"beast_fetch",
	&"beast_savage_bite",
	&"beast_run_down",
	&"beast_thrash",
	&"beast_defensive_posture",
	&"beast_airlift",
	&"beast_tail_swipe",
	&"beast_gore",
	&"engineer_recall",
	&"engineer_dismantle",
	&"engineer_sludge_bomb",
	&"engineer_construct_turret",
	&"engineer_frag_bomb",
	&"engineer_magnetic_mine",
	&"engineer_tesla_barricade",
	&"engineer_flak_cannon",
	&"engineer_wrench_smack",
	&"engineer_emp_grenade",
	&"engineer_rocket_launcher",
	&"engineer_scrap_shield",
	&"engineer_manual_detonation",
	&"engineer_overdrive_injection",
	&"engineer_barbed_wire",
	&"shaman_usher",
	&"shaman_curse_of_weakness",
	&"shaman_healing_totem",
	&"shaman_flame_totem",
	&"shaman_bloodlust",
	&"shaman_hex",
	&"shaman_voodoo_link",
	&"shaman_terrify",
	&"shaman_miasma",
	&"shaman_bone_spear",
	&"shaman_ancestral_spirit",
	&"shaman_totem_guard",
	&"shaman_sympathetic_bond",
	&"shaman_earthbind_totem",
	&"shaman_soul_siphon",
	&"shaman_pain_spike",
]

const CLASS_IDS: Array[StringName] = [
	&"knight",
	&"bruiser",
	&"archer",
	&"lancer",
	&"mage",
	&"cleric",
	&"mercenary",
	&"monk",
	&"rogue",
	&"beast_rider",
	&"engineer",
	&"shaman",
]

static func run_all(failures: Array[String]) -> void:
	_check_converted_skills(failures)

static func _check_converted_skills(failures: Array[String]) -> void:
	for skill_id: StringName in CONVERTED_SKILL_IDS:
		var ability: AbilityData = _find_ability(skill_id)
		if ability == null:
			failures.append("CONVERTED_SKILL_IDS missing ability %s" % String(skill_id))
			continue
		_assert_skill_converted(ability, failures)

static func _assert_skill_converted(ability: AbilityData, failures: Array[String]) -> void:
	var label := String(ability.id)
	_assert_modules_converted(label, "base", ability.modules, failures)
	_assert_modules_converted(label, "upgrade", ability.upgraded_modules, failures)

static func _assert_modules_converted(
	label: String,
	profile: String,
	modules: Array[AbilityModule],
	failures: Array[String]
) -> void:
	for module: AbilityModule in modules:
		if module == null:
			continue
		for layer: AbilityLayer in module.layers:
			if layer == null or layer.effect == null:
				continue
			for key: Variant in layer.effect.modifiers:
				var key_text := String(key)
				if not _has_typed_owner(module, layer, key_text):
					failures.append("%s %s leftover untyped runtime key %s" % [label, profile, key_text])


static func _has_typed_owner(module: AbilityModule, layer: AbilityLayer, key: String) -> bool:
	match key:
		"exclude_caster":
			return module.exclude_caster
		"terrain_id":
			return module.terrain_id != StringName() or layer.terrain_id != StringName()
		"hazard_duration":
			return module.hazard_duration != 0 or layer.hazard_duration != 0
		"cost_all_movement":
			return module.cost_all_movement
		"cleanse_target":
			return module.cleanse_target
		"mag_heal":
			return module.mag_heal
		"enemy_mag_atk":
			return module.enemy_mag_atk != 0
		"shield_closest_ally_pct_damage":
			return not is_zero_approx(module.shield_closest_ally_pct_damage)
		"ally_str_per_debuff":
			return module.ally_str_per_debuff != 0
		"sanctuary":
			return module.sanctuary
		"sanctuary_enemy_push":
			return module.sanctuary_enemy_push != 0
		"creation_adjacent_push":
			return module.creation_adjacent_push != 0
		"holy_aura":
			return module.holy_aura
		"life_link":
			return module.life_link
		"life_link_reduction":
			return module.life_link_reduction != 0
		"revive_percent_max_hp":
			return not is_zero_approx(module.revive_percent_max_hp)
		"spend_self_hp":
			return module.spend_self_hp != 0
		"revive_shield":
			return module.revive_shield != 0
		"holy_ground":
			return module.holy_ground
		"holy_ground_zone":
			return module.holy_ground_zone
		"holy_ground_def_down":
			return module.holy_ground_def_down != 0
		"stagger_if_debuffed":
			return module.stagger_if_debuffed
		"push":
			return module.push != 0
		"grant_ap":
			return module.grant_ap != 0 or layer.grant_ap != 0
		"grant_scrap":
			return module.grant_scrap != 0 or layer.grant_scrap != 0
		"self_move_zero_next_turn":
			return module.self_move_zero_next_turn
		"link_two_enemies":
			return module.link_two_enemies
		"magic_link_damage":
			return module.magic_link_damage != 0
		"link_partner_pick":
			return module.link_partner_pick
		"link_blind":
			return module.link_blind
		"counterattack_melee":
			return layer.counterattack_melee
		"counterattack_on_intercept":
			return layer.counterattack_on_intercept
		"pullback":
			return module.pullback
		"pullback_ally_def":
			return module.pullback_ally_def != 0
		"movement_mp_override":
			return module.movement_mp_override != 0
		"swift_strike":
			return module.swift_strike
		"target_damaged_ap":
			return module.target_damaged_ap != 0
		"remove_push_mitigation":
			return module.remove_push_mitigation
		"prevent_target_shield":
			return module.prevent_target_shield
		"bonus_if_target_adjacent_to_ally":
			return module.bonus_if_target_adjacent_to_ally != 0
		"next_attack_pierce":
			return module.next_attack_pierce
		"pierce":
			return module.pierce
		"target_def_pct_debuff":
			return not is_zero_approx(module.target_def_pct_debuff)
		"target_def_pct_duration":
			return module.target_def_pct_duration != 0
		"if_target_attacked_caster_last_turn_bonus":
			return module.if_target_attacked_caster_last_turn_bonus != 0
		"if_target_attacked_caster_last_turn_stagger":
			return module.if_target_attacked_caster_last_turn_stagger
		"target_def_debuff":
			return module.target_def_debuff != 0
		"on_kill_all_allies_heal":
			return module.on_kill_all_allies_heal != 0
		"on_kill_all_allies_shield":
			return module.on_kill_all_allies_shield != 0
		"next_skill_zero_ap":
			return module.next_skill_zero_ap
		"smoke_on_start":
			return module.smoke_on_start
		"flank_run_adjacent_enemy_bonus":
			return module.flank_run_adjacent_enemy_bonus != 0
		"bleed_bonus_damage":
			return module.bleed_bonus_damage != 0
		"duelist_mark_target":
			return module.duelist_mark_target
		"marked_target_defense":
			return module.marked_target_defense != 0
		"unacted_target_ignore_def_pct":
			return not is_zero_approx(module.unacted_target_ignore_def_pct)
		"bleed_weapon":
			return module.next_attack_bleed_weapon or layer.bleed_weapon
		"skip_terrain_entry_status":
			return layer.skip_terrain_entry_status
		"skip_terrain_entry_bleed":
			return layer.skip_terrain_entry_bleed
		"hazard_damage_bonus":
			return layer.hazard_damage_bonus != 0
		"trap_damage_bonus":
			return layer.trap_damage_bonus != 0
		"hazard_status":
			return module.hazard_status != GameEnums.StatusType.NONE
		"bonus_dmg_from_occupied":
			return module.bonus_dmg_from_occupied != 0
		"bonus_dmg_per_10_hp":
			return module.bonus_dmg_per_10_hp != 0
		"bonus_dmg_pct_max_hp":
			return not is_zero_approx(module.bonus_dmg_pct_max_hp)
		"heal_if_targets_gte":
			return module.heal_if_targets_gte != 0
		"bounce_count":
			return module.bounce_count != 0
		"bounce_range":
			return module.bounce_range != 0
		"buff_on_push":
			return module.buff_on_push != 0
		"frenzy_on_kill_ap":
			return module.frenzy_on_kill_ap != 0
		"push_board_items":
			return module.push_board_items != 0
		"item_collision_damage":
			return module.item_collision_damage != 0
		"item_collision_str_div":
			return module.item_collision_str_div != 0
		"item_collision_vulnerable":
			return module.item_collision_vulnerable != 0
		"violent_collision_recast":
			return module.violent_collision_recast != 0
		"next_attack_strength":
			return module.next_attack_strength != 0
		"next_turn":
			return module.next_turn or layer.next_turn
		"preserve_facing":
			return module.preserve_facing
		"ignore_zoc":
			return module.ignore_zoc
		"next_ranged_attack_strength":
			return module.next_ranged_attack_strength != 0
		"root_break_on_damage":
			return module.root_break_on_damage
		"skewer":
			return module.skewer != 0
		"bounce_walls_45":
			return module.bounce_walls_45
		"spread_status_adjacent":
			return module.spread_status_adjacent
		"grapple_wall_pull_self":
			return module.grapple_wall_pull_self
		"grapple_pass_through_damage":
			return module.grapple_pass_through_damage != 0 or layer.grapple_pass_through_damage != 0
		"destroy_terrain":
			return module.destroy_terrain
		"ignite_flammable_terrain":
			return module.ignite_flammable_terrain or layer.ignite_flammable_terrain
		"allies_range_bonus":
			return module.allies_range_bonus != 0
		"allies_pierce":
			return module.allies_pierce
		"prevent_stealth_teleport":
			return module.prevent_stealth_teleport
		"allow_friendly_target":
			return module.allow_friendly_target
		"ally_damage_zero":
			return module.ally_damage_zero or layer.ally_damage_zero
		"trap_status":
			return module.terrain_hazard_status != GameEnums.StatusType.NONE
		"trap_damage":
			return module.trap_damage != 0
		"trap_bleed_weapon":
			return module.trap_bleed_weapon
		"trap_vulnerable":
			return module.trap_vulnerable or layer.trap_vulnerable
		"crossing_weapon_damage":
			return module.crossing_weapon_damage
		"crossing_mov_penalty":
			return module.crossing_mov_penalty != 0
		"crossing_blind":
			return module.crossing_blind or layer.crossing_blind
		"trap_def_debuff":
			return module.trap_def_debuff != 0 or layer.trap_def_debuff != 0
		"range_one_damage_multiplier":
			return (
				not is_zero_approx(module.range_one_damage_multiplier)
				or not is_zero_approx(layer.range_one_damage_multiplier)
			)
		"damage_multiplier":
			return not is_zero_approx(layer.damage_multiplier)
		"side_attack_only":
			return layer.side_attack_only
		"target_after_move_adjacent":
			return layer.target_after_move_adjacent
		"l_shape_move":
			return module.l_shape_move
		"create_trampled_terrain":
			return module.create_trampled_terrain
		"limit_once_per_turn":
			return module.limit_once_per_turn
		"halve_target_def_one_turn":
			return module.halve_target_def_one_turn
		"armor_explosion_atk":
			return module.armor_explosion_atk != 0
		"bonus_atk_vs_fear_or_lower_movement":
			return module.bonus_atk_vs_fear_or_lower_movement != 0
		"on_kill_max_move":
			return module.on_kill_max_move != 0
		"next_turn_max_move":
			return module.next_turn_max_move != 0
		"upgraded_trample":
			return module.upgraded_trample
		"brace_attacker_stagger":
			return module.brace_attacker_stagger != 0
		"pull_until_adjacent":
			return module.pull_until_adjacent
		"pull_self_if_rooted":
			return module.pull_self_if_rooted
		"line_breaker":
			return module.line_breaker
		"vault_obstacle_or_gap_only":
			return module.vault_obstacle_or_gap_only
		"landing_adjacent_push":
			return module.landing_adjacent_push != 0
		"landing_adjacent_push_stagger":
			return module.landing_adjacent_push_stagger
		"bonus_per_enemy_passed":
			return module.bonus_per_enemy_passed != 0
		"blink":
			return module.blink
		"leave_elemental_surface":
			return module.leave_elemental_surface
		"reaction_terrain":
			return module.reaction_terrain != StringName() or layer.reaction_terrain != StringName()
		"reaction_damage":
			return module.reaction_damage != 0
		"surface_chain":
			return module.bounce_surface_chain
		"lightning":
			return module.lightning_surface
		"strike_all_surface":
			return module.strike_all_surface
		"teleport_visible":
			return module.teleport_visible
		"delayed_next_turn":
			return module.delayed_next_turn
		"create_crater":
			return module.create_crater
		"pull_to_center":
			return module.pull_to_center
		"pull_surfaces":
			return module.pull_surfaces
		"mana_shield":
			return module.mana_shield
		"mana_shield_casting":
			return module.mana_shield_casting
		"destroy_corpse_on_kill":
			return module.destroy_corpse_on_kill
		"kill_grant_ap":
			return module.kill_grant_ap != 0
		"utility_only":
			return module.utility_only
		"elemental_surge":
			return module.elemental_surge
		"elemental_surge_ap":
			return module.elemental_surge_ap != 0
		"construct_hp_pct":
			return (
				not is_zero_approx(module.construct_hp_pct)
				or not is_zero_approx(layer.construct_hp_pct)
			)
		"slip_past":
			return module.slip_past
		"land_opposite_target":
			return module.land_opposite_target
		"move_through_adjacent_unit":
			return module.move_through_adjacent_unit
		"ally_def_buff":
			return module.ally_def_buff != 0
		"shadow_step":
			return module.shadow_step
		"behind_target_strength":
			return module.behind_target_strength != 0
		"smoke_field":
			return module.smoke_field
		"smoke_stealth_outside_attackers":
			return module.smoke_stealth_outside_attackers
		"smoke_ally_heal_per_turn":
			return module.smoke_ally_heal_per_turn != 0
		"grapple_bidirectional":
			return module.grapple_bidirectional
		"pull_self_or_target":
			return module.pull_self_or_target
		"trap_collision_damage_multiplier":
			return module.trap_collision_damage_multiplier != 0
		"switcheroo":
			return module.switcheroo
		"inherit_incoming_attacks":
			return module.inherit_incoming_attacks
		"if_target_unacted_stagger":
			return module.if_target_unacted_stagger
		"if_target_staggered_bonus":
			return module.if_target_staggered_bonus != 0
		"on_kill_spread_silence_adjacent":
			return module.on_kill_spread_silence_adjacent
		"confusion_next_turn":
			return module.confusion_next_turn
		"on_kill_refresh_mark_zero_ap":
			return module.on_kill_refresh_mark_zero_ap
		"bonus_if_target_debuffed":
			return module.bonus_if_target_debuffed != 0
		"kidnap":
			return module.kidnap
		"swap_collision_stagger_both":
			return module.swap_collision_stagger_both
		"pierce_vs_blind":
			return module.pierce_vs_blind
		"hazard_blind_on_entry":
			return module.hazard_blind_on_entry
		"enemy_collision_stagger_both":
			return module.enemy_collision_stagger_both or layer.enemy_collision_stagger_both
		"movement_penalty":
			return layer.movement_penalty != 0
		"from_behind_only":
			return layer.from_behind_only
		"poison_hazard":
			return layer.poison_hazard
		"reposition_opposite_side":
			return module.reposition_opposite_side
		"reposition_movement_cost":
			return module.reposition_movement_cost != 0
		"reposition_range":
			return module.reposition_range != 0
		"pounce_land_adjacent":
			return module.pounce_land_adjacent
		"feral_drag":
			return module.feral_drag
		"drag_remaining_movement":
			return module.drag_remaining_movement
		"redirect_incoming_damage":
			return module.redirect_incoming_damage
		"drop_adjacent":
			return module.drop_adjacent
		"does_not_consume_action_slot":
			return module.does_not_consume_action_slot
		"drop_trap_damage_multiplier":
			return not is_zero_approx(module.drop_trap_damage_multiplier)
		"pull_before_attack":
			return module.pull_before_attack != 0
		"purge_buffs":
			return module.purge_buffs
		"on_kill_shield":
			return module.on_kill_shield != 0
		"run_down_pass_adjacent_push":
			return module.run_down_pass_adjacent_push != 0
		"trample_atk":
			return module.trample_atk != 0
		"run_down_push_bleed_weapon":
			return module.run_down_push_bleed_weapon
		"intercept_push_attacker":
			return module.intercept_push_attacker != 0
		"airlift_pickup_step":
			return module.airlift_pickup_step != 0
		"airlift_drop_step":
			return module.airlift_drop_step != 0
		"airlift_keep_caster":
			return module.airlift_keep_caster
		"airlift_ally_attack_strength":
			return module.airlift_ally_attack_strength != 0
		"landing_push":
			return layer.landing_push != 0
		"status_requires_debuff":
			return layer.status_requires_debuff
		"cone_all_targets":
			return layer.cone_all_targets
		"wall_collision_stagger":
			return layer.wall_collision_stagger
		"oil_field":
			return layer.oil_field
		"arrival_overclock":
			return module.arrival_overclock
		"target_def_pct_loss":
			return not is_zero_approx(module.target_def_pct_loss)
		"on_hit_scrap":
			return module.on_hit_scrap != 0
		"ignite_oil_area":
			return module.ignite_oil_area
		"construct_spawn":
			return module.construct_spawn
		"turret_attack":
			return module.turret_attack != 0
		"on_death_adjacent_damage":
			return module.on_death_adjacent_damage != 0
		"ignite_oil":
			return module.ignite_oil
		"construct_destruction_refund_ap":
			return module.construct_destruction_refund_ap != 0
		"mine_pull":
			return module.mine_pull != 0
		"mine_damage":
			return module.mine_damage != 0
		"mine_explode":
			return module.mine_explode
		"absorbs_items_scrap":
			return module.absorbs_items_scrap
		"tesla_wall":
			return module.tesla_wall
		"manual_detonation_stagger":
			return module.manual_detonation_stagger
		"scrap_attack_bonus":
			return module.scrap_attack_bonus != 0
		"scrap_bleed_weapon":
			return module.scrap_bleed_weapon
		"wrench_smack":
			return module.wrench_smack
		"wrench_strength_bonus":
			return module.wrench_strength_bonus != 0
		"emp_grenade":
			return module.emp_grenade
		"mechanical_boss_damage_wpn":
			return module.mechanical_boss_damage_wpn != 0
		"emp_friendly_construct_heal":
			return module.emp_friendly_construct_heal != 0
		"emp_friendly_construct_overclock":
			return module.emp_friendly_construct_overclock
		"rocket_launcher":
			return module.rocket_launcher
		"exhaust_next_turn":
			return module.exhaust_next_turn
		"sacrifice_construct_instant":
			return module.sacrifice_construct_instant
		"scrap_shield":
			return module.scrap_shield
		"scrap_multiplier":
			return module.scrap_multiplier != 0
		"shield_depletion_explode":
			return module.shield_depletion_explode
		"manual_detonation":
			return module.manual_detonation
		"refund_scrap":
			return module.refund_scrap != 0
		"overdrive_injection":
			return module.overdrive_injection
		"construct_unmitigated_damage":
			return module.construct_unmitigated_damage != 0
		"refund_scrap_on_construct_death":
			return module.refund_scrap_on_construct_death != 0
		"barbed_wire":
			return module.barbed_wire
		"entry_root":
			return module.entry_root
		"adjacent_defense_bonus":
			return module.adjacent_defense_bonus != 0
		"density_shift":
			return module.density_shift
		"ignore_target_magic_pct":
			return not is_zero_approx(module.ignore_target_magic_pct)
		"creation_adjacent_damage":
			return module.creation_adjacent_damage != 0 or layer.creation_adjacent_damage != 0
		"apply_weaken_enemy":
			return module.apply_weaken_enemy
		"elemental_surface":
			return layer.elemental_surface
		"reaction_steam_splash":
			return layer.reaction_steam_splash
		"reaction_steam_splash_size":
			return layer.reaction_steam_splash_size != 0
		"reaction_steam_splash_damage":
			return layer.reaction_steam_splash_damage != 0
		"set_max_move":
			return layer.set_max_move != 0
		"arcane_trail":
			return layer.arcane_trail
		"strip_stealth":
			return module.strip_stealth
		"object_collision_stagger":
			return layer.object_collision_stagger
		"weapon_scaled":
			return layer.weapon_scaled
		"buff_per_destroyed_object":
			return layer.buff_per_destroyed_object != 0
		"stagger_on_collision":
			return layer.stagger_on_collision
		"intercept_grant_str":
			return layer.intercept_grant_str != 0
		"push_collision_pierce":
			return layer.push_collision_pierce
		"push_collision_damage":
			return layer.push_collision_damage != 0
		"difficult_terrain_created":
			return layer.difficult_terrain_created
		"rooted_push_bleed_weapon":
			return layer.rooted_push_bleed_weapon
		"leap_absorb_surface":
			return module.leap_absorb_surface
		"track_first_hit_zero":
			return module.track_first_hit_zero
		"chakra_shift":
			return module.chakra_shift
		"chakra_burst_damage":
			return module.chakra_burst_damage != 0
		"chakra_burst_shape":
			return module.chakra_burst_shape != GameEnums.TargetShape.SINGLE
		"chakra_burst_size":
			return module.chakra_burst_size != 0
		"stop_adjacent_first_enemy":
			return module.stop_adjacent_first_enemy
		"dash_absorb_element":
			return module.dash_absorb_element or layer.dash_absorb_element
		"target_magic_defense":
			return module.target_magic_defense
		"steal_target_magic":
			return module.steal_target_magic != 0
		"next_turn_move_penalty":
			return module.next_turn_move_penalty != 0
		"bonus_per_target_status":
			return module.bonus_per_target_status != 0
		"mantra_peace_weaken":
			return module.mantra_peace_weaken
		"inner_fire":
			return module.inner_fire
		"inner_fire_surface":
			return module.inner_fire_surface
		"landed_magic_bonus":
			return module.landed_magic_bonus != 0
		"enemy_pushed_mov":
			return module.enemy_pushed_mov != 0
		"blind_on_pass_over":
			return module.blind_on_pass_over
		"burning_splash_magic":
			return layer.burning_splash_magic != 0
		"burning_splash_shape":
			return layer.burning_splash_shape != GameEnums.TargetShape.SINGLE
		"pierce_if_first_zero":
			return layer.pierce_if_first_zero
		"damage_adjacent_on_landing":
			return layer.damage_adjacent_on_landing
		"require_dash_line_enemy":
			return layer.require_dash_line_enemy
		"collision_splash_damage":
			return layer.collision_splash_damage != 0
		"collision_splash_weaken":
			return layer.collision_splash_weaken
		"push_if_target_on_water":
			return layer.push_if_target_on_water != 0
		"relocate_subject_only":
			return module.relocate_subject_only
		"relocate_target":
			return module.relocate_target
		"move_active_totem":
			return module.move_active_totem
		"curse_of_weakness":
			return module.curse_of_weakness
		"stat_str":
			return module.stat_str != 0
		"stat_def":
			return module.stat_def != 0
		"push_mitigation_zero":
			return module.push_mitigation_zero
		"totem_kind":
			return module.totem_kind != &""
		"pulse_aoe":
			return module.pulse_aoe != 0
		"pulse_heal":
			return module.pulse_heal != 0
		"pulse_cleanse":
			return module.pulse_cleanse
		"pulse_mag_atk":
			return module.pulse_mag_atk != 0
		"pulse_fire":
			return module.pulse_fire
		"bloodlust":
			return module.bloodlust
		"bloodlust_def":
			return module.bloodlust_def != 0
		"bloodlust_mov":
			return module.bloodlust_mov != 0
		"bloodlust_hp":
			return module.bloodlust_hp != 0
		"bloodlust_bleed_on_attack":
			return module.bloodlust_bleed_on_attack
		"hex":
			return module.hex
		"wither":
			return module.wither
		"boss_damage_reduction":
			return not is_zero_approx(module.boss_damage_reduction)
		"hex_vulnerable":
			return module.hex_vulnerable
		"voodoo_link":
			return module.voodoo_link
		"shared_damage_wpn":
			return module.shared_damage_wpn != 0
		"shared_push":
			return module.shared_push
		"terrify":
			return module.terrify
		"boss_fallback_purge_shield":
			return module.boss_fallback_purge_shield
		"boss_fallback_vulnerable":
			return module.boss_fallback_vulnerable
		"poison_spread_on_push_collision":
			return module.poison_spread_on_push_collision
		"bone_spear":
			return module.bone_spear
		"spawn_furthest_empty_on_line":
			return layer.spawn_furthest_empty_on_line
		"ghost_duration":
			return module.ghost_duration != 0
		"echo_next_cast":
			return module.echo_next_cast
		"ghost_hp_pct":
			return not is_zero_approx(module.ghost_hp_pct)
		"echo_upgraded":
			return module.echo_upgraded
		"melee_def":
			return module.melee_def != 0
		"sympathetic_bond":
			return module.sympathetic_bond
		"link_ally_enemy":
			return module.link_ally_enemy
		"ally_heal_enemy_wpn":
			return module.ally_heal_enemy_wpn
		"enemy_damage_ally_heal":
			return module.enemy_damage_ally_heal != 0
		"bonus_damage_per_debuff":
			return module.bonus_damage_per_debuff != 0
		"heal_per_debuff":
			return module.heal_per_debuff != 0
		"pain_spike":
			return module.pain_spike
		"linked_enemy_damage":
			return module.linked_enemy_damage != 0
		"linked_enemy_blind":
			return module.linked_enemy_blind
		"pulse_status":
			return module.pulse_status != GameEnums.StatusType.NONE
		"pulse_weaken":
			return module.pulse_weaken
		"lightning_rod":
			return layer.lightning_rod
		_:
			return false

static func _find_ability(skill_id: StringName) -> AbilityData:
	for class_id: StringName in CLASS_IDS:
		var unit: UnitData = DataLibrary.get_unit(class_id)
		if unit == null:
			continue
		for ability: AbilityData in unit.abilities:
			if ability != null and ability.id == skill_id:
				return ability
	return null

