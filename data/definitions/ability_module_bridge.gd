class_name AbilityModuleBridge
extends RefCounted

## Purpose: Compile authored AbilityModule profiles into transient EffectData
## execution payloads.
## Responsibilities: Normalize module authoring and preserve module/layer order
## while runtime systems consume the shared EffectData execution contract.
## Dependencies: AbilityData, AbilityModule, AbilityLayer, AbilityKeyword, EffectData, GameEnums.
## Lifecycle: static helpers; no instance state.


## Canonical tags (ability-data.md §0).
const TAG_ATTACK := &"attack"
const TAG_MOVEMENT := &"movement"
const TAG_POSITIONING := &"positioning"
const TAG_SPELL := &"spell"
const TAG_HEAL := &"heal"

const _ModuleAuthoringRules := preload("res://data/definitions/module_authoring_rules.gd")


static func normalize_effect_status_fields(effect: EffectData) -> void:
	if effect == null:
		return
	if not GameEnums.effect_type_applies_status(effect.type):
		effect.status_type = GameEnums.StatusType.NONE
	elif effect.status_type == GameEnums.StatusType.NONE:
		effect.status_type = GameEnums.StatusType.STAT_BUFF_STR


static func normalize_module_status_fields(module: AbilityModule) -> void:
	if module == null:
		return
	if not GameEnums.effect_type_applies_status(module.primary_type):
		module.status_type = GameEnums.StatusType.NONE
	elif module.status_type == GameEnums.StatusType.NONE:
		module.status_type = GameEnums.StatusType.STAT_BUFF_STR
	for layer: AbilityLayer in module.layers:
		if layer != null and layer.effect != null:
			normalize_effect_status_fields(layer.effect)


static func normalize_effect_authoring_fields(effect: EffectData) -> void:
	normalize_effect_status_fields(effect)
	if not GameEnums.effect_type_uses_module_scaling(effect.type):
		effect.scaling_stat = GameEnums.StatType.NONE
	if effect.type != GameEnums.EffectType.DAMAGE:
		effect.bonus_if_adjacent_at_cast = 0
		effect.def_debuff_before_damage = 0
	if not GameEnums.effect_type_uses_spawn_unit(effect.type):
		effect.spawn_unit_id = &""


static func normalize_module_authoring_fields(
	module: AbilityModule,
	planner_group: GameEnums.PlannerGroup = GameEnums.PlannerGroup.ACTION,
	module_index: int = 0,
) -> void:
	if module == null:
		return
	module.invalidate_runtime_modifiers_cache()
	normalize_module_status_fields(module)
	if not GameEnums.effect_type_uses_module_scaling(module.primary_type):
		module.scaling_stat = GameEnums.StatType.NONE
	if module.primary_type != GameEnums.EffectType.DAMAGE:
		module.bonus_if_adjacent_at_cast = 0
		module.def_debuff_before_damage = 0
	_normalize_hit_count(module)
	if module.aim_binding != GameEnums.AimBinding.SAME_AS_MODULE_N:
		module.aim_module_index = 0
	if not GameEnums.effect_type_uses_spawn_unit(module.primary_type):
		module.spawn_unit_id = &""
	if module.target_shape == GameEnums.TargetShape.SINGLE:
		module.target_shape_size = 1
	_ModuleAuthoringRules.normalize_module_context_fields(module, planner_group, module_index)
	for layer: AbilityLayer in module.layers:
		if layer == null:
			continue
		if layer.effect != null:
			normalize_effect_authoring_fields(layer.effect)
		for key: String in _ModuleAuthoringRules.excluded_layer_conditions(module):
			if layer.condition == GameEnums.LayerCondition[key]:
				layer.condition = GameEnums.LayerCondition.AT_RESOLUTION
				break


