class_name ClassLibraryEditorScreen
extends Control

const PREVIEW_VIEWPORT_SIZE: Vector2i = Vector2i(1280, 720)

static var _restore_unit_id: StringName = &""

enum FieldTrackState { MATCHES_FACTORY, SAVED_OVERRIDE, UNSAVED_EDIT }
enum ViewMode { UNIT, GLOSSARY, DEFINITIONS }


var _selected_unit: UnitData
var _view_mode: ViewMode = ViewMode.UNIT
var _view_unit_id: StringName = &""
var _detail_vbox: VBoxContainer
var _detail_scroll: ScrollContainer
var _unit_workspace: Control
var _skills_workspace: Control
var _class_workspace: Control
var _unit_tab: int = 0
var _tab_btn_skills: Button
var _tab_btn_class: Button
var _unit_split: HSplitContainer
var _main_split: HSplitContainer
var _editor_split: HSplitContainer
var _class_split: HSplitContainer
var _list_scroll: ScrollContainer
var _list_vbox: VBoxContainer
var _data_scroll: ScrollContainer
var _data_vbox: VBoxContainer
var _impl_scroll: ScrollContainer
var _impl_vbox: VBoxContainer
var _class_list_scroll: ScrollContainer
var _class_list_vbox: VBoxContainer
var _class_stats_panel: PanelContainer
var _class_stats_vbox: VBoxContainer
var _class_passive_data_scroll: ScrollContainer
var _class_passive_data_vbox: VBoxContainer
var _class_passive_impl_scroll: ScrollContainer
var _class_passive_impl_vbox: VBoxContainer
var _selected_passive: PassiveData
var _selected_ability: AbilityData
var _unit_tab_group: ButtonGroup
var _active_list_key: String = ""
var _active_class_list_key: String = ""
var _list_item_cards: Dictionary = {}
var _class_list_item_cards: Dictionary = {}
var _save_status: Label
var _scale_label: Label
var _sidebar_panel: PanelContainer
var _toolbar_panel: PanelContainer
var _ability_ui: Dictionary = {}
var _passive_ui: Dictionary = {}
var _glossary_overrides: Dictionary = {}
var _class_buttons: Dictionary = {}
var _nav_buttons: Array[Button] = []
var _active_sidebar_btn: Button = null
var _factory_abilities: Dictionary = {}
var _saved_abilities: Dictionary = {}
var _field_tracks: Dictionary = {}
var _preview_unit_state: UnitState
var _preview_panel: PanelContainer
var _preview_viewport: SubViewport
var _preview_scene: Node2D
var _preview_refresh_btn: Button
var _preview_restart_btn: Button
var _preview_toggle_btn: Button
var _preview_visible: bool = true


func _ready() -> void:
	if has_node("ColorRect"):
		$ColorRect.color = ClassLibraryTheme.BG_BASE
	if has_node("Title"):
		_style_hero_label($Title)
	if has_node("BackButton"):
		_style_toolbar_button($BackButton)
	$BackButton.pressed.connect(_on_back_pressed)
	if MenuNavigation:
		MenuNavigation.register(self, _on_back_pressed, _preview_allows_back)
	_load_overrides()
	_build_layout()
	ClassLibrarySchema.apply_saved_unit_overrides()
	DataLibrary.get_all_player_units()
	_factory_abilities = ClassLibrarySchema.snapshot_factory_abilities()
	_saved_abilities = ClassLibrarySchema.snapshot_ability_map_from_units(DataLibrary.get_all_player_units())
	var units: Array[UnitData] = DataLibrary.get_all_player_units()
	var pick: UnitData = null
	if _restore_unit_id != &"":
		pick = DataLibrary.get_unit(_restore_unit_id)
		_restore_unit_id = &""
	if pick == null and not units.is_empty():
		pick = units[0]
	if pick != null:
		_select_unit(pick)
		call_deferred("_refresh_preview")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


## Guard for MenuNavigation: allow back only when the mouse is outside the preview panel.
## Returns false when hovering the preview so the right-click propagates to the
## SubViewport's _unhandled_input, where TacticalInputController cancels the action.
func _preview_allows_back() -> bool:
	if _preview_panel == null or not _preview_panel.visible:
		return true
	return not _preview_panel.get_global_rect().has_point(get_viewport().get_mouse_position())


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
	hint.text = "Live edits · Save persists skills & glossary · Reset Factories = code defaults"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SMALL))
	hint.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_MUTED)
	top_bar.add_child(hint)
	var sep := VSeparator.new()
	top_bar.add_child(sep)
	_preview_toggle_btn = Button.new()
	_preview_toggle_btn.text = "Hide Preview"
	_style_toolbar_button(_preview_toggle_btn)
	_preview_toggle_btn.pressed.connect(_toggle_preview)
	top_bar.add_child(_preview_toggle_btn)
	_preview_refresh_btn = Button.new()
	_preview_refresh_btn.text = "Refresh"
	_style_toolbar_button(_preview_refresh_btn)
	_preview_refresh_btn.pressed.connect(_refresh_preview)
	top_bar.add_child(_preview_refresh_btn)
	_preview_restart_btn = Button.new()
	_preview_restart_btn.text = "Restart Battle"
	_style_toolbar_button(_preview_restart_btn)
	_preview_restart_btn.pressed.connect(_restart_preview)
	top_bar.add_child(_preview_restart_btn)

	var main_split := HSplitContainer.new()
	_main_split = main_split
	main_split.anchor_right = 1.0
	main_split.anchor_bottom = 1.0
	main_split.offset_top = 148.0
	main_split.offset_bottom = -16.0
	main_split.offset_left = 24.0
	main_split.offset_right = -24.0
	main_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_split)

	var sidebar := PanelContainer.new()
	_sidebar_panel = sidebar
	sidebar.custom_minimum_size = Vector2(ClassLibraryTheme.sidebar_width(), 0)
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_stylebox_override("panel", ClassLibraryTheme.panel_style(ClassLibraryTheme.BG_SIDEBAR))
	main_split.add_child(sidebar)
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

	var editor_split := HSplitContainer.new()
	_editor_split = editor_split
	editor_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_split.size_flags_stretch_ratio = 0.55
	editor_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_split.add_child(editor_split)

	var detail_panel := PanelContainer.new()
	detail_panel.name = "DetailPanel"
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", ClassLibraryTheme.panel_style(ClassLibraryTheme.BG_CARD))
	editor_split.add_child(detail_panel)
	var detail_pad := MarginContainer.new()
	detail_pad.add_theme_constant_override("margin_left", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_MD))
	detail_pad.add_theme_constant_override("margin_right", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_MD))
	detail_pad.add_theme_constant_override("margin_top", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_MD))
	detail_pad.add_theme_constant_override("margin_bottom", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_MD))
	detail_panel.add_child(detail_pad)

	_detail_scroll = ScrollContainer.new()
	_detail_scroll.name = "ReferenceScroll"
	_detail_scroll.visible = false
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_pad.add_child(_detail_scroll)
	_detail_vbox = VBoxContainer.new()
	_detail_vbox.name = "DetailVBox"
	_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_vbox.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_LG))
	_detail_scroll.add_child(_detail_vbox)
	_detail_scroll.resized.connect(_sync_detail_width)

	_unit_workspace = VBoxContainer.new()
	_unit_workspace.name = "UnitWorkspace"
	_unit_workspace.visible = true
	_unit_workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_unit_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_pad.add_child(_unit_workspace)

	_unit_tab_group = ButtonGroup.new()

	var tab_shell := PanelContainer.new()
	tab_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_shell.add_theme_stylebox_override(
		"panel",
		ClassLibraryTheme.panel_style(ClassLibraryTheme.BG_INSET, ClassLibraryTheme.BORDER_SUBTLE, 1, 4, ClassLibraryTheme.SPACE_SM),
	)
	_unit_workspace.add_child(tab_shell)
	var tab_inner := VBoxContainer.new()
	tab_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_inner.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	tab_shell.add_child(tab_inner)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	tab_inner.add_child(tab_row)
	_tab_btn_skills = _make_tab_button("Skills", ClassLibraryTheme.ACCENT_INGAME)
	_tab_btn_class = _make_tab_button("Class & Passives", ClassLibraryTheme.ACCENT_STATS)
	tab_row.add_child(_tab_btn_skills)
	tab_row.add_child(_tab_btn_class)
	_tab_btn_skills.pressed.connect(func() -> void: _set_unit_tab(0))
	_tab_btn_class.pressed.connect(func() -> void: _set_unit_tab(1))
	var tab_rule := ColorRect.new()
	tab_rule.custom_minimum_size.y = 1.0
	tab_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_rule.color = ClassLibraryTheme.BORDER_SUBTLE
	tab_inner.add_child(tab_rule)

	_skills_workspace = VBoxContainer.new()
	_skills_workspace.name = "SkillsWorkspace"
	_skills_workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skills_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_unit_workspace.add_child(_skills_workspace)

	_unit_split = HSplitContainer.new()
	_unit_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_unit_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skills_workspace.add_child(_unit_split)

	var list_shell := _build_editor_column_shell(
		"In-Game Preview", ClassLibraryTheme.Column.INGAME, ClassLibraryTheme.dim(200.0), 0.30,
	)
	_unit_split.add_child(list_shell.panel)
	_list_scroll = list_shell.scroll
	_list_vbox = list_shell.content

	var data_shell := _build_editor_column_shell(
		"Ability Data", ClassLibraryTheme.Column.DATA, ClassLibraryTheme.dim(220.0), 0.38,
	)
	_unit_split.add_child(data_shell.panel)
	_data_scroll = data_shell.scroll
	_data_vbox = data_shell.content

	var impl_shell := _build_editor_column_shell(
		"How It Works", ClassLibraryTheme.Column.IMPL, ClassLibraryTheme.dim(200.0), 0.32,
	)
	_unit_split.add_child(impl_shell.panel)
	_impl_scroll = impl_shell.scroll
	_impl_vbox = impl_shell.content

	_class_workspace = VBoxContainer.new()
	_class_workspace.name = "ClassWorkspace"
	_class_workspace.visible = false
	_class_workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_class_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_unit_workspace.add_child(_class_workspace)

	_class_stats_panel = PanelContainer.new()
	_class_stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_class_stats_panel.add_theme_stylebox_override("panel", ClassLibraryTheme.column_style(ClassLibraryTheme.Column.STATS))
	_class_workspace.add_child(_class_stats_panel)
	var class_stats_outer := VBoxContainer.new()
	class_stats_outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_stats_outer.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	_class_stats_panel.add_child(class_stats_outer)
	var class_stats_hdr := Label.new()
	class_stats_hdr.text = "CLASS STATS & EQUIPMENT"
	class_stats_hdr.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SUBSECTION))
	class_stats_hdr.add_theme_color_override("font_color", ClassLibraryTheme.ACCENT_STATS)
	class_stats_outer.add_child(class_stats_hdr)
	var class_stats_scroll := ScrollContainer.new()
	class_stats_scroll.custom_minimum_size.y = ClassLibraryTheme.dim(168.0)
	class_stats_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_stats_outer.add_child(class_stats_scroll)
	_class_stats_vbox = VBoxContainer.new()
	_class_stats_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_class_stats_vbox.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	class_stats_scroll.add_child(_class_stats_vbox)

	var class_split := HSplitContainer.new()
	_class_split = class_split
	class_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_class_workspace.add_child(class_split)
	var class_list_shell := _build_editor_column_shell(
		"In-Game Preview", ClassLibraryTheme.Column.PASSIVE, ClassLibraryTheme.dim(200.0), 0.30,
	)
	class_split.add_child(class_list_shell.panel)
	_class_list_scroll = class_list_shell.scroll
	_class_list_vbox = class_list_shell.content
	var class_data_shell := _build_editor_column_shell(
		"Passive Data", ClassLibraryTheme.Column.PASSIVE, ClassLibraryTheme.dim(220.0), 0.35,
	)
	class_split.add_child(class_data_shell.panel)
	_class_passive_data_scroll = class_data_shell.scroll
	_class_passive_data_vbox = class_data_shell.content
	var class_impl_shell := _build_editor_column_shell(
		"How It Works", ClassLibraryTheme.Column.IMPL, ClassLibraryTheme.dim(200.0), 0.35,
	)
	class_split.add_child(class_impl_shell.panel)
	_class_passive_impl_scroll = class_impl_shell.scroll
	_class_passive_impl_vbox = class_impl_shell.content

	_build_preview_panel(editor_split)

	_load_layout_config()
	_main_split.dragged.connect(func(_o: int) -> void: _save_layout_config())
	_editor_split.dragged.connect(func(_o: int) -> void: _save_layout_config())
	_unit_split.dragged.connect(func(_o: int) -> void: _save_layout_config())
	_class_split.dragged.connect(func(_o: int) -> void: _save_layout_config())

	_set_unit_tab(0)

	_sync_detail_width()
	_update_scale_label()


