class_name AbilityData
extends Resource

## Purpose: A data-driven ability. An ability is a target rule + cost + a list of
## effects. Adding an ability means authoring a Resource, not writing code
## (constitution: "Abilities become data").
## Responsibilities: Describe targeting, cost, and the effects to apply.
## Dependencies: EffectData.
## Lifecycle: immutable definition shared by all units that own it.

@export var id: StringName = &""
@export var display_name: String = ""

## Economy / timeline classification (see Master Bible § Universal Action Economy).
@export var kind: GameEnums.AbilityKind = GameEnums.AbilityKind.CLASS_SKILL

## Action points consumed when used (CLASS_SKILL only; Run AP is spent on MOVE via uses_run).
@export var action_point_cost: int = 1

## Movement points consumed when used (MOVEMENT_SKILL only).
@export var movement_point_cost: int = 0

## Maximum Manhattan distance from actor to target tile.
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
	if f == GameEnums.TargetingFlags.ENEMY:
		return GameEnums.TargetingMode.ENEMY_UNIT
	if (f & unit_mask) == unit_mask:
		return GameEnums.TargetingMode.ANY_UNIT
	if has_targeting(GameEnums.TargetingFlags.DASH_LINE):
		return GameEnums.TargetingMode.DASH_LINE
	if has_targeting(GameEnums.TargetingFlags.TILE):
		return GameEnums.TargetingMode.TILE
	return GameEnums.TargetingMode.ENEMY_UNIT

## The geometric shape of the affected area.
@export var target_shape: GameEnums.TargetShape = GameEnums.TargetShape.SINGLE

## The size/radius parameter for the geometric shape (e.g., 3 for 3x3 square).
@export var target_shape_size: int = 1

## Optional overrides for when the ability is upgraded. -1 means do not override.
@export var upgraded_range_tiles: int = -1
@export var upgraded_target_shape: GameEnums.TargetShape = GameEnums.TargetShape.SINGLE
@export var upgraded_target_shape_size: int = -1

## Ordered list of effects applied to the target, in order.
@export var effects: Array[EffectData] = []

## Effects applied to the target if this ability is upgraded.
@export var upgraded_effects: Array[EffectData] = []

## Description of what the upgrade does.
@export var upgrade_description: String = ""

## Maximum times this ability can be used per combat (-1 for unlimited).
@export var uses_per_combat: int = -1

## Opaque key the presentation layer maps to an animation/VFX/SFX.
## The simulation never loads or plays anything; it only forwards this string.
@export var presentation_key: StringName = &""

## Presentation anim override; AUTO uses kind + targeting rules.
@export var presentation_anim: GameEnums.PresentationAnim = GameEnums.PresentationAnim.AUTO

## Determines which stat (STR/MAG/NONE) scales the damage of this ability.
@export var scaling_stat: GameEnums.StatType = GameEnums.StatType.NONE

## Legacy mirror of kind == MOVEMENT_SKILL (synced from kind in factories/editor; not authored separately).
@export var is_movement_skill: bool = false


func is_movement_kind() -> bool:
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
