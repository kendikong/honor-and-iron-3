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
	source.self_move_zero_next_turn = true
	source.link_two_enemies = true
	source.magic_link_damage = 1
	source.link_partner_pick = true
	var layer := AbilityLayer.new()
	layer.push_collision_pierce = true
	layer.crossing_blind = true
	layer.range_one_damage_multiplier = 0.7
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
	source.layers.append(layer)
	var encoded: Dictionary = schema.call("module_to_dict", source) as Dictionary
	var restored := AbilityModule.new()
	schema.call("apply_module_dict", restored, encoded)
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
	_assert(failures, "self_move_zero_next_turn", restored.self_move_zero_next_turn)
	_assert(failures, "link_two_enemies", restored.link_two_enemies)
	_assert(failures, "magic_link_damage", restored.magic_link_damage == 1)
	_assert(failures, "link_partner_pick", restored.link_partner_pick)
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


static func _assert(failures: Array[String], key: String, condition: bool) -> void:
	if not condition:
		failures.append("typed schema roundtrip lost %s" % key)
