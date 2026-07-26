extends Control

## Main-menu options — all tabs wired to GameSettings + EffectsSettings (no placeholders).

signal close_requested

const _EFFECT_TOGGLES: Array[Dictionary] = [
	{"key": "wind_field", "label": "Wind field"},
	{"key": "time_light", "label": "Day / night cycle"},
	{"key": "cloud_shadows", "label": "Cloud shadows"},
	{"key": "mist", "label": "Mist overlay"},
	{"key": "water_ripples", "label": "Water ripples"},
	{"key": "shoreline_foam", "label": "Shoreline foam"},
	{"key": "water_sparkles", "label": "Water sparkles"},
	{"key": "fish_splash", "label": "Fish splash"},
	{"key": "ambient_particles", "label": "Ambient particles"},
	{"key": "ecology_actors", "label": "Ecology actors"},
	{"key": "rare_events", "label": "Rare ambient events"},
	{"key": "oblique_contact_shadows", "label": "Contact shadows"},
]

const _DEV_SHADOW_TOGGLES: Array[Dictionary] = [
	{"key": "shadow_perf_mode", "label": "Shadow performance mode"},
	{"key": "shadow_freeze_time", "label": "Freeze game time"},
	{"key": "shadow_edge_soften", "label": "Soften shadow edges"},
]

const _CONTROLS_TEXT: String = """[b]Tactical combat[/b]
• Left click — select unit, plan move, or use ability
• Right click — undo last action or deselect
• Scroll wheel — change selected ability
• A — aim mode (vector-target skills)
• O — open in-game options
• Esc — pause menu

[b]Map camera[/b]
• Middle mouse drag — pan map
• Ctrl + scroll — zoom multiplier (session)

[b]Menus[/b]
• Esc / Back — return from sub-screens"""

var _game_settings: GameSettings
var _effects_settings: EffectsSettings

var _resolution_option: OptionButton
var _resolution_status_label: Label
var _window_mode_option: OptionButton
var _map_zoom_option: OptionButton
var _map_scale_slider: HSlider
var _map_scale_label: Label
var _ui_scale_slider: HSlider
var _ui_scale_label: Label
var _text_scale_slider: HSlider
var _text_scale_label: Label
var _text_size_option: OptionButton
var _panel_width_slider: HSlider
var _panel_width_label: Label
var _master_slider: HSlider
var _sfx_slider: HSlider
var _music_slider: HSlider
var _damage_numbers_check: CheckButton
var _show_fps_check: CheckButton
var _show_tod_check: CheckButton
var _effect_checks: Dictionary = {}
var _dev_shadow_checks: Dictionary = {}
var _dev_tile_labels_check: CheckButton
var _dev_boredom_atmo_check: CheckButton
var _dev_boredom_water_check: CheckButton


func _ready() -> void:
	$BackButton.pressed.connect(_on_back_pressed)
	MenuNavigation.register(self, _on_back_pressed)

	_game_settings = GameSettings.new()
	_game_settings.load_from_disk()

	_effects_settings = EffectsSettings.new()
	_effects_settings.load_from_disk()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 120)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)

	var tab_container := TabContainer.new()
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(tab_container)

	_build_display_tab(tab_container)
	_build_graphics_tab(tab_container)
	_build_sound_tab(tab_container)
	_build_gameplay_tab(tab_container)
	_build_controls_tab(tab_container)
	_build_interface_tab(tab_container)
	_build_developer_tab(tab_container)


