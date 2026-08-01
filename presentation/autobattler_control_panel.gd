class_name AutobattlerControlPanel
extends CanvasLayer

## Collapsible autobattler controls — small top-right toggle, expands on demand.

const PANEL_WIDTH: int = 260
const PANEL_HEIGHT_EXPANDED: float = 196.0
const PANEL_HEIGHT_COLLAPSED: float = 34.0
const PREFS_PATH: String = "user://autobattler_panel_prefs.cfg"

var _director: CombatDirector
var _hook: AutobattlerHookRegistry

var _root: PanelContainer
var _body: VBoxContainer
var _toggle_btn: Button
var _title_label: Label
var _collapsed: bool = true
var _full_active: bool = false
var _phase_active: bool = false
var _full_btn: Button
var _phase_btn: Button
var _aggro_label: Label


func setup(director: CombatDirector, unit_layer: TacticalUnitLayer = null) -> void:
	_director = director
	_hook = AutobattlerHookRegistry.new(director)
	_hook.set_unit_layer(unit_layer)
	layer = 23
	_load_prefs()
	_build_ui()
	_set_collapsed(_collapsed)


func _load_prefs() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PREFS_PATH) == OK:
		_collapsed = cfg.get_value("panel", "collapsed", true)


func _save_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("panel", "collapsed", _collapsed)
	cfg.save(PREFS_PATH)


func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.name = "AutobattlerPanel"
	_root.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_root.offset_top = 8.0
	_root.offset_right = -8.0
	_root.offset_left = -(float(PANEL_WIDTH) + 8.0)
	_root.offset_bottom = PANEL_HEIGHT_COLLAPSED + 8.0
	_root.add_theme_stylebox_override("panel", _panel_style())
	add_child(_root)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_root.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	margin.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	outer.add_child(header)

	_toggle_btn = Button.new()
	_toggle_btn.text = "AI"
	_toggle_btn.tooltip_text = "Autobattler controls"
	_toggle_btn.flat = true
	_toggle_btn.custom_minimum_size = Vector2(28.0, 22.0)
	_toggle_btn.pressed.connect(_on_toggle_pressed)
	header.add_child(_toggle_btn)

	var title := Label.new()
	title.text = "Autobattler"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.82, 0.86, 0.95))
	header.add_child(title)
	_title_label = title

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	outer.add_child(_body)

	_add_hint(_body, "AI plans your turn. Full mode auto-executes.")

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	_body.add_child(btn_row)

	_full_btn = _add_toggle_button(btn_row, "Full: OFF", _on_full_pressed)
	_phase_btn = _add_toggle_button(btn_row, "Assist: OFF", _on_phase_pressed)

	var aggro_row := HBoxContainer.new()
	aggro_row.add_theme_constant_override("separation", 8)
	_body.add_child(aggro_row)

	_aggro_label = Label.new()
	_aggro_label.text = "Aggro 0.50"
	_aggro_label.custom_minimum_size.x = 72.0
	_aggro_label.add_theme_font_size_override("font_size", 12)
	aggro_row.add_child(_aggro_label)

	var aggro_slider := HSlider.new()
	aggro_slider.min_value = 0.0
	aggro_slider.max_value = 1.0
	aggro_slider.step = 0.05
	aggro_slider.value = 0.5
	aggro_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aggro_slider.value_changed.connect(_on_aggro_changed)
	aggro_row.add_child(aggro_slider)


func _add_toggle_button(parent: Control, text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn


func _add_hint(parent: VBoxContainer, text: String) -> void:
	var hint := Label.new()
	hint.text = text
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
	parent.add_child(hint)


func _on_toggle_pressed() -> void:
	_set_collapsed(not _collapsed)
	_save_prefs()


func _set_collapsed(collapsed: bool) -> void:
	_collapsed = collapsed
	if _body != null:
		_body.visible = not _collapsed
	if _title_label != null:
		_title_label.visible = not _collapsed
	if _toggle_btn != null:
		_toggle_btn.text = "AI" if _collapsed else "▾"
		_toggle_btn.tooltip_text = "Open autobattler controls" if _collapsed else "Collapse"
	if _root != null:
		var height: float = PANEL_HEIGHT_COLLAPSED if _collapsed else PANEL_HEIGHT_EXPANDED
		_root.offset_bottom = height + 8.0


func _on_full_pressed() -> void:
	_full_active = not _full_active
	if _full_active:
		_phase_active = false
		_hook.set_active(true, true)
		_full_btn.text = "Full: ON"
		_phase_btn.text = "Assist: OFF"
	else:
		_hook.set_active(false)
		_full_btn.text = "Full: OFF"


func _on_phase_pressed() -> void:
	_phase_active = not _phase_active
	if _phase_active:
		_full_active = false
		_hook.set_active(true, false)
		_phase_btn.text = "Assist: ON"
		_full_btn.text = "Full: OFF"
	else:
		_hook.set_active(false)
		_phase_btn.text = "Assist: OFF"


func _on_aggro_changed(value: float) -> void:
	if _aggro_label != null:
		_aggro_label.text = "Aggro %.2f" % value
	if _hook != null and _hook._ai_instance != null:
		_hook._ai_instance.aggressiveness = value


func _panel_style() -> StyleBoxFlat:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.14, 0.82)
	bg.set_corner_radius_all(6)
	bg.set_border_width_all(1)
	bg.border_color = Color(0.32, 0.38, 0.5, 0.9)
	bg.set_content_margin_all(2)
	return bg