func _sync_detail_width() -> void:
	if _detail_scroll != null and _detail_vbox != null:
		_detail_vbox.custom_minimum_size.x = maxf(ClassLibraryTheme.dim(720.0), _detail_scroll.size.x - ClassLibraryTheme.dim(8.0))


func _save_layout_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("layout", "main", _main_split.split_offset)
	cfg.set_value("layout", "editor", _editor_split.split_offset)
	cfg.set_value("layout", "unit", _unit_split.split_offset)
	cfg.set_value("layout", "class", _class_split.split_offset)
	cfg.save("user://class_editor_layout.cfg")


func _load_layout_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://class_editor_layout.cfg") == OK:
		_main_split.split_offset = int(cfg.get_value("layout", "main", 0))
		_editor_split.split_offset = int(cfg.get_value("layout", "editor", 0))
		_unit_split.split_offset = int(cfg.get_value("layout", "unit", 0))
		_class_split.split_offset = int(cfg.get_value("layout", "class", 0))


func _build_preview_panel(parent: HSplitContainer) -> void:
	_preview_panel = PanelContainer.new()
	_preview_panel.name = "PreviewPanel"
	_preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_panel.size_flags_stretch_ratio = 0.45
	_preview_panel.add_theme_stylebox_override("panel", ClassLibraryTheme.panel_style(ClassLibraryTheme.BG_CARD))
	parent.add_child(_preview_panel)
	
	var preview_pad := MarginContainer.new()
	preview_pad.add_theme_constant_override("margin_left", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	preview_pad.add_theme_constant_override("margin_right", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	preview_pad.add_theme_constant_override("margin_top", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	preview_pad.add_theme_constant_override("margin_bottom", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	_preview_panel.add_child(preview_pad)
	
	var preview_vbox := VBoxContainer.new()
	preview_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_vbox.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	preview_pad.add_child(preview_vbox)
	
	var preview_hdr := Label.new()
	preview_hdr.text = "TACTICAL PREVIEW"
	preview_hdr.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SUBSECTION))
	preview_hdr.add_theme_color_override("font_color", ClassLibraryTheme.ACCENT_INGAME)
	preview_vbox.add_child(preview_hdr)
	
	var viewport_container := SubViewportContainer.new()
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	preview_vbox.add_child(viewport_container)
	
	_preview_viewport = SubViewport.new()
	_preview_viewport.size = PREVIEW_VIEWPORT_SIZE
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport_container.add_child(_preview_viewport)
	
	_preview_scene = preload("res://scenes/TestBattle.tscn").instantiate()
	_preview_viewport.add_child(_preview_scene)


func _toggle_preview() -> void:
	_preview_visible = not _preview_visible
	if _preview_toggle_btn != null:
		_preview_toggle_btn.text = "Hide Preview" if _preview_visible else "Show Preview"
	if _preview_panel != null:
		_preview_panel.visible = _preview_visible


func _refresh_preview() -> void:
	if _preview_scene == null or _selected_unit == null:
		return
	var session := TestBattleSession.new()
	session.player_class_id = _selected_unit.id
	session.set_all_passives_enabled(_selected_unit.id, true)
	session.unkillable_dummies = true
	session.infinite_player_ap = true
	if _preview_scene.has_method("apply_training_board"):
		_preview_scene.apply_training_board()


func _restart_preview() -> void:
	if _preview_scene == null or _preview_viewport == null:
		return
	_preview_viewport.remove_child(_preview_scene)
	_preview_scene.queue_free()
	_preview_scene = preload("res://scenes/TestBattle.tscn").instantiate()
	_preview_viewport.add_child(_preview_scene)
	_refresh_preview()


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
	var data: Dictionary = ClassLibrarySchema.read_editor_save()
	if data.is_empty():
		data = {"glossary": _glossary_overrides, "units": {}, "ui_scale": ClassLibraryTheme.user_scale()}
	data["ui_scale"] = ClassLibraryTheme.user_scale()
	ClassLibrarySchema.write_editor_save(data)


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
		[ClassLibraryTheme.ACCENT_OVERRIDE_SAVED, "Gold — saved library override"],
		[ClassLibraryTheme.ACCENT_OVERRIDE_UNSAVED, "Orange — unsaved edit"],
		[ClassLibraryTheme.ACCENT_INGAME, "Yellow — in-game preview"],
		[ClassLibraryTheme.ACCENT_DATA, "Blue — data column"],
		[ClassLibraryTheme.ACCENT_IMPL, "Teal — implementation"],
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


func _section_card(
	title: String,
	accent: Color,
	col: ClassLibraryTheme.Column = ClassLibraryTheme.Column.NEUTRAL,
	parent: VBoxContainer = null,
) -> VBoxContainer:
	var wrap := PanelContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_stylebox_override("panel", ClassLibraryTheme.column_style(col))
	var target: VBoxContainer = parent if parent != null else _detail_vbox
	target.add_child(wrap)
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


func _build_editor_column_shell(
	title: String,
	col: ClassLibraryTheme.Column,
	min_width: float,
	stretch_ratio: float = 1.0,
) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch_ratio
	if min_width > 0.0:
		panel.custom_minimum_size.x = min_width
	panel.add_theme_stylebox_override("panel", ClassLibraryTheme.column_style(col))
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	panel.add_child(outer)
	var hdr := Label.new()
	hdr.text = title.to_upper()
	hdr.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SUBSECTION))
	hdr.add_theme_color_override("font_color", ClassLibraryTheme.accent_for_column(col))
	outer.add_child(hdr)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	scroll.add_child(content)
	return {"panel": panel, "scroll": scroll, "content": content}


