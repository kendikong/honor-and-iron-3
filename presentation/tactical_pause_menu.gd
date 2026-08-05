class_name TacticalPauseMenu
extends CanvasLayer

## Full-screen pause overlay â€” resume, settings, compendium, restart turn/battle.

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
	_root.color = Color(0, 0, 0, 0.85)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_CENTER)
	_root.add_child(hbox)
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 220
	vbox.add_theme_constant_override("separation", 8)
	hbox.add_child(vbox)
	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	_add_button(vbox, "Resume", close_menu)
	_add_button(vbox, "Settings", func() -> void:
		close_menu()
		if _options != null:
			_options.open(),
	)
	_add_button(vbox, "Compendium", func() -> void:
		var comp: CompendiumScreen = load("res://scenes/Compendium.tscn").instantiate()
		comp.overlay_mode = true
		comp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_root.add_child(comp),
	)
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
	_add_button(vbox, "Exit to Main Menu", func() -> void:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"),
	)


func _add_button(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size.y = 40
	btn.pressed.connect(callback)
	parent.add_child(btn)
