class_name DebugReportDialog
extends Control

## Owner-facing report form. The service supplies all automatic runtime context;
## this form only collects the human description of what felt wrong.

var _service: DebugReportRuntime
var _category: OptionButton
var _severity: OptionButton
var _title: LineEdit
var _description: TextEdit
var _expected: TextEdit
var _actual: TextEdit
var _screenshot: CheckBox
var _status: Label
var _save_button: Button
var _saving: bool = false


func setup(service: DebugReportRuntime) -> void:
	_service = service
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = MenuTheme.BG_DIM
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var viewport_size := get_viewport_rect().size
	panel.custom_minimum_size = Vector2(
		clampf(viewport_size.x - 48.0, 360.0, 780.0),
		clampf(viewport_size.y - 48.0, 420.0, 700.0),
	)
	add_child(panel)
	MenuTheme.apply_panel(panel)

	var margin := MarginContainer.new()
	for key: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(key, 18)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	scroll.add_child(root)

	var title := Label.new()
	title.text = "REPORT A BUG"
	title.add_theme_font_size_override("font_size", 28)
	MenuTheme.style_title(title)
	root.add_child(title)

	var explanation := Label.new()
	explanation.text = (
		"Describe what you saw. The report automatically includes the current "
		+ "scene, board, units, timeline, preview, recent actions, runtime metadata, "
		+ "and optional screenshot."
	)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MenuTheme.style_muted_label(explanation)
	root.add_child(explanation)

	var metadata := HBoxContainer.new()
	metadata.add_theme_constant_override("separation", 8)
	root.add_child(metadata)
	_category = _add_option(metadata, "Bug", ["Bug", "Design concern", "Balance concern", "Visual polish"])
	_severity = _add_option(metadata, "Medium", ["Blocker", "High", "Medium", "Low"])

	_title = _add_line_edit(root, "Short title", "Example: Blink preview shows an unreachable tile")
	_description = _add_text_edit(
		root,
		"What happened?",
		"Explain the exact steps or what felt wrong.",
		90,
	)
	_expected = _add_text_edit(
		root,
		"What did you expect? (optional)",
		"Example: The red overlay should include only tiles within range.",
		55,
	)
	_actual = _add_text_edit(
		root,
		"What actually happened? (optional)",
		"Example: The tile was red, but commit rejected the action.",
		55,
	)

	_screenshot = CheckBox.new()
	_screenshot.text = "Attach one screenshot (captures only when I press Save)"
	_screenshot.button_pressed = false
	root.add_child(_screenshot)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)
	root.add_child(buttons)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size.x = 120
	MenuTheme.style_menu_button(cancel)
	cancel.pressed.connect(_service.close_report_dialog)
	buttons.add_child(cancel)
	var save := Button.new()
	save.text = "Save Bug Report"
	save.custom_minimum_size.x = 180
	MenuTheme.style_menu_button(save)
	save.pressed.connect(_save_report)
	_save_button = save
	buttons.add_child(save)
	_title.call_deferred("grab_focus")


func _save_report() -> void:
	if _saving:
		return
	var title := _title.text.strip_edges()
	var description := _description.text.strip_edges()
	if title.is_empty() or description.is_empty():
		_status.text = "Please provide a short title and describe what happened."
		return
	_saving = true
	if _save_button != null:
		_save_button.disabled = true
	_status.text = "Saving report..."
	var result := _service.submit_report(
		_category.get_item_text(_category.selected),
		_severity.get_item_text(_severity.selected),
		title,
		description,
		_expected.text,
		_actual.text,
		_screenshot.button_pressed,
	)
	var paths: Array = result.get("display_paths", result.get("paths", []))
	if paths.is_empty():
		_status.text = "Could not write the report. Check the Godot user-data folder permissions."
		_saving = false
		if _save_button != null:
			_save_button.disabled = false
		return
	var report_id_text: String = str(result.get("report_id", "report"))
	var path_text: String = "\n".join(paths)
	_status.text = "Saved %s\n%s" % [report_id_text, path_text]
	await get_tree().create_timer(1.0, true).timeout
	_service.close_report_dialog()


func _add_option(parent: HBoxContainer, default_text: String, values: Array[String]) -> OptionButton:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 2)
	parent.add_child(group)
	var label := Label.new()
	label.text = "Category" if default_text == "Bug" else "Severity"
	MenuTheme.style_section_label(label)
	group.add_child(label)
	var option := OptionButton.new()
	for value: String in values:
		option.add_item(value)
	option.select(values.find(default_text))
	option.custom_minimum_size.x = 180
	group.add_child(option)
	return option


func _add_line_edit(parent: VBoxContainer, placeholder: String, tooltip: String) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.tooltip_text = tooltip
	field.custom_minimum_size.y = 38
	parent.add_child(field)
	return field


func _add_text_edit(
	parent: VBoxContainer,
	placeholder: String,
	tooltip: String,
	height: float,
) -> TextEdit:
	var field := TextEdit.new()
	field.placeholder_text = placeholder
	field.tooltip_text = tooltip
	field.custom_minimum_size.y = height
	field.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	parent.add_child(field)
	return field
