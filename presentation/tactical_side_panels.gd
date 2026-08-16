class_name TacticalSidePanels
extends CanvasLayer

## Left/right combat panels — unit info, tile info, skills, intents, battle log.

const COLOR_SELECT: Color = Color(0.98, 0.86, 0.32, 0.95)
const COLOR_SKILL_DISABLED: Color = Color(0.55, 0.55, 0.55, 0.85)
const COLOR_SKILL_PREMOVE_BG: Color = Color(0.12, 0.18, 0.30, 0.96)
const COLOR_SKILL_ACTION_BG: Color = Color(0.20, 0.17, 0.15, 0.96)
const LOG_FONT_SIZE: int = 10
const _SKILL_UI_SETTLE_SEC: float = 0.075

var _panel_width: int = 280
var _ui_scale: float = 1.0
var _text_scale: float = 1.0
var _section_titles: Array[Label] = []
var _rich_labels: Array[RichTextLabel] = []

var _director: CombatDirector
var _map_view: TacticalMapView
var _intent_state: CombatIntentState
var _planning_input: CombatPlanningInput
var _planning_overlay: TacticalPlanningOverlay

var _left_anchor: Control
var _right_anchor: Control
var _info_label: RichTextLabel
var _tile_info_label: RichTextLabel
var _intent_label: RichTextLabel
var _skill_list: VBoxContainer
var _skill_scroll: ScrollContainer
var _log_label: RichTextLabel
var _warn_label: RichTextLabel
var _warn_panel: PanelContainer
var _force_basic_check: CheckBox
var _auto_run_check: CheckBox
var _auto_use_skill_check: CheckBox
var _danger_area_check: CheckBox
var _wait_btn: Button
var _wait_btn_syncing: bool = false

var _board: BoardState
var _preview_board: BoardState
var _phase: int = CombatDirector.Phase.PLANNING
var _selected_id: int = -1
var _selected_ability: int = 0
var _hover_coord: Vector2i = Vector2i(-999, -999)
var _intent_units: Dictionary = {}
var _last_math_telemetry: Dictionary = {}
var _settings: GameSettings


func apply_settings(settings: GameSettings) -> void:
	if settings == null:
		return
	_settings = settings
	_ui_scale = settings.combat_ui_scale
	_text_scale = settings.combat_text_scale
	_panel_width = int(round(float(settings.inspector_panel_width) * _ui_scale))
	CombatUiFormatters.configure_body_font(settings.scaled_body_font())
	var title_sz: int = settings.scaled_title_font()
	var body_sz: int = settings.scaled_body_font()
	var hint_sz: int = settings.scaled_hint_font()
	for title: Label in _section_titles:
		title.add_theme_font_size_override("font_size", title_sz)
	for rich: RichTextLabel in _rich_labels:
		rich.add_theme_font_size_override("normal_font_size", body_sz)
	if _log_label != null:
		_log_label.add_theme_font_size_override("normal_font_size", CombatUiFormatters.scaled_font_size(LOG_FONT_SIZE))
	if _force_basic_check != null:
		_force_basic_check.add_theme_font_size_override("font_size", hint_sz)
	if _auto_run_check != null:
		_auto_run_check.add_theme_font_size_override("font_size", hint_sz)
	if _auto_use_skill_check != null:
		_auto_use_skill_check.add_theme_font_size_override("font_size", hint_sz)
	if _danger_area_check != null:
		_danger_area_check.add_theme_font_size_override("font_size", hint_sz)
	if _wait_btn != null:
		_wait_btn.add_theme_font_size_override("font_size", hint_sz)
	_apply_planning_prefs()
	_on_viewport_resized()
	_last_skill_rebuild_key = ""
	_rebuild_ability_buttons()
	_refresh_info()
	_refresh_intent_label()


func get_panel_width() -> int:
	return _panel_width


func setup(
	director: CombatDirector,
	map_view: TacticalMapView,
	intent_state: CombatIntentState = null,
	planning_input: CombatPlanningInput = null,
	planning_overlay: TacticalPlanningOverlay = null,
) -> void:
	_director = director
	_map_view = map_view
	_intent_state = intent_state
	_planning_input = planning_input
	_planning_overlay = planning_overlay
	layer = 21
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_resized)
	EventBus.board_changed.connect(_on_board_changed)
	EventBus.preview_updated.connect(_on_preview_updated)
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.ability_selected.connect(_on_ability_selected)
	EventBus.turn_phase_changed.connect(_on_phase_changed)
	EventBus.timeline_changed.connect(_on_timeline_changed)
	EventBus.sim_event.connect(_on_sim_event)
	EventBus.action_rejected.connect(_on_action_rejected)
	if _intent_state != null:
		_intent_state.intents_changed.connect(_on_intents_changed)
		_intent_state.hover_coord_changed.connect(func(coord: Vector2i) -> void:
			_hover_coord = coord
			_refresh_info(),
		)
	if _planning_overlay != null:
		_planning_overlay.live_preview_changed.connect(func() -> void:
			_refresh_intent_label()
			_refresh_info(),
		)
	_on_viewport_resized()


