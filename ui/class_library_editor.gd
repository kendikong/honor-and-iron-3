class_name ClassLibraryEditorScreen
extends Control

const SAVE_PATH: String = "user://class_library_editor_overrides.json"

static var _restore_unit_id: StringName = &""

enum ViewMode { UNIT, GLOSSARY, DEFINITIONS }

var _selected_unit: UnitData
var _view_mode: ViewMode = ViewMode.UNIT
var _view_unit_id: StringName = &""
var _detail_vbox: VBoxContainer
var _detail_scroll: ScrollContainer
var _save_status: Label
var _scale_label: Label
var _sidebar_panel: PanelContainer
var _toolbar_panel: PanelContainer
var _ability_ui: Dictionary = {}
var _glossary_overrides: Dictionary = {}
var _class_buttons: Dictionary = {}
var _nav_buttons: Array[Button] = []
var _active_sidebar_btn: Button = null


func _ready() -> void:
	if has_node("ColorRect"):
		$ColorRect.color = ClassLibraryTheme.BG_BASE
	if has_node("Title"):
		_style_hero_label($Title)
	if has_node("BackButton"):
		_style_toolbar_button($BackButton)
	$BackButton.pressed.connect(_on_back_pressed)
	if MenuNavigation:
		MenuNavigation.register(self, _on_back_pressed)
	_load_overrides()
	_build_layout()
	var units: Array[UnitData] = DataLibrary.get_all_player_units()
	var pick: UnitData = null
	if _restore_unit_id != &"":
		pick = DataLibrary.get_unit(_restore_unit_id)
		_restore_unit_id = &""
	if pick == null and not units.is_empty():
		pick = units[0]
	if pick != null:
		_select_unit(pick)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _build_layout() -> void:
	var toolbar_panel := PanelContainer.new()
	_toolbar_panel = toolbar_panel
	toolbar_panel.anchor_right = 1.0
	toolbar_panel.offset_left = ClassLibraryTheme.sidebar_width() + ClassLibraryTheme.px(48)
	toolbar_panel.offset_top = 88.0
	toolbar_panel.offset_right = -32.0
	toolbar_panel.offset_bottom = 136.0
	toolbar_panel.add_theme_stylebox_override("panel", ClassLibraryTheme.panel_style(ClassLibraryTheme.BG_TOOLBAR))
	add_child(toolbar_panel)
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_MD))
	toolbar_panel.add_child(top_bar)
	var save_btn := Button.new()
	save_btn.text = "Save"
	_style_toolbar_button(save_btn)
	save_btn.pressed.connect(_save_overrides)
	top_bar.add_child(save_btn)
	var reload_btn := Button.new()
	reload_btn.text = "Reset Factories"
	_style_toolbar_button(reload_btn)
	reload_btn.pressed.connect(_reload_factories)
	top_bar.add_child(reload_btn)
	_add_scale_controls(top_bar)
	_save_status = Label.new()
	_save_status.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	_save_status.add_theme_color_override("font_color", ClassLibraryTheme.ACCENT_SUCCESS)
	top_bar.add_child(_save_status)
	var hint := Label.new()
	hint.text = "Live edits · Save = glossary only · Reset = factory defaults"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SMALL))
	hint.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_MUTED)
	top_bar.add_child(hint)

	var split := HSplitContainer.new()
	split.anchor_right = 1.0
	split.anchor_bottom = 1.0
	split.offset_top = 148.0
	split.offset_bottom = -16.0
	split.offset_left = 24.0
	split.offset_right = -24.0
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)

	var sidebar := PanelContainer.new()
	_sidebar_panel = sidebar
	sidebar.custom_minimum_size = Vector2(ClassLibraryTheme.sidebar_width(), 0)
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_stylebox_override("panel", ClassLibraryTheme.panel_style(ClassLibraryTheme.BG_SIDEBAR))
	split.add_child(sidebar)
	var sidebar_pad := MarginContainer.new()
	sidebar_pad.add_theme_constant_override("margin_left", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	sidebar_pad.add_theme_constant_override("margin_right", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	sidebar_pad.add_theme_constant_override("margin_top", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	sidebar_pad.add_theme_constant_override("margin_bottom", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	sidebar.add_child(sidebar_pad)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_pad.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_XS))
	scroll.add_child(list)
	_add_sidebar_header(list, "Reference")
	_add_nav_button(list, "Glossary", ClassLibraryTheme.ACCENT_INGAME, _select_glossary)
	_add_nav_button(list, "Definitions", ClassLibraryTheme.ACCENT_IMPL, _select_definitions)
	_add_sidebar_header(list, "Player Classes")
	for unit: UnitData in DataLibrary.get_all_player_units():
		_add_unit_button(list, unit)
	_add_color_key(list)

	var detail_panel := PanelContainer.new()
	detail_panel.name = "DetailPanel"
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", ClassLibraryTheme.panel_style(ClassLibraryTheme.BG_CARD))
	split.add_child(detail_panel)
	var detail_pad := MarginContainer.new()
	detail_pad.add_theme_constant_override("margin_left", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_MD))
	detail_pad.add_theme_constant_override("margin_right", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_MD))
	detail_pad.add_theme_constant_override("margin_top", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_MD))
	detail_pad.add_theme_constant_override("margin_bottom", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_MD))
	detail_panel.add_child(detail_pad)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_pad.add_child(_detail_scroll)
	_detail_vbox = VBoxContainer.new()
	_detail_vbox.name = "DetailVBox"
	_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_vbox.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_LG))
	_detail_scroll.add_child(_detail_vbox)
	_detail_scroll.resized.connect(_sync_detail_width)
	_sync_detail_width()
	_update_scale_label()


