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
	return modifiers
