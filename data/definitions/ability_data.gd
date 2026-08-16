class_name AbilityData
extends Resource

## Purpose: A data-driven ability — header + ordered modules (ability-data.md).
## Responsibilities: Describe planner column, cost, tags, presentation, and modules.
## Legacy flat effects[] are compiled from modules for readers not yet migrated.
## Dependencies: EffectData, AbilityModule, AbilityModuleBridge.
## Lifecycle: immutable definition shared by all units that own it.

@export var id: StringName = &""
@export var display_name: String = ""

## Timeline column for class-library cards (ability-data.md §1). Source of truth when set.
@export var planner_group: GameEnums.PlannerGroup = GameEnums.PlannerGroup.ACTION
## When >= 0, upgraded profile uses this planner column (Adrenaline Surge [+] = Pre-Move).
@export var upgraded_planner_group: int = -1

## Classification tags: attack, movement, positioning, spell, heal (multi-tag OK).
@export var tags: Array[StringName] = []

## Cost block (ability-data.md §1).
@export var primary_resource: GameEnums.CostResource = GameEnums.CostResource.NONE
@export var primary_value: int = 1
## Optional replacement for the header primary cost when the ability is upgraded.
@export var upgraded_primary_value: int = -1
@export var cost_modifier: GameEnums.CostModifier = GameEnums.CostModifier.NONE
@export var cost_modifier_n: int = 0
@export var secondary_resource: GameEnums.CostResource = GameEnums.CostResource.NONE
@export var secondary_value: int = 0
@export var upgraded_secondary_value: int = -1

## Ordered modular steps (source of truth when non-empty after finalize).
@export var modules: Array[AbilityModule] = []
@export var upgraded_modules: Array[AbilityModule] = []

## Economy / timeline classification — legacy mirror of planner_group (+ UNIVERSAL_*).
@export var kind: GameEnums.AbilityKind = GameEnums.AbilityKind.CLASS_SKILL

## Action points consumed when used (CLASS_SKILL only; Run AP is spent on MOVE via uses_run).
@export var action_point_cost: int = 1

## Movement points consumed when used (MOVEMENT_SKILL / PRE_MOVE only).
@export var movement_point_cost: int = 0

## Maximum Manhattan distance from actor to target tile (legacy mirror of primary aim module).
@export var range_tiles: int = 1

## Who may be targeted. Author with targeting_flags; targeting_mode is synced legacy.
@export var targeting_mode: GameEnums.TargetingMode = GameEnums.TargetingMode.ANY_UNIT

## Targeting bitmask (TargetingFlags). Source of truth for the class library editor.
@export var targeting_flags: int = 0

## Legacy mirror; synced from targeting_flags SELF bit.
@export var can_target_self: bool = false


func has_targeting(flag: int) -> bool:
	return (targeting_flags & flag) != 0


func set_targeting_flag(flag: int, enabled: bool) -> void:
	if enabled:
		targeting_flags |= flag
	else:
		targeting_flags &= ~flag
	sync_legacy_targeting()


func ensure_targeting_flags_from_mode() -> void:
	if targeting_flags != 0:
		sync_legacy_targeting()
		return
	targeting_flags = _targeting_mode_to_flags(targeting_mode)
	sync_legacy_targeting()


func sync_legacy_targeting() -> void:
	can_target_self = has_targeting(GameEnums.TargetingFlags.SELF)
	targeting_mode = _targeting_flags_to_mode()


static func _targeting_mode_to_flags(mode: int) -> int:
	match mode:
		GameEnums.TargetingMode.SELF:
			return GameEnums.TargetingFlags.SELF
		GameEnums.TargetingMode.ALLY_UNIT:
			return GameEnums.TargetingFlags.ALLY
		GameEnums.TargetingMode.ALLY_OR_SELF:
			return GameEnums.TargetingFlags.SELF | GameEnums.TargetingFlags.ALLY
		GameEnums.TargetingMode.ENEMY_UNIT:
			return GameEnums.TargetingFlags.ENEMY
		GameEnums.TargetingMode.ANY_UNIT:
			return (
				GameEnums.TargetingFlags.SELF
				| GameEnums.TargetingFlags.ALLY
				| GameEnums.TargetingFlags.ENEMY
			)
		GameEnums.TargetingMode.TILE:
			return GameEnums.TargetingFlags.TILE
		GameEnums.TargetingMode.DASH_LINE:
			return GameEnums.TargetingFlags.DASH_LINE
	return GameEnums.TargetingFlags.ENEMY


func _targeting_flags_to_mode() -> int:
	var f: int = targeting_flags
	var unit_mask: int = (
		GameEnums.TargetingFlags.SELF
		| GameEnums.TargetingFlags.ALLY
		| GameEnums.TargetingFlags.ENEMY
	)
	if f == GameEnums.TargetingFlags.SELF:
		return GameEnums.TargetingMode.SELF
	if f == GameEnums.TargetingFlags.ALLY:
		return GameEnums.TargetingMode.ALLY_UNIT
	if f == (GameEnums.TargetingFlags.SELF | GameEnums.TargetingFlags.ALLY):
		return GameEnums.TargetingMode.ALLY_OR_SELF
	if has_targeting(GameEnums.TargetingFlags.TILE):
		return GameEnums.TargetingMode.TILE
	if f == GameEnums.TargetingFlags.ENEMY:
		return GameEnums.TargetingMode.ENEMY_UNIT
	if (
		has_targeting(GameEnums.TargetingFlags.ALLY)
		and has_targeting(GameEnums.TargetingFlags.ENEMY)
		and not has_targeting(GameEnums.TargetingFlags.TILE)
	):
		return GameEnums.TargetingMode.ANY_UNIT
	if (f & unit_mask) == unit_mask:
		return GameEnums.TargetingMode.ANY_UNIT
	if has_targeting(GameEnums.TargetingFlags.DASH_LINE):
		return GameEnums.TargetingMode.DASH_LINE
	return GameEnums.TargetingMode.ENEMY_UNIT

