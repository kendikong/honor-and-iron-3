class_name LayerShapeConversionRules
extends RefCounted

## Shape bar for ER-2: converted skills must be Swap-shaped (modules + layers + keywords),
## not typed-extra dumps. See docs/design/LAYER_SHAPE_CONVERSION_GATE.md.

enum EnforceMode {
	## Print violations; never fail (migration audit).
	AUDIT_ONLY,
	## Fail when CONVERTED_SKILL_IDS skills set layer-mandate typed extras.
	LAYER_MANDATE,
	## Fail when any non-allowlist typed extra is set on converted skills.
	STRICT_ALLOWLIST,
}

## Fields the binding matrix assigns to **layers** (or GRANT_AP/HEAL on conditions) — not module knobs.
const LAYER_MANDATE_TYPED_PROPS: Array[String] = [
	"frenzy_on_kill_ap",
	"heal_if_targets_gte",
	"on_kill_all_allies_heal",
	"on_kill_all_allies_shield",
	"on_kill_shield",
	"on_kill_max_move",
	"on_kill_refresh_mark_zero_ap",
	"on_kill_spread_silence_adjacent",
	"target_damaged_ap",
	"kill_grant_ap",
	"next_skill_zero_ap",
	"grant_ap", ## ON_KILL / conditional grants belong on layers, not primary module fields.
	"grant_scrap",
	"buff_on_push", ## Matrix: STR buff on PUSH layer.
	"heal_per_debuff",
	"on_hit_scrap",
	"violent_collision_recast", ## Matrix: IF_COLLIDED + second MOVE module, not a recast knob.
]

## ER-1 allowlist: typed extras that may remain on modules after real conversion.
const ER1_ALLOWLIST_TYPED_PROPS: Array[String] = [
	## Hazard / terrain
	"terrain_id", "hazard_duration", "hazard_status", "terrain_hazard_status",
	"trap_damage", "trap_bleed_weapon", "trap_vulnerable", "trap_def_debuff",
	"crossing_weapon_damage", "crossing_mov_penalty", "crossing_blind",
	"strip_stealth", "smoke_on_start", "smoke_field", "smoke_stealth_outside_attackers",
	"ignite_flammable_terrain", "destroy_terrain", "reaction_terrain", "reaction_damage",
	"leave_elemental_surface", "lightning_surface", "strike_all_surface",
	"bounce_surface_chain", "pull_surfaces", "pull_to_center", "create_crater",
	"oil_field", "hazard_blind_on_entry", "barbed_wire", "entry_root",
	"mine_pull", "mine_damage", "mine_explode", "tesla_wall", "ignite_oil",
	"ignite_oil_area", "manual_detonation", "manual_detonation_stagger",
	"holy_ground", "holy_ground_zone", "holy_ground_def_down", "inner_fire_surface",
	## Motion behavior (not separate click effects)
	"preserve_facing", "ignore_zoc", "blink", "vault_obstacle_or_gap_only",
	"pull_self_if_rooted", "pull_until_adjacent", "next_turn", "next_turn_max_move",
	"movement_mp_override", "cost_all_movement", "bonus_per_enemy_passed",
	"create_trampled_terrain", "upgraded_trample", "line_breaker",
	"landing_adjacent_push", "landing_adjacent_push_stagger",
	"stop_adjacent_first_enemy", "dash_absorb_element", "leap_absorb_surface",
	"enemy_pushed_mov", "blind_on_pass_over",
	"item_collision_damage", "item_collision_str_div", "item_collision_vulnerable",
	"push_board_items", "grapple_wall_pull_self", "grapple_pass_through_damage",
	"relocate_subject_only", "relocate_target", "move_active_totem",
	"pounce_land_adjacent", "feral_drag", "drag_remaining_movement",
	"reposition_opposite_side", "reposition_movement_cost", "reposition_range",
	"airlift_pickup_step", "airlift_drop_step", "airlift_keep_caster",
	"run_down_pass_adjacent_push", "run_down_push_bleed_weapon",
	"slip_past", "land_opposite_target", "move_through_adjacent_unit",
	"shadow_step", "kidnap", "pullback", "chakra_shift",
	"drop_adjacent", "teleport_visible",
	## Attack riders explicitly marked **New field** in binding matrix (until migrated)
	"bonus_dmg_from_occupied", "bonus_dmg_per_10_hp", "bonus_dmg_pct_max_hp",
	"bounce_count", "bounce_range", "bounce_walls_45", "skewer", "pierce",
	"next_attack_strength", "next_attack_bleed_weapon", "next_attack_pierce",
	"next_ranged_attack_strength", "root_break_on_damage", "spread_status_adjacent",
	"halve_target_def_one_turn", "armor_explosion_atk", "bonus_atk_vs_fear_or_lower_movement",
	"range_one_damage_multiplier", "bleed_bonus_damage", "target_def_debuff",
	"target_def_pct_debuff", "target_def_pct_duration", "bonus_if_target_adjacent_to_ally",
	"if_target_attacked_caster_last_turn_bonus",
	"if_target_attacked_caster_last_turn_stagger",
	"unacted_target_ignore_def_pct", "marked_target_defense", "duelist_mark_target",
	"flank_run_adjacent_enemy_bonus", "bonus_per_target_status",
	"push", ## Primary PUSH amount on Forced Movement modules.
	## Spawn / construct
	"construct_hp_pct", "totem_kind", "turret_attack", "construct_spawn",
	## Resource / header economy on module
	"delayed_next_turn", "spend_self_hp", "mana_shield", "self_move_zero_next_turn",
	"refund_scrap", "scrap_multiplier",
	## Status / link behaviors still on typed migration path
	"curse_of_weakness", "hex", "wither", "bloodlust", "voodoo_link", "life_link",
	"life_link_reduction", "sanctuary", "holy_aura", "mag_heal", "cleanse_target",
	"link_two_enemies", "link_blind", "link_partner_pick", "sympathetic_bond",
]

