class_name TriageInboxPanel
extends PanelContainer

var title_label: Label
var warnings_list: VBoxContainer

func _init() -> void:
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	title_label = Label.new()
	title_label.text = "Triage Inbox (Root Cause Ranking)"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	warnings_list = VBoxContainer.new()
	warnings_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(warnings_list)

func populate(warnings: Array) -> void:
	for child in warnings_list.get_children():
		child.queue_free()
		
	for w in warnings:
		var card = PanelContainer.new()
		var card_vbox = VBoxContainer.new()
		card.add_child(card_vbox)
		
		var header = HBoxContainer.new()
		var severity_lbl = Label.new()
		var s_name = TriageEngine.Severity.keys()[w.severity]
		severity_lbl.text = "[%s]" % s_name
		if w.severity == TriageEngine.Severity.CRITICAL:
			severity_lbl.modulate = Color.RED
		elif w.severity == TriageEngine.Severity.MAJOR:
			severity_lbl.modulate = Color.ORANGE
		header.add_child(severity_lbl)
		
		var title_lbl = Label.new()
		title_lbl.text = "%s (Conf: %d%%)" % [w.title, w.confidence]
		header.add_child(title_lbl)
		card_vbox.add_child(header)
		
		var desc = Label.new()
		desc.text = w.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		card_vbox.add_child(desc)
		
		var state_btn = OptionButton.new()
		state_btn.add_item("Investigating")
		state_btn.add_item("Expected")
		state_btn.add_item("Fixed")
		state_btn.add_item("Ignore")
		card_vbox.add_child(state_btn)
		
		warnings_list.add_child(card)
