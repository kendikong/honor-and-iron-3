class_name TacticalSimPresenter
extends Node

## Execution feedback for TacticalCombat — overlay sync, LPC playback, floating damage.

const _FloatingTextScene = preload("res://presentation/floating_text.tscn")

var _overlay: TacticalUnitOverlay
var _unit_layer: TacticalUnitLayer
var _map_view: TacticalMapView
var _director: CombatDirector
var _push_flush_scheduled: bool = false


func setup(
	director: CombatDirector,
	overlay: TacticalUnitOverlay,
	unit_layer: TacticalUnitLayer = null,
	map_view: TacticalMapView = null,
) -> void:
	_director = director
	_overlay = overlay
	_unit_layer = unit_layer
	_map_view = map_view
	EventBus.board_changed.connect(_on_board_changed)
	EventBus.preview_updated.connect(_on_preview_updated)
	EventBus.sim_event.connect(_on_sim_event)
	EventBus.planning_commit_events.connect(_on_planning_commit_events)
	if _unit_layer != null:
		_unit_layer.push_tweens_idle.connect(_on_push_tweens_idle)


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
	if event.type == GameEnums.SimEventType.UNIT_DAMAGED:
		_spawn_damage_text(event)
	if _is_push_event(event):
		_schedule_push_flush()


func _spawn_damage_text(event: SimEvent) -> void:
	if _map_view == null:
		return
	var unit_id: int = int(event.data.get("unit", -1))
	var amount: int = int(event.data.get("amount", 0))
	if amount <= 0:
		return
	var dmg_type: StringName = event.data.get("damage_type", &"physical")
	var color: Color = Color(1.0, 0.35, 0.35)
	if dmg_type == &"heal" or int(event.data.get("hp_damaged", amount)) < 0:
		color = Color(0.35, 0.95, 0.45)
	elif dmg_type == &"magical":
		color = Color(0.65, 0.45, 0.95)
	var screen_pos: Vector2
	var actor := _unit_layer.get_actor(unit_id) if _unit_layer != null else null
	if actor != null:
		screen_pos = actor.position
	elif _director != null and _director.board != null:
		var unit := _director.board.get_unit_by_id(unit_id)
		if unit == null:
			return
		screen_pos = _map_view.grid_to_local(unit.position)
	else:
		return
	var ft: FloatingText = _FloatingTextScene.instantiate()
	ft.setup(screen_pos, str(amount), color)
	_map_view.add_child(ft)


func _on_planning_commit_events(events: Array) -> void:
	var had_push: bool = false
	for raw: Variant in events:
		if raw is SimEvent:
			if _is_push_event(raw):
				had_push = true
			_on_sim_event(raw as SimEvent)
	if had_push:
		_schedule_push_flush()


func _is_push_event(event: SimEvent) -> bool:
	return event.type in [
		GameEnums.SimEventType.UNIT_PUSHED,
		GameEnums.SimEventType.COLLISION,
	]


func _schedule_push_flush() -> void:
	if _push_flush_scheduled:
		return
	_push_flush_scheduled = true
	call_deferred("_flush_push_batch")


func _flush_push_batch() -> void:
	_push_flush_scheduled = false
	if _unit_layer == null or _unit_layer.get_active_push_tweens() == 0:
		EventBus.push_animations_complete.emit()


func _on_push_tweens_idle() -> void:
	EventBus.push_animations_complete.emit()
