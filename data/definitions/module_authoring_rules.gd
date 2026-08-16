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


static func module_uses_motion_mode(effect_type: GameEnums.EffectType) -> bool:
	## Dest EffectTypes (MOVE/JUMP/TELEPORT and their landing variants) own destination.
	## DASH, SWAP, and occupy-push still use MotionMode.
	return effect_type in [
		GameEnums.EffectType.DASH,
		GameEnums.EffectType.SWAP,
		GameEnums.EffectType.MOVE_INTO_AND_PUSH,
	]


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
	if flag == GameEnums.TargetingFlags.DASH_LINE:
		return module.primary_type == GameEnums.EffectType.DASH
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
		GameEnums.LayerCondition.ON_LAND, GameEnums.LayerCondition.PER_TILE_MOVED:
			return motion
		GameEnums.LayerCondition.WHEN_MOVED_THROUGH_ENEMY:
			return motion or parent_module_has_pass_through_keyword(parent_module)
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
	for keyword: AbilityKeyword in module.keywords:
		if keyword == null:
			continue
		if not keyword_uses_amount(keyword.keyword_id):
			keyword.amount = 0
		if not keyword_uses_push_amount(keyword.keyword_id):
			keyword.push_amount = 0
		if not keyword_uses_emit_as_effect(keyword.keyword_id):
			keyword.emit_as_effect = false


static func normalize_module_targeting_flags(module: AbilityModule) -> void:
	if module == null:
		return
	for flag: int in [
		GameEnums.TargetingFlags.SELF,
		GameEnums.TargetingFlags.ALLY,
		GameEnums.TargetingFlags.ENEMY,
		GameEnums.TargetingFlags.TILE,
		GameEnums.TargetingFlags.DASH_LINE,
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
	if module == null:
		return false
	for keyword: AbilityKeyword in module.keywords:
		if keyword == null:
			continue
		if keyword.keyword_id in [
			GameEnums.AbilityKeywordId.TRAMPLE,
			GameEnums.AbilityKeywordId.BULLDOZE,
		]:
			return true
	return false


static func keyword_uses_push_amount(keyword_id: GameEnums.AbilityKeywordId) -> bool:
	return keyword_id == GameEnums.AbilityKeywordId.BULLDOZE
