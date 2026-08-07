extends Label

func _make_custom_tooltip(for_text: String) -> Control:
	var rtol := RichTextLabel.new()
	rtol.bbcode_enabled = true
	rtol.text = for_text
	rtol.fit_content = true
	rtol.custom_minimum_size = Vector2(300, 150)
	
	# Give it a nice clean dark panel style
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.25, 0.25, 0.3, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	
	panel.add_child(rtol)
	return panel
