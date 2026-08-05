class_name UniversalInspectorPanel
extends PanelContainer

signal replay_requested(run_id: int)
signal pin_requested(run_id: int)

var title_label: Label
var details_rich_text: RichTextLabel
var action_row: HBoxContainer
var _meta: Dictionary = {}
var _current_run_id: int = -1


func _init() -> void:
	MassSimTheme.apply_panel(self)
	custom_minimum_size = Vector2(340, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)
	title_label = Label.new()
	title_label.text = "Universal Inspector"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MassSimTheme.style_section(title_label)
	vbox.add_child(title_label)
	details_rich_text = RichTextLabel.new()
	details_rich_text.bbcode_enabled = true
	details_rich_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_rich_text.text = (
		"[color=#8fa3b8]Click KPIs, tier rows, triage warnings, or Ctrl+K entries.[/color]\n\n"
		+ "[b]Three-Click Rule[/b]\n"
		+ "Warning â†’ Inspector â†’ Open Replay."
	)
	vbox.add_child(details_rich_text)
	action_row = HBoxContainer.new()
	action_row.visible = false
	vbox.add_child(action_row)


func update_context(title: String, bbcode_details: String, meta: Dictionary = {}) -> void:
	title_label.text = title
	details_rich_text.text = bbcode_details
	_meta = meta.duplicate(true)
	_current_run_id = int(meta.get("run_id", -1))
	_rebuild_actions()


func show_replay(report: MassSimBatchReport, run_id: int) -> void:
	_current_run_id = run_id
	_meta = {"run_id": run_id}
	title_label.text = "Replay #%d" % run_id
	details_rich_text.text = MassSimReplayFormat.format_run(report, run_id)
	_rebuild_actions()


func _rebuild_actions() -> void:
	for child: Node in action_row.get_children():
		child.queue_free()
	if _current_run_id < 0:
		action_row.visible = false
		return
	action_row.visible = true
	var open_btn := Button.new()
	open_btn.text = "Open Replay"
	MassSimTheme.style_button(open_btn)
	open_btn.pressed.connect(func() -> void: replay_requested.emit(_current_run_id))
	action_row.add_child(open_btn)
	var pin_btn := Button.new()
	pin_btn.text = "Pin"
	MassSimTheme.style_button(pin_btn)
	pin_btn.pressed.connect(func() -> void: pin_requested.emit(_current_run_id))
	action_row.add_child(pin_btn)
	var copy_btn := Button.new()
	copy_btn.text = "Copy ID"
	MassSimTheme.style_button(copy_btn)
	copy_btn.pressed.connect(func() -> void: DisplayServer.clipboard_set(str(_current_run_id)))
	action_row.add_child(copy_btn)
