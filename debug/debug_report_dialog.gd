class_name DebugReportDialog
extends Control

## Owner-facing report form + history. The service supplies runtime context and persistence.

enum HistoryFilter { ACTIVE, ALL, TRASH }

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
var _tabs: TabContainer
var _history_filter: OptionButton
var _history_list: VBoxContainer
var _history_status: Label
var _history_filter_mode: int = HistoryFilter.ACTIVE


func setup(service: DebugReportRuntime) -> void:
	_service = service
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	if _service != null and not _service.report_status_changed.is_connected(_on_report_status_changed):
		_service.report_status_changed.connect(_on_report_status_changed)
	call_deferred("_refresh_history_list")


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = MenuTheme.BG_DIM
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var viewport_size := get_viewport_rect().size
	panel.custom_minimum_size = Vector2(
		clampf(viewport_size.x - 48.0, 360.0, 820.0),
		clampf(viewport_size.y - 48.0, 420.0, 720.0),
	)
	add_child(panel)
	MenuTheme.apply_panel(panel)

	var margin := MarginContainer.new()
	for key: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(key, 18)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)

	var heading := Label.new()
	heading.text = "BUG REPORTS"
	heading.add_theme_font_size_override("font_size", 28)
	MenuTheme.style_title(heading)
	outer.add_child(heading)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.tab_changed.connect(_on_tab_changed)
	outer.add_child(_tabs)

	_build_new_report_tab()
	_build_history_tab()

	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	outer.add_child(close_row)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size.x = 120
	MenuTheme.style_menu_button(close)
	close.pressed.connect(_service.close_report_dialog)
	close_row.add_child(close)

	_tabs.set_tab_title(0, "New Report")
	_tabs.set_tab_title(1, "History")
	_title.call_deferred("grab_focus")


func _build_new_report_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	scroll.add_child(root)

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


func _build_history_tab() -> void:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	_tabs.add_child(root)

	var explanation := Label.new()
	explanation.text = (
		"Past reports you filed on this machine. Mark each one still ongoing, done, "
		+ "or trash. Trash hides it from the active list but keeps the file for reference."
	)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MenuTheme.style_muted_label(explanation)
	root.add_child(explanation)

	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	root.add_child(filter_row)
	var filter_label := Label.new()
	filter_label.text = "Show"
	MenuTheme.style_section_label(filter_label)
	filter_row.add_child(filter_label)
	_history_filter = OptionButton.new()
	_history_filter.add_item("Active (still ongoing)", HistoryFilter.ACTIVE)
	_history_filter.add_item("All", HistoryFilter.ALL)
	_history_filter.add_item("Trash only", HistoryFilter.TRASH)
	_history_filter.item_selected.connect(_on_history_filter_changed)
	filter_row.add_child(_history_filter)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_history_list = VBoxContainer.new()
	_history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_history_list)

	_history_status = Label.new()
	_history_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_history_status)


func _on_tab_changed(tab_index: int) -> void:
	if tab_index == 1:
		_refresh_history_list()


func _on_history_filter_changed(index: int) -> void:
	_history_filter_mode = index
	_refresh_history_list()


func _on_report_status_changed(_report_id: String, _status: String) -> void:
	if _tabs != null and _tabs.current_tab == 1:
		_refresh_history_list()


func _refresh_history_list() -> void:
	if _history_list == null or _service == null:
		return
	for child: Node in _history_list.get_children():
		child.queue_free()
	var reports: Array[Dictionary] = _service.list_reports(true)
	var visible_count := 0
	for summary: Dictionary in reports:
		var status: String = String(summary.get("status", DebugReportRuntime.STATUS_ONGOING))
		if not _history_entry_visible(status):
			continue
		visible_count += 1
		_history_list.add_child(_make_history_row(summary))
	if visible_count == 0:
		var empty := Label.new()
		empty.text = "No reports in this view yet."
		MenuTheme.style_muted_label(empty)
		_history_list.add_child(empty)
	_history_status.text = "%d report(s) shown." % visible_count


func _history_entry_visible(status: String) -> bool:
	match _history_filter_mode:
		HistoryFilter.ACTIVE:
			return status == DebugReportRuntime.STATUS_ONGOING
		HistoryFilter.TRASH:
			return status == DebugReportRuntime.STATUS_TRASH
		_:
			return true


func _make_history_row(summary: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	MenuTheme.apply_panel(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	var title := Label.new()
	var report_id: String = String(summary.get("report_id", ""))
	var title_text: String = String(summary.get("title", "(untitled)"))
	title.text = "%s — %s" % [report_id, title_text]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MenuTheme.style_section_label(title)
	column.add_child(title)

	var meta := Label.new()
	var created_at: String = String(summary.get("created_at", ""))
	var severity: String = String(summary.get("severity", ""))
	var category: String = String(summary.get("category", ""))
	var status: String = String(summary.get("status", DebugReportRuntime.STATUS_ONGOING))
	meta.text = "%s · %s · %s · %s" % [
		created_at if not created_at.is_empty() else "unknown date",
		severity,
		category,
		DebugReportRuntime.status_display_name(status),
	]
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MenuTheme.style_muted_label(meta)
	column.add_child(meta)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	column.add_child(buttons)
	buttons.add_child(
		_make_status_button(
			report_id,
			DebugReportRuntime.STATUS_ONGOING,
			"Still ongoing",
			status == DebugReportRuntime.STATUS_ONGOING,
		),
	)
	buttons.add_child(
		_make_status_button(
			report_id,
			DebugReportRuntime.STATUS_DONE,
			"Done",
			status == DebugReportRuntime.STATUS_DONE,
		),
	)
	buttons.add_child(
		_make_status_button(
			report_id,
			DebugReportRuntime.STATUS_TRASH,
			"Trash",
			status == DebugReportRuntime.STATUS_TRASH,
		),
	)
	return panel


func _make_status_button(
	report_id: String,
	status_value: String,
	label_text: String,
	is_current: bool,
) -> Button:
	var button := Button.new()
	button.text = label_text
	button.toggle_mode = true
	button.button_pressed = is_current
	button.disabled = is_current
	button.custom_minimum_size.x = 110
	MenuTheme.style_menu_button(button)
	button.pressed.connect(_on_history_status_pressed.bind(report_id, status_value))
	return button


func _on_history_status_pressed(report_id: String, status_value: String) -> void:
	if _service == null:
		return
	if _service.set_report_status(report_id, status_value):
		_history_status.text = "Updated %s to %s." % [
			report_id,
			DebugReportRuntime.status_display_name(status_value),
		]
		_refresh_history_list()
	else:
		_history_status.text = "Could not update %s." % report_id


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
	_tabs.current_tab = 1
	_refresh_history_list()
	_saving = false
	if _save_button != null:
		_save_button.disabled = false
	_title.text = ""
	_description.text = ""
	_expected.text = ""
	_actual.text = ""
	_screenshot.button_pressed = false


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
