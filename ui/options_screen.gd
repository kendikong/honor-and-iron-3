class_name OptionsScreen
extends Control

## Unified settings — main menu scene and in-game overlay share this UI.

signal close_requested
signal map_regenerate_requested
signal map_reseed_requested
signal map_toggle_center_requested
signal map_resize_requested(delta: int)
signal map_cycle_biome_requested
signal map_tile_labels_toggled(pressed: bool)
signal map_boredom_atmosphere_toggled(pressed: bool)
signal map_boredom_water_toggled(pressed: bool)
signal character_gen_changed

var overlay_mode: bool = false
## In-game overlay: dim backdrop + side panel so the scene stays visible for live tweaks.
var live_preview: bool = false
var hide_developer_tab: bool = false
var show_sandbox_tools: bool = false

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
var _team_outlines_check: CheckButton
var _show_fps_check: CheckButton
var _show_tod_check: CheckButton
var _effect_checks: Dictionary = {}
var _dev_shadow_checks: Dictionary = {}
var _dev_tile_labels_check: CheckButton
var _dev_boredom_atmo_check: CheckButton
var _dev_boredom_water_check: CheckButton
var _developer_tab_root: MarginContainer
var _sandbox_tools_box: VBoxContainer
var _sandbox_tile_labels_check: CheckButton
var _sandbox_boredom_atmo_check: CheckButton
var _sandbox_boredom_water_check: CheckButton
var _char_profile: CharacterGenProfile
var _char_scale_slider: HSlider
var _char_scale_label: Label
var _on_applied: Callable
var _on_effects_changed: Callable
var _pending_settings: GameSettings
var _pending_effects: EffectsSettings


func setup(
	settings: GameSettings,
	on_applied: Callable = Callable(),
	effects: EffectsSettings = null,
	on_effects_changed: Callable = Callable(),
) -> void:
	_pending_settings = settings
	_on_applied = on_applied
	_pending_effects = effects
	_on_effects_changed = on_effects_changed
	if is_node_ready() and _game_settings != settings:
		_game_settings = settings
		if effects != null:
			_effects_settings = effects


func setup_character_gen(profile: CharacterGenProfile) -> void:
	_char_profile = profile
	if _char_scale_slider != null and profile != null:
		_char_scale_slider.set_block_signals(true)
		_char_scale_slider.value = profile.display_scale
		_on_char_scale_changed(profile.display_scale)
		_char_scale_slider.set_block_signals(false)


func set_map_tool_state(tile_labels: bool, boredom_atmosphere: bool, boredom_water: bool) -> void:
	if _sandbox_tile_labels_check != null:
		_sandbox_tile_labels_check.set_block_signals(true)
		_sandbox_tile_labels_check.button_pressed = tile_labels
		_sandbox_tile_labels_check.set_block_signals(false)
	if _sandbox_boredom_atmo_check != null:
		_sandbox_boredom_atmo_check.set_block_signals(true)
		_sandbox_boredom_atmo_check.button_pressed = boredom_atmosphere
		_sandbox_boredom_atmo_check.set_block_signals(false)
	if _sandbox_boredom_water_check != null:
		_sandbox_boredom_water_check.set_block_signals(true)
		_sandbox_boredom_water_check.button_pressed = boredom_water
		_sandbox_boredom_water_check.set_block_signals(false)


func _ready() -> void:
	if overlay_mode:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if live_preview:
		_apply_live_preview_chrome()
	else:
		$ColorRect.color = MenuTheme.BG
		MenuTheme.style_title($Title)
		$Title.text = "Settings"
		$Title.add_theme_color_override("font_color", MenuTheme.TEXT)
		$BackButton.text = "Close" if overlay_mode else "Back"
		MenuTheme.style_menu_button($BackButton)
		$BackButton.pressed.connect(_on_back_pressed)
		MenuNavigation.register(self, _on_back_pressed)

	if _pending_settings != null:
		_game_settings = _pending_settings
	else:
		_game_settings = GameSettings.new()
		_game_settings.load_from_disk()

	if _pending_effects != null:
		_effects_settings = _pending_effects
	else:
		_effects_settings = EffectsSettings.new()
		_effects_settings.load_from_disk()

	var tab_host: Control = _build_tab_host()
	var tab_container := TabContainer.new()
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_host.add_child(tab_container)

	_build_display_tab(tab_container)
	_build_graphics_tab(tab_container)
	_build_sound_tab(tab_container)
	_build_interface_tab(tab_container)
	_build_gameplay_tab(tab_container)
	_build_controls_tab(tab_container)
	_build_developer_tab(tab_container)
	if hide_developer_tab and _developer_tab_root != null:
		_developer_tab_root.visible = false
	if _sandbox_tools_box != null:
		_sandbox_tools_box.visible = show_sandbox_tools
	_apply_interface_to_ui()