func _sync_detail_width() -> void:
	if _detail_scroll != null and _detail_vbox != null:
		_detail_vbox.custom_minimum_size.x = maxf(ClassLibraryTheme.dim(720.0), _detail_scroll.size.x - ClassLibraryTheme.dim(8.0))


func _add_scale_controls(parent: HBoxContainer) -> void:
	var sep := VSeparator.new()
	parent.add_child(sep)
	var scale_box := HBoxContainer.new()
	scale_box.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_XS))
	parent.add_child(scale_box)
	var scale_lbl := Label.new()
	scale_lbl.text = "UI"
	scale_lbl.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SMALL))
	scale_lbl.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_MUTED)
	scale_box.add_child(scale_lbl)
	var minus := Button.new()
	minus.text = "−"
	_style_toolbar_button(minus)
	minus.custom_minimum_size = Vector2(ClassLibraryTheme.px(28), ClassLibraryTheme.px(28))
	minus.pressed.connect(func() -> void: _bump_ui_scale(-ClassLibraryTheme.USER_SCALE_STEP))
	scale_box.add_child(minus)
	_scale_label = Label.new()
	_scale_label.custom_minimum_size.x = ClassLibraryTheme.px(44)
	_scale_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scale_label.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	_scale_label.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_PRIMARY)
	_scale_label.tooltip_text = "Double-click to reset to 100%"
	_scale_label.gui_input.connect(_on_scale_label_input)
	scale_box.add_child(_scale_label)
	var plus := Button.new()
	plus.text = "+"
	_style_toolbar_button(plus)
	plus.custom_minimum_size = Vector2(ClassLibraryTheme.px(28), ClassLibraryTheme.px(28))
	plus.pressed.connect(func() -> void: _bump_ui_scale(ClassLibraryTheme.USER_SCALE_STEP))
	scale_box.add_child(plus)
	_update_scale_label()


func _on_scale_label_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
		ClassLibraryTheme.set_user_scale(1.0)
		_update_scale_label()
		_rebuild_shell_layout()
		_persist_ui_scale()
		_refresh_current_view()


func _bump_ui_scale(delta: float) -> void:
	ClassLibraryTheme.set_user_scale(ClassLibraryTheme.user_scale() + delta)
	_update_scale_label()
	_rebuild_shell_layout()
	_persist_ui_scale()
	_refresh_current_view()


func _persist_ui_scale() -> void:
	var data: Dictionary = {"glossary": _glossary_overrides, "units": {}, "ui_scale": ClassLibraryTheme.user_scale()}
	if FileAccess.file_exists(SAVE_PATH):
		var existing: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if typeof(existing) == TYPE_DICTIONARY:
			data = existing
			data["ui_scale"] = ClassLibraryTheme.user_scale()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()


func _update_scale_label() -> void:
	if _scale_label != null:
		_scale_label.text = "%d%%" % int(round(ClassLibraryTheme.user_scale() * 100.0))


func _rebuild_shell_layout() -> void:
	if has_node("Title"):
		_style_hero_label($Title)
	if _sidebar_panel != null:
		_sidebar_panel.custom_minimum_size.x = ClassLibraryTheme.sidebar_width()
	if _toolbar_panel != null:
		_toolbar_panel.offset_left = ClassLibraryTheme.sidebar_width() + ClassLibraryTheme.px(48)
	if _detail_scroll != null:
		_sync_detail_width()


func _refresh_current_view() -> void:
	match _view_mode:
		ViewMode.GLOSSARY:
			_select_glossary()
		ViewMode.DEFINITIONS:
			_select_definitions()
		_:
			var unit: UnitData = DataLibrary.get_unit(_view_unit_id)
			if unit != null:
				_select_unit(unit)


func _add_color_key(parent: VBoxContainer) -> void:
	parent.add_child(Control.new()) # spacer
	var key_hdr := Label.new()
	key_hdr.text = "COLOR KEY"
	key_hdr.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SMALL))
	key_hdr.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_DIM)
	parent.add_child(key_hdr)
	for spec: Array in [
		[ClassLibraryTheme.ACCENT_INGAME, "Gold — in-game"],
		[ClassLibraryTheme.ACCENT_DATA, "Blue — data"],
		[ClassLibraryTheme.ACCENT_IMPL, "Teal — system"],
	]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_XS))
		parent.add_child(row)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(ClassLibraryTheme.px(8), ClassLibraryTheme.px(8))
		dot.color = spec[0]
		row.add_child(dot)
		var lbl := Label.new()
		lbl.text = spec[1]
		lbl.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SMALL))
		lbl.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_DIM)
		row.add_child(lbl)


# --- Styling helpers ---

func _style_hero_label(lbl: Label) -> void:
	lbl.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_HERO))
	lbl.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_PRIMARY)


func _style_toolbar_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", ClassLibraryTheme.toolbar_button_style())
	btn.add_theme_stylebox_override("hover", ClassLibraryTheme.panel_style(ClassLibraryTheme.BG_INSET, ClassLibraryTheme.ACCENT_DATA))
	btn.add_theme_stylebox_override("pressed", ClassLibraryTheme.panel_style(ClassLibraryTheme.BG_INSET, ClassLibraryTheme.ACCENT_DATA))
	btn.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_PRIMARY)
	btn.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))


func _style_sidebar_button(btn: Button, active: bool, accent: Color) -> void:
	if active:
		btn.add_theme_stylebox_override("normal", ClassLibraryTheme.sidebar_button_active(accent))
		btn.add_theme_stylebox_override("hover", ClassLibraryTheme.sidebar_button_active(accent))
		btn.add_theme_stylebox_override("pressed", ClassLibraryTheme.sidebar_button_active(accent))
		btn.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_PRIMARY)
	else:
		btn.add_theme_stylebox_override("normal", ClassLibraryTheme.sidebar_button_normal())
		btn.add_theme_stylebox_override("hover", ClassLibraryTheme.panel_style(ClassLibraryTheme.BG_INSET, ClassLibraryTheme.BORDER_SUBTLE))
		btn.add_theme_stylebox_override("pressed", ClassLibraryTheme.panel_style(ClassLibraryTheme.BG_INSET))
		btn.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_MUTED)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))


