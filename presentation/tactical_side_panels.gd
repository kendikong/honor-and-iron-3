class_name TacticalSidePanels
extends CanvasLayer

## Left/right combat panels — unit info, tile info, skills, intents, battle log.

const COLOR_SELECT: Color = Color(0.98, 0.86, 0.32, 0.95)
const COLOR_SKILL_DISABLED: Color = Color(0.55, 0.55, 0.55, 0.85)
const LOG_FONT_SIZE: int = 10

var _panel_width: int = 280
var _ui_scale: float = 1.0
var _section_titles: Array[Label] = []
var _rich_labels: Array[RichTextLabel] = []

var _director: CombatDirector
var _map_view: TacticalMapView
var _intent_state: CombatIntentState
var _planning_input: CombatPlanningInput

var _left_anchor: Control
var _right_anchor: Control
var _info_label: RichTextLabel
var _tile_info_label: RichTextLabel
var _intent_label: RichTextLabel
var _skill_list: VBoxContainer
var _log_label: RichTextLabel
var _force_basic_check: CheckBox

var _board: BoardState
var _preview_board: BoardState
var _phase: int = CombatDirector.Phase.PLANNING_PHASE_1
var _selected_id: int = -1
var _selected_ability: int = 0
var _hover_coord: Vector2i = Vector2i(-999, -999)
var _intent_units: Dictionary = {}
var _last_math_telemetry: Dictionary = {}


func apply_settings(settings: GameSettings) -> void:
	if settings == null:
		return
	_ui_scale = settings.combat_ui_scale
	_panel_width = int(round(float(settings.inspector_panel_width) * _ui_scale))
	var title_sz: int = int(round(float(settings.inspector_title_font()) * _ui_scale))
	var body_sz: int = int(round(float(settings.inspector_body_font()) * _ui_scale))
	var hint_sz: int = int(round(float(settings.inspector_hint_font()) * _ui_scale))
	for title: Label in _section_titles:
		title.add_theme_font_size_override("font_size", title_sz)
	for rich: RichTextLabel in _rich_labels:
		rich.add_theme_font_size_override("normal_font_size", body_sz)
	if _log_label != null:
		_log_label.add_theme_font_size_override("normal_font_size", int(round(float(LOG_FONT_SIZE) * _ui_scale)))
	if _force_basic_check != null:
		_force_basic_check.add_theme_font_size_override("font_size", hint_sz)
	_on_viewport_resized()
	_rebuild_ability_buttons_if_dirty()


