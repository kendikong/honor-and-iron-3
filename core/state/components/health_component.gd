class_name HealthComponent
extends RefCounted

## Purpose: A unit's live hit points (capability via composition).
## Responsibilities: Track current/max HP; report alive; clone itself.
## Dependencies: none.
## Lifecycle: owned by a UnitState; deep-copied during board cloning.

var current_hp: int = 1
var max_hp: int = 1

func _init(p_max_hp: int = 1) -> void:
	max_hp = p_max_hp
	current_hp = p_max_hp

func is_alive() -> bool:
	return current_hp > 0

func clone() -> HealthComponent:
	var copy := HealthComponent.new(max_hp)
	copy.current_hp = current_hp
	return copy
