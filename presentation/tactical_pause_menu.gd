class_name TacticalPauseMenu
extends CanvasLayer

## Pause overlay — scene actions here; unified Settings opens `OptionsScreen`.

var _director: CombatDirector
var _map_view: TacticalMapView
var _options: OptionsMenu
var _root: ColorRect
var _visible_state: bool = false

signal opened
signal closed


func setup(
	director: CombatDirector,
	map_view: TacticalMapView,
	options: OptionsMenu,
) -> void:
	_director = director
	_map_view = map_view
	_options = options
	layer = 35
	_build_ui()
	visible = true
	_root.visible = false


func is_open() -> bool:
	return _visible_state


func open() -> void:
	_root.visible = true
	_visible_state = true
	opened.emit()


func close_menu() -> void:
	_root.visible = false
	_visible_state = false
	closed.emit()


func _build_ui() -> void:
	_root = ColorRect.new()
	_root.color = MenuTheme.BG_DIM
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	MenuTheme.apply_panel(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MenuTheme.style_title(title)
	vbox.add_child(title)

	_add_section(vbox, "Session")
	_add_button(vbox, "Resume", close_menu)
	_add_button(vbox, "Settings", func() -> void:
		close_menu()
		if _options != null:
			_options.open(),
	)
	_add_button(vbox, "Compendium", _open_compendium_overlay)

	_add_section(vbox, "Battle")
	_add_button(vbox, "Restart Turn", func() -> void:
		close_menu()
		if _director != null:
			_director.restart_turn(),
	)
	_add_button(vbox, "Restart Battle", func() -> void:
		close_menu()
		if _director != null:
			_director.restart(),
	)

	_add_section(vbox, "Leave")
	_add_button(vbox, "Exit to Main Menu", func() -> void:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"),
		true)


func _open_compendium_overlay() -> void:
	var comp: CompendiumScreen = load("res://scenes/Compendium.tscn").instantiate()
	comp.overlay_mode = true
	comp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(comp)


func _add_section(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	MenuTheme.style_section_label(lbl)
	parent.add_child(lbl)


func _add_button(parent: VBoxContainer, text: String, callback: Callable, danger: bool = false) -> void:
	var btn := Button.new()
	btn.text = text
	MenuTheme.style_menu_button(btn)
	if danger:
		btn.add_theme_color_override("font_color", MenuTheme.DANGER)
	btn.pressed.connect(callback)
	parent.add_child(btn)