static func validate_modules(
	modules: Array[AbilityModule],
	planner_group: GameEnums.PlannerGroup = GameEnums.PlannerGroup.ACTION,
) -> Array[String]:
	var errors: Array[String] = []
	for index: int in modules.size():
		var module: AbilityModule = modules[index]
		if module == null:
			errors.append("module %d is null" % index)
			continue
		if (
			(module.primary_type == GameEnums.EffectType.MOVE
			or module.primary_type == GameEnums.EffectType.DASH)
			and module.min_range < 1
		):
			errors.append("module %d MOVE/DASH min_range must be >= 1" % index)
		if module.max_range < module.min_range:
			errors.append("module %d max_range is below min_range" % index)
		if (
			module.targeting_flags & GameEnums.TargetingFlags.DASH_LINE
			and module.primary_type != GameEnums.EffectType.DASH
		):
			errors.append("module %d DASH_LINE requires a DASH primary" % index)
		if module.primary_type == GameEnums.EffectType.SWAP and module.target_shape != GameEnums.TargetShape.SINGLE:
			errors.append("module %d SWAP requires SINGLE shape" % index)
		if (
			module.target_shape == GameEnums.TargetShape.SINGLE
			and module.target_shape_size != 1
		):
			errors.append("module %d SINGLE shape requires size 1" % index)
		if (
			module.target_shape != GameEnums.TargetShape.SINGLE
			and module.target_shape_size < 1
		):
			errors.append("module %d shaped target requires size >= 1" % index)
		if (
			planner_group == GameEnums.PlannerGroup.ACTION
			and (
				module.primary_type == GameEnums.EffectType.PAIRED_MOVE
				or (
					module.primary_type == GameEnums.EffectType.SWAP
					and (module.targeting_flags & GameEnums.TargetingFlags.ALLY) != 0
				)
			)
		):
			errors.append("module %d ally relocation is legal only in PRE_MOVE" % index)
	return errors


## Typed runtime queries for module-owned behavior.
## These keep AbilitySystem/PhysicsSystem on the typed module profile instead of
## reconstructing decisions from transient execution payloads.
static func module_has_effect(module: AbilityModule, effect_type: GameEnums.EffectType) -> bool:
	if module == null:
		return false
	if module.primary_type == effect_type:
		return true
	for keyword: AbilityKeyword in module.keywords:
		if keyword == null:
			continue
		if (
			keyword.emit_as_effect
			and keyword.keyword_id == GameEnums.AbilityKeywordId.TRAMPLE
			and effect_type == GameEnums.EffectType.TRAMPLE
		):
			return true
		if (
			keyword.emit_as_effect
			and keyword.keyword_id == GameEnums.AbilityKeywordId.BULLDOZE
			and effect_type == GameEnums.EffectType.BULLDOZE
		):
			return true
	for layer: AbilityLayer in module.layers:
		if layer != null and layer.effect != null and layer.effect.type == effect_type:
			return true
	return false


static func module_effect_amount(module: AbilityModule, effect_type: GameEnums.EffectType) -> int:
	if module == null:
		return 0
	if module.primary_type == effect_type:
		return module.amount
	for keyword: AbilityKeyword in module.keywords:
		if keyword == null or not keyword.emit_as_effect:
			continue
		if (
			keyword.keyword_id == GameEnums.AbilityKeywordId.TRAMPLE
			and effect_type == GameEnums.EffectType.TRAMPLE
		):
			return keyword.amount
		if (
			keyword.keyword_id == GameEnums.AbilityKeywordId.BULLDOZE
			and effect_type == GameEnums.EffectType.BULLDOZE
		):
			return keyword.amount
	for layer: AbilityLayer in module.layers:
		if layer != null and layer.effect != null and layer.effect.type == effect_type:
			return layer.effect.amount
	return 0