func _build_tab_host() -> Control:
	if not live_preview:
		var margin := MarginContainer.new()
		MenuInterfaceApplier.stamp_content_margin(margin)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 48)
		margin.add_theme_constant_override("margin_right", 48)
		margin.add_theme_constant_override("margin_top", 120)
		margin.add_theme_constant_override("margin_bottom", 48)
		add_child(margin)
		return margin

	$Title.visible = false
	$BackButton.visible = false

	var panel := PanelContainer.new()
	panel.name = "LivePreviewPanel"
	MenuTheme.apply_panel(panel)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -508.0
	panel.offset_top = 12.0
	panel.offset_right = -12.0
	panel.offset_bottom = -12.0
	add_child(panel)

	var outer_margin := MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 14)
	outer_margin.add_theme_constant_override("margin_right", 14)
	outer_margin.add_theme_constant_override("margin_top", 12)
	outer_margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(outer_margin)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 10)
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_margin.add_child(shell)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	shell.add_child(header)

	var title := Label.new()
	title.text = "Settings"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MenuTheme.style_title(title)
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "Close"
	MenuTheme.style_menu_button(close_btn)
	close_btn.custom_minimum_size = Vector2(96.0, 36.0)
	close_btn.pressed.connect(_on_back_pressed)
	header.add_child(close_btn)
	MenuNavigation.register(self, _on_back_pressed)

	var hint := Label.new()
	hint.text = "Game stays visible — graphics and display changes apply live."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MenuTheme.style_muted_label(hint)
	shell.add_child(hint)

	var tab_wrap := MarginContainer.new()
	tab_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_child(tab_wrap)
	return tab_wrap


func _apply_live_preview_chrome() -> void:
	$ColorRect.color = Color(0.02, 0.03, 0.06, 0.38)
	$ColorRect.mouse_filter = Control.MOUSE_FILTER_STOP


func _build_display_tab(parent: TabContainer) -> void:
	var scroll := _scroll_tab(parent, "Display")
	var vbox := _vbox(scroll)
	_add_hint(vbox, "Video changes need Apply. Map camera settings apply immediately.")

	_add_section(vbox, "Video")
	_resolution_option = OptionButton.new()
	for res: Vector2i in GameSettings.RESOLUTION_PRESETS:
		_resolution_option.add_item("%d × %d" % [res.x, res.y])
	_resolution_option.select(_game_settings.resolution_index())
	_resolution_option.item_selected.connect(func(_i: int) -> void: _sync_resolution_controls())
	vbox.add_child(_label("Resolution"))
	vbox.add_child(_resolution_option)
	_resolution_status_label = Label.new()
	MenuInterfaceApplier.stamp_font_tier(_resolution_status_label, MenuInterfaceApplier.TIER_HINT)
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

	_add_section(vbox, "Map camera")
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
	MenuInterfaceApplier.stamp_font_tier(_map_scale_label, MenuInterfaceApplier.TIER_VALUE)
	_map_scale_label.custom_minimum_size.x = 48
	scale_row.add_child(_map_scale_slider)
	scale_row.add_child(_map_scale_label)
	vbox.add_child(_label("Map scale multiplier"))
	vbox.add_child(scale_row)
	_on_map_scale_changed(_game_settings.map_zoom_multiplier)

	_add_section(vbox, "On-screen HUD")
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
	var hint_text := (
		"Ambient living-map effects — saved automatically. Toggle while the game is visible behind this panel."
		if live_preview
		else "Ambient living-map effects — saved automatically."
	)
	_add_hint(vbox, hint_text)

	for entry: Dictionary in _EFFECT_TOGGLES:
		var key: String = entry["key"]
		var check := CheckButton.new()
		check.text = entry["label"]
		check.button_pressed = bool(_effects_settings.get(key))
		check.toggled.connect(func(pressed: bool) -> void: _on_effect_toggled(key, pressed))
		vbox.add_child(check)
		_effect_checks[key] = check


func _build_sound_tab(parent: TabContainer) -> void:
	var scroll := _scroll_tab(parent, "Audio")
	var vbox := _vbox(scroll)
	_add_hint(vbox, "Volume changes apply immediately.")

	_master_slider = _add_volume_row(vbox, "Master volume", _game_settings.master_volume)
	_sfx_slider = _add_volume_row(vbox, "Sound effects", _game_settings.sfx_volume)
	_music_slider = _add_volume_row(vbox, "Music", _game_settings.music_volume)