## The geometric shape of the affected area (legacy mirror of primary aim module).
@export var target_shape: GameEnums.TargetShape = GameEnums.TargetShape.SINGLE

## The size/radius parameter for the geometric shape (e.g., 3 for 3x3 square).
@export var target_shape_size: int = 1

## Optional overrides for when the ability is upgraded. -1 means do not override.
@export var upgraded_range_tiles: int = -1
@export var upgraded_movement_point_cost: int = -1
@export var upgraded_target_shape: GameEnums.TargetShape = GameEnums.TargetShape.SINGLE
@export var upgraded_target_shape_size: int = -1

## Ordered list of effects — compiled from modules for legacy AbilitySystem readers.
@export var effects: Array[EffectData] = []

## Effects applied to the target if this ability is upgraded (compiled from upgraded_modules).
@export var upgraded_effects: Array[EffectData] = []

## Description of what the upgrade does.
@export var upgrade_description: String = ""

## Maximum times this ability can be used per combat (-1 for unlimited).
@export var uses_per_combat: int = -1
## True when the skill may be used only once each turn (replaces leftover limit_once_per_turn).
@export var once_per_turn: bool = false

## Opaque key the presentation layer maps to an animation/VFX/SFX.
## The simulation never loads or plays anything; it only forwards this string.
@export var presentation_key: StringName = &""

## Presentation anim override; AUTO uses tags + module rules (ability-data.md §7).
@export var presentation_anim: GameEnums.PresentationAnim = GameEnums.PresentationAnim.AUTO

## Determines which stat (STR/MAG/NONE) scales the damage of this ability (legacy; prefer per-module).
@export var scaling_stat: GameEnums.StatType = GameEnums.StatType.NONE

## Legacy mirror of planner_group == PRE_MOVE (synced; not authored separately).
@export var is_movement_skill: bool = false


## Infer modules from flat effects when needed; compile modules → effects; sync kind/cost mirrors.
func finalize_modular() -> void:
	AbilityModuleBridge.finalize_ability(self)


## Returns the one authored module profile active for this ability state.
## Upgraded profiles are complete replacements, not scalar patches over base modules.
func get_active_modules(upgraded: bool = false) -> Array[AbilityModule]:
	if upgraded and not upgraded_modules.is_empty():
		return upgraded_modules
	return modules


func get_active_primary_value(upgraded: bool = false) -> int:
	if upgraded and upgraded_primary_value >= 0:
		return upgraded_primary_value
	return primary_value


func get_active_secondary_value(upgraded: bool = false) -> int:
	if upgraded and upgraded_secondary_value >= 0:
		return upgraded_secondary_value
	return secondary_value


## Returns the card-facing range from the first non-motion NEW_AIM module.
## Motion distance belongs to active_motion_module(), never this legacy card range.
func get_active_card_range(upgraded: bool = false) -> int:
	for module: AbilityModule in get_active_modules(upgraded):
		if (
			module != null
			and module.aim_binding == GameEnums.AimBinding.NEW_AIM
			and not AbilityModuleBridge.is_motion_type(module.primary_type)
		):
			return module.max_range
	if upgraded and upgraded_modules.is_empty() and upgraded_range_tiles >= 0:
		return upgraded_range_tiles
	return range_tiles


## Returns the active motion module, including its authored min/max distance.
func get_active_motion_module(upgraded: bool = false) -> AbilityModule:
	return AbilityModuleBridge.first_motion_module(
		get_active_modules(upgraded), true, true,
	)


func has_modules() -> bool:
	return not modules.is_empty()


func is_pre_move_planner() -> bool:
	return planner_group == GameEnums.PlannerGroup.PRE_MOVE


func is_pre_move_for(upgraded: bool) -> bool:
	if is_universal_run() or is_movement_kind():
		return true
	if upgraded and upgraded_planner_group == GameEnums.PlannerGroup.PRE_MOVE:
		return true
	return planner_group == GameEnums.PlannerGroup.PRE_MOVE


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)


func is_movement_kind() -> bool:
	## Prefer planner_group when synced; kind remains authoritative for UNIVERSAL_* and pre-finalize.
	if planner_group == GameEnums.PlannerGroup.PRE_MOVE and kind == GameEnums.AbilityKind.MOVEMENT_SKILL:
		return true
	return kind == GameEnums.AbilityKind.MOVEMENT_SKILL


func is_pre_move_kind() -> bool:
	return is_movement_kind() or kind == GameEnums.AbilityKind.UNIVERSAL_RUN


func is_universal_run() -> bool:
	return kind == GameEnums.AbilityKind.UNIVERSAL_RUN


func is_universal_wait() -> bool:
	return kind == GameEnums.AbilityKind.UNIVERSAL_WAIT


func is_class_kind() -> bool:
	return kind == GameEnums.AbilityKind.CLASS_SKILL


func consumes_action_slot() -> bool:
	return kind == GameEnums.AbilityKind.CLASS_SKILL


func consumes_action_slot_for(upgraded: bool) -> bool:
	if is_pre_move_for(upgraded):
		return false
	return consumes_action_slot()
