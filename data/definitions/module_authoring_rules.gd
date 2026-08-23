class_name ModuleAuthoringRules
extends RefCounted

## Canonical rules: which module/layer fields apply to a primary effect type.
## Class Editor greys inactive fields; AbilityModuleBridge.normalize enforces the same rules.
## Standalone — do not call AbilityModuleBridge here (avoids circular class_name load).


static func _is_motion_type(effect_type: GameEnums.EffectType) -> bool:
	return (
		GameEnums.is_walk_motion(effect_type)
		or GameEnums.is_jump_motion(effect_type)
		or GameEnums.is_teleport_motion(effect_type)
		or effect_type == GameEnums.EffectType.DASH
		or effect_type == GameEnums.EffectType.SWAP
		or effect_type == GameEnums.EffectType.MOVE_INTO_AND_PUSH
	)


static func effect_type_can_deal_damage(effect_type: GameEnums.EffectType) -> bool:
	return effect_type in [
		GameEnums.EffectType.DAMAGE,
		GameEnums.EffectType.DAMAGE_SELF,
		GameEnums.EffectType.EXPLODE,
		GameEnums.EffectType.RANGED_EXPLODE,
		GameEnums.EffectType.TRAMPLE,
		GameEnums.EffectType.BULLDOZE,
	]


static func module_uses_phase(planner_group: GameEnums.PlannerGroup) -> bool:
	return planner_group == GameEnums.PlannerGroup.ACTION


static func excluded_module_phases(planner_group: GameEnums.PlannerGroup) -> PackedStringArray:
	if planner_group == GameEnums.PlannerGroup.PRE_MOVE:
		return PackedStringArray(["ON_PRE", "ON_POST"])
	return PackedStringArray()


static func module_uses_range(module: AbilityModule) -> bool:
	if module == null:
		return false
	if module.primary_type == GameEnums.EffectType.ADD_STATUS_SELF:
		return (module.targeting_flags & GameEnums.TargetingFlags.ALLY) != 0 \
			or (module.targeting_flags & GameEnums.TargetingFlags.ENEMY) != 0
	return true


static func module_uses_los(module: AbilityModule) -> bool:
	if module == null or not module_uses_range(module):
		return false
	if _is_motion_type(module.primary_type):
		return false
	if module_has_only_self_targeting(module):
		return false
	return true


static func module_uses_range_origin(module: AbilityModule, module_index: int) -> bool:
	if module == null:
		return false
	if not module_uses_range(module):
		return false
	return module_index > 0 or module.aim_binding != GameEnums.AimBinding.NEW_AIM


static func module_uses_shape(module: AbilityModule) -> bool:
	if module == null:
		return false
	if module.primary_type == GameEnums.EffectType.SWAP:
		return false
	return true


static func module_uses_shape_size(module: AbilityModule) -> bool:
	if module == null or not module_uses_shape(module):
		return false
	return module.target_shape != GameEnums.TargetShape.SINGLE


static func module_uses_hit_count(module: AbilityModule) -> bool:
	return module != null and module.primary_type == GameEnums.EffectType.DAMAGE


static func module_uses_l_shape_move(module: AbilityModule) -> bool:
	if module == null:
		return false
	return (
		module.primary_type == GameEnums.EffectType.MOVE
		or GameEnums.is_walk_motion(module.primary_type)
	)


static func module_uses_target_filter_hp(module: AbilityModule) -> bool:
	return module != null and module.target_filter == GameEnums.ModuleTargetFilter.HP


static func module_uses_target_filter_hp_pct(module: AbilityModule) -> bool:
	return (
		module_uses_target_filter_hp(module)
		and module.target_filter_hp == GameEnums.ModuleTargetFilterHp.BELOW_PCT
	)


static func module_uses_target_filter_status(module: AbilityModule) -> bool:
	return module != null and module.target_filter == GameEnums.ModuleTargetFilter.STATUS


static func module_uses_target_filter_status_type(module: AbilityModule) -> bool:
	return (
		module_uses_target_filter_status(module)
		and module.target_filter_status_mode == GameEnums.ModuleTargetFilterStatus.SPECIFIC
	)


static func module_uses_target_filter_stat(module: AbilityModule) -> bool:
	return module != null and module.target_filter == GameEnums.ModuleTargetFilter.STAT


static func module_uses_target_filter_occupant(module: AbilityModule) -> bool:
	return module != null and module.target_filter == GameEnums.ModuleTargetFilter.OCCUPANT


static func excluded_module_gates(module: AbilityModule) -> PackedStringArray:
	var excluded := PackedStringArray()
	if module == null:
		return excluded
	if not _is_motion_type(module.primary_type):
		excluded.append("IF_COLLIDED")
	if not effect_type_can_deal_damage(module.primary_type):
		excluded.append("IF_KILL")
		excluded.append("IF_DAMAGE_DEALT")
	return excluded


static func targeting_flag_applies(module: AbilityModule, flag: int) -> bool:
	if module == null:
		return false
	if flag == GameEnums.TargetingFlags.EXCLUDE_CASTER:
		return (module.targeting_flags & (
			GameEnums.TargetingFlags.SELF | GameEnums.TargetingFlags.ALLY
		)) != 0
	if module.primary_type == GameEnums.EffectType.ADD_STATUS_SELF:
		return flag == GameEnums.TargetingFlags.SELF \
			or flag == GameEnums.TargetingFlags.ALLY
	if flag == GameEnums.TargetingFlags.TILE and module.primary_type == GameEnums.EffectType.SWAP:
		return false
	return true


static func keyword_uses_amount(keyword_id: GameEnums.AbilityKeywordId) -> bool:
	return keyword_id != GameEnums.AbilityKeywordId.NONE