func _build_gameplay_tab(parent: TabContainer) -> void:
	var scroll := _scroll_tab(parent, "Gameplay")
	var vbox := _vbox(scroll)
	_add_hint(vbox, "Core combat rules — not configurable.")

	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = (
		"Honor & Iron uses perfect information: enemy intent is always visible "
		+ "during planning. Timeline programming is always available in combat."
	)
	MenuInterfaceApplier.stamp_font_tier(info, MenuInterfaceApplier.TIER_BODY)
	info.add_theme_color_override("font_color", MenuTheme.TEXT)
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
	MenuInterfaceApplier.stamp_font_tier(_ui_scale_label, MenuInterfaceApplier.TIER_VALUE)
	vbox.add_child(_label("UI layout scale (panels & buttons)"))
	vbox.add_child(_slider_value_row(_ui_scale_slider, _ui_scale_label))
	_on_ui_scale_changed(_game_settings.combat_ui_scale)

	_text_scale_slider = HSlider.new()
	_text_scale_slider.min_value = 0.75
	_text_scale_slider.max_value = 2.5
	_text_scale_slider.step = 0.05
	_text_scale_slider.value = _game_settings.combat_text_scale
	_text_scale_slider.value_changed.connect(_on_text_scale_changed)
	_text_scale_label = Label.new()
	MenuInterfaceApplier.stamp_font_tier(_text_scale_label, MenuInterfaceApplier.TIER_VALUE)
	vbox.add_child(_label("Text scale"))
	vbox.add_child(_slider_value_row(_text_scale_slider, _text_scale_label))
	_on_text_scale_changed(_game_settings.combat_text_scale)

	_text_size_option = OptionButton.new()
	_text_size_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for label: String in GameSettings.TEXT_SIZE_LABELS:
		_text_size_option.add_item(label)
	_text_size_option.select(_game_settings.inspector_text_size_index)
	_text_size_option.item_selected.connect(func(_i: int) -> void:
		_game_settings.inspector_text_size_index = _text_size_option.selected
		_apply_interface_live(),
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
	MenuInterfaceApplier.stamp_font_tier(_panel_width_label, MenuInterfaceApplier.TIER_VALUE)
	vbox.add_child(_label("Inspector panel width"))
	vbox.add_child(_slider_value_row(_panel_width_slider, _panel_width_label))
	_on_panel_width_changed(float(_game_settings.inspector_panel_width))

	_damage_numbers_check = CheckButton.new()
	_damage_numbers_check.text = "Show floating damage numbers"
	_damage_numbers_check.button_pressed = _game_settings.show_damage_numbers
	_damage_numbers_check.toggled.connect(func(pressed: bool) -> void:
		_game_settings.show_damage_numbers = pressed
		_save_game_settings(),
	)
	vbox.add_child(_damage_numbers_check)

	_team_outlines_check = CheckButton.new()
	_team_outlines_check.text = "Always show team outlines (blue allies, red enemies)"
	_team_outlines_check.button_pressed = _game_settings.show_team_outlines
	_team_outlines_check.toggled.connect(func(pressed: bool) -> void:
		_game_settings.show_team_outlines = pressed
		_save_game_settings(),
	)
	vbox.add_child(_team_outlines_check)

	if _char_profile != null:
		_add_section(vbox, "Units on map")
		_char_scale_slider = HSlider.new()
		_char_scale_slider.min_value = 0.25
		_char_scale_slider.max_value = 4.0
		_char_scale_slider.step = 0.05
		_char_scale_slider.value = _char_profile.display_scale
		_char_scale_slider.value_changed.connect(_on_char_scale_changed)
		_char_scale_label = Label.new()
		MenuInterfaceApplier.stamp_font_tier(_char_scale_label, MenuInterfaceApplier.TIER_VALUE)
		vbox.add_child(_label("Character display scale"))
		vbox.add_child(_slider_value_row(_char_scale_slider, _char_scale_label))
		_on_char_scale_changed(_char_profile.display_scale)


func _on_char_scale_changed(value: float) -> void:
	if _char_scale_label != null:
		_char_scale_label.text = "%.2f×" % value
	if _char_profile != null:
		_char_profile.display_scale = value
		_char_profile.save_to_user_disk()
		character_gen_changed.emit()


func _build_developer_tab(parent: TabContainer) -> void:
	var scroll := _scroll_tab(parent, "Developer")
	_developer_tab_root = scroll.get_parent() as MarginContainer
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

	_sandbox_tools_box = VBoxContainer.new()
	vbox.add_child(_sandbox_tools_box)
	_add_section(_sandbox_tools_box, "Map sandbox tools")
	_add_hint(_sandbox_tools_box, "Only used in the map dev sandbox scene.")
	_add_button(_sandbox_tools_box, "Regenerate map", func() -> void: map_regenerate_requested.emit())
	_add_button(_sandbox_tools_box, "New seed", func() -> void: map_reseed_requested.emit())
	_add_button(_sandbox_tools_box, "Next biome", func() -> void: map_cycle_biome_requested.emit())
	var size_row := HBoxContainer.new()
	size_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_sandbox_tools_box.add_child(size_row)
	var minus_btn := Button.new()
	minus_btn.text = "Map −"
	minus_btn.pressed.connect(func() -> void: map_resize_requested.emit(-2))
	size_row.add_child(minus_btn)
	var plus_btn := Button.new()
	plus_btn.text = "Map +"
	plus_btn.pressed.connect(func() -> void: map_resize_requested.emit(2))
	size_row.add_child(plus_btn)
	_add_button(_sandbox_tools_box, "Toggle center cell", func() -> void: map_toggle_center_requested.emit())
	_sandbox_tile_labels_check = CheckButton.new()
	_sandbox_tile_labels_check.text = "Tile ID labels"
	_sandbox_tile_labels_check.toggled.connect(func(pressed: bool) -> void: map_tile_labels_toggled.emit(pressed))
	_sandbox_tools_box.add_child(_sandbox_tile_labels_check)
	_sandbox_boredom_atmo_check = CheckButton.new()
	_sandbox_boredom_atmo_check.text = "Boredom test — atmosphere only"
	_sandbox_boredom_atmo_check.toggled.connect(func(pressed: bool) -> void: map_boredom_atmosphere_toggled.emit(pressed))
	_sandbox_tools_box.add_child(_sandbox_boredom_atmo_check)
	_sandbox_boredom_water_check = CheckButton.new()
	_sandbox_boredom_water_check.text = "Boredom test — water only"
	_sandbox_boredom_water_check.toggled.connect(func(pressed: bool) -> void: map_boredom_water_toggled.emit(pressed))
	_sandbox_tools_box.add_child(_sandbox_boredom_water_check)


func _apply_display_video() -> void:
	_game_settings.set_resolution_index(_resolution_option.selected)
	_game_settings.set_window_mode_index(_window_mode_option.selected)
	_game_settings.apply_and_save(get_window(), true)
	_sync_resolution_controls()
	_notify_settings_applied()


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
	_apply_interface_live()


func _on_text_scale_changed(value: float) -> void:
	_text_scale_label.text = "%.2f×" % value
	_game_settings.combat_text_scale = value
	_apply_interface_live()


func _on_panel_width_changed(value: float) -> void:
	_panel_width_label.text = "%d" % int(value)
	_game_settings.inspector_panel_width = int(value)
	_apply_interface_live()


func _apply_interface_live() -> void:
	if _text_size_option != null:
		_game_settings.inspector_text_size_index = _text_size_option.selected
	if _panel_width_slider != null:
		_game_settings.inspector_panel_width = int(_panel_width_slider.value)
	_game_settings.save_to_disk()
	_game_settings.changed.emit()
	_apply_interface_to_ui()
	EventBus.interface_settings_changed.emit()
	_notify_settings_applied()


func _notify_settings_applied() -> void:
	if _on_applied.is_valid():
		_on_applied.call()


func _apply_interface_to_ui() -> void:
	MenuInterfaceApplier.apply(self, _game_settings)


func _on_effect_toggled(key: String, pressed: bool) -> void:
	_effects_settings.set(key, pressed)
	_effects_settings.save_to_disk()
	_effects_settings.changed.emit()
	if _on_effects_changed.is_valid():
		_on_effects_changed.call()


func _on_shadow_debug_toggled(key: String, pressed: bool) -> void:
	_effects_settings.set(key, pressed)
	_effects_settings.save_to_disk()
	_effects_settings.changed.emit()
	if _on_effects_changed.is_valid():
		_on_effects_changed.call()


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
	MenuInterfaceApplier.stamp_font_tier(value_lbl, MenuInterfaceApplier.TIER_VALUE)
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
	_notify_settings_applied()


func _slider_value_row(slider: HSlider, value_label: Label) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.custom_minimum_size.x = 56
	MenuInterfaceApplier.stamp_font_tier(value_label, MenuInterfaceApplier.TIER_VALUE)
	row.add_child(slider)
	row.add_child(value_label)
	return row


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
	MenuInterfaceApplier.stamp_font_tier(lbl, MenuInterfaceApplier.TIER_BODY)
	return lbl


func _add_hint(parent: VBoxContainer, text: String) -> void:
	var hint := Label.new()
	hint.text = text
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MenuTheme.style_muted_label(hint)
	parent.add_child(hint)


func _add_section(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	MenuTheme.style_section_label(lbl)
	parent.add_child(lbl)


func _add_button(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	parent.add_child(btn)


func _on_back_pressed() -> void:
	if overlay_mode or close_requested.get_connections().size() > 0:
		close_requested.emit()
	else:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
