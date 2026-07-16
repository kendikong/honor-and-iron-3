class_name SimResult
extends RefCounted

## Purpose: The output of one simulate() call: the resulting board plus the
## ordered event log that produced it.
## Responsibilities: Bundle final_state and events.
## Dependencies: BoardState, SimEvent.
## Lifecycle: returned by Simulator.simulate(); previews read final_state then
##   discard; execution adopts final_state and animates events.

var final_state: BoardState
var events: Array[SimEvent] = []

func _init(p_final_state: BoardState = null) -> void:
	final_state = p_final_state