static func keyword_uses_emit_as_effect(keyword_id: GameEnums.AbilityKeywordId) -> bool:
	return (
		keyword_id == GameEnums.AbilityKeywordId.TRAMPLE
		or keyword_id == GameEnums.AbilityKeywordId.BULLDOZE
	)


static func layer_condition_applies(
	parent_module: AbilityModule,
	condition: GameEnums.LayerCondition,
) -> bool:
	if parent_module == null:
		return true
	var motion: bool = _is_motion_type(parent_module.primary_type)
	match condition:
		GameEnums.LayerCondition.DURING:
			return _is_motion_type(parent_module.primary_type) or effect_type_can_deal_damage(
				parent_module.primary_type
			)
		GameEnums.LayerCondition.ON_LAND, GameEnums.LayerCondition.PER_TILE_MOVED:
			return motion
		GameEnums.LayerCondition.WHEN_MOVED_THROUGH_ENEMY:
			return motion or module_has_during_pass_through(parent_module)
		GameEnums.LayerCondition.ON_COLLISION, GameEnums.LayerCondition.ON_CHAIN_COLLISION:
			return motion or effect_type_can_deal_damage(parent_module.primary_type)
		GameEnums.LayerCondition.IF_ALREADY_ADJACENT:
			return effect_type_can_deal_damage(parent_module.primary_type)
		_:
			return true


static func excluded_layer_conditions(parent_module: AbilityModule) -> PackedStringArray:
	var excluded := PackedStringArray()
	for key: String in GameEnums.LayerCondition.keys():
		var condition: GameEnums.LayerCondition = GameEnums.LayerCondition[key]
		if not layer_condition_applies(parent_module, condition):
			excluded.append(key)
	return excluded


static func normalize_module_context_fields(
	module: AbilityModule,
	planner_group: GameEnums.PlannerGroup,
	module_index: int,
) -> void:
	if module == null:
		return
	if planner_group == GameEnums.PlannerGroup.ACTION:
		if module.primary_type == GameEnums.EffectType.PAIRED_MOVE:
			module.primary_type = GameEnums.EffectType.MOVE
		elif (
			module.primary_type == GameEnums.EffectType.SWAP
			and (module.targeting_flags & GameEnums.TargetingFlags.ALLY) != 0
		):
			module.targeting_flags &= ~GameEnums.TargetingFlags.ALLY
	if planner_group == GameEnums.PlannerGroup.PRE_MOVE:
		module.execution_phase = GameEnums.ModulePhase.ON_ACTION
	for key: String in excluded_module_gates(module):
		if module.gate == GameEnums.ModuleGate[key]:
			module.gate = GameEnums.ModuleGate.ALWAYS
			break
	if not module_uses_target_filter_hp(module):
		module.target_filter_hp = GameEnums.ModuleTargetFilterHp.BELOW_PCT
		module.target_filter_hp_pct = 0
	elif not module_uses_target_filter_hp_pct(module):
		module.target_filter_hp_pct = 0
	if not module_uses_target_filter_status(module):
		module.target_filter_status_mode = GameEnums.ModuleTargetFilterStatus.ANY_DEBUFF
		module.target_filter_status = GameEnums.StatusType.NONE
		module.target_filter_status_or = GameEnums.StatusType.NONE
	elif not module_uses_target_filter_status_type(module):
		module.target_filter_status = GameEnums.StatusType.NONE
		module.target_filter_status_or = GameEnums.StatusType.NONE
	if not module_uses_target_filter_stat(module):
		module.target_filter_stat = GameEnums.ModuleTargetFilterStat.CON_LEQ_CASTER_STR
	if not module_uses_target_filter_occupant(module):
		module.target_filter_occupant = GameEnums.ModuleTargetFilterOccupant.ALLY_CONSTRUCT
	if not module_uses_range(module):
		module.min_range = 0
		module.max_range = 0
		module.requires_los = false
		module.range_origin = GameEnums.RangeOrigin.ACTOR
	elif not module_uses_los(module):
		module.requires_los = false
	if module_uses_range(module) and not module_uses_range_origin(module, module_index):
		module.range_origin = GameEnums.RangeOrigin.ACTOR
	normalize_module_targeting_flags(module)
	migrate_keywords_to_layers(module)
	for layer: AbilityLayer in module.layers:
		if layer == null:
			continue
		if layer.condition == GameEnums.LayerCondition.DURING:
			if not during_layer_compatible(module, layer):
				layer.condition = GameEnums.LayerCondition.AT_RESOLUTION


static func migrate_keywords_to_layers(module: AbilityModule) -> void:
	if module == null or module.keywords.is_empty():
		return
	for keyword: AbilityKeyword in module.keywords:
		if keyword == null:
			continue
		var layer: AbilityLayer = during_layer_from_keyword(keyword)
		if layer != null:
			module.layers.append(layer)
	module.keywords.clear()
	module.invalidate_runtime_modifiers_cache()


static func during_layer_from_keyword(keyword: AbilityKeyword) -> AbilityLayer:
	if keyword == null or keyword.keyword_id == GameEnums.AbilityKeywordId.NONE:
		return null
	var layer := AbilityLayer.new()
	layer.condition = GameEnums.LayerCondition.DURING
	layer.during_emit_effect = keyword.emit_as_effect
	layer.effect = EffectData.new()
	match keyword.keyword_id:
		GameEnums.AbilityKeywordId.TRAMPLE:
			layer.effect.type = GameEnums.EffectType.TRAMPLE
			layer.effect.amount = keyword.amount
		GameEnums.AbilityKeywordId.BULLDOZE:
			layer.effect.type = GameEnums.EffectType.BULLDOZE
			layer.effect.amount = keyword.amount
			layer.during_bulldoze_push = keyword.push_amount
		GameEnums.AbilityKeywordId.GHOST:
			layer.effect.type = GameEnums.EffectType.ADD_STATUS_SELF
			layer.effect.status_type = GameEnums.StatusType.GHOST
			layer.effect.amount = 1
			layer.during_emit_effect = false
		GameEnums.AbilityKeywordId.PIERCE:
			layer.effect.type = GameEnums.EffectType.ADD_STATUS_SELF
			layer.effect.status_type = GameEnums.StatusType.PIERCE
			layer.effect.amount = 1
			layer.during_emit_effect = false
		GameEnums.AbilityKeywordId.CANTO:
			layer.effect.type = GameEnums.EffectType.ADD_STATUS_SELF
			layer.effect.status_type = GameEnums.StatusType.CANTO
			layer.effect.amount = 1
			layer.during_emit_effect = false
		_:
			return null
	return layer


