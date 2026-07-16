class_name TacticalCombatHud
extends CanvasLayer

## Bottom combat HUD — phase, timeline summary, execute / undo (Phase 4 shell).

var _director: CombatDirector
var _map_view: TacticalMapView

var _phase_label: Label
var _timeline_label: RichTextLabel
var _warn_label: Label
var _execute_btn: Button
var _undo_btn: Button
var _clear_btn: Button
var _is_ready: bool = false


func setup(director: CombatDirector, map_view: TacticalMapView) -> void:
	_director = director
	_map_view = map_view
	layer = 20
	_build_ui()
	EventBus.turn_phase_changed.connect(_on_phase_changed)
	EventBus.timeline_changed.connect(_on_timeline_changed)
	EventBus.action_rejected.connect(_on_action_rejected)
	EventBus.board_changed.connect(func(_b: BoardState) -> void: _refresh_timeline())
	_on_phase_changed(_director.phase)
	_refresh_timeline()


func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	root.add_theme_constant_override("margin_left", 12)
	root.add_theme_constant_override("margin_top", 8)
	root.add_theme_constant_override("margin_right", 12)
	add_child(root)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	root.add_child(top_row)

	var back := Button.new()
	back.text = "← Battle Setup"
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/BattleSetup.tscn"))
	top_row.add_child(back)

	var title := Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text = "Tactical Combat"
	title.add_theme_font_size_override("font_size", 20)
	top_row.add_child(title)

	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -220
	add_child(bottom)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	bottom.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(left)

	_phase_label = Label.new()
	_phase_label.text = "Phase: PLANNING 1"
	_phase_label.add_theme_font_size_override("font_size", 18)
	left.add_child(_phase_label)

	_timeline_label = RichTextLabel.new()
	_timeline_label.bbcode_enabled = true
	_timeline_label.fit_content = true
	_timeline_label.custom_minimum_size = Vector2(0, 120)
	_timeline_label.scroll_active = true
	left.add_child(_timeline_label)

	_warn_label = Label.new()
	_warn_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.4))
	left.add_child(_warn_label)

	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(buttons)

	_execute_btn = Button.new()
	_execute_btn.text = "Ready — Execute Phase"
	_execute_btn.custom_minimum_size = Vector2(200, 48)
	_execute_btn.pressed.connect(_on_execute_pressed)
	buttons.add_child(_execute_btn)

	_undo_btn = Button.new()
	_undo_btn.text = "Undo Unit"
	_undo_btn.pressed.connect(_on_undo_pressed)
	buttons.add_child(_undo_btn)

	_clear_btn = Button.new()
	_clear_btn.text = "Clear Phase Plan"
	_clear_btn.pressed.connect(_on_clear_pressed)
	buttons.add_child(_clear_btn)


func _on_phase_changed(phase: int) -> void:
	var names: Dictionary = {
		CombatDirector.Phase.PLANNING_PHASE_1: "PLANNING 1",
		CombatDirector.Phase.PLANNING_PHASE_2: "PLANNING 2",
		CombatDirector.Phase.EXECUTING_PHASE_1: "EXECUTING 1…",
		CombatDirector.Phase.EXECUTING_PHASE_2: "EXECUTING 2…",
		CombatDirector.Phase.ENEMY_TURN: "ENEMY TURN…",
		CombatDirector.Phase.VICTORY: "VICTORY",
		CombatDirector.Phase.DEFEAT: "DEFEAT",
	}
	_phase_label.text = "Phase: %s" % names.get(phase, str(phase))
	var planning: bool = (
		phase == CombatDirector.Phase.PLANNING_PHASE_1
		or phase == CombatDirector.Phase.PLANNING_PHASE_2
	)
	_execute_btn.disabled = not planning
	_undo_btn.disabled = not planning
	_clear_btn.disabled = not planning
	if not planning:
		_is_ready = false
		_execute_btn.text = "Ready — Execute Phase"


func _on_timeline_changed(_timeline: Timeline, statuses: PackedStringArray) -> void:
	_refresh_timeline(statuses)


func _refresh_timeline(statuses: PackedStringArray = PackedStringArray()) -> void:
	if _director == null or _timeline_label == null:
		return
	var lines: Array[String] = []
	for unit in _director.board.units:
		if unit.team != GameEnums.Team.PLAYER or not unit.is_alive():
			continue
		var p1: String = _describe_action(_find_action(_director.plan_phase_1, unit.id))
		var p2: String = _describe_action(_find_action(_director.plan_phase_2, unit.id))
		lines.append(
			"[b]%s[/b]  ·  P1: %s  ·  P2: %s" % [unit.definition.display_name, p1, p2],
		)
	if lines.is_empty():
		_timeline_label.text = "[i]Click a blue token to select · click a tile to move · click enemy to attack[/i]"
	else:
		var body: String = ""
		for line: String in lines:
			body += "[li]%s[/li]" % line
		_timeline_label.text = "[ul]%s[/ul]" % body
	if statuses.size() > 0:
		for reason: String in statuses:
			if reason != "":
				_warn_label.text = "Plan issue: %s" % reason
				return
	_warn_label.text = ""


func _find_action(plan: Timeline, unit_id: int) -> TimelineAction:
	for action: TimelineAction in plan.entries:
		if action.actor_id == unit_id:
			return action
	return null


func _describe_action(action: TimelineAction) -> String:
	if action == null:
		return "—"
	match action.type:
		GameEnums.ActionType.MOVE:
			return "Move → %s" % action.target_coord
		GameEnums.ActionType.FACE:
			return "Face"
		GameEnums.ActionType.ABILITY:
			var ability_name: String = action.ability.display_name if action.ability != null else "Ability"
			return "%s → #%d" % [ability_name, action.target_unit_id]
	return "?"


func _on_action_rejected(reason: String) -> void:
	_warn_label.text = "Rejected: %s" % reason


func _on_execute_pressed() -> void:
	if NetworkManager != null and NetworkManager.is_multiplayer:
		GlobalTimeline.rpc_set_ready(not _is_ready)
	else:
		GlobalTimeline.rpc_set_ready(true)


func _on_undo_pressed() -> void:
	if _director == null or _director.selected_unit_id <= 0:
		return
	_director.rpc_remove_last_for_unit(_director.selected_unit_id)


func _on_clear_pressed() -> void:
	if _director != null:
		_director.clear_plan()