func set_hover_coord(coord: Vector2i) -> void:
	if _intent_state != null:
		_intent_state.set_hover_coord(coord)
		return
	if coord == _hover_coord:
		return
	_hover_coord = coord
	_refresh_info()


func set_warning(text: String) -> void:
	if _warn_label == null:
		return
	if text.is_empty():
		_warn_label.text = ""
		_warn_panel.visible = false
		return
	_warn_panel.visible = true
	_warn_label.text = "[color=#%s]! %s[/color]" % [CombatUiFormatters.HEX_DEATH, text]


func _on_action_rejected(reason: String) -> void:
	set_warning(CombatUiFormatters.reason_text(reason))


func _on_intents_changed(units: Dictionary) -> void:
	_intent_units = units
	_refresh_intent_label()


func _build_ui() -> void:
	_left_anchor = _make_panel_column(true)
	add_child(_left_anchor)
	_right_anchor = _make_panel_column(false)
	add_child(_right_anchor)


func _make_panel_column(left_side: bool) -> Control:
	var anchor := Control.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = int(round(72.0 * _ui_scale))
	col.offset_bottom = -int(round(8.0 * _ui_scale))
	col.add_theme_constant_override("separation", 8)
	anchor.add_child(col)
	if left_side:
		_tile_info_label = _add_weighted_rich_panel(col, "Tile", 0.2)
		_warn_label = _add_weighted_rich_panel(col, "Warning", 0.08)
		_warn_panel = _warn_label.get_parent().get_parent().get_parent() as PanelContainer
		_warn_panel.visible = false
		_log_label = _add_weighted_log_panel(col, 0.52)
		_intent_label = _add_weighted_rich_panel(col, "Enemy Intent", 0.2)
	else:
		_info_label = _add_weighted_rich_panel(col, "Unit Info", 0.45)
		_skill_list = _add_weighted_skill_panel(col, 0.45)
		_add_planning_controls(col)
	return anchor


func _add_planning_controls(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	_wait_btn = Button.new()
	_wait_btn.text = "Wait"
	_wait_btn.toggle_mode = true
	_wait_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wait_btn.tooltip_text = "Turn modifier: skip Action and Post-Move for this unit. Click again to cancel."
	_wait_btn.pressed.connect(_on_wait_pressed)
	row.add_child(_wait_btn)

	_force_basic_check = CheckBox.new()
	_force_basic_check.text = "Force Basic Movement"
	_force_basic_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_force_basic_check.toggled.connect(_on_force_basic_toggled)
	row.add_child(_force_basic_check)

	var auto_row := HBoxContainer.new()
	auto_row.add_theme_constant_override("separation", 8)
	parent.add_child(auto_row)
	_auto_run_check = CheckBox.new()
	_auto_run_check.text = "Auto Run"
	_auto_run_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_auto_run_check.tooltip_text = (
		"Hide Run from the skill list. Extended move tiles always show when affordable; "
		+ "Run AP is spent only when the destination requires it."
	)
	_auto_run_check.toggled.connect(_on_auto_run_toggled)
	auto_row.add_child(_auto_run_check)

	_auto_use_skill_check = CheckBox.new()
	_auto_use_skill_check.text = "Auto Skill After Move"
	_auto_use_skill_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_auto_use_skill_check.tooltip_text = (
		"When enabled, hovering a move tile with a self-target skill shows move/skill composite cursors. "
		+ "When disabled, only movement icons are shown on move tiles."
	)
	_auto_use_skill_check.toggled.connect(_on_auto_use_skill_toggled)
	auto_row.add_child(_auto_use_skill_check)

	_danger_area_check = CheckBox.new()
	_danger_area_check.text = "Danger Area"
	_danger_area_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_danger_area_check.toggled.connect(_on_danger_area_toggled)
	row.add_child(_danger_area_check)
	_refresh_wait_button()


func _add_weighted_rich_panel(parent: VBoxContainer, title: String, weight: float) -> RichTextLabel:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = weight
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 14)
	_section_titles.append(lbl)
	vbox.add_child(lbl)
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = false
	rich.scroll_active = true
	rich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rich_labels.append(rich)
	vbox.add_child(rich)
	return rich