## Gold-standard reference + exemplar skills with explicit shape expectations (grow per refactor wave).
const CONVERSION_SHAPE_EXPECTATIONS: Dictionary = {
	&"knight_swap": {
		"gold_standard": true,
		"max_typed_extras": 0,
	},
	&"bruiser_frenzy": {
		"forbidden_typed": ["frenzy_on_kill_ap"],
		"required_layers": [
			{
				"condition": "ON_KILL",
				"effect_type": "GRANT_AP",
				"profile": "upgrade",
			},
		],
	},
	&"bruiser_crimson_whirlwind": {
		"forbidden_typed": ["heal_if_targets_gte"],
		"required_layers": [
			{
				"condition": "PER_TARGET_HIT",
				"effect_type": "HEAL",
				"profile": "upgrade",
			},
		],
	},
	&"bruiser_push_through": {
		"forbidden_typed": ["buff_on_push"],
	},
	&"bruiser_violent_collision": {
		"forbidden_typed": ["violent_collision_recast"],
		"min_modules": 2,
	},
}

const GOLD_STANDARD_SKILL_IDS: Array[StringName] = [&"knight_swap"]


static func collect_active_typed_extras(module: AbilityModule) -> Array[String]:
	if module == null:
		return []
	var active: Array[String] = []
	for prop: String in ModuleAuthoringRules.typed_extra_module_property_names():
		if module.is_typed_extra_property_set(prop):
			active.append(prop)
	return active


static func layer_mandate_violations_on_module(module: AbilityModule) -> Array[String]:
	var violations: Array[String] = []
	for prop: String in collect_active_typed_extras(module):
		if prop in LAYER_MANDATE_TYPED_PROPS:
			violations.append(prop)
	return violations


static func non_allowlist_violations_on_module(module: AbilityModule) -> Array[String]:
	var violations: Array[String] = []
	for prop: String in collect_active_typed_extras(module):
		if prop not in ER1_ALLOWLIST_TYPED_PROPS:
			violations.append(prop)
	return violations


static func module_has_layer_signature(
	module: AbilityModule,
	condition: GameEnums.LayerCondition,
	effect_type: GameEnums.EffectType,
) -> bool:
	if module == null:
		return false
	for layer: AbilityLayer in module.layers:
		if layer == null or layer.effect == null:
			continue
		if layer.condition == condition and layer.effect.type == effect_type:
			return true
	return false


static func audit_ability_shape(ability: AbilityData) -> Array[String]:
	var failures: Array[String] = []
	if ability == null:
		return failures
	var label: String = String(ability.id)
	var spec: Dictionary = CONVERSION_SHAPE_EXPECTATIONS.get(ability.id, {})
	if bool(spec.get("gold_standard", false)):
		var max_extras: int = int(spec.get("max_typed_extras", 0))
		var count: int = (
			_count_typed_extras_in_modules(ability.modules)
			+ _count_typed_extras_in_modules(ability.upgraded_modules)
		)
		if count > max_extras:
			failures.append(
				"%s gold standard expects <=%d typed extras, found %d"
				% [label, max_extras, count]
			)
	for forbidden: String in spec.get("forbidden_typed", []):
		if _modules_set_prop(ability.modules, forbidden) or _modules_set_prop(ability.upgraded_modules, forbidden):
			failures.append("%s still sets forbidden typed extra %s" % [label, forbidden])
	if int(spec.get("min_modules", 0)) > 0:
		if ability.modules.size() < int(spec["min_modules"]):
			failures.append(
				"%s expects >=%d base modules, found %d"
				% [label, int(spec["min_modules"]), ability.modules.size()]
			)
	for layer_spec: Variant in spec.get("required_layers", []):
		if not layer_spec is Dictionary:
			continue
		var profile: String = String(layer_spec.get("profile", "base"))
		var modules: Array[AbilityModule] = (
			ability.upgraded_modules if profile == "upgrade" else ability.modules
		)
		var condition: GameEnums.LayerCondition = _layer_condition_from_spec(
			layer_spec.get("condition", "AT_RESOLUTION")
		)
		var effect_type: GameEnums.EffectType = _effect_type_from_spec(
			layer_spec.get("effect_type", "DAMAGE")
		)
		var found: bool = false
		for module: AbilityModule in modules:
			if module_has_layer_signature(module, condition, effect_type):
				found = true
				break
		if not found:
			failures.append(
				"%s missing required layer condition=%s effect=%s on %s profile"
				% [label, str(condition), str(effect_type), profile]
			)
	return failures


