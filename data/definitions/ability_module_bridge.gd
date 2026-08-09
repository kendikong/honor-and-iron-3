class_name AbilityModuleBridge
extends RefCounted

## Purpose: Compile modular AbilityModule lists ↔ legacy flat EffectData lists.
## Responsibilities: One-way authoring bridge so AbilitySystem can keep reading effects[]
## while factories/editor author modules (ability-data.md §12.15).
## Dependencies: AbilityData, AbilityModule, AbilityLayer, AbilityKeyword, EffectData, GameEnums.
## Lifecycle: static helpers; no instance state.


## Canonical tags (ability-data.md §0).
const TAG_ATTACK := &"attack"
const TAG_MOVEMENT := &"movement"
const TAG_POSITIONING := &"positioning"
const TAG_SPELL := &"spell"
const TAG_HEAL := &"heal"


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
		_apply_layer_condition_to_effect(layer_eff, layer.condition)
		out.append(layer_eff)
	return out


## Runtime compatibility list: only modules whose gate is active before execution.
## IF_COLLIDED is resolved by PhysicsSystem from the active module profile.
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
	module.legacy_modifiers = effect.modifiers.duplicate(true)


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
	## - After a motion module, the next non-keyword effect starts a new module (move then strike).
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
			if not modules.is_empty():
				mod.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
				mod.aim_module_index = 0
			modules.append(mod)
			continue
		if is_motion_type(modules[modules.size() - 1].primary_type):
			## Strike / utility after skill-owned motion — new module, shared aim.
			var after_move: AbilityModule = _module_from_primary_effect(eff, ability)
			after_move.aim_binding = GameEnums.AimBinding.SAME_AS_MODULE_N
			after_move.aim_module_index = 0
			modules.append(after_move)
			continue
		var layer := AbilityLayer.new()
		layer.effect = _duplicate_effect(eff)
		layer.condition = _infer_layer_condition(eff)
		modules[modules.size() - 1].layers.append(layer)
	## Recast stamp (modifiers) → gated follow-up MOVE module (bible §2.7 / §10 Violent Collision).
	if (
		not modules.is_empty()
		and modules[0].legacy_modifiers.has("violent_collision_recast")
		and modules.size() == 1
	):
		var motion_mod: AbilityModule = modules[0]
		motion_mod.keywords = _ensure_bulldoze_keyword(motion_mod)
		var move_mod := AbilityModule.new()
		move_mod.execution_phase = GameEnums.ModulePhase.ON_ACTION
		move_mod.primary_type = GameEnums.EffectType.MOVE
		move_mod.min_range = 1
		move_mod.max_range = 2
		move_mod.motion_mode = GameEnums.MotionMode.TO_EMPTY_TILE
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
	## Keep the legacy card range on non-motion aims. Motion distance remains on modules.
	var first_module: AbilityModule = null
	for mod: AbilityModule in modules:
		if mod == null:
			continue
		if first_module == null:
			first_module = mod
		if (
			mod.aim_binding == GameEnums.AimBinding.NEW_AIM
			and not is_motion_type(mod.primary_type)
		):
			ability.range_tiles = mod.max_range
			ability.target_shape = mod.target_shape
			ability.target_shape_size = mod.target_shape_size
			if mod.targeting_flags != 0:
				ability.targeting_flags = mod.targeting_flags
			return
	## A motion-owned landing footprint (e.g. Meteor Drop) is still the
	## ability's authored card shape when no later non-motion aim exists.
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
		t == GameEnums.EffectType.MOVE
		or t == GameEnums.EffectType.DASH
		or t == GameEnums.EffectType.TELEPORT_CASTER
		or t == GameEnums.EffectType.SWAP
		or t == GameEnums.EffectType.MOVE_INTO_AND_PUSH
	)


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
	mod.legacy_modifiers = eff.modifiers.duplicate(true)
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
	_strip_promoted_modifier_keys(mod)
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
	for key: Variant in eff.modifiers.keys():
		motion.legacy_modifiers[key] = eff.modifiers[key]


static func _infer_layer_condition(eff: EffectData) -> GameEnums.LayerCondition:
	if eff.modifiers.has("damage_adjacent_on_landing") or eff.modifiers.has("belly_flop_push"):
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


static func _infer_motion_mode(eff: EffectData) -> GameEnums.MotionMode:
	match eff.type:
		GameEnums.EffectType.MOVE_INTO_AND_PUSH:
			return GameEnums.MotionMode.INTO_OCCUPIED_PUSH
		GameEnums.EffectType.MOVE, GameEnums.EffectType.DASH, GameEnums.EffectType.TELEPORT_CASTER:
			return GameEnums.MotionMode.TO_EMPTY_TILE
		GameEnums.EffectType.SWAP:
			return GameEnums.MotionMode.TO_TARGET_UNIT
		_:
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
		kw.amount = int(mod.legacy_modifiers.get("bulldoze", 1))
		kw.push_amount = int(mod.legacy_modifiers.get("push", 1))
		kws.append(kw)
	return kws


static func _strip_promoted_modifier_keys(mod: AbilityModule) -> void:
	## Keep keys that AbilitySystem still reads from modifiers until typed runtime lands.
	## Do not strip bulldoze/push/ghost_move/violent_collision_recast yet.
	pass


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
