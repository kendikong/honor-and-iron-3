class_name TacticalCombatHud
extends CanvasLayer

## Bottom combat HUD — phase, timeline summary, execute / undo (Phase 4 shell).

var _director: CombatDirector
var _map_view: TacticalMapView

var _phase_caption: Label
var _phase_label: Label
var _timeline_grid: TacticalTimelineGrid
var _warn_label: Label
var _side_panels: TacticalSidePanels
var _intent_state: CombatIntentState
var _planning_overlay: TacticalPlanningOverlay
var _planning_input: CombatPlanningInput
var _execute_btn: Button
var _undo_btn: Button
var _clear_btn: Button
var _bottom_panel: PanelContainer
var _panel_width: int = 280
var _ui_scale: float = 1.0
var _banner: PanelContainer
var _banner_label: Label
var _victory_restart_button: Button
var _victory_restart_callback: Callable = Callable()
var _is_ready: bool = false
var _sfx: SfxPlayer
var _compendium_overlay: CompendiumScreen
var _settings: GameSettings
var _hint_label: Label
var _last_timeline_mp_key: String = ""


func setup(
	director: CombatDirector,
	map_view: TacticalMapView,
	sfx: SfxPlayer = null,
	side_panels: TacticalSidePanels = null,
	intent_state: CombatIntentState = null,
	planning_overlay: TacticalPlanningOverlay = null,
	planning_input: CombatPlanningInput = null,
) -> void:
	_director = director
	_map_view = map_view
	_sfx = sfx
	_side_panels = side_panels
	_intent_state = intent_state
	_planning_overlay = planning_overlay
	_planning_input = planning_input
	layer = 22
	_build_ui()
	_build_banner()
	EventBus.turn_phase_changed.connect(_on_phase_changed)
	EventBus.timeline_changed.connect(_on_timeline_changed)
	EventBus.action_rejected.connect(_on_action_rejected)
	EventBus.board_changed.connect(_on_board_changed)
	EventBus.preview_updated.connect(_on_preview_updated)
	EventBus.selection_changed.connect(func(id: int) -> void:
		if _timeline_grid != null:
			_timeline_grid.set_selected(id)
		_refresh_timeline()
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
	if _planning_overlay != null and not _planning_overlay.live_preview_changed.is_connected(_on_live_preview_changed):
		_planning_overlay.live_preview_changed.connect(_on_live_preview_changed)
	_on_phase_changed(_director.phase)
	_refresh_timeline()


func apply_settings(settings: GameSettings) -> void:
	if settings == null:
		return
	_settings = settings
	_ui_scale = settings.combat_ui_scale
	CombatUiFormatters.configure_body_font(settings.scaled_body_font())
	_panel_width = int(round(float(settings.inspector_panel_width) * _ui_scale))
	var title_sz: int = settings.scaled_title_font()
	var body_sz: int = settings.scaled_hint_font()
	var cell_sz: int = settings.scaled_body_font()
	if _phase_caption != null:
		_phase_caption.add_theme_font_size_override("font_size", maxi(9, body_sz - 1))
	if _phase_label != null:
		_phase_label.add_theme_font_size_override("font_size", title_sz)
	if _hint_label != null:
		_hint_label.add_theme_font_size_override("font_size", maxi(9, body_sz - 1))
	if _timeline_grid != null:
		_timeline_grid.apply_font_sizes(title_sz, cell_sz)
	for child: Node in get_children():
		_apply_ui_scale_recursive(child, body_sz, title_sz)
	if _execute_btn != null:
		_execute_btn.custom_minimum_size = Vector2(220.0 * _ui_scale, 52.0 * _ui_scale)
		_execute_btn.add_theme_font_size_override("font_size", body_sz + 1)
	if _undo_btn != null:
		_undo_btn.custom_minimum_size = Vector2(220.0 * _ui_scale, 34.0 * _ui_scale)
	if _clear_btn != null:
		_clear_btn.custom_minimum_size = Vector2(220.0 * _ui_scale, 34.0 * _ui_scale)
	if _undo_btn != null:
		_undo_btn.add_theme_font_size_override("font_size", body_sz)
	if _clear_btn != null:
		_clear_btn.add_theme_font_size_override("font_size", body_sz)
	_layout_bottom_insets()
	_refresh_timeline()


func _apply_ui_scale_recursive(node: Node, body_sz: int, title_sz: int) -> void:
	if node is Label and node != _phase_label and node != _phase_caption and node != _hint_label and node != _warn_label:
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
	_bottom_panel.offset_top = -int(round(272.0 * _ui_scale))


func _on_timeline_warning(text: String) -> void:
	if text.is_empty():
		_warn_label.text = ""
	else:
		_warn_label.text = "[color=#%s]! %s[/color]" % [CombatUiFormatters.HEX_DEATH, CombatUiFormatters.reason_text(text)]


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
	bottom.offset_top = -272
	_bottom_panel = bottom
	_apply_bottom_panel_style(bottom)
	add_child(bottom)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 10)
	bottom.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var phase_sidebar := VBoxContainer.new()
	phase_sidebar.custom_minimum_size = Vector2(118, 0)
	phase_sidebar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	phase_sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	phase_sidebar.add_theme_constant_override("separation", 4)
	hbox.add_child(phase_sidebar)

	_phase_caption = Label.new()
	_phase_caption.text = "Phase"
	_phase_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	_phase_caption.add_theme_font_size_override("font_size", 10)
	_phase_caption.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65))
	phase_sidebar.add_child(_phase_caption)

	_phase_label = Label.new()
	_phase_label.text = "PLANNING"
	_phase_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_phase_label.add_theme_font_size_override("font_size", 16)
	_phase_label.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	phase_sidebar.add_child(_phase_label)

	var phase_rule := ColorRect.new()
	phase_rule.custom_minimum_size = Vector2(0, 1)
	phase_rule.color = Color(0.28, 0.32, 0.40, 0.9)
	phase_sidebar.add_child(phase_rule)

	var hint := Label.new()
	hint.text = "Drag to move\nScroll = ability\nA = aim · Esc = pause"
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.58, 0.62, 0.70))
	_hint_label = hint
	phase_sidebar.add_child(hint)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	phase_sidebar.add_child(spacer)

	_warn_label = Label.new()
	_warn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warn_label.add_theme_font_size_override("font_size", 9)
	_warn_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.4))
	phase_sidebar.add_child(_warn_label)

	var table_col := VBoxContainer.new()
	table_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(table_col)

	_timeline_grid = TacticalTimelineGrid.new()
	_timeline_grid.setup(_director)
	_timeline_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_timeline_grid.custom_minimum_size = Vector2(0, 204)
	table_col.add_child(_timeline_grid)

	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_END
	buttons.custom_minimum_size = Vector2(220, 0)
	buttons.add_theme_constant_override("separation", 8)
	hbox.add_child(buttons)

	_execute_btn = Button.new()
	_execute_btn.text = "Ready to Execute"
	_execute_btn.clip_text = false
	_execute_btn.autowrap_mode = TextServer.AUTOWRAP_OFF
	_execute_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_execute_btn.custom_minimum_size = Vector2(220, 52)
	_execute_btn.pressed.connect(_on_execute_pressed)
	buttons.add_child(_execute_btn)

	var action_spacer := Control.new()
	action_spacer.custom_minimum_size = Vector2(0, 4)
	buttons.add_child(action_spacer)

	_undo_btn = Button.new()
	_undo_btn.text = "Undo Unit"
	_undo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_undo_btn.custom_minimum_size = Vector2(220, 34)
	_undo_btn.pressed.connect(_on_undo_pressed)
	buttons.add_child(_undo_btn)

	_clear_btn = Button.new()
	_clear_btn.text = "Clear Phase Plan"
	_clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clear_btn.custom_minimum_size = Vector2(220, 34)
	_clear_btn.pressed.connect(_on_clear_pressed)
	buttons.add_child(_clear_btn)


