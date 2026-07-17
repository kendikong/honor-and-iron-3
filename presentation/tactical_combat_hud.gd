class_name TacticalCombatHud
extends CanvasLayer

## Bottom combat HUD — phase, timeline summary, execute / undo (Phase 4 shell).

var _director: CombatDirector
var _map_view: TacticalMapView

var _phase_label: Label
var _timeline_grid: TacticalTimelineGrid
var _warn_label: Label
var _side_panels: TacticalSidePanels
var _intent_state: CombatIntentState
var _execute_btn: Button
var _undo_btn: Button
var _clear_btn: Button
var _bottom_panel: PanelContainer
var _panel_width: int = 280
var _ui_scale: float = 1.0
var _banner: PanelContainer
var _banner_label: Label
var _is_ready: bool = false
var _sfx: SfxPlayer
var _compendium_overlay: CompendiumScreen


func setup(
	director: CombatDirector,
	map_view: TacticalMapView,
	sfx: SfxPlayer = null,
	side_panels: TacticalSidePanels = null,
	intent_state: CombatIntentState = null,
) -> void:
	_director = director
	_map_view = map_view
	_sfx = sfx
	_side_panels = side_panels
	_intent_state = intent_state
	layer = 22
	_build_ui()
	_build_banner()
	EventBus.turn_phase_changed.connect(_on_phase_changed)
	EventBus.timeline_changed.connect(_on_timeline_changed)
	EventBus.action_rejected.connect(_on_action_rejected)
	EventBus.board_changed.connect(_on_board_changed)
	EventBus.selection_changed.connect(func(id: int) -> void:
		if _timeline_grid != null:
			_timeline_grid.set_selected(id)
		_refresh_undo_button(),
	)
	if GlobalTimeline.player_ready_changed.is_connected(_on_player_ready_changed) == false:
		GlobalTimeline.player_ready_changed.connect(_on_player_ready_changed)
	if _timeline_grid != null:
		_timeline_grid.row_hovered.connect(func(id: int) -> void:
			if _intent_state != null:
				_intent_state.set_timeline_hover(id),
		)
		_timeline_grid.row_unhovered.connect(func(_id: int) -> void:
			if _intent_state != null:
				_intent_state.clear_timeline_hover(),
		)
		_timeline_grid.warning_changed.connect(_on_timeline_warning)
	_on_phase_changed(_director.phase)
	_refresh_timeline()


func apply_settings(settings: GameSettings) -> void:
	if settings == null:
		return
	_ui_scale = settings.combat_ui_scale
	_panel_width = int(round(float(settings.inspector_panel_width) * _ui_scale))
	var title_sz: int = int(round(float(settings.inspector_title_font()) * _ui_scale))
	var body_sz: int = int(round(float(settings.inspector_hint_font()) * _ui_scale))
	if _phase_label != null:
		_phase_label.add_theme_font_size_override("font_size", title_sz)
	for child: Node in get_children():
		_apply_ui_scale_recursive(child, body_sz, title_sz)
	if _execute_btn != null:
		_execute_btn.custom_minimum_size = Vector2(200.0 * _ui_scale, 48.0 * _ui_scale)
		_execute_btn.add_theme_font_size_override("font_size", body_sz)
	if _undo_btn != null:
		_undo_btn.add_theme_font_size_override("font_size", body_sz)
	if _clear_btn != null:
		_clear_btn.add_theme_font_size_override("font_size", body_sz)
	_layout_bottom_insets()


func _apply_ui_scale_recursive(node: Node, body_sz: int, title_sz: int) -> void:
	if node is Label and node != _phase_label:
		var lbl := node as Label
		if lbl.text == "Tactical Combat":
			lbl.add_theme_font_size_override("font_size", title_sz)
		else:
			lbl.add_theme_font_size_override("font_size", body_sz)
	elif node is Button and node != _execute_btn and node != _undo_btn and node != _clear_btn:
		(node as Button).add_theme_font_size_override("font_size", body_sz)
	for child: Node in node.get_children():
		_apply_ui_scale_recursive(child, body_sz, title_sz)


func _layout_bottom_insets() -> void:
	if _bottom_panel == null:
		return
	var inset: float = float(_panel_width) + 16.0
	_bottom_panel.offset_left = inset
	_bottom_panel.offset_right = -inset
	_bottom_panel.offset_top = -int(round(280.0 * _ui_scale))


func _on_timeline_warning(text: String) -> void:
	if text.is_empty():
		_warn_label.text = ""
	else:
		_warn_label.text = "Plan issue: %s" % CombatUiFormatters.reason_text(text)