static func during_layer_compatible(module: AbilityModule, layer: AbilityLayer) -> bool:
	if module == null or layer == null or layer.effect == null:
		return false
	if layer.condition != GameEnums.LayerCondition.DURING:
		return true
	var effect_type: int = layer.effect.type
	if effect_type in [GameEnums.EffectType.BULLDOZE, GameEnums.EffectType.TRAMPLE]:
		return _is_motion_type(module.primary_type)
	if (
		layer.effect.type == GameEnums.EffectType.ADD_STATUS_SELF
		and layer.effect.status_type == GameEnums.StatusType.GHOST
	):
		return _is_motion_type(module.primary_type)
	if (
		layer.effect.type == GameEnums.EffectType.ADD_STATUS_SELF
		and layer.effect.status_type == GameEnums.StatusType.PIERCE
	):
		return effect_type_can_deal_damage(module.primary_type) or _is_motion_type(
			module.primary_type
		)
	return true


static func apply_during_layer_to_modifiers(bag: Dictionary, layer: AbilityLayer) -> void:
	if layer == null or layer.effect == null:
		return
	match layer.effect.type:
		GameEnums.EffectType.TRAMPLE:
			if layer.effect.amount != 0:
				bag["trample"] = layer.effect.amount
		GameEnums.EffectType.BULLDOZE:
			bag["bulldoze"] = layer.effect.amount
			if layer.during_bulldoze_push != 0:
				bag["push"] = layer.during_bulldoze_push
			elif layer.effect.modifiers.has("push"):
				bag["push"] = int(layer.effect.modifiers["push"])
		GameEnums.EffectType.ADD_STATUS_SELF:
			match layer.effect.status_type:
				GameEnums.StatusType.GHOST:
					bag["ghost_move"] = 1
				GameEnums.StatusType.PIERCE:
					if not bag.has("next_attack_pierce") and not bag.has("pierce"):
						bag["next_attack_pierce"] = 1
				_:
					pass
		_:
			pass


static func during_layer_emits_effect_row(layer: AbilityLayer) -> bool:
	if layer == null or layer.effect == null:
		return false
	if layer.condition != GameEnums.LayerCondition.DURING:
		return false
	if not layer.during_emit_effect:
		return false
	return layer.effect.type in [
		GameEnums.EffectType.TRAMPLE,
		GameEnums.EffectType.BULLDOZE,
	]


static func module_has_during_pass_through(module: AbilityModule) -> bool:
	if module == null:
		return false
	for layer: AbilityLayer in module.layers:
		if layer == null or layer.condition != GameEnums.LayerCondition.DURING:
			continue
		if layer.effect == null:
			continue
		if layer.effect.type in [
			GameEnums.EffectType.TRAMPLE,
			GameEnums.EffectType.BULLDOZE,
		]:
			return true
	return false


static func module_has_during_status(
	module: AbilityModule,
	status_type: GameEnums.StatusType,
) -> bool:
	if module == null:
		return false
	for layer: AbilityLayer in module.layers:
		if layer == null or layer.condition != GameEnums.LayerCondition.DURING:
			continue
		if layer.effect == null:
			continue
		if (
			layer.effect.type == GameEnums.EffectType.ADD_STATUS_SELF
			and layer.effect.status_type == status_type
		):
			return true
	return false


const LEGACY_TARGETING_FLAG_DASH_LINE: int = 16
const LEGACY_TARGETING_MODE_DASH_LINE: int = 5
const LEGACY_TARGETING_MODE_ALLY_OR_SELF: int = 6


static func migrate_targeting_flags(flags: int) -> int:
	var out: int = flags
	if (out & LEGACY_TARGETING_FLAG_DASH_LINE) != 0:
		out = (out & ~LEGACY_TARGETING_FLAG_DASH_LINE) | GameEnums.TargetingFlags.TILE
	return out


static func migrate_targeting_mode(mode: int) -> int:
	if mode == LEGACY_TARGETING_MODE_DASH_LINE:
		return GameEnums.TargetingMode.TILE
	if mode == LEGACY_TARGETING_MODE_ALLY_OR_SELF:
		return GameEnums.TargetingMode.ALLY_OR_SELF
	return mode


static func normalize_module_targeting_flags(module: AbilityModule) -> void:
	if module == null:
		return
	module.targeting_flags = migrate_targeting_flags(module.targeting_flags)
	for flag: int in [
		GameEnums.TargetingFlags.SELF,
		GameEnums.TargetingFlags.ALLY,
		GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetingFlags.TILE,
		GameEnums.TargetingFlags.EXCLUDE_CASTER,
	]:
		if not targeting_flag_applies(module, flag):
			module.targeting_flags &= ~flag
	if module.primary_type == GameEnums.EffectType.ADD_STATUS_SELF:
		if (module.targeting_flags & GameEnums.TargetingFlags.ALLY) == 0:
			module.targeting_flags |= GameEnums.TargetingFlags.SELF


