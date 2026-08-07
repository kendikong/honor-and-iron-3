class_name Timeline
extends RefCounted

## Purpose: The ordered list of planned player actions for a turn ("the heart of
## the game"). Supports free editing during planning.
## Responsibilities: Store and edit ordered actions; clone itself.
## Dependencies: TimelineAction.
## Lifecycle: rebuilt/edited every planning phase; cloned for preview simulation.

var entries: Array[TimelineAction] = []

func add(action: TimelineAction) -> void:
	entries.append(action)

func insert_at(index: int, action: TimelineAction) -> void:
	entries.insert(clampi(index, 0, entries.size()), action)

func remove_at(index: int) -> void:
	if index >= 0 and index < entries.size():
		entries.remove_at(index)

func reorder(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= entries.size():
		return
	var action := entries[from_index]
	entries.remove_at(from_index)
	entries.insert(clampi(to_index, 0, entries.size()), action)

func clear() -> void:
	entries.clear()

func size() -> int:
	return entries.size()

func clone() -> Timeline:
	var copy := Timeline.new()
	for action in entries:
		copy.entries.append(action.clone())
	return copy
