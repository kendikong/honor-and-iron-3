class_name CommanderContext
extends RefCounted

## Purpose: Carries the dynamic context weights (the "Mood") computed at the start
##   of each Commander AI turn, before any candidate generation or simulation.
## Lifecycle: created once per planning turn by CommanderAI.compute_context(), then
##   passed read-only through the Fast-Pass and grading stages.

var aggression: float = 0.5

## Pillar weights for the Objective Metric
var w_lethality: float = 1.0
var w_survivability: float = 1.0
var w_position: float = 1.0

## Flags set during context resolution (used by telemetry)
var healer_absence_bonus_applied: bool = false
var density_bonus_applied: bool = false