static func module_has_only_self_targeting(module: AbilityModule) -> bool:
	if module == null:
		return false
	var flags: int = module.targeting_flags
	if flags == 0:
		return false
	return flags == GameEnums.TargetingFlags.SELF


static func parent_module_has_pass_through_keyword(module: AbilityModule) -> bool:
	return module_has_during_pass_through(module)


static func keyword_uses_push_amount(keyword_id: GameEnums.AbilityKeywordId) -> bool:
	return keyword_id == GameEnums.AbilityKeywordId.BULLDOZE


## Class Editor Primary / Layer Type dropdown families.
## When adding an EffectType, put it in one family here. Fail-loud if any type is missing.
static func effect_primary_families() -> Array[Dictionary]:
	return [
		{
			"label": "Attack",
			"types": [
				GameEnums.EffectType.DAMAGE,
				GameEnums.EffectType.DAMAGE_SELF,
				GameEnums.EffectType.EXPLODE,
				GameEnums.EffectType.RANGED_EXPLODE,
			],
		},
		{
			"label": "Heal",
			"types": [
				GameEnums.EffectType.HEAL,
			],
		},
		{
			"label": "Shield",
			"types": [
				GameEnums.EffectType.ARMOR_UP,
			],
		},
		{
			"label": "Status",
			"types": [
				GameEnums.EffectType.ADD_STATUS,
				GameEnums.EffectType.ADD_STATUS_SELF,
				GameEnums.EffectType.REMOVE_STATUS,
				GameEnums.EffectType.CLEANSE,
				GameEnums.EffectType.PURGE,
			],
		},
		{
			"label": "Movement (Self)",
			"types": [
				GameEnums.EffectType.MOVE,
				GameEnums.EffectType.MOVE_ADJACENT_TO,
				GameEnums.EffectType.MOVE_TO_BEHIND,
				GameEnums.EffectType.MOVE_TOWARD,
				GameEnums.EffectType.MOVE_INTO_AND_PUSH,
				GameEnums.EffectType.JUMP,
				GameEnums.EffectType.JUMP_ADJACENT_TO,
				GameEnums.EffectType.JUMP_TO_BEHIND,
				GameEnums.EffectType.JUMP_TOWARD,
				GameEnums.EffectType.TELEPORT_CASTER,
				GameEnums.EffectType.TELEPORT_ADJACENT_TO,
				GameEnums.EffectType.TELEPORT_TO_BEHIND,
				GameEnums.EffectType.TELEPORT_TOWARD,
				GameEnums.EffectType.DASH,
			],
		},
		{
			"label": "Forced Movement",
			"types": [
				GameEnums.EffectType.PUSH,
				GameEnums.EffectType.PULL,
				GameEnums.EffectType.THROW_BEHIND,
			],
		},
		{
			"label": "Move someone",
			"types": [
				GameEnums.EffectType.SWAP,
				GameEnums.EffectType.PAIRED_MOVE,
			],
		},
		{
			"label": "Hazard",
			"types": [
				GameEnums.EffectType.CHANGE_TERRAIN,
				GameEnums.EffectType.CREATE_HAZARD,
				GameEnums.EffectType.DESTROY_OBSTACLE,
			],
		},
		{
			"label": "Summon",
			"types": [
				GameEnums.EffectType.SPAWN,
			],
		},
		{
			"label": "Resource",
			"types": [
				GameEnums.EffectType.GRANT_AP,
				GameEnums.EffectType.GRANT_SCRAP,
				GameEnums.EffectType.REFUND_AP_ON_CC,
			],
		},
		{
			"label": "Legacy — convert off",
			"types": [
				GameEnums.EffectType.TRAMPLE,
				GameEnums.EffectType.BULLDOZE,
				GameEnums.EffectType.PUSH_STAGGER_ON_COLLISION,
				GameEnums.EffectType.PULL_VULNERABLE_ON_ADJACENT,
				GameEnums.EffectType.PUSH_CHAIN_COLLISION,
			],
		},
	]


static func uncategorized_effect_types() -> Array[GameEnums.EffectType]:
	var seen: Dictionary = {}
	for family: Dictionary in effect_primary_families():
		for effect_type: GameEnums.EffectType in family["types"]:
			seen[effect_type] = true
	var missing: Array[GameEnums.EffectType] = []
	for key: String in GameEnums.EffectType.keys():
		var effect_type: GameEnums.EffectType = GameEnums.EffectType[key]
		if not seen.has(effect_type):
			missing.append(effect_type)
	return missing


static var _uncategorized_logged: bool = false


static func log_uncategorized_effect_types_once() -> Array[GameEnums.EffectType]:
	var missing: Array[GameEnums.EffectType] = uncategorized_effect_types()
	if missing.is_empty() or _uncategorized_logged:
		return missing
	_uncategorized_logged = true
	push_error("ModuleAuthoringRules: uncategorized EffectType(s) must join a primary family: %s" % str(missing))
	return missing


static var _typed_extra_module_props: Array[String] = []

const _RESOURCE_BUILTIN_PROPS: Array[String] = [
	"script", "resource_name", "resource_path", "metadata",
]


static func _ensure_typed_extra_module_props() -> void:
	if not _typed_extra_module_props.is_empty():
		return
	var probe := AbilityModule.new()
	for info: Dictionary in probe.get_property_list():
		var name: String = String(info.name)
		if name.begins_with("_"):
			continue
		if name in _RESOURCE_BUILTIN_PROPS:
			continue
		if int(info.usage) & PROPERTY_USAGE_STORAGE == 0:
			continue
		if name in [
			"execution_phase", "primary_type", "amount", "status_type", "status_duration",
			"scaling_stat", "spawn_unit_id", "l_shape_move", "min_range", "max_range",
			"requires_los", "range_origin", "target_shape", "target_shape_size",
			"aim_binding", "aim_module_index", "targeting_flags", "keywords", "layers",
			"gate", "target_filter", "target_filter_hp", "target_filter_hp_pct",
			"target_filter_status_mode", "target_filter_status", "target_filter_status_or",
			"target_filter_stat", "target_filter_occupant", "presentation_anim",
			"bonus_if_adjacent_at_cast", "def_debuff_before_damage", "hit_count",
			"exclude_caster",
		]:
			continue
		_typed_extra_module_props.append(name)


