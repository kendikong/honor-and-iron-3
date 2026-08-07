class_name StatusData
extends RefCounted

## Represents a temporary status effect on a unit.

var type: GameEnums.StatusType
var duration: int # In turns.
var value: int # E.g., the amount of stat increased or decreased.
var ticks_remaining: int # Used internally to track half-phases

func _init(p_type: GameEnums.StatusType, p_duration: int, p_value: int = 0, p_ticks: int = -1) -> void:
	type = p_type
	duration = p_duration
	value = p_value
	if p_ticks == -1:
		ticks_remaining = (p_duration * 2 + 1) if p_duration > 0 else p_duration
	else:
		ticks_remaining = p_ticks

func clone() -> StatusData:
	return StatusData.new(type, duration, value, ticks_remaining)