static func audit_converted_skills(
	mode: EnforceMode = EnforceMode.LAYER_MANDATE,
	class_prefix: String = "",
) -> Array[String]:
	var failures: Array[String] = []
	for skill_id: StringName in ExtraRulesConversionContract.CONVERTED_SKILL_IDS:
		if not class_prefix.is_empty() and not String(skill_id).begins_with(class_prefix):
			continue
		var ability: AbilityData = find_factory_ability(skill_id)
		if ability == null:
			failures.append("layer_shape: missing ability %s" % String(skill_id))
			continue
		failures.append_array(audit_ability_shape(ability))
		for profile: String in ["base", "upgrade"]:
			var modules: Array[AbilityModule] = (
				ability.upgraded_modules if profile == "upgrade" else ability.modules
			)
			for module_index: int in modules.size():
				var module: AbilityModule = modules[module_index]
				if module == null:
					continue
				var mandate: Array[String] = layer_mandate_violations_on_module(module)
				if not mandate.is_empty() and mode != EnforceMode.AUDIT_ONLY:
					failures.append(
						"%s %s module %d layer-mandate typed extras: %s"
						% [String(skill_id), profile, module_index, ", ".join(mandate)]
					)
				if mode == EnforceMode.STRICT_ALLOWLIST:
					var disallowed: Array[String] = non_allowlist_violations_on_module(module)
					if not disallowed.is_empty():
						failures.append(
							"%s %s module %d non-allowlist typed extras: %s"
							% [String(skill_id), profile, module_index, ", ".join(disallowed)]
						)
	return failures


static func print_audit_report() -> void:
	print("LAYER_SHAPE_AUDIT: converted_skills=%d" % ExtraRulesConversionContract.CONVERTED_SKILL_IDS.size())
	for skill_id: StringName in ExtraRulesConversionContract.CONVERTED_SKILL_IDS:
		var ability: AbilityData = find_factory_ability(skill_id)
		if ability == null:
			print("  %s: MISSING" % String(skill_id))
			continue
		var mandate_count: int = 0
		var allowlist_count: int = 0
		for module: AbilityModule in ability.modules:
			if module == null:
				continue
			mandate_count += layer_mandate_violations_on_module(module).size()
			allowlist_count += non_allowlist_violations_on_module(module).size()
		for module: AbilityModule in ability.upgraded_modules:
			if module == null:
				continue
			mandate_count += layer_mandate_violations_on_module(module).size()
			allowlist_count += non_allowlist_violations_on_module(module).size()
		var extras: int = (
			_count_typed_extras_in_modules(ability.modules)
			+ _count_typed_extras_in_modules(ability.upgraded_modules)
		)
		print(
			"  %s: typed_extras=%d mandate_violations=%d non_allowlist=%d"
			% [String(skill_id), extras, mandate_count, allowlist_count]
		)


static func _count_typed_extras_in_modules(modules: Array[AbilityModule]) -> int:
	var count: int = 0
	for module: AbilityModule in modules:
		if module == null:
			continue
		count += collect_active_typed_extras(module).size()
	return count


static func _modules_set_prop(modules: Array[AbilityModule], prop: String) -> bool:
	for module: AbilityModule in modules:
		if module != null and module.is_typed_extra_property_set(prop):
			return true
	return false


static func find_factory_ability(skill_id: StringName) -> AbilityData:
	for class_id: StringName in ExtraRulesConversionContract.CLASS_IDS:
		var unit: UnitData = DataLibrary.get_unit(class_id)
		if unit == null:
			continue
		for ability: AbilityData in unit.abilities:
			if ability != null and ability.id == skill_id:
				return ability
	return null


static func _layer_condition_from_spec(value: Variant) -> GameEnums.LayerCondition:
	if value is int:
		return value as GameEnums.LayerCondition
	match String(value).to_upper():
		"ON_KILL":
			return GameEnums.LayerCondition.ON_KILL
		"AT_RESOLUTION":
			return GameEnums.LayerCondition.AT_RESOLUTION
		"ON_COLLISION":
			return GameEnums.LayerCondition.ON_COLLISION
		"PER_TARGET_HIT":
			return GameEnums.LayerCondition.PER_TARGET_HIT
		_:
			return GameEnums.LayerCondition.AT_RESOLUTION


static func _effect_type_from_spec(value: Variant) -> GameEnums.EffectType:
	if value is int:
		return value as GameEnums.EffectType
	match String(value).to_upper():
		"GRANT_AP":
			return GameEnums.EffectType.GRANT_AP
		"HEAL":
			return GameEnums.EffectType.HEAL
		"ADD_STATUS_SELF":
			return GameEnums.EffectType.ADD_STATUS_SELF
		"DAMAGE":
			return GameEnums.EffectType.DAMAGE
		_:
			return GameEnums.EffectType.DAMAGE
