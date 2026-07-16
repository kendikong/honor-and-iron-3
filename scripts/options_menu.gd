class_name OptionsMenu
extends CanvasLayer

## In-game options overlay — **O** to toggle. Display settings with apply + persist.

signal opened
signal closed
signal map_regenerate_requested
signal map_reseed_requested
signal map_toggle_center_requested
signal map_resize_requested(delta: int)
signal map_cycle_biome_requested
signal map_tile_labels_toggled(pressed: bool)
signal map_boredom_atmosphere_toggled(pressed: bool)
signal map_boredom_water_toggled(pressed: bool)
signal character_gen_changed

var _settings: GameSettings
var _on_applied: Callable

var _root: Control
var _main_panel: PanelContainer
var _display_panel: PanelContainer
var _resolution_option: OptionButton
var _window_mode_option: OptionButton
var _map_zoom_option: OptionButton
var _map_scale_slider: HSlider
var _map_scale_value: Label
var _text_size_option: OptionButton
var _panel_width_slider: HSlider
var _panel_width_value: Label

var _map_panel: PanelContainer
var _char_scale_slider: HSlider
var _char_scale_value: Label
var _tile_labels_check: CheckButton
var _boredom_atmo_check: CheckButton
var _boredom_water_check: CheckButton

var _char_profile: CharacterGenProfile
var _is_open: bool = false
var _combat_mode: bool = false
var _effects_panel: PanelContainer
var _effects_settings: EffectsSettings
var _effects_checks: Dictionary = {}
var _on_effects_changed: Callable
var _map_settings_btn: Button


func _ready() -> void:
	layer = 30
	visible = true
	_build_ui()
	_root.visible = false


func setup(settings: GameSettings, on_applied: Callable) -> void:
	_settings = settings
	_on_applied = on_applied


func setup_character_gen(profile: CharacterGenProfile) -> void:
	_char_profile = profile


func setup_combat_effects(settings: EffectsSettings, on_changed: Callable) -> void:
	_effects_settings = settings
	_on_effects_changed = on_changed
	_build_combat_effects_panel()


func set_combat_mode(enabled: bool) -> void:
	_combat_mode = enabled
	if _map_settings_btn != null:
		_map_settings_btn.visible = not enabled


func is_open() -> bool:
	return _is_open


func open() -> void:
	if _settings == null:
		return
	_sync_controls_from_settings()
	_show_main()
	_root.visible = true
	_is_open = true
	opened.emit()


func close_menu() -> void:
	if not _is_open:
		return
	_root.visible = false
	_is_open = false
	closed.emit()


func set_map_tool_state(tile_labels: bool, boredom_atmosphere: bool, boredom_water: bool) -> void:
	if _tile_labels_check != null:
		_tile_labels_check.set_block_signals(true)
		_tile_labels_check.button_pressed = tile_labels
		_tile_labels_check.set_block_signals(false)
	if _boredom_atmo_check != null:
		_boredom_atmo_check.set_block_signals(true)
		_boredom_atmo_check.button_pressed = boredom_atmosphere
		_boredom_atmo_check.set_block_signals(false)
	if _boredom_water_check != null:
		_boredom_water_check.set_block_signals(true)
		_boredom_water_check.button_pressed = boredom_water
		_boredom_water_check.set_block_signals(false)


func toggle() -> void:
	if _is_open:
		close_menu()
	else:
		open()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_O:
			toggle()
			get_viewport().set_input_as_handled()
		elif _is_open and event.keycode == KEY_ESCAPE:
			close_menu()
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_main_panel = _make_panel()
	center.add_child(_main_panel)
	_build_main_menu(_main_panel)

	_display_panel = _make_panel()
	_display_panel.visible = false
	center.add_child(_display_panel)
	_build_display_menu(_display_panel)

	_map_panel = _make_panel()
	_map_panel.visible = false
	center.add_child(_map_panel)
	_build_map_menu(_map_panel)

	_effects_panel = _make_panel()
	_effects_panel.visible = false
	center.add_child(_effects_panel)


func _make_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	return panel


func _build_main_menu(panel: PanelContainer) -> void:
	var margin: MarginContainer = _margin(panel)
	var vbox: VBoxContainer = _vbox(margin)
	_add_title(vbox, "Options")
	_add_hint(vbox, "Press O or Esc to close")
	vbox.add_child(HSeparator.new())
	_add_button(vbox, "Display…", _show_display)
	_map_settings_btn = _add_button(vbox, "Map Settings…", _show_map_settings)
	_add_button(vbox, "Ambient Effects…", _show_effects)
	vbox.add_child(HSeparator.new())
	_add_button(vbox, "Close", close_menu)