func _show_unit_workspace(show_unit: bool) -> void:
	if _unit_workspace != null:
		_unit_workspace.visible = show_unit
	if _detail_scroll != null:
		_detail_scroll.visible = not show_unit


func _make_tab_button(text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_group = _unit_tab_group
	btn.custom_minimum_size = Vector2(ClassLibraryTheme.px(140), ClassLibraryTheme.px(32))
	_style_tab_button(btn, false, accent)
	return btn


func _style_tab_button(btn: Button, active: bool, accent: Color) -> void:
	if active:
		btn.add_theme_stylebox_override("normal", ClassLibraryTheme.panel_style(ClassLibraryTheme.BG_INSET, accent, 1, 4))
		btn.add_theme_stylebox_override("hover", ClassLibraryTheme.panel_style(ClassLibraryTheme.BG_INSET, accent, 1, 4))
		btn.add_theme_stylebox_override("pressed", ClassLibraryTheme.panel_style(ClassLibraryTheme.BG_INSET, accent, 1, 4))
		btn.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_PRIMARY)
	else:
		btn.add_theme_stylebox_override("normal", ClassLibraryTheme.toolbar_button_style())
		btn.add_theme_stylebox_override("hover", ClassLibraryTheme.panel_style(ClassLibraryTheme.BG_INSET, ClassLibraryTheme.BORDER_SUBTLE))
		btn.add_theme_stylebox_override("pressed", ClassLibraryTheme.panel_style(ClassLibraryTheme.BG_INSET))
		btn.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_MUTED)
	btn.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	btn.button_pressed = active


func _set_unit_tab(tab: int) -> void:
	_unit_tab = tab
	if _tab_btn_skills != null:
		_style_tab_button(_tab_btn_skills, tab == 0, ClassLibraryTheme.ACCENT_INGAME)
	if _tab_btn_class != null:
		_style_tab_button(_tab_btn_class, tab == 1, ClassLibraryTheme.ACCENT_STATS)
	if _skills_workspace != null:
		_skills_workspace.visible = tab == 0
	if _class_workspace != null:
		_class_workspace.visible = tab == 1
	if _selected_unit == null:
		return
	if tab == 0 and _selected_ability == null:
		_select_default_ability(_selected_unit)
	elif tab == 1 and _selected_passive == null:
		_select_default_passive(_selected_unit)


func _clear_pane(vbox: VBoxContainer) -> void:
	if vbox == null:
		return
	for child: Node in vbox.get_children():
		child.queue_free()


func _entry_key_passive(passive: PassiveData) -> String:
	return "passive:%s" % String(passive.id)


func _entry_key_ability(ability: AbilityData) -> String:
	return "ability:%s" % String(ability.id)


func _style_list_item_card(card: PanelContainer, active: bool, accent: Color) -> void:
	var border: Color = accent if active else ClassLibraryTheme.BORDER_SUBTLE
	var bg: Color = ClassLibraryTheme.BG_INSET if active else ClassLibraryTheme.BG_CARD
	card.add_theme_stylebox_override(
		"panel",
		ClassLibraryTheme.panel_style(bg, border, 1 if active else 1, 4, ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM)),
	)


func _set_active_list_item(key: String, accent: Color) -> void:
	_active_list_key = key
	for entry_key: String in _list_item_cards.keys():
		var card: PanelContainer = _list_item_cards[entry_key]
		if not is_instance_valid(card):
			continue
		var item_accent: Color = card.get_meta("list_accent", ClassLibraryTheme.ACCENT_NEUTRAL)
		_style_list_item_card(card, entry_key == key, item_accent if entry_key == key else ClassLibraryTheme.BORDER_SUBTLE)


func _set_active_class_list_item(key: String, accent: Color) -> void:
	_active_class_list_key = key
	for entry_key: String in _class_list_item_cards.keys():
		var card: PanelContainer = _class_list_item_cards[entry_key]
		if not is_instance_valid(card):
			continue
		var item_accent: Color = card.get_meta("list_accent", ClassLibraryTheme.ACCENT_NEUTRAL)
		_style_list_item_card(card, entry_key == key, item_accent if entry_key == key else ClassLibraryTheme.BORDER_SUBTLE)


func _preview_unit() -> UnitState:
	return _preview_unit_state


func _make_list_preview_chip(emoji: String, val: String, tip: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.tooltip_text = tip
	row.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_XS))
	var emoji_lbl := Label.new()
	emoji_lbl.text = emoji
	emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_lbl.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	var val_lbl := Label.new()
	val_lbl.text = val
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	val_lbl.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	row.add_child(emoji_lbl)
	row.add_child(val_lbl)
	return {"row": row, "val_lbl": val_lbl}


func _ability_effect_preview_bbcode(ability: AbilityData) -> String:
	if ability == null:
		return ""
	CombatUiFormatters.configure_body_font(ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	var body_px: int = ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY)
	var body: String = CombatUiFormatters.ability_effect_bbcode(ability, _preview_unit())
	return "[font_size=%d]%s[/font_size]" % [body_px, body]


func _add_selectable_preview_card(
	parent: VBoxContainer,
	key: String,
	title_text: String,
	subtitle_text: String,
	accent: Color,
	on_select: Callable,
	card_registry: Dictionary,
	active_key: String,
	ability: AbilityData = null,
	passive: PassiveData = null,
) -> Dictionary:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.set_meta("list_accent", accent)
	_style_list_item_card(card, active_key == key, accent if active_key == key else ClassLibraryTheme.BORDER_SUBTLE)
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			on_select.call()
		elif event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_KP_ENTER:
				on_select.call()
				card.accept_event()
	)
	parent.add_child(card)
	card_registry[key] = card
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_XS))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	var name_lbl := Label.new()
	name_lbl.text = title_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_TITLE))
	name_lbl.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_PRIMARY)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	if ability != null:
		name_lbl.tooltip_text = CombatUiFormatters.ability_tooltip_text(ability, _preview_unit())
	elif passive != null and not passive.description.is_empty():
		name_lbl.tooltip_text = passive.description
	head.add_child(name_lbl)
	var sub_lbl: Label = null
	if not subtitle_text.is_empty():
		sub_lbl = Label.new()
		sub_lbl.text = subtitle_text
		sub_lbl.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SMALL))
		sub_lbl.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_DIM)
		sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(sub_lbl)
	var preview_wrap := PanelContainer.new()
	preview_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_wrap.add_theme_stylebox_override("panel", ClassLibraryTheme.column_style(ClassLibraryTheme.Column.INGAME))
	box.add_child(preview_wrap)
	var preview_inner := VBoxContainer.new()
	preview_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_inner.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_XS))
	preview_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_wrap.add_child(preview_inner)
	var cost_val_lbl: Label = null
	var range_val_lbl: Label = null
	var cost_row: HBoxContainer = null
	var range_row: HBoxContainer = null
	if ability != null:
		var chips := HBoxContainer.new()
		chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chips.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_MD))
		preview_inner.add_child(chips)
		var cost_chip: Dictionary = CombatUiFormatters.ability_cost_chip(ability)
		var cost_refs: Dictionary = _make_list_preview_chip(
			String(cost_chip.get("emoji", "")),
			String(cost_chip.get("text", "")),
			String(cost_chip.get("tooltip", "")),
		)
		cost_row = cost_refs["row"] as HBoxContainer
		cost_val_lbl = cost_refs["val_lbl"] as Label
		chips.add_child(cost_row)
		var range_chip: Dictionary = CombatUiFormatters.ability_range_chip(ability, _preview_unit())
		var range_refs: Dictionary = _make_list_preview_chip(
			String(range_chip.get("emoji", "")),
			String(range_chip.get("text", "")),
			String(range_chip.get("tooltip", "")),
		)
		range_row = range_refs["row"] as HBoxContainer
		range_val_lbl = range_refs["val_lbl"] as Label
		chips.add_child(range_row)
	var preview := RichTextLabel.new()
	preview.bbcode_enabled = true
	preview.scroll_active = true
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size.y = ClassLibraryTheme.px(72 if ability != null else 88)
	preview.add_theme_color_override("default_color", ClassLibraryTheme.TEXT_PRIMARY)
	preview.add_theme_font_size_override("normal_font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	preview.mouse_filter = Control.MOUSE_FILTER_PASS
	preview_inner.add_child(preview)
	var sync_preview_width := func() -> void:
		_sync_list_preview_width(preview, preview_wrap)
	preview_wrap.resized.connect(sync_preview_width)
	preview.tree_entered.connect(sync_preview_width)
	return {
		"preview": preview,
		"title": name_lbl,
		"sub_lbl": sub_lbl if not subtitle_text.is_empty() else null,
		"wrap": preview_wrap,
		"cost_val": cost_val_lbl,
		"range_val": range_val_lbl,
		"cost_row": cost_row,
		"range_row": range_row,
	}


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
	_passive_ui.clear()
	_list_item_cards.clear()
	_class_list_item_cards.clear()
	_active_list_key = ""
	_active_class_list_key = ""
	_selected_passive = null
	_selected_ability = null
	_preview_unit_state = null
	if _detail_vbox != null:
		for child: Node in _detail_vbox.get_children():
			child.queue_free()
	_clear_pane(_list_vbox)
	_clear_pane(_data_vbox)
	_clear_pane(_impl_vbox)
	_clear_pane(_class_list_vbox)
	_clear_pane(_class_stats_vbox)
	_clear_pane(_class_passive_data_vbox)
	_clear_pane(_class_passive_impl_vbox)


func _select_unit(unit: UnitData) -> void:
	_selected_unit = unit
	_view_mode = ViewMode.UNIT
	_view_unit_id = unit.id
	if _class_buttons.has(unit.id):
		_set_active_sidebar(_class_buttons[unit.id], ClassLibraryTheme.ACCENT_STATS)
	_clear_detail()
	_preview_unit_state = UnitState.create(
		0,
		unit,
		GameEnums.Team.PLAYER,
		Vector2i.ZERO,
		{
			"active_abilities": unit.abilities,
			"active_passives": unit.passives,
			"level": unit.level,
		},
	)
	_show_unit_workspace(true)
	_set_unit_tab(_unit_tab)
	_build_skills_tab(unit)
	_build_class_tab(unit)
	if _unit_tab == 0:
		_select_default_ability(unit)
	else:
		_select_default_passive(unit)
	_refresh_preview()


func _build_skills_tab(unit: UnitData) -> void:
	if _list_vbox == null:
		return
	if unit.abilities.is_empty():
		var none := Label.new()
		none.text = "No skills."
		none.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_MUTED)
		_list_vbox.add_child(none)
		return
	for ability: AbilityData in unit.abilities:
		var key := _entry_key_ability(ability)
		var card_refs: Dictionary = _add_selectable_preview_card(
			_list_vbox,
			key,
			ability.display_name,
			String(ability.id),
			ClassLibraryTheme.ACCENT_INGAME,
			func() -> void: _select_ability_entry(ability),
			_list_item_cards,
			_active_list_key,
			ability,
		)
		_ability_ui[ability] = card_refs
		_refresh_ability_ui(ability)


