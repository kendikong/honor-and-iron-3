class_name AbilityModuleBridge
extends RefCounted

## Purpose: Compile modular AbilityModule lists ↔ legacy flat EffectData lists.
## Responsibilities: One-way authoring/compatibility bridge while factories and the
## editor author modules (ability-data.md §12.15). Native runtime decisions stay
## on typed module queries and ordered module execution.
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
	if not _ModuleAuthoringRules.module_uses_motion_mode(module.primary_type):
		module.motion_mode = GameEnums.MotionMode.NONE
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


static func validate_modules(modules: Array[AbilityModule]) -> Array[String]:
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
	return errors


## Typed runtime queries for module-owned behavior.
## These keep AbilitySystem/PhysicsSystem from treating the transitional
## effects[] cache as a second source of active decisions.
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
		if layer != null and layer.effect != null and layer.effect.modifiers.has(key_text):
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
		if layer != null and layer.effect != null and layer.effect.modifiers.has(key_text):
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


static func sync_header_from_legacy(ability: AbilityData) -> void:
	if ability == null:
		return
	ability.planner_group = planner_group_from_kind(ability.kind)
	if ability.primary_resource == GameEnums.CostResource.NONE:
		if ability.planner_group == GameEnums.PlannerGroup.PRE_MOVE:
			ability.primary_resource = GameEnums.CostResource.MP
			ability.primary_value = ability.movement_point_cost
		else:
			ability.primary_resource = GameEnums.CostResource.AP
			ability.primary_value = ability.action_point_cost
	## Promote zero-AP-adjacent cost modifier into header cost block.
	for eff: EffectData in ability.effects:
		if eff != null and eff.modifiers.has("zero_ap_adjacent_enemies"):
			ability.cost_modifier = GameEnums.CostModifier.ZERO_IF_ADJACENT_ENEMIES_GTE_N
			ability.cost_modifier_n = int(eff.modifiers["zero_ap_adjacent_enemies"])
			break
	if ability.tags.is_empty():
		ability.tags = _infer_tags(ability)


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
	if ability.cost_modifier == GameEnums.CostModifier.ZERO_IF_ADJACENT_ENEMIES_GTE_N:
		_ensure_zero_ap_modifier_on_effects(ability)
	if ability.cost_modifier == GameEnums.CostModifier.SPEND_ALL_MOVEMENT:
		_ensure_spend_all_movement_on_effects(ability)
	if ability.once_per_turn and not ability.effects.is_empty() and ability.effects[0] != null:
		ability.effects[0].modifiers["limit_once_per_turn"] = true


## Expand one module without applying its resolution gate.
## The caller owns gate timing; this preserves module order and layer order.
static func compile_module_to_effects(module: AbilityModule) -> Array[EffectData]:
	var out: Array[EffectData] = []
	if module == null:
		return out
	var primary: EffectData = module.primary_as_effect()
	if module.motion_mode != GameEnums.MotionMode.NONE:
		primary.modifiers["motion_mode"] = module.motion_mode
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
		_apply_layer_condition_to_effect(layer_eff, layer.condition)
		out.append(layer_eff)
	return out


## Compatibility list: only unconditional modules are exposed for unmigrated
## EffectData readers. AbilitySystem resolves module gates from ordered simulation
## events; this list must never decide whether a gated module runs.
static func compile_modules_for_runtime(modules: Array[AbilityModule]) -> Array[EffectData]:
	var out: Array[EffectData] = []
	var has_collided_gate := false
	for module: AbilityModule in modules:
		if module == null:
			continue
		if module.gate == GameEnums.ModuleGate.IF_COLLIDED:
			has_collided_gate = true
			continue
		if module.gate != GameEnums.ModuleGate.ALWAYS:
			continue
		out.append_array(compile_module_to_effects(module))
	if has_collided_gate and not out.is_empty():
		out[0].modifiers["violent_collision_recast"] = 1
	return out