func _set_active_sidebar(btn: Button, accent: Color) -> void:
	if _active_sidebar_btn != null and is_instance_valid(_active_sidebar_btn):
		var old_accent: Color = _active_sidebar_btn.get_meta("nav_accent", ClassLibraryTheme.ACCENT_NEUTRAL)
		_style_sidebar_button(_active_sidebar_btn, false, old_accent)
	_active_sidebar_btn = btn
	btn.set_meta("nav_accent", accent)
	_style_sidebar_button(btn, true, accent)


func _field_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = ClassLibraryTheme.label_col_width()
	l.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	l.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_MUTED)
	return l


func _section_card(title: String, accent: Color, col: ClassLibraryTheme.Column = ClassLibraryTheme.Column.NEUTRAL) -> VBoxContainer:
	var wrap := PanelContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_stylebox_override("panel", ClassLibraryTheme.column_style(col))
	_detail_vbox.add_child(wrap)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	wrap.add_child(inner)
	var hdr := PanelContainer.new()
	hdr.add_theme_stylebox_override("panel", ClassLibraryTheme.section_header_bar(accent))
	inner.add_child(hdr)
	var hdr_lbl := Label.new()
	hdr_lbl.text = title.to_upper()
	hdr_lbl.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SECTION))
	hdr_lbl.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_PRIMARY)
	hdr.add_child(hdr_lbl)
	return inner


func _column_shell(title: String, col: ClassLibraryTheme.Column, stretch: float) -> VBoxContainer:
	var outer := PanelContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_stretch_ratio = stretch
	outer.add_theme_stylebox_override("panel", ClassLibraryTheme.column_style(col))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	outer.add_child(box)
	var accent: Color = ClassLibraryTheme.accent_for_column(col)
	var hdr := Label.new()
	hdr.text = title
	hdr.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SUBSECTION))
	hdr.add_theme_color_override("font_color", accent)
	box.add_child(hdr)
	box.set_meta("column_root", outer)
	return box


# --- Sidebar ---

func _add_sidebar_header(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text.to_upper()
	lbl.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SMALL))
	lbl.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_DIM)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(lbl)


func _add_nav_button(parent: Control, text: String, accent: Color, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.flat = true
	_style_sidebar_button(btn, false, accent)
	btn.pressed.connect(func() -> void:
		_set_active_sidebar(btn, accent)
		callback.call()
	)
	btn.set_meta("nav_accent", accent)
	parent.add_child(btn)
	_nav_buttons.append(btn)


func _add_unit_button(parent: Control, unit: UnitData) -> void:
	var btn := Button.new()
	btn.text = unit.display_name
	btn.flat = true
	_style_sidebar_button(btn, false, ClassLibraryTheme.ACCENT_STATS)
	btn.pressed.connect(func() -> void:
		_set_active_sidebar(btn, ClassLibraryTheme.ACCENT_STATS)
		_select_unit(unit)
	)
	btn.set_meta("nav_accent", ClassLibraryTheme.ACCENT_STATS)
	parent.add_child(btn)
	_class_buttons[unit.id] = btn


func _clear_detail() -> void:
	_ability_ui.clear()
	if _detail_vbox == null:
		return
	for c: Node in _detail_vbox.get_children():
		c.queue_free()


func _select_unit(unit: UnitData) -> void:
	_selected_unit = unit
	_view_mode = ViewMode.UNIT
	_view_unit_id = unit.id
	if _class_buttons.has(unit.id):
		_set_active_sidebar(_class_buttons[unit.id], ClassLibraryTheme.ACCENT_STATS)
	_clear_detail()
	_add_page_header(unit.display_name, "ID: %s" % String(unit.id), ClassLibraryTheme.ACCENT_STATS)
	_build_stats_section(unit)
	_build_weapon_section(unit)
	_build_passives_section(unit)
	_build_abilities_section(unit)


func _add_page_header(title: String, subtitle: String, accent: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_MD))
	_detail_vbox.add_child(row)
	var accent_bar := ColorRect.new()
	accent_bar.custom_minimum_size = Vector2(ClassLibraryTheme.px(4), ClassLibraryTheme.px(56))
	accent_bar.color = accent
	row.add_child(accent_bar)
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_HERO))
	t.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_PRIMARY)
	text_col.add_child(t)
	var s := Label.new()
	s.text = subtitle
	s.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	s.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_MUTED)
	text_col.add_child(s)


# --- Class sections ---

