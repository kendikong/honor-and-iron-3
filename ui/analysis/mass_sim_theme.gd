class_name MassSimTheme
extends RefCounted

## Dark analytics styling aligned with MenuTheme.


static func style_root(control: Control) -> void:
	control.add_theme_color_override("font_color", MenuTheme.TEXT)


static func apply_panel(panel: PanelContainer) -> void:
	MenuTheme.apply_panel(panel)


static func apply_popup(popup: PopupPanel) -> void:
	MenuTheme.apply_popup(popup)


static func style_title(label: Label) -> void:
	MenuTheme.style_title(label)


static func style_muted(label: Label) -> void:
	MenuTheme.style_muted_label(label)


static func style_section(label: Label) -> void:
	MenuTheme.style_section_label(label)


static func style_button(btn: Button) -> void:
	MenuTheme.style_menu_button(btn)


static func make_kpi_card(title: String, body: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	apply_panel(panel)
	panel.custom_minimum_size = Vector2(160, 90)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var title_lbl := Label.new()
	title_lbl.text = title
	style_muted(title_lbl)
	vbox.add_child(title_lbl)
	var body_lbl := Label.new()
	body_lbl.text = body
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	body_lbl.add_theme_color_override("font_color", accent)
	vbox.add_child(body_lbl)
	return panel


static func make_kpi_card_rich(title: String, body_bbcode: String) -> PanelContainer:
	var panel := PanelContainer.new()
	apply_panel(panel)
	panel.custom_minimum_size = Vector2(160, 90)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var title_lbl := Label.new()
	title_lbl.text = title
	style_muted(title_lbl)
	vbox.add_child(title_lbl)
	var body_lbl := RichTextLabel.new()
	body_lbl.bbcode_enabled = true
	body_lbl.fit_content = true
	body_lbl.scroll_active = false
	body_lbl.text = body_bbcode
	vbox.add_child(body_lbl)
	return panel


static func color_hex(color: Color) -> String:
	return color.to_html(false)


static func directional_color(value: float, average: float, tolerance: float) -> Color:
	var delta: float = value - average
	var abs_dev: float = absf(delta)
	if abs_dev <= tolerance:
		return Color(0.62, 0.66, 0.72)
	var intensity: float = clampf((abs_dev - tolerance) / maxf(tolerance, 0.001), 0.0, 1.0)
	if delta > 0.0:
		return Color(0.55, 0.88, 1.0).lerp(Color(0.15, 0.45, 1.0), intensity)
	return Color(1.0, 0.78, 0.42).lerp(Color(0.95, 0.32, 0.32), intensity)


static func directional_color_inverted(value: float, average: float, tolerance: float) -> Color:
	return directional_color(average - (value - average), average, tolerance)


static func dev_color_vs_average(value: float, average: float, tolerance: float) -> Color:
	return directional_color(value, average, tolerance)


static func dev_color(current: float, target: float, tolerance: float) -> Color:
	var dev: float = absf(current - target)
	if dev <= tolerance:
		return Color(0.49, 0.81, 0.63)
	if dev <= tolerance * 2.0:
		return Color(1.0, 0.71, 0.28)
	return Color(0.98, 0.45, 0.45)