static func module_has_modifier(module: AbilityModule, key: StringName) -> bool:
	if module == null:
		return false
	var key_text: String = String(key)
	var runtime: Dictionary = module.compile_runtime_modifiers()
	if runtime.has(key) or runtime.has(key_text):
		return true
	for layer: AbilityLayer in module.layers:
		if layer != null and (
			layer.compile_runtime_modifiers().has(key_text)
			or (
				layer.effect != null
				and layer.effect.modifiers.has(key_text)
			)
		):
			return true
	for keyword: AbilityKeyword in module.keywords:
		if keyword == null:
			continue
		match key:
			&"bulldoze":
				if keyword.keyword_id == GameEnums.AbilityKeywordId.BULLDOZE:
					return true
			&"push":
				if keyword.keyword_id == GameEnums.AbilityKeywordId.BULLDOZE and keyword.push_amount != 0:
					return true
			&"ghost_move":
				if keyword.keyword_id == GameEnums.AbilityKeywordId.GHOST:
					return true
			&"next_attack_pierce":
				if keyword.keyword_id == GameEnums.AbilityKeywordId.PIERCE:
					return true
			_:
				pass
	return false


static func module_modifier_value(module: AbilityModule, key: StringName, default_value: int = 0) -> int:
	if module == null:
		return default_value
	var key_text: String = String(key)
	var runtime: Dictionary = module.compile_runtime_modifiers()
	if runtime.has(key_text):
		return int(runtime[key_text])
	for layer: AbilityLayer in module.layers:
		if layer == null:
			continue
		var layer_runtime := layer.compile_runtime_modifiers()
		if layer_runtime.has(key_text):
			return int(layer_runtime[key_text])
		if layer.effect != null and layer.effect.modifiers.has(key_text):
			return int(layer.effect.modifiers[key_text])
	for keyword: AbilityKeyword in module.keywords:
		if keyword == null:
			continue
		match key:
			&"bulldoze":
				if keyword.keyword_id == GameEnums.AbilityKeywordId.BULLDOZE:
					return keyword.amount
			&"push":
				if keyword.keyword_id == GameEnums.AbilityKeywordId.BULLDOZE:
					return keyword.push_amount
			&"ghost_move":
				if keyword.keyword_id == GameEnums.AbilityKeywordId.GHOST:
					return 1
			&"next_attack_pierce":
				if keyword.keyword_id == GameEnums.AbilityKeywordId.PIERCE:
					return 1
			_:
				pass
	return default_value


static func modules_have_effect(
	modules: Array[AbilityModule],
	effect_type: GameEnums.EffectType,
) -> bool:
	for module: AbilityModule in modules:
		if module_has_effect(module, effect_type):
			return true
	return false


static func modules_have_modifier(modules: Array[AbilityModule], key: StringName) -> bool:
	for module: AbilityModule in modules:
		if module_has_modifier(module, key):
			return true
	return false


static func modules_modifier_value(
	modules: Array[AbilityModule],
	key: StringName,
	default_value: int = 0,
) -> int:
	for module: AbilityModule in modules:
		if module_has_modifier(module, key):
			return module_modifier_value(module, key, default_value)
	return default_value


static func pass_through_modifiers_from_modules(modules: Array[AbilityModule]) -> Dictionary:
	var trample_atk: int = 0
	var bulldoze: int = 0
	var push: int = 0
	for module: AbilityModule in modules:
		if module == null:
			continue
		if module.primary_type == GameEnums.EffectType.TRAMPLE:
			trample_atk = module.amount
		elif module.primary_type == GameEnums.EffectType.BULLDOZE:
			bulldoze = module.amount
		for keyword: AbilityKeyword in module.keywords:
			if keyword == null:
				continue
			if keyword.keyword_id == GameEnums.AbilityKeywordId.TRAMPLE:
				trample_atk = keyword.amount
			elif keyword.keyword_id == GameEnums.AbilityKeywordId.BULLDOZE:
				bulldoze = keyword.amount
				push = keyword.push_amount
		bulldoze = maxi(bulldoze, module_modifier_value(module, &"bulldoze", 0))
		push = maxi(push, module_modifier_value(module, &"push", 0))
		trample_atk = maxi(trample_atk, module_modifier_value(module, &"trample_atk", 0))
		for layer: AbilityLayer in module.layers:
			if (
				layer != null
				and layer.effect != null
				and layer.effect.type == GameEnums.EffectType.PUSH
			):
				push = maxi(push, layer.effect.amount)
	return {
		"trample_atk": trample_atk,
		"bulldoze": bulldoze,
		"push": push,
	}