func _build_stats_section(unit: UnitData) -> void:
	var section := _section_card("Stats", ClassLibraryTheme.ACCENT_STATS, ClassLibraryTheme.Column.STATS)
	var hp_lbl := Label.new()
	hp_lbl.text = "Max HP: %d" % (unit.base_constitution * 5)
	hp_lbl.add_theme_color_override("font_color", ClassLibraryTheme.ACCENT_STATS)
	hp_lbl.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	var row_move := _stat_row(section, "Movement", ClassLibraryTheme.ACCENT_DATA)
	_bind_int(row_move, "Level", unit.level, func(v: int) -> void: unit.level = v)
	_bind_int(row_move, "CON", unit.base_constitution, func(v: int) -> void:
		unit.base_constitution = v
		hp_lbl.text = "Max HP: %d" % (v * 5)
	)
	_bind_int(row_move, "MOV", unit.move_points, func(v: int) -> void: unit.move_points = v)
	_bind_int(row_move, "AP", unit.action_points, func(v: int) -> void: unit.action_points = v)
	row_move.add_child(hp_lbl)
	var row_combat := _stat_row(section, "Combat", ClassLibraryTheme.ACCENT_INGAME)
	_bind_int(row_combat, "STR", unit.base_strength, func(v: int) -> void: unit.base_strength = v)
	_bind_int(row_combat, "MAG", unit.base_magic, func(v: int) -> void: unit.base_magic = v)
	_bind_int(row_combat, "DEF", unit.base_defense, func(v: int) -> void: unit.base_defense = v)
	var row_growth := _stat_row(section, "Growth", ClassLibraryTheme.ACCENT_IMPL)
	_bind_enum(row_growth, "Preferred", GameEnums.StatType, unit.preferred_stat, func(v: int) -> void: unit.preferred_stat = v)
	_bind_enum(row_growth, "Move Type", GameEnums.MovementType, unit.movement_type, func(v: int) -> void: unit.movement_type = v)


func _stat_row(parent: VBoxContainer, title: String, accent: Color) -> GridContainer:
	_add_subsection_label(parent, title, accent)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_MD))
	grid.add_theme_constant_override("v_separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_XS))
	parent.add_child(grid)
	return grid


func _build_weapon_section(unit: UnitData) -> void:
	var section := _section_card("Equipment", ClassLibraryTheme.ACCENT_NEUTRAL)
	if unit.equipped_weapon == null:
		var none := Label.new()
		none.text = "No weapon equipped."
		none.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_MUTED)
		section.add_child(none)
		return
	var wpn := unit.equipped_weapon
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_MD))
	grid.add_theme_constant_override("v_separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	section.add_child(grid)
	_bind_string(grid, "Weapon", wpn.display_name, func(v: String) -> void: wpn.display_name = v)
	_bind_int(grid, "STR +", wpn.bonus_strength, func(v: int) -> void: wpn.bonus_strength = v)
	_bind_int(grid, "MAG +", wpn.bonus_magic, func(v: int) -> void: wpn.bonus_magic = v)
	_bind_int(grid, "DEF +", wpn.bonus_defense, func(v: int) -> void: wpn.bonus_defense = v)
	_bind_int(grid, "HP +", wpn.bonus_max_hp, func(v: int) -> void: wpn.bonus_max_hp = v)
	_bind_int(grid, "MOV +", wpn.bonus_move, func(v: int) -> void: wpn.bonus_move = v)


func _build_passives_section(unit: UnitData) -> void:
	var section := _section_card("Passives", ClassLibraryTheme.ACCENT_PASSIVE, ClassLibraryTheme.Column.PASSIVE)
	if unit.passives.is_empty():
		var none := Label.new()
		none.text = "None"
		none.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_MUTED)
		section.add_child(none)
		return
	for passive: PassiveData in unit.passives:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", ClassLibraryTheme.panel_style(
			ClassLibraryTheme.BG_INSET, ClassLibraryTheme.ACCENT_PASSIVE, 1, 4, ClassLibraryTheme.SPACE_SM
		))
		section.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
		card.add_child(box)
		var head := HBoxContainer.new()
		box.add_child(head)
		var name_lbl := Label.new()
		name_lbl.text = passive.display_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_TITLE))
		name_lbl.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_PRIMARY)
		head.add_child(name_lbl)
		var id_lbl := Label.new()
		id_lbl.text = String(passive.id)
		id_lbl.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SMALL))
		id_lbl.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_DIM)
		head.add_child(id_lbl)
		var preview_wrap := PanelContainer.new()
		preview_wrap.add_theme_stylebox_override("panel", ClassLibraryTheme.column_style(ClassLibraryTheme.Column.INGAME))
		box.add_child(preview_wrap)
		var preview := RichTextLabel.new()
		preview.bbcode_enabled = true
		preview.fit_content = true
		preview.scroll_active = true
		preview.custom_minimum_size = Vector2(0, ClassLibraryTheme.px(72))
		preview_wrap.add_child(preview)
		var edits := VBoxContainer.new()
		edits.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_XS))
		box.add_child(edits)
		var name_row := GridContainer.new()
		name_row.columns = 2
		edits.add_child(name_row)
		_bind_string(name_row, "Name", passive.display_name, func(v: String) -> void:
			passive.display_name = v
			name_lbl.text = v
		)
		var desc_edit := _bind_multiline(edits, "Description", passive.description, func(v: String) -> void:
			passive.description = v
			_refresh_passive_preview(passive, preview)
		)
		desc_edit.custom_minimum_size = Vector2(0, ClassLibraryTheme.px(64))
		_bind_multiline(edits, "Upgraded", passive.upgraded_description, func(v: String) -> void:
			passive.upgraded_description = v
			_refresh_passive_preview(passive, preview)
		)
		desc_edit.text_changed.connect(func(_t: String) -> void: _refresh_passive_preview(passive, preview))
		_refresh_passive_preview(passive, preview)


func _refresh_passive_preview(passive: PassiveData, preview: RichTextLabel) -> void:
	preview.text = ClassLibrarySchema.passive_preview_bbcode(passive)


func _build_abilities_section(unit: UnitData) -> void:
	var section := _section_card("Skills & Abilities", ClassLibraryTheme.ACCENT_DATA)
	for ability: AbilityData in unit.abilities:
		_build_ability_row(section, ability)