static func typed_extra_property_from_label(label: String) -> String:
	if label.is_empty():
		return ""
	_ensure_typed_extra_module_props()
	if _TYPED_EXTRA_LABEL_OVERRIDES.has(label):
		return String(_TYPED_EXTRA_LABEL_OVERRIDES[label])
	if label in _typed_extra_module_props:
		return label
	for candidate: String in [
		_guess_typed_extra_property(label),
		_guess_typed_extra_property(_expand_authoring_label(label)),
	]:
		if candidate in _typed_extra_module_props:
			return candidate
	return ""


static func layer_property_from_label(label: String) -> String:
	if label.is_empty():
		return ""
	_ensure_typed_extra_layer_props()
	var stripped: String = label
	if stripped.begins_with("Layer "):
		stripped = stripped.substr(6)
	if _TYPED_EXTRA_LABEL_OVERRIDES.has(stripped):
		var mapped: String = String(_TYPED_EXTRA_LABEL_OVERRIDES[stripped])
		if mapped in _typed_extra_layer_props:
			return mapped
	if stripped in _typed_extra_layer_props:
		return stripped
	for candidate: String in [
		_guess_typed_extra_property(stripped),
		_guess_typed_extra_property(_expand_authoring_label(stripped)),
	]:
		if candidate in _typed_extra_layer_props:
			return candidate
	return ""


static func _expand_authoring_label(label: String) -> String:
	var s: String = label
	s = s.replace(" BLEED WPN", " Bleed Weapon")
	s = s.replace("Pass Damage", "Pass Through Damage")
	s = s.replace(" STR Div", " Str Div")
	s = s.replace(" STR", " Strength")
	s = s.replace(" WPN", " Weapon")
	s = s.replace(" MAG", " Magic")
	s = s.replace(" MOV", " Move")
	return s


static func _guess_typed_extra_property(label: String) -> String:
	var s: String = label.to_lower()
	s = s.replace(" /10 hp", "_per_10_hp")
	s = s.replace(" /", "_per_")
	s = s.replace("%", "pct")
	s = s.replace(">=", "gte")
	s = s.replace("/", "_")
	s = s.replace("-", "_")
	s = s.replace(" ", "_")
	while s.contains("__"):
		s = s.replace("__", "_")
	return s.strip_edges()


static func typed_extra_active_count(module: AbilityModule) -> int:
	if module == null:
		return 0
	var count: int = 0
	for prop: String in typed_extra_module_property_names():
		if module.is_typed_extra_property_set(prop):
			count += 1
	return count


static func typed_extra_module_property_names() -> Array[String]:
	_ensure_typed_extra_module_props()
	return _typed_extra_module_props.duplicate()


static func typed_extra_field_applies(module: AbilityModule, property: String) -> bool:
	if module == null or property.is_empty():
		return false
	if module.is_typed_extra_property_set(property):
		return true
	var primary: int = module.primary_type
	if _typed_extra_property_in_group(property, _HAZARD_TYPED_PROPS):
		return primary in [
			GameEnums.EffectType.CREATE_HAZARD,
			GameEnums.EffectType.CHANGE_TERRAIN,
			GameEnums.EffectType.DESTROY_OBSTACLE,
		]
	if _typed_extra_property_in_group(property, _MOTION_TYPED_PROPS):
		return _is_motion_type(primary) or primary == GameEnums.EffectType.DASH
	if _typed_extra_property_in_group(property, _FORCED_MOVE_TYPED_PROPS):
		return primary in [
			GameEnums.EffectType.PUSH,
			GameEnums.EffectType.PULL,
			GameEnums.EffectType.THROW_BEHIND,
			GameEnums.EffectType.MOVE_INTO_AND_PUSH,
		] or _is_motion_type(primary)
	if _typed_extra_property_in_group(property, _ATTACK_TYPED_PROPS):
		return (
			effect_type_can_deal_damage(primary)
			or primary in [
				GameEnums.EffectType.DAMAGE,
				GameEnums.EffectType.DAMAGE_SELF,
				GameEnums.EffectType.EXPLODE,
				GameEnums.EffectType.RANGED_EXPLODE,
			]
		)
	if _typed_extra_property_in_group(property, _HEAL_TYPED_PROPS):
		return primary in [
			GameEnums.EffectType.HEAL,
			GameEnums.EffectType.ARMOR_UP,
			GameEnums.EffectType.CLEANSE,
			GameEnums.EffectType.PURGE,
			GameEnums.EffectType.REMOVE_STATUS,
			GameEnums.EffectType.ADD_STATUS,
			GameEnums.EffectType.ADD_STATUS_SELF,
		]
	if _typed_extra_property_in_group(property, _RESOURCE_TYPED_PROPS):
		return primary in [
			GameEnums.EffectType.GRANT_AP,
			GameEnums.EffectType.GRANT_SCRAP,
			GameEnums.EffectType.REFUND_AP_ON_CC,
		]
	if _typed_extra_property_in_group(property, _SUMMON_TYPED_PROPS):
		return primary == GameEnums.EffectType.SPAWN
	if property == "violent_collision_recast":
		return module_has_during_pass_through(module)
	return false


