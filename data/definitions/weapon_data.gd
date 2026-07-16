class_name WeaponData
extends Resource

## Purpose: A data-driven placeholder for the weapon/gear system.
## Responsibilities: Provide descriptive info and bonus stats.

@export var id: StringName = &""
@export var display_name: String = ""

@export var might: int = 0
@export var bonus_strength: int = 0
@export var bonus_magic: int = 0
@export var bonus_defense: int = 0
@export var bonus_max_hp: int = 0
@export var bonus_move: int = 0