static func compile_modules_to_effects(modules: Array[AbilityModule]) -> Array[EffectData]:
	var out: Array[EffectData] = []
	var has_collided_gate := false
	for mod: AbilityModule in modules:
		if mod == null:
			continue
		## Gated follow-ups (e.g. Violent Collision MOVE) are modular authoring only until
		## AbilitySystem executes gates natively. Legacy flat list keeps the stamp modifier
		## on the prior motion primary — do not emit a second MOVE effect here.
		if mod.gate == GameEnums.ModuleGate.IF_COLLIDED:
			has_collided_gate = true
			continue
		out.append_array(compile_module_to_effects(mod))
	if has_collided_gate and not out.is_empty():
		var stamp: EffectData = out[0]
		if stamp != null:
			stamp.modifiers["violent_collision_recast"] = 1
	return out


static func clear_module_profile(ability: AbilityData, upgraded: bool) -> void:
	if ability == null:
		return
	if upgraded:
		ability.upgraded_modules.clear()
		ability.upgraded_effects.clear()
	else:
		ability.modules.clear()
		ability.effects.clear()


static func _copy_effect_to_module(effect: EffectData, module: AbilityModule) -> void:
	if effect == null or module == null:
		return
	module.amount = effect.amount
	module.status_type = effect.status_type
	module.status_duration = effect.status_duration
	module.scaling_stat = effect.scaling_stat
	module.spawn_unit_id = effect.spawn_unit_id
	module.bonus_if_adjacent_at_cast = effect.bonus_if_adjacent_at_cast
	module.def_debuff_before_damage = effect.def_debuff_before_damage
	_normalize_hit_count(module)


static func _copy_effect_to_effect(source: EffectData, target: EffectData) -> void:
	if source == null or target == null:
		return
	target.amount = source.amount
	target.status_type = source.status_type
	target.status_duration = source.status_duration
	target.scaling_stat = source.scaling_stat
	target.spawn_unit_id = source.spawn_unit_id
	target.bonus_if_adjacent_at_cast = source.bonus_if_adjacent_at_cast
	target.def_debuff_before_damage = source.def_debuff_before_damage
	target.modifiers = source.modifiers.duplicate(true)


static func _sync_modules_from_generated_effects(ability: AbilityData) -> void:
	if ability == null or ability.modules.is_empty():
		return
	var cursor: int = 0
	for module: AbilityModule in ability.modules:
		if module == null or module.gate != GameEnums.ModuleGate.ALWAYS:
			continue
		if cursor >= ability.effects.size():
			return
		_copy_effect_to_module(ability.effects[cursor], module)
		cursor += 1
		for keyword: AbilityKeyword in module.keywords:
			if keyword != null and keyword.emit_as_effect:
				cursor += 1
		for layer: AbilityLayer in module.layers:
			if layer == null or layer.effect == null:
				continue
			if cursor >= ability.effects.size():
				return
			_copy_effect_to_effect(ability.effects[cursor], layer.effect)
			cursor += 1


