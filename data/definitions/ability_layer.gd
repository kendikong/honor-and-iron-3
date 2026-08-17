class_name AbilityLayer
extends Resource

## Purpose: Extra effect on the same targets as its parent module (ability-data.md §5).
## Responsibilities: Hold EffectData payload + activation condition.
## Dependencies: EffectData, GameEnums.
## Lifecycle: authored on AbilityModule; immutable at runtime.

@export var effect: EffectData = null
@export var condition: GameEnums.LayerCondition = GameEnums.LayerCondition.AT_RESOLUTION

## Typed collision-layer behavior; compile into the compatibility EffectData view.
@export var object_collision_stagger: bool = false
@export var enemy_collision_stagger_both: bool = false
@export var weapon_scaled: bool = false
@export var buff_per_destroyed_object: int = 0
@export var stagger_on_collision: bool = false
@export var intercept_grant_str: int = 0
@export var push_collision_pierce: bool = false
@export var push_collision_damage: int = 0
@export var difficult_terrain_created: bool = false
@export var rooted_push_bleed_weapon: bool = false
@export var grapple_pass_through_damage: int = 0
@export var ignite_flammable_terrain: bool = false
@export var ally_damage_zero: bool = false
@export var trap_vulnerable: bool = false
@export var crossing_blind: bool = false
@export var trap_def_debuff: int = 0
@export var range_one_damage_multiplier: float = 0.0


func compile_runtime_modifiers() -> Dictionary:
	var modifiers: Dictionary = {}
	if object_collision_stagger:
		modifiers["object_collision_stagger"] = 1
	if enemy_collision_stagger_both:
		modifiers["enemy_collision_stagger_both"] = 1
	if weapon_scaled:
		modifiers["weapon_scaled"] = 1
	if buff_per_destroyed_object != 0:
		modifiers["buff_per_destroyed_object"] = buff_per_destroyed_object
	if stagger_on_collision:
		modifiers["stagger_on_collision"] = 1
	if intercept_grant_str != 0:
		modifiers["intercept_grant_str"] = intercept_grant_str
	if push_collision_pierce:
		modifiers["push_collision_pierce"] = true
	if push_collision_damage != 0:
		modifiers["push_collision_damage"] = push_collision_damage
	if difficult_terrain_created:
		modifiers["difficult_terrain_created"] = true
	if rooted_push_bleed_weapon:
		modifiers["rooted_push_bleed_weapon"] = true
	if grapple_pass_through_damage != 0:
		modifiers["grapple_pass_through_damage"] = grapple_pass_through_damage
	if ignite_flammable_terrain:
		modifiers["ignite_flammable_terrain"] = true
	if ally_damage_zero:
		modifiers["ally_damage_zero"] = true
	if trap_vulnerable:
		modifiers["trap_vulnerable"] = true
	if crossing_blind:
		modifiers["crossing_blind"] = true
	if trap_def_debuff != 0:
		modifiers["trap_def_debuff"] = trap_def_debuff
	if not is_zero_approx(range_one_damage_multiplier):
		modifiers["range_one_damage_multiplier"] = range_one_damage_multiplier
	return modifiers


func ingest_runtime_key(key: String, value: Variant) -> void:
	match key:
		"object_collision_stagger":
			object_collision_stagger = bool(value)
		"enemy_collision_stagger_both":
			enemy_collision_stagger_both = bool(value)
		"weapon_scaled":
			weapon_scaled = bool(value)
		"buff_per_destroyed_object":
			buff_per_destroyed_object = int(value)
		"stagger_on_collision":
			stagger_on_collision = bool(value)
		"intercept_grant_str":
			intercept_grant_str = int(value)
		"push_collision_pierce":
			push_collision_pierce = bool(value)
		"push_collision_damage":
			push_collision_damage = int(value)
		"difficult_terrain_created":
			difficult_terrain_created = bool(value)
		"rooted_push_bleed_weapon":
			rooted_push_bleed_weapon = bool(value)
		"grapple_pass_through_damage":
			grapple_pass_through_damage = int(value)
		"ignite_flammable_terrain":
			ignite_flammable_terrain = bool(value)
		"ally_damage_zero":
			ally_damage_zero = bool(value)
		"trap_vulnerable":
			trap_vulnerable = bool(value)
		"crossing_blind":
			crossing_blind = bool(value)
		"trap_def_debuff":
			trap_def_debuff = int(value)
		"range_one_damage_multiplier":
			range_one_damage_multiplier = float(value)
