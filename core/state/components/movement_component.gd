class_name MovementComponent
extends RefCounted

## Purpose: A unit's live movement points for the current turn.
## Responsibilities: Track current/max points; reset; clone itself.
## Dependencies: none.
## Lifecycle: owned by a UnitState; deep-copied during board cloning.

var points_left: int = 0
var max_points: int = 0

func _init(p_max_points: int = 0) -> void:
	max_points = p_max_points
	points_left = p_max_points

func reset() -> void:
	points_left = max_points

func clone() -> MovementComponent:
	var copy := MovementComponent.new(max_points)
	copy.points_left = points_left
	return copy
