class_name MassSimSkirmishSetupDialog
extends Window

signal setup_applied(setup: MassSimSkirmishSetup)

var _fields: SkirmishSetupFields
var _epoch_note: Label


func _init() -> void:
	title = "Skirmish Setup"
	unresizable = false
	transient = true
	exclusive = false
	min_size = Vector2i(520, 520)
	close_requested.connect(func() -> void: hide())
	var panel := PanelContainer.new()
	MassSimTheme.apply_panel(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var scroll_body := VBoxContainer.new()
	scroll_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_body.add_theme_constant_override("separation", 10)
	scroll.add_child(scroll_body)
	var intro := Label.new()
	intro.text = "Configure roster size, levels, and player loadout. Saved to workspace; New Epoch locks these rules."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll_body.add_child(intro)
	_epoch_note = Label.new()
	_epoch_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MassSimTheme.style_muted(_epoch_note)
	scroll_body.add_child(_epoch_note)
	_fields = SkirmishSetupFields.new()
	scroll_body.add_child(_fields)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(btn_row)
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(96, 36)
	MassSimTheme.style_button(cancel_btn)
	cancel_btn.pressed.connect(func() -> void: hide())
	btn_row.add_child(cancel_btn)
	var ok_btn := Button.new()
	ok_btn.text = "Save Setup"
	ok_btn.custom_minimum_size = Vector2(120, 36)
	MassSimTheme.style_button(ok_btn)
	ok_btn.pressed.connect(_on_apply)
	btn_row.add_child(ok_btn)


func open_with(setup: MassSimSkirmishSetup, epoch_locked: MassSimSkirmishSetup = null) -> void:
	_fields.load_setup(setup)
	if epoch_locked != null:
		_epoch_note.text = "Active epoch locked: %s â€” change setup then click New Epoch." % epoch_locked.summary_label()
	else:
		_epoch_note.text = "Edits apply to the next batch. Click New Epoch to start a comparable log."
	popup_centered(Vector2i(520, 520))


func _on_apply() -> void:
	setup_applied.emit(_fields.read_setup())
	hide()