static func infer_modules_from_effects(
	effects: Array[EffectData],
	ability: AbilityData
) -> Array[AbilityModule]:
	var modules: Array[AbilityModule] = []
	if effects.is_empty():
		return modules
	## Bible mapping (ability-data.md §2 / §5 / §6), compile-stable:
	## - Motion primary → module; TRAMPLE/BULLDOZE EffectTypes → keywords on that motion.
	## - Motion add-ons (Trampling PUSH, Bowling chain, collision riders) → layers on that motion.
	## - After a motion module, the next strike (e.g. DAMAGE) starts a new module (move then attack).
	## - Same-aim extras on a non-motion module → layers (AT_RESOLUTION unless modifiers say otherwise).
	for eff: EffectData in effects:
		if eff == null:
			continue
		if (
			not modules.is_empty()
			and _is_pass_through_type(eff.type)
			and is_motion_type(modules[modules.size() - 1].primary_type)
		):
			_merge_pass_through_into_motion(modules[modules.size() - 1], eff)
			continue
		if modules.is_empty() or is_motion_type(eff.type):
			var mod: AbilityModule = _module_from_primary_effect(eff, ability)
			modules.append(mod)
			continue
		if is_motion_type(modules[modules.size() - 1].primary_type):
			if _layers_on_motion_module(eff):
				var motion_layer := AbilityLayer.new()
				motion_layer.effect = _duplicate_effect(eff)
				motion_layer.condition = _infer_layer_condition(eff)
				modules[modules.size() - 1].layers.append(motion_layer)
				continue
			## Strike after motion — new module with its own aim (same-target extras are layers).
			var after_move: AbilityModule = _module_from_primary_effect(eff, ability)
			modules.append(after_move)
			continue
		var layer := AbilityLayer.new()
		layer.effect = _duplicate_effect(eff)
		layer.condition = _infer_layer_condition(eff)
		modules[modules.size() - 1].layers.append(layer)
	## Recast stamp (modifiers) → gated follow-up MOVE module (bible §2.7 / §10 Violent Collision).
	if (
		not modules.is_empty()
		and modules[0].runtime_has("violent_collision_recast")
		and modules.size() == 1
	):
		var motion_mod: AbilityModule = modules[0]
		motion_mod.keywords = _ensure_bulldoze_keyword(motion_mod)
		var move_mod := AbilityModule.new()
		move_mod.execution_phase = GameEnums.ModulePhase.ON_ACTION
		move_mod.primary_type = GameEnums.EffectType.MOVE
		move_mod.min_range = 1
		move_mod.max_range = 2
		move_mod.motion_mode = GameEnums.MotionMode.NONE
		move_mod.targeting_flags = GameEnums.TargetingFlags.TILE
		move_mod.gate = GameEnums.ModuleGate.IF_COLLIDED
		move_mod.aim_binding = GameEnums.AimBinding.NEW_AIM
		modules.append(move_mod)
	return modules


## Populate modules from flat effects when modules empty; compile modules → effects when modules set.
static func finalize_ability(ability: AbilityData) -> void:
	if ability == null:
		return
	## Factories often set targeting_mode after _configure_ability_targeting left flags on a
	## different value (e.g. SELF mode with ALLY flags). Prefer authored mode → flags.
	_prefer_authored_targeting_mode(ability)
	if ability.modules.is_empty() and not ability.effects.is_empty():
		sync_header_from_legacy(ability)
		ability.modules = infer_modules_from_effects(ability.effects, ability)
	if ability.upgraded_modules.is_empty() and not ability.upgraded_effects.is_empty():
		var upgraded_proxy := AbilityData.new()
		upgraded_proxy.range_tiles = (
			ability.upgraded_range_tiles if ability.upgraded_range_tiles >= 0 else ability.range_tiles
		)
		upgraded_proxy.target_shape = ability.upgraded_target_shape
		upgraded_proxy.target_shape_size = (
			ability.upgraded_target_shape_size
			if ability.upgraded_target_shape_size >= 0
			else ability.target_shape_size
		)
		upgraded_proxy.targeting_flags = ability.targeting_flags
		upgraded_proxy.effects = ability.upgraded_effects
		ability.upgraded_modules = infer_modules_from_effects(ability.upgraded_effects, upgraded_proxy)
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
		## Authoritative modules: compile to flat effects for legacy readers.
		## Exception: keep violent_collision_recast on primary until native gate runtime.
		_sync_modules_from_generated_effects(ability)
		var compiled: Array[EffectData] = compile_modules_to_effects(ability.modules)
		if not compiled.is_empty():
			ability.effects = compiled
		_apply_module_range_to_ability(ability, ability.modules)
	if not ability.upgraded_modules.is_empty():
		var up_compiled: Array[EffectData] = compile_modules_to_effects(ability.upgraded_modules)
		if not up_compiled.is_empty():
			ability.upgraded_effects = up_compiled
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