static func planner_group_from_kind(kind: GameEnums.AbilityKind) -> GameEnums.PlannerGroup:
	match kind:
		GameEnums.AbilityKind.MOVEMENT_SKILL:
			return GameEnums.PlannerGroup.PRE_MOVE
		_:
			return GameEnums.PlannerGroup.ACTION


static func kind_from_planner_group(
	planner_group: GameEnums.PlannerGroup,
	existing_kind: GameEnums.AbilityKind
) -> GameEnums.AbilityKind:
	## Preserve UNIVERSAL_* system actions; only map class-library cards.
	if (
		existing_kind == GameEnums.AbilityKind.UNIVERSAL_RUN
		or existing_kind == GameEnums.AbilityKind.UNIVERSAL_WAIT
	):
		return existing_kind
	match planner_group:
		GameEnums.PlannerGroup.PRE_MOVE:
			return GameEnums.AbilityKind.MOVEMENT_SKILL
		_:
			return GameEnums.AbilityKind.CLASS_SKILL


static func sync_legacy_from_header(ability: AbilityData) -> void:
	if ability == null:
		return
	ability.kind = kind_from_planner_group(ability.planner_group, ability.kind)
	ability.is_movement_skill = ability.planner_group == GameEnums.PlannerGroup.PRE_MOVE
	match ability.primary_resource:
		GameEnums.CostResource.MP:
			ability.movement_point_cost = ability.primary_value
		GameEnums.CostResource.AP:
			ability.action_point_cost = ability.primary_value
		_:
			pass
## Expand one module without applying its resolution gate.
## The caller owns gate timing; this preserves module order and layer order.
static func compile_module_to_effects(module: AbilityModule) -> Array[EffectData]:
	var out: Array[EffectData] = []
	if module == null:
		return out
	var primary: EffectData = module.primary_as_effect()
	_apply_keywords_to_effect(primary, module)
	out.append(primary)
	for kw: AbilityKeyword in module.keywords:
		if kw == null or not kw.emit_as_effect:
			continue
		if kw.keyword_id == GameEnums.AbilityKeywordId.TRAMPLE:
			var trample_eff := EffectData.new()
			trample_eff.type = GameEnums.EffectType.TRAMPLE
			trample_eff.amount = kw.amount
			out.append(trample_eff)
		elif kw.keyword_id == GameEnums.AbilityKeywordId.BULLDOZE:
			var bulldoze_eff := EffectData.new()
			bulldoze_eff.type = GameEnums.EffectType.BULLDOZE
			bulldoze_eff.amount = kw.amount
			out.append(bulldoze_eff)
	for layer: AbilityLayer in module.layers:
		if layer == null or layer.effect == null:
			continue
		var layer_eff: EffectData = _duplicate_effect(layer.effect)
		_merge_runtime_modifiers(layer_eff, module.compile_runtime_modifiers())
		_merge_runtime_modifiers(layer_eff, layer.compile_runtime_modifiers())
		_apply_layer_condition_to_effect(layer_eff, layer.condition)
		out.append(layer_eff)
	return out


static func compile_modules_to_effects(modules: Array[AbilityModule]) -> Array[EffectData]:
	var out: Array[EffectData] = []
	for mod: AbilityModule in modules:
		if mod == null:
			continue
		if mod.gate == GameEnums.ModuleGate.IF_COLLIDED:
			continue
		out.append_array(compile_module_to_effects(mod))
	return out


static func clear_module_profile(ability: AbilityData, upgraded: bool) -> void:
	if ability == null:
		return
	if upgraded:
		ability.upgraded_modules.clear()
	else:
		ability.modules.clear()


