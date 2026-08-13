extends Control

const _OPTIONS_SCENE: PackedScene = preload("res://scenes/Options.tscn")

var _options_overlay: Control = null


func _ready() -> void:
	$ColorRect.color = MenuTheme.BG
	MenuTheme.style_title($Title)
	$Title.add_theme_color_override("font_color", MenuTheme.TEXT)
	_rebuild_menu()


func _rebuild_menu() -> void:
	var vbox: VBoxContainer = $VBoxContainer
	for child: Node in vbox.get_children():
		child.queue_free()
	vbox.add_theme_constant_override("separation", 12)

	_add_section_label(vbox, "Play")
	_add_nav_button(vbox, "Local Co-op", _on_local_coop_pressed)
	_add_nav_button(vbox, "LAN Co-op", _on_lan_coop_pressed)
	_add_nav_button(vbox, "Online Co-op", _on_online_coop_pressed)

	vbox.add_child(_separator())

	_add_section_label(vbox, "Reference")
	_add_nav_button(vbox, "Compendium", _on_compendium_pressed)

	vbox.add_child(_separator())

	_add_section_label(vbox, "Tools")
	_add_nav_button(vbox, "Skill Test Arena", _on_test_battle_pressed)
	_add_nav_button(vbox, "Class Library Editor", _on_class_library_pressed)
	_add_nav_button(vbox, "Map Dev Sandbox", _on_dev_sandbox_pressed)
	_add_nav_button(vbox, "Mass Simulation Analytics", _on_mass_sim_pressed)
	_add_nav_button(vbox, "Report Bug", _on_report_bug_pressed)

	vbox.add_child(_separator())

	_add_section_label(vbox, "Application")
	_add_nav_button(vbox, "Settings", _on_options_pressed)
	_add_nav_button(vbox, "Exit Game", _on_exit_pressed, true)


func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	MenuTheme.style_section_label(lbl)
	parent.add_child(lbl)


func _add_nav_button(parent: VBoxContainer, text: String, callback: Callable, danger: bool = false) -> void:
	var btn := Button.new()
	btn.text = text
	MenuTheme.style_menu_button(btn)
	if danger:
		btn.add_theme_color_override("font_color", MenuTheme.DANGER)
	btn.pressed.connect(callback)
	parent.add_child(btn)


func _separator() -> Control:
	var sep := HSeparator.new()
	sep.modulate = MenuTheme.PANEL_BORDER
	return sep


func _on_options_pressed() -> void:
	if _options_overlay != null:
		return
	_options_overlay = _OPTIONS_SCENE.instantiate() as Control
	var screen: OptionsScreen = _options_overlay as OptionsScreen
	if screen != null:
		screen.overlay_mode = true
		screen.close_requested.connect(_close_options_overlay)
	add_child(_options_overlay)


func _close_options_overlay() -> void:
	if _options_overlay != null:
		_options_overlay.queue_free()
		_options_overlay = null


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_mass_sim_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MassSimDashboard.tscn")


func _on_dev_sandbox_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/test_map.tscn")


func _on_test_battle_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/TestBattle.tscn")


func _on_local_coop_pressed() -> void:
	if NetworkManager:
		NetworkManager.is_multiplayer = false
	get_tree().change_scene_to_file("res://scenes/BattleSetup.tscn")


func _on_lan_coop_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/LanLobby.tscn")


func _on_online_coop_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/OnlineLobby.tscn")


func _on_compendium_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Compendium.tscn")


func _on_class_library_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ClassLibraryEditor.tscn")


func _on_report_bug_pressed() -> void:
	if DebugReportService != null:
		DebugReportService.open_report_dialog()