func _build_class_tab(unit: UnitData) -> void:
	if _class_stats_vbox == null:
		return
	_add_compact_unit_header(_class_stats_vbox, unit)
	_build_stats_section(unit, _class_stats_vbox)
	_build_weapon_section(unit, _class_stats_vbox)
	if _class_list_vbox == null:
		return
	if unit.passives.is_empty():
		var none := Label.new()
		none.text = "No passives."
		none.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_MUTED)
		_class_list_vbox.add_child(none)
		return
	for passive: PassiveData in unit.passives:
		var key := _entry_key_passive(passive)
		var card_refs: Dictionary = _add_selectable_preview_card(
			_class_list_vbox,
			key,
			passive.display_name,
			String(passive.id),
			ClassLibraryTheme.ACCENT_PASSIVE,
			func() -> void: _select_passive_entry(passive),
			_class_list_item_cards,
			_active_class_list_key,
			null,
			passive,
		)
		_passive_ui[passive] = card_refs
		_refresh_passive_ui(passive)


func _select_default_ability(unit: UnitData) -> void:
	if unit.abilities.is_empty():
		_show_ability_placeholder()
		return
	_select_ability_entry(unit.abilities[0])


func _select_default_passive(unit: UnitData) -> void:
	if unit.passives.is_empty():
		_show_passive_placeholder()
		return
	_select_passive_entry(unit.passives[0])


func _select_ability_entry(ability: AbilityData) -> void:
	_selected_ability = ability
	_selected_passive = null
	_set_active_list_item(_entry_key_ability(ability), ClassLibraryTheme.ACCENT_INGAME)
	_rebuild_ability_detail_panes(ability)


func _select_passive_entry(passive: PassiveData) -> void:
	_selected_passive = passive
	_selected_ability = null
	_set_active_class_list_item(_entry_key_passive(passive), ClassLibraryTheme.ACCENT_PASSIVE)
	_rebuild_passive_detail_panes(passive)


func _show_ability_placeholder() -> void:
	_clear_pane(_data_vbox)
	_clear_pane(_impl_vbox)
	var data_hint := Label.new()
	data_hint.text = "Select a skill from the list."
	data_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	data_hint.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_MUTED)
	_data_vbox.add_child(data_hint)
	var impl_hint := Label.new()
	impl_hint.text = "Implementation notes appear here after you select a skill."
	impl_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	impl_hint.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_MUTED)
	_impl_vbox.add_child(impl_hint)


func _show_passive_placeholder() -> void:
	_clear_pane(_class_passive_data_vbox)
	_clear_pane(_class_passive_impl_vbox)
	var data_hint := Label.new()
	data_hint.text = "Select a passive from the list."
	data_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	data_hint.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_MUTED)
	_class_passive_data_vbox.add_child(data_hint)
	var impl_hint := Label.new()
	impl_hint.text = "Implementation notes appear here after you select a passive."
	impl_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	impl_hint.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_MUTED)
	_class_passive_impl_vbox.add_child(impl_hint)


func _rebuild_ability_detail_panes(ability: AbilityData) -> void:
	_clear_pane(_data_vbox)
	_clear_pane(_impl_vbox)
	if ability == null:
		_show_ability_placeholder()
		return
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", ClassLibraryTheme.section_header_bar(ClassLibraryTheme.ACCENT_DATA))
	_data_vbox.add_child(header)
	var name_inner := HBoxContainer.new()
	name_inner.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	header.add_child(name_inner)
	var name_edit := LineEdit.new()
	name_edit.text = ability.display_name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_TITLE))
	name_edit.text_changed.connect(func(t: String) -> void:
		ability.display_name = t
		_refresh_ability_ui(ability)
	)
	_track_ability_field(ability, "display_name", [name_edit])
	name_inner.add_child(name_edit)
	var id_badge := Label.new()
	id_badge.text = String(ability.id)
	id_badge.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SMALL))
	id_badge.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_DIM)
	name_inner.add_child(id_badge)
	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.tooltip_text = "Restore this skill to coded factory defaults"
	_style_toolbar_button(reset_btn)
	reset_btn.pressed.connect(func() -> void: _reset_ability_to_default(ability))
	name_inner.add_child(reset_btn)
	_populate_ability_data_editor(_data_vbox, ability)
	var impl_lbl := Label.new()
	impl_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	impl_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	impl_lbl.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	impl_lbl.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_SECONDARY)
	_impl_vbox.add_child(impl_lbl)
	var dump_hdr := Label.new()
	dump_hdr.text = "RAW DATA"
	dump_hdr.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SMALL))
	dump_hdr.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_DIM)
	_impl_vbox.add_child(dump_hdr)
	var dump_lbl := Label.new()
	dump_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dump_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dump_lbl.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_MONO))
	dump_lbl.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_DIM)
	_impl_vbox.add_child(dump_lbl)
	if not _ability_ui.has(ability):
		_ability_ui[ability] = {}
	_ability_ui[ability]["impl"] = impl_lbl
	_ability_ui[ability]["dump"] = dump_lbl
	_ability_ui[ability]["reset_btn"] = reset_btn
	_ability_ui[ability]["name_edit"] = name_edit
	_refresh_ability_ui(ability)


func _rebuild_passive_detail_panes(passive: PassiveData) -> void:
	_clear_pane(_class_passive_data_vbox)
	_clear_pane(_class_passive_impl_vbox)
	if passive == null:
		_show_passive_placeholder()
		return
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", ClassLibraryTheme.section_header_bar(ClassLibraryTheme.ACCENT_PASSIVE))
	_class_passive_data_vbox.add_child(header)
	var name_inner := HBoxContainer.new()
	name_inner.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	header.add_child(name_inner)
	var id_badge := Label.new()
	id_badge.text = String(passive.id)
	id_badge.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SMALL))
	id_badge.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_DIM)
	name_inner.add_child(id_badge)
	var name_row := GridContainer.new()
	name_row.columns = 2
	_class_passive_data_vbox.add_child(name_row)
	_bind_string(name_row, "Name", passive.display_name, func(v: String) -> void:
		passive.display_name = v
		_refresh_passive_ui(passive)
	)
	var desc_edit := _bind_multiline(_class_passive_data_vbox, "Description", passive.description, func(v: String) -> void:
		passive.description = v
		_refresh_passive_ui(passive)
	)
	desc_edit.custom_minimum_size = Vector2(0, ClassLibraryTheme.px(96))
	_bind_multiline(_class_passive_data_vbox, "Upgraded", passive.upgraded_description, func(v: String) -> void:
		passive.upgraded_description = v
		_refresh_passive_ui(passive)
	)
	var impl_lbl := Label.new()
	impl_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	impl_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	impl_lbl.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	impl_lbl.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_SECONDARY)
	_class_passive_impl_vbox.add_child(impl_lbl)
	var dump_hdr := Label.new()
	dump_hdr.text = "RAW DATA"
	dump_hdr.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SMALL))
	dump_hdr.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_DIM)
	_class_passive_impl_vbox.add_child(dump_hdr)
	var dump_lbl := Label.new()
	dump_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dump_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dump_lbl.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_MONO))
	dump_lbl.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_DIM)
	_class_passive_impl_vbox.add_child(dump_lbl)
	if not _passive_ui.has(passive):
		_passive_ui[passive] = {}
	_passive_ui[passive]["impl"] = impl_lbl
	_passive_ui[passive]["dump"] = dump_lbl
	_refresh_passive_ui(passive)