func _add_weighted_log_panel(parent: VBoxContainer, weight: float) -> RichTextLabel:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = weight
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)
	var log_title := Label.new()
	log_title.text = "Battle Log"
	log_title.add_theme_font_size_override("font_size", 14)
	_section_titles.append(log_title)
	vbox.add_child(log_title)
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.scroll_following = true
	rich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rich.add_theme_font_size_override("normal_font_size", LOG_FONT_SIZE)
	vbox.add_child(rich)
	return rich


func _add_weighted_skill_panel(parent: VBoxContainer, weight: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = weight
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var skill_vbox := VBoxContainer.new()
	skill_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(skill_vbox)
	var skill_title := Label.new()
	skill_title.text = "Skills"
	skill_title.add_theme_font_size_override("font_size", 14)
	_section_titles.append(skill_title)
	skill_vbox.add_child(skill_title)
	var skill_scroll := ScrollContainer.new()
	skill_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_vbox.add_child(skill_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_scroll.add_child(list)
	_skill_scroll = skill_scroll
	_skill_list = list
	return list


func _on_viewport_resized() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var w: float = float(_panel_width)
	if _left_anchor != null:
		_left_anchor.offset_left = 8
		_left_anchor.offset_right = -(vp.x - w - 16.0)
	if _right_anchor != null:
		_right_anchor.offset_left = maxf(0.0, vp.x - w - 16.0)
		_right_anchor.offset_right = -8


func _apply_planning_prefs() -> void:
	if _settings == null:
		return
	if _force_basic_check != null:
		_force_basic_check.set_pressed_no_signal(_settings.planning_force_basic)
	if _auto_run_check != null:
		_auto_run_check.set_pressed_no_signal(_settings.planning_auto_run)
	if _auto_use_skill_check != null:
		_auto_use_skill_check.set_pressed_no_signal(_settings.planning_auto_use_skill_after_move)
	if _danger_area_check != null:
		_danger_area_check.set_pressed_no_signal(_settings.planning_danger_area)
	if _planning_input != null:
		_planning_input.force_basic_movement = _settings.planning_force_basic
		_planning_input.auto_run = _settings.planning_auto_run
		_planning_input.auto_use_skill_after_move = _settings.planning_auto_use_skill_after_move
	if _planning_overlay != null:
		_planning_overlay.set_show_danger_area(_settings.planning_danger_area)
	_refresh_planning_move_overlay()


func _save_planning_prefs() -> void:
	if _settings == null:
		return
	if _force_basic_check != null:
		_settings.planning_force_basic = _force_basic_check.button_pressed
	if _auto_run_check != null:
		_settings.planning_auto_run = _auto_run_check.button_pressed
	if _auto_use_skill_check != null:
		_settings.planning_auto_use_skill_after_move = _auto_use_skill_check.button_pressed
	if _danger_area_check != null:
		_settings.planning_danger_area = _danger_area_check.button_pressed
	_settings.save_to_disk()


func _on_force_basic_toggled(pressed: bool) -> void:
	if pressed and _auto_run_check != null and _auto_run_check.button_pressed:
		_auto_run_check.set_pressed_no_signal(false)
		if _planning_input != null:
			_planning_input.auto_run = false
	if _planning_input != null:
		_planning_input.force_basic_movement = pressed
	_save_planning_prefs()
	_refresh_planning_move_overlay()


func _on_auto_run_toggled(pressed: bool) -> void:
	if pressed and _force_basic_check != null and _force_basic_check.button_pressed:
		_force_basic_check.set_pressed_no_signal(false)
		if _planning_input != null:
			_planning_input.force_basic_movement = false
	if _planning_input != null:
		_planning_input.auto_run = pressed
		_director.sync_selected_ability_if_invalid()
		_selected_ability = _director.selected_ability_index
	_last_skill_rebuild_key = ""
	_rebuild_ability_buttons()
	_save_planning_prefs()
	_refresh_planning_move_overlay()


func _on_auto_use_skill_toggled(pressed: bool) -> void:
	if _planning_input != null:
		_planning_input.auto_use_skill_after_move = pressed
	_save_planning_prefs()
	_refresh_planning_move_overlay()


func _refresh_planning_move_overlay() -> void:
	if _planning_overlay != null and _director != null:
		_planning_overlay.recompute_hover_ranges(
			_planning_input.force_basic_movement if _planning_input != null else false,
			_director.selected_ability_index,
			_planning_input.dragging if _planning_input != null else false,
			_planning_input.get_drag_unit_id() if _planning_input != null else -1,
		)
	if _planning_input != null:
		var cell: Vector2i = _planning_input.get_hover_tile_for_ui()
		_planning_input.on_hover_moved(cell)


func _on_wait_pressed() -> void:
	if _wait_btn_syncing or _director == null or _selected_id < 0:
		return
	_director.rpc_plan_wait(_selected_id)


func _refresh_wait_button() -> void:
	if _wait_btn == null:
		return
	var waiting: bool = (
		_director != null and _selected_id >= 0 and _director.unit_has_wait_planned(_selected_id)
	)
	_wait_btn_syncing = true
	_wait_btn.set_pressed_no_signal(waiting)
	_wait_btn_syncing = false
	_wait_btn.text = "Waiting" if waiting else "Wait"
	if waiting:
		_wait_btn.disabled = false
		_wait_btn.tooltip_text = "Cancel wait — restore action planning for this unit."
		return
	_wait_btn.tooltip_text = "Turn modifier: skip Action and Post-Move for this unit."
	_wait_btn.disabled = not _can_enable_wait()


func _on_danger_area_toggled(pressed: bool) -> void:
	if _planning_overlay != null:
		_planning_overlay.set_show_danger_area(pressed)
	_save_planning_prefs()


func _add_rich_panel(parent: VBoxContainer, title: String, min_h: int = 120) -> RichTextLabel:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = min_h
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	margin.add_child(vbox)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 14)
	_section_titles.append(lbl)
	vbox.add_child(lbl)
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = false
	rich.scroll_active = true
	rich.custom_minimum_size.y = float(mini(min_h, 120))
	rich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rich_labels.append(rich)
	vbox.add_child(rich)
	return rich


var _last_skill_rebuild_key: String = ""
var _skill_ui_lock: bool = false
var _skill_ui_settle_generation: int = 0


func _on_board_changed(board: BoardState) -> void:
	_board = board
	_refresh_info()
	_refresh_intent_label()
	_refresh_ability_buttons_if_dirty()


func _on_preview_updated(result: SimResult) -> void:
	_preview_board = result.final_state
	if _intent_state != null:
		_intent_state.set_preview_board(result.final_state)
	_refresh_info()
	_refresh_ability_buttons_if_dirty()
	_refresh_wait_button()


func _on_timeline_changed(_plan: Timeline, _statuses: PackedStringArray) -> void:
	_last_skill_rebuild_key = ""
	_refresh_ability_buttons_if_dirty()
	_refresh_wait_button()


func _on_selection_changed(unit_id: int) -> void:
	_selected_id = unit_id
	if unit_id >= 0 and _director != null:
		_selected_ability = _director.selected_ability_index
	_refresh_info()
	if unit_id < 0:
		_clear_skill_buttons()
		return
	_last_skill_rebuild_key = ""
	_refresh_ability_buttons_if_dirty()
	_scroll_selected_skill_into_view()
	_refresh_wait_button()


func _clear_skill_buttons() -> void:
	if _skill_list == null:
		return
	for c: Node in _skill_list.get_children():
		_skill_list.remove_child(c)
		c.queue_free()
	_last_skill_rebuild_key = ""


func _on_ability_selected(index: int) -> void:
	_selected_ability = index
	if index >= 0 and _force_basic_check != null and _force_basic_check.button_pressed:
		_force_basic_check.set_pressed_no_signal(false)
		if _planning_input != null:
			_planning_input.force_basic_movement = false
		if _settings != null:
			_settings.planning_force_basic = false
	if _skill_ui_lock:
		return
	if _skill_list != null and _skill_list.get_child_count() > 0:
		_update_skill_selection_highlight()
		_scroll_selected_skill_into_view()
	else:
		_refresh_ability_buttons_if_dirty()
	_schedule_info_refresh()


func _schedule_info_refresh() -> void:
	_skill_ui_settle_generation += 1
	var gen: int = _skill_ui_settle_generation
	if not is_inside_tree():
		_refresh_info()
		_scroll_selected_skill_into_view()
		return
	get_tree().create_timer(_SKILL_UI_SETTLE_SEC).timeout.connect(
		func() -> void:
			if gen != _skill_ui_settle_generation:
				return
			_refresh_info()
			_scroll_selected_skill_into_view(),
		CONNECT_ONE_SHOT,
	)


func _update_skill_selection_highlight() -> void:
	if _skill_list == null:
		return
	var unit := _committed_plan_unit(_selected_id)
	if unit == null:
		unit = _board.get_unit_by_id(_selected_id)
	for c: Node in _skill_list.get_children():
		var row_panel := c as PanelContainer
		if row_panel == null or row_panel.get_child_count() == 0:
			continue
		var row_btn := row_panel.get_child(0) as Button
		if row_btn == null:
			continue
		var index: int = int(row_btn.get_meta(&"ability_index", -1))
		if index < 0:
			continue
		var usable: bool = not row_btn.disabled
		row_btn.modulate = Color.WHITE if usable else COLOR_SKILL_DISABLED
		var ability: AbilityData = null
		if unit != null and index >= 0 and index < unit.active_abilities.size():
			ability = unit.active_abilities[index] as AbilityData
		if ability != null:
			var is_selected: bool = index == _selected_ability
			_apply_skill_row_panel_style(
				row_panel, ability, is_selected, usable,
			)
			_apply_skill_row_name_color(row_btn, ability, is_selected)


func _skill_list_row_for_ability_index(ability_index: int) -> int:
	if ability_index < 0 or _board == null or _selected_id < 0:
		return -1
	var unit := _committed_plan_unit(_selected_id)
	if unit == null:
		unit = _board.get_unit_by_id(_selected_id)
	if unit == null:
		return -1
	var row: int = 0
	for i: int in range(unit.active_abilities.size()):
		var ability: AbilityData = unit.active_abilities[i] as AbilityData
		if _planning_input != null and _planning_input.auto_run and ability.is_universal_run():
			if i == ability_index:
				return -1
			continue
		if i == ability_index:
			return row
		row += 1
	return -1


func _scroll_selected_skill_into_view() -> void:
	if _skill_scroll == null or _skill_list == null:
		return
	var row: int = _skill_list_row_for_ability_index(_selected_ability)
	if row < 0:
		return
	var count: int = _skill_list.get_child_count()
	if row >= count:
		return
	var row_ctrl: Control = _skill_list.get_child(row) as Control
	if row_ctrl == null or not is_instance_valid(row_ctrl):
		return
	if row_ctrl.size.y <= 1.0:
		call_deferred("_ensure_skill_visible_by_index", row)
		return
	_apply_skill_list_scroll(row, row_ctrl)


func _ensure_skill_visible_by_index(row: int) -> void:
	if _skill_scroll == null or _skill_list == null:
		return
	if row != _skill_list_row_for_ability_index(_selected_ability):
		return
	var count: int = _skill_list.get_child_count()
	if row < 0 or row >= count:
		return
	var row_ctrl: Control = _skill_list.get_child(row) as Control
	if row_ctrl == null or not is_instance_valid(row_ctrl):
		return
	_apply_skill_list_scroll(row, row_ctrl)


func _apply_skill_list_scroll(row: int, row_ctrl: Control) -> void:
	var count: int = _skill_list.get_child_count()
	var bar: VScrollBar = _skill_scroll.get_v_scroll_bar()
	if row == 0:
		_skill_scroll.scroll_vertical = 0
		return
	if row == count - 1 and bar != null:
		_skill_scroll.scroll_vertical = int(bar.max_value)
		return
	_skill_scroll.ensure_control_visible(row_ctrl)


func get_log_label() -> RichTextLabel:
	return _log_label


func get_log_plain_text(max_chars: int = 4000) -> String:
	if _log_label == null:
		return ""
	var text := _log_label.get_parsed_text()
	if text.length() <= max_chars:
		return text
	return text.substr(text.length() - max_chars)


func _on_phase_changed(phase: int) -> void:
	_phase = phase
	if _intent_state != null:
		_intent_state.set_phase(phase)
	_refresh_intent_label()


func _on_sim_event(event: SimEvent) -> void:
	if _log_label == null:
		return
	var result: Dictionary = CombatUiFormatters.log_line(_board, event, _last_math_telemetry)
	_last_math_telemetry = result.get("telemetry", {})
	var line: String = result.get("line", "")
	if line != "":
		_append_log(line)


func _append_log(text: String) -> void:
	_log_label.append_text(
		"[font_size=%d]%s[/font_size]\n" % [CombatUiFormatters.scaled_font_size(LOG_FONT_SIZE), text],
	)


func _refresh_info() -> void:
	if _board == null or _info_label == null or _tile_info_label == null:
		return
	var hov: Vector2i = _hover_coord
	if _planning_input != null:
		var ui_hov: Vector2i = _planning_input.get_hover_tile_for_ui()
		if _board.is_in_bounds(ui_hov):
			hov = ui_hov
	_tile_info_label.text = CombatUiFormatters.tile_info(_board, hov)
	if _selected_id >= 0:
		var committed: UnitState = _committed_plan_unit(_selected_id)
		var live_board: BoardState = _live_preview_board()
		var use_live: bool = (
			live_board != null
			and _planning_input != null
			and not _planning_input.drag_preview_failed
		)
		var u: UnitState = null
		var info_board: BoardState = null
		## Planning AP from canonical intent economy (live sim, run premove, skill scroll).
		var ap_override: int = -1
		if _planning_input != null and _selected_id >= 0:
			ap_override = _planning_input.planning_display_ap_left(_selected_id)
		if use_live:
			u = live_board.get_unit_by_id(_selected_id)
			info_board = live_board
		if u == null:
			u = committed
			info_board = _preview_board
			if info_board == null and _director != null and _director.projected_state != null:
				info_board = _director.projected_state
			if info_board == null:
				info_board = _board
		if u == null and _director != null and _director.base_board != null:
			u = _director.base_board.get_unit_by_id(_selected_id)
		if u != null:
			var uses_run: bool = (
				_planning_input != null and _planning_input.unit_move_requires_run(u.id)
			)
			_info_label.text = CombatUiFormatters.unit_info(info_board, u, uses_run, ap_override)
			_append_hover_action_hint()
			return
	if not _board.is_in_bounds(hov):
		_info_label.text = ""
		return
	var unit := _board.get_unit_at(hov)
	if unit != null:
		var hover_run: bool = (
			_planning_input != null and _planning_input.unit_move_requires_run(unit.id)
		)
		_info_label.text = CombatUiFormatters.unit_info(_board, unit, hover_run)
	else:
		_info_label.text = "[font_size=%d][color=#%s]Hover a unit or tile for details.[/color][/font_size]" % [
			CombatUiFormatters.scaled_font_size(10),
			CombatUiFormatters.HEX_DIM,
		]


## Committed-plan AP minus selected skill cost (skill button affordability only).
func _selection_preview_ap_left(unit: UnitState) -> int:
	if unit == null:
		return -1
	var ap_left: int = unit.ability.points_left
	if _selected_ability < 0 or _selected_ability >= unit.active_abilities.size():
		return ap_left
	var ability: AbilityData = unit.active_abilities[_selected_ability] as AbilityData
	if ability == null:
		return ap_left
	if _planning_input != null and _planning_input.auto_run and ability.is_universal_run():
		return ap_left
	## Show cost of the scrolled skill even if greyed / not currently selectable.
	return maxi(0, ap_left - ability.action_point_cost)


func _append_hover_action_hint() -> void:
	if _planning_input == null or _director == null or _info_label == null:
		return
	if not CombatDirector.is_planning_phase(_phase):
		return
	var hov: Vector2i = _planning_input.get_hover_tile_for_ui()
	if not _board.is_in_bounds(hov):
		return
	var actor := _board.get_unit_by_id(_selected_id)
	if actor == null:
		return
	var hint: String = ""
	if _planning_input.skill_interaction_active() or _planning_input.aiming:
		if _planning_input.preview_state.preview_board != null:
			hint = "\n[color=#%s][i]Live preview active at (%d,%d)[/i][/color]" % [
				CombatUiFormatters.HEX_DIM,
				hov.x,
				hov.y,
			]
	elif _planning_input.dragging:
		hint = "\n[color=#%s][i]Dragging — tile (%d,%d)[/i][/color]" % [
			CombatUiFormatters.HEX_DIM,
			hov.x,
			hov.y,
		]
	if hint != "":
		_info_label.text += hint


func _refresh_intent_label() -> void:
	if _intent_label == null or _board == null:
		return
	var intent_list: Array = _board.intents
	if _planning_input != null:
		var use_live: bool = (
			_planning_input.dragging
			or _planning_input.skill_interaction_active()
			or _planning_input.aiming
		)
		if use_live:
			var live: Array = _planning_input.preview_state.live_intents
			if not live.is_empty():
				intent_list = live
	var body: String = CombatUiFormatters.summarize_intents(
		_board, _phase == CombatDirector.Phase.ENEMY_TURN, _intent_units, intent_list,
	)
	_intent_label.text = "💀 Enemy intent:\n%s" % body


func _refresh_ability_buttons_if_dirty() -> void:
	if _skill_ui_lock:
		return
	if _selected_id < 0:
		return
	var unit := _committed_plan_unit(_selected_id)
	if unit == null:
		unit = _board.get_unit_by_id(_selected_id) if _board != null else null
	if unit == null or unit.is_enemy():
		return
	var key: String = _skill_rebuild_cache_key(unit)
	if key == _last_skill_rebuild_key:
		return
	_last_skill_rebuild_key = key
	_rebuild_ability_buttons()
	_refresh_wait_button()


func _skill_rebuild_cache_key(unit: UnitState) -> String:
	var status_bits: int = 0
	if unit.has_status(GameEnums.StatusType.STAGGER):
		status_bits |= 1
	if unit.has_status(GameEnums.StatusType.SILENCE):
		status_bits |= 2
	if unit.has_status(GameEnums.StatusType.PACIFY):
		status_bits |= 4
	return "%d:%d:%d:%d" % [
		_selected_id,
		unit.ability.points_left,
		1 if unit.turn_action_used else 0,
		status_bits,
	]


func _rebuild_ability_buttons() -> void:
	if _skill_list == null:
		return
	_skill_ui_lock = true
	if _settings != null:
		CombatUiFormatters.configure_body_font(_settings.scaled_body_font())
	for c: Node in _skill_list.get_children():
		_skill_list.remove_child(c)
		c.queue_free()
	if _board == null or _selected_id < 0:
		_skill_ui_lock = false
		return
	## Affordability uses committed plan only — live hover must not grey sibling skills.
	var unit := _committed_plan_unit(_selected_id)
	if unit == null:
		unit = _board.get_unit_by_id(_selected_id)
	if unit == null or unit.is_enemy():
		_skill_ui_lock = false
		return
	var abilities: Array = unit.active_abilities
	var selected_usable: bool = true
	if _selected_ability >= 0 and _selected_ability < abilities.size():
		var sel_ability: AbilityData = abilities[_selected_ability] as AbilityData
		if _planning_input != null and _planning_input.auto_run and sel_ability.is_universal_run():
			selected_usable = false
		else:
			selected_usable = AbilitySystem.ability_planning_selectable(unit, sel_ability, _board)
	if (
		not selected_usable
		and _director != null
		and _director.find_awaiting_action(_selected_id) == null
	):
		_director.sync_selected_ability_if_invalid()
		_selected_ability = _director.selected_ability_index
	for i: int in abilities.size():
		var ability: AbilityData = abilities[i]
		if _planning_input != null and _planning_input.auto_run and ability.is_universal_run():
			continue
		var index: int = i
		var row_panel := PanelContainer.new()
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		var selected_row: bool = index == _selected_ability
		var usable: bool = AbilitySystem.ability_planning_selectable(unit, ability, _board)
		_apply_skill_row_panel_style(row_panel, ability, selected_row, usable)
		var row_btn := Button.new()
		row_btn.set_meta(&"ability_index", index)
		row_btn.disabled = not usable
		row_btn.flat = true
		row_btn.focus_mode = Control.FOCUS_NONE
		row_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		row_btn.modulate = Color.WHITE if usable else COLOR_SKILL_DISABLED
		row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_btn.pressed.connect(func() -> void:
			if _director != null and usable:
				_director.select_ability(index)
		)
		var transparent := StyleBoxFlat.new()
		transparent.bg_color = Color(0, 0, 0, 0)
		transparent.set_content_margin_all(0)
		row_btn.add_theme_stylebox_override("normal", transparent)
		row_btn.add_theme_stylebox_override("hover", transparent)
		row_btn.add_theme_stylebox_override("pressed", transparent)
		row_btn.add_theme_stylebox_override("disabled", transparent)
		row_btn.add_theme_stylebox_override("focus", transparent)
		row_panel.add_child(row_btn)
		var btn_vbox := VBoxContainer.new()
		btn_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn_vbox.add_theme_constant_override("separation", 2)
		row_btn.add_child(btn_vbox)
		var layout: Dictionary = CombatUiFormatters.ability_skill_list_layout(ability, unit)
		var header_hbox := HBoxContainer.new()
		header_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header_hbox.add_theme_constant_override("separation", 8)
		btn_vbox.add_child(header_hbox)
		var name_lbl := Label.new()
		name_lbl.text = String(layout.get("title", ability.display_name)).to_upper()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", CombatUiFormatters.scaled_font_size(10))
		if selected_row:
			name_lbl.add_theme_color_override(
				"font_color",
				CombatUiFormatters.ability_skill_row_select_font_color(ability),
			)
		header_hbox.add_child(name_lbl)
		var cost_chip: Dictionary = layout.get("cost", {})
		header_hbox.add_child(_make_skill_icon(
			String(cost_chip.get("emoji", "")),
			String(cost_chip.get("text", "")),
			String(cost_chip.get("tooltip", "")),
		))
		var module_lines: PackedStringArray = layout.get("module_lines", PackedStringArray())
		var effect_px: int = CombatUiFormatters.scaled_font_size(9)
		var module_line_count: int = maxi(module_lines.size(), 1)
		for line_bbcode: String in module_lines:
			var module_lbl := RichTextLabel.new()
			module_lbl.bbcode_enabled = true
			module_lbl.fit_content = true
			module_lbl.scroll_active = false
			module_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
			module_lbl.custom_minimum_size.x = float(maxi(120, _panel_width - 48))
			module_lbl.add_theme_font_size_override("normal_font_size", effect_px)
			module_lbl.text = "[font_size=%d]%s[/font_size]" % [effect_px, line_bbcode]
			btn_vbox.add_child(module_lbl)
		var header_h: float = float(CombatUiFormatters.scaled_font_size(10)) * 1.6
		var module_h: float = float(module_line_count) * float(effect_px) * 1.35
		row_btn.custom_minimum_size.y = header_h + module_h + 10.0
		_skill_list.add_child(row_panel)

	_skill_ui_lock = false
	_refresh_wait_button()
	_scroll_selected_skill_into_view()


func _can_enable_wait() -> bool:
	if _director == null or _selected_id < 0:
		return false
	if _director.get_planning_move_timing(_selected_id) != GameEnums.MoveTiming.PRE_ACTION:
		return false
	var unit := _committed_plan_unit(_selected_id)
	if unit == null and _board != null:
		unit = _board.get_unit_by_id(_selected_id)
	return unit != null and unit.can_use_action_slot()


func _is_unit_action_exhausted() -> bool:
	if _director != null and _selected_id >= 0 and _director.unit_has_wait_planned(_selected_id):
		return true
	if _planning_input != null:
		return _planning_input.selected_phase_action_exhausted(_selected_id)
	if _selected_id < 0 or _board == null:
		return true
	var unit := _committed_plan_unit(_selected_id)
	if unit == null:
		unit = _board.get_unit_by_id(_selected_id)
	if unit == null:
		return true
	return not unit.can_use_action_slot()


func _apply_skill_row_panel_style(
	panel: PanelContainer,
	ability: AbilityData,
	selected: bool,
	usable: bool,
) -> void:
	var bg: Color = CombatUiFormatters.ability_skill_row_background(ability, selected)
	if not usable:
		bg = bg.lerp(COLOR_SKILL_DISABLED, 0.45)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	if ability != null and ability.is_pre_move_planner():
		style.border_color = (
			Color(0.45, 0.78, 1.0, 0.95) if selected else Color(0.20, 0.50, 0.82, 0.85)
		)
		style.set_border_width_all(2 if selected else 1)
	else:
		style.border_color = Color(0.32, 0.32, 0.36, 0.55)
		style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)