static func normalize_ability(ability: AbilityData) -> void:
	if ability == null:
		return
	## Factories author module profiles and header targeting together. Normalize
	## only the typed profile; never infer one from a flat effect list.
	_prefer_authored_targeting_mode(ability)
	for index: int in ability.modules.size():
		var module: AbilityModule = ability.modules[index]
		if module != null:
			normalize_module_authoring_fields(module, ability.planner_group, index)
	for index: int in ability.upgraded_modules.size():
		var upgraded_module: AbilityModule = ability.upgraded_modules[index]
		if upgraded_module != null:
			normalize_module_authoring_fields(
				upgraded_module, ability.planner_group, index
			)
	if not ability.modules.is_empty():
		_apply_module_range_to_ability(ability, ability.modules)
	sync_legacy_from_header(ability)
	_promote_header_extras(ability)
	_prefer_authored_targeting_mode(ability)
	ability.sync_legacy_targeting()


static func _prefer_authored_targeting_mode(ability: AbilityData) -> void:
	## Only reconcile self-target authoring. TILE/DASH_LINE skills often set flags as
	## source of truth while mode is a legacy mirror — do not clobber those.
	if (
		ability.targeting_mode == GameEnums.TargetingMode.SELF
	):
		ability.targeting_flags = GameEnums.TargetingFlags.SELF
		ability.targeting_mode = GameEnums.TargetingMode.SELF


static func _apply_module_range_to_ability(ability: AbilityData, modules: Array[AbilityModule]) -> void:
	## Header range follows the first player aim (first NEW_AIM module). Shape still
	## comes from the first non-motion NEW_AIM, or from a motion landing footprint.
	var first_module: AbilityModule = null
	var first_new_aim: AbilityModule = null
	var first_non_motion_aim: AbilityModule = null
	for mod: AbilityModule in modules:
		if mod == null:
			continue
		if first_module == null:
			first_module = mod
		if mod.aim_binding != GameEnums.AimBinding.NEW_AIM:
			continue
		if first_new_aim == null:
			first_new_aim = mod
		if not is_motion_type(mod.primary_type) and first_non_motion_aim == null:
			first_non_motion_aim = mod
	if first_new_aim != null:
		ability.range_tiles = first_new_aim.max_range
	if first_non_motion_aim != null:
		ability.target_shape = first_non_motion_aim.target_shape
		ability.target_shape_size = first_non_motion_aim.target_shape_size
		if first_non_motion_aim.targeting_flags != 0:
			ability.targeting_flags |= first_non_motion_aim.targeting_flags
		return
	if (
		first_module != null
		and is_motion_type(first_module.primary_type)
		and first_module.target_shape != GameEnums.TargetShape.SINGLE
	):
		ability.target_shape = first_module.target_shape
		ability.target_shape_size = first_module.target_shape_size
		if first_module.targeting_flags != 0:
			ability.targeting_flags = first_module.targeting_flags


static func is_motion_type(t: GameEnums.EffectType) -> bool:
	return (
		GameEnums.is_walk_motion(t)
		or GameEnums.is_jump_motion(t)
		or GameEnums.is_teleport_motion(t)
		or t == GameEnums.EffectType.DASH
		or t == GameEnums.EffectType.SWAP
		or t == GameEnums.EffectType.MOVE_INTO_AND_PUSH
	)


static func first_motion_module(
	modules: Array[AbilityModule],
	exclude_post_phase: bool = false,
	require_always_gate: bool = false,
) -> AbilityModule:
	for module: AbilityModule in modules:
		if module == null or not is_motion_type(module.primary_type):
			continue
		if require_always_gate and module.gate != GameEnums.ModuleGate.ALWAYS:
			continue
		if exclude_post_phase and module.execution_phase == GameEnums.ModulePhase.ON_POST:
			continue
		return module
	return null


static func module_is_caster_movement(module: AbilityModule) -> bool:
	if module == null:
		return false
	if module.primary_type in [
		GameEnums.EffectType.DASH,
		GameEnums.EffectType.MOVE_INTO_AND_PUSH,
	]:
		return true
	if GameEnums.is_teleport_motion(module.primary_type):
		return (
			not module_has_modifier(module, &"reposition_opposite_side")
			and not module_has_modifier(module, &"airlift_keep_caster")
		)
	if GameEnums.is_path_motion(module.primary_type):
		return (
			not module_has_modifier(module, &"post_attack_move")
			and not module_has_modifier(module, &"relocate_target")
			and not module_has_modifier(module, &"relocate_subject_only")
		)
	return false