func _refresh_passive_ui(passive: PassiveData) -> void:
	if not _passive_ui.has(passive):
		return
	var refs: Dictionary = _passive_ui[passive]
	var preview: RichTextLabel = refs.get("preview")
	if preview != null:
		_refresh_passive_preview(passive, preview)
		var wrap: PanelContainer = refs.get("wrap")
		if wrap != null:
			_sync_list_preview_width(preview, wrap)
	var title: Label = refs.get("title")
	if title != null:
		title.text = passive.display_name
		if not passive.description.is_empty():
			title.tooltip_text = passive.description
		else:
			title.tooltip_text = ""
	if refs.has("impl") and refs["impl"] != null:
		refs["impl"].text = ClassLibrarySchema.passive_implementation_notes(passive)
	if refs.has("dump") and refs["dump"] != null:
		refs["dump"].text = ClassLibrarySchema.passive_data_dump(passive)


func _add_compact_unit_header(parent: VBoxContainer, unit: UnitData) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	parent.add_child(row)
	var accent_bar := ColorRect.new()
	accent_bar.custom_minimum_size = Vector2(ClassLibraryTheme.px(3), ClassLibraryTheme.px(36))
	accent_bar.color = ClassLibraryTheme.ACCENT_STATS
	row.add_child(accent_bar)
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)
	var t := Label.new()
	t.text = unit.display_name
	t.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_TITLE))
	t.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_PRIMARY)
	text_col.add_child(t)
	var s := Label.new()
	s.text = "ID: %s" % String(unit.id)
	s.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SMALL))
	s.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_MUTED)
	text_col.add_child(s)


func _add_page_header(title: String, subtitle: String, accent: Color) -> void:
	_add_page_header_to(_detail_vbox, title, subtitle, accent)


func _add_page_header_to(parent: VBoxContainer, title: String, subtitle: String, accent: Color) -> void:
	if parent == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_MD))
	parent.add_child(row)
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

func _build_stats_section(unit: UnitData, parent: VBoxContainer) -> void:
	var section := _section_card("Stats", ClassLibraryTheme.ACCENT_STATS, ClassLibraryTheme.Column.STATS, parent)
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


func _build_weapon_section(unit: UnitData, parent: VBoxContainer) -> void:
	var section := _section_card("Equipment", ClassLibraryTheme.ACCENT_NEUTRAL, ClassLibraryTheme.Column.NEUTRAL, parent)
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


func _sync_list_preview_width(preview: RichTextLabel, host: PanelContainer) -> void:
	if preview == null or host == null:
		return
	var margin: float = ClassLibraryTheme.px(ClassLibraryTheme.SPACE_MD) * 2.0
	var panel_style: StyleBox = host.get_theme_stylebox("panel")
	if panel_style is StyleBoxFlat:
		var flat: StyleBoxFlat = panel_style as StyleBoxFlat
		margin = flat.content_margin_left + flat.content_margin_right
	preview.custom_minimum_size.x = maxf(host.size.x - margin, 1.0)


func _refresh_passive_preview(passive: PassiveData, preview: RichTextLabel) -> void:
	CombatUiFormatters.configure_body_font(ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	preview.text = ClassLibrarySchema.passive_preview_bbcode(passive)


func _populate_ability_data_editor(parent: VBoxContainer, ability: AbilityData) -> void:
	_field_tracks.erase(ability.id)
	ability.finalize_modular()
	ability.is_movement_skill = ability.planner_group == GameEnums.PlannerGroup.PRE_MOVE
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	grid.add_theme_constant_override("v_separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_XS))
	parent.add_child(grid)
	var planner_row := _bind_enum(
		grid, "planner_group", GameEnums.PlannerGroup, ability.planner_group,
		func(v: int) -> void:
			ability.planner_group = v
			ability.kind = AbilityModuleBridge.kind_from_planner_group(v as GameEnums.PlannerGroup, ability.kind)
			ability.is_movement_skill = v == GameEnums.PlannerGroup.PRE_MOVE
			if v == GameEnums.PlannerGroup.PRE_MOVE:
				ability.primary_resource = GameEnums.CostResource.MP
			elif ability.kind == GameEnums.AbilityKind.CLASS_SKILL:
				ability.primary_resource = GameEnums.CostResource.AP
			ability.finalize_modular()
			_refresh_ability_ui(ability)
	)
	_track_ability_field(ability, "planner_group", planner_row)
	var tags_row := _bind_string(grid, "tags", _tags_to_csv(ability.tags), func(v: String) -> void:
		ability.tags = _tags_from_csv(v)
		_refresh_ability_ui(ability)
	)
	_track_ability_field(ability, "tags", tags_row)
	var resource_row := _bind_enum(
		grid, "Primary Resource", GameEnums.CostResource, ability.primary_resource,
		func(v: int) -> void:
			ability.primary_resource = v as GameEnums.CostResource
			if ability.planner_group == GameEnums.PlannerGroup.PRE_MOVE:
				ability.primary_resource = GameEnums.CostResource.MP
			elif ability.primary_resource == GameEnums.CostResource.NONE:
				ability.primary_resource = GameEnums.CostResource.AP
			ability.finalize_modular()
			_refresh_ability_ui(ability)
	)
	_track_ability_field(ability, "primary_resource", resource_row)
	var primary_value_row := _bind_int(grid, "Primary Cost", ability.primary_value, func(v: int) -> void:
		ability.primary_value = maxi(0, v)
		ability.finalize_modular()
		_refresh_ability_ui(ability)
	)
	_track_ability_field(ability, "primary_value", primary_value_row)
	var secondary_resource_row := _bind_enum(
		grid, "Secondary Resource", GameEnums.CostResource, ability.secondary_resource,
		func(v: int) -> void:
			ability.secondary_resource = v as GameEnums.CostResource
			ability.finalize_modular()
			_refresh_ability_ui(ability)
	)
	_track_ability_field(ability, "secondary_resource", secondary_resource_row)
	var secondary_value_row := _bind_int(
		grid, "Secondary Cost", ability.secondary_value, func(v: int) -> void:
			ability.secondary_value = maxi(0, v)
			ability.finalize_modular()
			_refresh_ability_ui(ability)
	)
	_track_ability_field(ability, "secondary_value", secondary_value_row)
	var cost_modifier_row := _bind_enum(
		grid, "Cost Modifier", GameEnums.CostModifier, ability.cost_modifier,
		func(v: int) -> void:
			ability.cost_modifier = v as GameEnums.CostModifier
			ability.finalize_modular()
			_refresh_ability_ui(ability)
	)
	_track_ability_field(ability, "cost_modifier", cost_modifier_row)
	var cost_modifier_n_row := _bind_int(
		grid, "Cost Modifier N", ability.cost_modifier_n, func(v: int) -> void:
			ability.cost_modifier_n = maxi(0, v)
			ability.finalize_modular()
			_refresh_ability_ui(ability)
	)
	_track_ability_field(ability, "cost_modifier_n", cost_modifier_n_row)
	var uses_row := _bind_int(grid, "Uses/Combat", ability.uses_per_combat, func(v: int) -> void:
		ability.uses_per_combat = v
		_refresh_ability_ui(ability)
	)
	_track_ability_field(ability, "uses_per_combat", uses_row)
	var present_key_row := _bind_string(
		grid, "Present Key", String(ability.presentation_key), func(v: String) -> void:
			ability.presentation_key = StringName(v)
			_refresh_ability_ui(ability)
	)
	_track_ability_field(ability, "presentation_key", present_key_row)
	var present_anim_row := _bind_enum(
		grid, "Present Anim", GameEnums.PresentationAnim, ability.presentation_anim,
		func(v: int) -> void:
			ability.presentation_anim = v as GameEnums.PresentationAnim
			_refresh_ability_ui(ability)
	)
	_track_ability_field(ability, "presentation_anim", present_anim_row)
	var upgrade_edit := _bind_multiline(
		parent, "Upgrade Text", ability.upgrade_description, func(v: String) -> void:
			ability.upgrade_description = v
			_refresh_ability_ui(ability)
	)
	_track_ability_field(ability, "upgrade_description", [upgrade_edit])
	var grey_cb := func() -> void:
		var is_pre_move: bool = ability.planner_group == GameEnums.PlannerGroup.PRE_MOVE
		_grey_row(resource_row, is_pre_move)
		_grey_row(primary_value_row, false)
		_grey_row(secondary_resource_row, false)
		_grey_row(secondary_value_row, ability.secondary_resource == GameEnums.CostResource.NONE)
		_grey_row(cost_modifier_n_row, ability.cost_modifier == GameEnums.CostModifier.NONE)
	if not _ability_ui.has(ability):
		_ability_ui[ability] = {}
	_ability_ui[ability]["greying_cb"] = grey_cb
	grey_cb.call()
	_add_subsection_label(parent, "Modules (authoritative)", ClassLibraryTheme.ACCENT_DATA)
	var modules_preview := RichTextLabel.new()
	modules_preview.bbcode_enabled = true
	modules_preview.fit_content = true
	modules_preview.scroll_active = false
	modules_preview.text = ClassLibrarySchema.modules_summary_bbcode(ability)
	parent.add_child(modules_preview)
	_ability_ui[ability]["modules_preview"] = modules_preview
	var module_box := VBoxContainer.new()
	module_box.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_XS))
	parent.add_child(module_box)
	_rebuild_modules_editor(module_box, ability, ability.modules, false)
	var add_module := Button.new()
	add_module.text = "+ Module"
	_style_toolbar_button(add_module)
	add_module.pressed.connect(func() -> void:
		ability.modules.append(_new_module_for_ability(ability))
		_on_modules_edited(ability, module_box, false)
	)
	parent.add_child(add_module)
	_add_subsection_label(parent, "Upgraded Modules (full replacement)", ClassLibraryTheme.ACCENT_INGAME)
	var upgraded_module_box := VBoxContainer.new()
	upgraded_module_box.add_theme_constant_override(
		"separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_XS)
	)
	parent.add_child(upgraded_module_box)
	_rebuild_modules_editor(
		upgraded_module_box, ability, ability.upgraded_modules, true
	)
	var add_upgraded_module := Button.new()
	add_upgraded_module.text = "+ Upgraded Module"
	_style_toolbar_button(add_upgraded_module)
	add_upgraded_module.pressed.connect(func() -> void:
		ability.upgraded_modules.append(_new_module_for_ability(ability))
		_on_modules_edited(ability, upgraded_module_box, true)
	)
	parent.add_child(add_upgraded_module)