func _apply_skill_row_name_color(
	row_btn: Button,
	ability: AbilityData,
	selected: bool,
) -> void:
	if row_btn == null or row_btn.get_child_count() == 0:
		return
	var btn_vbox := row_btn.get_child(0) as VBoxContainer
	if btn_vbox == null or btn_vbox.get_child_count() == 0:
		return
	var header_hbox := btn_vbox.get_child(0) as HBoxContainer
	if header_hbox == null or header_hbox.get_child_count() == 0:
		return
	var name_lbl := header_hbox.get_child(0) as Label
	if name_lbl == null:
		return
	if selected:
		name_lbl.add_theme_color_override(
			"font_color",
			CombatUiFormatters.ability_skill_row_select_font_color(ability),
		)
	else:
		name_lbl.remove_theme_color_override("font_color")


func _make_skill_icon(emoji: String, val: String, tip: String) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.tooltip_text = tip
	var emoji_lbl := Label.new()
	emoji_lbl.text = emoji
	emoji_lbl.add_theme_font_size_override("font_size", CombatUiFormatters.scaled_font_size(10))
	var val_lbl := Label.new()
	val_lbl.text = val
	val_lbl.add_theme_font_size_override("font_size", CombatUiFormatters.scaled_font_size(10))
	row.add_child(emoji_lbl)
	row.add_child(val_lbl)
	return row