func _apply_bottom_panel_style(panel: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.11, 0.96)
	sb.border_color = Color(0.22, 0.26, 0.34, 0.95)
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)


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
	_victory_restart_button = Button.new()
	_victory_restart_button.text = "Back to Battle Setup"
	_victory_restart_button.pressed.connect(_on_victory_restart_pressed)
	vbox.add_child(_victory_restart_button)


func configure_victory_restart(button_text: String, callback: Callable) -> void:
	if _victory_restart_button != null:
		_victory_restart_button.text = button_text
	_victory_restart_callback = callback


func _on_victory_restart_pressed() -> void:
	if _victory_restart_callback.is_valid():
		_victory_restart_callback.call()
		return
	get_tree().change_scene_to_file("res://scenes/BattleSetup.tscn")


func _on_phase_changed(phase: int) -> void:
	var names: Dictionary = {
		CombatDirector.Phase.PLANNING: "PLANNING",
		CombatDirector.Phase.EXECUTING: "EXECUTING…",
		CombatDirector.Phase.ENEMY_TURN: "ENEMY TURN…",
		CombatDirector.Phase.VICTORY: "VICTORY",
		CombatDirector.Phase.DEFEAT: "DEFEAT",
	}
	_phase_label.text = String(names.get(phase, str(phase)))
	if _timeline_grid != null:
		_timeline_grid.set_phase(phase)
	var planning: bool = CombatDirector.is_planning_phase(phase)
	_execute_btn.disabled = not planning
	_undo_btn.visible = planning
	_clear_btn.disabled = not planning
	_refresh_undo_button()
	if planning:
		_is_ready = false
		if GlobalTimeline != null:
			GlobalTimeline.rpc_reset_ready_states()
		_execute_btn.text = "Ready to Execute"
		_execute_btn.modulate = Color.WHITE
	elif not planning:
		_is_ready = false
		_execute_btn.text = "Executing..."
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


