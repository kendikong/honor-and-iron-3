class_name FpsHud
extends CanvasLayer

## Smoothed FPS readout â€” top-right above the map viewport.

var _panel: PanelContainer
var _label: Label
var _map_rect: Rect2 = Rect2()
var _fps: float = 60.0


func _ready() -> void:
	layer = 25
	_build_ui()
	get_viewport().size_changed.connect(_reposition)


func configure_map_rect(map_rect: Rect2) -> void:
	_map_rect = map_rect
	_reposition()


func _process(delta: float) -> void:
	if delta > 0.0:
		var instant: float = 1.0 / delta
		_fps = lerpf(_fps, instant, clampf(delta * 8.0, 0.0, 1.0))
	if _label != null:
		_label.text = "%d FPS" % int(round(_fps))


func _build_ui() -> void:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	_panel.add_child(margin)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0))
	_label.text = "-- FPS"
	margin.add_child(_label)


func _reposition() -> void:
	if _panel == null or _map_rect.size.x < 1.0:
		return
	var panel_size: Vector2 = _panel.get_combined_minimum_size()
	_panel.position = Vector2(
		_map_rect.position.x + _map_rect.size.x - panel_size.x - 8.0,
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