func _build_display_menu(panel: PanelContainer) -> void:
	var margin: MarginContainer = _margin(panel)
	var vbox: VBoxContainer = _vbox(margin)
	_add_title(vbox, "Display")
	_add_hint(vbox, "Changes apply when you click Apply")

	_resolution_option = OptionButton.new()
	_resolution_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for res: Vector2i in GameSettings.RESOLUTION_PRESETS:
		_resolution_option.add_item("%d × %d" % [res.x, res.y])
	vbox.add_child(_label("Resolution"))
	vbox.add_child(_resolution_option)

	_window_mode_option = _add_labeled_option(vbox, "Window mode", GameSettings.WINDOW_MODE_LABELS)
	_map_zoom_option = _add_labeled_option(vbox, "Map tile zoom", GameSettings.MAP_ZOOM_LABELS)

	var scale_row: HBoxContainer = HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 10)
	vbox.add_child(_label("Map scale multiplier"))
	vbox.add_child(scale_row)
	_map_scale_slider = HSlider.new()
	_map_scale_slider.min_value = 0.5
	_map_scale_slider.max_value = 3.0
	_map_scale_slider.step = 0.25
	_map_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_scale_slider.value_changed.connect(_on_map_scale_slider_changed)
	scale_row.add_child(_map_scale_slider)
	_map_scale_value = Label.new()
	_map_scale_value.custom_minimum_size = Vector2(40, 0)
	scale_row.add_child(_map_scale_value)

	_text_size_option = _add_labeled_option(vbox, "Inspector text", GameSettings.TEXT_SIZE_LABELS)

	var width_row: HBoxContainer = HBoxContainer.new()
	width_row.add_theme_constant_override("separation", 10)
	vbox.add_child(_label("Inspector panel width"))
	vbox.add_child(width_row)
	_panel_width_slider = HSlider.new()
	_panel_width_slider.min_value = 320.0
	_panel_width_slider.max_value = 960.0
	_panel_width_slider.step = 20.0
	_panel_width_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_width_slider.value_changed.connect(_on_panel_width_slider_changed)
	width_row.add_child(_panel_width_slider)
	_panel_width_value = Label.new()
	_panel_width_value.custom_minimum_size = Vector2(48, 0)
	width_row.add_child(_panel_width_value)

	vbox.add_child(HSeparator.new())
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(actions)
	_add_button_to(actions, "Apply", _apply_display)
	_add_button_to(actions, "Back", _show_main)


func _build_map_menu(panel: PanelContainer) -> void:
	var margin: MarginContainer = _margin(panel)
	var vbox: VBoxContainer = _vbox(margin)
	_add_title(vbox, "Map Settings")
	_add_hint(vbox, "Map overrides and character settings")

	_add_section(vbox, "Character")
	var scale_row: HBoxContainer = HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 10)
	vbox.add_child(_label("Display scale"))
	vbox.add_child(scale_row)
	_char_scale_slider = HSlider.new()
	_char_scale_slider.min_value = 0.25
	_char_scale_slider.max_value = 4.0
	_char_scale_slider.step = 0.05
	_char_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_char_scale_slider.value_changed.connect(_on_char_scale_changed)
	scale_row.add_child(_char_scale_slider)
	_char_scale_value = Label.new()
	_char_scale_value.custom_minimum_size = Vector2(40, 0)
	scale_row.add_child(_char_scale_value)

	vbox.add_child(HSeparator.new())
	_add_section(vbox, "Generation")
	_add_button(vbox, "Regenerate Map", func(): map_regenerate_requested.emit())
	_add_button(vbox, "New Seed", func(): map_reseed_requested.emit())
	_add_button(vbox, "Next Biome", func(): map_cycle_biome_requested.emit())
	var size_row: HBoxContainer = HBoxContainer.new()
	size_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(size_row)
	_add_button_to(size_row, "Map −", func(): map_resize_requested.emit(-2))
	_add_button_to(size_row, "Map +", func(): map_resize_requested.emit(2))

	vbox.add_child(HSeparator.new())
	_add_section(vbox, "Debug / Overlays")
	_add_button(vbox, "Toggle Center Cell", func(): map_toggle_center_requested.emit())
	_tile_labels_check = _add_tool_check(vbox, "Tile ID labels", func(b): map_tile_labels_toggled.emit(b))

	vbox.add_child(HSeparator.new())
	_add_section(vbox, "Boredom Tests")
	_boredom_atmo_check = _add_tool_check(vbox, "Boredom map (atmosphere)", func(b): map_boredom_atmosphere_toggled.emit(b))
	_boredom_water_check = _add_tool_check(vbox, "Boredom map (water)", func(b): map_boredom_water_toggled.emit(b))

	vbox.add_child(HSeparator.new())
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(actions)
	_add_button_to(actions, "Apply Settings", _apply_display)
	_add_button_to(actions, "Back", _show_main)

func _add_tool_check(parent: VBoxContainer, label_text: String, on_toggled: Callable) -> CheckButton:
	var check: CheckButton = CheckButton.new()
	check.text = label_text
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check.add_theme_font_size_override("font_size", 15)
	check.toggled.connect(on_toggled)
	parent.add_child(check)
	return check


func _add_section(parent: VBoxContainer, text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.95))
	parent.add_child(label)


func _apply_display() -> void:
	if _settings == null:
		return
	_read_controls_to_settings()
	_settings.apply_and_save(get_window())
	if _on_applied.is_valid():
		_on_applied.call()
	close_menu()