func _build_display_tab(parent: TabContainer) -> void:
	var scroll := _scroll_tab(parent, "Display")
	var vbox := _vbox(scroll)
	_add_hint(vbox, "Resolution and window mode use Apply. Map zoom applies immediately.")

	_resolution_option = OptionButton.new()
	for res: Vector2i in GameSettings.RESOLUTION_PRESETS:
		_resolution_option.add_item("%d × %d" % [res.x, res.y])
	_resolution_option.select(_game_settings.resolution_index())
	_resolution_option.item_selected.connect(func(_i: int) -> void: _sync_resolution_controls())
	vbox.add_child(_label("Resolution"))
	vbox.add_child(_resolution_option)
	_resolution_status_label = Label.new()
	_resolution_status_label.add_theme_font_size_override("font_size", 13)
	_resolution_status_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88))
	vbox.add_child(_resolution_status_label)

	_window_mode_option = OptionButton.new()
	for label: String in GameSettings.WINDOW_MODE_LABELS:
		_window_mode_option.add_item(label)
	_window_mode_option.select(_game_settings.window_mode_index())
	_window_mode_option.item_selected.connect(func(_i: int) -> void: _apply_window_mode())
	vbox.add_child(_label("Window mode"))
	vbox.add_child(_window_mode_option)
	_sync_resolution_controls()

	_map_zoom_option = OptionButton.new()
	for label: String in GameSettings.MAP_ZOOM_LABELS:
		_map_zoom_option.add_item(label)
	_map_zoom_option.select(_game_settings.map_zoom_mode)
	_map_zoom_option.item_selected.connect(func(_i: int) -> void: _apply_map_zoom_live())
	vbox.add_child(_label("Map tile zoom"))
	vbox.add_child(_map_zoom_option)

	var scale_row := HBoxContainer.new()
	_map_scale_slider = HSlider.new()
	_map_scale_slider.min_value = 0.5
	_map_scale_slider.max_value = 3.0
	_map_scale_slider.step = 0.25
	_map_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_scale_slider.value = _game_settings.map_zoom_multiplier
	_map_scale_slider.value_changed.connect(_on_map_scale_changed)
	_map_scale_label = Label.new()
	_map_scale_label.custom_minimum_size.x = 48
	scale_row.add_child(_map_scale_slider)
	scale_row.add_child(_map_scale_label)
	vbox.add_child(_label("Map scale multiplier"))
	vbox.add_child(scale_row)
	_on_map_scale_changed(_game_settings.map_zoom_multiplier)

	_show_fps_check = CheckButton.new()
	_show_fps_check.text = "Show FPS counter"
	_show_fps_check.button_pressed = _game_settings.show_fps_hud
	_show_fps_check.toggled.connect(func(pressed: bool) -> void:
		_game_settings.show_fps_hud = pressed
		_save_game_settings(),
	)
	vbox.add_child(_show_fps_check)

	_show_tod_check = CheckButton.new()
	_show_tod_check.text = "Show time-of-day clock"
	_show_tod_check.button_pressed = _game_settings.show_time_of_day_hud
	_show_tod_check.toggled.connect(func(pressed: bool) -> void:
		_game_settings.show_time_of_day_hud = pressed
		_save_game_settings(),
	)
	vbox.add_child(_show_tod_check)

	vbox.add_child(HSeparator.new())
	_add_button(vbox, "Apply resolution & window mode", _apply_display_video)


func _build_graphics_tab(parent: TabContainer) -> void:
	var scroll := _scroll_tab(parent, "Graphics")
	var vbox := _vbox(scroll)
	_add_hint(vbox, "Ambient living-map effects — saved automatically.")

	for entry: Dictionary in _EFFECT_TOGGLES:
		var key: String = entry["key"]
		var check := CheckButton.new()
		check.text = entry["label"]
		check.button_pressed = bool(_effects_settings.get(key))
		check.toggled.connect(func(pressed: bool) -> void: _on_effect_toggled(key, pressed))
		vbox.add_child(check)
		_effect_checks[key] = check


func _build_sound_tab(parent: TabContainer) -> void:
	var scroll := _scroll_tab(parent, "Sound")
	var vbox := _vbox(scroll)
	_add_hint(vbox, "Volume changes apply immediately.")

	_master_slider = _add_volume_row(vbox, "Master volume", _game_settings.master_volume)
	_sfx_slider = _add_volume_row(vbox, "Sound effects", _game_settings.sfx_volume)
	_music_slider = _add_volume_row(vbox, "Music", _game_settings.music_volume)


func _build_gameplay_tab(parent: TabContainer) -> void:
	var scroll := _scroll_tab(parent, "Gameplay")
	var vbox := _vbox(scroll)
	_add_hint(vbox, "Combat presentation preferences.")

	_damage_numbers_check = CheckButton.new()
	_damage_numbers_check.text = "Show floating damage numbers"
	_damage_numbers_check.button_pressed = _game_settings.show_damage_numbers
	_damage_numbers_check.toggled.connect(func(pressed: bool) -> void:
		_game_settings.show_damage_numbers = pressed
		_save_game_settings(),
	)
	vbox.add_child(_damage_numbers_check)

	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = (
		"Honor & Iron uses perfect information: enemy intent is always visible "
		+ "during planning. Timeline programming is always available in combat."
	)
	vbox.add_child(info)


