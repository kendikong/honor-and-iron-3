class_name TriageInboxPanel
extends PanelContainer

signal inspect_requested(title: String, body: String, meta: Dictionary)

var title_label: Label
var warnings_list: VBoxContainer


func _init() -> void:
	MassSimTheme.apply_panel(self)
	var vbox := VBoxContainer.new()
	add_child(vbox)
	title_label = Label.new()
	title_label.text = "Triage Inbox (Root Cause Ranking)"
	MassSimTheme.style_section(title_label)
	vbox.add_child(title_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 180)
	vbox.add_child(scroll)
	warnings_list = VBoxContainer.new()
	warnings_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(warnings_list)


func populate(warnings: Array, workspace: MassSimWorkspace = null) -> void:
	for child: Node in warnings_list.get_children():
		child.queue_free()
	if warnings.is_empty():
		var empty := Label.new()
		empty.text = "No warnings â€” batch looks healthy."
		MassSimTheme.style_muted(empty)
		warnings_list.add_child(empty)
		return
	for w: Variant in warnings:
		if not w is Dictionary:
			continue
		var wd: Dictionary = w as Dictionary
		var card := PanelContainer.new()
		MassSimTheme.apply_panel(card)
		var card_vbox := VBoxContainer.new()
		card.add_child(card_vbox)
		var header := HBoxContainer.new()
		var severity_lbl := Label.new()
		var sev: int = int(wd.get("severity", TriageEngine.Severity.INFO))
		severity_lbl.text = "[%s]" % TriageEngine.Severity.keys()[sev]
		match sev:
			TriageEngine.Severity.CRITICAL:
				severity_lbl.modulate = Color(1.0, 0.35, 0.35)
			TriageEngine.Severity.MAJOR:
				severity_lbl.modulate = Color(1.0, 0.65, 0.2)
			TriageEngine.Severity.MODERATE:
				severity_lbl.modulate = Color(0.9, 0.85, 0.4)
		header.add_child(severity_lbl)
		var title_lbl := Label.new()
		title_lbl.text = "%s (Conf: %d%%)" % [String(wd.get("title", "")), int(wd.get("confidence", 0))]
		header.add_child(title_lbl)
		card_vbox.add_child(header)
		var desc := Label.new()
		desc.text = String(wd.get("description", ""))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		card_vbox.add_child(desc)
		var title_key: String = String(wd.get("title", ""))
		var state_btn := OptionButton.new()
		state_btn.add_item("Investigating")
		state_btn.add_item("Expected")
		state_btn.add_item("Fixed")
		state_btn.add_item("Ignore")
		if workspace != null and workspace.triage_states.has(title_key):
			var saved: int = int(workspace.triage_states[title_key])
			state_btn.select(clampi(saved, 0, 3))
		state_btn.item_selected.connect(func(idx: int) -> void:
			if workspace != null:
				workspace.triage_states[title_key] = idx
				workspace.save()
		)
		card_vbox.add_child(state_btn)
		var inspect_btn := Button.new()
		inspect_btn.text = "Open in Inspector"
		inspect_btn.pressed.connect(func() -> void:
			inspect_requested.emit(
				String(wd.get("title", "Warning")),
				String(wd.get("description", "")),
				wd,
			)
		)
		card_vbox.add_child(inspect_btn)
		warnings_list.add_child(card)