static func _infer_tags(ability: AbilityData) -> Array[StringName]:
	var tags: Array[StringName] = []
	if ability.planner_group == GameEnums.PlannerGroup.PRE_MOVE:
		tags.append(TAG_POSITIONING)
	var has_damage := false
	var has_move := false
	var has_heal := false
	for eff: EffectData in ability.effects:
		if eff == null:
			continue
		match eff.type:
			GameEnums.EffectType.DAMAGE, GameEnums.EffectType.TRAMPLE, GameEnums.EffectType.BULLDOZE:
				has_damage = true
			GameEnums.EffectType.MOVE, GameEnums.EffectType.DASH, GameEnums.EffectType.TELEPORT_CASTER, \
			GameEnums.EffectType.MOVE_INTO_AND_PUSH:
				has_move = true
			GameEnums.EffectType.HEAL:
				has_heal = true
			_:
				pass
	if has_damage:
		tags.append(TAG_ATTACK)
	if has_move:
		tags.append(TAG_MOVEMENT)
	if has_heal:
		tags.append(TAG_HEAL)
	if tags.is_empty():
		tags.append(TAG_SPELL)
	return tags


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
			module.motion_mode != GameEnums.MotionMode.SLIDE_TARGET_OPPOSITE
			and not module_has_modifier(module, &"airlift_keep_caster")
		)
	if GameEnums.is_path_motion(module.primary_type):
		return (
			not module_has_modifier(module, &"post_attack_move")
			and not module_has_modifier(module, &"relocate_target")
			and not module_has_modifier(module, &"relocate_subject_only")
		)
	return false


static func _is_pass_through_type(t: GameEnums.EffectType) -> bool:
	return t == GameEnums.EffectType.TRAMPLE or t == GameEnums.EffectType.BULLDOZE


static func _module_from_primary_effect(eff: EffectData, ability: AbilityData) -> AbilityModule:
	var mod := AbilityModule.new()
	mod.execution_phase = _infer_phase(eff, 0, ability)
	mod.primary_type = eff.type
	mod.amount = eff.amount
	mod.status_type = eff.status_type
	mod.status_duration = eff.status_duration
	mod.scaling_stat = eff.scaling_stat
	mod.spawn_unit_id = eff.spawn_unit_id
	mod.bonus_if_adjacent_at_cast = eff.bonus_if_adjacent_at_cast
	mod.def_debuff_before_damage = eff.def_debuff_before_damage
	mod.ingest_compatibility_modifiers(eff.modifiers)
	var is_motion: bool = is_motion_type(eff.type)
	mod.min_range = 1 if is_motion else 0
	mod.max_range = (
		eff.amount
		if is_motion and eff.amount > 0
		else ability.range_tiles
	)
	mod.target_shape = ability.target_shape
	mod.target_shape_size = ability.target_shape_size
	mod.targeting_flags = ability.targeting_flags
	mod.motion_mode = _infer_motion_mode(eff)
	mod.gate = GameEnums.ModuleGate.ALWAYS
	mod.keywords = _keywords_from_effect(eff)
	normalize_module_authoring_fields(mod)
	return mod


static func _merge_pass_through_into_motion(motion: AbilityModule, eff: EffectData) -> void:
	var kw := AbilityKeyword.new()
	if eff.type == GameEnums.EffectType.TRAMPLE:
		kw.keyword_id = GameEnums.AbilityKeywordId.TRAMPLE
	else:
		kw.keyword_id = GameEnums.AbilityKeywordId.BULLDOZE
	kw.amount = eff.amount
	kw.emit_as_effect = true
	motion.keywords.append(kw)
	motion.ingest_compatibility_modifiers(eff.modifiers)


## Bible §6: extras on a motion module (Trampling PUSH, Bowling [+] chain) are layers — not a second module.
static func _layers_on_motion_module(eff: EffectData) -> bool:
	if eff == null:
		return false
	return eff.type in [
		GameEnums.EffectType.PUSH,
		GameEnums.EffectType.PUSH_CHAIN_COLLISION,
		GameEnums.EffectType.PUSH_STAGGER_ON_COLLISION,
		GameEnums.EffectType.PULL_VULNERABLE_ON_ADJACENT,
	]


