class_name WorldClockHud
extends CanvasLayer

## In-game clock — top center above the map.

var _panel: PanelContainer
var _label: Label
var _skip_night_button: Button
var _skip_dusk_button: Button
var _map_rect: Rect2 = Rect2()


func _ready() -> void:
	layer = 25
	_build_ui()
	if not WeatherBus.state_changed.is_connected(_on_weather_changed):
		WeatherBus.state_changed.connect(_on_weather_changed)
	get_viewport().size_changed.connect(_reposition)
	_refresh()
	_reposition()


func configure_map_rect(map_rect: Rect2) -> void:
	_map_rect = map_rect
	_reposition()


func _build_ui() -> void:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(0.94, 0.95, 1.0))
	vbox.add_child(_label)

	var skip_row: HBoxContainer = HBoxContainer.new()
	skip_row.add_theme_constant_override("separation", 6)
	vbox.add_child(skip_row)

	_skip_night_button = Button.new()
	_skip_night_button.text = "Skip night → 5 AM"
	_skip_night_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skip_night_button.add_theme_font_size_override("font_size", 13)
	_skip_night_button.pressed.connect(_on_skip_night_pressed)
	skip_row.add_child(_skip_night_button)

	_skip_dusk_button = Button.new()
	_skip_dusk_button.text = "Skip to dusk → 4 PM"
	_skip_dusk_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skip_dusk_button.add_theme_font_size_override("font_size", 13)
	_skip_dusk_button.pressed.connect(_on_skip_dusk_pressed)
	skip_row.add_child(_skip_dusk_button)

	var speed_opt: OptionButton = OptionButton.new()
	speed_opt.add_item("1x (1 min/s)", 1)
	speed_opt.add_item("5x (5 min/s)", 5)
	speed_opt.add_item("15x (15 min/s)", 15)
	speed_opt.add_item("60x (1 hr/s)", 60)
	speed_opt.select(0) # Default 1x
	speed_opt.item_selected.connect(func(idx: int): WeatherBus.set_time_speed(float(speed_opt.get_item_id(idx))))
	skip_row.add_child(speed_opt)

	var fast_night_box: CheckBox = CheckBox.new()
	fast_night_box.text = "Fast Night (2x)"
	fast_night_box.button_pressed = true
	fast_night_box.add_theme_font_size_override("font_size", 13)
	fast_night_box.toggled.connect(func(toggled: bool): WeatherBus.set_fast_night(toggled))
	skip_row.add_child(fast_night_box)


func _on_skip_night_pressed() -> void:
	WeatherBus.skip_night_to_dawn()


func _on_skip_dusk_pressed() -> void:
	WeatherBus.skip_to_dusk()


func _on_weather_changed() -> void:
	_refresh()


func _refresh() -> void:
	if _label == null:
		return
	_label.text = WeatherBus.clock_display_text()


func _reposition() -> void:
	if _panel == null or _map_rect.size.x < 1.0:
		return
	var panel_size: Vector2 = _panel.get_combined_minimum_size()
	_panel.position = Vector2(
		_map_rect.position.x + (_map_rect.size.x - panel_size.x) * 0.5,
		_map_rect.position.y + 8.0,
	)


func _panel_style() -> StyleBoxFlat:
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.06, 0.1, 0.88)
	bg.border_width_left = 1
	bg.border_width_top = 1
	bg.border_width_right = 1
	bg.border_width_bottom = 1
	bg.border_color = Color(0.32, 0.36, 0.48)
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	return bg