func setup(
	director: CombatDirector,
	map_view: TacticalMapView,
	intent_state: CombatIntentState = null,
	planning_input: CombatPlanningInput = null,
) -> void:
	_director = director
	_map_view = map_view
	_intent_state = intent_state
	_planning_input = planning_input
	layer = 21
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_resized)
	EventBus.board_changed.connect(_on_board_changed)
	EventBus.preview_updated.connect(_on_preview_updated)
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.ability_selected.connect(_on_ability_selected)
	EventBus.turn_phase_changed.connect(_on_phase_changed)
	EventBus.sim_event.connect(_on_sim_event)
	if _intent_state != null:
		_intent_state.intents_changed.connect(_on_intents_changed)
		_intent_state.hover_coord_changed.connect(func(coord: Vector2i) -> void:
			_hover_coord = coord
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


func set_warning(_text: String) -> void:
	pass


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
	col.offset_bottom = -int(round(280.0 * _ui_scale))
	col.add_theme_constant_override("separation", 8)
	anchor.add_child(col)
	if left_side:
		_force_basic_check = CheckBox.new()
		_force_basic_check.text = "Force Basic Movement"
		_force_basic_check.toggled.connect(_on_force_basic_toggled)
		col.add_child(_force_basic_check)
		var skill_panel := PanelContainer.new()
		skill_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(skill_panel)
		var skill_margin := MarginContainer.new()
		skill_margin.add_theme_constant_override("margin_left", 8)
		skill_margin.add_theme_constant_override("margin_right", 8)
		skill_margin.add_theme_constant_override("margin_top", 8)
		skill_margin.add_theme_constant_override("margin_bottom", 8)
		skill_panel.add_child(skill_margin)
		var skill_vbox := VBoxContainer.new()
		skill_margin.add_child(skill_vbox)
		var skill_title := Label.new()
		skill_title.text = "Skills"
		skill_title.add_theme_font_size_override("font_size", 14)
		_section_titles.append(skill_title)
		skill_vbox.add_child(skill_title)
		var skill_scroll := ScrollContainer.new()
		skill_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		skill_scroll.custom_minimum_size.y = 180
		skill_vbox.add_child(skill_scroll)
		_skill_list = VBoxContainer.new()
		_skill_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_scroll.add_child(_skill_list)
		_info_label = _add_rich_panel(col, "Unit Info")
		_tile_info_label = _add_rich_panel(col, "Tile", 72)
	else:
		_intent_label = _add_rich_panel(col, "Enemy Intent", 100)
		var log_panel := PanelContainer.new()
		log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(log_panel)
		var log_margin := MarginContainer.new()
		log_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		log_margin.add_theme_constant_override("margin_left", 8)
		log_margin.add_theme_constant_override("margin_right", 8)
		log_margin.add_theme_constant_override("margin_top", 8)
		log_margin.add_theme_constant_override("margin_bottom", 8)
		log_panel.add_child(log_margin)
		var log_vbox := VBoxContainer.new()
		log_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		log_margin.add_child(log_vbox)
		var log_title := Label.new()
		log_title.text = "Battle Log"
		log_title.add_theme_font_size_override("font_size", 14)
		_section_titles.append(log_title)
		log_vbox.add_child(log_title)
		_log_label = RichTextLabel.new()
		_log_label.bbcode_enabled = true
		_log_label.scroll_following = true
		_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_log_label.add_theme_font_size_override("normal_font_size", LOG_FONT_SIZE)
		log_vbox.add_child(_log_label)
	return anchor


func _on_viewport_resized() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var w: float = float(_panel_width)
	if _left_anchor != null:
		_left_anchor.offset_left = 8
		_left_anchor.offset_right = -(vp.x - w - 16.0)
	if _right_anchor != null:
		_right_anchor.offset_left = maxf(0.0, vp.x - w - 16.0)
		_right_anchor.offset_right = -8


func _on_force_basic_toggled(pressed: bool) -> void:
	if _planning_input != null:
		_planning_input.force_basic_movement = pressed


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
	rich.fit_content = true
	rich.scroll_active = true
	rich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rich_labels.append(rich)
	vbox.add_child(rich)
	return rich


var _last_skill_rebuild_key: String = ""


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
	_rebuild_ability_buttons()


func _on_selection_changed(unit_id: int) -> void:
	_selected_id = unit_id
	_last_skill_rebuild_key = ""
	if _intent_state != null:
		_intent_state.set_selection(unit_id)
	_refresh_info()
	_rebuild_ability_buttons()


func _on_ability_selected(index: int) -> void:
	_selected_ability = index
	_rebuild_ability_buttons()


func get_log_label() -> RichTextLabel:
	return _log_label


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
	_log_label.append_text("[font_size=%d]%s[/font_size]\n" % [LOG_FONT_SIZE, text])


func _refresh_info() -> void:
	if _board == null or _info_label == null or _tile_info_label == null:
		return
	var hov: Vector2i = _hover_coord
	_tile_info_label.text = CombatUiFormatters.tile_info(_board, hov)
	if _selected_id >= 0:
		var u := _board.get_unit_by_id(_selected_id)
		if u != null:
			_info_label.text = CombatUiFormatters.unit_info(_board, u)
			return
	if not _board.is_in_bounds(hov):
		_info_label.text = ""
		return
	var unit := _board.get_unit_at(hov)
	if unit != null:
		_info_label.text = CombatUiFormatters.unit_info(_board, unit)
	else:
		_info_label.text = "[color=#%s]Hover a unit or tile for details.[/color]" % CombatUiFormatters.HEX_DIM


func _refresh_intent_label() -> void:
	if _intent_label == null or _board == null:
		return
	var body: String = CombatUiFormatters.summarize_intents(_board, _phase, _intent_units)
	_intent_label.text = "💀 Enemy intent:\n%s" % body


func _refresh_ability_buttons_if_dirty() -> void:
	if _selected_id < 0:
		return
	var unit := _proj_unit(_selected_id)
	if unit == null:
		unit = _board.get_unit_by_id(_selected_id) if _board != null else null
	if unit == null or unit.is_enemy():
		return
	var key: String = "%d:%d:%d" % [_selected_id, _selected_ability, unit.ability.points_left]
	if key == _last_skill_rebuild_key:
		return
	_last_skill_rebuild_key = key
	_rebuild_ability_buttons()


func _rebuild_ability_buttons() -> void:
	if _skill_list == null:
		return
	for c: Node in _skill_list.get_children():
		_skill_list.remove_child(c)
		c.queue_free()
	if _board == null or _selected_id < 0:
		return
	var unit := _proj_unit(_selected_id)
	if unit == null:
		unit = _board.get_unit_by_id(_selected_id)
	if unit == null or unit.is_enemy():
		return
	var abilities: Array = unit.active_abilities
	for i: int in abilities.size():
		var ability: AbilityData = abilities[i]
		var index: int = i
		var row_btn := Button.new()
		var can_afford: bool = unit.ability.points_left >= ability.action_point_cost
		row_btn.disabled = not can_afford
		row_btn.modulate = COLOR_SELECT if index == _selected_ability else (
			Color.WHITE if can_afford else COLOR_SKILL_DISABLED
		)
		row_btn.pressed.connect(func() -> void:
			if _director != null:
				_director.select_ability(index)
		)
		row_btn.tooltip_text = CombatUiFormatters.ability_desc(ability, unit)
		row_btn.custom_minimum_size.y = 54.0 * _ui_scale
		_skill_list.add_child(row_btn)
		var vbox := VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_btn.add_child(vbox)
		var name_lbl := Label.new()
		name_lbl.text = ability.display_name
		name_lbl.add_theme_font_size_override("font_size", int(round(9.0 * _ui_scale)))
		vbox.add_child(name_lbl)
		var stats := Label.new()
		stats.text = "🔵%d  🏹%d" % [ability.action_point_cost, ability.range_tiles]
		stats.add_theme_font_size_override("font_size", int(round(9.0 * _ui_scale)))
		vbox.add_child(stats)
		var special := RichTextLabel.new()
		special.bbcode_enabled = true
		special.fit_content = true
		special.mouse_filter = Control.MOUSE_FILTER_IGNORE
		special.custom_minimum_size.x = float(_panel_width - 48)
		special.text = "[font_size=10]%s[/font_size]" % CombatUiFormatters.ability_effect_bbcode(ability, unit)
		vbox.add_child(special)


func _proj_unit(unit_id: int) -> UnitState:
	if _director == null or unit_id < 0:
		return null
	var proj: BoardState = _preview_board
	if proj == null and _director.projected_state != null:
		proj = _director.projected_state
	if proj == null:
		return _board.get_unit_by_id(unit_id) if _board != null else null
	return proj.get_unit_by_id(unit_id)