static var _typed_extra_layer_props: Array[String] = []


static func _ensure_typed_extra_layer_props() -> void:
	if not _typed_extra_layer_props.is_empty():
		return
	var probe := AbilityLayer.new()
	for info: Dictionary in probe.get_property_list():
		var name: String = String(info.name)
		if name.begins_with("_"):
			continue
		if int(info.usage) & PROPERTY_USAGE_STORAGE == 0:
			continue
		if name in ["effect", "condition"]:
			continue
		_typed_extra_layer_props.append(name)


static func _layer_collision_context(layer: AbilityLayer, parent: AbilityModule) -> bool:
	if layer == null or parent == null:
		return false
	return layer.condition in [
		GameEnums.LayerCondition.ON_COLLISION,
		GameEnums.LayerCondition.ON_CHAIN_COLLISION,
		GameEnums.LayerCondition.WHEN_MOVED_THROUGH_ENEMY,
	] or _is_motion_type(parent.primary_type)


static func _layer_motion_context(layer: AbilityLayer, parent: AbilityModule) -> bool:
	if layer == null or parent == null:
		return false
	if layer.condition in [
		GameEnums.LayerCondition.ON_LAND,
		GameEnums.LayerCondition.PER_TILE_MOVED,
	]:
		return true
	return _is_motion_type(parent.primary_type)


static func _layer_effect_type(layer: AbilityLayer) -> GameEnums.EffectType:
	if layer == null or layer.effect == null:
		return GameEnums.EffectType.DAMAGE
	return layer.effect.type


static func layer_typed_field_applies(
	layer: AbilityLayer,
	parent: AbilityModule,
	property: String,
) -> bool:
	if layer == null or property.is_empty():
		return false
	if layer.is_typed_property_set(property):
		return true
	if layer.condition == GameEnums.LayerCondition.DURING:
		return _during_layer_typed_field_applies(layer, property)
	if parent == null:
		return false
	var effect_type: GameEnums.EffectType = _layer_effect_type(layer)
	if _typed_extra_property_in_group(property, _LAYER_COLLISION_PROPS):
		return _layer_collision_context(layer, parent)
	if _typed_extra_property_in_group(property, _LAYER_MOTION_PROPS):
		return _layer_motion_context(layer, parent)
	if _typed_extra_property_in_group(property, _LAYER_HAZARD_PROPS):
		return effect_type in [
			GameEnums.EffectType.CREATE_HAZARD,
			GameEnums.EffectType.CHANGE_TERRAIN,
			GameEnums.EffectType.DESTROY_OBSTACLE,
		] or layer.condition == GameEnums.LayerCondition.ON_LAND
	if _typed_extra_property_in_group(property, _LAYER_ATTACK_PROPS):
		return effect_type_can_deal_damage(effect_type) or effect_type == GameEnums.EffectType.DAMAGE
	if _typed_extra_property_in_group(property, _LAYER_RESOURCE_PROPS):
		return effect_type in [
			GameEnums.EffectType.GRANT_AP,
			GameEnums.EffectType.GRANT_SCRAP,
			GameEnums.EffectType.REFUND_AP_ON_CC,
		]
	if _typed_extra_property_in_group(property, _LAYER_COUNTER_PROPS):
		return effect_type_can_deal_damage(parent.primary_type)
	if _typed_extra_property_in_group(property, _LAYER_SPAWN_PROPS):
		return effect_type == GameEnums.EffectType.SPAWN
	if _typed_extra_property_in_group(property, _LAYER_STATUS_PROPS):
		return effect_type in [
			GameEnums.EffectType.ADD_STATUS,
			GameEnums.EffectType.REMOVE_STATUS,
			GameEnums.EffectType.CLEANSE,
			GameEnums.EffectType.PURGE,
		]
	return false


static func _typed_extra_property_in_group(property: String, group: Array[String]) -> bool:
	return property in group


const _TYPED_EXTRA_LABEL_OVERRIDES: Dictionary = {
	"Range 1 Damage Multiplier": "range_one_damage_multiplier",
	"Shield Closest Ally %": "shield_closest_ally_pct_damage",
	"Revive Max HP %": "revive_percent_max_hp",
	"Construct HP %": "construct_hp_pct",
	"Ignore Target MAG %": "ignore_target_magic_pct",
	"Unacted Target DEF Ignore": "unacted_target_ignore_def_pct",
	"Target DEF % Debuff": "target_def_pct_debuff",
	"Target DEF % Duration": "target_def_pct_duration",
	"Bonus Dmg % Max HP": "bonus_dmg_pct_max_hp",
	"Heal If Targets >=": "heal_if_targets_gte",
	"MAG HEAL": "mag_heal",
	"PUSH": "push",
	"Surface Chain": "bounce_surface_chain",
	"Violent Collision Recast": "violent_collision_recast",
	"Next Ranged Attack STR": "next_ranged_attack_strength",
	"Next Attack BLEED WPN": "next_attack_bleed_weapon",
	"Grapple Pass Damage": "grapple_pass_through_damage",
	"Item Collision STR Div": "item_collision_str_div",
	"Trap BLEED WPN": "trap_bleed_weapon",
	"Crossing WPN Damage": "crossing_weapon_damage",
	"Terrain ID": "terrain_id",
}


const _HAZARD_TYPED_PROPS: Array[String] = [
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
]


const _MOTION_TYPED_PROPS: Array[String] = [
	"preserve_facing", "ignore_zoc", "blink", "vault_obstacle_or_gap_only",
	"pull_self_if_rooted", "pull_until_adjacent", "next_turn", "next_turn_max_move",
	"on_kill_max_move", "movement_mp_override", "cost_all_movement",
	"bonus_per_enemy_passed", "create_trampled_terrain", "upgraded_trample",
	"line_breaker", "landing_adjacent_push", "landing_adjacent_push_stagger",
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
	"shadow_step", "kidnap", "pullback", "chakra_shift", "stop_adjacent_first_enemy",
]