func _bbcode_plain_length(bbcode: String) -> int:
	var plain := ""
	var in_tag := false
	for i: int in bbcode.length():
		var c: String = bbcode[i]
		if c == "[":
			in_tag = true
		elif c == "]":
			in_tag = false
		elif not in_tag:
			plain += c
	return plain.length()


## Unit after committed plan only — never live hover (avoids greying skills on preview spend).
func _committed_plan_unit(unit_id: int) -> UnitState:
	if _director == null or unit_id < 0:
		return null
	if _director.projected_state != null:
		var proj_u: UnitState = _director.projected_state.get_unit_by_id(unit_id)
		if proj_u != null:
			return proj_u
	if _preview_board != null:
		var preview_u: UnitState = _preview_board.get_unit_by_id(unit_id)
		if preview_u != null:
			return preview_u
	return _board.get_unit_by_id(unit_id) if _board != null else null


func _proj_unit(unit_id: int) -> UnitState:
	if _director == null or unit_id < 0:
		return null
	var proj: BoardState = _live_preview_board()
	if proj == null:
		proj = _preview_board
	if proj == null and _director.projected_state != null:
		proj = _director.projected_state
	if proj == null:
		return _board.get_unit_by_id(unit_id) if _board != null else null
	return proj.get_unit_by_id(unit_id)


func _live_preview_board() -> BoardState:
	if _planning_overlay != null:
		var live: CombatPlanningPreview = _planning_overlay.get_live_preview()
		if live != null and live.preview_board != null:
			return live.preview_board
	if _planning_input != null and _planning_input.preview_state != null:
		if (
			_planning_input.dragging
			or _planning_input.skill_interaction_active()
			or _planning_input.aiming
			or _planning_input.is_live_preview_active()
		):
			return _planning_input.preview_state.preview_board
	return null
