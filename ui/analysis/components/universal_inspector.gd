class_name UniversalInspectorPanel
extends PanelContainer

var title_label: Label
var details_rich_text: RichTextLabel

func _init() -> void:
	custom_minimum_size = Vector2(300, 0)
	
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	title_label = Label.new()
	title_label.text = "Universal Inspector"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	details_rich_text = RichTextLabel.new()
	details_rich_text.bbcode_enabled = true
	details_rich_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_rich_text.text = "Click any metric, chart, or warning to view contextual details here."
	vbox.add_child(details_rich_text)

func update_context(title: String, bbcode_details: String) -> void:
	title_label.text = title
	details_rich_text.text = bbcode_details