static func _infer_layer_condition(eff: EffectData) -> GameEnums.LayerCondition:
	if eff.modifiers.has("damage_adjacent_on_landing"):
		return GameEnums.LayerCondition.ON_LAND
	if eff.modifiers.has("heal_per_target_hit"):
		return GameEnums.LayerCondition.PER_TARGET_HIT
	if (
		eff.modifiers.has("on_kill_heal_shield")
		or eff.modifiers.has("frenzy_on_kill_ap")
	):
		return GameEnums.LayerCondition.ON_KILL
	if (
		eff.modifiers.has("object_collision_stagger")
		or eff.modifiers.has("stagger_on_collision")
		or eff.modifiers.has("enemy_collision_stagger_both")
	):
		return GameEnums.LayerCondition.ON_COLLISION
	if eff.type == GameEnums.EffectType.PUSH_CHAIN_COLLISION:
		return GameEnums.LayerCondition.ON_CHAIN_COLLISION
	if eff.bonus_if_adjacent_at_cast != 0:
		return GameEnums.LayerCondition.IF_ALREADY_ADJACENT
	return GameEnums.LayerCondition.AT_RESOLUTION


static func _infer_motion_mode(_eff: EffectData) -> GameEnums.MotionMode:
	return GameEnums.MotionMode.NONE


static func _infer_phase(_eff: EffectData, _idx: int, _ability: AbilityData) -> GameEnums.ModulePhase:
	return GameEnums.ModulePhase.ON_ACTION


static func _gate_from_modifiers(mods: Dictionary) -> GameEnums.ModuleGate:
	if mods.has("violent_collision_recast"):
		## Gate lives on the follow-up MOVE module; primary stays ALWAYS.
		return GameEnums.ModuleGate.ALWAYS
	return GameEnums.ModuleGate.ALWAYS


static func _keywords_from_effect(eff: EffectData) -> Array[AbilityKeyword]:
	var out: Array[AbilityKeyword] = []
	if eff.type == GameEnums.EffectType.TRAMPLE:
		var kw := AbilityKeyword.new()
		kw.keyword_id = GameEnums.AbilityKeywordId.TRAMPLE
		kw.amount = eff.amount
		out.append(kw)
	if eff.type == GameEnums.EffectType.BULLDOZE:
		var kw2 := AbilityKeyword.new()
		kw2.keyword_id = GameEnums.AbilityKeywordId.BULLDOZE
		kw2.amount = eff.amount
		out.append(kw2)
	if eff.modifiers.has("bulldoze") or eff.modifiers.has("push"):
		var kw3 := AbilityKeyword.new()
		kw3.keyword_id = GameEnums.AbilityKeywordId.BULLDOZE
		kw3.amount = int(eff.modifiers.get("bulldoze", 0))
		kw3.push_amount = int(eff.modifiers.get("push", 0))
		out.append(kw3)
	if eff.modifiers.has("ghost_move"):
		var kw4 := AbilityKeyword.new()
		kw4.keyword_id = GameEnums.AbilityKeywordId.GHOST
		out.append(kw4)
	return out


static func _ensure_bulldoze_keyword(mod: AbilityModule) -> Array[AbilityKeyword]:
	var kws: Array[AbilityKeyword] = mod.keywords.duplicate()
	var has_bd := false
	for kw: AbilityKeyword in kws:
		if kw != null and kw.keyword_id == GameEnums.AbilityKeywordId.BULLDOZE:
			has_bd = true
			break
	if not has_bd:
		var kw := AbilityKeyword.new()
		kw.keyword_id = GameEnums.AbilityKeywordId.BULLDOZE
		kw.amount = int(mod.runtime_value("bulldoze", 1))
		kw.push_amount = int(mod.runtime_value("push", 1))
		kws.append(kw)
	return kws


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
	if ability.cost_modifier == GameEnums.CostModifier.SPEND_ALL_MOVEMENT:
		_ensure_spend_all_movement_on_effects(ability)


static func _ensure_spend_all_movement_on_effects(ability: AbilityData) -> void:
	if ability == null:
		return
	for effects: Array[EffectData] in [ability.effects, ability.upgraded_effects]:
		if effects.is_empty() or effects[0] == null:
			continue
		effects[0].modifiers["cost_all_movement"] = true


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


static func _ensure_zero_ap_modifier_on_effects(ability: AbilityData) -> void:
	var n: int = ability.cost_modifier_n if ability.cost_modifier_n > 0 else 2
	if ability.effects.is_empty():
		return
	var first: EffectData = ability.effects[0]
	if first != null:
		first.modifiers["zero_ap_adjacent_enemies"] = n


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
