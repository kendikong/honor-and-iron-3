class_name Intent
extends RefCounted

## Purpose: One enemy's locked plan for the turn, made public to the players
## (perfect information). Reuses TimelineAction so intents resolve through the
## exact same pipeline as player actions.
## Responsibilities: Hold an enemy's ordered actions and a human-readable summary.
## Dependencies: TimelineAction.
## Lifecycle: produced by EnemyPlanner during planning; stored on BoardState;
##   regenerated each turn.

var enemy_id: int = -1
var actions: Array[TimelineAction] = []

## Human-readable description for the intent display.
var summary: String = ""

func clone() -> Intent:
	var copy := Intent.new()
	copy.enemy_id = enemy_id
	copy.summary = summary
	for action in actions:
		copy.actions.append(action.clone())
	return copy