func _sync_controls_from_settings() -> void:
	_resolution_option.select(_settings.resolution_index())
	_window_mode_option.select(_settings.window_mode_index())
	_map_zoom_option.select(_settings.map_zoom_mode)
	_map_scale_slider.value = _settings.map_zoom_multiplier
	_on_map_scale_slider_changed(_settings.map_zoom_multiplier)
	_text_size_option.select(_settings.inspector_text_size_index)
	_panel_width_slider.value = float(_settings.inspector_panel_width)
	_on_panel_width_slider_changed(float(_settings.inspector_panel_width))
	if _char_profile != null:
		_char_scale_slider.value = _char_profile.display_scale
		_on_char_scale_changed(_char_profile.display_scale)


func _read_controls_to_settings() -> void:
	_settings.set_resolution_index(_resolution_option.selected)
	_settings.set_window_mode_index(_window_mode_option.selected)
	_settings.map_zoom_mode = _map_zoom_option.selected as GameSettings.MapZoomMode
	_settings.map_zoom_multiplier = _map_scale_slider.value
	_settings.inspector_text_size_index = _text_size_option.selected
	_settings.inspector_panel_width = int(_panel_width_slider.value)


func _show_main() -> void:
	_main_panel.visible = true
	_display_panel.visible = false
	_map_panel.visible = false
	if _effects_panel != null:
		_effects_panel.visible = false


func _show_effects() -> void:
	_sync_effects_checks()
	_main_panel.visible = false
	_display_panel.visible = false
	_map_panel.visible = false
	if _effects_panel != null:
		_effects_panel.visible = true


func _show_display() -> void:
	_sync_controls_from_settings()
	_main_panel.visible = false
	_display_panel.visible = true
	_map_panel.visible = false
	if _effects_panel != null:
		_effects_panel.visible = false


func _show_map_settings() -> void:
	_sync_controls_from_settings()
	_main_panel.visible = false
	_display_panel.visible = false
	_map_panel.visible = true
	if _effects_panel != null:
		_effects_panel.visible = false


func _on_map_scale_slider_changed(value: float) -> void:
	_map_scale_value.text = "%.2f×" % value


func _on_char_scale_changed(value: float) -> void:
	_char_scale_value.text = "%.2f×" % value
	if _char_profile != null:
		_char_profile.display_scale = value
	character_gen_changed.emit()


func _on_panel_width_slider_changed(value: float) -> void:
	_panel_width_value.text = "%d" % int(value)


func _margin(panel: PanelContainer) -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	return margin


func _vbox(parent: MarginContainer) -> VBoxContainer:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	parent.add_child(vbox)
	return vbox


func _add_title(vbox: VBoxContainer, text: String) -> void:
	var title: Label = Label.new()
	title.text = text
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	vbox.add_child(title)


func _add_hint(vbox: VBoxContainer, text: String) -> void:
	var hint: Label = Label.new()
	hint.text = text
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	vbox.add_child(hint)


func _add_button(vbox: VBoxContainer, text: String, callback: Callable) -> Button:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)
	return _add_button_to(row, text, callback)


func _add_button_to(parent: BoxContainer, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 32)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	return label


func _add_labeled_option(vbox: VBoxContainer, label_text: String, items: PackedStringArray) -> OptionButton:
	vbox.add_child(_label(label_text))
	var option: OptionButton = OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item: String in items:
		option.add_item(item)
	vbox.add_child(option)
	return option


func _build_combat_effects_panel() -> void:
	if _effects_panel == null or _effects_settings == null:
		return
	if _effects_panel.get_child_count() > 0:
		return
	var margin: MarginContainer = _margin(_effects_panel)
	var vbox: VBoxContainer = _vbox(margin)
	_add_title(vbox, "Ambient Effects")
	_add_hint(vbox, "Combat map living systems · saved automatically")
	vbox.add_child(HSeparator.new())
	var toggles: Array[Dictionary] = [
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
	for entry: Dictionary in toggles:
		var key: String = entry["key"]
		var check: CheckButton = CheckButton.new()
		check.text = entry["label"]
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		check.toggled.connect(func(pressed: bool) -> void: _on_effect_toggled(key, pressed))
		vbox.add_child(check)
		_effects_checks[key] = check
	vbox.add_child(HSeparator.new())
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(actions)
	_add_button_to(actions, "Back", _show_main)


func _sync_effects_checks() -> void:
	if _effects_settings == null:
		return
	for key: Variant in _effects_checks.keys():
		var check: CheckButton = _effects_checks[key] as CheckButton
		if check == null:
			continue
		check.set_block_signals(true)
		check.button_pressed = bool(_effects_settings.get(key))
		check.set_block_signals(false)


func _on_effect_toggled(key: String, pressed: bool) -> void:
	if _effects_settings == null:
		return
	_effects_settings.set(key, pressed)
	_effects_settings.save_to_disk()
	_effects_settings.changed.emit()
	if _on_effects_changed.is_valid():
		_on_effects_changed.call()


func _panel_style() -> StyleBoxFlat:
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.14, 0.98)
	bg.set_corner_radius_all(8)
	bg.set_border_width_all(1)
	bg.border_color = Color(0.35, 0.4, 0.52)
	bg.set_content_margin_all(4)
	return bg