func _new_module_for_ability(ability: AbilityData) -> AbilityModule:
	var module := AbilityModule.new()
	var authored_modules: Array[AbilityModule] = ability.get_active_modules()
	if not authored_modules.is_empty() and authored_modules.back() != null:
		module = authored_modules.back().duplicate(true) as AbilityModule
		return module
	module.primary_type = GameEnums.EffectType.DAMAGE
	module.amount = 1
	return module


func _on_modules_edited(
	ability: AbilityData,
	parent: VBoxContainer,
	upgraded: bool,
) -> void:
	var modules: Array[AbilityModule] = (
		ability.upgraded_modules if upgraded else ability.modules
	)
	if modules.is_empty():
		if upgraded:
			ability.upgraded_effects.clear()
		else:
			ability.effects.clear()
	ability.finalize_modular()
	_rebuild_modules_editor(parent, ability, modules, upgraded)
	_refresh_ability_ui(ability)


func _on_module_field_edited(ability: AbilityData) -> void:
	ability.finalize_modular()
	_refresh_ability_ui(ability)


func _rebuild_modules_editor(
	parent: VBoxContainer,
	ability: AbilityData,
	modules: Array[AbilityModule],
	upgraded: bool,
) -> void:
	for child: Node in parent.get_children():
		child.queue_free()
	for index: int in modules.size():
		var module: AbilityModule = modules[index]
		if module == null:
			continue
		var panel := VBoxContainer.new()
		parent.add_child(panel)
		var header := HBoxContainer.new()
		panel.add_child(header)
		var title := Label.new()
		title.text = "Module %d" % index
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(title)
		var remove := Button.new()
		remove.text = "Remove"
		_style_toolbar_button(remove)
		remove.pressed.connect(func() -> void:
			modules.remove_at(index)
			_on_modules_edited(ability, parent, upgraded)
		)
		header.add_child(remove)
		_build_module_fields(panel, ability, module, modules, upgraded)


func _build_module_fields(
	parent: VBoxContainer,
	ability: AbilityData,
	module: AbilityModule,
	modules: Array[AbilityModule],
	upgraded: bool,
) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("v_separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_XS))
	parent.add_child(grid)
	var changed := func() -> void: _on_module_field_edited(ability)
	_bind_enum(grid, "Phase", GameEnums.ModulePhase, module.execution_phase, func(v: int) -> void:
		module.execution_phase = v
		changed.call()
	)
	_bind_enum(grid, "Primary", GameEnums.EffectType, module.primary_type, func(v: int) -> void:
		module.primary_type = v
		changed.call()
	)
	_bind_int(grid, "Amount", module.amount, func(v: int) -> void:
		module.amount = v
		changed.call()
	)
	_bind_enum(grid, "Status", GameEnums.StatusType, module.status_type, func(v: int) -> void:
		module.status_type = v
		changed.call()
	)
	_bind_int(grid, "Duration", module.status_duration, func(v: int) -> void:
		module.status_duration = v
		changed.call()
	)
	_bind_enum(grid, "Scaling", GameEnums.StatType, module.scaling_stat, func(v: int) -> void:
		module.scaling_stat = v
		changed.call()
	)
	_bind_enum(grid, "Motion Mode", GameEnums.MotionMode, module.motion_mode, func(v: int) -> void:
		module.motion_mode = v
		changed.call()
	)
	_bind_int(grid, "Min Range", module.min_range, func(v: int) -> void:
		module.min_range = v
		changed.call()
	)
	_bind_int(grid, "Max Range", module.max_range, func(v: int) -> void:
		module.max_range = v
		changed.call()
	)
	_bind_bool(grid, "Requires LOS", module.requires_los, func(v: bool) -> void:
		module.requires_los = v
		changed.call()
	)
	_bind_enum(grid, "Range Origin", GameEnums.RangeOrigin, module.range_origin, func(v: int) -> void:
		module.range_origin = v
		changed.call()
	)
	_bind_enum(grid, "Shape", GameEnums.TargetShape, module.target_shape, func(v: int) -> void:
		module.target_shape = v
		changed.call()
	)
	_bind_int(grid, "Shape Size", module.target_shape_size, func(v: int) -> void:
		module.target_shape_size = v
		changed.call()
	)
	_bind_enum(grid, "Aim Binding", GameEnums.AimBinding, module.aim_binding, func(v: int) -> void:
		module.aim_binding = v
		changed.call()
	)
	_bind_int(grid, "Aim Module", module.aim_module_index, func(v: int) -> void:
		module.aim_module_index = v
		changed.call()
	)
	_bind_enum(grid, "Gate", GameEnums.ModuleGate, module.gate, func(v: int) -> void:
		module.gate = v
		changed.call()
	)
	_bind_enum(grid, "Presentation", GameEnums.PresentationAnim, module.presentation_anim, func(v: int) -> void:
		module.presentation_anim = v
		changed.call()
	)
	_bind_int(grid, "Adjacent Bonus", module.bonus_if_adjacent_at_cast, func(v: int) -> void:
		module.bonus_if_adjacent_at_cast = v
		changed.call()
	)
	_bind_int(grid, "DEF Debuff", module.def_debuff_before_damage, func(v: int) -> void:
		module.def_debuff_before_damage = v
		changed.call()
	)
	_add_module_targeting_flags(parent, ability, module)
	_add_module_keywords_editor(parent, ability, module)
	_add_module_layers_editor(parent, ability, module)


func _add_module_targeting_flags(
	parent: VBoxContainer,
	ability: AbilityData,
	module: AbilityModule,
) -> void:
	_add_subsection_label(parent, "Module Targeting", ClassLibraryTheme.ACCENT_DATA)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_MD))
	parent.add_child(row)
	for spec: Array in [
		[GameEnums.TargetingFlags.SELF, "Self"],
		[GameEnums.TargetingFlags.ALLY, "Ally"],
		[GameEnums.TargetingFlags.ENEMY, "Enemy"],
		[GameEnums.TargetingFlags.TILE, "Tile"],
		[GameEnums.TargetingFlags.DASH_LINE, "Dash line"],
	]:
		var flag: int = int(spec[0])
		var check := CheckBox.new()
		check.text = String(spec[1])
		check.button_pressed = module.has_targeting(flag)
		check.toggled.connect(func(enabled: bool) -> void:
			if enabled:
				module.targeting_flags |= flag
			else:
				module.targeting_flags &= ~flag
			_on_module_field_edited(ability)
		)
		row.add_child(check)


