class_name AbilityModuleBridge
extends RefCounted

const TAG_ATTACK := &"attack"
const TAG_MOVEMENT := &"movement"
const TAG_POSITIONING := &"positioning"
const TAG_SPELL := &"spell"
const TAG_HEAL := &"heal"

const CANONICAL_TAGS: Array[StringName] = [
	TAG_ATTACK,
	TAG_MOVEMENT,
	TAG_POSITIONING,
	TAG_SPELL,
	TAG_HEAL,
]

static func is_canonical_tag(tag: StringName) -> bool:
	return tag in CANONICAL_TAGS

static func sanitize_tags(tags: Array[StringName]) -> Array[StringName]:
	var clean: Array[StringName] = []
	for t: StringName in tags:
		if is_canonical_tag(t) and not clean.has(t):
			clean.append(t)
	return clean

static func validate_tag_list(tags: Array[StringName]) -> Dictionary:
	var rejected := PackedStringArray()
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for t: StringName in tags:
		if not is_canonical_tag(t):
			if not rejected.has(String(t)):
				rejected.append(String(t))
			errors.append("Invalid tag: " + str(t))
		if seen.has(t):
			errors.append("Duplicate tag: " + str(t))
		seen[t] = true
	return {
		"ok": errors.is_empty(),
		"valid": errors.is_empty(),
		"errors": errors,
		"tags": sanitize_tags(tags),
		"rejected": rejected,
	}

static func planner_group_from_kind(kind: GameEnums.AbilityKind) -> GameEnums.PlannerGroup:
	match kind:
		GameEnums.AbilityKind.MOVEMENT_SKILL:
			return GameEnums.PlannerGroup.PRE_MOVE
		GameEnums.AbilityKind.CLASS_SKILL:
			return GameEnums.PlannerGroup.ACTION
	return GameEnums.PlannerGroup.ACTION

static func kind_from_planner_group(
	group: GameEnums.PlannerGroup,
	fallback: GameEnums.AbilityKind = GameEnums.AbilityKind.CLASS_SKILL
) -> GameEnums.AbilityKind:
	if fallback == GameEnums.AbilityKind.UNIVERSAL_RUN or fallback == GameEnums.AbilityKind.UNIVERSAL_WAIT:
		return fallback
	match group:
		GameEnums.PlannerGroup.PRE_MOVE:
			return GameEnums.AbilityKind.MOVEMENT_SKILL
		GameEnums.PlannerGroup.ACTION:
			return GameEnums.AbilityKind.CLASS_SKILL
	return fallback

static func ability_has_displacement_effect(ability: AbilityData) -> bool:
	if ability == null:
		return false
	for mod: AbilityModule in ability.modules:
		if mod == null:
			continue
		var t: GameEnums.EffectType = mod.primary_type
		if t == GameEnums.EffectType.DASH or t == GameEnums.EffectType.MOVE or t == GameEnums.EffectType.TELEPORT_CASTER or t == GameEnums.EffectType.SWAP:
			return true
	return false

static func sync_legacy_from_header(ability: AbilityData) -> void:
	if ability == null:
		return
	enforce_planner_cost_coupling(ability)
	ability.kind = kind_from_planner_group(ability.planner_group, ability.kind)
	ability.is_movement_skill = ability_has_displacement_effect(ability)
	match ability.primary_resource:
		GameEnums.CostResource.AP:
			ability.action_point_cost = ability.primary_value
			ability.movement_point_cost = 0
		GameEnums.CostResource.MP:
			ability.movement_point_cost = ability.primary_value
			ability.action_point_cost = 0
		GameEnums.CostResource.NONE:
			ability.action_point_cost = 0
			ability.movement_point_cost = 0
		_:
			pass

static func is_planner_cost_legal(
	planner: GameEnums.PlannerGroup,
	res: GameEnums.CostResource
) -> bool:
	match planner:
		GameEnums.PlannerGroup.PRE_MOVE:
			return res == GameEnums.CostResource.MP
		GameEnums.PlannerGroup.ACTION:
			return res == GameEnums.CostResource.AP or res == GameEnums.CostResource.HP
	return false

static func legal_primary_resources(
	planner: GameEnums.PlannerGroup
) -> Array[GameEnums.CostResource]:
	match planner:
		GameEnums.PlannerGroup.PRE_MOVE:
			return [GameEnums.CostResource.MP]
		GameEnums.PlannerGroup.ACTION:
			return [GameEnums.CostResource.AP, GameEnums.CostResource.HP]
	return [GameEnums.CostResource.NONE]