static func _merge_runtime_modifiers(effect: EffectData, runtime: Dictionary) -> void:
	if effect == null:
		return
	for key: Variant in runtime:
		var key_text: String = String(key)
		if key_text.is_empty() or effect.modifiers.has(key_text):
			continue
		effect.modifiers[key_text] = runtime[key]


static func _promote_header_extras(ability: AbilityData) -> void:
	if ability == null:
		return
	if ability.cost_modifier == GameEnums.CostModifier.NONE and modules_have_modifier(
		ability.modules, &"cost_all_movement"
	):
		ability.cost_modifier = GameEnums.CostModifier.SPEND_ALL_MOVEMENT
	if not ability.once_per_turn and modules_have_modifier(ability.modules, &"limit_once_per_turn"):
		ability.once_per_turn = true


static func _normalize_hit_count(module: AbilityModule) -> void:
	if module == null:
		return
	if module.primary_type != GameEnums.EffectType.DAMAGE:
		module.hit_count = 1
	elif module.hit_count < 1:
		module.hit_count = 1


static func _apply_keywords_to_effect(eff: EffectData, mod: AbilityModule) -> void:
	for kw: AbilityKeyword in mod.keywords:
		if kw == null:
			continue
		match kw.keyword_id:
			GameEnums.AbilityKeywordId.TRAMPLE:
				## Keep EffectType.TRAMPLE as primary when authored that way; else flag.
				if eff.type != GameEnums.EffectType.TRAMPLE:
					eff.modifiers["trample"] = kw.amount
			GameEnums.AbilityKeywordId.BULLDOZE:
				eff.modifiers["bulldoze"] = kw.amount
				if kw.push_amount != 0:
					eff.modifiers["push"] = kw.push_amount
			GameEnums.AbilityKeywordId.GHOST:
				eff.modifiers["ghost_move"] = 1
			GameEnums.AbilityKeywordId.PIERCE:
				eff.modifiers["next_attack_pierce"] = 1
			_:
				pass


static func _apply_layer_condition_to_effect(eff: EffectData, condition: GameEnums.LayerCondition) -> void:
	match condition:
		GameEnums.LayerCondition.ON_COLLISION:
			if not eff.modifiers.has("object_collision_stagger") and not eff.modifiers.has("stagger_on_collision"):
				eff.modifiers["stagger_on_collision"] = 1
		GameEnums.LayerCondition.ON_CHAIN_COLLISION:
			## Represented by PUSH_CHAIN_COLLISION effect type historically.
			pass
		GameEnums.LayerCondition.ON_LAND:
			eff.modifiers["damage_adjacent_on_landing"] = 1
		GameEnums.LayerCondition.PER_TARGET_HIT:
			eff.modifiers["heal_per_target_hit"] = 1
		GameEnums.LayerCondition.ON_KILL:
			if not eff.modifiers.has("on_kill_heal_shield") and not eff.modifiers.has("frenzy_on_kill_ap"):
				eff.modifiers["on_kill_heal_shield"] = 1
		GameEnums.LayerCondition.IF_FROM_BEHIND:
			eff.modifiers["from_behind_only"] = true
		_:
			pass


static func _duplicate_effect(src: EffectData) -> EffectData:
	var eff := EffectData.new()
	eff.type = src.type
	eff.amount = src.amount
	eff.status_type = src.status_type
	eff.status_duration = src.status_duration
	eff.scaling_stat = src.scaling_stat
	eff.spawn_unit_id = src.spawn_unit_id
	eff.bonus_if_adjacent_at_cast = src.bonus_if_adjacent_at_cast
	eff.def_debuff_before_damage = src.def_debuff_before_damage
	eff.modifiers = src.modifiers.duplicate(true)
	return eff