func _add_module_keywords_editor(
	parent: VBoxContainer,
	ability: AbilityData,
	module: AbilityModule,
) -> void:
	_add_subsection_label(parent, "Keywords", ClassLibraryTheme.ACCENT_DATA)
	var box := VBoxContainer.new()
	parent.add_child(box)
	for index: int in module.keywords.size():
		var keyword: AbilityKeyword = module.keywords[index]
		var grid := GridContainer.new()
		grid.columns = 2
		box.add_child(grid)
		_bind_enum(grid, "Keyword %d" % index, GameEnums.AbilityKeywordId, keyword.keyword_id, func(v: int) -> void:
			keyword.keyword_id = v
			_on_module_field_edited(ability)
		)
		_bind_int(grid, "Amount", keyword.amount, func(v: int) -> void:
			keyword.amount = v
			_on_module_field_edited(ability)
		)
		_bind_int(grid, "Push Amount", keyword.push_amount, func(v: int) -> void:
			keyword.push_amount = v
			_on_module_field_edited(ability)
		)
		_bind_bool(grid, "Emit Legacy Effect", keyword.emit_as_effect, func(v: bool) -> void:
			keyword.emit_as_effect = v
			_on_module_field_edited(ability)
		)
		var remove := Button.new()
		remove.text = "Remove Keyword"
		remove.pressed.connect(func() -> void:
			module.keywords.remove_at(index)
			_rebuild_ability_detail_panes(ability)
		)
		box.add_child(remove)
	var add := Button.new()
	add.text = "+ Keyword"
	add.pressed.connect(func() -> void:
		module.keywords.append(AbilityKeyword.new())
		_rebuild_ability_detail_panes(ability)
	)
	box.add_child(add)


func _add_module_layers_editor(
	parent: VBoxContainer,
	ability: AbilityData,
	module: AbilityModule,
) -> void:
	_add_subsection_label(parent, "Layers", ClassLibraryTheme.ACCENT_DATA)
	var box := VBoxContainer.new()
	parent.add_child(box)
	for index: int in module.layers.size():
		var layer: AbilityLayer = module.layers[index]
		if layer.effect == null:
			layer.effect = EffectData.new()
		var grid := GridContainer.new()
		grid.columns = 2
		box.add_child(grid)
		_bind_enum(grid, "Layer %d Condition" % index, GameEnums.LayerCondition, layer.condition, func(v: int) -> void:
			layer.condition = v
			_on_module_field_edited(ability)
		)
		_bind_enum(grid, "Layer Type", GameEnums.EffectType, layer.effect.type, func(v: int) -> void:
			layer.effect.type = v
			_on_module_field_edited(ability)
		)
		_bind_int(grid, "Layer Amount", layer.effect.amount, func(v: int) -> void:
			layer.effect.amount = v
			_on_module_field_edited(ability)
		)
		_bind_enum(grid, "Layer Scaling", GameEnums.StatType, layer.effect.scaling_stat, func(v: int) -> void:
			layer.effect.scaling_stat = v
			_on_module_field_edited(ability)
		)
		var remove := Button.new()
		remove.text = "Remove Layer"
		remove.pressed.connect(func() -> void:
			module.layers.remove_at(index)
			_rebuild_ability_detail_panes(ability)
		)
		box.add_child(remove)
	var add := Button.new()
	add.text = "+ Layer"
	add.pressed.connect(func() -> void:
		var layer := AbilityLayer.new()
		layer.effect = EffectData.new()
		layer.effect.type = GameEnums.EffectType.DAMAGE
		layer.effect.amount = 1
		module.layers.append(layer)
		_rebuild_ability_detail_panes(ability)
	)
	box.add_child(add)