func _build_ability_row(parent: VBoxContainer, ability: AbilityData) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", ClassLibraryTheme.panel_style(ClassLibraryTheme.BG_INSET, ClassLibraryTheme.BORDER_SUBTLE, 1, 6, ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM)))
	parent.add_child(card)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	card.add_child(outer)
	var name_row := PanelContainer.new()
	name_row.add_theme_stylebox_override("panel", ClassLibraryTheme.section_header_bar(ClassLibraryTheme.ACCENT_DATA))
	outer.add_child(name_row)
	var name_inner := HBoxContainer.new()
	name_inner.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	name_row.add_child(name_inner)
	var name_edit := LineEdit.new()
	name_edit.text = ability.display_name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_TITLE))
	name_edit.text_changed.connect(func(t: String) -> void:
		ability.display_name = t
		_refresh_ability_ui(ability)
	)
	name_inner.add_child(name_edit)
	var id_badge := Label.new()
	id_badge.text = String(ability.id)
	id_badge.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SMALL))
	id_badge.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_DIM)
	name_inner.add_child(id_badge)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	outer.add_child(cols)

	var col_game := _column_shell("In-Game Preview", ClassLibraryTheme.Column.INGAME, 0.30)
	cols.add_child(col_game.get_meta("column_root"))
	var preview := RichTextLabel.new()
	preview.bbcode_enabled = true
	preview.fit_content = true
	preview.scroll_active = true
	preview.custom_minimum_size = Vector2(0, ClassLibraryTheme.px(100))
	col_game.add_child(preview)

	var col_data := _column_shell("Ability Data", ClassLibraryTheme.Column.DATA, 0.38)
	cols.add_child(col_data.get_meta("column_root"))
	var data_scroll := ScrollContainer.new()
	data_scroll.custom_minimum_size = Vector2(0, ClassLibraryTheme.px(240))
	data_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_data.add_child(data_scroll)
	var data_vbox := VBoxContainer.new()
	data_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	data_scroll.add_child(data_vbox)
	_populate_ability_data_editor(data_vbox, ability)

	var col_impl := _column_shell("How It Works", ClassLibraryTheme.Column.IMPL, 0.32)
	cols.add_child(col_impl.get_meta("column_root"))
	var impl_scroll := ScrollContainer.new()
	impl_scroll.custom_minimum_size = Vector2(0, ClassLibraryTheme.px(240))
	col_impl.add_child(impl_scroll)
	var impl_vbox := VBoxContainer.new()
	impl_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	impl_scroll.add_child(impl_vbox)
	var impl_lbl := Label.new()
	impl_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	impl_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	impl_lbl.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	impl_lbl.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_SECONDARY)
	impl_vbox.add_child(impl_lbl)
	var dump_hdr := Label.new()
	dump_hdr.text = "RAW DATA"
	dump_hdr.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SMALL))
	dump_hdr.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_DIM)
	impl_vbox.add_child(dump_hdr)
	var dump_lbl := Label.new()
	dump_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dump_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dump_lbl.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_MONO))
	dump_lbl.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_DIM)
	impl_vbox.add_child(dump_lbl)

	_ability_ui[ability] = {"preview": preview, "impl": impl_lbl, "dump": dump_lbl}
	_refresh_ability_ui(ability)


func _populate_ability_data_editor(parent: VBoxContainer, ability: AbilityData) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	grid.add_theme_constant_override("v_separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_XS))
	parent.add_child(grid)
	_bind_enum(grid, "kind", GameEnums.AbilityKind, ability.kind, func(v: int) -> void:
		ability.kind = v
		ability.is_movement_skill = v == GameEnums.AbilityKind.MOVEMENT_SKILL
		_refresh_ability_ui(ability)
	)
	_bind_bool(grid, "movement_skill", ability.is_movement_skill, func(v: bool) -> void:
		ability.is_movement_skill = v
		if v:
			ability.kind = GameEnums.AbilityKind.MOVEMENT_SKILL
		_refresh_ability_ui(ability)
	)
	_bind_int(grid, "AP", ability.action_point_cost, func(v: int) -> void:
		ability.action_point_cost = v
		_refresh_ability_ui(ability)
	)
	_bind_int(grid, "MP", ability.movement_point_cost, func(v: int) -> void:
		ability.movement_point_cost = v
		_refresh_ability_ui(ability)
	)
	_bind_int(grid, "Range", ability.range_tiles, func(v: int) -> void:
		ability.range_tiles = v
		_refresh_ability_ui(ability)
	)
	_bind_enum(grid, "Targeting", GameEnums.TargetingMode, ability.targeting_mode, func(v: int) -> void:
		ability.targeting_mode = v
		_refresh_ability_ui(ability)
	)
	_bind_bool(grid, "Target Self", ability.can_target_self, func(v: bool) -> void:
		ability.can_target_self = v
		_refresh_ability_ui(ability)
	)
	_bind_enum(grid, "Shape", GameEnums.TargetShape, ability.target_shape, func(v: int) -> void:
		ability.target_shape = v
		_refresh_ability_ui(ability)
	)
	_bind_int(grid, "Shape Size", ability.target_shape_size, func(v: int) -> void:
		ability.target_shape_size = v
		_refresh_ability_ui(ability)
	)
	_bind_enum(grid, "Scaling", GameEnums.StatType, ability.scaling_stat, func(v: int) -> void:
		ability.scaling_stat = v
		_refresh_ability_ui(ability)
	)
	_bind_int(grid, "Uses/Combat", ability.uses_per_combat, func(v: int) -> void: ability.uses_per_combat = v)
	_bind_string(grid, "Present Key", String(ability.presentation_key), func(v: String) -> void:
		ability.presentation_key = StringName(v)
	)
	_bind_enum(grid, "Present Anim", GameEnums.PresentationAnim, ability.presentation_anim, func(v: int) -> void:
		ability.presentation_anim = v
	)
	_bind_int(grid, "Upg Range", ability.upgraded_range_tiles, func(v: int) -> void:
		ability.upgraded_range_tiles = v
		_refresh_ability_ui(ability)
	)
	_bind_enum(grid, "Upg Shape", GameEnums.TargetShape, ability.upgraded_target_shape, func(v: int) -> void:
		ability.upgraded_target_shape = v
		_refresh_ability_ui(ability)
	)
	_bind_int(grid, "Upg Size", ability.upgraded_target_shape_size, func(v: int) -> void:
		ability.upgraded_target_shape_size = v
		_refresh_ability_ui(ability)
	)
	_bind_multiline(parent, "Upgrade Text", ability.upgrade_description, func(v: String) -> void:
		ability.upgrade_description = v
	)
	_add_subsection_label(parent, "Effects", ClassLibraryTheme.ACCENT_DATA)
	var eff_box := VBoxContainer.new()
	eff_box.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_XS))
	parent.add_child(eff_box)
	_rebuild_effects_editor(eff_box, ability, ability.effects, false)
	var add_eff := Button.new()
	add_eff.text = "+ Effect"
	_style_toolbar_button(add_eff)
	add_eff.pressed.connect(func() -> void:
		var e := EffectData.new()
		e.type = GameEnums.EffectType.DAMAGE
		e.amount = 1
		ability.effects.append(e)
		_rebuild_effects_editor(eff_box, ability, ability.effects, false)
		_refresh_ability_ui(ability)
	)
	parent.add_child(add_eff)
	_add_subsection_label(parent, "Upgraded Effects", ClassLibraryTheme.ACCENT_INGAME)
	var up_box := VBoxContainer.new()
	parent.add_child(up_box)
	_rebuild_effects_editor(up_box, ability, ability.upgraded_effects, true)
	var add_up := Button.new()
	add_up.text = "+ Upgraded Effect"
	_style_toolbar_button(add_up)
	add_up.pressed.connect(func() -> void:
		ability.upgraded_effects.append(EffectData.new())
		_rebuild_effects_editor(up_box, ability, ability.upgraded_effects, true)
		_refresh_ability_ui(ability)
	)
	parent.add_child(add_up)


