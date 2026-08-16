class_name AbilityComponent
extends RefCounted

## Purpose: A unit's live action points for the current combat.
## Responsibilities: Track current/max AP; turn-start grant; clone itself.
## Dependencies: GameEnums.MAX_AP / TURN_START_AP_GAIN.
## Lifecycle: owned by a UnitState; deep-copied during board cloning.
## Combat starts at 0 AP. Each turn start adds TURN_START_AP_GAIN, capped at max_points.

var points_left: int = 0
var max_points: int = 0

func _init(p_max_points: int = 0) -> void:
	max_points = p_max_points
	points_left = 0


func reset() -> void:
	points_left = max_points


func grant_turn_start() -> void:
	grant(GameEnums.TURN_START_AP_GAIN)


func grant(amount: int) -> int:
	var before: int = points_left
	points_left = mini(max_points, points_left + amount)
	return points_left - before


func clone() -> AbilityComponent:
	var copy := AbilityComponent.new(max_points)
	copy.points_left = points_left
	return copy
