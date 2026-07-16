class_name TacticalSimPresenter
extends Node

## Execution feedback for TacticalCombat — overlay sync + LPC move/attack playback.

var _overlay: TacticalUnitOverlay
var _unit_layer: TacticalUnitLayer


func setup(
	director: CombatDirector,
	overlay: TacticalUnitOverlay,
	unit_layer: TacticalUnitLayer = null,
) -> void:
	_overlay = overlay
	_unit_layer = unit_layer
	EventBus.board_changed.connect(_on_board_changed)
	EventBus.preview_updated.connect(_on_preview_updated)
	EventBus.sim_event.connect(_on_sim_event)
	EventBus.planning_commit_events.connect(_on_planning_commit_events)


func _on_board_changed(board: BoardState) -> void:
	if _overlay != null:
		_overlay.set_board(board)


func _on_preview_updated(result: SimResult) -> void:
	if _overlay != null:
		_overlay.set_preview_board(result.final_state)


func _on_sim_event(event: SimEvent) -> void:
	if _overlay != null:
		_overlay.apply_sim_event(event)
	if _unit_layer != null:
		_unit_layer.apply_sim_event(event)
	if _is_push_event(event):
		call_deferred("_finish_push_animations")


func _on_planning_commit_events(events: Array) -> void:
	for raw: Variant in events:
		if raw is SimEvent:
			_on_sim_event(raw)
	call_deferred("_finish_push_animations")


func _is_push_event(event: SimEvent) -> bool:
	return event.type in [
		GameEnums.SimEventType.UNIT_PUSHED,
		GameEnums.SimEventType.COLLISION,
	]


func _finish_push_animations() -> void:
	EventBus.push_animations_complete.emit()