func _build_controls_tab(parent: TabContainer) -> void:
	var scroll := _scroll_tab(parent, "Controls")
	var vbox := _vbox(scroll)
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = true
	rich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rich.text = _CONTROLS_TEXT
	vbox.add_child(rich)
	_add_hint(vbox, "Key rebinding is not available yet; bindings are fixed.")


func _build_interface_tab(parent: TabContainer) -> void:
	var scroll := _scroll_tab(parent, "Interface")
	var vbox := _vbox(scroll)
	_add_hint(vbox, "UI layout scale affects panels/buttons. Text scale affects fonts only.")

	_ui_scale_slider = HSlider.new()
	_ui_scale_slider.min_value = 0.75
	_ui_scale_slider.max_value = 2.5
	_ui_scale_slider.step = 0.05
	_ui_scale_slider.value = _game_settings.combat_ui_scale
	_ui_scale_slider.value_changed.connect(_on_ui_scale_changed)
	_ui_scale_label = Label.new()
	var ui_row := HBoxContainer.new()
	ui_row.add_child(_ui_scale_slider)
	ui_row.add_child(_ui_scale_label)
	vbox.add_child(_label("UI layout scale (panels & buttons)"))
	vbox.add_child(ui_row)
	_on_ui_scale_changed(_game_settings.combat_ui_scale)

	_text_scale_slider = HSlider.new()
	_text_scale_slider.min_value = 0.75
	_text_scale_slider.max_value = 2.5
	_text_scale_slider.step = 0.05
	_text_scale_slider.value = _game_settings.combat_text_scale
	_text_scale_slider.value_changed.connect(_on_text_scale_changed)
	_text_scale_label = Label.new()
	_text_scale_label.custom_minimum_size.x = 48
	var text_row := HBoxContainer.new()
	text_row.add_child(_text_scale_slider)
	text_row.add_child(_text_scale_label)
	vbox.add_child(_label("Text scale"))
	vbox.add_child(text_row)
	_on_text_scale_changed(_game_settings.combat_text_scale)

	_text_size_option = OptionButton.new()
	for label: String in GameSettings.TEXT_SIZE_LABELS:
		_text_size_option.add_item(label)
	_text_size_option.select(_game_settings.inspector_text_size_index)
	_text_size_option.item_selected.connect(func(_i: int) -> void:
		_game_settings.inspector_text_size_index = _text_size_option.selected
		_save_game_settings(),
	)
	vbox.add_child(_label("Inspector text size"))
	vbox.add_child(_text_size_option)

	_panel_width_slider = HSlider.new()
	_panel_width_slider.min_value = 320.0
	_panel_width_slider.max_value = 960.0
	_panel_width_slider.step = 20.0
	_panel_width_slider.value = float(_game_settings.inspector_panel_width)
	_panel_width_slider.value_changed.connect(_on_panel_width_changed)
	_panel_width_label = Label.new()
	_panel_width_label.custom_minimum_size.x = 48
	var width_row := HBoxContainer.new()
	width_row.add_child(_panel_width_slider)
	width_row.add_child(_panel_width_label)
	vbox.add_child(_label("Inspector panel width"))
	vbox.add_child(width_row)
	_on_panel_width_changed(float(_game_settings.inspector_panel_width))


func _build_developer_tab(parent: TabContainer) -> void:
	var scroll := _scroll_tab(parent, "Developer")
	var vbox := _vbox(scroll)
	_add_hint(vbox, "Sandbox / debug tools — apply in test map and tactical scenes.")

	_dev_tile_labels_check = _add_dev_check(
		vbox,
		"Tile ID labels (sandbox map)",
		_game_settings.dev_tile_labels,
		func(pressed: bool) -> void: _game_settings.dev_tile_labels = pressed,
	)
	_dev_boredom_atmo_check = _add_dev_check(
		vbox,
		"Boredom test — atmosphere only",
		_game_settings.dev_boredom_atmosphere,
		func(pressed: bool) -> void: _game_settings.dev_boredom_atmosphere = pressed,
	)
	_dev_boredom_water_check = _add_dev_check(
		vbox,
		"Boredom test — water only",
		_game_settings.dev_boredom_water,
		func(pressed: bool) -> void: _game_settings.dev_boredom_water = pressed,
	)

	vbox.add_child(HSeparator.new())
	_add_section(vbox, "Shadow debug")
	for entry: Dictionary in _DEV_SHADOW_TOGGLES:
		var key: String = entry["key"]
		var check := CheckButton.new()
		check.text = entry["label"]
		check.button_pressed = bool(_effects_settings.get(key))
		check.toggled.connect(func(pressed: bool) -> void: _on_shadow_debug_toggled(key, pressed))
		vbox.add_child(check)
		_dev_shadow_checks[key] = check