func _rebuild_effects_editor(parent: VBoxContainer, ability: AbilityData, effects: Array[EffectData], upgraded: bool) -> void:
	for c: Node in parent.get_children():
		c.queue_free()
	var accent: Color = ClassLibraryTheme.ACCENT_INGAME if upgraded else ClassLibraryTheme.ACCENT_DATA
	for i: int in effects.size():
		var eff: EffectData = effects[i]
		var eff_panel := PanelContainer.new()
		eff_panel.add_theme_stylebox_override("panel", ClassLibraryTheme.panel_style(ClassLibraryTheme.BG_BASE, accent, 1, 4, ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM)))
		parent.add_child(eff_panel)
		var ev := VBoxContainer.new()
		eff_panel.add_child(ev)
		var row := HBoxContainer.new()
		ev.add_child(row)
		var idx_lbl := Label.new()
		idx_lbl.text = "Effect %d" % i
		idx_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		idx_lbl.add_theme_color_override("font_color", accent)
		row.add_child(idx_lbl)
		var rm := Button.new()
		rm.text = "×"
		_style_toolbar_button(rm)
		rm.pressed.connect(func() -> void:
			var pos: int = effects.find(eff)
			if pos >= 0:
				effects.remove_at(pos)
			_rebuild_effects_editor(parent, ability, effects, upgraded)
			_refresh_ability_ui(ability)
		)
		row.add_child(rm)
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("v_separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_XS))
		ev.add_child(g)
		_bind_enum(g, "Type", GameEnums.EffectType, eff.type, func(v: int) -> void:
			eff.type = v
			_refresh_ability_ui(ability)
		)
		_bind_int(g, "Amount", eff.amount, func(v: int) -> void:
			eff.amount = v
			_refresh_ability_ui(ability)
		)
		_bind_enum(g, "Scale Stat", GameEnums.StatType, eff.scaling_stat, func(v: int) -> void:
			eff.scaling_stat = v
			_refresh_ability_ui(ability)
		)
		_bind_enum(g, "Status", GameEnums.StatusType, eff.status_type, func(v: int) -> void:
			eff.status_type = v
			_refresh_ability_ui(ability)
		)
		_bind_int(g, "Duration", eff.status_duration, func(v: int) -> void:
			eff.status_duration = v
			_refresh_ability_ui(ability)
		)
		_bind_int(g, "Adj Bonus", eff.bonus_if_adjacent_at_cast, func(v: int) -> void:
			eff.bonus_if_adjacent_at_cast = v
			_refresh_ability_ui(ability)
		)
		_bind_int(g, "DEF Debuff", eff.def_debuff_before_damage, func(v: int) -> void:
			eff.def_debuff_before_damage = v
			_refresh_ability_ui(ability)
		)
		_bind_string(g, "Spawn ID", String(eff.spawn_unit_id), func(v: String) -> void:
			eff.spawn_unit_id = StringName(v)
		)


func _refresh_ability_ui(ability: AbilityData) -> void:
	if not _ability_ui.has(ability):
		return
	var refs: Dictionary = _ability_ui[ability]
	refs["preview"].text = ClassLibrarySchema.in_game_ability_bbcode(ability)
	refs["impl"].text = ClassLibrarySchema.ability_implementation_notes(ability)
	refs["dump"].text = ClassLibrarySchema.ability_data_dump(ability)


# --- Reference pages ---

func _select_glossary() -> void:
	_selected_unit = null
	_view_mode = ViewMode.GLOSSARY
	_clear_detail()
	_add_page_header("Glossary", "Player-facing tooltips vs system definitions", ClassLibraryTheme.ACCENT_INGAME)
	_add_glossary_table_header()
	var manual: Dictionary = ClassLibrarySchema.manual_keywords()
	var keys: Array = manual.keys()
	keys.sort()
	for kw: String in keys:
		_add_glossary_row(kw, _glossary_tooltip(kw, manual[kw]), _glossary_system(kw, manual[kw]), false)
	_add_subsection_label(_detail_vbox, "Status Effects", ClassLibraryTheme.ACCENT_IMPL)
	var status_defs: Dictionary = {}
	for def_entry: Dictionary in ClassLibrarySchema.enum_definitions():
		if def_entry.get("category") == "StatusType":
			status_defs[def_entry.get("name")] = def_entry
	for k: String in GameEnums.StatusType.keys():
		var st: GameEnums.StatusType = GameEnums.StatusType[k]
		var display_name: String = CombatUiFormatters._status_name(st)
		var tooltip: String = CombatUiFormatters._status_desc(st)
		var sys_text: String = ""
		if status_defs.has(k):
			sys_text = String(status_defs[k].get("system", ""))
		_add_glossary_row(display_name, tooltip, sys_text, true)


func _add_glossary_table_header() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	_detail_vbox.add_child(row)
	for spec: Array in [
		["Keyword", 140, ClassLibraryTheme.TEXT_MUTED],
		["Game Tooltip", 1.0, ClassLibraryTheme.ACCENT_INGAME],
		["System Definition", 1.0, ClassLibraryTheme.ACCENT_IMPL],
	]:
		var hdr := Label.new()
		hdr.text = spec[0]
		hdr.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SMALL))
		hdr.add_theme_color_override("font_color", spec[2])
		if spec[1] is float:
			hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hdr.size_flags_stretch_ratio = spec[1]
		else:
			hdr.custom_minimum_size.x = spec[1]
		row.add_child(hdr)


