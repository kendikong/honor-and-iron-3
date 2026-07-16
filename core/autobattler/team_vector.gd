class_name TeamVector
extends RefCounted

## Purpose: Represents one candidate bundle of unit actions evaluated by the Commander AI.
## A TeamVector contains exactly one action per player unit, all applied simultaneously.
## Lifecycle: created during Step 4 (Vector Simulation), graded, then the best one is executed.

## The timeline actions that make up this vector (one per unit)
var actions: Array[TimelineAction] = []

## Lightweight fast-pass score (sum of individual Fast_Scores before full simulation)
var fast_score: float = 0.0

## Full Objective Metric score after headless simulation (assigned in Step 5)
var utility_score: float = -INF

## Whether this vector survived Alpha-Beta pruning (false = was rejected early)
var passed_pruning: bool = true

## Full telemetry breakdown for HUD (populated during grading)
## Keys: "lethality", "survivability", "position", "potential", "penalties", "context"
var telemetry: Dictionary = {}