const _FORCED_MOVE_TYPED_PROPS: Array[String] = [
	"push", "buff_on_push", "landing_adjacent_push", "landing_adjacent_push_stagger",
	"pull_until_adjacent", "pull_self_if_rooted", "pull_to_center", "pull_surfaces",
	"intercept_push_attacker", "remove_push_mitigation", "enemy_pushed_mov",
	"sanctuary_enemy_push", "creation_adjacent_push", "mine_pull",
]


const _ATTACK_TYPED_PROPS: Array[String] = [
	"bonus_dmg_from_occupied", "bonus_dmg_per_10_hp", "bonus_dmg_pct_max_hp",
	"bounce_count", "bounce_range", "bounce_walls_45", "skewer", "pierce",
	"next_attack_strength", "next_attack_bleed_weapon", "next_attack_pierce",
	"next_ranged_attack_strength", "root_break_on_damage", "spread_status_adjacent",
	"halve_target_def_one_turn", "armor_explosion_atk", "bonus_atk_vs_fear_or_lower_movement",
	"range_one_damage_multiplier", "bleed_bonus_damage", "target_def_debuff",
	"target_def_pct_debuff", "target_def_pct_duration", "bonus_if_target_adjacent_to_ally",
	"if_target_attacked_caster_last_turn_bonus", "if_target_attacked_caster_last_turn_stagger",
	"unacted_target_ignore_def_pct", "marked_target_defense", "duelist_mark_target",
	"flank_run_adjacent_enemy_bonus", "bonus_per_target_status", "chakra_burst_damage",
	"chakra_burst_size", "landed_magic_bonus", "enemy_mag_atk", "target_magic_defense",
	"steal_target_magic", "ignore_target_magic_pct", "apply_weaken_enemy",
	"creation_adjacent_damage", "trap_damage", "magic_link_damage", "pulse_mag_atk",
	"mechanical_boss_damage_wpn", "wrench_smack", "scrap_attack_bonus",
	"on_hit_scrap", "turret_attack", "on_death_adjacent_damage",
]


const _HEAL_TYPED_PROPS: Array[String] = [
	"heal_if_targets_gte", "mag_heal", "cleanse_target", "shield_closest_ally_pct_damage",
	"ally_str_per_debuff", "sanctuary", "holy_aura", "life_link", "life_link_reduction",
	"revive_percent_max_hp", "revive_shield", "spend_self_hp", "on_kill_all_allies_heal",
	"on_kill_all_allies_shield", "pulse_heal", "pulse_cleanse", "emp_friendly_construct_heal",
	"ally_heal_enemy_wpn", "heal_per_debuff", "sanctuary_enemy_push",
]


const _RESOURCE_TYPED_PROPS: Array[String] = [
	"grant_ap", "grant_scrap", "kill_grant_ap", "frenzy_on_kill_ap", "elemental_surge_ap",
	"target_damaged_ap", "next_skill_zero_ap", "construct_destruction_refund_ap",
	"refund_scrap", "refund_scrap_on_construct_death", "on_hit_scrap",
	"elemental_surge", "utility_only", "does_not_consume_action_slot",
]


const _SUMMON_TYPED_PROPS: Array[String] = [
	"construct_hp_pct", "construct_spawn", "totem_kind", "pulse_aoe", "pulse_fire",
	"turret_attack", "absorbs_items_scrap", "arrival_overclock", "overdrive_injection",
	"sacrifice_construct_instant", "scrap_shield", "shield_depletion_explode",
	"construct_unmitigated_damage", "drop_adjacent", "drop_trap_damage_multiplier",
]


const _LAYER_COLLISION_PROPS: Array[String] = [
	"object_collision_stagger", "enemy_collision_stagger_both", "stagger_on_collision",
	"push_collision_pierce", "push_collision_damage", "collision_splash_damage",
	"collision_splash_weaken", "wall_collision_stagger", "rooted_push_bleed_weapon",
	"grapple_pass_through_damage", "push_if_target_on_water",
]


const _LAYER_MOTION_PROPS: Array[String] = [
	"difficult_terrain_created", "damage_adjacent_on_landing", "arcane_trail",
	"set_max_move", "target_after_move_adjacent", "dash_absorb_element",
	"require_dash_line_enemy", "landing_push", "movement_penalty",
	"spawn_furthest_empty_on_line", "elemental_surface",
]


const _LAYER_HAZARD_PROPS: Array[String] = [
	"terrain_id", "hazard_duration", "hazard_blind_on_entry", "poison_hazard", "oil_field",
	"hazard_damage_bonus", "trap_damage_bonus", "trap_vulnerable", "trap_def_debuff",
	"crossing_blind", "ignite_flammable_terrain", "reaction_terrain",
	"reaction_steam_splash", "reaction_steam_splash_size", "reaction_steam_splash_damage",
	"skip_terrain_entry_status", "skip_terrain_entry_bleed",
]


const _LAYER_ATTACK_PROPS: Array[String] = [
	"weapon_scaled", "range_one_damage_multiplier", "damage_multiplier", "side_attack_only",
	"creation_adjacent_damage", "burning_splash_magic", "pierce_if_first_zero", "bleed_weapon",
]


const _LAYER_RESOURCE_PROPS: Array[String] = [
	"grant_ap", "grant_scrap", "next_turn", "buff_per_destroyed_object", "intercept_grant_str",
]


const _LAYER_COUNTER_PROPS: Array[String] = [
	"counterattack_melee", "counterattack_on_intercept",
]