func _glossary_tooltip(kw: String, default_val: String) -> String:
	if _glossary_overrides.has(kw) and _glossary_overrides[kw].has("tooltip"):
		return _glossary_overrides[kw]["tooltip"]
	return default_val


func _glossary_system(kw: String, default_val: String) -> String:
	if _glossary_overrides.has(kw) and _glossary_overrides[kw].has("system"):
		return _glossary_overrides[kw]["system"]
	return default_val


func _add_glossary_row(keyword: String, tooltip_default: String, system_default: String, is_status: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	_detail_vbox.add_child(row)
	var kw_wrap := PanelContainer.new()
	kw_wrap.custom_minimum_size.x = ClassLibraryTheme.dim(140.0)
	kw_wrap.add_theme_stylebox_override("panel", ClassLibraryTheme.panel_style(ClassLibraryTheme.BG_INSET, ClassLibraryTheme.ACCENT_NEUTRAL, 1, 4, ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM)))
	row.add_child(kw_wrap)
	var kw_lbl := Label.new()
	kw_lbl.text = keyword
	kw_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kw_lbl.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	kw_lbl.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_PRIMARY)
	kw_wrap.add_child(kw_lbl)
	var tip_wrap := PanelContainer.new()
	tip_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_wrap.size_flags_stretch_ratio = 1.0
	tip_wrap.add_theme_stylebox_override("panel", ClassLibraryTheme.column_style(
		ClassLibraryTheme.Column.GLOSSARY_GAME if not is_status else ClassLibraryTheme.Column.INGAME
	))
	row.add_child(tip_wrap)
	var tip_edit := TextEdit.new()
	tip_edit.text = tooltip_default
	tip_edit.custom_minimum_size.y = ClassLibraryTheme.dim(56.0)
	tip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_edit.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	tip_edit.text_changed.connect(func() -> void:
		if not _glossary_overrides.has(keyword):
			_glossary_overrides[keyword] = {}
		_glossary_overrides[keyword]["tooltip"] = tip_edit.text
	)
	tip_wrap.add_child(tip_edit)
	var sys_wrap := PanelContainer.new()
	sys_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sys_wrap.size_flags_stretch_ratio = 1.0
	sys_wrap.add_theme_stylebox_override("panel", ClassLibraryTheme.column_style(ClassLibraryTheme.Column.GLOSSARY_SYS))
	row.add_child(sys_wrap)
	var sys_edit := TextEdit.new()
	sys_edit.text = system_default
	sys_edit.custom_minimum_size.y = ClassLibraryTheme.dim(56.0)
	sys_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sys_edit.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	sys_edit.text_changed.connect(func() -> void:
		if not _glossary_overrides.has(keyword):
			_glossary_overrides[keyword] = {}
		_glossary_overrides[keyword]["system"] = sys_edit.text
	)
	sys_wrap.add_child(sys_edit)


func _select_definitions() -> void:
	_selected_unit = null
	_view_mode = ViewMode.DEFINITIONS
	_clear_detail()
	_add_page_header("Definitions", "Enums and keywords used by the ability system", ClassLibraryTheme.ACCENT_IMPL)
	var grouped: Dictionary = {}
	for entry: Dictionary in ClassLibrarySchema.enum_definitions():
		var cat: String = String(entry.get("category", ""))
		if not grouped.has(cat):
			grouped[cat] = []
		(grouped[cat] as Array).append(entry)
	var cats: Array = grouped.keys()
	cats.sort()
	for cat: String in cats:
		_add_subsection_label(_detail_vbox, cat, _category_color(cat))
		_add_definitions_table_header()
		var row_i := 0
		for entry: Dictionary in grouped[cat]:
			_add_definition_row(entry, row_i)
			row_i += 1