static func enforce_planner_cost_coupling(ability: AbilityData) -> void:
	if not is_planner_cost_legal(ability.planner_group, ability.primary_resource):
		match ability.planner_group:
			GameEnums.PlannerGroup.PRE_MOVE:
				ability.primary_resource = GameEnums.CostResource.MP
				ability.primary_value = 1
			GameEnums.PlannerGroup.ACTION:
				ability.primary_resource = GameEnums.CostResource.AP
				ability.primary_value = 1

static func ensure_if_collided_followup_move(ability: AbilityData) -> void:
	if ability == null:
		return
	_append_if_collided_move_if_missing(ability.modules)
	if not ability.upgraded_modules.is_empty():
		_append_if_collided_move_if_missing(ability.upgraded_modules)
	for mod: AbilityModule in ability.modules:
		if mod != null:
			mod.legacy_modifiers.erase("violent_collision_recast")

static func _append_if_collided_move_if_missing(modules: Array[AbilityModule]) -> void:
	if modules.is_empty():
		return
	var has_followup := false
	for mod: AbilityModule in modules:
		if mod != null and mod.gate == GameEnums.ModuleGate.IF_COLLIDED and mod.primary_type == GameEnums.EffectType.MOVE:
			has_followup = true
			break
	if not has_followup:
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

static func finalize_ability(ability: AbilityData) -> void:
	if ability == null:
		return
	## Modules are authoritative for range, shape, and per-module targeting.
	## Header mirrors remain synchronized for runtime consumers that still read
	## the compatibility fields; finalization never rewrites module authoring.
	_inherit_header_targeting_to_unspecified_modules(ability)
	if not ability.modules.is_empty():
		_apply_module_range_to_ability(ability, ability.modules)
		var primary: AbilityModule = ability.modules[0]
		if primary != null and primary.targeting_flags != 0:
			ability.targeting_flags = primary.targeting_flags
			ability.sync_legacy_targeting()
	else:
		_prefer_authored_targeting_mode(ability)
	if _should_ensure_if_collided_followup(ability):
		ensure_if_collided_followup_move(ability)
		_apply_module_range_to_ability(ability, ability.modules)
	sync_legacy_from_header(ability)

static func _inherit_header_targeting_to_unspecified_modules(ability: AbilityData) -> void:
	if ability == null or ability.targeting_flags == 0:
		return
	for module: AbilityModule in ability.modules:
		if module != null and module.targeting_flags == 0:
			module.targeting_flags = ability.targeting_flags
	for module: AbilityModule in ability.upgraded_modules:
		if module != null and module.targeting_flags == 0:
			module.targeting_flags = ability.targeting_flags

static func _should_ensure_if_collided_followup(ability: AbilityData) -> bool:
	if ability == null:
		return false
	if ability_has_module_gate(ability, GameEnums.ModuleGate.IF_COLLIDED):
		return false
	return _has_violent_collision_dash_package(ability)

static func ability_has_module_gate(ability: AbilityData, gate: GameEnums.ModuleGate) -> bool:
	if ability == null:
		return false
	for mod: AbilityModule in ability.modules:
		if mod != null and mod.gate == gate:
			return true
	return false

static func _has_violent_collision_dash_package(ability: AbilityData) -> bool:
	if ability == null or ability.modules.is_empty():
		return false
	var mod: AbilityModule = ability.modules[0]
	if mod != null and mod.primary_type == GameEnums.EffectType.DASH:
		if mod.legacy_modifiers.has("violent_collision_recast"):
			return true
		if mod.legacy_modifiers.has("bulldoze") and mod.legacy_modifiers.has("push"):
			return true
	return false

static func _prefer_authored_targeting_mode(ability: AbilityData) -> void:
	## targeting_mode is the authoritative source when explicitly set by the factory.
	## Derive targeting_flags from it rather than the reverse, so factory overrides
	## (e.g. targeting_mode = SELF) survive finalize_modular().
	ability.targeting_flags = AbilityData._targeting_mode_to_flags(ability.targeting_mode)
	ability.sync_legacy_targeting()

static func _apply_module_range_to_ability(ability: AbilityData, modules: Array[AbilityModule]) -> void:
	if modules.is_empty() or modules[0] == null:
		return
	var primary_mod: AbilityModule = modules[0]
	ability.range_tiles = primary_mod.max_range
	ability.target_shape = primary_mod.target_shape
	ability.target_shape_size = primary_mod.target_shape_size
	## Only overwrite targeting_flags if the module actually declares them;
	## self-target abilities set targeting_flags on the ability header, not per-module.
	if primary_mod.targeting_flags != 0:
		ability.targeting_flags = primary_mod.targeting_flags