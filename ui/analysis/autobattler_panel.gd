class_name AutobattlerPanel
extends Control

var _label: RichTextLabel
var _metrics_label: RichTextLabel

func _ready() -> void:
	custom_minimum_size = Vector2(300, 200)
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)
	
	var title = Label.new()
	title.text = "Autobattler Thoughts"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_label)
	
	_metrics_label = RichTextLabel.new()
	_metrics_label.bbcode_enabled = true
	_metrics_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_metrics_label)

func update_thoughts(unit_name: String, action_desc: String, score: float, weights: Variant) -> void:
	_label.text = "[color=yellow]Unit:[/color] %s\n[color=yellow]Action:[/color] %s\n[color=yellow]Score:[/color] %.2f" % [unit_name, action_desc, score]
	_metrics_label.text = ""