func get_timeline_grid() -> TacticalTimelineGrid:
	return _timeline_grid


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

	var compendium := Button.new()
	compendium.text = "Compendium"
	compendium.pressed.connect(_open_compendium_overlay)
	top_row.add_child(compendium)

	var title := Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text = "Tactical Combat"
	title.add_theme_font_size_override("font_size", 20)
	top_row.add_child(title)

	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -280
	_bottom_panel = bottom
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

	var hint := Label.new()
	hint.text = "Drag to move · scroll = ability · A = aim · Esc = pause"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	left.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 140)
	left.add_child(scroll)
	_timeline_grid = TacticalTimelineGrid.new()
	_timeline_grid.setup(_director)
	scroll.add_child(_timeline_grid)

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


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.offset_left = -180
	_banner.offset_right = 180
	_banner.offset_top = -60
	_banner.offset_bottom = 60
	_banner.visible = false
	add_child(_banner)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_banner.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(_banner_label)
	var restart := Button.new()
	restart.text = "Back to Battle Setup"
	restart.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/BattleSetup.tscn"))
	vbox.add_child(restart)


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
	if _timeline_grid != null:
		_timeline_grid.set_phase(phase)
	var planning: bool = (
		phase == CombatDirector.Phase.PLANNING_PHASE_1
		or phase == CombatDirector.Phase.PLANNING_PHASE_2
	)
	_execute_btn.disabled = not planning
	_undo_btn.visible = planning
	_clear_btn.disabled = not planning
	_refresh_undo_button()
	if not planning:
		_is_ready = false
		_execute_btn.text = "Ready — Execute Phase"
		_execute_btn.modulate = Color.WHITE
	if phase == CombatDirector.Phase.VICTORY:
		_show_banner("Victory!")
		if _sfx != null:
			_sfx.play("win")
		if _side_panels != null:
			CombatUiFormatters.append_victory_log(_side_panels.get_log_label(), true)
	elif phase == CombatDirector.Phase.DEFEAT:
		_show_banner("Defeat")
		if _sfx != null:
			_sfx.play("lose")
		if _side_panels != null:
			CombatUiFormatters.append_victory_log(_side_panels.get_log_label(), false)
	else:
		_hide_banner()


func _on_timeline_changed(_timeline: Timeline, statuses: PackedStringArray) -> void:
	_refresh_timeline(statuses)
	_refresh_undo_button()


func _on_board_changed(board: BoardState) -> void:
	if _timeline_grid != null:
		_timeline_grid.set_board(board)
	_refresh_timeline()


func _refresh_timeline(statuses: PackedStringArray = PackedStringArray()) -> void:
	if _director == null or _timeline_grid == null:
		return
	if _director.board != null:
		_timeline_grid.set_board(_director.board)
	_timeline_grid.set_phase(_director.phase)
	_timeline_grid.set_selected(_director.selected_unit_id)
	var plan: Timeline = (
		_director.plan_phase_1
		if (
			_director.phase == CombatDirector.Phase.PLANNING_PHASE_1
			or _director.phase == CombatDirector.Phase.EXECUTING_PHASE_1
		)
		else _director.plan_phase_2
	)
	_timeline_grid.rebuild(plan, statuses)
	if statuses.size() > 0:
		for reason: String in statuses:
			if reason != "":
				_warn_label.text = "Plan issue: %s" % CombatUiFormatters.reason_text(reason)
				return
	_warn_label.text = ""


func _on_action_rejected(reason: String) -> void:
	_warn_label.text = "Rejected: %s" % CombatUiFormatters.reason_text(reason)
	if _sfx != null:
		_sfx.play("invalid")


func _on_execute_pressed() -> void:
	if _sfx != null:
		_sfx.play("execute")
	if NetworkManager != null and NetworkManager.is_multiplayer:
		GlobalTimeline.rpc_set_ready(not _is_ready)
	else:
		GlobalTimeline.rpc_set_ready(true)


func _on_player_ready_changed(_player_id: int, is_ready: bool) -> void:
	_is_ready = is_ready
	if _execute_btn == null:
		return
	if is_ready:
		_execute_btn.text = "Cancel Ready"
		_execute_btn.modulate = Color(0.4, 0.9, 0.4)
	else:
		_execute_btn.text = "Ready — Execute Phase"
		_execute_btn.modulate = Color.WHITE


func _on_undo_pressed() -> void:
	if _director == null or _director.selected_unit_id <= 0:
		return
	_director.rpc_remove_last_for_unit(_director.selected_unit_id)


func _on_clear_pressed() -> void:
	if _director != null:
		_director.clear_plan()


func _show_banner(text: String) -> void:
	if _banner_label != null:
		_banner_label.text = text
	if _banner != null:
		_banner.visible = true


func _refresh_undo_button() -> void:
	if _undo_btn == null or _director == null:
		return
	var planning: bool = (
		_director.phase == CombatDirector.Phase.PLANNING_PHASE_1
		or _director.phase == CombatDirector.Phase.PLANNING_PHASE_2
	)
	_undo_btn.disabled = (
		not planning
		or _director.selected_unit_id < 0
		or not _director.unit_has_undoable_action(_director.selected_unit_id)
	)


func _open_compendium_overlay() -> void:
	if _compendium_overlay != null and is_instance_valid(_compendium_overlay):
		_compendium_overlay.queue_free()
	_compendium_overlay = load("res://scenes/Compendium.tscn").instantiate() as CompendiumScreen
	if _compendium_overlay == null:
		return
	_compendium_overlay.overlay_mode = true
	_compendium_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_compendium_overlay)


func _hide_banner() -> void:
	if _banner != null:
		_banner.visible = false
