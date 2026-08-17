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
	var layer := AbilityLayer.new()
	layer.push_collision_pierce = true
	layer.crossing_blind = true
	layer.range_one_damage_multiplier = 0.7
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
	_assert(failures, "layer_push_collision_pierce", restored.layers[0].push_collision_pierce)
	_assert(failures, "layer_crossing_blind", restored.layers[0].crossing_blind)
	_assert(
		failures,
		"layer_range_one_damage_multiplier",
		is_equal_approx(restored.layers[0].range_one_damage_multiplier, 0.7),
	)


static func _assert(failures: Array[String], key: String, condition: bool) -> void:
	if not condition:
		failures.append("typed schema roundtrip lost %s" % key)
