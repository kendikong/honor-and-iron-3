class_name SimEvent
extends RefCounted

## Purpose: A single, ordered, deterministic record of something the simulation
## did (moved, damaged, pushed, ...). The presentation layer animates a list of
## these; the simulation never reads them back (constitution Golden Rule).
## Responsibilities: Hold an event type plus a small data payload.
## Dependencies: GameEnums.
## Lifecycle: produced inside simulate(); consumed by presentation or tests.

var type: GameEnums.SimEventType
var data: Dictionary = {}

static func make(p_type: GameEnums.SimEventType, p_data: Dictionary = {}) -> SimEvent:
	var event := SimEvent.new()
	event.type = p_type
	event.data = p_data
	return event

func describe() -> String:
	return "%s %s" % [GameEnums.SimEventType.keys()[type], data]