func _add_definitions_table_header() -> void:
	var header_row := PanelContainer.new()
	header_row.add_theme_stylebox_override("panel", ClassLibraryTheme.panel_style(
		ClassLibraryTheme.BG_INSET, ClassLibraryTheme.BORDER_SUBTLE, 1, 0, ClassLibraryTheme.SPACE_SM
	))
	_detail_vbox.add_child(header_row)
	var header_inner := HBoxContainer.new()
	header_row.add_child(header_inner)
	for spec: Array in [
		["Name", 0.28, ClassLibraryTheme.ACCENT_DATA],
		["Game Tooltip", 0.36, ClassLibraryTheme.ACCENT_INGAME],
		["System", 0.36, ClassLibraryTheme.TEXT_SECONDARY],
	]:
		var h := Label.new()
		h.text = spec[0]
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.size_flags_stretch_ratio = spec[1]
		h.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SMALL))
		h.add_theme_color_override("font_color", spec[2])
		header_inner.add_child(h)


func _add_definition_row(entry: Dictionary, row_i: int) -> void:
	var row_panel := PanelContainer.new()
	row_panel.add_theme_stylebox_override("panel", ClassLibraryTheme.panel_style(
		ClassLibraryTheme.BG_INSET if row_i % 2 == 0 else ClassLibraryTheme.BG_CARD,
		ClassLibraryTheme.BORDER_SUBTLE, 1, 0, ClassLibraryTheme.SPACE_SM,
	))
	_detail_vbox.add_child(row_panel)
	var row := HBoxContainer.new()
	row_panel.add_child(row)
	for spec: Array in [
		["name", 0.28, ClassLibraryTheme.ACCENT_DATA],
		["tooltip", 0.36, ClassLibraryTheme.TEXT_SECONDARY],
		["system", 0.36, ClassLibraryTheme.TEXT_MUTED],
	]:
		var l := Label.new()
		l.text = String(entry.get(spec[0], ""))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_stretch_ratio = spec[1]
		l.add_theme_color_override("font_color", spec[2])
		l.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
		row.add_child(l)


func _category_color(category: String) -> Color:
	match category:
		"AbilityKind":
			return ClassLibraryTheme.ACCENT_DATA
		"TargetingMode":
			return ClassLibraryTheme.ACCENT_IMPL
		"EffectType":
			return ClassLibraryTheme.ACCENT_INGAME
		"StatusType":
			return ClassLibraryTheme.ACCENT_PASSIVE
		"TargetShape":
			return ClassLibraryTheme.ACCENT_STATS
		_:
			return ClassLibraryTheme.ACCENT_NEUTRAL


func _add_subsection_label(parent: Control, text: String, accent: Color) -> void:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SUBSECTION))
	l.add_theme_color_override("font_color", accent)
	parent.add_child(l)


# --- Widget bindings ---

func _bind_int(parent: GridContainer, label: String, value: int, setter: Callable) -> void:
	parent.add_child(_field_label(label))
	var spin := SpinBox.new()
	spin.min_value = -999
	spin.max_value = 9999
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	spin.value_changed.connect(func(v: float) -> void: setter.call(int(v)))
	parent.add_child(spin)


func _bind_bool(parent: GridContainer, label: String, value: bool, setter: Callable) -> void:
	parent.add_child(_field_label(label))
	var chk := CheckBox.new()
	chk.button_pressed = value
	chk.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	chk.toggled.connect(func(v: bool) -> void: setter.call(v))
	parent.add_child(chk)


func _bind_string(parent: GridContainer, label: String, value: String, setter: Callable) -> void:
	parent.add_child(_field_label(label))
	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	edit.text_changed.connect(func(t: String) -> void: setter.call(t))
	parent.add_child(edit)


func _bind_string_stacked(parent: VBoxContainer, label: String, value: String, setter: Callable) -> void:
	parent.add_child(_field_label(label))
	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(t: String) -> void: setter.call(t))
	parent.add_child(edit)


func _bind_enum(parent: GridContainer, label: String, enum_obj: Variant, current: int, setter: Callable) -> void:
	parent.add_child(_field_label(label))
	var opt := OptionButton.new()
	var keys: PackedStringArray = enum_obj.keys()
	for i: int in keys.size():
		opt.add_item(keys[i], i)
	opt.selected = current
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.item_selected.connect(func(idx: int) -> void: setter.call(idx))
	parent.add_child(opt)


func _bind_multiline(parent: Control, label: String, value: String, setter: Callable) -> TextEdit:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(wrap)
	wrap.add_child(_field_label(label))
	var edit := TextEdit.new()
	edit.text = value
	edit.custom_minimum_size = Vector2(0, ClassLibraryTheme.px(64))
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	edit.text_changed.connect(func() -> void: setter.call(edit.text))
	wrap.add_child(edit)
	return edit


func _save_overrides() -> void:
	var data: Dictionary = {
		"glossary": _glossary_overrides,
		"units": {},
		"ui_scale": ClassLibraryTheme.user_scale(),
	}
	if _selected_unit != null:
		data["last_unit"] = String(_selected_unit.id)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
		if _save_status != null:
			_save_status.text = "Saved"
			_save_status.add_theme_color_override("font_color", ClassLibraryTheme.ACCENT_SUCCESS)
	else:
		if _save_status != null:
			_save_status.text = "Save failed"
			_save_status.add_theme_color_override("font_color", ClassLibraryTheme.ACCENT_DANGER)


func _load_overrides() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_glossary_overrides = parsed.get("glossary", {})
	ClassLibraryTheme.set_user_scale(float(parsed.get("ui_scale", 1.0)))


func _reload_factories() -> void:
	if _selected_unit != null:
		_restore_unit_id = _selected_unit.id
	DataLibrary.reset_cache()
	get_tree().reload_current_scene()