func _on_preview_updated(result: SimResult) -> void:
	if result != null and result.final_state != null and _timeline_grid != null:
		_timeline_grid.set_display_board(result.final_state)
		_refresh_timeline()


func _on_live_preview_changed() -> void:
	if _timeline_grid == null:
		return
	var live_board: BoardState = null
	if _planning_overlay != null:
		var live: CombatPlanningPreview = _planning_overlay.get_live_preview()
		if live != null:
			live_board = live.preview_board
	if live_board == null and _planning_input != null and _planning_input.preview_state != null:
		if (
			_planning_input.dragging
			or _planning_input.skill_interaction_active()
			or _planning_input.aiming
			or _planning_input.is_live_preview_active()
		):
			live_board = _planning_input.preview_state.preview_board
	if live_board == null and _director != null:
		live_board = _director.projected_state
	_timeline_grid.set_display_board(live_board)
	var mp_key: String = _timeline_mp_key(live_board)
	if mp_key == _last_timeline_mp_key:
		return
	_last_timeline_mp_key = mp_key
	_refresh_timeline()


func _timeline_mp_key(board: BoardState) -> String:
	if board == null:
		return ""
	var parts: PackedStringArray = []
	for unit: UnitState in board.units:
		if unit == null or unit.is_enemy() or not unit.is_alive():
			continue
		parts.append("%d:%d/%d" % [unit.id, unit.movement.points_left, unit.ability.points_left])
	return ",".join(parts)


func _refresh_timeline(statuses: PackedStringArray = PackedStringArray()) -> void:
	if _director == null or _timeline_grid == null:
		return
	if _director.board != null:
		_timeline_grid.set_board(_director.board)
	_timeline_grid.set_phase(_director.phase)
	_timeline_grid.set_selected(_director.selected_unit_id)
	var plan: Timeline = _director.get_player_plan()
	_timeline_grid.rebuild(plan, statuses)
	if statuses.size() > 0:
		for reason: String in statuses:
			if reason != "":
				_warn_label.text = "Plan issue: %s" % CombatUiFormatters.reason_text(reason)
				return
	_warn_label.text = ""


func _on_action_rejected(reason: String) -> void:
	_warn_label.text = "[color=#%s]! %s[/color]" % [
		CombatUiFormatters.HEX_DEATH,
		CombatUiFormatters.reason_text(reason),
	]
	if _side_panels != null:
		_side_panels.set_warning(CombatUiFormatters.reason_text(reason))
	if _sfx != null:
		_sfx.play("invalid")


func _on_execute_pressed() -> void:
	if _sfx != null:
		_sfx.play("execute")
	var next_ready: bool = not _is_ready
	if NetworkManager != null and NetworkManager.is_multiplayer:
		GlobalTimeline.rpc_set_ready(next_ready)
	else:
		GlobalTimeline.rpc_set_ready(next_ready)


func _on_player_ready_changed(_player_id: int, is_ready: bool) -> void:
	_is_ready = is_ready
	if _execute_btn == null:
		return
	if is_ready:
		_execute_btn.text = "Cancel Ready"
		_execute_btn.modulate = Color(0.4, 0.9, 0.4)
	else:
		_execute_btn.text = "Ready to Execute"
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
		CombatDirector.is_planning_phase(_director.phase)
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
