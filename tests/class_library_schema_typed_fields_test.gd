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
	_assert(
		failures,
		"layer_range_one_damage_multiplier",
		is_equal_approx(restored.layers[0].range_one_damage_multiplier, 0.7),
	)


static func _assert(failures: Array[String], key: String, condition: bool) -> void:
	if not condition:
		failures.append("typed schema roundtrip lost %s" % key)