const _LAYER_SPAWN_PROPS: Array[String] = [
	"construct_hp_pct", "lightning_rod",
]


const _LAYER_STATUS_PROPS: Array[String] = [
	"status_requires_debuff", "cone_all_targets", "from_behind_only", "ally_damage_zero",
]


static func layer_modifier_groups() -> Array[Dictionary]:
	return [
		{"title": "Collision", "props": _LAYER_COLLISION_PROPS},
		{"title": "Motion & landing", "props": _LAYER_MOTION_PROPS},
		{"title": "Hazards & terrain", "props": _LAYER_HAZARD_PROPS},
		{"title": "Attack modifiers", "props": _LAYER_ATTACK_PROPS},
		{"title": "Resources & buffs", "props": _LAYER_RESOURCE_PROPS},
		{"title": "Counters", "props": _LAYER_COUNTER_PROPS},
		{"title": "Spawn & constructs", "props": _LAYER_SPAWN_PROPS},
		{"title": "Status rules", "props": _LAYER_STATUS_PROPS},
	]


static func layer_summary(layer: AbilityLayer) -> String:
	if layer == null:
		return "empty"
	var condition_key: String = GameEnums.LayerCondition.keys()[layer.condition]
	if layer.condition == GameEnums.LayerCondition.DURING:
		return "during %s" % layer_during_preset_label(layer)
	if layer.effect == null:
		return condition_key.to_lower()
	return "%s %s" % [
		condition_key.to_lower(),
		GameEnums.EffectType.keys()[layer.effect.type].to_lower(),
	]


static func layer_during_preset_label(layer: AbilityLayer) -> String:
	if layer == null or layer.effect == null:
		return "?"
	match layer.effect.type:
		GameEnums.EffectType.BULLDOZE:
			return "bulldoze"
		GameEnums.EffectType.TRAMPLE:
			return "trample"
		GameEnums.EffectType.ADD_STATUS_SELF:
			match layer.effect.status_type:
				GameEnums.StatusType.GHOST:
					return "ghost"
				GameEnums.StatusType.PIERCE:
					return "pierce"
				_:
					return "status_self"
		_:
			return GameEnums.EffectType.keys()[layer.effect.type].to_lower()


static func layer_during_presets(module: AbilityModule) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if module == null or not _is_motion_type(module.primary_type):
		return out
	out.append({"id": &"bulldoze", "label": "Bulldoze — push through obstacles"})
	out.append({"id": &"trample", "label": "Trample — ignore difficult terrain"})
	out.append({"id": &"ghost", "label": "Ghost — pass through units"})
	if effect_type_can_deal_damage(module.primary_type) or _is_motion_type(module.primary_type):
		out.append({"id": &"pierce", "label": "Pierce — ignore block on next hit"})
	return out


static func layer_during_preset_id(layer: AbilityLayer) -> StringName:
	if layer == null or layer.effect == null:
		return &""
	match layer.effect.type:
		GameEnums.EffectType.BULLDOZE:
			return &"bulldoze"
		GameEnums.EffectType.TRAMPLE:
			return &"trample"
		GameEnums.EffectType.ADD_STATUS_SELF:
			match layer.effect.status_type:
				GameEnums.StatusType.GHOST:
					return &"ghost"
				GameEnums.StatusType.PIERCE:
					return &"pierce"
				_:
					return &""
		_:
			return &""


static func apply_layer_during_preset(layer: AbilityLayer, preset_id: StringName) -> void:
	if layer == null:
		return
	if layer.effect == null:
		layer.effect = EffectData.new()
	layer.condition = GameEnums.LayerCondition.DURING
	match preset_id:
		&"bulldoze":
			layer.effect.type = GameEnums.EffectType.BULLDOZE
			layer.effect.amount = maxi(1, layer.effect.amount)
			layer.during_emit_effect = true
		&"trample":
			layer.effect.type = GameEnums.EffectType.TRAMPLE
			layer.effect.amount = maxi(1, layer.effect.amount)
			layer.during_emit_effect = true
		&"ghost":
			layer.effect.type = GameEnums.EffectType.ADD_STATUS_SELF
			layer.effect.status_type = GameEnums.StatusType.GHOST
			layer.effect.amount = 1
			layer.during_emit_effect = false
		&"pierce":
			layer.effect.type = GameEnums.EffectType.ADD_STATUS_SELF
			layer.effect.status_type = GameEnums.StatusType.PIERCE
			layer.effect.amount = 1
			layer.during_emit_effect = false
		_:
			pass
	AbilityModuleBridge.normalize_effect_authoring_fields(layer.effect)


static func ensure_layer_during_compatible(module: AbilityModule, layer: AbilityLayer) -> void:
	if layer == null or module == null:
		return
	if layer.condition != GameEnums.LayerCondition.DURING:
		return
	if during_layer_compatible(module, layer):
		return
	var presets: Array[Dictionary] = layer_during_presets(module)
	if presets.is_empty():
		layer.condition = GameEnums.LayerCondition.AT_RESOLUTION
		return
	apply_layer_during_preset(layer, presets[0]["id"])


static func _during_layer_typed_field_applies(layer: AbilityLayer, property: String) -> bool:
	if layer == null or layer.effect == null:
		return false
	if property == "during_bulldoze_push":
		return layer.effect.type == GameEnums.EffectType.BULLDOZE
	match layer.effect.type:
		GameEnums.EffectType.BULLDOZE:
			return property in _LAYER_COLLISION_PROPS
		GameEnums.EffectType.TRAMPLE:
			return property in ["weapon_scaled", "difficult_terrain_created"]
		GameEnums.EffectType.ADD_STATUS_SELF:
			if layer.effect.status_type == GameEnums.StatusType.PIERCE:
				return property == "pierce_if_first_zero"
			return false
		_:
			return false