func _tags_to_csv(tags: Array[StringName]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for t: StringName in tags:
		parts.append(String(t))
	return ",".join(parts)


func _tags_from_csv(text: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for part: String in text.split(",", false):
		var trimmed: String = part.strip_edges()
		if not trimmed.is_empty():
			out.append(StringName(trimmed))
	return out


func _refresh_ability_ui(ability: AbilityData) -> void:
	if not _ability_ui.has(ability):
		return
	var refs: Dictionary = _ability_ui[ability]
	
	if refs.has("greying_cb"):
		var cb: Callable = refs["greying_cb"]
		if cb.is_valid():
			cb.call()
	for cb_key in ["base_effect_greying_cbs", "upgraded_effect_greying_cbs"]:
		if refs.has(cb_key):
			for cb: Callable in refs.get(cb_key, []):
				if cb.is_valid():
					cb.call()
	var modules_preview: RichTextLabel = refs.get("modules_preview")
	if modules_preview != null:
		modules_preview.text = ClassLibrarySchema.modules_summary_bbcode(ability)
				
	var preview: RichTextLabel = refs.get("preview")
	if preview != null:
		preview.text = _ability_effect_preview_bbcode(ability)
		var wrap: PanelContainer = refs.get("wrap")
		if wrap != null:
			_sync_list_preview_width(preview, wrap)
	var sub_lbl: Label = refs.get("sub_lbl")
	if sub_lbl != null:
		var type_str := "ACTION"
		if ability.planner_group == GameEnums.PlannerGroup.PRE_MOVE:
			type_str = "PRE_MOVE (basic positioning)"
		elif AbilitySystem.is_movement_skill(ability):
			type_str = "ACTION + movement"
		sub_lbl.text = String(ability.id) + " | " + type_str
	var cost_val: Label = refs.get("cost_val")
	if cost_val != null:
		var cost_chip: Dictionary = CombatUiFormatters.ability_cost_chip(ability)
		cost_val.text = String(cost_chip.get("text", ""))
	var cost_row: HBoxContainer = refs.get("cost_row")
	if cost_row != null:
		var cost_chip_row: Dictionary = CombatUiFormatters.ability_cost_chip(ability)
		cost_row.tooltip_text = String(cost_chip_row.get("tooltip", ""))
	var range_val: Label = refs.get("range_val")
	if range_val != null:
		var range_chip: Dictionary = CombatUiFormatters.ability_range_chip(ability, _preview_unit())
		range_val.text = String(range_chip.get("text", ""))
	var range_row: HBoxContainer = refs.get("range_row")
	if range_row != null:
		var range_chip_row: Dictionary = CombatUiFormatters.ability_range_chip(ability, _preview_unit())
		range_row.tooltip_text = String(range_chip_row.get("tooltip", ""))
	var is_unsaved: bool = false
	var is_saved_override: bool = false
	if _saved_abilities.has(ability.id):
		var saved_ab: AbilityData = _saved_abilities[ability.id] as AbilityData
		is_unsaved = ClassLibrarySchema.ability_data_dump(ability) != ClassLibrarySchema.ability_data_dump(saved_ab)
	if _factory_abilities.has(ability.id) and _saved_abilities.has(ability.id):
		var factory_ab: AbilityData = _factory_abilities[ability.id] as AbilityData
		var saved_ab2: AbilityData = _saved_abilities[ability.id] as AbilityData
		is_saved_override = (
			ClassLibrarySchema.ability_data_dump(saved_ab2)
			!= ClassLibrarySchema.ability_data_dump(factory_ab)
		)

	var title: Label = refs.get("title")
	if title != null:
		title.text = ability.display_name
		title.tooltip_text = CombatUiFormatters.ability_tooltip_text(ability, _preview_unit())
		if is_unsaved:
			title.add_theme_color_override("font_color", ClassLibraryTheme.ACCENT_OVERRIDE_UNSAVED)
		elif is_saved_override:
			title.add_theme_color_override("font_color", ClassLibraryTheme.ACCENT_OVERRIDE_SAVED)
		else:
			title.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_PRIMARY)
			
	var reset_btn: Button = refs.get("reset_btn")
	if reset_btn != null:
		if is_unsaved or is_saved_override:
			reset_btn.add_theme_color_override("font_color", ClassLibraryTheme.ACCENT_OVERRIDE_UNSAVED)
		else:
			reset_btn.remove_theme_color_override("font_color")
			
	var name_edit: LineEdit = refs.get("name_edit")
	if name_edit != null:
		if is_unsaved:
			name_edit.add_theme_color_override("font_color", ClassLibraryTheme.ACCENT_OVERRIDE_UNSAVED)
		elif is_saved_override:
			name_edit.add_theme_color_override("font_color", ClassLibraryTheme.ACCENT_OVERRIDE_SAVED)
		else:
			name_edit.remove_theme_color_override("font_color")

	_refresh_ability_field_colors(ability)

	if refs.has("impl") and refs["impl"] != null:
		refs["impl"].text = ClassLibrarySchema.ability_implementation_notes(ability)
	if refs.has("dump") and refs["dump"] != null:
		refs["dump"].text = ClassLibrarySchema.ability_data_dump(ability)


func _snapshot_ability_defaults() -> void:
	_factory_abilities = ClassLibrarySchema.snapshot_factory_abilities()
	_saved_abilities = ClassLibrarySchema.snapshot_ability_map_from_units(DataLibrary.get_all_player_units())


func _track_ability_field(ability: AbilityData, field: String, controls: Variant) -> void:
	if ability == null or field.is_empty():
		return
	if not _field_tracks.has(ability.id):
		_field_tracks[ability.id] = []
	var rows: Array = _field_tracks[ability.id] as Array
	for i: int in range(rows.size() - 1, -1, -1):
		var row: Dictionary = rows[i] as Dictionary
		if String(row.get("field", "")) == field:
			rows.remove_at(i)
	var packed: Array[Control] = []
	if controls is Array:
		for ctrl: Variant in controls as Array:
			if ctrl is Control:
				packed.append(ctrl as Control)
	elif controls is Control:
		packed.append(controls as Control)
	rows.append({"field": field, "controls": packed})


func _ability_field_state(ability: AbilityData, field: String) -> FieldTrackState:
	var factory_ab: AbilityData = _factory_abilities.get(ability.id) as AbilityData
	var saved_ab: AbilityData = _saved_abilities.get(ability.id) as AbilityData
	var cur_sig: String = ClassLibrarySchema.ability_field_signature(ability, field)
	var saved_sig: String = ClassLibrarySchema.ability_field_signature(saved_ab, field) if saved_ab != null else ClassLibrarySchema.ability_field_signature(factory_ab, field)
	var factory_sig: String = ClassLibrarySchema.ability_field_signature(factory_ab, field) if factory_ab != null else cur_sig
	if cur_sig != saved_sig:
		return FieldTrackState.UNSAVED_EDIT
	if saved_sig != factory_sig:
		return FieldTrackState.SAVED_OVERRIDE
	return FieldTrackState.MATCHES_FACTORY


func _apply_field_track_color(controls: Array, state: FieldTrackState) -> void:
	for ctrl: Variant in controls:
		if not (ctrl is Control):
			continue
		var node: Control = ctrl as Control
		if node is Label:
			continue
		match state:
			FieldTrackState.SAVED_OVERRIDE:
				node.add_theme_color_override("font_color", ClassLibraryTheme.ACCENT_OVERRIDE_SAVED)
			FieldTrackState.UNSAVED_EDIT:
				node.add_theme_color_override("font_color", ClassLibraryTheme.ACCENT_OVERRIDE_UNSAVED)
			_:
				node.remove_theme_color_override("font_color")


func _refresh_ability_field_colors(ability: AbilityData) -> void:
	if ability == null or not _field_tracks.has(ability.id):
		return
	for entry: Variant in _field_tracks[ability.id] as Array:
		var row: Dictionary = entry as Dictionary
		var field: String = String(row.get("field", ""))
		var controls: Array = row.get("controls", []) as Array
		_apply_field_track_color(controls, _ability_field_state(ability, field))


func _collect_effect_editor_controls(parent: VBoxContainer) -> Array[Control]:
	var out: Array[Control] = []
	for child: Node in parent.get_children():
		_collect_controls_recursive(child, out)
	return out


func _collect_controls_recursive(node: Node, out: Array[Control]) -> void:
	if node is SpinBox or node is OptionButton or node is LineEdit or node is TextEdit or node is CheckBox:
		out.append(node as Control)
	for child: Node in node.get_children():
		_collect_controls_recursive(child, out)


func _reset_ability_to_default(ability: AbilityData) -> void:
	if ability == null or not _factory_abilities.has(ability.id) or _selected_unit == null:
		return
	ClassLibrarySchema.copy_ability_into(
		ability,
		_factory_abilities[ability.id] as AbilityData,
	)
	var keep_id: StringName = ability.id
	_select_unit(_selected_unit)
	for ab: AbilityData in _selected_unit.abilities:
		if ab.id == keep_id:
			_select_ability_entry(ab)
			break
	if _save_status != null:
		_save_status.text = "Reset %s" % String(ability.display_name)
		_save_status.add_theme_color_override("font_color", ClassLibraryTheme.ACCENT_SUCCESS)


# --- Reference pages ---

func _select_glossary() -> void:
	_selected_unit = null
	_view_mode = ViewMode.GLOSSARY
	_show_unit_workspace(false)
	_clear_detail()
	_add_page_header("Glossary", "Player-facing tooltips vs how the sim implements each keyword", ClassLibraryTheme.ACCENT_INGAME)
	_add_glossary_table_header()
	var manual: Dictionary = ClassLibrarySchema.manual_keywords()
	var keys: Array = manual.keys()
	keys.sort()
	for kw: String in keys:
		_add_glossary_row(
			kw,
			_glossary_tooltip(kw, manual[kw]),
			_glossary_system(kw),
			false,
		)
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
		["Implementation", 1.0, ClassLibraryTheme.ACCENT_IMPL],
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


func _glossary_system(kw: String) -> String:
	if _glossary_overrides.has(kw) and _glossary_overrides[kw].has("system"):
		return _glossary_overrides[kw]["system"]
	return ClassLibrarySchema.manual_keyword_system(kw)


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
	_show_unit_workspace(false)
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
		["Implementation", 0.36, ClassLibraryTheme.TEXT_SECONDARY],
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

func _bind_int(parent: GridContainer, label: String, value: int, setter: Callable) -> Array[Control]:
	var lbl := _field_label(label)
	parent.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = -999
	spin.max_value = 9999
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	spin.value_changed.connect(func(v: float) -> void: setter.call(int(v)))
	parent.add_child(spin)
	return [lbl, spin]


func _bind_bool(parent: GridContainer, label: String, value: bool, setter: Callable) -> void:
	parent.add_child(_field_label(label))
	var chk := CheckBox.new()
	chk.button_pressed = value
	chk.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	chk.toggled.connect(func(v: bool) -> void: setter.call(v))
	parent.add_child(chk)


func _bind_string(parent: GridContainer, label: String, value: String, setter: Callable) -> Array[Control]:
	var lbl: Label = _field_label(label)
	parent.add_child(lbl)
	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	edit.text_changed.connect(func(t: String) -> void: setter.call(t))
	parent.add_child(edit)
	return [lbl, edit]


func _bind_string_stacked(parent: VBoxContainer, label: String, value: String, setter: Callable) -> void:
	parent.add_child(_field_label(label))
	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(t: String) -> void: setter.call(t))
	parent.add_child(edit)


func _bind_enum(parent: GridContainer, label: String, enum_obj: Variant, current: int, setter: Callable) -> Array[Control]:
	var lbl := _field_label(label)
	parent.add_child(lbl)
	var opt := OptionButton.new()
	var keys: PackedStringArray = enum_obj.keys()
	for i: int in keys.size():
		opt.add_item(keys[i], i)
	opt.selected = current
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.item_selected.connect(func(idx: int) -> void: setter.call(idx))
	parent.add_child(opt)
	return [lbl, opt]


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


func _grey_row(row: Array[Control], greyed: bool) -> void:
	var alpha: float = 0.35 if greyed else 1.0
	for ctrl: Control in row:
		ctrl.modulate.a = alpha
		if ctrl is BaseButton or ctrl is SpinBox or ctrl is OptionButton or ctrl is LineEdit:
			ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE if greyed else Control.MOUSE_FILTER_STOP


func _save_overrides() -> void:
	for unit: UnitData in DataLibrary.get_all_player_units():
		DataLibrary.finalize_unit_abilities(unit)
	var data: Dictionary = ClassLibrarySchema.read_editor_save()
	if data.is_empty():
		data = {}
	data["glossary"] = _glossary_overrides
	data["units"] = ClassLibrarySchema.collect_player_unit_overrides()
	data["ui_scale"] = ClassLibraryTheme.user_scale()
	if _selected_unit != null:
		data["last_unit"] = String(_selected_unit.id)
	if ClassLibrarySchema.write_editor_save(data):
		_saved_abilities = ClassLibrarySchema.snapshot_ability_map_from_units(DataLibrary.get_all_player_units())
		if _selected_ability != null:
			_refresh_ability_field_colors(_selected_ability)
		if _save_status != null:
			_save_status.text = "Saved"
			_save_status.add_theme_color_override("font_color", ClassLibraryTheme.ACCENT_SUCCESS)
		_refresh_preview()
	else:
		if _save_status != null:
			_save_status.text = "Save failed"
			_save_status.add_theme_color_override("font_color", ClassLibraryTheme.ACCENT_DANGER)


func _load_overrides() -> void:
	var parsed: Dictionary = ClassLibrarySchema.read_editor_save()
	if parsed.is_empty():
		return
	_glossary_overrides = parsed.get("glossary", {})
	ClassLibraryTheme.set_user_scale(float(parsed.get("ui_scale", 1.0)))
	if parsed.has("last_unit"):
		_restore_unit_id = StringName(String(parsed["last_unit"]))


func _reload_factories() -> void:
	if _selected_unit != null:
		_restore_unit_id = _selected_unit.id
	var data: Dictionary = ClassLibrarySchema.read_editor_save()
	if data.is_empty():
		data = {}
	data["units"] = {}
	ClassLibrarySchema.write_editor_save(data)
	DataLibrary.reset_cache()
	get_tree().reload_current_scene()
