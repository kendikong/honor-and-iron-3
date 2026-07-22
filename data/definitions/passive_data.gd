class_name PassiveData
extends Resource

## Purpose: A data-driven passive ability. Modifies unit behavior or stats passively.
## Responsibilities: Provide descriptive info and mechanical hooks for systems.
## Lifecycle: immutable definition shared by all units that own it.

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var upgraded_description: String = ""
@export var modifiers: Dictionary = {}
