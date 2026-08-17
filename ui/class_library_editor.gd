class_name ClassLibraryEditorScreen
extends Control

const PREVIEW_VIEWPORT_SIZE: Vector2i = Vector2i(1280, 720)
const CANONICAL_ABILITY_TAGS: Array[StringName] = [
	AbilityModuleBridge.TAG_ATTACK,
	AbilityModuleBridge.TAG_MOVEMENT,
	AbilityModuleBridge.TAG_POSITIONING,
	AbilityModuleBridge.TAG_SPELL,
	AbilityModuleBridge.TAG_HEAL,
]
const ModuleAuthoringRules = preload("res://data/definitions/module_authoring_rules.gd")
const _BibleText = preload("res://ui/class_library_bible_text.gd")

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
var _column_visible: Dictionary = {
	"list": true,
	"data": true,
	"impl": true,
}
var _column_panels: Dictionary = {
	"list": [],
	"data": [],
	"impl": [],
}
var _column_toggle_btns: Dictionary = {}


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
	hint.text = "Factory skills only · Save is off · Reset Factories = code defaults"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SMALL))
	hint.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_MUTED)
	top_bar.add_child(hint)
	var sep := VSeparator.new()
	top_bar.add_child(sep)
	_add_column_toggle(top_bar, "list", "Skill List")
	_add_column_toggle(top_bar, "data", "Ability Data")
	_add_column_toggle(top_bar, "impl", "How It Works")
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
		"In-Game Preview", ClassLibraryTheme.Column.INGAME, ClassLibraryTheme.dim(200.0), 0.30, "list",
	)
	_unit_split.add_child(list_shell.panel)
	_list_scroll = list_shell.scroll
	_list_vbox = list_shell.content

	var data_shell := _build_editor_column_shell(
		"Ability Data", ClassLibraryTheme.Column.DATA, ClassLibraryTheme.dim(220.0), 0.38, "data",
	)
	_unit_split.add_child(data_shell.panel)
	_data_scroll = data_shell.scroll
	_data_vbox = data_shell.content

	var impl_shell := _build_editor_column_shell(
		"How It Works", ClassLibraryTheme.Column.IMPL, ClassLibraryTheme.dim(200.0), 0.32, "impl",
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
		"In-Game Preview", ClassLibraryTheme.Column.PASSIVE, ClassLibraryTheme.dim(200.0), 0.30, "list",
	)
	class_split.add_child(class_list_shell.panel)
	_class_list_scroll = class_list_shell.scroll
	_class_list_vbox = class_list_shell.content
	var class_data_shell := _build_editor_column_shell(
		"Passive Data", ClassLibraryTheme.Column.PASSIVE, ClassLibraryTheme.dim(220.0), 0.35, "data",
	)
	class_split.add_child(class_data_shell.panel)
	_class_passive_data_scroll = class_data_shell.scroll
	_class_passive_data_vbox = class_data_shell.content
	var class_impl_shell := _build_editor_column_shell(
		"How It Works", ClassLibraryTheme.Column.IMPL, ClassLibraryTheme.dim(200.0), 0.35, "impl",
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
	cfg.set_value("columns", "list", bool(_column_visible.get("list", true)))
	cfg.set_value("columns", "data", bool(_column_visible.get("data", true)))
	cfg.set_value("columns", "impl", bool(_column_visible.get("impl", true)))
	cfg.save("user://class_editor_layout.cfg")


func _load_layout_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://class_editor_layout.cfg") == OK:
		_main_split.split_offset = int(cfg.get_value("layout", "main", 0))
		_editor_split.split_offset = int(cfg.get_value("layout", "editor", 0))
		_unit_split.split_offset = int(cfg.get_value("layout", "unit", 0))
		_class_split.split_offset = int(cfg.get_value("layout", "class", 0))
		_column_visible["list"] = bool(cfg.get_value("columns", "list", true))
		_column_visible["data"] = bool(cfg.get_value("columns", "data", true))
		_column_visible["impl"] = bool(cfg.get_value("columns", "impl", true))
	_apply_column_visibility()


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
	data["units"] = {}
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
	column_id: String = "",
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
	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	outer.add_child(hdr_row)
	var hdr := Label.new()
	hdr.text = title.to_upper()
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_SUBSECTION))
	hdr.add_theme_color_override("font_color", ClassLibraryTheme.accent_for_column(col))
	hdr_row.add_child(hdr)
	if column_id != "":
		var hide_btn := Button.new()
		hide_btn.text = "Hide"
		_style_toolbar_button(hide_btn)
		hide_btn.pressed.connect(func() -> void: _set_column_visible(column_id, false))
		hdr_row.add_child(hide_btn)
		var bucket: Array = _column_panels.get(column_id, []) as Array
		bucket.append(panel)
		_column_panels[column_id] = bucket
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = false
	outer.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	scroll.add_child(content)
	return {"panel": panel, "scroll": scroll, "content": content}


func _add_column_toggle(parent: HBoxContainer, column_id: String, label: String) -> void:
	var btn := Button.new()
	btn.text = "Hide %s" % label
	_style_toolbar_button(btn)
	btn.pressed.connect(func() -> void:
		_set_column_visible(column_id, not bool(_column_visible.get(column_id, true)))
	)
	parent.add_child(btn)
	_column_toggle_btns[column_id] = btn


func _set_column_visible(column_id: String, visible: bool) -> void:
	_column_visible[column_id] = visible
	_apply_column_visibility()
	_save_layout_config()


func _apply_column_visibility() -> void:
	for column_id: String in _column_panels.keys():
		var visible: bool = bool(_column_visible.get(column_id, true))
		for panel_var: Variant in _column_panels[column_id] as Array:
			if panel_var is Control:
				(panel_var as Control).visible = visible
		var btn: Button = _column_toggle_btns.get(column_id) as Button
		if btn != null:
			btn.text = (
				"Hide %s" % _column_toggle_label(column_id)
				if visible
				else "Show %s" % _column_toggle_label(column_id)
			)


func _column_toggle_label(column_id: String) -> String:
	match column_id:
		"list":
			return "Skill List"
		"data":
			return "Ability Data"
		"impl":
			return "How It Works"
		_:
			return column_id.capitalize()


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
		vbox.remove_child(child)
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


func _bible_list_tooltip(display_name: String, item_id: String) -> String:
	var class_display: String = ""
	if _selected_unit != null:
		class_display = _selected_unit.display_name
	return _BibleText.lookup(display_name, class_display, item_id)