func _apply_display_video() -> void:
	_game_settings.set_resolution_index(_resolution_option.selected)
	_game_settings.set_window_mode_index(_window_mode_option.selected)
	_game_settings.apply_and_save(get_window(), true)
	_sync_resolution_controls()


func _apply_window_mode() -> void:
	_game_settings.set_window_mode_index(_window_mode_option.selected)
	_sync_resolution_controls()
	_game_settings.apply_to_window(get_window(), true)
	_sync_resolution_controls()
	_save_game_settings()


func _sync_resolution_controls() -> void:
	if _resolution_option == null or _window_mode_option == null:
		return
	var windowed: bool = _window_mode_option.selected == 0
	_resolution_option.disabled = not windowed
	if _resolution_status_label != null:
		_resolution_status_label.text = _game_settings.format_resolution_status(
			get_window(),
			_resolution_option.selected,
		)


func _apply_map_zoom_live() -> void:
	_game_settings.map_zoom_mode = _map_zoom_option.selected as GameSettings.MapZoomMode
	_save_game_settings()


func _on_map_scale_changed(value: float) -> void:
	_map_scale_label.text = "%.2f×" % value
	_game_settings.map_zoom_multiplier = value
	_save_game_settings()


func _on_ui_scale_changed(value: float) -> void:
	_ui_scale_label.text = "%.2f×" % value
	_game_settings.combat_ui_scale = value
	_save_game_settings()


func _on_text_scale_changed(value: float) -> void:
	_text_scale_label.text = "%.2f×" % value
	_game_settings.combat_text_scale = value
	_save_game_settings()


func _on_panel_width_changed(value: float) -> void:
	_panel_width_label.text = "%d" % int(value)
	_game_settings.inspector_panel_width = int(value)
	_save_game_settings()


func _on_effect_toggled(key: String, pressed: bool) -> void:
	_effects_settings.set(key, pressed)
	_effects_settings.save_to_disk()


func _on_shadow_debug_toggled(key: String, pressed: bool) -> void:
	_effects_settings.set(key, pressed)
	_effects_settings.save_to_disk()


func _add_dev_check(
	parent: VBoxContainer,
	text: String,
	initial: bool,
	on_changed: Callable,
) -> CheckButton:
	var check := CheckButton.new()
	check.text = text
	check.button_pressed = initial
	check.toggled.connect(func(pressed: bool) -> void:
		on_changed.call(pressed)
		_save_game_settings(),
	)
	parent.add_child(check)
	return check


func _add_volume_row(parent: VBoxContainer, title: String, initial: float) -> HSlider:
	parent.add_child(_label(title))
	var row := HBoxContainer.new()
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value = initial * 100.0
	var value_lbl := Label.new()
	value_lbl.custom_minimum_size.x = 40
	value_lbl.text = "%d%%" % int(slider.value)
	slider.value_changed.connect(func(v: float) -> void:
		value_lbl.text = "%d%%" % int(v)
		match title:
			"Master volume":
				_game_settings.master_volume = v / 100.0
			"Sound effects":
				_game_settings.sfx_volume = v / 100.0
			"Music":
				_game_settings.music_volume = v / 100.0
		_game_settings.apply_audio_buses()
		_save_game_settings(),
	)
	row.add_child(slider)
	row.add_child(value_lbl)
	parent.add_child(row)
	return slider


func _save_game_settings() -> void:
	_game_settings.save_to_disk()
	_game_settings.changed.emit()


func _scroll_tab(parent: TabContainer, tab_name: String) -> ScrollContainer:
	var margin := MarginContainer.new()
	margin.name = tab_name
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	parent.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	return scroll


func _vbox(parent: Control) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	parent.add_child(vbox)
	return vbox


func _label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	return lbl


func _add_hint(parent: VBoxContainer, text: String) -> void:
	var hint := Label.new()
	hint.text = text
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	parent.add_child(hint)


func _add_section(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	parent.add_child(lbl)


func _add_button(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	parent.add_child(btn)


func _on_back_pressed() -> void:
	if close_requested.get_connections().size() > 0:
		close_requested.emit()
	else:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