func _apply_bible_tooltip(
	card: Control,
	title: Label,
	preview: RichTextLabel,
	display_name: String,
	item_id: String,
) -> void:
	var tip: String = _bible_list_tooltip(display_name, item_id)
	if card != null:
		card.tooltip_text = tip
	if title != null:
		title.tooltip_text = tip
	if preview != null:
		preview.tooltip_text = tip


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
	var module_lines: PackedStringArray = CombatUiFormatters.ability_skill_module_lines_bbcode(
		ability,
		_preview_unit(),
	)
	var body: String = "\n".join(module_lines)
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
	var preview := RichTextLabel.new()
	preview.bbcode_enabled = true
	preview.scroll_active = false
	preview.fit_content = true
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size.y = ClassLibraryTheme.px(48 if ability != null else 88)
	preview.add_theme_color_override("default_color", ClassLibraryTheme.TEXT_PRIMARY)
	preview.add_theme_font_size_override("normal_font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_inner.add_child(preview)
	var sync_preview_width := func() -> void:
		_sync_list_preview_width(preview, preview_wrap)
	preview.tree_entered.connect(sync_preview_width)
	preview_wrap.resized.connect(sync_preview_width)
	var bible_id: String = ""
	if ability != null:
		bible_id = String(ability.id)
	elif passive != null:
		bible_id = String(passive.id)
	_apply_bible_tooltip(card, name_lbl, preview, title_text, bible_id)
	return {
		"card": card,
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
	_reveal_selected_list_card(_list_item_cards, _entry_key_ability(ability), _list_scroll)


func _select_passive_entry(passive: PassiveData) -> void:
	_selected_passive = passive
	_selected_ability = null
	_set_active_class_list_item(_entry_key_passive(passive), ClassLibraryTheme.ACCENT_PASSIVE)
	_rebuild_passive_detail_panes(passive)
	_reveal_selected_list_card(_class_list_item_cards, _entry_key_passive(passive), _class_list_scroll)


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
	if ability != null:
		_field_tracks[ability.id] = []
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
	_apply_bible_tooltip(
		refs.get("card") as Control,
		title,
		refs.get("preview") as RichTextLabel,
		passive.display_name,
		String(passive.id),
	)
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


func _reveal_selected_list_card(card_registry: Dictionary, key: String, scroll: ScrollContainer) -> void:
	if scroll == null or key.is_empty() or not card_registry.has(key):
		return
	var card: PanelContainer = card_registry[key]
	if not is_instance_valid(card):
		return
	if card.size.y <= 1.0:
		scroll.call_deferred("ensure_control_visible", card)
		return
	scroll.ensure_control_visible(card)


func _sync_list_preview_width(preview: RichTextLabel, host: PanelContainer) -> void:
	if preview == null or host == null:
		return
	var margin: float = ClassLibraryTheme.px(ClassLibraryTheme.SPACE_MD) * 2.0
	var panel_style: StyleBox = host.get_theme_stylebox("panel")
	if panel_style is StyleBoxFlat:
		var flat: StyleBoxFlat = panel_style as StyleBoxFlat
		margin = flat.content_margin_left + flat.content_margin_right
	var next_w: float = maxf(host.size.x - margin, 1.0)
	if is_equal_approx(preview.custom_minimum_size.x, next_w):
		return
	preview.custom_minimum_size.x = next_w


func _refresh_passive_preview(passive: PassiveData, preview: RichTextLabel) -> void:
	CombatUiFormatters.configure_body_font(ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	preview.text = ClassLibrarySchema.passive_preview_bbcode(passive)


func _populate_ability_data_editor(parent: VBoxContainer, ability: AbilityData) -> void:
	_field_tracks.erase(ability.id)
	_normalize_editor_modules(ability)
	ability.finalize_modular()
	if not _ability_ui.has(ability):
		_ability_ui[ability] = {}
	_ability_ui[ability]["module_grey_cbs"] = []
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_SM))
	grid.add_theme_constant_override("v_separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_XS))
	parent.add_child(grid)
	var planner_row := _bind_enum(
		grid, "planner_group", GameEnums.PlannerGroup, ability.planner_group,
		func(v: int) -> void:
			ability.planner_group = v
			if v == GameEnums.PlannerGroup.PRE_MOVE:
				ability.primary_resource = GameEnums.CostResource.MP
			else:
				ability.primary_resource = GameEnums.CostResource.AP
			ability.finalize_modular()
			_rebuild_ability_detail_panes(ability)
	)
	_track_ability_field(ability, "planner_group", planner_row)
	var upgrade_pre_move_row := _bind_bool(
		grid,
		"Upgrade is Pre-Move",
		ability.upgraded_planner_group == GameEnums.PlannerGroup.PRE_MOVE,
		func(v: bool) -> void:
			ability.upgraded_planner_group = (
				GameEnums.PlannerGroup.PRE_MOVE if v else -1
			)
			ability.finalize_modular()
			_rebuild_ability_detail_panes(ability)
	)
	_track_ability_field(ability, "upgraded_planner_group", upgrade_pre_move_row)
	var tags_row := _bind_string(grid, "tags", _tags_to_csv(ability.tags), func(v: String) -> void:
		ability.tags = _validated_tags_from_csv(v)
		_refresh_ability_ui(ability)
	)
	_track_ability_field(ability, "tags", tags_row)
	var resource_row := _bind_enum(
		grid, "Primary Resource", GameEnums.CostResource, ability.primary_resource,
		func(v: int) -> void:
			ability.primary_resource = v as GameEnums.CostResource
			if ability.planner_group == GameEnums.PlannerGroup.PRE_MOVE:
				ability.primary_resource = GameEnums.CostResource.MP
			else:
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
	var once_row := _bind_bool(grid, "Once Per Turn", ability.once_per_turn, func(v: bool) -> void:
		ability.once_per_turn = v
		ability.finalize_modular()
		_refresh_ability_ui(ability)
	)
	_track_ability_field(ability, "once_per_turn", once_row)
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
	module.primary_type = GameEnums.EffectType.DAMAGE
	module.amount = 1
	module.min_range = 1
	module.max_range = 1
	module.targeting_flags = (
		GameEnums.TargetingFlags.TILE
		if ability.planner_group == GameEnums.PlannerGroup.PRE_MOVE
		else GameEnums.TargetingFlags.ENEMY
	)
	return module


func _normalize_editor_modules(ability: AbilityData) -> void:
	for index: int in ability.modules.size():
		var module: AbilityModule = ability.modules[index]
		if module == null:
			continue
		if (
			module.primary_type == GameEnums.EffectType.MOVE
			or GameEnums.is_path_motion(module.primary_type)
			or module.primary_type == GameEnums.EffectType.DASH
		):
			module.min_range = maxi(1, module.min_range)
		if module.max_range < module.min_range:
			module.max_range = module.min_range
		if module.primary_type == GameEnums.EffectType.SWAP:
			module.target_shape = GameEnums.TargetShape.SINGLE
		AbilityModuleBridge.normalize_module_authoring_fields(
			module, ability.planner_group, index
		)
	for index: int in ability.upgraded_modules.size():
		var upgraded_module: AbilityModule = ability.upgraded_modules[index]
		if upgraded_module == null:
			continue
		if (
			upgraded_module.primary_type == GameEnums.EffectType.MOVE
			or GameEnums.is_path_motion(upgraded_module.primary_type)
			or upgraded_module.primary_type == GameEnums.EffectType.DASH
		):
			upgraded_module.min_range = maxi(1, upgraded_module.min_range)
		if upgraded_module.max_range < upgraded_module.min_range:
			upgraded_module.max_range = upgraded_module.min_range
		if upgraded_module.primary_type == GameEnums.EffectType.SWAP:
			upgraded_module.target_shape = GameEnums.TargetShape.SINGLE
		AbilityModuleBridge.normalize_module_authoring_fields(
			upgraded_module, ability.planner_group, index
		)


func _apply_module_field_greying(
	module: AbilityModule,
	rows: Dictionary,
	ability: AbilityData,
	module_index: int,
) -> void:
	_grey_row(rows.get("phase", []), not ModuleAuthoringRules.module_uses_phase(ability.planner_group))
	_grey_row(
		rows.get("scaling", []),
		not GameEnums.effect_type_uses_module_scaling(module.primary_type),
	)
	_grey_row(
		rows.get("motion_mode", []),
		not ModuleAuthoringRules.module_uses_motion_mode(module.primary_type),
	)
	_grey_row(rows.get("min_range", []), not ModuleAuthoringRules.module_uses_range(module))
	_grey_row(rows.get("max_range", []), not ModuleAuthoringRules.module_uses_range(module))
	_grey_row(rows.get("requires_los", []), not ModuleAuthoringRules.module_uses_los(module))
	_grey_row(
		rows.get("range_origin", []),
		not ModuleAuthoringRules.module_uses_range_origin(module, module_index),
	)
	_grey_row(rows.get("hit_count", []), not ModuleAuthoringRules.module_uses_hit_count(module))
	_grey_row(rows.get("adjacent_bonus", []), module.primary_type != GameEnums.EffectType.DAMAGE)
	_grey_row(rows.get("def_debuff", []), module.primary_type != GameEnums.EffectType.DAMAGE)
	_grey_row(rows.get("shape", []), not ModuleAuthoringRules.module_uses_shape(module))
	_grey_row(rows.get("shape_size", []), not ModuleAuthoringRules.module_uses_shape_size(module))
	_grey_row(rows.get("condition_hp", []), not ModuleAuthoringRules.module_uses_target_filter_hp(module))
	_grey_row(
		rows.get("condition_hp_pct", []),
		not ModuleAuthoringRules.module_uses_target_filter_hp_pct(module),
	)
	_grey_row(
		rows.get("condition_status", []),
		not ModuleAuthoringRules.module_uses_target_filter_status(module),
	)
	_grey_row(
		rows.get("condition_status_type", []),
		not ModuleAuthoringRules.module_uses_target_filter_status_type(module),
	)
	_grey_row(
		rows.get("condition_status_or", []),
		not ModuleAuthoringRules.module_uses_target_filter_status_type(module),
	)
	_grey_row(rows.get("condition_stat", []), not ModuleAuthoringRules.module_uses_target_filter_stat(module))
	_grey_row(
		rows.get("condition_occupant", []),
		not ModuleAuthoringRules.module_uses_target_filter_occupant(module),
	)


func _refresh_module_field_greying(ability: AbilityData) -> void:
	if not _ability_ui.has(ability):
		return
	for cb: Callable in _ability_ui[ability].get("module_grey_cbs", []):
		if cb.is_valid():
			cb.call()


func _module_min_range(module: AbilityModule) -> int:
	if (
		module.primary_type == GameEnums.EffectType.MOVE
		or module.primary_type == GameEnums.EffectType.DASH
	):
		return 1
	return 0


func _on_modules_edited(
	ability: AbilityData,
	parent: VBoxContainer,
	upgraded: bool,
) -> void:
	var modules: Array[AbilityModule] = (
		ability.upgraded_modules if upgraded else ability.modules
	)
	if modules.is_empty():
		AbilityModuleBridge.clear_module_profile(ability, upgraded)
	_normalize_editor_modules(ability)
	ability.finalize_modular()
	_rebuild_modules_editor(parent, ability, modules, upgraded)
	_refresh_ability_ui(ability)


func _on_module_field_edited(ability: AbilityData) -> void:
	_normalize_editor_modules(ability)
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
		_build_module_fields(panel, ability, module, modules, upgraded, index)


func _build_module_fields(
	parent: VBoxContainer,
	ability: AbilityData,
	module: AbilityModule,
	modules: Array[AbilityModule],
	upgraded: bool,
	module_index: int,
) -> void:
	_normalize_editor_modules(ability)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("v_separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_XS))
	parent.add_child(grid)
	var changed := func() -> void: _on_module_field_edited(ability)
	var rebuild_detail := func() -> void:
		_normalize_editor_modules(ability)
		ability.finalize_modular()
		_rebuild_ability_detail_panes(ability)
	var grey_rows: Dictionary = {}
	grey_rows["phase"] = _bind_enum_excluding(
		grid,
		"Phase",
		GameEnums.ModulePhase,
		module.execution_phase,
		func(v: int) -> void:
			module.execution_phase = v
			changed.call(),
		ModuleAuthoringRules.excluded_module_phases(ability.planner_group),
	)
	_bind_effect_type(grid, "Primary", module.primary_type, func(v: int) -> void:
		module.primary_type = v
		rebuild_detail.call()
	)
	_bind_int(grid, "Amount", module.amount, func(v: int) -> void:
		module.amount = v
		changed.call()
	)
	grey_rows["hit_count"] = _bind_int(grid, "Hit Count", module.hit_count, func(v: int) -> void:
		module.hit_count = v
		changed.call()
	, 1)
	if GameEnums.effect_type_applies_status(module.primary_type):
		_bind_enum_excluding(
			grid,
			"Status",
			GameEnums.StatusType,
			module.status_type,
			func(v: int) -> void:
				module.status_type = v
				changed.call(),
			PackedStringArray(["NONE"]),
		)
		_bind_int(grid, "Duration", module.status_duration, func(v: int) -> void:
			module.status_duration = v
			changed.call()
		)
	if GameEnums.effect_type_uses_spawn_unit(module.primary_type):
		_bind_string(grid, "Spawn Unit Id", String(module.spawn_unit_id), func(v: String) -> void:
			module.spawn_unit_id = StringName(v)
			changed.call()
		)
	grey_rows["scaling"] = _bind_enum(grid, "Scaling", GameEnums.StatType, module.scaling_stat, func(v: int) -> void:
		module.scaling_stat = v
		changed.call()
	)
	grey_rows["motion_mode"] = _bind_enum(grid, "Motion Mode", GameEnums.MotionMode, module.motion_mode, func(v: int) -> void:
		module.motion_mode = v
		changed.call()
	)
	var min_range_setter := func(v: int) -> void:
		module.min_range = v
		changed.call()
	grey_rows["min_range"] = _bind_int(
		grid, "Min Range", module.min_range, min_range_setter, _module_min_range(module)
	)
	grey_rows["max_range"] = _bind_int(grid, "Max Range", module.max_range, func(v: int) -> void:
		module.max_range = v
		changed.call()
	)
	grey_rows["requires_los"] = _bind_bool(grid, "Requires LOS", module.requires_los, func(v: bool) -> void:
		module.requires_los = v
		changed.call()
	)
	grey_rows["range_origin"] = _bind_enum(grid, "Range Origin", GameEnums.RangeOrigin, module.range_origin, func(v: int) -> void:
		module.range_origin = v
		changed.call()
	)
	var shape_row := _bind_enum(
		grid, "Shape", GameEnums.TargetShape, module.target_shape, func(v: int) -> void:
			if module.primary_type == GameEnums.EffectType.SWAP:
				module.target_shape = GameEnums.TargetShape.SINGLE
			else:
				module.target_shape = v
			changed.call()
			_refresh_module_field_greying(ability)
	)
	grey_rows["shape"] = shape_row
	var shape_size_setter := func(v: int) -> void:
		module.target_shape_size = v
		changed.call()
	var shape_size_row := _bind_int(
		grid, "Radius (1 = 3×3)", module.target_shape_size, shape_size_setter, 1
	)
	grey_rows["shape_size"] = shape_size_row
	grey_rows["gate"] = _bind_enum_excluding(
		grid,
		"Gate",
		GameEnums.ModuleGate,
		module.gate,
		func(v: int) -> void:
			module.gate = v
			changed.call(),
		ModuleAuthoringRules.excluded_module_gates(module),
	)
	grey_rows["condition"] = _bind_enum(
		grid, "Condition", GameEnums.ModuleTargetFilter, module.target_filter, func(v: int) -> void:
			module.target_filter = v
			changed.call()
			_refresh_module_field_greying(ability)
	)
	grey_rows["condition_hp"] = _bind_enum(
		grid, "HP Rule", GameEnums.ModuleTargetFilterHp, module.target_filter_hp, func(v: int) -> void:
			module.target_filter_hp = v
			changed.call()
			_refresh_module_field_greying(ability)
	)
	grey_rows["condition_hp_pct"] = _bind_int(
		grid, "HP %", module.target_filter_hp_pct, func(v: int) -> void:
			module.target_filter_hp_pct = v
			changed.call()
	, 1)
	grey_rows["condition_status"] = _bind_enum(
		grid,
		"Status Rule",
		GameEnums.ModuleTargetFilterStatus,
		module.target_filter_status_mode,
		func(v: int) -> void:
			module.target_filter_status_mode = v
			changed.call()
			_refresh_module_field_greying(ability)
	)
	grey_rows["condition_status_type"] = _bind_enum(
		grid,
		"Status",
		GameEnums.StatusType,
		module.target_filter_status,
		func(v: int) -> void:
			module.target_filter_status = v
			changed.call(),
	)
	grey_rows["condition_status_or"] = _bind_enum(
		grid,
		"Status OR",
		GameEnums.StatusType,
		module.target_filter_status_or,
		func(v: int) -> void:
			module.target_filter_status_or = v
			changed.call(),
	)
	grey_rows["condition_stat"] = _bind_enum(
		grid, "Stat Rule", GameEnums.ModuleTargetFilterStat, module.target_filter_stat, func(v: int) -> void:
			module.target_filter_stat = v
			changed.call()
	)
	grey_rows["condition_occupant"] = _bind_enum(
		grid,
		"Occupant",
		GameEnums.ModuleTargetFilterOccupant,
		module.target_filter_occupant,
		func(v: int) -> void:
			module.target_filter_occupant = v
			changed.call()
	)
	_bind_enum(grid, "Presentation", GameEnums.PresentationAnim, module.presentation_anim, func(v: int) -> void:
		module.presentation_anim = v
		changed.call()
	)
	grey_rows["adjacent_bonus"] = _bind_int(grid, "Adjacent Bonus", module.bonus_if_adjacent_at_cast, func(v: int) -> void:
		module.bonus_if_adjacent_at_cast = v
		changed.call()
	)
	grey_rows["def_debuff"] = _bind_int(grid, "DEF Debuff", module.def_debuff_before_damage, func(v: int) -> void:
		module.def_debuff_before_damage = v
		changed.call()
	)
	var module_grey_cb := func() -> void:
		_apply_module_field_greying(module, grey_rows, ability, module_index)
	_ability_ui[ability]["module_grey_cbs"].append(module_grey_cb)
	module_grey_cb.call()
	_add_module_targeting_flags(parent, ability, module)
	_add_module_typed_extras_editor(parent, ability, module)
	_add_module_keywords_editor(parent, ability, module)
	_add_module_layers_editor(parent, ability, module)
	_add_module_extras_editor(parent, ability, module)


func _add_module_targeting_flags(
	parent: VBoxContainer,
	ability: AbilityData,
	module: AbilityModule,
) -> void:
	_add_subsection_label(parent, "Module Targeting — who you click", ClassLibraryTheme.ACCENT_DATA)
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
		var dash_greyed: bool = not ModuleAuthoringRules.targeting_flag_applies(module, flag)
		check.disabled = dash_greyed
		check.modulate.a = 0.35 if dash_greyed else 1.0
		check.toggled.connect(func(enabled: bool) -> void:
			if enabled:
				module.targeting_flags |= flag
			else:
				module.targeting_flags &= ~flag
			_on_module_field_edited(ability)
		)
		row.add_child(check)
	_add_subsection_label(parent, "Module Targeting — blast", ClassLibraryTheme.ACCENT_DATA)
	var blast_row := HBoxContainer.new()
	blast_row.add_theme_constant_override("separation", ClassLibraryTheme.px(ClassLibraryTheme.SPACE_MD))
	parent.add_child(blast_row)
	var skip := CheckBox.new()
	skip.text = "Skip caster in blast"
	skip.button_pressed = module.exclude_caster or module.has_targeting(GameEnums.TargetingFlags.EXCLUDE_CASTER)
	var skip_greyed: bool = not ModuleAuthoringRules.targeting_flag_applies(
		module, GameEnums.TargetingFlags.EXCLUDE_CASTER
	)
	skip.disabled = skip_greyed
	skip.modulate.a = 0.35 if skip_greyed else 1.0
	skip.toggled.connect(func(enabled: bool) -> void:
		module.exclude_caster = enabled
		if enabled:
			module.targeting_flags |= GameEnums.TargetingFlags.EXCLUDE_CASTER
		else:
			module.targeting_flags &= ~GameEnums.TargetingFlags.EXCLUDE_CASTER
		_on_module_field_edited(ability)
	)
	blast_row.add_child(skip)


func _add_module_typed_extras_editor(
	parent: VBoxContainer,
	ability: AbilityData,
	module: AbilityModule,
) -> void:
	_add_subsection_label(parent, "Typed Skill Fields", ClassLibraryTheme.ACCENT_DATA)
	var grid := GridContainer.new()
	grid.columns = 2
	parent.add_child(grid)
	_bind_string(grid, "Terrain Id", String(module.terrain_id), func(v: String) -> void:
		module.terrain_id = StringName(v)
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Hazard Duration", module.hazard_duration, func(v: int) -> void:
		module.hazard_duration = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_enum(grid, "Hazard Status", GameEnums.StatusType, module.hazard_status, func(v: int) -> void:
		module.hazard_status = v as GameEnums.StatusType
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Bonus Dmg Occupied", module.bonus_dmg_from_occupied, func(v: int) -> void:
		module.bonus_dmg_from_occupied = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Bonus Dmg /10 HP", module.bonus_dmg_per_10_hp, func(v: int) -> void:
		module.bonus_dmg_per_10_hp = v
		_on_module_field_edited(ability)
	)
	_bind_string(
		grid,
		"Bonus Dmg % Max HP",
		str(module.bonus_dmg_pct_max_hp),
		func(v: String) -> void:
			if v.strip_edges().is_valid_float():
				module.bonus_dmg_pct_max_hp = maxf(0.0, float(v))
				_on_module_field_edited(ability)
	)
	_bind_int(grid, "Heal If Targets >=", module.heal_if_targets_gte, func(v: int) -> void:
		module.heal_if_targets_gte = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Bounce Count", module.bounce_count, func(v: int) -> void:
		module.bounce_count = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Bounce Range", module.bounce_range, func(v: int) -> void:
		module.bounce_range = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Buff On Push", module.buff_on_push, func(v: int) -> void:
		module.buff_on_push = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Frenzy On Kill AP", module.frenzy_on_kill_ap, func(v: int) -> void:
		module.frenzy_on_kill_ap = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Push Board Items", module.push_board_items, func(v: int) -> void:
		module.push_board_items = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Item Collision Damage", module.item_collision_damage, func(v: int) -> void:
		module.item_collision_damage = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Item Collision STR Div", module.item_collision_str_div, func(v: int) -> void:
		module.item_collision_str_div = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_int(
		grid,
		"Item Collision Vulnerable",
		module.item_collision_vulnerable,
		func(v: int) -> void:
			module.item_collision_vulnerable = maxi(0, v)
			_on_module_field_edited(ability)
	)
	_bind_int(
		grid,
		"Violent Collision Recast",
		module.violent_collision_recast,
		func(v: int) -> void:
			module.violent_collision_recast = maxi(0, v)
			_on_module_field_edited(ability)
	)
	_bind_int(grid, "Next Attack Strength", module.next_attack_strength, func(v: int) -> void:
		module.next_attack_strength = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_bool(
		grid,
		"Next Attack BLEED WPN",
		module.next_attack_bleed_weapon,
		func(v: bool) -> void:
			module.next_attack_bleed_weapon = v
			_on_module_field_edited(ability),
	)
	_bind_bool(grid, "Next Turn", module.next_turn, func(v: bool) -> void:
		module.next_turn = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Preserve Facing", module.preserve_facing, func(v: bool) -> void:
		module.preserve_facing = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Ignore ZOC", module.ignore_zoc, func(v: bool) -> void:
		module.ignore_zoc = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Next Ranged Attack STR", module.next_ranged_attack_strength, func(v: int) -> void:
		module.next_ranged_attack_strength = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Root Break On Damage", module.root_break_on_damage, func(v: bool) -> void:
		module.root_break_on_damage = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Skewer", module.skewer, func(v: int) -> void:
		module.skewer = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Bounce Walls 45", module.bounce_walls_45, func(v: bool) -> void:
		module.bounce_walls_45 = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Spread Status Adjacent", module.spread_status_adjacent, func(v: bool) -> void:
		module.spread_status_adjacent = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Grapple Wall Pull Self", module.grapple_wall_pull_self, func(v: bool) -> void:
		module.grapple_wall_pull_self = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Grapple Pass Damage", module.grapple_pass_through_damage, func(v: int) -> void:
		module.grapple_pass_through_damage = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Destroy Terrain", module.destroy_terrain, func(v: bool) -> void:
		module.destroy_terrain = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Ignite Flammable Terrain", module.ignite_flammable_terrain, func(v: bool) -> void:
		module.ignite_flammable_terrain = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Allies Range Bonus", module.allies_range_bonus, func(v: int) -> void:
		module.allies_range_bonus = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Allies Pierce", module.allies_pierce, func(v: bool) -> void:
		module.allies_pierce = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Prevent Stealth Teleport", module.prevent_stealth_teleport, func(v: bool) -> void:
		module.prevent_stealth_teleport = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Allow Friendly Target", module.allow_friendly_target, func(v: bool) -> void:
		module.allow_friendly_target = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Ally Damage Zero", module.ally_damage_zero, func(v: bool) -> void:
		module.ally_damage_zero = v
		_on_module_field_edited(ability)
	)
	_bind_enum(grid, "Terrain Hazard Status", GameEnums.StatusType, module.terrain_hazard_status, func(v: int) -> void:
		module.terrain_hazard_status = v as GameEnums.StatusType
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Trap Damage", module.trap_damage, func(v: int) -> void:
		module.trap_damage = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Trap BLEED WPN", module.trap_bleed_weapon, func(v: bool) -> void:
		module.trap_bleed_weapon = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Trap Vulnerable", module.trap_vulnerable, func(v: bool) -> void:
		module.trap_vulnerable = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Crossing WPN Damage", module.crossing_weapon_damage, func(v: bool) -> void:
		module.crossing_weapon_damage = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Crossing MOV Penalty", module.crossing_mov_penalty, func(v: int) -> void:
		module.crossing_mov_penalty = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Crossing BLIND", module.crossing_blind, func(v: bool) -> void:
		module.crossing_blind = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Trap DEF Debuff", module.trap_def_debuff, func(v: int) -> void:
		module.trap_def_debuff = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Strip Stealth", module.strip_stealth, func(v: bool) -> void:
		module.strip_stealth = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Limit Once Per Turn", module.limit_once_per_turn, func(v: bool) -> void:
		module.limit_once_per_turn = v
		_on_module_field_edited(ability)
	)
	_bind_string(
		grid,
		"Range 1 Damage Multiplier",
		str(module.range_one_damage_multiplier),
		func(v: String) -> void:
			if v.strip_edges().is_valid_float():
				module.range_one_damage_multiplier = maxf(0.0, float(v))
				_on_module_field_edited(ability),
	)
	_bind_bool(grid, "Halve Target DEF", module.halve_target_def_one_turn, func(v: bool) -> void:
		module.halve_target_def_one_turn = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Armor Explosion ATK", module.armor_explosion_atk, func(v: int) -> void:
		module.armor_explosion_atk = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Bonus ATK Fear/Low MOV", module.bonus_atk_vs_fear_or_lower_movement, func(v: int) -> void:
		module.bonus_atk_vs_fear_or_lower_movement = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "On Kill MAX MOV", module.on_kill_max_move, func(v: int) -> void:
		module.on_kill_max_move = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Next Turn MAX MOV", module.next_turn_max_move, func(v: int) -> void:
		module.next_turn_max_move = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Upgraded TRAMPLE", module.upgraded_trample, func(v: bool) -> void:
		module.upgraded_trample = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Brace Attacker Stagger", module.brace_attacker_stagger, func(v: int) -> void:
		module.brace_attacker_stagger = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Pull Until Adjacent", module.pull_until_adjacent, func(v: bool) -> void:
		module.pull_until_adjacent = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Pull Self If Rooted", module.pull_self_if_rooted, func(v: bool) -> void:
		module.pull_self_if_rooted = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Paired Ally Charge", module.paired_ally_charge, func(v: bool) -> void:
		module.paired_ally_charge = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Paired Ally Strike ATK", module.paired_ally_strike_atk, func(v: int) -> void:
		module.paired_ally_strike_atk = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "On Kill Both AP", module.on_kill_both_ap, func(v: int) -> void:
		module.on_kill_both_ap = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Vault Obstacle/Gap Only", module.vault_obstacle_or_gap_only, func(v: bool) -> void:
		module.vault_obstacle_or_gap_only = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Landing Adjacent PUSH", module.landing_adjacent_push, func(v: int) -> void:
		module.landing_adjacent_push = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Landing Adjacent STAGGER", module.landing_adjacent_push_stagger, func(v: bool) -> void:
		module.landing_adjacent_push_stagger = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Line Breaker", module.line_breaker, func(v: bool) -> void:
		module.line_breaker = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Bonus Per Enemy Passed", module.bonus_per_enemy_passed, func(v: int) -> void:
		module.bonus_per_enemy_passed = maxi(0, v)
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Create Trampled Terrain", module.create_trampled_terrain, func(v: bool) -> void:
		module.create_trampled_terrain = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Blink", module.blink, func(v: bool) -> void:
		module.blink = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Leave Elemental Surface", module.leave_elemental_surface, func(v: bool) -> void:
		module.leave_elemental_surface = v
		_on_module_field_edited(ability)
	)
	_bind_string(grid, "Reaction Terrain", str(module.reaction_terrain), func(v: String) -> void:
		module.reaction_terrain = StringName(v)
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Reaction Damage", module.reaction_damage, func(v: int) -> void:
		module.reaction_damage = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Surface Chain", module.bounce_surface_chain, func(v: bool) -> void:
		module.bounce_surface_chain = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Lightning Surface", module.lightning_surface, func(v: bool) -> void:
		module.lightning_surface = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Strike All Surface", module.strike_all_surface, func(v: bool) -> void:
		module.strike_all_surface = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Teleport Visible", module.teleport_visible, func(v: bool) -> void:
		module.teleport_visible = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Delayed Next Turn", module.delayed_next_turn, func(v: bool) -> void:
		module.delayed_next_turn = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Create Crater", module.create_crater, func(v: bool) -> void:
		module.create_crater = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Pull To Center", module.pull_to_center, func(v: bool) -> void:
		module.pull_to_center = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Pull Surfaces", module.pull_surfaces, func(v: bool) -> void:
		module.pull_surfaces = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Mana Shield", module.mana_shield, func(v: bool) -> void:
		module.mana_shield = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Mana Shield Casting", module.mana_shield_casting, func(v: bool) -> void:
		module.mana_shield_casting = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Destroy Corpse On Kill", module.destroy_corpse_on_kill, func(v: bool) -> void:
		module.destroy_corpse_on_kill = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Kill Grant AP", module.kill_grant_ap, func(v: int) -> void:
		module.kill_grant_ap = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Utility Only", module.utility_only, func(v: bool) -> void:
		module.utility_only = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Elemental Surge", module.elemental_surge, func(v: bool) -> void:
		module.elemental_surge = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Elemental Surge AP", module.elemental_surge_ap, func(v: int) -> void:
		module.elemental_surge_ap = v
		_on_module_field_edited(ability)
	)
	_bind_string(grid, "Construct HP %", str(module.construct_hp_pct), func(v: String) -> void:
		if v.is_valid_float():
			module.construct_hp_pct = float(v)
			_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Density Shift", module.density_shift, func(v: bool) -> void:
		module.density_shift = v
		_on_module_field_edited(ability)
	)
	_bind_string(grid, "Ignore Target MAG %", str(module.ignore_target_magic_pct), func(v: String) -> void:
		if v.is_valid_float():
			module.ignore_target_magic_pct = float(v)
			_on_module_field_edited(ability)
	)
	_bind_int(grid, "Creation Adjacent Damage", module.creation_adjacent_damage, func(v: int) -> void:
		module.creation_adjacent_damage = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Apply WEAKEN Enemy", module.apply_weaken_enemy, func(v: bool) -> void:
		module.apply_weaken_enemy = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Cost All Movement", module.cost_all_movement, func(v: bool) -> void:
		module.cost_all_movement = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Cleanse Target", module.cleanse_target, func(v: bool) -> void:
		module.cleanse_target = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "MAG HEAL", module.mag_heal, func(v: bool) -> void:
		module.mag_heal = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Enemy MAG ATK", module.enemy_mag_atk, func(v: int) -> void:
		module.enemy_mag_atk = v
		_on_module_field_edited(ability)
	)
	_bind_string(grid, "Shield Closest Ally %", str(module.shield_closest_ally_pct_damage), func(v: String) -> void:
		if v.is_valid_float():
			module.shield_closest_ally_pct_damage = float(v)
			_on_module_field_edited(ability)
	)
	_bind_int(grid, "Ally STR Per Debuff", module.ally_str_per_debuff, func(v: int) -> void:
		module.ally_str_per_debuff = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Sanctuary", module.sanctuary, func(v: bool) -> void:
		module.sanctuary = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Sanctuary Enemy PUSH", module.sanctuary_enemy_push, func(v: int) -> void:
		module.sanctuary_enemy_push = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Creation Adjacent PUSH", module.creation_adjacent_push, func(v: int) -> void:
		module.creation_adjacent_push = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Holy Aura", module.holy_aura, func(v: bool) -> void:
		module.holy_aura = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Life Link", module.life_link, func(v: bool) -> void:
		module.life_link = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Life Link Reduction", module.life_link_reduction, func(v: int) -> void:
		module.life_link_reduction = v
		_on_module_field_edited(ability)
	)
	_bind_string(grid, "Revive Max HP %", str(module.revive_percent_max_hp), func(v: String) -> void:
		if v.is_valid_float():
			module.revive_percent_max_hp = float(v)
			_on_module_field_edited(ability)
	)
	_bind_int(grid, "Spend Self HP", module.spend_self_hp, func(v: int) -> void:
		module.spend_self_hp = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Revive Shield", module.revive_shield, func(v: int) -> void:
		module.revive_shield = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Holy Ground", module.holy_ground, func(v: bool) -> void:
		module.holy_ground = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Holy Ground Zone", module.holy_ground_zone, func(v: bool) -> void:
		module.holy_ground_zone = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Holy Ground DEF Down", module.holy_ground_def_down, func(v: int) -> void:
		module.holy_ground_def_down = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Stagger If Debuffed", module.stagger_if_debuffed, func(v: bool) -> void:
		module.stagger_if_debuffed = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "PUSH", module.push, func(v: int) -> void:
		module.push = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Grant AP", module.grant_ap, func(v: int) -> void:
		module.grant_ap = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Self Move Zero Next Turn", module.self_move_zero_next_turn, func(v: bool) -> void:
		module.self_move_zero_next_turn = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Link Two Enemies", module.link_two_enemies, func(v: bool) -> void:
		module.link_two_enemies = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Magic Link Damage", module.magic_link_damage, func(v: int) -> void:
		module.magic_link_damage = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Link Partner Pick", module.link_partner_pick, func(v: bool) -> void:
		module.link_partner_pick = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Link Blind", module.link_blind, func(v: bool) -> void:
		module.link_blind = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Pullback", module.pullback, func(v: bool) -> void:
		module.pullback = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Pullback Ally DEF", module.pullback_ally_def, func(v: int) -> void:
		module.pullback_ally_def = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Movement MP Override", module.movement_mp_override, func(v: int) -> void:
		module.movement_mp_override = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Swift Strike", module.swift_strike, func(v: bool) -> void:
		module.swift_strike = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Target Damaged AP", module.target_damaged_ap, func(v: int) -> void:
		module.target_damaged_ap = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Remove Push Mitigation", module.remove_push_mitigation, func(v: bool) -> void:
		module.remove_push_mitigation = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Prevent Target Shield", module.prevent_target_shield, func(v: bool) -> void:
		module.prevent_target_shield = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Adjacent Ally Bonus", module.bonus_if_target_adjacent_to_ally, func(v: int) -> void:
		module.bonus_if_target_adjacent_to_ally = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Pierce", module.pierce, func(v: bool) -> void:
		module.pierce = v
		_on_module_field_edited(ability)
	)
	_bind_float(grid, "Target DEF % Debuff", module.target_def_pct_debuff, func(v: float) -> void:
		module.target_def_pct_debuff = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Target DEF % Duration", module.target_def_pct_duration, func(v: int) -> void:
		module.target_def_pct_duration = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Riposte Bonus", module.if_target_attacked_caster_last_turn_bonus, func(v: int) -> void:
		module.if_target_attacked_caster_last_turn_bonus = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Riposte Stagger", module.if_target_attacked_caster_last_turn_stagger, func(v: bool) -> void:
		module.if_target_attacked_caster_last_turn_stagger = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Target DEF Debuff", module.target_def_debuff, func(v: int) -> void:
		module.target_def_debuff = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Kill Allies Heal", module.on_kill_all_allies_heal, func(v: int) -> void:
		module.on_kill_all_allies_heal = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Kill Allies Shield", module.on_kill_all_allies_shield, func(v: int) -> void:
		module.on_kill_all_allies_shield = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Next Skill Zero AP", module.next_skill_zero_ap, func(v: bool) -> void:
		module.next_skill_zero_ap = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Smoke On Start", module.smoke_on_start, func(v: bool) -> void:
		module.smoke_on_start = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Flank Enemy Bonus", module.flank_run_adjacent_enemy_bonus, func(v: int) -> void:
		module.flank_run_adjacent_enemy_bonus = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Bleed Bonus Damage", module.bleed_bonus_damage, func(v: int) -> void:
		module.bleed_bonus_damage = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Duelist Mark Target", module.duelist_mark_target, func(v: bool) -> void:
		module.duelist_mark_target = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Marked Target DEF", module.marked_target_defense, func(v: int) -> void:
		module.marked_target_defense = v
		_on_module_field_edited(ability)
	)
	_bind_float(grid, "Unacted Target DEF Ignore", module.unacted_target_ignore_def_pct, func(v: float) -> void:
		module.unacted_target_ignore_def_pct = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Leap Absorb Surface", module.leap_absorb_surface, func(v: bool) -> void:
		module.leap_absorb_surface = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Track First Hit Zero", module.track_first_hit_zero, func(v: bool) -> void:
		module.track_first_hit_zero = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Chakra Shift", module.chakra_shift, func(v: bool) -> void:
		module.chakra_shift = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Chakra Burst Damage", module.chakra_burst_damage, func(v: int) -> void:
		module.chakra_burst_damage = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Chakra Burst Size", module.chakra_burst_size, func(v: int) -> void:
		module.chakra_burst_size = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Stop Adjacent First Enemy", module.stop_adjacent_first_enemy, func(v: bool) -> void:
		module.stop_adjacent_first_enemy = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Dash Absorb Element", module.dash_absorb_element, func(v: bool) -> void:
		module.dash_absorb_element = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Target Magic Defense", module.target_magic_defense, func(v: bool) -> void:
		module.target_magic_defense = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Steal Target MAG", module.steal_target_magic, func(v: int) -> void:
		module.steal_target_magic = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Next Turn MOV Penalty", module.next_turn_move_penalty, func(v: int) -> void:
		module.next_turn_move_penalty = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Bonus Per Target Status", module.bonus_per_target_status, func(v: int) -> void:
		module.bonus_per_target_status = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Mantra Peace Weaken", module.mantra_peace_weaken, func(v: bool) -> void:
		module.mantra_peace_weaken = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Inner Fire", module.inner_fire, func(v: bool) -> void:
		module.inner_fire = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Inner Fire Surface", module.inner_fire_surface, func(v: bool) -> void:
		module.inner_fire_surface = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Landed MAG Bonus", module.landed_magic_bonus, func(v: int) -> void:
		module.landed_magic_bonus = v
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "Enemy Pushed MOV", module.enemy_pushed_mov, func(v: int) -> void:
		module.enemy_pushed_mov = v
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "Blind On Pass Over", module.blind_on_pass_over, func(v: bool) -> void:
		module.blind_on_pass_over = v
		_on_module_field_edited(ability)
	)
	_bind_string(
		grid,
		"totem_kind",
		String(module.totem_kind),
		func(value: String) -> void:
			module.totem_kind = StringName(value)
			_on_module_field_edited(ability)
	)
	_add_typed_module_bindings(grid, ability, module)


func _add_typed_module_bindings(
	grid: GridContainer,
	ability: AbilityData,
	module: AbilityModule,
) -> void:
	for field_name: String in [
		"relocate_subject_only", "relocate_target", "move_active_totem",
		"curse_of_weakness", "push_mitigation_zero", "pulse_cleanse", "pulse_fire",
		"bloodlust", "bloodlust_bleed_on_attack", "hex", "wither", "hex_vulnerable",
		"voodoo_link", "shared_push", "terrify", "boss_fallback_purge_shield",
		"boss_fallback_vulnerable", "poison_spread_on_push_collision", "bone_spear",
		"echo_next_cast", "echo_upgraded", "sympathetic_bond", "link_ally_enemy",
		"ally_heal_enemy_wpn", "pain_spike", "linked_enemy_blind", "pulse_weaken",
		"slip_past", "land_opposite_target", "move_through_adjacent_unit", "shadow_step",
		"smoke_field", "smoke_stealth_outside_attackers", "grapple_bidirectional",
		"pull_self_or_target", "switcheroo", "inherit_incoming_attacks",
		"if_target_unacted_stagger", "on_kill_spread_silence_adjacent",
		"confusion_next_turn", "on_kill_refresh_mark_zero_ap", "kidnap",
		"swap_collision_stagger_both", "pierce_vs_blind", "hazard_blind_on_entry",
		"enemy_collision_stagger_both", "reposition_opposite_side",
		"pounce_land_adjacent", "feral_drag", "drag_remaining_movement",
		"redirect_incoming_damage", "drop_adjacent", "does_not_consume_action_slot",
		"purge_buffs", "run_down_push_bleed_weapon", "airlift_keep_caster",
	]:
		_bind_bool(grid, field_name, bool(module.get(field_name)), func(value: bool) -> void:
			module.set(field_name, value)
			_on_module_field_edited(ability)
		)
	for field_name: String in [
		"stat_str", "stat_def", "pulse_aoe", "pulse_heal", "pulse_mag_atk",
		"bloodlust_def", "bloodlust_mov", "bloodlust_hp", "shared_damage_wpn",
		"ranged_reduction", "melee_def", "enemy_damage_ally_heal",
		"bonus_damage_per_debuff", "heal_per_debuff", "linked_enemy_damage", "ghost_duration",
		"pulse_status", "ally_def_buff", "behind_target_strength",
		"smoke_ally_heal_per_turn", "trap_collision_damage_multiplier",
		"if_target_staggered_bonus", "bonus_if_target_debuffed",
		"reposition_movement_cost", "reposition_range", "pull_before_attack",
		"on_kill_shield", "run_down_pass_adjacent_push", "trample_atk",
		"intercept_push_attacker", "airlift_pickup_step", "airlift_drop_step",
		"airlift_ally_attack_strength",
	]:
		_bind_int(grid, field_name, int(module.get(field_name)), func(value: int) -> void:
			module.set(field_name, value)
			_on_module_field_edited(ability)
		)
	for field_name: String in ["drop_trap_damage_multiplier"]:
		_bind_float(grid, field_name, float(module.get(field_name)), func(value: float) -> void:
			module.set(field_name, value)
			_on_module_field_edited(ability)
		)
	for field_name: String in ["boss_damage_reduction", "ghost_hp_pct"]:
		_bind_float(grid, field_name, float(module.get(field_name)), func(value: float) -> void:
			module.set(field_name, value)
			_on_module_field_edited(ability)
		)


func _add_typed_layer_bindings(
	grid: GridContainer,
	ability: AbilityData,
	layer: AbilityLayer,
) -> void:
	_bind_bool(grid, "lightning_rod", layer.lightning_rod, func(value: bool) -> void:
		layer.lightning_rod = value
		_on_module_field_edited(ability)
	)
	_bind_bool(
		grid,
		"spawn_furthest_empty_on_line",
		layer.spawn_furthest_empty_on_line,
		func(value: bool) -> void:
			layer.spawn_furthest_empty_on_line = value
			_on_module_field_edited(ability)
	)
	_bind_float(
		grid,
		"construct_hp_pct",
		layer.construct_hp_pct,
		func(value: float) -> void:
			layer.construct_hp_pct = value
			_on_module_field_edited(ability)
	)
	_bind_int(grid, "movement_penalty", layer.movement_penalty, func(value: int) -> void:
		layer.movement_penalty = value
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "from_behind_only", layer.from_behind_only, func(value: bool) -> void:
		layer.from_behind_only = value
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "hazard_blind_on_entry", layer.hazard_blind_on_entry, func(value: bool) -> void:
		layer.hazard_blind_on_entry = value
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "poison_hazard", layer.poison_hazard, func(value: bool) -> void:
		layer.poison_hazard = value
		_on_module_field_edited(ability)
	)
	_bind_int(grid, "landing_push", layer.landing_push, func(value: int) -> void:
		layer.landing_push = value
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "status_requires_debuff", layer.status_requires_debuff, func(value: bool) -> void:
		layer.status_requires_debuff = value
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "cone_all_targets", layer.cone_all_targets, func(value: bool) -> void:
		layer.cone_all_targets = value
		_on_module_field_edited(ability)
	)
	_bind_bool(grid, "wall_collision_stagger", layer.wall_collision_stagger, func(value: bool) -> void:
		layer.wall_collision_stagger = value
		_on_module_field_edited(ability)
	)


func _add_module_extras_editor(
	parent: VBoxContainer,
	ability: AbilityData,
	module: AbilityModule,
) -> void:
	_add_subsection_label(parent, "Extra Rules", ClassLibraryTheme.ACCENT_DATA)
	var box := VBoxContainer.new()
	parent.add_child(box)
	for index: int in module.extras.size():
		var extra: AbilityExtraRule = module.extras[index]
		if extra == null:
			extra = AbilityExtraRule.new()
			module.extras[index] = extra
		var grid := GridContainer.new()
		grid.columns = 2
		box.add_child(grid)
		var custom_key_edit: LineEdit
		_bind_enum(grid, "Extra %d" % index, AbilityExtraRule.Id, extra.id, func(v: int) -> void:
			extra.id = v as AbilityExtraRule.Id
			extra.override_key = ""
			if custom_key_edit != null:
				custom_key_edit.text = ""
			_on_module_field_edited(ability)
		)
		var value_edit := LineEdit.new()
		value_edit.text = str(extra.value)
		value_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_edit.text_submitted.connect(func(text: String) -> void:
			extra.value = _parse_extra_value(text)
			_on_module_field_edited(ability)
		)
		value_edit.focus_exited.connect(func() -> void:
			extra.value = _parse_extra_value(value_edit.text)
			_on_module_field_edited(ability)
		)
		grid.add_child(_field_label("Value"))
		grid.add_child(value_edit)
		custom_key_edit = LineEdit.new()
		custom_key_edit.text = extra.override_key
		custom_key_edit.placeholder_text = "Only for Extra = NONE"
		custom_key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_key_edit.text_changed.connect(func(text: String) -> void:
			extra.override_key = text.strip_edges()
			if not extra.override_key.is_empty():
				extra.id = AbilityExtraRule.Id.NONE
			_on_module_field_edited(ability)
		)
		grid.add_child(_field_label("Custom Key"))
		grid.add_child(custom_key_edit)
		var remove := Button.new()
		remove.text = "Remove Extra"
		remove.pressed.connect(func() -> void:
			module.extras.remove_at(index)
			_rebuild_ability_detail_panes(ability)
		)
		box.add_child(remove)
	var add := Button.new()
	add.text = "+ Extra Rule"
	add.pressed.connect(func() -> void:
		module.extras.append(AbilityExtraRule.new())
		_rebuild_ability_detail_panes(ability)
	)
	box.add_child(add)


func _parse_extra_value(text: String) -> Variant:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return true
	if trimmed == "true":
		return true
	if trimmed == "false":
		return false
	if trimmed.is_valid_int():
		return int(trimmed)
	if trimmed.is_valid_float():
		return float(trimmed)
	return StringName(trimmed)


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
			_refresh_module_field_greying(ability)
		)
		var amount_row := _bind_int(grid, "Amount", keyword.amount, func(v: int) -> void:
			keyword.amount = v
			_on_module_field_edited(ability)
		)
		var push_row := _bind_int(grid, "Push Amount", keyword.push_amount, func(v: int) -> void:
			keyword.push_amount = v
			_on_module_field_edited(ability)
		)
		var emit_row := _bind_bool(grid, "Emit Legacy Effect", keyword.emit_as_effect, func(v: bool) -> void:
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
		var keyword_grey_cb := func() -> void:
			_grey_row(
				push_row,
				not ModuleAuthoringRules.keyword_uses_push_amount(keyword.keyword_id),
			)
			_grey_row(
				amount_row,
				not ModuleAuthoringRules.keyword_uses_amount(keyword.keyword_id),
			)
			_grey_row(
				emit_row,
				not ModuleAuthoringRules.keyword_uses_emit_as_effect(keyword.keyword_id),
			)
		_ability_ui[ability]["module_grey_cbs"].append(keyword_grey_cb)
		keyword_grey_cb.call()
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
		_bind_enum_excluding(
			grid,
			"Layer %d Condition" % index,
			GameEnums.LayerCondition,
			layer.condition,
			func(v: int) -> void:
				layer.condition = v
				_on_module_field_edited(ability),
			ModuleAuthoringRules.excluded_layer_conditions(module),
		)
		_bind_bool(
			grid,
			"Object Collision Stagger",
			layer.object_collision_stagger,
			func(v: bool) -> void:
				layer.object_collision_stagger = v
				_on_module_field_edited(ability),
		)
		_bind_bool(
			grid,
			"Enemy Collision Stagger Both",
			layer.enemy_collision_stagger_both,
			func(v: bool) -> void:
				layer.enemy_collision_stagger_both = v
				_on_module_field_edited(ability),
		)
		_bind_bool(grid, "Weapon Scaled", layer.weapon_scaled, func(v: bool) -> void:
			layer.weapon_scaled = v
			_on_module_field_edited(ability)
		)
		_bind_int(
			grid,
			"Buff Per Destroyed Object",
			layer.buff_per_destroyed_object,
			func(v: int) -> void:
				layer.buff_per_destroyed_object = maxi(0, v)
				_on_module_field_edited(ability),
		)
		_bind_bool(grid, "Stagger On Collision", layer.stagger_on_collision, func(v: bool) -> void:
			layer.stagger_on_collision = v
			_on_module_field_edited(ability)
		)
		_bind_int(
			grid,
			"Intercept Grant STR",
			layer.intercept_grant_str,
			func(v: int) -> void:
				layer.intercept_grant_str = maxi(0, v)
				_on_module_field_edited(ability),
		)
		_bind_bool(grid, "Push Collision Pierce", layer.push_collision_pierce, func(v: bool) -> void:
			layer.push_collision_pierce = v
			_on_module_field_edited(ability)
		)
		_bind_int(grid, "Push Collision Damage", layer.push_collision_damage, func(v: int) -> void:
			layer.push_collision_damage = maxi(0, v)
			_on_module_field_edited(ability)
		)
		_bind_bool(grid, "Difficult Terrain Created", layer.difficult_terrain_created, func(v: bool) -> void:
			layer.difficult_terrain_created = v
			_on_module_field_edited(ability)
		)
		_bind_bool(grid, "Rooted Push BLEED WPN", layer.rooted_push_bleed_weapon, func(v: bool) -> void:
			layer.rooted_push_bleed_weapon = v
			_on_module_field_edited(ability)
		)
		_bind_int(grid, "Grapple Pass Damage", layer.grapple_pass_through_damage, func(v: int) -> void:
			layer.grapple_pass_through_damage = maxi(0, v)
			_on_module_field_edited(ability)
		)
		_bind_bool(grid, "Ignite Flammable Terrain", layer.ignite_flammable_terrain, func(v: bool) -> void:
			layer.ignite_flammable_terrain = v
			_on_module_field_edited(ability)
		)
		_bind_bool(grid, "Ally Damage Zero", layer.ally_damage_zero, func(v: bool) -> void:
			layer.ally_damage_zero = v
			_on_module_field_edited(ability)
		)
		_bind_bool(grid, "Trap Vulnerable", layer.trap_vulnerable, func(v: bool) -> void:
			layer.trap_vulnerable = v
			_on_module_field_edited(ability)
		)
		_bind_bool(grid, "Crossing BLIND", layer.crossing_blind, func(v: bool) -> void:
			layer.crossing_blind = v
			_on_module_field_edited(ability)
		)
		_bind_int(grid, "Trap DEF Debuff", layer.trap_def_debuff, func(v: int) -> void:
			layer.trap_def_debuff = maxi(0, v)
			_on_module_field_edited(ability)
		)
		_bind_string(
			grid,
			"Range 1 Damage Multiplier",
			str(layer.range_one_damage_multiplier),
			func(v: String) -> void:
				if v.strip_edges().is_valid_float():
					layer.range_one_damage_multiplier = maxf(0.0, float(v))
					_on_module_field_edited(ability),
		)
		_bind_bool(grid, "Elemental Surface", layer.elemental_surface, func(v: bool) -> void:
			layer.elemental_surface = v
			_on_module_field_edited(ability)
		)
		_bind_string(grid, "Reaction Terrain", str(layer.reaction_terrain), func(v: String) -> void:
			layer.reaction_terrain = StringName(v)
			_on_module_field_edited(ability)
		)
		_bind_bool(grid, "Steam Splash", layer.reaction_steam_splash, func(v: bool) -> void:
			layer.reaction_steam_splash = v
			_on_module_field_edited(ability)
		)
		_bind_int(grid, "Steam Splash Size", layer.reaction_steam_splash_size, func(v: int) -> void:
			layer.reaction_steam_splash_size = v
			_on_module_field_edited(ability)
		)
		_bind_int(grid, "Steam Splash Damage", layer.reaction_steam_splash_damage, func(v: int) -> void:
			layer.reaction_steam_splash_damage = v
			_on_module_field_edited(ability)
		)
		_bind_int(grid, "Set Max MOV", layer.set_max_move, func(v: int) -> void:
			layer.set_max_move = v
			_on_module_field_edited(ability)
		)
		_bind_bool(grid, "Arcane Trail", layer.arcane_trail, func(v: bool) -> void:
			layer.arcane_trail = v
			_on_module_field_edited(ability)
		)
		_bind_int(grid, "Creation Adjacent Damage", layer.creation_adjacent_damage, func(v: int) -> void:
			layer.creation_adjacent_damage = v
			_on_module_field_edited(ability)
		)
		_bind_string(grid, "Terrain ID", str(layer.terrain_id), func(v: String) -> void:
			layer.terrain_id = StringName(v)
			_on_module_field_edited(ability)
		)
		_bind_int(grid, "Hazard Duration", layer.hazard_duration, func(v: int) -> void:
			layer.hazard_duration = v
			_on_module_field_edited(ability)
		)
		_bind_bool(grid, "Counterattack Melee", layer.counterattack_melee, func(v: bool) -> void:
			layer.counterattack_melee = v
			_on_module_field_edited(ability)
		)
		_bind_bool(grid, "Counterattack On Intercept", layer.counterattack_on_intercept, func(v: bool) -> void:
			layer.counterattack_on_intercept = v
			_on_module_field_edited(ability)
		)
		_bind_bool(grid, "Bleed Weapon", layer.bleed_weapon, func(v: bool) -> void:
			layer.bleed_weapon = v
			_on_module_field_edited(ability)
		)
		_bind_bool(grid, "Skip Terrain Status", layer.skip_terrain_entry_status, func(v: bool) -> void:
			layer.skip_terrain_entry_status = v
			_on_module_field_edited(ability)
		)
		_bind_bool(grid, "Skip Terrain Bleed", layer.skip_terrain_entry_bleed, func(v: bool) -> void:
			layer.skip_terrain_entry_bleed = v
			_on_module_field_edited(ability)
		)
		_bind_int(grid, "Hazard Damage Bonus", layer.hazard_damage_bonus, func(v: int) -> void:
			layer.hazard_damage_bonus = v
			_on_module_field_edited(ability)
		)
		_bind_int(grid, "Trap Damage Bonus", layer.trap_damage_bonus, func(v: int) -> void:
			layer.trap_damage_bonus = v
			_on_module_field_edited(ability)
		)
		_bind_int(grid, "Grant AP", layer.grant_ap, func(v: int) -> void:
			layer.grant_ap = v
			_on_module_field_edited(ability)
		)
		_bind_bool(grid, "Next Turn", layer.next_turn, func(v: bool) -> void:
			layer.next_turn = v
			_on_module_field_edited(ability)
		)
		_bind_int(grid, "Burning Splash MAG", layer.burning_splash_magic, func(v: int) -> void:
			layer.burning_splash_magic = v
			_on_module_field_edited(ability)
		)
		_bind_bool(grid, "Pierce If First Hit Zero", layer.pierce_if_first_zero, func(v: bool) -> void:
			layer.pierce_if_first_zero = v
			_on_module_field_edited(ability)
		)
		_bind_bool(grid, "Damage Adjacent On Landing", layer.damage_adjacent_on_landing, func(v: bool) -> void:
			layer.damage_adjacent_on_landing = v
			_on_module_field_edited(ability)
		)
		_bind_bool(grid, "Require Dash Line Enemy", layer.require_dash_line_enemy, func(v: bool) -> void:
			layer.require_dash_line_enemy = v
			_on_module_field_edited(ability)
		)
		_bind_bool(grid, "Layer Dash Absorb Element", layer.dash_absorb_element, func(v: bool) -> void:
			layer.dash_absorb_element = v
			_on_module_field_edited(ability)
		)
		_bind_int(grid, "Collision Splash Damage", layer.collision_splash_damage, func(v: int) -> void:
			layer.collision_splash_damage = v
			_on_module_field_edited(ability)
		)
		_bind_bool(grid, "Collision Splash Weaken", layer.collision_splash_weaken, func(v: bool) -> void:
			layer.collision_splash_weaken = v
			_on_module_field_edited(ability)
		)
		_bind_int(grid, "Push If Target On Water", layer.push_if_target_on_water, func(v: int) -> void:
			layer.push_if_target_on_water = v
			_on_module_field_edited(ability)
		)
		_add_typed_layer_bindings(grid, ability, layer)
		_bind_effect_type(grid, "Layer Type", layer.effect.type, func(v: int) -> void:
			layer.effect.type = v
			AbilityModuleBridge.normalize_effect_authoring_fields(layer.effect)
			_rebuild_ability_detail_panes(ability)
		)
		_bind_int(grid, "Layer Amount", layer.effect.amount, func(v: int) -> void:
			layer.effect.amount = v
			_on_module_field_edited(ability)
		)
		var layer_grey_rows: Dictionary = {}
		if GameEnums.effect_type_applies_status(layer.effect.type):
			layer_grey_rows["status"] = _bind_enum_excluding(
				grid,
				"Layer Status",
				GameEnums.StatusType,
				layer.effect.status_type,
				func(v: int) -> void:
					layer.effect.status_type = v
					_on_module_field_edited(ability),
				PackedStringArray(["NONE"]),
			)
			layer_grey_rows["duration"] = _bind_int(
				grid,
				"Layer Duration",
				layer.effect.status_duration,
				func(v: int) -> void:
					layer.effect.status_duration = v
					_on_module_field_edited(ability)
			)
		if GameEnums.effect_type_uses_spawn_unit(layer.effect.type):
			_bind_string(grid, "Layer Spawn Id", String(layer.effect.spawn_unit_id), func(v: String) -> void:
				layer.effect.spawn_unit_id = StringName(v)
				_on_module_field_edited(ability)
			)
		layer_grey_rows["scaling"] = _bind_enum(
			grid,
			"Layer Scaling",
			GameEnums.StatType,
			layer.effect.scaling_stat,
			func(v: int) -> void:
				layer.effect.scaling_stat = v
				_on_module_field_edited(ability)
		)
		if layer.effect.type == GameEnums.EffectType.DAMAGE:
			layer_grey_rows["adjacent_bonus"] = _bind_int(
				grid,
				"Layer Adjacent Bonus",
				layer.effect.bonus_if_adjacent_at_cast,
				func(v: int) -> void:
					layer.effect.bonus_if_adjacent_at_cast = v
					_on_module_field_edited(ability)
			)
			layer_grey_rows["def_debuff"] = _bind_int(
				grid,
				"Layer DEF Debuff",
				layer.effect.def_debuff_before_damage,
				func(v: int) -> void:
					layer.effect.def_debuff_before_damage = v
					_on_module_field_edited(ability)
			)
		var layer_grey_cb := func() -> void:
			_grey_row(
				layer_grey_rows.get("scaling", []),
				not GameEnums.effect_type_uses_module_scaling(layer.effect.type),
			)
		layer_grey_cb.call()
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


func _validated_tags_from_csv(text: String) -> Array[StringName]:
	var accepted: Array[StringName] = []
	var rejected: Array[StringName] = []
	for tag: StringName in _tags_from_csv(text):
		if CANONICAL_ABILITY_TAGS.has(tag):
			if not accepted.has(tag):
				accepted.append(tag)
		else:
			rejected.append(tag)
	if not rejected.is_empty():
		push_error("Ability editor rejected unknown tags: %s" % ", ".join(rejected))
	return accepted


func _refresh_ability_ui(ability: AbilityData) -> void:
	if not _ability_ui.has(ability):
		return
	var refs: Dictionary = _ability_ui[ability]
	
	if refs.has("greying_cb"):
		var cb: Callable = refs["greying_cb"]
		if cb.is_valid():
			cb.call()
	_refresh_module_field_greying(ability)
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
	var title: Label = refs.get("title")
	if title != null:
		title.text = ability.display_name
		title.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_PRIMARY)
	_apply_bible_tooltip(
		refs.get("card") as Control,
		title,
		refs.get("preview") as RichTextLabel,
		ability.display_name,
		String(ability.id),
	)
			
	var reset_btn: Button = refs.get("reset_btn")
	if reset_btn != null:
		reset_btn.remove_theme_color_override("font_color")
			
	var name_edit: LineEdit = refs.get("name_edit")
	if name_edit != null:
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
			if is_instance_valid(ctrl) and ctrl is Control:
				packed.append(ctrl as Control)
	elif is_instance_valid(controls) and controls is Control:
		packed.append(controls as Control)
	rows.append({"field": field, "controls": packed})


func _ability_field_state(_ability: AbilityData, _field: String) -> FieldTrackState:
	return FieldTrackState.MATCHES_FACTORY


func _apply_field_track_color(controls: Array, state: FieldTrackState) -> void:
	for ctrl: Variant in controls:
		if not is_instance_valid(ctrl) or not (ctrl is Control):
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
		if k == "NONE":
			continue
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

func _bind_int(
	parent: GridContainer,
	label: String,
	value: int,
	setter: Callable,
	min_value: int = -999,
	max_value: int = 9999,
) -> Array[Control]:
	var lbl := _field_label(label)
	parent.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	spin.value_changed.connect(func(v: float) -> void: setter.call(int(v)))
	parent.add_child(spin)
	return [lbl, spin]


func _bind_float(
	parent: GridContainer,
	label: String,
	value: float,
	setter: Callable,
	min_value: float = -999.0,
	max_value: float = 9999.0,
) -> Array[Control]:
	var lbl := _field_label(label)
	parent.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = 0.01
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	spin.value_changed.connect(func(v: float) -> void: setter.call(v))
	parent.add_child(spin)
	return [lbl, spin]


func _bind_bool(parent: GridContainer, label: String, value: bool, setter: Callable) -> Array[Control]:
	var lbl := _field_label(label)
	parent.add_child(lbl)
	var chk := CheckBox.new()
	chk.button_pressed = value
	chk.add_theme_font_size_override("font_size", ClassLibraryTheme.font(ClassLibraryTheme.FONT_BODY))
	chk.toggled.connect(func(v: bool) -> void: setter.call(v))
	parent.add_child(chk)
	return [lbl, chk]


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
	return _bind_enum_excluding(parent, label, enum_obj, current, setter, PackedStringArray())


func _bind_effect_type(parent: GridContainer, label: String, current: int, setter: Callable) -> Array[Control]:
	var lbl := _field_label(label)
	parent.add_child(lbl)
	var opt := OptionButton.new()
	var missing: Array[GameEnums.EffectType] = ModuleAuthoringRules.log_uncategorized_effect_types_once()
	var item_types: Array[int] = []
	for family: Dictionary in ModuleAuthoringRules.effect_primary_families():
		opt.add_separator(String(family["label"]))
		for effect_type: GameEnums.EffectType in family["types"]:
			var type_id: int = int(effect_type)
			opt.add_item(GameEnums.EffectType.keys()[type_id], type_id)
			item_types.append(type_id)
	for leftover: GameEnums.EffectType in missing:
		var leftover_id: int = int(leftover)
		opt.add_item(GameEnums.EffectType.keys()[leftover_id], leftover_id)
		item_types.append(leftover_id)
	if item_types.is_empty():
		parent.add_child(opt)
		return [lbl, opt]
	if current not in item_types:
		setter.call(item_types[0])
		current = item_types[0]
	var id_index: int = opt.get_item_index(current)
	opt.selected = id_index if id_index >= 0 else 0
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.item_selected.connect(func(idx: int) -> void:
		setter.call(opt.get_item_id(idx))
	)
	parent.add_child(opt)
	return [lbl, opt]


func _bind_enum_excluding(
	parent: GridContainer,
	label: String,
	enum_obj: Variant,
	current: int,
	setter: Callable,
	exclude: PackedStringArray,
) -> Array[Control]:
	var lbl := _field_label(label)
	parent.add_child(lbl)
	var opt := OptionButton.new()
	var keys: PackedStringArray = enum_obj.keys()
	var enum_values: Array[int] = []
	for i: int in keys.size():
		if exclude.has(keys[i]):
			continue
		enum_values.append(i)
		opt.add_item(keys[i], enum_values.size() - 1)
	var selected: int = enum_values.find(current)
	if selected < 0:
		selected = 0
		if not enum_values.is_empty():
			setter.call(enum_values[0])
	opt.selected = selected
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.item_selected.connect(func(idx: int) -> void: setter.call(enum_values[idx]))
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
		if not is_instance_valid(ctrl):
			continue
		ctrl.modulate.a = alpha
		if ctrl is BaseButton or ctrl is SpinBox or ctrl is OptionButton or ctrl is LineEdit:
			ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE if greyed else Control.MOUSE_FILTER_STOP


func _save_overrides() -> void:
	if _save_status != null:
		_save_status.text = "Save is off — factory skills only"
		_save_status.add_theme_color_override("font_color", ClassLibraryTheme.TEXT_MUTED)


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
